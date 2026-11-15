import Foundation

/// Grove indicatie van het bedrag dat een huurder per maand te veel betaalt, voor de gratis versie.
/// Het exacte bedrag staat achter de betaalmuur; de band is bewust breed.
public struct Bandbreedte: Equatable, Sendable {
    /// Ondergrens in hele euro's.
    public let van: Int
    /// Bovengrens in hele euro's; nil = "meer dan `van`".
    public let tot: Int?

    /// Grenzen per maand. Onder € 1 is er geen band (dan geen verschil van betekenis).
    static let grenzen = [1, 50, 100, 200, 300, 500]

    public static func voor(teVeelPerMaand verschil: Double) -> Bandbreedte? {
        guard verschil >= Double(grenzen[0]) else { return nil }
        for (i, g) in grenzen.enumerated().reversed() where verschil >= Double(g) {
            let van = i == 0 ? 0 : g
            return Bandbreedte(van: van, tot: i + 1 < grenzen.count ? grenzen[i + 1] : nil)
        }
        return nil
    }
}
