import SwiftUI
import ARKit
import SceneKit
import HuurmeterCore

/// Oppervlakte meten met de camera (ARKit, met LiDAR het nauwkeurigst): loop de rand van een tuin, balkon,
/// berging of gedeelde ruimte rond en tik elke hoek aan op de grond. De app rekent de oppervlakte in
/// bovenaanzicht uit (ook L-vormen). Werkt ook buiten, waar de kamerscan (RoomPlan) geen muren vindt.
struct OppervlakteMeterView: View {
    @Environment(\.dismiss) private var dismiss
    let titel: String
    let gebruik: (Double) -> Void

    @State private var hoeken = 0
    @State private var oppervlakte: Double = 0
    @State private var actie = MeetActie(soort: .geen, teller: 0)

    static var beschikbaar: Bool { ARWorldTrackingConfiguration.isSupported }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                HoekenMeetweergave(actie: actie) { aantal, m2 in
                    hoeken = aantal
                    oppervlakte = m2
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
                    if hoeken >= 3 {
                        Text(verbatim: Inmeting.weergave(oppervlakte))
                            .font(.title2.weight(.heavy)).monospacedDigit().foregroundStyle(Huisstijl.bosgroen)
                    }
                    HStack {
                        Button {
                            actie = MeetActie(soort: .laatsteWeg, teller: actie.teller + 1)
                        } label: {
                            Label("Laatste hoek weg", systemImage: "arrow.uturn.backward")
                        }
                        .disabled(hoeken == 0)
                        Spacer()
                        Button("Gebruik") {
                            gebruik(oppervlakte)
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(hoeken < 3 || oppervlakte <= 0)
                    }
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                .padding()
            }
            .navigationTitle(titel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuleer") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button("Opnieuw") { actie = MeetActie(soort: .alles, teller: actie.teller + 1) }
                }
            }
        }
    }

    private var uitleg: LocalizedStringKey {
        switch hoeken {
        case 0: return "Ga in een hoek staan, richt het kruisje op de grond in de hoek en tik."
        case 1, 2: return "Loop naar de volgende hoek en tik. Ga zo de hele rand rond."
        default: return "Tik nog meer hoeken aan als de vorm niet rechthoekig is. Klopt het? Tik op Gebruik."
        }
    }
}

struct MeetActie: Equatable {
    enum Soort { case geen, laatsteWeg, alles }
    let soort: Soort
    let teller: Int
}

/// ARKit-weergave: elke tik legt een hoekpunt op de grond; de punten worden met lijnen verbonden.
private struct HoekenMeetweergave: UIViewRepresentable {
    let actie: MeetActie
    let gewijzigd: (Int, Double) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(gewijzigd: gewijzigd) }

    func makeUIView(context: Context) -> ARSCNView {
        let v = ARSCNView(frame: .zero)
        v.automaticallyUpdatesLighting = true
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh   // LiDAR: nauwkeuriger raken van de grond
        }
        v.session.run(config)
        v.addGestureRecognizer(UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tik(_:))))
        context.coordinator.weergave = v
        return v
    }

    func updateUIView(_ v: ARSCNView, context: Context) {
        let c = context.coordinator
        guard c.actieTeller != actie.teller else { return }
        c.actieTeller = actie.teller
        switch actie.soort {
        case .laatsteWeg: if !c.punten.isEmpty { c.punten.removeLast() }
        case .alles: c.punten.removeAll()
        case .geen: break
        }
        c.teken()
    }

    static func dismantleUIView(_ v: ARSCNView, coordinator: Coordinator) { v.session.pause() }

    final class Coordinator: NSObject {
        let gewijzigd: (Int, Double) -> Void
        weak var weergave: ARSCNView?
        var punten: [SCNVector3] = []
        var knopen: [SCNNode] = []
        var actieTeller = 0
        private let limoen = UIColor(red: 0.776, green: 0.941, blue: 0.420, alpha: 1)

        init(gewijzigd: @escaping (Int, Double) -> Void) { self.gewijzigd = gewijzigd }

        @objc func tik(_ g: UITapGestureRecognizer) {
            guard let v = weergave else { return }
            let midden = CGPoint(x: v.bounds.midX, y: v.bounds.midY)
            let treffer = [ARRaycastQuery.TargetAlignment.horizontal, .any].lazy.compactMap { richting -> ARRaycastResult? in
                guard let q = v.raycastQuery(from: midden, allowing: .estimatedPlane, alignment: richting) else { return nil }
                return v.session.raycast(q).first
            }.first
            guard let treffer else { return }
            let t = treffer.worldTransform.columns.3
            punten.append(SCNVector3(t.x, t.y, t.z))
            teken()
        }

        func teken() {
            guard let v = weergave else { return }
            knopen.forEach { $0.removeFromParentNode() }
            knopen = []
            for p in punten {
                let bol = SCNNode(geometry: SCNSphere(radius: 0.02))
                bol.geometry?.firstMaterial?.diffuse.contents = limoen
                bol.position = p
                v.scene.rootNode.addChildNode(bol)
                knopen.append(bol)
            }
            if punten.count >= 2 {
                var paren = Array(zip(punten, punten.dropFirst()))
                if punten.count >= 3, let eerste = punten.first, let laatste = punten.last { paren.append((laatste, eerste)) }
                for (a, b) in paren {
                    let lijn = SCNNode(geometry: SCNGeometry(
                        sources: [SCNGeometrySource(vertices: [a, b])],
                        elements: [SCNGeometryElement(indices: [Int32(0), Int32(1)], primitiveType: .line)]))
                    lijn.geometry?.firstMaterial?.diffuse.contents = UIColor.white
                    v.scene.rootNode.addChildNode(lijn)
                    knopen.append(lijn)
                }
            }
            let m2 = Geometrie.grondOppervlakte(punten.map { Punt3(Double($0.x), Double($0.y), Double($0.z)) })
            let aantal = punten.count
            DispatchQueue.main.async { self.gewijzigd(aantal, m2) }
        }
    }
}

/// Kleine knop naast een m²-veld die de oppervlaktemeter opent.
struct MeetOppervlakteKnop: View {
    let titel: String
    let gebruik: (Double) -> Void
    @State private var toon = false

    var body: some View {
        if OppervlakteMeterView.beschikbaar {
            Button {
                toon = true
            } label: {
                Image(systemName: "camera.metering.spot")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Huisstijl.bosgroen)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(Text("Meet met de camera"))
            .fullScreenCover(isPresented: $toon) {
                OppervlakteMeterView(titel: titel, gebruik: gebruik)
            }
        }
    }
}
