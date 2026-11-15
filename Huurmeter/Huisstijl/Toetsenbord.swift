import SwiftUI
import UIKit

/// Toetsenbord wegtikken in de hele app: een tik buiten een invoerveld sluit het toetsenbord.
/// Het numerieke toetsenbord heeft geen eigen "Klaar"-toets, dus dit is nodig om het weg te krijgen.
@MainActor
final class ToetsenbordSluiter: NSObject, UIGestureRecognizerDelegate {
    static let gedeeld = ToetsenbordSluiter()
    private var vensters = Set<ObjectIdentifier>()

    func installeer() {
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            for venster in scene.windows where !vensters.contains(ObjectIdentifier(venster)) {
                let tik = UITapGestureRecognizer(target: self, action: #selector(getikt(_:)))
                tik.cancelsTouchesInView = false   // knoppen en schakelaars blijven gewoon werken
                tik.delegate = self
                venster.addGestureRecognizer(tik)
                vensters.insert(ObjectIdentifier(venster))
            }
        }
    }

    @objc private func getikt(_ tik: UITapGestureRecognizer) {
        tik.view?.endEditing(true)
    }

    /// Een tik op een (ander) invoerveld telt niet, anders sluit het toetsenbord meteen weer.
    nonisolated func gestureRecognizer(_ g: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        MainActor.assumeIsolated {
            var v = touch.view
            while let huidig = v {
                if huidig is UITextField || huidig is UITextView { return false }
                v = huidig.superview
            }
            return true
        }
    }

    nonisolated func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith ander: UIGestureRecognizer) -> Bool {
        true
    }
}

extension View {
    /// "Klaar"-knop boven het toetsenbord en het toetsenbord wegvegen bij scrollen.
    func toetsenbordKlaar() -> some View {
        scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Klaar") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .fontWeight(.semibold)
                }
            }
    }
}
