import Foundation
import UserNotifications
import WWSKit
import HuurmeterCore

/// Plant de lokale herinneringen van een woning (geen server; alles op het toestel).
enum Meldingen {
    static func sleutel(_ w: Woning) -> String { "woning-\(Int(w.aangemaakt.timeIntervalSince1970))" }

    /// Vraagt toestemming (alleen de eerste keer zichtbaar voor de gebruiker). Geeft terug of meldingen mogen.
    static func vraagToestemming() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Vervangt alle geplande meldingen van deze woning door een nieuwe planning.
    @MainActor
    static func plan(voor w: Woning) async {
        let centrum = UNUserNotificationCenter.current()
        await verwijder(voor: w)
        guard w.herinneringenAan else { return }

        let vandaag = Dag(Date())
        var termijn: Termijn?
        if let start = w.contractStart {
            let regels = HuidigeRegels.regels
            let maanden = regels?.termijnen.toetsingAanvangshuurMaanden ?? 6
            let einde = Dag(start).plusMaanden(maanden)
            if vandaag <= einde { termijn = Termijn(einddatum: einde, resterendeDagen: vandaag.dagen(tot: einde)) }
        }
        for h in Herinneringen.plan(woningId: sleutel(w), adres: w.adres.weergave, termijn: termijn, vandaag: vandaag) {
            let inhoud = UNMutableNotificationContent()
            inhoud.title = h.titel
            inhoud.body = h.tekst
            inhoud.sound = .default
            var moment = DateComponents()
            moment.year = h.datum.jaar; moment.month = h.datum.maand; moment.day = h.datum.dag; moment.hour = h.uur
            let trigger = UNCalendarNotificationTrigger(dateMatching: moment, repeats: false)
            try? await centrum.add(UNNotificationRequest(identifier: h.id, content: inhoud, trigger: trigger))
        }
    }

    @MainActor
    static func verwijder(voor w: Woning) async {
        let centrum = UNUserNotificationCenter.current()
        let voorvoegsel = sleutel(w) + "."
        let ids = await centrum.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(voorvoegsel) }
        centrum.removePendingNotificationRequests(withIdentifiers: ids)
    }
}
