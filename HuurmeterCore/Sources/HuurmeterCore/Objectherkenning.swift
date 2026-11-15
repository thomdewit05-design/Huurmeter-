import Foundation

/// Een object dat de camera (RoomPlan) in een ruimte heeft herkend, met afmetingen in meters.
public struct GevondenObject: Sendable, Equatable {
    public enum Soort: String, Sendable, CaseIterable {
        case kookplaat, oven, vaatwasser, koelkast, wastafelOfSpoelbak, kast, toilet, bad, wasmachine, overig
    }
    public let soort: Soort
    public let breedte: Double
    public let hoogte: Double
    public let diepte: Double

    public init(_ soort: Soort, breedte: Double = 0, hoogte: Double = 0, diepte: Double = 0) {
        self.soort = soort; self.breedte = breedte; self.hoogte = hoogte; self.diepte = diepte
    }
}

/// Welke ruimte er is gescand.
public enum ScanRuimte: Sendable, Equatable {
    case keuken
    case badkamer(Int)
    case toilet
}

/// Een voorgesteld antwoord op een vraag van scherm 5. De gebruiker bevestigt het altijd zelf.
public struct Voorstel: Sendable, Equatable, Identifiable {
    public struct Optie: Sendable, Equatable, Hashable {
        public let sleutel: String
        public let tekst: String
    }

    public let id: String
    public let titel: String
    public let uitleg: String?
    /// De vraag(en) waarop het voorstel kan landen; bij meer dan één kiest de gebruiker (bijv. het soort kookplaat).
    public let opties: [Optie]
    public var gekozen: Int
    /// Aantal of lengte (m) die wordt ingevuld.
    public var waarde: Double
    /// true: waarde is een lengte in meters; false: een aantal.
    public let isLengte: Bool
    public let rubriek: String
    public var overnemen: Bool

    public var sleutel: String { opties[min(max(gekozen, 0), opties.count - 1)].sleutel }

    /// true: de gebruiker kan het aantal aanpassen (bad, wastafel, toilet in een aparte toiletruimte);
    /// anders is het een ja/nee-vraag en wordt 1 ingevuld.
    public var isAantal: Bool {
        guard !isLengte else { return false }
        return id == "bad" || id == "wastafel" || (id == "toilet" && sleutel.hasPrefix("toilet."))
    }
}

/// Zet herkende objecten om in voorstellen. Alleen wat de camera echt kan zien; ingebouwd of niet, het soort
/// kookplaat en een douche herkent RoomPlan niet, dus daar vraagt de app het na.
public enum Objectherkenning {
    public static func voorstellen(_ objecten: [GevondenObject], ruimte: ScanRuimte) -> [Voorstel] {
        func aantal(_ s: GevondenObject.Soort) -> Int { objecten.filter { $0.soort == s }.count }
        var lijst: [Voorstel] = []

        switch ruimte {
        case .keuken:
            if aantal(.kookplaat) > 0 {
                lijst.append(Voorstel(id: "kookplaat", titel: "Kookplaat", uitleg: "Kies het soort. Alleen een ingebouwde kookplaat telt.",
                                      opties: [.init(sleutel: "keuken.kookplaatInductie", tekst: "Inductie"),
                                               .init(sleutel: "keuken.kookplaatKeramisch", tekst: "Keramisch"),
                                               .init(sleutel: "keuken.kookplaatGas", tekst: "Gas")],
                                      gekozen: 0, waarde: 1, isLengte: false, rubriek: "5", overnemen: true))
            }
            if aantal(.oven) > 0 {
                lijst.append(Voorstel(id: "oven", titel: "Oven", uitleg: "Alleen een ingebouwde oven telt.",
                                      opties: [.init(sleutel: "keuken.ovenElektrisch", tekst: "Elektrisch"),
                                               .init(sleutel: "keuken.ovenGas", tekst: "Gas")],
                                      gekozen: 0, waarde: 1, isLengte: false, rubriek: "5", overnemen: true))
            }
            if aantal(.vaatwasser) > 0 {
                lijst.append(Voorstel(id: "vaatwasser", titel: "Vaatwasser", uitleg: "Alleen een ingebouwde vaatwasser telt.",
                                      opties: [.init(sleutel: "keuken.vaatwasmachine", tekst: "Vaatwasser")],
                                      gekozen: 0, waarde: 1, isLengte: false, rubriek: "5", overnemen: true))
            }
            if aantal(.koelkast) > 0 {
                // Een vrijstaande koelkast telt niet; die is van buiten niet te onderscheiden, dus standaard uit.
                lijst.append(Voorstel(id: "koelkast", titel: "Koelkast", uitleg: "Alleen als hij is ingebouwd (achter een keukendeur).",
                                      opties: [.init(sleutel: "keuken.koelkast", tekst: "Koelkast")],
                                      gekozen: 0, waarde: 1, isLengte: false, rubriek: "5", overnemen: false))
            }
            if let lengte = aanrechtSchatting(objecten) {
                lijst.append(Voorstel(id: "aanrecht", titel: "Lengte van het aanrecht (schatting)",
                                      uitleg: "Opgeteld uit de onderkasten, spoelbak en apparaten onder het blad. Controleer het met de AR-meter of een rolmaat.",
                                      opties: [.init(sleutel: "keuken.aanrecht", tekst: "Aanrecht")],
                                      gekozen: 0, waarde: lengte, isLengte: true, rubriek: "5", overnemen: false))
            }

        case .badkamer(let i):
            let p = "badkamer\(i)"
            if aantal(.bad) > 0 {
                lijst.append(Voorstel(id: "bad", titel: "Bad", uitleg: nil,
                                      opties: [.init(sleutel: "\(p).baden", tekst: "Bad")],
                                      gekozen: 0, waarde: Double(aantal(.bad)), isLengte: false, rubriek: "6", overnemen: true))
            }
            let wastafels = objecten.filter { $0.soort == .wastafelOfSpoelbak }
            if !wastafels.isEmpty {
                // Een brede wastafel (vanaf 1,2 m) is waarschijnlijk een dubbele; die moet minstens 70 cm met twee kranen zijn.
                let breed = wastafels.allSatisfy { $0.breedte >= 1.2 }
                lijst.append(Voorstel(id: "wastafel", titel: "Wastafel", uitleg: "Een dubbele wastafel is minstens 70 cm breed en heeft twee kranen.",
                                      opties: [.init(sleutel: "\(p).wastafels", tekst: "Gewone wastafel"),
                                               .init(sleutel: "\(p).meerpersoonswastafels", tekst: "Dubbele wastafel")],
                                      gekozen: breed ? 1 : 0, waarde: Double(wastafels.count), isLengte: false, rubriek: "6", overnemen: true))
            }
            if aantal(.toilet) > 0 {
                lijst.append(Voorstel(id: "toilet", titel: "Toilet in de badkamer", uitleg: "Een hangend toilet hangt aan de muur, zonder voet.",
                                      opties: [.init(sleutel: "\(p).toiletStaand", tekst: "Staand"),
                                               .init(sleutel: "\(p).toiletHangend", tekst: "Hangend")],
                                      gekozen: 0, waarde: 1, isLengte: false, rubriek: "6", overnemen: true))
            }

        case .toilet:
            if aantal(.toilet) > 0 {
                lijst.append(Voorstel(id: "toilet", titel: "Toilet", uitleg: "Een hangend toilet hangt aan de muur, zonder voet.",
                                      opties: [.init(sleutel: "toilet.staand", tekst: "Staand"),
                                               .init(sleutel: "toilet.hangend", tekst: "Hangend")],
                                      gekozen: 0, waarde: Double(aantal(.toilet)), isLengte: false, rubriek: "6", overnemen: true))
            }
            if aantal(.wastafelOfSpoelbak) > 0 {
                lijst.append(Voorstel(id: "fontein", titel: "Wastafel in het toilet", uitleg: nil,
                                      opties: [.init(sleutel: "toilet.wastafel", tekst: "Wastafel")],
                                      gekozen: 0, waarde: 1, isLengte: false, rubriek: "6", overnemen: true))
            }
        }
        return lijst
    }

    /// Schatting van de aanrechtlengte: de breedte van alles wat onder het blad staat (onderkasten van 60 tot
    /// 110 cm hoog, spoelbak, vaatwasser en kookplaat), afgerond op 10 cm. Nil als er niets onder het blad is gezien.
    public static func aanrechtSchatting(_ objecten: [GevondenObject]) -> Double? {
        let onderBlad = objecten.filter { o in
            switch o.soort {
            case .kast: return (0.6...1.1).contains(o.hoogte)
            case .wastafelOfSpoelbak, .vaatwasser, .kookplaat: return o.hoogte <= 1.1
            default: return false
            }
        }
        let som = onderBlad.reduce(0) { $0 + $1.breedte }
        guard som >= 0.3 else { return nil }
        return (som * 10).rounded() / 10
    }
}
