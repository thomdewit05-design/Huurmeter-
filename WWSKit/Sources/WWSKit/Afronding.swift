import Foundation

/// Afrondingsregels uit de toelichting bij Bijlage I onder A, Besluit huurprijzen woonruimte.
/// Een kleine marge vangt binaire afrondingsfouten van Double op (bv. 0,1 + 0,2).
public enum Afronding {
    static let marge = 1e-9

    /// Per rubriek: "na saldering afgerond op 0,25 punt waarbij een achtste (1/8) punt naar boven wordt afgerond".
    public static func rubriek(_ x: Double) -> Double {
        ((x * 4 + 0.5 + marge).rounded(.down)) / 4
    }

    /// Oppervlakte per ruimte: "afgerond op twee decimalen".
    public static func tweeDecimalen(_ x: Double) -> Double {
        ((x * 100 + 0.5 + marge).rounded(.down)) / 100
    }

    /// Totale oppervlakte en puntentotaal: hele eenheden, 0,5 of meer naar boven.
    public static func heel(_ x: Double) -> Double {
        (x + 0.5 + marge).rounded(.down)
    }

    /// Naar beneden op hele punten (cap op de WOZ, 11.3).
    public static func omlaag(_ x: Double) -> Double {
        (x + marge).rounded(.down)
    }

    /// Bedragen op hele centen.
    public static func centen(_ x: Double) -> Double {
        ((x * 100 + 0.5 + marge).rounded(.down)) / 100
    }
}

/// Getallen in Nederlandse notatie voor de tussenstappen.
enum NL {
    static func getal(_ x: Double, decimalen: Int? = nil) -> String {
        if let d = decimalen { return Getalnotatie.nl(x, decimalen: d) }
        return Getalnotatie.nl(x, maxDecimalen: 4)
    }

    static func punten(_ x: Double) -> String {
        let s = getal(x, decimalen: x.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 2)
        return abs(x) == 1 ? "\(s) punt" : "\(s) punten"
    }

    static func m2(_ x: Double, decimalen: Int = 2) -> String { "\(getal(x, decimalen: decimalen)) m²" }

    static func euro(_ x: Double) -> String { "€ \(getal(x, decimalen: 2))" }
}
