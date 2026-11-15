import Foundation
import WWSKit

/// Herkent gegevens in de tekst van gescande brieven (op het toestel herkend). Altijd een voorstel:
/// de gebruiker bevestigt of corrigeert.
public enum DocumentHerkenner {
    // MARK: WOZ-beschikking

    public struct WOZ: Equatable, Sendable {
        public var waarde: Double?
        public var peildatum: Dag?
    }

    static let wozWoorden = ["woz-waarde", "woz waarde", "vastgestelde waarde", "waarde van de onroerende zaak", "waarde onroerende zaak"]

    public static func woz(_ tekst: String) -> WOZ {
        let regels = regelsVan(tekst)
        var r = WOZ()
        for (i, regel) in regels.enumerated() where r.waarde == nil {
            let klein = regel.lowercased()
            guard wozWoorden.contains(where: klein.contains), !klein.contains("peildatum") else { continue }
            for kandidaat in [regel] + regels[(i + 1)..<min(i + 3, regels.count)] {
                if let b = grootBedrag(in: kandidaat), (10_000...10_000_000).contains(b) { r.waarde = b; break }
            }
        }
        for (i, regel) in regels.enumerated() where r.peildatum == nil {
            guard regel.lowercased().contains("peildatum") else { continue }
            r.peildatum = ContractHerkenner.datum(in: regel) ?? (i + 1 < regels.count ? ContractHerkenner.datum(in: regels[i + 1]) : nil)
        }
        return r
    }

    /// Bedrag zonder centen zoals op een WOZ-beschikking: "€ 312.000", "312.000 euro", "€312000".
    static func grootBedrag(in tekst: String) -> Double? {
        let patroon = #"(?:€|eur(?:o)?)\s*([0-9]{1,3}(?:[.\s][0-9]{3})+|[0-9]{4,8})|([0-9]{1,3}(?:\.[0-9]{3})+)\s*(?:euro|eur)"#
        guard let re = try? NSRegularExpression(pattern: patroon, options: [.caseInsensitive]),
              let m = re.firstMatch(in: tekst, range: NSRange(tekst.startIndex..., in: tekst)) else { return nil }
        let r = Range(m.range(at: 1), in: tekst) ?? Range(m.range(at: 2), in: tekst)
        guard let r else { return nil }
        return Double(tekst[r].replacingOccurrences(of: ".", with: "").replacingOccurrences(of: " ", with: ""))
    }

    // MARK: Energielabel

    public struct Label: Equatable, Sendable {
        public var label: Energielabel?
        public var opnamedatum: Dag?
    }

    static let labelWoorden = ["energieklasse", "energielabel", "labelklasse", "energie label"]
    static let opnameWoorden = ["opnamedatum", "datum van opname", "datum opname", "registratiedatum", "datum registratie"]

    public static func energielabel(_ tekst: String) -> Label {
        let regels = regelsVan(tekst)
        var r = Label()
        for (i, regel) in regels.enumerated() where r.label == nil {
            let klein = regel.lowercased()
            guard labelWoorden.contains(where: klein.contains) else { continue }
            r.label = labelKlasse(naWoord: regel) ?? (i + 1 < regels.count ? labelKlasse(alleen: regels[i + 1]) : nil)
        }
        for (i, regel) in regels.enumerated() where r.opnamedatum == nil {
            guard opnameWoorden.contains(where: regel.lowercased().contains) else { continue }
            r.opnamedatum = ContractHerkenner.datum(in: regel) ?? (i + 1 < regels.count ? ContractHerkenner.datum(in: regels[i + 1]) : nil)
        }
        return r
    }

    /// "Energieklasse: A++" → A++. Kijkt alleen naar wat ná het woord komt.
    static func labelKlasse(naWoord regel: String) -> Energielabel? {
        let klein = regel.lowercased()
        guard let woord = labelWoorden.compactMap({ klein.range(of: $0) }).first else { return nil }
        let rest = String(regel[woord.upperBound...])
        return labelKlasse(alleen: rest)
    }

    /// Eerste losse labelklasse in de tekst: A++++ t/m G.
    static func labelKlasse(alleen tekst: String) -> Energielabel? {
        let patroon = #"(?<![A-Za-z])(A\s?\+{1,4}|[A-G])(?![A-Za-z])"#
        guard let re = try? NSRegularExpression(pattern: patroon),
              let m = re.firstMatch(in: tekst, range: NSRange(tekst.startIndex..., in: tekst)),
              let r = Range(m.range(at: 1), in: tekst) else { return nil }
        return Energielabel(rawValue: tekst[r].replacingOccurrences(of: " ", with: ""))
    }

    static func regelsVan(_ tekst: String) -> [String] {
        tekst.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}

extension ContractHerkenner {
    /// Woorden die aangeven dat het adres van het gehuurde volgt (niet dat van de verhuurder).
    static let gehuurdeWoorden = ["het gehuurde", "gehuurde", "woonruimte", "gelegen aan", "gelegen te", "adres van de woning", "object"]

    /// Postcode en huisnummer van het gehuurde. Alleen als er een woord als "het gehuurde" vlak voor staat,
    /// zodat het adres van de verhuurder niet wordt overgenomen.
    static func adres(in regels: [String]) -> (postcode: String, huisnummer: String)? {
        guard let pcRe = try? NSRegularExpression(pattern: #"\b([1-9][0-9]{3})\s?([A-Z]{2})\b"#),
              let hnRe = try? NSRegularExpression(pattern: #"\p{L}\s+([0-9]{1,5}(?:\s?[A-Za-z]{1,2}\b)?(?:-[0-9A-Za-z]{1,4})?)"#) else { return nil }
        for (i, regel) in regels.enumerated() {
            guard let m = pcRe.firstMatch(in: regel, range: NSRange(regel.startIndex..., in: regel)) else { continue }
            let context = regels[max(0, i - 2)...i].joined(separator: " ").lowercased()
            guard gehuurdeWoorden.contains(where: context.contains) else { continue }
            let pc = String(regel[Range(m.range(at: 1), in: regel)!]) + String(regel[Range(m.range(at: 2), in: regel)!])
            // Huisnummer: het laatste nummer na een woord, vóór de postcode op dezelfde regel of op de regel erboven.
            let voor = String(regel[..<Range(m.range, in: regel)!.lowerBound])
            for bron in [voor] + (i > 0 ? [regels[i - 1]] : []) {
                let treffers = hnRe.matches(in: bron, range: NSRange(bron.startIndex..., in: bron))
                if let t = treffers.last, let r = Range(t.range(at: 1), in: bron) {
                    return (pc, bron[r].trimmingCharacters(in: .whitespaces))
                }
            }
        }
        return nil
    }

    /// Voorschot servicekosten per maand.
    static func servicekosten(in regels: [String]) -> Double? {
        for (i, regel) in regels.enumerated() where regel.lowercased().contains("servicekosten") {
            if let b = bedrag(in: regel) ?? (i + 1 < regels.count ? bedrag(in: regels[i + 1]) : nil), (1...1_000).contains(b) {
                return b
            }
        }
        return nil
    }
}
