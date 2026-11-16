import SwiftUI
import UIKit
import Combine

/// Animaties en feedback in huisstijl: één veerbeweging voor de hele app, zodat alles hetzelfde aanvoelt.
extension Animation {
    /// Standaardbeweging: snel en rustig uitlopend.
    static let huurmeter = Animation.spring(response: 0.38, dampingFraction: 0.86)
    /// Voor kleine dingen zoals tegels en schakelaars.
    static let huurmeterKort = Animation.spring(response: 0.25, dampingFraction: 0.8)
}

/// Knoppen en kaarten die meegeven als je erop drukt.
struct IndrukStijl: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.huurmeterKort, value: configuration.isPressed)
    }
}

/// Verschijnt met een korte schuif- en vervaagbeweging; `volgorde` zorgt voor een trapsgewijze opbouw.
private struct Verschijn: ViewModifier {
    let volgorde: Int
    @State private var zichtbaar = false
    @Environment(\.accessibilityReduceMotion) private var minderBeweging

    func body(content: Content) -> some View {
        content
            .opacity(zichtbaar ? 1 : 0)
            .offset(y: zichtbaar || minderBeweging ? 0 : 14)
            .onAppear {
                guard !zichtbaar else { return }
                withAnimation(.huurmeter.delay(minderBeweging ? 0 : Double(volgorde) * 0.06)) { zichtbaar = true }
            }
    }
}

/// Houdt bij of het toetsenbord in beeld is (met de animatieduur van het systeem).
@MainActor
final class Toetsenbord: ObservableObject {
    @Published private(set) var zichtbaar = false
    private var abonnementen: Set<AnyCancellable> = []

    init() {
        let nc = NotificationCenter.default
        nc.publisher(for: UIResponder.keyboardWillShowNotification)
            .sink { [weak self] _ in withAnimation(.easeOut(duration: 0.25)) { self?.zichtbaar = true } }
            .store(in: &abonnementen)
        nc.publisher(for: UIResponder.keyboardWillHideNotification)
            .sink { [weak self] _ in withAnimation(.easeOut(duration: 0.25)) { self?.zichtbaar = false } }
            .store(in: &abonnementen)
    }
}

extension View {
    func verschijn(_ volgorde: Int = 0) -> some View { modifier(Verschijn(volgorde: volgorde)) }

    /// Onderbalk die wegschuift zodra het toetsenbord verschijnt, in plaats van erop mee te springen.
    func onderbalk<Balk: View>(@ViewBuilder _ balk: @escaping () -> Balk) -> some View {
        modifier(Onderbalk(balk: balk))
    }
}

private struct Onderbalk<Balk: View>: ViewModifier {
    let balk: () -> Balk
    @StateObject private var toetsenbord = Toetsenbord()

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            if !toetsenbord.zichtbaar {
                balk().transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}

/// Overgang tussen stappen: vooruit schuift van rechts in, terug van links.
extension AnyTransition {
    static func stap(vooruit: Bool) -> AnyTransition {
        .asymmetric(insertion: .move(edge: vooruit ? .trailing : .leading).combined(with: .opacity),
                    removal: .move(edge: vooruit ? .leading : .trailing).combined(with: .opacity))
    }
}
