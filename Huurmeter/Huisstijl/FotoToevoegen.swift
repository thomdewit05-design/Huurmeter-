import SwiftUI
import PhotosUI
import UIKit

/// Staat aan zolang de camera over een scherm heen ligt; schermen die bij verdwijnen opruimen, slaan dat dan over.
@MainActor
enum CameraStatus {
    static var open = false
}

/// Foto toevoegen: zelf fotograferen met de camera of kiezen uit de bibliotheek. Levert verkleinde JPEG's
/// (max. 1600 px, kwaliteit 0,7) die alleen op het toestel worden bewaard.
struct FotoToevoegenKnop<Inhoud: View>: View {
    var maxAantal: Int = 1
    @ViewBuilder let label: () -> Inhoud
    let gekozen: ([Data]) -> Void

    @State private var toonCamera = false
    @State private var toonBibliotheek = false
    @State private var keuze: [PhotosPickerItem] = []

    private var cameraBeschikbaar: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    var body: some View {
        Menu {
            if cameraBeschikbaar {
                Button { CameraStatus.open = true; toonCamera = true } label: { Label("Foto maken", systemImage: "camera") }
            }
            Button { toonBibliotheek = true } label: { Label("Kies uit bibliotheek", systemImage: "photo.on.rectangle") }
        } label: {
            label()
        }
        .photosPicker(isPresented: $toonBibliotheek, selection: $keuze, maxSelectionCount: maxAantal, matching: .images)
        .fullScreenCover(isPresented: $toonCamera) {
            CameraKiezer { beeld in
                toonCamera = false
                CameraStatus.open = false
                if let beeld, let jpeg = Self.jpeg(beeld) { gekozen([jpeg]) }
            }
            .ignoresSafeArea()
        }
        .onChange(of: keuze) {
            let items = keuze
            guard !items.isEmpty else { return }
            Task {
                var lijst: [Data] = []
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let beeld = UIImage(data: data), let jpeg = Self.jpeg(beeld) {
                        lijst.append(jpeg)
                    }
                }
                keuze = []
                if !lijst.isEmpty { gekozen(lijst) }
            }
        }
    }

    static func jpeg(_ beeld: UIImage) -> Data? {
        beeld.verkleind(maximaleZijde: 1600).jpegData(compressionQuality: 0.7)
    }
}

/// De camera van het toestel (UIImagePickerController).
struct CameraKiezer: UIViewControllerRepresentable {
    let klaar: (UIImage?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(klaar: klaar) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let vc = UIImagePickerController()
        vc.sourceType = .camera
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let klaar: (UIImage?) -> Void
        init(klaar: @escaping (UIImage?) -> Void) { self.klaar = klaar }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            klaar(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { klaar(nil) }
    }
}
