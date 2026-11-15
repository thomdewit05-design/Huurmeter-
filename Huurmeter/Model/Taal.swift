import Foundation
import WWSKit
import HuurmeterCore

// Engelse versie (functie 12). Teksten uit de packages (vragen, stappen, rubrieken) zijn Nederlands;
// de app zoekt ze op in Localizable.xcstrings. Ontbreekt een vertaling, dan blijft de Nederlandse tekst staan.
// Bewust Nederlands: de conceptbrief en het PDF-dossier (die gaan naar de verhuurder of de Huurcommissie),
// bronvermeldingen en de rekenstappen per rubriek.
extension String {
    var vertaald: String { NSLocalizedString(self, comment: "") }
}

enum Weergave {
    static func segment(_ s: Segment) -> String {
        switch s {
        case .sociaal: return String(localized: "Sociale huur")
        case .midden: return String(localized: "Middenhuur")
        case .vrij: return String(localized: "Vrije sector")
        }
    }

    static func samenvatting(_ u: Uitkomst, kaleHuur: Double?) -> Opmaak.Samenvatting {
        let seg = segment(u.segment)
        guard let max = u.maximaleHuur else {
            return Opmaak.Samenvatting(kop: String(localized: "Vrije sector: geen maximale huur"),
                                       regels: [String(localized: "Met \(u.totaal) punten valt de woning in de vrije sector. Daar geldt geen wettelijke maximale huurprijs.")],
                                       teVeel: false)
        }
        var regels = [String(localized: "Maximale kale huur: \(Opmaak.euro(max)) per maand.")]
        if u.prijsopslag > 0 {
            let pct = Opmaak.getal(u.prijsopslag * 100, decimalen: 0)
            let zonder = Opmaak.euro(u.maximaleHuurZonderOpslag ?? max)
            regels.append(String(localized: "Inclusief \(pct)% opslag (\(zonder) zonder opslag)."))
        }
        guard let huur = kaleHuur, let verschil = u.verschilPerMaand, let perJaar = u.verschilPerJaar else {
            regels.append(String(localized: "Vul uw kale huur in om het verschil te zien."))
            return Opmaak.Samenvatting(kop: String(localized: "\(u.totaal) punten · \(seg)"), regels: regels, teVeel: false)
        }
        if verschil > 0 {
            regels.append(String(localized: "U betaalt \(Opmaak.euro(huur)): \(Opmaak.euro(verschil)) per maand te veel, \(Opmaak.euro(perJaar)) per jaar."))
            return Opmaak.Samenvatting(kop: String(localized: "Mogelijk \(Opmaak.euro(verschil)) per maand te veel"), regels: regels, teVeel: true)
        }
        regels.append(String(localized: "U betaalt \(Opmaak.euro(huur)), dat is niet meer dan het maximum."))
        return Opmaak.Samenvatting(kop: String(localized: "\(u.totaal) punten · \(seg)"), regels: regels, teVeel: false)
    }

    static func termijn(_ t: Termijn) -> String {
        String(localized: "Nog \(t.resterendeDagen) dagen om de Huurcommissie te vragen uw aanvangshuur te toetsen (tot en met \(t.einddatum.description)). Dit geldt alleen als dit uw eerste huurcontract voor deze woning is.")
    }
}
