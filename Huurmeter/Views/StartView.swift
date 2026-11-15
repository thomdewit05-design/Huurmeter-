import SwiftUI
import SwiftData
import HuurmeterCore

/// Scherm 1: opgeslagen woningen en "Nieuwe woning".
struct StartView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Woning.gewijzigd, order: .reverse) private var woningen: [Woning]
    @State private var pad: [Woning] = []
    @State private var toonInfo = false

    var body: some View {
        NavigationStack(path: $pad) {
            Group {
                if woningen.isEmpty {
                    ContentUnavailableView {
                        VStack(spacing: 16) {
                            Logo().frame(width: 96, height: 96)
                            Text("Klopt uw huur?").font(.title2.weight(.heavy)).foregroundStyle(Huisstijl.bosgroen)
                        }
                    } description: {
                        Text("Reken in ongeveer tien minuten uit wat de maximale kale huur van uw woning is.")
                    } actions: {
                        Button("Nieuwe woning", action: nieuweWoning)
                            .buttonStyle(.borderedProminent)
                        NavigationLink("Ik huur een kamer") { KamerView() }
                    }
                } else {
                    List {
                        ForEach(woningen) { woning in
                            NavigationLink(value: woning) { WoningRij(woning: woning) }
                        }
                        .onDelete(perform: verwijder)
                        Section {
                            NavigationLink { KamerView() } label: {
                                Label("Huurt u een kamer?", systemImage: "door.left.hand.open")
                            }
                        }
                    }
                }
            }
            .huisstijlAchtergrond()
            .navigationTitle("Huurmeter")
            .navigationDestination(for: Woning.self) { WoningView(woning: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { toonInfo = true } label: { Label("Info", systemImage: "info.circle") }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: nieuweWoning) { Label("Nieuwe woning", systemImage: "plus") }
                }
            }
            .sheet(isPresented: $toonInfo) { NavigationStack { InfoView() } }
        }
    }

    private func nieuweWoning() {
        let w = Woning()
        context.insert(w)
        pad.append(w)
    }

    private func verwijder(_ indexen: IndexSet) {
        for i in indexen { context.delete(woningen[i]) }
    }
}

private struct WoningRij: View {
    let woning: Woning

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(woning.titel).font(.headline)
            if let b = woning.laatsteBerekening {
                Text("\(b.totaal) punten" + (b.maxHuur.map { " · max. \(Opmaak.euro($0))" } ?? " · vrije sector"))
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                Text("Nog niet berekend").font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
