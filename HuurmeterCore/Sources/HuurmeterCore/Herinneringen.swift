import Foundation
import WWSKit

/// Een lokale melding die de app plant (geen server, alles op het toestel).
public struct Herinnering: Equatable, Sendable, Identifiable {
    public let id: String
    public let datum: Dag
    /// Uur van de dag waarop de melding komt (lokale tijd).
    public let uur: Int
    public let titel: String
    public let tekst: String
}

/// Plant herinneringen voor één woning:
/// - de termijn van zes maanden om de aanvangshuur te laten toetsen (twee weken en drie dagen vooraf);
/// - elk jaar op 1 mei: de jaarlijkse huurverhoging komt eraan (meestal per 1 juli; het voorstel moet
///   ten minste twee maanden vooraf komen, art. 7:252 BW).
public enum Herinneringen {
    public static let dagenVoorafTermijn = [14, 3]

    public static func plan(woningId: String, adres: String, termijn: Termijn?, vandaag: Dag) -> [Herinnering] {
        var lijst: [Herinnering] = []
        let wie = adres.isEmpty ? "uw woning" : adres
        if let t = termijn {
            for dagen in dagenVoorafTermijn {
                let datum = t.einddatum.plusDagen(-dagen)
                guard vandaag < datum else { continue }
                lijst.append(Herinnering(
                    id: "\(woningId).termijn.\(dagen)", datum: datum, uur: 10,
                    titel: "Nog \(dagen) dagen voor de aanvangshuur",
                    tekst: "Tot en met \(t.einddatum) kunt u de Huurcommissie vragen de huur van \(wie) te toetsen."))
            }
        }
        // Eerstvolgende 1 mei na vandaag.
        var mei = Dag(vandaag.jaar, 5, 1)
        if !(vandaag < mei) { mei = Dag(vandaag.jaar + 1, 5, 1) }
        lijst.append(Herinnering(
            id: "\(woningId).huurverhoging.\(mei.jaar)", datum: mei, uur: 10,
            titel: "Huurverhoging op komst",
            tekst: "Krijgt u een voorstel voor huurverhoging voor \(wie)? Controleer in Huurmeter of het mag."))
        return lijst.sorted { $0.datum < $1.datum }
    }
}
