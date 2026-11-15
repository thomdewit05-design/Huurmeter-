import SwiftUI
import SwiftData
import WWSKit
import HuurmeterCore

/// Scherm 1: dashboard met de woningen, wat aandacht nodig heeft en de hulpmiddelen.
struct StartView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Woning.gewijzigd, order: .reverse) private var woningen: [Woning]
    @State private var pad: [Woning] = []
    @State private var toonInfo = false
    @State private var teVerwijderen: Woning?

    private var vandaag: Dag { Dag(Date()) }
    private var recentste: Woning? { woningen.first }

    var body: some View {
        NavigationStack(path: $pad) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    WelkomKaart(woningen: woningen, nieuweWoning: nieuweWoning)
                    AandachtBlok(woningen: woningen, vandaag: vandaag)
                    woningenBlok
                    HulpmiddelenBlok(woning: recentste, nieuweWoning: nieuweWoning)
                    voetnoot
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background(Huisstijl.salie.ignoresSafeArea())
            .navigationTitle("Huurmeter")
            .navigationBarTitleDisplayMode(.inline)
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
            .confirmationDialog("Woning verwijderen?", isPresented: Binding(get: { teVerwijderen != nil }, set: { if !$0 { teVerwijderen = nil } }),
                                titleVisibility: .visible) {
                Button("Verwijderen", role: .destructive) {
                    if let w = teVerwijderen { context.delete(w) }
                    teVerwijderen = nil
                }
            } message: {
                Text("Alle gegevens, foto's en berekeningen van deze woning worden van uw telefoon verwijderd.")
            }
        }
    }

    @ViewBuilder
    private var woningenBlok: some View {
        if !woningen.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                BlokKop(titel: "Uw woningen", icoon: "house")
                ForEach(woningen) { woning in
                    NavigationLink(value: woning) { WoningKaart(woning: woning) }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) { teVerwijderen = woning } label: {
                                Label("Verwijderen", systemImage: "trash")
                            }
                        }
                }
            }
        }
    }

    private var voetnoot: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Alles wat u invult blijft op uw telefoon.", systemImage: "lock.shield")
            Text(Uitkomst.disclaimer.vertaald)
        }
        .font(.footnote)
        .foregroundStyle(Huisstijl.gedempt)
        .padding(.top, 4)
    }

    private func nieuweWoning() {
        let w = Woning()
        context.insert(w)
        pad.append(w)
    }
}

// MARK: - Welkom

private struct WelkomKaart: View {
    @Environment(Winkel.self) private var winkel
    let woningen: [Woning]
    let nieuweWoning: () -> Void

    private var groet: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: return String(localized: "Goedemorgen")
        case 12..<18: return String(localized: "Goedemiddag")
        default: return String(localized: "Goedenavond")
        }
    }

    private var teVeel: Int { woningen.filter { WoningStatus(woning: $0) == .teVeel }.count }

    private var samenvatting: String {
        if woningen.isEmpty { return String(localized: "Reken in ongeveer tien minuten uit wat de maximale kale huur van uw woning is.") }
        if teVeel > 0 { return String(localized: "Bij \(teVeel) van uw woningen betaalt u waarschijnlijk te veel huur.") }
        return String(localized: "U volgt \(woningen.count) woningen. Hieronder ziet u wat aandacht nodig heeft.")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Logo(dak: Huisstijl.limoen, vinkje: .white, achtergrond: .white.opacity(0.12))
                    .frame(width: 52, height: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text(groet).font(.subheadline.weight(.semibold)).foregroundStyle(.white.opacity(0.8))
                    Text("Klopt uw huur?").font(.title.weight(.heavy)).foregroundStyle(.white)
                }
            }
            Text(samenvatting)
                .font(.body)
                .foregroundStyle(.white.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { knoppen }
                VStack(alignment: .leading, spacing: 10) { knoppen }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Color(licht: 0x17402E, donker: 0x17402E), Color(licht: 0x2A6B4C, donker: 0x1F5239)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
        .overlay(alignment: .topTrailing) {
            Circle().fill(Huisstijl.limoen.opacity(0.18)).frame(width: 140, height: 140)
                .offset(x: 40, y: -50).clipped().allowsHitTesting(false).accessibilityHidden(true)
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .padding(.top, 8)
    }

    @ViewBuilder
    private var knoppen: some View {
        Button(action: nieuweWoning) {
            Label("Nieuwe woning", systemImage: "plus")
                .font(.headline)
                .foregroundStyle(Color(licht: 0x17402E, donker: 0x17402E))
                .padding(.horizontal, 18).padding(.vertical, 12)
                .background(Color(licht: 0xC6F06B, donker: 0xC6F06B), in: Capsule())
        }
        NavigationLink { KamerView() } label: {
            Label("Ik huur een kamer", systemImage: "door.left.hand.open")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 18).padding(.vertical, 12)
                .overlay(Capsule().stroke(.white.opacity(0.6), lineWidth: 1.5))
        }
    }
}

// MARK: - Aandacht nodig

private struct AandachtBlok: View {
    let woningen: [Woning]
    let vandaag: Dag
    private let plannen = try? Stappenplannen.laad()

    private struct Punt: Identifiable {
        let id: String
        let icoon: String
        let titel: String
        let tekst: String
        let dagen: Int?
        let kleur: Color
        let woning: Woning?
    }

    private var punten: [Punt] {
        var lijst: [Punt] = []
        // Termijn om de aanvangshuur te laten toetsen (BW 7:249).
        if let p = plannen?.procedure("aanvangshuur") {
            for w in woningen {
                guard let start = w.contractStart else { continue }
                let t = p.termijnen(anker: Dag(start), vandaag: vandaag)
                guard !t.verlopen else { continue }
                lijst.append(Punt(id: "termijn-\(w.persistentModelID.hashValue)", icoon: "hourglass",
                                  titel: String(localized: "Aanvangshuur laten toetsen"),
                                  tekst: String(localized: "\(w.titel): kan tot en met \(t.uiterlijk.description), als dit uw eerste contract voor deze woning is."),
                                  dagen: t.dagenOver, kleur: t.dagenOver <= 30 ? Huisstijl.signaal : Huisstijl.bosgroen, woning: w))
            }
        }
        // Open gebreken.
        let open = woningen.flatMap { w in w.gebreken.filter(\.open).map { (w, $0) } }
        if !open.isEmpty {
            let gemeld = open.filter { $0.1.gemeld != nil }.count
            lijst.append(Punt(id: "gebreken", icoon: "wrench.and.screwdriver",
                              titel: String(localized: "Open gebreken: \(open.count)"),
                              tekst: gemeld == open.count ? String(localized: "Alle gebreken zijn gemeld bij de verhuurder.")
                                                          : String(localized: "Niet gemeld bij de verhuurder: \(open.count - gemeld). Meld ze schriftelijk; dan gaan de termijnen lopen."),
                              dagen: nil, kleur: Huisstijl.signaal, woning: open.first?.0))
        }
        // Seizoen van de jaarlijkse huurverhoging (voorstellen komen in het voorjaar, verhoging per 1 juli).
        if (4...7).contains(vandaag.maand), let w = woningen.first {
            lijst.append(Punt(id: "verhoging", icoon: "arrow.up.right.circle",
                              titel: String(localized: "Huurverhoging gekregen?"),
                              tekst: String(localized: "Controleer of het voorstel binnen het maximum blijft. Bezwaar maakt u vóór de ingangsdatum."),
                              dagen: nil, kleur: Huisstijl.bosgroen, woning: w))
        }
        return lijst
    }

    var body: some View {
        if !punten.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                BlokKop(titel: "Aandacht nodig", icoon: "bell.badge")
                ForEach(punten) { p in
                    Group {
                        if let w = p.woning {
                            NavigationLink { bestemming(p, w) } label: { rij(p) }
                        } else {
                            rij(p)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func bestemming(_ p: Punt, _ w: Woning) -> some View {
        switch p.id {
        case "gebreken": GebrekenView(woning: w)
        case "verhoging": HuurverhogingView(woning: w)
        default: StappenplanView(woning: w)
        }
    }

    private func rij(_ p: Punt) -> some View {
        HStack(alignment: .center, spacing: 14) {
            if let dagen = p.dagen {
                VStack(spacing: 0) {
                    Text(verbatim: "\(dagen)").font(.title2.weight(.heavy)).monospacedDigit().foregroundStyle(p.kleur)
                    Text(dagen == 1 ? "dag" : "dagen" as LocalizedStringKey).font(.caption2.weight(.semibold)).foregroundStyle(Huisstijl.gedempt)
                }
                .frame(width: 56, height: 56)
                .background(p.kleur.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                Image(systemName: p.icoon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(p.kleur)
                    .frame(width: 56, height: 56)
                    .background(p.kleur.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(p.titel).font(.headline).foregroundStyle(.primary)
                Text(p.tekst).font(.subheadline).foregroundStyle(Huisstijl.gedempt).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if p.woning != nil {
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
            }
        }
        .kaartStijl()
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Woningkaart

private enum WoningStatus: Equatable {
    case nietBerekend, vrijeSector, teVeel, binnenMaximum, geenHuur

    init(woning w: Woning) {
        guard let b = w.laatsteBerekening else { self = .nietBerekend; return }
        guard let max = b.maxHuur else { self = .vrijeSector; return }
        guard let huur = w.kaleHuur, huur > 0 else { self = .geenHuur; return }
        self = huur > max + 0.005 ? .teVeel : .binnenMaximum
    }
}

private struct WoningKaart: View {
    @Environment(Winkel.self) private var winkel
    let woning: Woning

    private var status: WoningStatus { WoningStatus(woning: woning) }
    private var klaar: Int {
        let c = woning.concept
        return Stap.allCases.filter { $0.status(c) == .klaar }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(woning.titel).font(.headline).foregroundStyle(.primary).lineLimit(2)
                    if !woning.plaats.isEmpty {
                        Text(woning.plaats).font(.subheadline).foregroundStyle(Huisstijl.gedempt)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
            }

            if let b = woning.laatsteBerekening {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(verbatim: "\(b.totaal)")
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .foregroundStyle(Huisstijl.bosgroen)
                    Text("punten").font(.subheadline.weight(.semibold)).foregroundStyle(Huisstijl.gedempt)
                    Spacer(minLength: 8)
                    statusPil(b)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Nog niet berekend").font(.subheadline.weight(.semibold)).foregroundStyle(Huisstijl.gedempt)
                        Spacer()
                        Text(verbatim: "\(klaar)/\(Stap.allCases.count)").font(.subheadline.weight(.bold)).monospacedDigit()
                            .foregroundStyle(Huisstijl.bosgroen)
                    }
                    ProgressView(value: Double(klaar), total: Double(Stap.allCases.count))
                        .tint(Huisstijl.bosgroen)
                        .accessibilityLabel(Text("Stappen ingevuld: \(klaar) van \(Stap.allCases.count)"))
                }
            }
        }
        .kaartStijl()
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func statusPil(_ b: Berekening) -> some View {
        switch status {
        case .teVeel:
            if winkel.ontgrendeld, let max = b.maxHuur, let huur = woning.kaleHuur {
                Pil(tekst: String(localized: "\(Opmaak.euro(huur - max)) p/m te veel"), voorgrond: Huisstijl.signaal, achtergrond: Huisstijl.signaalVlak)
            } else {
                Pil(tekst: String(localized: "Te veel huur"), voorgrond: Huisstijl.signaal, achtergrond: Huisstijl.signaalVlak)
            }
        case .binnenMaximum:
            Pil(tekst: String(localized: "Huur klopt"))
        case .vrijeSector:
            Pil(tekst: String(localized: "Vrije sector"), voorgrond: Huisstijl.gedempt, achtergrond: Huisstijl.salie)
        case .geenHuur:
            Pil(tekst: String(localized: "Huur invullen"), voorgrond: Huisstijl.gedempt, achtergrond: Huisstijl.salie)
        case .nietBerekend:
            EmptyView()
        }
    }
}

// MARK: - Hulpmiddelen

private struct HulpmiddelenBlok: View {
    let woning: Woning?
    let nieuweWoning: () -> Void

    private let kolommen = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            BlokKop(titel: "Hulpmiddelen", icoon: "square.grid.2x2")
            LazyVGrid(columns: kolommen, spacing: 12) {
                tegel("Huurverhoging checken", icoon: "arrow.up.right.circle", nodigWoning: true) { HuurverhogingView(woning: $0) }
                tegel("Servicekosten", icoon: "eurosign.circle", nodigWoning: true) { ServicekostenView(woning: $0) }
                tegel("Gebreken", icoon: "wrench.and.screwdriver", nodigWoning: true) { GebrekenView(woning: $0) }
                tegel("Naar de Huurcommissie", icoon: "list.number", nodigWoning: true) { StappenplanView(woning: $0) }
                NavigationLink { KamerView() } label: {
                    TegelInhoud(titel: "Kamer berekenen", icoon: "door.left.hand.open", ondertitel: nil)
                }
                .buttonStyle(.plain)
                NavigationLink { InfoView() } label: {
                    TegelInhoud(titel: "Uitleg en bronnen", icoon: "book", ondertitel: nil)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func tegel<V: View>(_ titel: LocalizedStringKey, icoon: String, nodigWoning: Bool,
                                @ViewBuilder bestemming: @escaping (Woning) -> V) -> some View {
        if let woning {
            NavigationLink { bestemming(woning) } label: {
                TegelInhoud(titel: titel, icoon: icoon, ondertitel: woning.titel)
            }
            .buttonStyle(.plain)
        } else {
            Button(action: nieuweWoning) {
                TegelInhoud(titel: titel, icoon: icoon, ondertitel: String(localized: "Voeg eerst een woning toe"))
            }
            .buttonStyle(.plain)
        }
    }
}

private struct TegelInhoud: View {
    let titel: LocalizedStringKey
    let icoon: String
    let ondertitel: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icoon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Huisstijl.opLimoen)
                .frame(width: 42, height: 42)
                .background(Huisstijl.limoen, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)
            Text(titel).font(.subheadline.weight(.bold)).foregroundStyle(.primary)
                .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
            if let ondertitel {
                Text(ondertitel).font(.caption).foregroundStyle(Huisstijl.gedempt).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .kaartStijl()
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Hulp

private struct BlokKop: View {
    let titel: LocalizedStringKey
    let icoon: String

    var body: some View {
        Label(titel, systemImage: icoon)
            .font(.title3.weight(.bold))
            .foregroundStyle(Huisstijl.bosgroen)
            .accessibilityAddTraits(.isHeader)
    }
}

private extension View {
    func kaartStijl() -> some View {
        padding(16)
            .background(Huisstijl.kaart, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
    }
}
