import Foundation
import StoreKit
import Observation

/// Eenmalige aankoop (StoreKit 2, niet-verbruikbaar) die de berekende maximale huur, het PDF-dossier en de
/// brief ontgrendelt voor onbeperkt veel woningen en kamers (spec §8). Geen abonnement, geen eigen server:
/// StoreKit controleert zelf. Gratis blijven: de puntentelling per rubriek en het oordeel (te veel of niet).
@MainActor
@Observable
final class Winkel {
    /// TODO (open punt Thom): product aanmaken in App Store Connect met dit ID, prijs € 9,99 (zie docs/PRIJS.md).
    /// Het ID blijft "dossier" zodat een al aangemaakt product blijft werken; de naam in de App Store is "Volledige uitkomst".
    static let productID = "nl.huurmeter.app.dossier"

    private(set) var product: Product?
    private(set) var ontgrendeld = false
    private(set) var bezig = false
    var melding: String?

    @ObservationIgnored private var luisteraar: Task<Void, Never>?

    init() {
        #if DEBUG
        // Alleen in ontwikkelbuilds, voor schermafbeeldingen en UI-tests: ontgrendeld zonder aankoop.
        if ProcessInfo.processInfo.arguments.contains("-demoOntgrendeld") {
            ontgrendeld = true
            return
        }
        #endif
        luisteraar = Task { [weak self] in
            for await resultaat in Transaction.updates {
                if case .verified(let transactie) = resultaat {
                    await transactie.finish()
                    await self?.controleerRechten()
                }
            }
        }
        Task { await laad() }
    }

    func laad() async {
        do {
            product = try await Product.products(for: [Self.productID]).first
        } catch {
            melding = "De App Store is nu niet bereikbaar. Probeer het later opnieuw."
        }
        await controleerRechten()
    }

    func controleerRechten() async {
        var gevonden = false
        for await resultaat in Transaction.currentEntitlements {
            if case .verified(let t) = resultaat, t.productID == Self.productID, t.revocationDate == nil {
                gevonden = true
            }
        }
        ontgrendeld = gevonden
    }

    func koop() async {
        guard let product else {
            melding = "Het product is nog niet geladen. Controleer uw internetverbinding."
            return
        }
        bezig = true
        defer { bezig = false }
        do {
            switch try await product.purchase() {
            case .success(let verificatie):
                if case .verified(let transactie) = verificatie {
                    await transactie.finish()
                    ontgrendeld = true
                } else {
                    melding = "De aankoop kon niet worden gecontroleerd."
                }
            case .pending:
                melding = "De aankoop wacht op goedkeuring."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            melding = "De aankoop is niet gelukt: \(error.localizedDescription)"
        }
    }

    func herstel() async {
        bezig = true
        defer { bezig = false }
        do {
            try await AppStore.sync()
        } catch {
            melding = "Herstellen is niet gelukt: \(error.localizedDescription)"
        }
        await controleerRechten()
        if !ontgrendeld && melding == nil { melding = "Er is geen eerdere aankoop gevonden voor dit Apple ID." }
    }
}
