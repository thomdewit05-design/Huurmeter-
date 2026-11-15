import Foundation
import WWSKit

/// Haalt de kale huur en de ingangsdatum uit de tekst van een gescand huurcontract. Alles gebeurt op
/// het toestel. De uitkomst is een voorstel: de gebruiker bevestigt of corrigeert altijd.
public enum ContractHerkenner {
    public struct Voorstel: Equatable, Sendable {
        public var kaleHuur: Double?
        public var kaleHuurRegel: String?
        public var ingangsdatum: Dag?
        public var ingangsdatumRegel: String?
        public var postcode: String?
        public var huisnummer: String?
        public var servicekostenPerMaand: Double?

        /// true als er niets is herkend.
        public var isLeeg: Bool { kaleHuur == nil && ingangsdatum == nil && postcode == nil && servicekostenPerMaand == nil }
    }

    /// Woorden die direct op de kale huur wijzen (zonder servicekosten).
    static let huurWoorden = ["kale huur", "kale huurprijs", "netto huur", "netto huurprijs", "basishuur", "huurprijs exclusief"]
    /// Algemene huurwoorden; alleen gebruikt als de regel niet over servicekosten of totaal gaat.
    static let algemeneHuurWoorden = ["huurprijs", "huur per maand", "maandhuur", "huur bedraagt"]
    static let uitsluiten = ["servicekosten", "service kosten", "voorschot", "totaal", "totale", "inclusief", "incl.", "borg", "waarborgsom", "energie", "gas", "water", "licht"]
    static let datumWoorden = ["ingangsdatum", "ingaande", "met ingang van", "gaat in op", "aanvang", "ingangs datum", "vanaf"]

    static let maanden = ["januari": 1, "februari": 2, "maart": 3, "april": 4, "mei": 5, "juni": 6, "juli": 7,
                          "augustus": 8, "september": 9, "oktober": 10, "november": 11, "december": 12,
                          "jan": 1, "feb": 2, "mrt": 3, "apr": 4, "jun": 6, "jul": 7, "aug": 8, "sep": 9, "sept": 9,
                          "okt": 10, "nov": 11, "dec": 12]

    public static func herken(_ tekst: String) -> Voorstel {
        let regels = tekst.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        var v = Voorstel()

        // Huur: eerst de specifieke woorden, dan de algemene. Een bedrag kan ook op de volgende regel staan.
        for woorden in [huurWoorden, algemeneHuurWoorden] where v.kaleHuur == nil {
            for (i, regel) in regels.enumerated() {
                let klein = regel.lowercased()
                guard woorden.contains(where: klein.contains) else { continue }
                if woorden == algemeneHuurWoorden && uitsluiten.contains(where: klein.contains) { continue }
                let kandidaat = bedrag(in: regel) ?? (i + 1 < regels.count ? bedrag(in: regels[i + 1]) : nil)
                if let b = kandidaat, b >= 50, b <= 10_000 {
                    v.kaleHuur = b; v.kaleHuurRegel = regel
                    break
                }
            }
        }

        for (i, regel) in regels.enumerated() {
            let klein = regel.lowercased()
            guard datumWoorden.contains(where: klein.contains) else { continue }
            if let d = datum(in: regel) ?? (i + 1 < regels.count ? datum(in: regels[i + 1]) : nil) {
                v.ingangsdatum = d; v.ingangsdatumRegel = regel
                break
            }
        }
        if let a = adres(in: regels) { v.postcode = a.postcode; v.huisnummer = a.huisnummer }
        v.servicekostenPerMaand = servicekosten(in: regels)
        return v
    }

    /// Eerste eurobedrag in de tekst: "€ 975,00", "EUR 1.150,-", "975,00 euro", "€975".
    static func bedrag(in tekst: String) -> Double? {
        let patroon = #"(?:€|eur(?:o)?\.?)\s*([0-9]{1,3}(?:[.\s][0-9]{3})*|[0-9]+)(?:,([0-9]{2}|-{1,2}))?|([0-9]{1,3}(?:\.[0-9]{3})*|[0-9]+),([0-9]{2})\s*(?:euro|eur)"#
        guard let re = try? NSRegularExpression(pattern: patroon, options: [.caseInsensitive]),
              let m = re.firstMatch(in: tekst, range: NSRange(tekst.startIndex..., in: tekst)) else { return nil }
        func groep(_ n: Int) -> String? {
            guard let r = Range(m.range(at: n), in: tekst) else { return nil }
            return String(tekst[r])
        }
        let heel = (groep(1) ?? groep(3))?.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: " ", with: "")
        let centen = groep(2) ?? groep(4)
        guard let h = heel, let euro = Double(h) else { return nil }
        if let c = centen, let cc = Double(c) { return euro + cc / 100 }
        return euro
    }

    /// Eerste datum: "01-07-2026", "1/7/2026", "1.7.2026", "1 juli 2026".
    static func datum(in tekst: String) -> Dag? {
        let numeriek = #"\b([0-3]?[0-9])[-/.]([01]?[0-9])[-/.]((?:19|20)[0-9]{2})\b"#
        if let re = try? NSRegularExpression(pattern: numeriek),
           let m = re.firstMatch(in: tekst, range: NSRange(tekst.startIndex..., in: tekst)),
           let d = Int(tekst[Range(m.range(at: 1), in: tekst)!]), let mnd = Int(tekst[Range(m.range(at: 2), in: tekst)!]),
           let j = Int(tekst[Range(m.range(at: 3), in: tekst)!]),
           let dag = Dag(iso: String(format: "%04d-%02d-%02d", j, mnd, d)) {
            return dag
        }
        let woordelijk = #"\b([0-3]?[0-9])\s+([a-z]+)\.?\s+((?:19|20)[0-9]{2})\b"#
        if let re = try? NSRegularExpression(pattern: woordelijk, options: [.caseInsensitive]) {
            for m in re.matches(in: tekst, range: NSRange(tekst.startIndex..., in: tekst)) {
                let maandWoord = tekst[Range(m.range(at: 2), in: tekst)!].lowercased()
                if let mnd = maanden[maandWoord], let d = Int(tekst[Range(m.range(at: 1), in: tekst)!]),
                   let j = Int(tekst[Range(m.range(at: 3), in: tekst)!]),
                   let dag = Dag(iso: String(format: "%04d-%02d-%02d", j, mnd, d)) {
                    return dag
                }
            }
        }
        return nil
    }
}
