import SwiftUI
import UIKit

/// Huisstijl richting C "Vriendelijk" (gekozen 15-11-2026). Zie docs/HUISSTIJL.md.
/// Elke kleur heeft een variant voor de donkere modus en haalt in beide minstens 4,5:1 contrast
/// waar hij als tekstkleur wordt gebruikt.
enum Huisstijl {
    /// Bosgroen #17402E: hoofdkleur, koppen, knoppen. Donker: limoen, zodat het leesbaar blijft.
    static let bosgroen = Color(licht: 0x17402E, donker: 0xC6F06B)
    /// Limoen #C6F06B: accentvlakken (labels, segment). Nooit als tekstkleur op wit.
    static let limoen = Color(licht: 0xC6F06B, donker: 0x3D5A1E)
    /// Tekst op een limoen vlak.
    static let opLimoen = Color(licht: 0x17402E, donker: 0xE7F7C9)
    /// Salie #F3F6EF: achtergrond van lijsten en schermen.
    static let salie = Color(licht: 0xF3F6EF, donker: 0x0F1712)
    /// Kaarten op de achtergrond.
    static let kaart = Color(licht: 0xFFFFFF, donker: 0x1A2620)
    /// Signaalrood #B42318 voor "te veel huur"; met een zacht vlak eronder.
    static let signaal = Color(licht: 0xB42318, donker: 0xFF8A80)
    static let signaalVlak = Color(licht: 0xFDE7E4, donker: 0x3A1714)
    /// Gedempte tekst (voldoet aan 4,5:1 op salie en wit).
    static let gedempt = Color(licht: 0x3F4D44, donker: 0xB7C4BB)
}

extension Color {
    init(licht: UInt32, donker: UInt32) {
        self.init(uiColor: UIColor { kenmerk in
            UIColor(hex: kenmerk.userInterfaceStyle == .dark ? donker : licht)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

/// Het logo: een dak met een vinkje ("klopt mijn huur?"). Getekend als vorm, zodat het op elke
/// grootte scherp is en meekleurt met de donkere modus.
struct Logo: View {
    var dak: Color = Huisstijl.limoen
    var vinkje: Color = .white
    var achtergrond: Color? = Huisstijl.bosgroen

    var body: some View {
        GeometryReader { geo in
            let z = min(geo.size.width, geo.size.height)
            ZStack {
                if let achtergrond {
                    RoundedRectangle(cornerRadius: z * 0.28, style: .continuous).fill(achtergrond)
                }
                LogoLijn(punten: [(16, 62), (64, 22), (112, 62)])
                    .stroke(dak, style: StrokeStyle(lineWidth: z * 12 / 128, lineCap: .round, lineJoin: .round))
                LogoLijn(punten: [(42, 84), (58, 100), (86, 70)])
                    .stroke(vinkje, style: StrokeStyle(lineWidth: z * 12 / 128, lineCap: .round, lineJoin: .round))
            }
            .frame(width: z, height: z)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

private struct LogoLijn: Shape {
    let punten: [(CGFloat, CGFloat)]

    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 128
        var p = Path()
        for (i, punt) in punten.enumerated() {
            let q = CGPoint(x: rect.minX + punt.0 * s, y: rect.minY + punt.1 * s)
            if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
        }
        return p
    }
}

/// Een label in een pil, zoals "Sociale huur" of "€ 97 per maand te veel".
struct Pil: View {
    let tekst: String
    var voorgrond: Color = Huisstijl.opLimoen
    var achtergrond: Color = Huisstijl.limoen

    var body: some View {
        Text(tekst)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(voorgrond)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(achtergrond, in: Capsule())
    }
}

extension View {
    /// Achtergrond in huisstijl voor lijsten en formulieren.
    func huisstijlAchtergrond() -> some View {
        scrollContentBackground(.hidden).background(Huisstijl.salie)
    }
}
