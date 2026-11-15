import SwiftUI
import SwiftData

@main
struct HuurmeterApp: App {
    @State private var winkel = Winkel()

    init() {
        #if DEBUG
        if VoorbeeldBestanden.gevraagd {
            Task { @MainActor in VoorbeeldBestanden.maak() }
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            if DemoData.actief {
                StartView()
                    .environment(winkel)
                    .modelContainer(DemoData.container)
                    .huisstijl()
            } else {
                StartView()
                    .environment(winkel)
                    .modelContainer(for: [Woning.self, Ruimte.self, Voorziening.self, Berekening.self, Gebrek.self])
                    .huisstijl()
            }
        }
    }
}

extension View {
    /// Huisstijl C: afgeronde systeemletter (schaalt mee met de tekstgrootte) en bosgroen als accent.
    func huisstijl() -> some View {
        fontDesign(.rounded).tint(Huisstijl.bosgroen)
            .onAppear { ToetsenbordSluiter.gedeeld.installeer() }
    }
}
