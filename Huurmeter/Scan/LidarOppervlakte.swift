import SwiftUI
import ARKit
import SceneKit
import HuurmeterCore

/// Oppervlakte meten met een LiDAR-scan: beweeg de camera over de vloer of de grond (berging, tuin, balkon,
/// gedeelde ruimte). ARKit bouwt een 3D-net; de app telt alleen de horizontale vlakken op vloerhoogte
/// (Grondraster). Het gemeten deel kleurt groen in beeld.
struct LidarOppervlakteView: View {
    @Environment(\.dismiss) private var dismiss
    let titel: String
    let gebruik: (Double) -> Void

    @State private var oppervlakte: Double = 0
    @State private var opnieuw = 0

    static var beschikbaar: Bool { ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                LidarNetweergave(opnieuw: opnieuw) { m2 in
                    withAnimation(.huurmeter) { oppervlakte = m2 }
                }
                .ignoresSafeArea()

                VStack(spacing: 12) {
                    Text(oppervlakte < 0.5
                         ? "Richt de camera schuin naar beneden en beweeg langzaam over de hele vloer of grond."
                         : "Het groene deel is gemeten. Ga door tot alles groen is en tik dan op Gebruik." as LocalizedStringKey)
                        .font(.subheadline).multilineTextAlignment(.center)
                    Text(verbatim: Inmeting.weergave(oppervlakte))
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Huisstijl.bosgroen)
                        .contentTransition(.numericText(value: oppervlakte))
                    Button {
                        gebruik(oppervlakte)
                        dismiss()
                    } label: {
                        Text("Gebruik").fontWeight(.semibold).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(oppervlakte < 0.5)
                    Text("Wat op de vloer staat (meubels, planten) wordt niet gezien. Meet die plekken zo nodig na of tel ze erbij.")
                        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding()
            }
            .navigationTitle(titel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuleer") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button("Opnieuw") { opnieuw += 1; oppervlakte = 0 }
                }
            }
        }
    }
}

/// ARSCNView met scene reconstruction: toont het 3D-net en rekent periodiek de vloeroppervlakte uit.
private struct LidarNetweergave: UIViewRepresentable {
    let opnieuw: Int
    let bijgewerkt: (Double) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(bijgewerkt: bijgewerkt) }

    func makeUIView(context: Context) -> ARSCNView {
        let v = ARSCNView(frame: .zero)
        v.delegate = context.coordinator
        v.automaticallyUpdatesLighting = true
        context.coordinator.start(v, opnieuw: false)
        return v
    }

    func updateUIView(_ v: ARSCNView, context: Context) {
        if context.coordinator.opnieuwTeller != opnieuw {
            context.coordinator.opnieuwTeller = opnieuw
            context.coordinator.start(v, opnieuw: true)
        }
    }

    static func dismantleUIView(_ v: ARSCNView, coordinator: Coordinator) {
        coordinator.timer?.invalidate()
        v.session.pause()
    }

    final class Coordinator: NSObject, ARSCNViewDelegate {
        let bijgewerkt: (Double) -> Void
        var opnieuwTeller = 0
        var timer: Timer?
        private var netten: [UUID: ARMeshAnchor] = [:]
        private let slot = NSLock()
        private let rekenrij = DispatchQueue(label: "huurmeter.lidar", qos: .userInitiated)
        private var bezig = false
        private let limoen = UIColor(red: 0.776, green: 0.941, blue: 0.420, alpha: 0.45)

        init(bijgewerkt: @escaping (Double) -> Void) { self.bijgewerkt = bijgewerkt }

        func start(_ v: ARSCNView, opnieuw: Bool) {
            let config = ARWorldTrackingConfiguration()
            config.sceneReconstruction = .mesh
            config.planeDetection = [.horizontal]
            slot.lock(); netten.removeAll(); slot.unlock()
            v.session.run(config, options: opnieuw ? [.resetTracking, .removeExistingAnchors, .resetSceneReconstruction] : [])
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true) { [weak self] _ in self?.reken() }
        }

        // MARK: Weergave van het net

        func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
            guard let net = anchor as? ARMeshAnchor else { return nil }
            bewaar(net)
            let knoop = SCNNode(geometry: geometrie(net.geometry))
            return knoop
        }

        func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
            guard let net = anchor as? ARMeshAnchor else { return }
            bewaar(net)
            node.geometry = geometrie(net.geometry)
        }

        func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
            slot.lock(); netten[anchor.identifier] = nil; slot.unlock()
        }

        private func bewaar(_ net: ARMeshAnchor) {
            slot.lock(); netten[net.identifier] = net; slot.unlock()
        }

        private func geometrie(_ g: ARMeshGeometry) -> SCNGeometry {
            let v = g.vertices
            let bron = SCNGeometrySource(buffer: v.buffer, vertexFormat: v.format, semantic: .vertex,
                                         vertexCount: v.count, dataOffset: v.offset, dataStride: v.stride)
            let f = g.faces
            let data = Data(bytes: f.buffer.contents(), count: f.count * f.indexCountPerPrimitive * f.bytesPerIndex)
            let element = SCNGeometryElement(data: data, primitiveType: .triangles, primitiveCount: f.count,
                                             bytesPerIndex: f.bytesPerIndex)
            let geo = SCNGeometry(sources: [bron], elements: [element])
            let m = SCNMaterial()
            m.diffuse.contents = limoen
            m.isDoubleSided = true
            m.lightingModel = .constant
            geo.materials = [m]
            return geo
        }

        // MARK: Oppervlakte

        private func reken() {
            guard !bezig else { return }
            bezig = true
            slot.lock(); let momentopname = Array(netten.values); slot.unlock()
            rekenrij.async { [weak self] in
                guard let self else { return }
                let perNet = momentopname.map(Self.driehoeken)
                let alle = perNet.flatMap { $0 }
                var m2 = 0.0
                if let y = Grondraster.vloerHoogte(alle) {
                    m2 = Grondraster.oppervlakte(perNet.map { Grondraster.cellen($0, vloerHoogte: y) })
                }
                DispatchQueue.main.async {
                    self.bezig = false
                    self.bijgewerkt(m2)
                }
            }
        }

        /// Driehoeken van één net in wereldcoördinaten (meters).
        static func driehoeken(_ net: ARMeshAnchor) -> [Grondraster.Driehoek] {
            let g = net.geometry
            let v = g.vertices, f = g.faces
            guard f.indexCountPerPrimitive == 3 else { return [] }
            let t = net.transform
            let basis = v.buffer.contents()
            func punt(_ i: Int) -> Punt3 {
                let p = basis.advanced(by: v.offset + v.stride * i).assumingMemoryBound(to: (Float, Float, Float).self).pointee
                let w = t * SIMD4<Float>(p.0, p.1, p.2, 1)
                return Punt3(Double(w.x), Double(w.y), Double(w.z))
            }
            let indexen = f.buffer.contents()
            func index(_ n: Int) -> Int {
                f.bytesPerIndex == 4
                    ? Int(indexen.advanced(by: n * 4).assumingMemoryBound(to: UInt32.self).pointee)
                    : Int(indexen.advanced(by: n * 2).assumingMemoryBound(to: UInt16.self).pointee)
            }
            var uit: [Grondraster.Driehoek] = []
            uit.reserveCapacity(f.count)
            for k in 0..<f.count {
                uit.append((punt(index(k * 3)), punt(index(k * 3 + 1)), punt(index(k * 3 + 2))))
            }
            return uit
        }
    }
}
