#if DEBUG
import Foundation
import SwiftData
import WWSKit
import HuurmeterCore

/// Alleen in ontwikkelbuilds: maakt met de demowoning het PDF-dossier en de conceptbrief, precies zoals een
/// koper ze krijgt, en zet ze in de map Documenten van de app. Gestart met `-demo -maakVoorbeeld`
/// (workflow "Voorbeeldbestanden"). De plattegronden zijn rechthoeken met de oppervlakte van elke ruimte,
/// omdat de demowoning niet echt is gescand.
enum VoorbeeldBestanden {
    static var gevraagd: Bool { ProcessInfo.processInfo.arguments.contains("-maakVoorbeeld") }

    @MainActor
    static func maak() {
        let context = DemoData.container.mainContext
        guard let w = try? context.fetch(FetchDescriptor<Woning>()).first,
              let regels = HuidigeRegels.regels,
              case .uitkomst(let u) = Rekenservice().bereken(w.concept, peildatum: Dag(Date())) else {
            print("VOORBEELD-MISLUKT")
            return
        }
        var plattegronden: [DossierPDF.Bijlage] = []
        for r in w.gesorteerdeRuimten where r.oppervlakte > 0 {
            let breedte = (r.oppervlakte * 1.3).squareRoot()
            let diepte = r.oppervlakte / breedte
            let hoeken = [Punt2(0, 0), Punt2(breedte, 0), Punt2(breedte, diepte), Punt2(0, diepte)]
            let muren = zip(hoeken, hoeken.dropFirst() + [hoeken[0]]).map { Lijnstuk(van: $0, naar: $1) }
            let deur = Lijnstuk(van: Punt2(0.2, 0), naar: Punt2(1.0, 0))
            let scan = ScanResultaat(vloer: hoeken, muren: muren, deuren: [deur], vloeroppervlakte: r.oppervlakte)
            if let png = Plattegrond.png(scan, naam: r.naam) {
                plattegronden.append(DossierPDF.Bijlage(titel: r.naam, beeld: png))
            }
        }
        let pdf = DossierPDF.maak(DossierInhoud(concept: w.concept, uitkomst: u, regels: regels),
                                  plattegronden: plattegronden, fotos: [])
        let brief = (try? Brief.tekst(concept: w.concept, uitkomst: u, vandaag: Dag(Date()))) ?? "Brief niet te maken"
        let map = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        do {
            try pdf.write(to: map.appendingPathComponent("voorbeeld-dossier.pdf"))
            try brief.write(to: map.appendingPathComponent("voorbeeld-brief.txt"), atomically: true, encoding: .utf8)
            print("VOORBEELD-KLAAR")
        } catch {
            print("VOORBEELD-MISLUKT \(error)")
        }
    }
}
#endif
