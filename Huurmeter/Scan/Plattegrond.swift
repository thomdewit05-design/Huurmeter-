import UIKit
import HuurmeterCore

/// Tekent een plattegrond van één gescande ruimte voor in de app en het dossier (spec §6).
enum Plattegrond {
    static func png(_ s: ScanResultaat, naam: String, zijde: CGFloat = 1200) -> Data? {
        let alle = s.vloer + s.muren.flatMap { [$0.van, $0.naar] }
        guard let pas = Geometrie.inpassen(alle, breedte: Double(zijde), hoogte: Double(zijde) - 120, marge: 90) else { return nil }
        let p: (Punt2) -> CGPoint = { let q = pas.omzetten($0); return CGPoint(x: q.x, y: q.y + 120) }

        let formaat = UIGraphicsImageRendererFormat()
        formaat.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: zijde, height: zijde), format: formaat)
        let beeld = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: zijde, height: zijde))

            // Vloer
            if let eerste = s.vloer.first {
                let vloer = UIBezierPath()
                vloer.move(to: p(eerste))
                for punt in s.vloer.dropFirst() { vloer.addLine(to: p(punt)) }
                vloer.close()
                UIColor(white: 0.92, alpha: 1).setFill()
                vloer.fill()
            }

            func teken(_ lijnen: [Lijnstuk], kleur: UIColor, dikte: CGFloat) {
                kleur.setStroke()
                for l in lijnen {
                    let pad = UIBezierPath()
                    pad.move(to: p(l.van))
                    pad.addLine(to: p(l.naar))
                    pad.lineWidth = dikte
                    pad.lineCapStyle = .square
                    pad.stroke()
                }
            }
            teken(s.muren, kleur: .black, dikte: 10)
            teken(s.ramen, kleur: .systemBlue, dikte: 14)
            teken(s.deuren, kleur: .white, dikte: 12)

            // Kop: naam en gemeten vloeroppervlak
            let kop = "\(naam) · vloer \(Inmeting.weergave(s.vloeroppervlakte)) (gescand)"
            (kop as NSString).draw(at: CGPoint(x: 40, y: 40), withAttributes: [
                .font: UIFont.systemFont(ofSize: 40, weight: .semibold), .foregroundColor: UIColor.black,
            ])

            // Schaalbalk van 1 meter
            let meter = CGFloat(pas.schaal)
            let y = zijde - 50
            let balk = UIBezierPath()
            balk.move(to: CGPoint(x: 40, y: y))
            balk.addLine(to: CGPoint(x: 40 + meter, y: y))
            balk.lineWidth = 6
            UIColor.darkGray.setStroke()
            balk.stroke()
            ("1 m" as NSString).draw(at: CGPoint(x: 50 + meter, y: y - 22), withAttributes: [
                .font: UIFont.systemFont(ofSize: 30), .foregroundColor: UIColor.darkGray,
            ])
        }
        return beeld.pngData()
    }
}
