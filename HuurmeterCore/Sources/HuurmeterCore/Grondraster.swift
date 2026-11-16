import Foundation

/// Oppervlakte uit een LiDAR-scan (het 3D-net van ARKit): alleen naar boven gerichte driehoeken op
/// vloerhoogte tellen. Ze worden op een raster van kleine vakjes in bovenaanzicht gelegd, zodat
/// overlappende stukken van de scan niet dubbel tellen.
public enum Grondraster {
    public struct Cel: Hashable, Sendable {
        public let x: Int
        public let z: Int
    }

    public typealias Driehoek = (Punt3, Punt3, Punt3)

    /// Standaard vakjesgrootte: 5 cm.
    public static let celGrootte = 0.05

    /// Naar boven gericht (normaal minder dan ~30° van verticaal)?
    static func isVloerachtig(_ d: Driehoek) -> (Bool, Double) {
        let (a, b, c) = d
        let ux = b.x - a.x, uy = b.y - a.y, uz = b.z - a.z
        let vx = c.x - a.x, vy = c.y - a.y, vz = c.z - a.z
        let nx = uy * vz - uz * vy, ny = uz * vx - ux * vz, nz = ux * vy - uy * vx
        let lengte = (nx * nx + ny * ny + nz * nz).squareRoot()
        guard lengte > 1e-12 else { return (false, 0) }
        return (abs(ny) / lengte > 0.85, lengte / 2)
    }

    /// Hoogte van de vloer: de laag (per 5 cm) met het meeste horizontale oppervlak.
    public static func vloerHoogte(_ driehoeken: [Driehoek]) -> Double? {
        var lagen: [Int: Double] = [:]
        for d in driehoeken {
            let (vloer, opp) = isVloerachtig(d)
            guard vloer else { continue }
            let y = (d.0.y + d.1.y + d.2.y) / 3
            lagen[Int((y / 0.05).rounded()), default: 0] += opp
        }
        guard let beste = lagen.max(by: { $0.value < $1.value }) else { return nil }
        return Double(beste.key) * 0.05
    }

    /// De vakjes die door vloerdriehoeken (binnen `marge` van de vloerhoogte) worden bedekt.
    public static func cellen(_ driehoeken: [Driehoek], vloerHoogte: Double, marge: Double = 0.12,
                              celGrootte: Double = celGrootte) -> Set<Cel> {
        var uit = Set<Cel>()
        for d in driehoeken {
            guard isVloerachtig(d).0 else { continue }
            let y = (d.0.y + d.1.y + d.2.y) / 3
            guard abs(y - vloerHoogte) <= marge else { continue }
            let p = [d.0, d.1, d.2].map { Punt2($0.x, $0.z) }
            let minX = Int((p.map(\.x).min()! / celGrootte).rounded(.down)), maxX = Int((p.map(\.x).max()! / celGrootte).rounded(.down))
            let minZ = Int((p.map(\.y).min()! / celGrootte).rounded(.down)), maxZ = Int((p.map(\.y).max()! / celGrootte).rounded(.down))
            var raak = false
            if minX <= maxX && minZ <= maxZ {
                for cx in minX...maxX {
                    for cz in minZ...maxZ {
                        let midden = Punt2((Double(cx) + 0.5) * celGrootte, (Double(cz) + 0.5) * celGrootte)
                        if binnen(midden, p[0], p[1], p[2]) { uit.insert(Cel(x: cx, z: cz)); raak = true }
                    }
                }
            }
            // Heel kleine driehoek zonder vakjesmidden erin: tel het vakje van het zwaartepunt.
            if !raak {
                let zx = (p[0].x + p[1].x + p[2].x) / 3, zz = (p[0].y + p[1].y + p[2].y) / 3
                uit.insert(Cel(x: Int((zx / celGrootte).rounded(.down)), z: Int((zz / celGrootte).rounded(.down))))
            }
        }
        return uit
    }

    /// Oppervlakte (m², twee decimalen) van alle vakjes samen.
    public static func oppervlakte<S: Sequence>(_ verzamelingen: S, celGrootte: Double = celGrootte) -> Double where S.Element == Set<Cel> {
        var alles = Set<Cel>()
        for v in verzamelingen { alles.formUnion(v) }
        return (Double(alles.count) * celGrootte * celGrootte * 100).rounded() / 100
    }

    static func binnen(_ p: Punt2, _ a: Punt2, _ b: Punt2, _ c: Punt2) -> Bool {
        func kant(_ p1: Punt2, _ p2: Punt2, _ p3: Punt2) -> Double { (p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y) }
        let d1 = kant(p, a, b), d2 = kant(p, b, c), d3 = kant(p, c, a)
        let neg = d1 < 0 || d2 < 0 || d3 < 0, pos = d1 > 0 || d2 > 0 || d3 > 0
        return !(neg && pos)
    }
}
