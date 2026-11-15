import SwiftUI
import VisionKit
import Vision
import HuurmeterCore

/// Scant het huurcontract met de documentcamera en herkent de tekst op het toestel (Vision).
/// Er gaat niets naar een server; de foto's worden na het herkennen niet bewaard.
struct ContractScanner: UIViewControllerRepresentable {
    let klaar: (String?) -> Void

    static var beschikbaar: Bool { VNDocumentCameraViewController.isSupported }

    func makeCoordinator() -> Coordinator { Coordinator(klaar: klaar) }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: VNDocumentCameraViewController, context: Context) {}

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let klaar: (String?) -> Void
        init(klaar: @escaping (String?) -> Void) { self.klaar = klaar }

        func documentCameraViewController(_ vc: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            let paginas = (0..<scan.pageCount).map { scan.imageOfPage(at: $0) }
            DispatchQueue.global(qos: .userInitiated).async {
                let tekst = paginas.compactMap(Self.herkenTekst).joined(separator: "\n")
                DispatchQueue.main.async { self.klaar(tekst.isEmpty ? nil : tekst) }
            }
        }

        func documentCameraViewControllerDidCancel(_ vc: VNDocumentCameraViewController) { klaar(nil) }

        func documentCameraViewController(_ vc: VNDocumentCameraViewController, didFailWithError error: Error) { klaar(nil) }

        static func herkenTekst(_ beeld: UIImage) -> String? {
            guard let cg = beeld.cgImage else { return nil }
            let verzoek = VNRecognizeTextRequest()
            verzoek.recognitionLevel = .accurate
            verzoek.recognitionLanguages = ["nl-NL"]
            verzoek.usesLanguageCorrection = true
            try? VNImageRequestHandler(cgImage: cg).perform([verzoek])
            let regels = (verzoek.results ?? []).compactMap { $0.topCandidates(1).first?.string }
            return regels.isEmpty ? nil : regels.joined(separator: "\n")
        }
    }
}

/// Knop + bevestiging voor het huurscherm.
struct ContractScanKnop: View {
    let woning: Woning
    @State private var toonScanner = false
    @State private var voorstel: ContractHerkenner.Voorstel?
    @State private var nietsGevonden = false

    var body: some View {
        Button {
            toonScanner = true
        } label: {
            Label("Huurcontract scannen", systemImage: "doc.viewfinder")
        }
        .fullScreenCover(isPresented: $toonScanner) {
            ContractScanner { tekst in
                toonScanner = false
                guard let tekst else { return }
                let v = ContractHerkenner.herken(tekst)
                if v.kaleHuur == nil && v.ingangsdatum == nil { nietsGevonden = true } else { voorstel = v }
            }
            .ignoresSafeArea()
        }
        .alert("Niets herkend", isPresented: $nietsGevonden) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("De kale huur en de ingangsdatum zijn niet gevonden. Scan de pagina met de huurprijs, of vul ze zelf in.")
        }
        .alert("Gevonden in uw contract", isPresented: Binding(get: { voorstel != nil }, set: { if !$0 { voorstel = nil } })) {
            Button("Overnemen") { neemOver() }
            Button("Annuleer", role: .cancel) {}
        } message: {
            Text(samenvatting)
        }
    }

    private var samenvatting: String {
        guard let v = voorstel else { return "" }
        var r: [String] = []
        if let h = v.kaleHuur { r.append("Kale huur: \(Opmaak.euro(h)) per maand") }
        if let d = v.ingangsdatum { r.append("Ingangsdatum: \(d)") }
        r.append("Controleer of dit klopt.")
        return r.joined(separator: "\n")
    }

    private func neemOver() {
        guard let v = voorstel else { return }
        if let h = v.kaleHuur { woning.kaleHuur = h }
        if let d = v.ingangsdatum { woning.contractStart = d.datum() }
        woning.geraakt()
        voorstel = nil
    }
}
