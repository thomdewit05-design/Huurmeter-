import SwiftUI
import SwiftData

@main
struct HuurmeterApp: App {
    var body: some Scene {
        WindowGroup {
            StartView()
        }
        .modelContainer(for: [Woning.self, Ruimte.self, Voorziening.self, Berekening.self])
    }
}
