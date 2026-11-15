import SwiftUI
import SwiftData
import PDFKit
import WWSKit
import HuurmeterCore

/// Scherm 8 (betaald): PDF-dossier en conceptbrief, delen via de deelknop.
struct ActieView: View {
    @Environment(Winkel.self) private var winkel
    let woning: Woning
    let uitkomst: Uitkomst

    @State private var dossier: URL?
    @State private var toonDossier = false

    var body: some View {
        List {
            if winkel.ontgrendeld {
                ontgrendeldeInhoud
            } else {
                betaalmuur
            }
        }
        .navigationTitle("Dossier en brief")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Melding", isPresented: Binding(get: { winkel.melding != nil }, set: { if !$0 { winkel.melding = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(winkel.melding ?? "")
        }
        .sheet(isPresented: $toonDossier) {
            if let dossier { DossierVoorbeeld(url: dossier) }
        }
    }

    // MARK: Betaalmuur (spec §8: eenmalig, geen abonnement)

    @ViewBuilder
    private var betaalmuur: some View {
        Section {
            Label("PDF-dossier met puntentelling, plattegronden en foto's", systemImage: "doc.richtext")
            Label("Conceptbrief aan uw verhuurder", systemImage: "envelope")
            Label("Voor onbeperkt veel woningen", systemImage: "house.and.flag")
        } header: {
            Text("Wat u krijgt")
        } footer: {
            Text("Eenmalige aankoop. Geen abonnement en geen advertenties. Uw gegevens blijven op uw telefoon.")
        }
        Section {
            Button {
                Task { await winkel.koop() }
            } label: {
                HStack {
                    Text(winkel.product.map { "Koop voor \($0.displayPrice)" } ?? "Laden…")
                    if winkel.bezig { Spacer(); ProgressView() }
                }
            }
            .disabled(winkel.product == nil || winkel.bezig)
            Button("Eerdere aankoop herstellen") { Task { await winkel.herstel() } }
                .disabled(winkel.bezig)
        }
    }

    // MARK: Na aankoop

    @ViewBuilder
    private var ontgrendeldeInhoud: some View {
        Section {
            Button {
                maakDossier()
            } label: {
                Label("Dossier maken (PDF)", systemImage: "doc.richtext")
            }
        } footer: {
            Text("Met de puntentelling per rubriek, de ruimtes (gescand of handmatig), plattegronden, bewijsfoto's en bronnen.")
        }

        Section {
            switch briefTekst {
            case .success(let tekst):
                Text(tekst).font(.footnote).textSelection(.enabled)
                ShareLink(item: tekst, subject: Text("Kale huur"), preview: SharePreview("Conceptbrief")) {
                    Label("Brief delen of kopiëren", systemImage: "square.and.arrow.up")
                }
            case .failure(let fout):
                Text(fout.description).foregroundStyle(.secondary)
            }
        } header: {
            Text("Conceptbrief aan de verhuurder")
        } footer: {
            Text("Dit is een concept. Vul de gegevens tussen [haken] in en lees de brief goed na voordat u hem verstuurt. \(Uitkomst.disclaimer)")
        }
    }

    private var briefTekst: Result<String, Brief.Fout> {
        do {
            return .success(try Brief.tekst(concept: woning.concept, uitkomst: uitkomst, vandaag: Dag(Date())))
        } catch let f as Brief.Fout {
            return .failure(f)
        } catch {
            return .failure(.kaleHuurOntbreekt)
        }
    }

    private func maakDossier() {
        guard let regels = HuidigeRegels.regels else { return }
        let inhoud = DossierInhoud(concept: woning.concept, uitkomst: uitkomst, regels: regels)
        let plattegronden = woning.gesorteerdeRuimten.compactMap { r in
            r.plattegrond.map { DossierPDF.Bijlage(titel: r.naam, beeld: $0) }
        }
        let teksten = Dictionary(Vragenlijst.alleVragen(regels: regels).map { ($0.sleutel, $0.tekst) }, uniquingKeysWith: { a, _ in a })
        let fotos = woning.voorzieningen.sorted { $0.sleutel < $1.sleutel }.compactMap { v in
            v.foto.map { DossierPDF.Bijlage(titel: teksten[v.sleutel] ?? v.sleutel, beeld: $0) }
        }
        let data = DossierPDF.maak(inhoud, plattegronden: plattegronden, fotos: fotos)
        let naam = woning.adres.weergave.isEmpty ? "woning" : woning.adres.weergave
        let veilig = naam.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Huurmeter-dossier-\(veilig).pdf")
        do {
            try data.write(to: url, options: .atomic)
            dossier = url
            toonDossier = true
        } catch {
            winkel.melding = "Het dossier kon niet worden opgeslagen: \(error.localizedDescription)"
        }
    }
}

/// Voorbeeld van het dossier met PDFKit, met deelknop.
private struct DossierVoorbeeld: View {
    @Environment(\.dismiss) private var dismiss
    let url: URL

    var body: some View {
        NavigationStack {
            PDFWeergave(url: url)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Dossier")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Sluit") { dismiss() } }
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(item: url) { Label("Delen", systemImage: "square.and.arrow.up") }
                    }
                }
        }
    }
}

private struct PDFWeergave: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let v = PDFView()
        v.autoScales = true
        v.document = PDFDocument(url: url)
        return v
    }

    func updateUIView(_ v: PDFView, context: Context) {
        if v.document?.documentURL != url { v.document = PDFDocument(url: url) }
    }
}
