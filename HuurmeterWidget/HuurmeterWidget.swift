import WidgetKit
import SwiftUI
import WWSKit
import HuurmeterCore

/// Widget: puntentotaal, te veel per maand en de resterende dagen voor de aanvangshuur van de laatst
/// berekende woning. Gegevens komen uit de gedeelde App Group-opslag die de app vult.
@main
struct HuurmeterWidgetBundle: WidgetBundle {
    var body: some Widget { HuurmeterWidget() }
}

struct HuurmeterWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "HuurmeterWidget", provider: Leverancier()) { item in
            WidgetWeergave(item: item)
                .containerBackground(Huisstijl.salie, for: .widget)
        }
        .configurationDisplayName("Huurmeter")
        .description("Punten, te veel betaalde huur en de dagen die u nog hebt om de aanvangshuur te laten toetsen.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct Item: TimelineEntry {
    let date: Date
    let gegevens: WidgetGegevens?
}

struct Leverancier: TimelineProvider {
    func placeholder(in context: Context) -> Item {
        Item(date: Date(), gegevens: WidgetGegevens(adres: "Voorbeeldstraat 1", punten: 135, segment: "Sociale huur",
                                                   maximaleHuur: 877.97, teVeelPerMaand: 97.03,
                                                   termijnEinde: Dag(Date()).plusDagen(42), berekendOp: Dag(Date())))
    }

    func getSnapshot(in context: Context, completion: @escaping (Item) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : Item(date: Date(), gegevens: lees()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Item>) -> Void) {
        // Eén item per dag voor een week, zodat het aantal resterende dagen elke ochtend klopt.
        let gegevens = lees()
        let k = Calendar.current
        let start = k.startOfDay(for: Date())
        let items = (0..<7).compactMap { k.date(byAdding: .day, value: $0, to: start) }.map { Item(date: $0, gegevens: gegevens) }
        completion(Timeline(entries: [Item(date: Date(), gegevens: gegevens)] + items.dropFirst(), policy: .atEnd))
    }

    private func lees() -> WidgetGegevens? {
        UserDefaults(suiteName: WidgetGegevens.appGroup).flatMap(WidgetGegevens.lees)
    }
}

struct WidgetWeergave: View {
    @Environment(\.widgetFamily) private var familie
    let item: Item

    var body: some View {
        if let g = item.gegevens {
            let dagen = g.resterendeDagen(op: Dag(item.date))
            if familie == .systemMedium {
                HStack(alignment: .top, spacing: 16) {
                    punten(g)
                    Divider()
                    VStack(alignment: .leading, spacing: 6) {
                        if let teVeel = g.teVeelPerMaand {
                            Text("\(Opmaak.euro(teVeel)) per maand te veel")
                                .font(.subheadline.weight(.bold)).foregroundStyle(Huisstijl.signaal)
                        } else if let max = g.maximaleHuur {
                            Text("Maximaal \(Opmaak.euro(max))").font(.subheadline.weight(.bold))
                        }
                        if let dagen {
                            Text("Nog \(dagen) dagen om de aanvangshuur te laten toetsen")
                                .font(.caption).foregroundStyle(Huisstijl.gedempt)
                        }
                        Spacer(minLength: 0)
                        Text(g.adres).font(.caption2).foregroundStyle(Huisstijl.gedempt).lineLimit(1)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    punten(g)
                    Spacer(minLength: 0)
                    if let teVeel = g.teVeelPerMaand {
                        Text("\(Opmaak.euro(teVeel)) te veel").font(.caption.weight(.bold)).foregroundStyle(Huisstijl.signaal)
                    }
                    if let dagen { Text("Nog \(dagen) dagen").font(.caption2).foregroundStyle(Huisstijl.gedempt) }
                }
            }
        } else {
            VStack(spacing: 8) {
                Logo().frame(width: 44, height: 44)
                Text("Bereken uw huur in de app").font(.caption).multilineTextAlignment(.center)
            }
        }
    }

    private func punten(_ g: WidgetGegevens) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(g.punten)").font(.system(.largeTitle, design: .rounded, weight: .heavy)).foregroundStyle(Huisstijl.bosgroen)
            Text("punten").font(.caption).foregroundStyle(Huisstijl.gedempt)
            Text(g.segment).font(.caption2.weight(.bold)).foregroundStyle(Huisstijl.opLimoen)
                .padding(.horizontal, 6).padding(.vertical, 2).background(Huisstijl.limoen, in: Capsule())
        }
        .fontDesign(.rounded)
    }
}
