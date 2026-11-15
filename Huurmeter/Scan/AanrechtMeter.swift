import SwiftUI
import ARKit
import SceneKit
import HuurmeterCore

/// Aanrecht meten met de camera (ARKit). Tik op het begin en het eind van het blad; bij een hoekaanrecht
/// meet u ook het tweede deel. De lengte telt op zoals toelichting 5.1 voorschrijft.
struct AanrechtMeterView: View {
    @Environment(\.dismiss) private var dismiss
    let gebruik: (Double) -> Void

    @State private var delen: [Double] = []
    @State private var huidig: Double?
    @State private var wissen = 0

    static var beschikbaar: Bool { ARWorldTrackingConfiguration.isSupported }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ARMeetweergave(wissen: wissen) { afstand in
                    huidig = afstand
                }
                .ignoresSafeArea()

                Image(systemName: "plus")
                    .font(.title2.weight(.light))
                    .foregroundStyle(.white)
                    .shadow(radius: 2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)

                VStack(spacing: 12) {
                    Text(uitleg).font(.subheadline).multilineTextAlignment(.center)
                    if let h = huidig {
                        Text("Dit deel: \(Opmaak.getal(h, decimalen: 2)) m").font(.headline)
                    }
                    if !delen.isEmpty {
                        Text("Totaal: \(Opmaak.getal(Geometrie.aanrechtLengte(delen + [huidig ?? 0]), decimalen: 2)) m")
                            .font(.title3.weight(.heavy)).foregroundStyle(Huisstijl.bosgroen)
                    }
                    HStack {
                        Button("Hoekdeel toevoegen") {
                            if let h = huidig { delen.append(h); huidig = nil; wissen += 1 }
                        }
                        .disabled(huidig == nil)
                        Spacer()
                        Button("Gebruik") {
                            gebruik(Geometrie.aanrechtLengte(delen + [huidig ?? 0]))
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(huidig == nil && delen.isEmpty)
                    }
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                .padding()
            }
            .navigationTitle("Aanrecht meten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuleer") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button("Opnieuw") { huidig = nil; delen = []; wissen += 1 }
                }
            }
        }
    }

    private var uitleg: String {
        huidig == nil
            ? "Richt het kruisje op het begin van het aanrecht en tik. Tik daarna op het eind. Meet over het midden van het blad."
            : "Klopt het? Tik op Gebruik, of voeg bij een hoekaanrecht het tweede deel toe."
    }
}

/// ARKit-weergave: twee tikken leggen een begin- en eindpunt op het oppervlak vast.
private struct ARMeetweergave: UIViewRepresentable {
    /// Verhogen om de punten te wissen.
    let wissen: Int
    let gemeten: (Double) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(gemeten: gemeten) }

    func makeUIView(context: Context) -> ARSCNView {
        let v = ARSCNView(frame: .zero)
        v.automaticallyUpdatesLighting = true
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        v.session.run(config)
        v.addGestureRecognizer(UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tik(_:))))
        context.coordinator.weergave = v
        return v
    }

    func updateUIView(_ v: ARSCNView, context: Context) {
        if context.coordinator.wisTeller != wissen {
            context.coordinator.wisTeller = wissen
            context.coordinator.wis()
        }
    }

    static func dismantleUIView(_ v: ARSCNView, coordinator: Coordinator) { v.session.pause() }

    final class Coordinator: NSObject {
        let gemeten: (Double) -> Void
        weak var weergave: ARSCNView?
        var punten: [SCNVector3] = []
        var knopen: [SCNNode] = []
        var wisTeller = 0

        init(gemeten: @escaping (Double) -> Void) { self.gemeten = gemeten }

        @objc func tik(_ g: UITapGestureRecognizer) {
            guard let v = weergave else { return }
            let midden = CGPoint(x: v.bounds.midX, y: v.bounds.midY)
            guard let query = v.raycastQuery(from: midden, allowing: .estimatedPlane, alignment: .any),
                  let treffer = v.session.raycast(query).first else { return }
            let t = treffer.worldTransform.columns.3
            if punten.count == 2 { wis() }
            let p = SCNVector3(t.x, t.y, t.z)
            punten.append(p)
            let bol = SCNNode(geometry: SCNSphere(radius: 0.006))
            bol.geometry?.firstMaterial?.diffuse.contents = UIColor(red: 0.776, green: 0.941, blue: 0.420, alpha: 1)
            bol.position = p
            v.scene.rootNode.addChildNode(bol)
            knopen.append(bol)
            if punten.count == 2 {
                let a = punten[0], b = punten[1]
                let afstand = Geometrie.afstand(Punt3(Double(a.x), Double(a.y), Double(a.z)),
                                                Punt3(Double(b.x), Double(b.y), Double(b.z)))
                let lijn = SCNNode(geometry: SCNGeometry(
                    sources: [SCNGeometrySource(vertices: [a, b])],
                    elements: [SCNGeometryElement(indices: [Int32(0), Int32(1)], primitiveType: .line)]))
                lijn.geometry?.firstMaterial?.diffuse.contents = UIColor.white
                v.scene.rootNode.addChildNode(lijn)
                knopen.append(lijn)
                DispatchQueue.main.async { self.gemeten(afstand) }
            }
        }

        func wis() {
            knopen.forEach { $0.removeFromParentNode() }
            knopen = []
            punten = []
        }
    }
}
