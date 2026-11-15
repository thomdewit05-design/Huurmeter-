import Foundation

/// Postcode in de vorm "1234AB".
public struct Postcode: Hashable, Codable, Sendable, CustomStringConvertible {
    public let waarde: String

    /// Accepteert spaties en kleine letters ("1234 ab"). Postcodes beginnen niet met 0.
    public init?(_ invoer: String) {
        let s = invoer.uppercased().filter { !$0.isWhitespace }
        guard s.count == 6 else { return nil }
        let cijfers = s.prefix(4), letters = s.suffix(2)
        guard cijfers.allSatisfy(\.isASCII), cijfers.allSatisfy(\.isNumber), cijfers.first != "0",
              letters.allSatisfy({ $0.isASCII && $0.isLetter }) else { return nil }
        waarde = s
    }

    /// Weergave met spatie: "1234 AB".
    public var description: String { "\(waarde.prefix(4)) \(waarde.suffix(2))" }
}

/// Huisnummer met optionele huisletter en toevoeging, bijv. "12", "12A", "12-2", "12 bis".
public struct Huisnummer: Hashable, Codable, Sendable, CustomStringConvertible {
    public let nummer: Int
    public let letter: String?
    public let toevoeging: String?

    public init(nummer: Int, letter: String? = nil, toevoeging: String? = nil) {
        self.nummer = nummer; self.letter = letter; self.toevoeging = toevoeging
    }

    public init?(_ invoer: String) {
        let s = invoer.trimmingCharacters(in: .whitespaces)
        let cijfers = s.prefix { $0.isASCII && $0.isNumber }
        guard let n = Int(cijfers), n > 0, n <= 99999 else { return nil }
        var rest = s.dropFirst(cijfers.count).drop { $0 == " " }
        var letter: String? = nil
        if let eerste = rest.first, eerste.isLetter, eerste.isASCII,
           rest.dropFirst().first.map({ !$0.isLetter }) ?? true {
            letter = String(eerste).uppercased()
            rest = rest.dropFirst()
        }
        let toev = rest.trimmingCharacters(in: CharacterSet(charactersIn: " -"))
        guard toev.count <= 4 else { return nil }
        self.init(nummer: n, letter: letter, toevoeging: toev.isEmpty ? nil : toev.uppercased())
    }

    public var description: String {
        var s = "\(nummer)\(letter ?? "")"
        if let t = toevoeging { s += "-\(t)" }
        return s
    }
}

/// Adresgegevens zoals de app ze toont en opslaat. Alles is door de gebruiker aan te passen.
public struct AdresGegevens: Hashable, Codable, Sendable {
    public var postcode: String
    public var huisnummer: String
    public var straat: String
    public var plaats: String
    public var gemeente: String?
    public var bouwjaar: Int?
    /// BAG-identificatie van het verblijfsobject (alleen ter referentie in het dossier).
    public var verblijfsobjectId: String?

    public init(postcode: String, huisnummer: String, straat: String = "", plaats: String = "",
                gemeente: String? = nil, bouwjaar: Int? = nil, verblijfsobjectId: String? = nil) {
        self.postcode = postcode; self.huisnummer = huisnummer; self.straat = straat; self.plaats = plaats
        self.gemeente = gemeente; self.bouwjaar = bouwjaar; self.verblijfsobjectId = verblijfsobjectId
    }

    /// "Binnenhof 1, 2513 AB 's-Gravenhage"
    public var weergave: String {
        let pc = Postcode(postcode)?.description ?? postcode
        let regel1 = [straat, huisnummer].filter { !$0.isEmpty }.joined(separator: " ")
        let regel2 = [pc, plaats].filter { !$0.isEmpty }.joined(separator: " ")
        return [regel1, regel2].filter { !$0.isEmpty }.joined(separator: ", ")
    }
}
