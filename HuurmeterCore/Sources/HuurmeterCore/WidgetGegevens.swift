import Foundation
import WWSKit

/// Wat de app voor de widget klaarzet (in de gedeelde App Group-opslag). Klein en zonder persoonsgegevens
/// buiten het adres, dat de gebruiker zelf in de app zag.
public struct WidgetGegevens: Codable, Equatable, Sendable {
    public var adres: String
    public var punten: Int
    public var segment: String
    public var maximaleHuur: Double?
    public var teVeelPerMaand: Double?
    /// Laatste dag om de aanvangshuur te laten toetsen (resterende dagen rekent de widget zelf uit).
    public var termijnEinde: Dag?
    public var berekendOp: Dag

    public init(adres: String, punten: Int, segment: String, maximaleHuur: Double?, teVeelPerMaand: Double?,
                termijnEinde: Dag?, berekendOp: Dag) {
        self.adres = adres; self.punten = punten; self.segment = segment; self.maximaleHuur = maximaleHuur
        self.teVeelPerMaand = teVeelPerMaand; self.termijnEinde = termijnEinde; self.berekendOp = berekendOp
    }

    public init(adres: String, uitkomst u: Uitkomst) {
        self.init(adres: adres, punten: u.totaal, segment: Opmaak.segment(u.segment), maximaleHuur: u.maximaleHuur,
                  teVeelPerMaand: (u.verschilPerMaand ?? 0) > 0 ? u.verschilPerMaand : nil,
                  termijnEinde: u.termijnAanvangshuur?.einddatum, berekendOp: u.peildatum)
    }

    public static let appGroup = "group.nl.huurmeter.app"
    public static let sleutel = "widget.laatsteWoning"

    public func resterendeDagen(op dag: Dag) -> Int? {
        guard let e = termijnEinde, dag <= e else { return nil }
        return dag.dagen(tot: e)
    }

    public func bewaar(in opslag: UserDefaults) {
        if let data = try? JSONEncoder().encode(self) { opslag.set(data, forKey: Self.sleutel) }
    }

    public static func lees(uit opslag: UserDefaults) -> WidgetGegevens? {
        opslag.data(forKey: sleutel).flatMap { try? JSONDecoder().decode(WidgetGegevens.self, from: $0) }
    }
}
