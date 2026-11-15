import SwiftUI
import SwiftData
import HuurmeterCore
import WWSKit

/// De stappen van een woning: de invoerschermen 2 t/m 6 en de uitkomst (scherm 7).
enum WoningStap: Int, CaseIterable, Identifiable {
    case adres, huur, ruimtes, voorzieningen, energieWoz, uitkomst

    var id: Int { rawValue }

    /// De invoerstap uit HuurmeterCore (nil voor de uitkomst).
    var invoer: Stap? {
        switch self {
        case .adres: return .adres
        case .huur: return .huur
        case .ruimtes: return .ruimtes
        case .voorzieningen: return .voorzieningen
        case .energieWoz: return .energieWoz
        case .uitkomst: return nil
        }
    }

    var titel: String { invoer?.titel.vertaald ?? String(localized: "Uitkomst") }
    var icoon: String { invoer?.systeemIcoon ?? "chart.bar.doc.horizontal" }
}

/// Eén woning als stappenplan: kop met voortgang, het scherm van de huidige stap en Vorige/Volgende.
/// De hulpmiddelen en herinneringen staan onder "Meer".
struct WoningView: View {
    @Bindable var woning: Woning
    @State private var stap: WoningStap = .adres
    @State private var begonnen = false
    @State private var punten: Int?
    @State private var toonMeer = false

    var body: some View {
        Group { inhoud(stap) }
            .id(stap)
            .transition(.opacity)
            .safeAreaInset(edge: .top, spacing: 0) { kop }
            .safeAreaInset(edge: .bottom, spacing: 0) { navigatie }
            .navigationTitle(woning.titel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { toonMeer = true } label: { Label("Meer", systemImage: "ellipsis.circle") }
                }
            }
            .sheet(isPresented: $toonMeer) {
                NavigationStack { WoningMeerView(woning: woning) }
            }
            .onAppear {
                guard !begonnen else { return }
                begonnen = true
                stap = beginstap()
                herbereken()
            }
            .onChange(of: woning.gewijzigd) { herbereken() }
    }

    /// De laatst geopende stap, anders de eerste stap die nog niet klaar is (alles klaar: de uitkomst).
    private func beginstap() -> WoningStap {
        if let n = woning.laatsteStap, let s = WoningStap(rawValue: n) { return s }
        let c = woning.concept
        return WoningStap.allCases.first { $0.invoer.map { $0.status(c) != .klaar } ?? true } ?? .uitkomst
    }

    private func ga(naar nieuw: WoningStap) {
        withAnimation(.easeInOut(duration: 0.2)) { stap = nieuw }
        woning.laatsteStap = nieuw.rawValue
    }

    private func herbereken() {
        if case .uitkomst(let u) = Rekenservice().bereken(woning.concept, peildatum: Dag(Date())) {
            punten = u.totaal
        } else {
            punten = nil
        }
    }

    @ViewBuilder
    private func inhoud(_ s: WoningStap) -> some View {
        switch s {
        case .adres: AdresView(woning: woning)
        case .huur: HuurView(woning: woning)
        case .ruimtes: RuimtesView(woning: woning)
        case .voorzieningen: VoorzieningenView(woning: woning)
        case .energieWoz: EnergieWozView(woning: woning)
        case .uitkomst: UitkomstView(woning: woning)
        }
    }

    // MARK: Kop en navigatie

    private var kop: some View {
        let totaal = WoningStap.allCases.count
        let concept = woning.concept
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: stap.icoon)
                    .font(.headline)
                    .foregroundStyle(Huisstijl.opLimoen)
                    .frame(width: 38, height: 38)
                    .background(Huisstijl.limoen, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Stap \(stap.rawValue + 1) van \(totaal)")
                        .font(.caption.weight(.semibold)).foregroundStyle(Huisstijl.gedempt)
                    Menu {
                        ForEach(WoningStap.allCases) { s in
                            Button { ga(naar: s) } label: {
                                Label(s.titel, systemImage: s.invoer.map { $0.status(concept) == .klaar } == true ? "checkmark.circle.fill" : s.icoon)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(verbatim: stap.titel).font(.title3.weight(.bold)).foregroundStyle(Huisstijl.bosgroen)
                            Image(systemName: "chevron.down").font(.caption.weight(.bold)).foregroundStyle(Huisstijl.gedempt)
                        }
                    }
                    .accessibilityHint(Text("Kies een andere stap"))
                }
                Spacer(minLength: 8)
                if let punten {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(verbatim: "\(punten)").font(.title2.weight(.heavy)).monospacedDigit().foregroundStyle(Huisstijl.bosgroen)
                        Text("punten").font(.caption2.weight(.semibold)).foregroundStyle(Huisstijl.gedempt)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            // Voortgang: één segment per stap, groen als die stap klaar is, omrand voor de huidige stap.
            HStack(spacing: 4) {
                ForEach(WoningStap.allCases) { s in
                    let klaar = s.invoer.map { $0.status(concept) == .klaar } ?? (punten != nil)
                    Capsule()
                        .fill(klaar ? Huisstijl.bosgroen : Huisstijl.salie)
                        .overlay(Capsule().stroke(s == stap ? Huisstijl.bosgroen : .clear, lineWidth: 1.5))
                        .frame(height: 6)
                }
            }
            .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Huisstijl.kaart)
        .overlay(alignment: .bottom) { Divider() }
    }

    private var navigatie: some View {
        HStack(spacing: 12) {
            if let vorige = WoningStap(rawValue: stap.rawValue - 1) {
                Button { ga(naar: vorige) } label: {
                    Label("Vorige", systemImage: "chevron.left").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            if let volgende = WoningStap(rawValue: stap.rawValue + 1) {
                Button { ga(naar: volgende) } label: {
                    HStack(spacing: 6) {
                        Text(volgende == .uitkomst ? "Bekijk uitkomst" : "Volgende")
                        Image(systemName: "chevron.right")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                Button { toonMeer = true } label: {
                    Label("Meer controleren", systemImage: "square.grid.2x2").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Huisstijl.kaart)
        .overlay(alignment: .top) { Divider() }
    }
}

/// Hulpmiddelen en herinneringen voor één woning (onder "Meer").
struct WoningMeerView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var woning: Woning
    @State private var meldingTekst: String?

    private var herinneringen: Binding<Bool> {
        Binding(get: { woning.herinneringenAan }, set: { aan in
            Task { @MainActor in
                let toegestaan = aan ? await Meldingen.vraagToestemming() : true
                if !toegestaan {
                    meldingTekst = String(localized: "Meldingen staan uit voor Huurmeter. Zet ze aan in Instellingen › Huurmeter › Meldingen.")
                    woning.herinneringenAan = false
                    return
                }
                meldingTekst = nil
                woning.herinneringenAan = aan
                await Meldingen.plan(voor: woning)
            }
        })
    }

    var body: some View {
        List {
            Section("Meer controleren") {
                NavigationLink { HuurverhogingView(woning: woning) } label: {
                    Label("Huurverhoging", systemImage: "arrow.up.right.circle")
                }
                NavigationLink { StappenplanView(woning: woning) } label: {
                    Label("Naar de Huurcommissie", systemImage: "list.number")
                }
                NavigationLink { GebrekenView(woning: woning) } label: {
                    Label("Gebreken", systemImage: "wrench.and.screwdriver")
                }
                .badge(woning.gebreken.filter(\.open).count)
                NavigationLink { ServicekostenView(woning: woning) } label: {
                    Label("Servicekosten", systemImage: "eurosign.circle")
                }
            }
            Section {
                Toggle(isOn: herinneringen) {
                    Label("Herinneringen", systemImage: "bell")
                }
            } footer: {
                Text(meldingTekst ?? String(localized: "Een melding twee weken en drie dagen voor het einde van de termijn voor de aanvangshuur, en elk jaar op 1 mei als de huurverhoging eraan komt."))
            }
        }
        .huisstijlAchtergrond()
        .navigationTitle(woning.titel)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("Sluit") { dismiss() } }
        }
    }
}
