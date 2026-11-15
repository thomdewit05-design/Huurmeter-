import SwiftUI
import RoomPlan
import HuurmeterCore
import WWSKit

/// De hele woning achter elkaar scannen: na elke kamer tikt de gebruiker op "Volgende kamer"; de camera
/// blijft doorlopen (RoomPlan, iOS 17). Aan het eind controleert de gebruiker namen en functies.
struct WoningScanView: View {
    @Environment(\.dismiss) private var dismiss
    let woning: Woning

    struct GescandeKamer: Identifiable {
        let id = UUID()
        let scan: ScanResultaat
        var naam: String
        var functie: RuimteFunctie
        /// Wat de camera in deze kamer herkende (apparaten, sanitair).
        var objecten: [GevondenObject] = []
    }

    @State private var kamers: [GescandeKamer] = []
    @State private var stopTeller = 0
    @State private var startTeller = 0
    @State private var laatsteStopIsKlaar = false
    @State private var controleren = false
    @State private var voorstellen: [Voorstel] = []

    var body: some View {
        NavigationStack {
            Group {
                if controleren {
                    controleLijst
                } else {
                    scanner
                }
            }
            .navigationTitle(controleren ? "Kamers controleren" : "Woning scannen" as LocalizedStringKey)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuleer") { dismiss() } }
            }
        }
    }

    private var scanner: some View {
        ZStack(alignment: .bottom) {
            MeerKamerScanner(stopTeller: stopTeller, startTeller: startTeller, pauzeerBijStop: laatsteStopIsKlaar) { kamer in
                if let kamer, let s = ScanResultaat(kamer) {
                    let label = kamer.sections.first.map { "\($0.label)" } ?? "unidentified"
                    kamers.append(GescandeKamer(scan: s, naam: "", functie: Kamerherkenning.functie(voorLabel: label),
                                                objecten: kamer.objects.map(VoorzieningScanView.object)))
                }
                if laatsteStopIsKlaar {
                    let namen = Kamerherkenning.namen(voor: kamers.map(\.functie))
                    for i in kamers.indices { kamers[i].naam = namen[i] }
                    werkVoorstellenBij()
                    controleren = true
                } else {
                    startTeller += 1
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 12) {
                Text(kamers.isEmpty
                     ? String(localized: "Begin in de eerste kamer. Richt de camera op de muren en loop langzaam rond.")
                     : String(localized: "Kamers gescand: \(kamers.count). Loop naar de volgende kamer."))
                    .font(.subheadline).multilineTextAlignment(.center)
                HStack {
                    Button("Volgende kamer") { laatsteStopIsKlaar = false; stopTeller += 1 }
                        .buttonStyle(.bordered)
                    Spacer()
                    Button("Klaar") { laatsteStopIsKlaar = true; stopTeller += 1 }
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
            .padding()
        }
    }

    private var controleLijst: some View {
        Form {
            Section {
                ForEach($kamers) { $k in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            TextField("Naam", text: $k.naam)
                            Text(Inmeting.weergave(k.scan.vloeroppervlakte)).monospacedDigit().foregroundStyle(Huisstijl.gedempt)
                        }
                        Picker("Functie", selection: $k.functie) {
                            ForEach(RuimteFunctie.allCases, id: \.self) { Text($0.naam.vertaald).tag($0) }
                        }
                        .onChange(of: k.functie) { werkVoorstellenBij() }
                    }
                }
                .onDelete { kamers.remove(atOffsets: $0); werkVoorstellenBij() }
            } footer: {
                Text("Controleer de namen en functies. Een schuin dak of verlaagd plafond geeft u daarna per kamer aan.")
            }
            if !voorstellen.isEmpty {
                Section {
                    Text("De camera heeft ook voorzieningen herkend. Controleer ze; ze worden ingevuld bij Voorzieningen.")
                        .font(.subheadline)
                } header: {
                    Text("Voorzieningen")
                }
                ForEach($voorstellen) { $v in VoorstelSectie(voorstel: $v) }
            }
            Section {
                Button("Kamers toevoegen") { voegToe() }
                    .disabled(kamers.isEmpty)
            }
        }
        .huisstijlAchtergrond()
    }

    /// Voorstellen opnieuw bepalen uit de kamers en hun functies (de keuze aan/uit blijft waar mogelijk staan).
    private func werkVoorstellenBij() {
        let oud = Dictionary(uniqueKeysWithValues: voorstellen.map { ($0.id, $0) })
        voorstellen = Objectherkenning.voorstellenVoorWoning(kamers.map { ($0.functie, $0.objecten) }).voorstellen.map { v in
            guard let o = oud[v.id] else { return v }
            var n = v
            n.overnemen = o.overnemen; n.gekozen = o.gekozen; n.waarde = o.waarde
            return n
        }
    }

    private func voegToe() {
        var volgorde = (woning.ruimten.map(\.volgorde).max() ?? 0) + 1
        for k in kamers {
            let r = Ruimte(naam: k.naam, functie: k.functie, volgorde: volgorde)
            volgorde += 1
            woning.ruimten.append(r)
            r.neemScanOver(k.scan, plattegrond: Plattegrond.png(k.scan, naam: k.naam))
        }
        for v in voorstellen where v.overnemen {
            woning.zetAntwoord(v.sleutel, v.waarde, rubriek: v.rubriek)
        }
        let badkamers = Objectherkenning.voorstellenVoorWoning(kamers.map { ($0.functie, $0.objecten) }).badkamers
        if badkamers > 0 && woning.antwoord("badkamers") < Double(badkamers) {
            woning.zetAntwoord("badkamers", Double(badkamers), rubriek: "6")
        }
        woning.geraakt()
        dismiss()
    }
}

/// RoomCaptureView die na een kamer kan doorlopen zonder de AR-sessie te stoppen.
private struct MeerKamerScanner: UIViewRepresentable {
    let stopTeller: Int
    let startTeller: Int
    let pauzeerBijStop: Bool
    let kamerKlaar: (CapturedRoom?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(kamerKlaar: kamerKlaar) }

    func makeUIView(context: Context) -> RoomCaptureView {
        let v = RoomCaptureView(frame: .zero)
        v.delegate = context.coordinator
        v.captureSession.run(configuration: RoomCaptureSession.Configuration())
        return v
    }

    func updateUIView(_ v: RoomCaptureView, context: Context) {
        let c = context.coordinator
        c.kamerKlaar = kamerKlaar
        if c.stops != stopTeller {
            c.stops = stopTeller
            v.captureSession.stop(pauseARSession: pauzeerBijStop)
        }
        if c.starts != startTeller {
            c.starts = startTeller
            v.captureSession.run(configuration: RoomCaptureSession.Configuration())
        }
    }

    static func dismantleUIView(_ v: RoomCaptureView, coordinator: Coordinator) { v.captureSession.stop() }

    @objc(HuurmeterMeerKamerCoordinator)
    final class Coordinator: NSObject, RoomCaptureViewDelegate {
        var kamerKlaar: (CapturedRoom?) -> Void
        var stops = 0
        var starts = 0

        init(kamerKlaar: @escaping (CapturedRoom?) -> Void) {
            self.kamerKlaar = kamerKlaar
            super.init()
        }

        required init?(coder: NSCoder) { return nil }
        func encode(with coder: NSCoder) {}

        func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: Error?) -> Bool { true }

        func captureView(didPresent processedResult: CapturedRoom, error: Error?) {
            kamerKlaar(error == nil ? processedResult : nil)
        }
    }
}
