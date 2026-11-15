import SwiftUI
import SwiftData

@main
struct HuurmeterApp: App {
    @State private var winkel = Winkel()

    var body: some Scene {
        WindowGroup {
            if DemoData.actief {
                StartView()
                    .environment(winkel)
                    .modelContainer(DemoData.container)
            } else {
                StartView()
                    .environment(winkel)
                    .modelContainer(for: [Woning.self, Ruimte.self, Voorziening.self, Berekening.self])
            }
        }
    }
}
