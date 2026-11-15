import SwiftUI
import RoomPlan
import simd
import HuurmeterCore

/// Fase 3: één ruimte inmeten met RoomPlan (LiDAR). Spec §6: één scan per ruimte; de oppervlakte komt
/// uit de vloerpolygoon van `CapturedRoom`, niet uit de omhullende rechthoek.
enum Scanner {
    /// Zonder LiDAR toont de app de scanknop niet; er komt geen foutmelding (spec §3).
    static var beschikbaar: Bool { RoomCaptureSession.isSupported }
}

/// Het camerabeeld van RoomPlan met zijn eigen begeleiding.
struct RoomPlanScanner: UIViewRepresentable {
    /// Zet op true om de scan af te ronden; RoomPlan verwerkt dan de ruimte en roept `klaar` aan.
    var stoppen: Bool
    let klaar: (CapturedRoom?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(klaar: klaar) }

    func makeUIView(context: Context) -> RoomCaptureView {
        let view = RoomCaptureView(frame: .zero)
        view.delegate = context.coordinator
        view.captureSession.run(configuration: RoomCaptureSession.Configuration())
        return view
    }

    func updateUIView(_ view: RoomCaptureView, context: Context) {
        if stoppen && !context.coordinator.gestopt {
            context.coordinator.gestopt = true
            view.captureSession.stop()
        }
    }

    static func dismantleUIView(_ view: RoomCaptureView, coordinator: Coordinator) {
        if !coordinator.gestopt { view.captureSession.stop() }
    }

    final class Coordinator: NSObject, RoomCaptureViewDelegate {
        let klaar: (CapturedRoom?) -> Void
        var gestopt = false

        init(klaar: @escaping (CapturedRoom?) -> Void) {
            self.klaar = klaar
            super.init()
        }

        // RoomCaptureViewDelegate erft van NSCoding; de coordinator wordt nooit gearchiveerd.
        required init?(coder: NSCoder) { return nil }
        func encode(with coder: NSCoder) {}

        func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: Error?) -> Bool { true }

        func captureView(didPresent processedResult: CapturedRoom, error: Error?) {
            klaar(error == nil ? processedResult : nil)
        }
    }
}

// MARK: - Van CapturedRoom naar de plattegrond

extension ScanResultaat {
    /// Zet de RoomPlan-uitkomst om naar bovenaanzicht in meters. Nil als er geen vloer is herkend.
    init?(_ kamer: CapturedRoom) {
        let vloeren = kamer.floors
        guard !vloeren.isEmpty else { return nil }
        // Oppervlakte: som van alle herkende vloervlakken, elk uit zijn eigen polygoon.
        let oppervlakte = vloeren.map { Geometrie.oppervlakte(Self.lokaleHoeken($0)) }.reduce(0, +)
        guard oppervlakte > 0 else { return nil }
        let grootste = vloeren.max { Geometrie.oppervlakte(Self.lokaleHoeken($0)) < Geometrie.oppervlakte(Self.lokaleHoeken($1)) }!
        self.init(
            vloer: Self.lokaleHoeken(grootste).map { Geometrie.bovenaanzicht(Self.wereld($0, grootste.transform)) },
            muren: kamer.walls.map(Self.lijn),
            deuren: (kamer.doors + kamer.openings).map(Self.lijn),
            ramen: kamer.windows.map(Self.lijn),
            vloeroppervlakte: oppervlakte)
    }

    /// Hoekpunten van een vlak in zijn eigen assenstelsel. Zonder polygoon is het vlak een rechthoek
    /// met de afmetingen die RoomPlan zelf voor dat vlak geeft.
    static func lokaleHoeken(_ vlak: CapturedRoom.Surface) -> [Punt3] {
        if !vlak.polygonCorners.isEmpty {
            return vlak.polygonCorners.map { Punt3(Double($0.x), Double($0.y), Double($0.z)) }
        }
        let bx = Double(vlak.dimensions.x) / 2, by = Double(vlak.dimensions.y) / 2
        return [Punt3(-bx, -by, 0), Punt3(bx, -by, 0), Punt3(bx, by, 0), Punt3(-bx, by, 0)]
    }

    static func wereld(_ p: Punt3, _ t: simd_float4x4) -> Punt3 {
        let w = t * SIMD4<Float>(Float(p.x), Float(p.y), Float(p.z), 1)
        return Punt3(Double(w.x), Double(w.y), Double(w.z))
    }

    /// Een muur, deur of raam als lijnstuk: de breedte van het vlak langs zijn eigen x-as.
    static func lijn(_ vlak: CapturedRoom.Surface) -> Lijnstuk {
        let h = Double(vlak.dimensions.x) / 2
        return Lijnstuk(van: Geometrie.bovenaanzicht(wereld(Punt3(-h, 0, 0), vlak.transform)),
                        naar: Geometrie.bovenaanzicht(wereld(Punt3(h, 0, 0), vlak.transform)))
    }
}
