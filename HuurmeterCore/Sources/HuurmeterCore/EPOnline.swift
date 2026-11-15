import Foundation
import WWSKit

/// Energielabel ophalen bij EP-Online (RVO), Public REST API v5:
/// `GET /api/v5/PandEnergielabel/Adres?postcode=&huisnummer=&huisletter=&huisnummertoevoeging=`,
/// API-sleutel in de Authorization-header. Gecontroleerd tegen de swagger-beschrijving op 15-11-2026.
public struct EPOnlineClient: Sendable {
    public static let basis = URL(string: "https://public.ep-online.nl/api/v5/PandEnergielabel/Adres")!

    public struct Label: Equatable, Sendable {
        public let label: Energielabel?
        public let energieIndex: Double?
        public let opnamedatum: Dag?
        public let registratiedatum: Dag?
        public let geldigTot: Dag?
        public let vereenvoudigd: Bool
    }

    public enum Fout: Error, Equatable, CustomStringConvertible {
        case geenSleutel, ongeldigAdres, geenLabel, sleutelGeweigerd, serverfout(Int), onverwachtAntwoord

        public var description: String {
            switch self {
            case .geenSleutel: return "Ophalen bij EP-Online is in deze versie niet beschikbaar."
            case .ongeldigAdres: return "Vul eerst een geldige postcode en huisnummer in (scherm Adres)."
            case .geenLabel: return "Er is voor dit adres geen energielabel geregistreerd. Dan telt het bouwjaar."
            case .sleutelGeweigerd: return "EP-Online weigert de aanvraag. Probeer het later opnieuw of vul het label zelf in."
            case .serverfout(let c): return "EP-Online is nu niet bereikbaar (fout \(c)). Vul het label zelf in."
            case .onverwachtAntwoord: return "Het antwoord van EP-Online kon niet worden gelezen. Vul het label zelf in."
            }
        }
    }

    let haler: HTTPHaler
    let sleutel: String?

    public init(sleutel: String?, haler: HTTPHaler = URLSessionHaler()) {
        self.sleutel = (sleutel?.isEmpty ?? true) ? nil : sleutel
        self.haler = haler
    }

    public var beschikbaar: Bool { sleutel != nil }

    public func haalLabel(postcode: String, huisnummer: String) async throws -> Label {
        guard let sleutel else { throw Fout.geenSleutel }
        guard let pc = Postcode(postcode), let hn = Huisnummer(huisnummer) else { throw Fout.ongeldigAdres }
        var c = URLComponents(url: Self.basis, resolvingAgainstBaseURL: false)!
        var q = [URLQueryItem(name: "postcode", value: pc.waarde), URLQueryItem(name: "huisnummer", value: String(hn.nummer))]
        if let l = hn.letter { q.append(URLQueryItem(name: "huisletter", value: l)) }
        if let t = hn.toevoeging { q.append(URLQueryItem(name: "huisnummertoevoeging", value: t)) }
        c.queryItems = q
        let (data, status) = try await haler.haal(c.url!, kopteksten: ["Authorization": sleutel])
        switch status {
        case 200: break
        case 404: throw Fout.geenLabel
        case 401, 403: throw Fout.sleutelGeweigerd
        default: throw Fout.serverfout(status)
        }
        let labels = try Self.lees(data)
        guard let nieuwste = labels.max(by: { ($0.registratiedatum ?? Dag(1900, 1, 1)) < ($1.registratiedatum ?? Dag(1900, 1, 1)) })
        else { throw Fout.geenLabel }
        return nieuwste
    }

    static func lees(_ data: Data) throws -> [Label] {
        struct Ruw: Decodable {
            let Registratiedatum: String?
            let Opnamedatum: String?
            let Geldig_tot: String?
            let Energieklasse: String?
            let EnergieIndex: Double?
            let IsVereenvoudigdLabel: Bool?
        }
        let ruw: [Ruw]
        do { ruw = try JSONDecoder().decode([Ruw].self, from: data) } catch { throw Fout.onverwachtAntwoord }
        func dag(_ s: String?) -> Dag? { s.flatMap { Dag(iso: String($0.prefix(10))) } }
        return ruw.map {
            let klasse = $0.Energieklasse?.replacingOccurrences(of: " ", with: "").uppercased()
            return Label(label: klasse.flatMap(Energielabel.init(rawValue:)), energieIndex: $0.EnergieIndex,
                         opnamedatum: dag($0.Opnamedatum), registratiedatum: dag($0.Registratiedatum),
                         geldigTot: dag($0.Geldig_tot), vereenvoudigd: $0.IsVereenvoudigdLabel ?? false)
        }
    }
}
