import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Haalt data op via HTTP. Eigen protocol zodat tests vaste antwoorden kunnen gebruiken.
public protocol HTTPHaler: Sendable {
    func haal(_ url: URL) async throws -> (Data, Int)
}

public struct URLSessionHaler: HTTPHaler {
    public init() {}

    public func haal(_ url: URL) async throws -> (Data, Int) {
        var verzoek = URLRequest(url: url, timeoutInterval: 15)
        verzoek.setValue("application/json", forHTTPHeaderField: "Accept")
        return try await withCheckedThrowingContinuation { cont in
            URLSession.shared.dataTask(with: verzoek) { data, response, error in
                if let error { cont.resume(throwing: error); return }
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                cont.resume(returning: (data ?? Data(), status))
            }.resume()
        }
    }
}

public enum PDOKFout: Error, Equatable, CustomStringConvertible {
    case ongeldigePostcode
    case ongeldigHuisnummer
    case adresNietGevonden
    case serverfout(Int)
    case onverwachtAntwoord

    public var description: String {
        switch self {
        case .ongeldigePostcode: return "Vul een geldige postcode in, bijvoorbeeld 1234 AB."
        case .ongeldigHuisnummer: return "Vul een geldig huisnummer in, bijvoorbeeld 12 of 12A."
        case .adresNietGevonden: return "Dit adres is niet gevonden. Controleer postcode en huisnummer, of vul het adres zelf in."
        case .serverfout(let c): return "De adresgegevens zijn nu niet op te halen (fout \(c)). Vul het adres zelf in."
        case .onverwachtAntwoord: return "De adresgegevens konden niet worden gelezen. Vul het adres zelf in."
        }
    }
}

/// Gratis openbare diensten van PDOK (Kadaster):
/// - Locatieserver v3.1 (`/bzk/locatieserver/search/v3_1/free`) voor straat, plaats en het BAG-verblijfsobject;
/// - BAG OGC API v2 (`/kadaster/bag/ogc/v2`) voor het pand en het bouwjaar.
/// Gecontroleerd op 15-11-2026 tegen de live API's.
public struct PDOKClient: Sendable {
    public static let locatieserver = URL(string: "https://api.pdok.nl/bzk/locatieserver/search/v3_1/free")!
    public static let bag = URL(string: "https://api.pdok.nl/kadaster/bag/ogc/v2")!

    let haler: HTTPHaler

    public init(haler: HTTPHaler = URLSessionHaler()) { self.haler = haler }

    /// Zoekt het adres en daarna het bouwjaar. Een mislukte bouwjaar-opvraging is geen fout:
    /// dan blijft het bouwjaar leeg en vult de gebruiker het zelf in.
    public func vulAan(postcode invoerPostcode: String, huisnummer invoerHuisnummer: String) async throws -> AdresGegevens {
        guard let pc = Postcode(invoerPostcode) else { throw PDOKFout.ongeldigePostcode }
        guard let hn = Huisnummer(invoerHuisnummer) else { throw PDOKFout.ongeldigHuisnummer }
        var adres = try await zoekAdres(postcode: pc, huisnummer: hn)
        if let id = adres.verblijfsobjectId {
            adres.bouwjaar = try? await bouwjaar(verblijfsobjectId: id)
        }
        return adres
    }

    public func zoekAdres(postcode: Postcode, huisnummer: Huisnummer) async throws -> AdresGegevens {
        var c = URLComponents(url: Self.locatieserver, resolvingAgainstBaseURL: false)!
        c.queryItems = [
            URLQueryItem(name: "q", value: "postcode:\(postcode.waarde) and huisnummer:\(huisnummer.nummer)"),
            URLQueryItem(name: "fq", value: "type:adres"),
            URLQueryItem(name: "rows", value: "50"),
        ]
        let (data, status) = try await haler.haal(c.url!)
        guard status == 200 else { throw PDOKFout.serverfout(status) }
        let docs = try Self.leesLocatieserver(data)
        guard let doc = Self.kies(docs, huisnummer: huisnummer) else { throw PDOKFout.adresNietGevonden }
        return AdresGegevens(postcode: doc.postcode ?? postcode.waarde, huisnummer: huisnummer.description,
                             straat: doc.straatnaam ?? "", plaats: doc.woonplaatsnaam ?? "",
                             gemeente: doc.gemeentenaam, bouwjaar: nil, verblijfsobjectId: doc.adresseerbaarobject_id)
    }

    /// Bouwjaar van het (oudste) pand waarin het verblijfsobject ligt.
    public func bouwjaar(verblijfsobjectId: String) async throws -> Int? {
        var c = URLComponents(url: Self.bag.appendingPathComponent("collections/verblijfsobject/items"), resolvingAgainstBaseURL: false)!
        c.queryItems = [URLQueryItem(name: "identificatie", value: verblijfsobjectId), URLQueryItem(name: "limit", value: "1")]
        let (data, status) = try await haler.haal(c.url!)
        guard status == 200 else { throw PDOKFout.serverfout(status) }
        let panden = try Self.leesPandLinks(data)
        var jaren: [Int] = []
        for link in panden.prefix(5) {
            guard let url = URL(string: link), url.host == Self.bag.host else { continue }
            let (pd, ps) = try await haler.haal(url)
            guard ps == 200 else { continue }
            if let j = try Self.leesBouwjaar(pd) { jaren.append(j) }
        }
        return jaren.min()
    }

    // MARK: Parsen (los te testen)

    struct LocatieDoc: Decodable {
        let postcode: String?
        let huisnummer: Int?
        let huisletter: String?
        let huisnummertoevoeging: String?
        let straatnaam: String?
        let woonplaatsnaam: String?
        let gemeentenaam: String?
        let adresseerbaarobject_id: String?
    }

    static func leesLocatieserver(_ data: Data) throws -> [LocatieDoc] {
        struct Antwoord: Decodable { struct R: Decodable { let docs: [LocatieDoc] }; let response: R }
        do { return try JSONDecoder().decode(Antwoord.self, from: data).response.docs }
        catch { throw PDOKFout.onverwachtAntwoord }
    }

    /// Kiest het document met precies de gevraagde huisletter en toevoeging.
    static func kies(_ docs: [LocatieDoc], huisnummer: Huisnummer) -> LocatieDoc? {
        func norm(_ s: String?) -> String { (s ?? "").uppercased().trimmingCharacters(in: .whitespaces) }
        return docs.first {
            $0.huisnummer == huisnummer.nummer
                && norm($0.huisletter) == norm(huisnummer.letter)
                && norm($0.huisnummertoevoeging) == norm(huisnummer.toevoeging)
        }
    }

    static func leesPandLinks(_ data: Data) throws -> [String] {
        struct Antwoord: Decodable {
            struct F: Decodable {
                struct P: Decodable {
                    let pand: [String]?
                    enum CodingKeys: String, CodingKey { case pand = "pand.href" }
                }
                let properties: P
            }
            let features: [F]
        }
        do { return try JSONDecoder().decode(Antwoord.self, from: data).features.first?.properties.pand ?? [] }
        catch { throw PDOKFout.onverwachtAntwoord }
    }

    static func leesBouwjaar(_ data: Data) throws -> Int? {
        struct Antwoord: Decodable { struct P: Decodable { let bouwjaar: Int? }; let properties: P }
        let jaar: Int?
        do { jaar = try JSONDecoder().decode(Antwoord.self, from: data).properties.bouwjaar }
        catch { throw PDOKFout.onverwachtAntwoord }
        // De BAG gebruikt soms 9999 voor een onbekend bouwjaar; alleen plausibele jaren overnemen.
        guard let j = jaar, (1000...2100).contains(j) else { return nil }
        return j
    }
}
