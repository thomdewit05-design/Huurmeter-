import Foundation
import WWSKit

/// Punt in de ruimte (meters), los van simd zodat de berekening ook buiten iOS te testen is.
/// RoomPlan gebruikt een rechtshandig assenstelsel met y omhoog; de vloer ligt dus in het x-z-vlak.
public struct Punt3: Hashable, Sendable {
    public var x: Double, y: Double, z: Double
    public init(_ x: Double, _ y: Double, _ z: Double) { self.x = x; self.y = y; self.z = z }
}

public struct Punt2: Hashable, Sendable {
    public var x: Double, y: Double
    public init(_ x: Double, _ y: Double) { self.x = x; self.y = y }
}

/// Een lijnstuk op de plattegrond (bijv. een muur, deur of raam), in meters in het vloervlak.
public struct Lijnstuk: Hashable, Sendable {
    public var van: Punt2, naar: Punt2
    public init(van: Punt2, naar: Punt2) { self.van = van; self.naar = naar }
    public var lengte: Double { hypot(naar.x - van.x, naar.y - van.y) }
}

public enum Geometrie {
    /// Oppervlakte van een vlakke veelhoek in de ruimte (methode van Newell). Werkt ongeacht hoe het vlak
    /// ligt, en dus ook als de hoekpunten van RoomPlan in een gekanteld lokaal assenstelsel staan.
    /// Spec §6: de oppervlakte komt uit de vloerpolygoon, niet uit de omhullende rechthoek.
    public static func oppervlakte(_ p: [Punt3]) -> Double {
        guard p.count >= 3 else { return 0 }
        var nx = 0.0, ny = 0.0, nz = 0.0
        for i in p.indices {
            let a = p[i], b = p[(i + 1) % p.count]
            nx += (a.y - b.y) * (a.z + b.z)
            ny += (a.z - b.z) * (a.x + b.x)
            nz += (a.x - b.x) * (a.y + b.y)
        }
        return 0.5 * (nx * nx + ny * ny + nz * nz).squareRoot()
    }

    /// Oppervlakte van een veelhoek in het vlak (schoenveterformule), altijd positief.
    public static func oppervlakte(_ p: [Punt2]) -> Double {
        guard p.count >= 3 else { return 0 }
        var s = 0.0
        for i in p.indices {
            let a = p[i], b = p[(i + 1) % p.count]
            s += a.x * b.y - b.x * a.y
        }
        return abs(s) / 2
    }

    /// Afstand tussen twee punten in de ruimte (meters).
    public static func afstand(_ a: Punt3, _ b: Punt3) -> Double {
        ((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y) + (a.z - b.z) * (a.z - b.z)).squareRoot()
    }

    /// Totale aanrechtlengte uit gemeten delen (hoekaanrecht: de lange zijden opgeteld, toelichting 5.1),
    /// afgerond op hele centimeters.
    public static func aanrechtLengte(_ delen: [Double]) -> Double {
        (delen.filter { $0 > 0 }.reduce(0, +) * 100).rounded() / 100
    }

    /// Bovenaanzicht: x blijft x, z wordt y (RoomPlan: y is omhoog).
    public static func bovenaanzicht(_ p: Punt3) -> Punt2 { Punt2(p.x, p.z) }

    /// Past figuren in een kader van `breedte` × `hoogte` (bijv. pixels), met gelijke schaal in beide richtingen
    /// en een marge. Geeft de omzetting terug als functie plus de schaal (eenheden per meter).
    public static func inpassen(_ punten: [Punt2], breedte: Double, hoogte: Double, marge: Double)
        -> (omzetten: @Sendable (Punt2) -> Punt2, schaal: Double)? {
        guard let minX = punten.map(\.x).min(), let maxX = punten.map(\.x).max(),
              let minY = punten.map(\.y).min(), let maxY = punten.map(\.y).max() else { return nil }
        let bw = max(maxX - minX, 0.01), bh = max(maxY - minY, 0.01)
        let beschikbaarB = max(breedte - 2 * marge, 1), beschikbaarH = max(hoogte - 2 * marge, 1)
        let schaal = min(beschikbaarB / bw, beschikbaarH / bh)
        let offX = (breedte - bw * schaal) / 2, offY = (hoogte - bh * schaal) / 2
        return ({ p in Punt2(offX + (p.x - minX) * schaal, offY + (p.y - minY) * schaal) }, schaal)
    }
}

/// Uitkomst van één scan, klaar om in de app te bewaren en te tekenen.
public struct ScanResultaat: Sendable, Equatable {
    /// Vloerpolygoon in bovenaanzicht (meters).
    public var vloer: [Punt2]
    public var muren: [Lijnstuk]
    public var deuren: [Lijnstuk]
    public var ramen: [Lijnstuk]
    /// Vloeroppervlak in m², berekend uit de vloerpolygoon.
    public var vloeroppervlakte: Double

    public init(vloer: [Punt2], muren: [Lijnstuk] = [], deuren: [Lijnstuk] = [], ramen: [Lijnstuk] = [],
                vloeroppervlakte: Double? = nil) {
        self.vloer = vloer; self.muren = muren; self.deuren = deuren; self.ramen = ramen
        self.vloeroppervlakte = vloeroppervlakte ?? Geometrie.oppervlakte(vloer)
    }
}

/// Hoe een gescande oppervlakte en de correcties van de gebruiker samen de WWS-oppervlakte geven.
public enum Inmeting {
    /// Oppervlakte die de app voorstelt na een scan: vloer min het deel lager dan 1,50 m en schachten.
    public static func voorstel(gescand: Double, aftrek: Double) -> Double {
        max(0, gescand - max(0, aftrek))
    }

    /// Spec §6: altijd met één decimaal tonen.
    public static func weergave(_ m2: Double) -> String { Opmaak.oppervlakte(m2) }
}

/// Vertaalt het kamertype dat RoomPlan herkent (CapturedRoom.Section.Label) naar een functie in de app.
/// Het blijft een voorstel; de gebruiker kan het aanpassen.
public enum Kamerherkenning {
    public static func functie(voorLabel label: String) -> RuimteFunctie {
        switch label.lowercased() {
        case "bathroom": return .badkamer
        case "bedroom": return .slaapkamer
        case "kitchen": return .keuken
        case "livingroom", "diningroom": return .woonkamer
        default: return .overig
        }
    }

    /// Voorgestelde naam, genummerd als het type vaker voorkomt ("Slaapkamer 2").
    public static func namen(voor functies: [RuimteFunctie]) -> [String] {
        var tellers: [RuimteFunctie: Int] = [:]
        let totaal = Dictionary(grouping: functies, by: { $0 }).mapValues(\.count)
        return functies.map { f in
            tellers[f, default: 0] += 1
            let basis = f == .overig ? "Kamer" : f.rawValue.prefix(1).uppercased() + f.rawValue.dropFirst()
            return (totaal[f] ?? 0) > 1 ? "\(basis) \(tellers[f]!)" : basis
        }
    }
}
