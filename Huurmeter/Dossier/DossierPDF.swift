import UIKit
import HuurmeterCore

/// Maakt het PDF-dossier (A4) uit `DossierInhoud`, met de plattegronden en bewijsfoto's.
enum DossierPDF {
    struct Bijlage {
        let titel: String
        let beeld: Data
    }

    static func maak(_ d: DossierInhoud, plattegronden: [Bijlage], fotos: [Bijlage]) -> Data {
        let pagina = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4 in punten
        let renderer = UIGraphicsPDFRenderer(bounds: pagina, format: {
            let f = UIGraphicsPDFRendererFormat()
            f.documentInfo = [kCGPDFContextTitle as String: d.titel, kCGPDFContextCreator as String: "Huurmeter"]
            return f
        }())
        return renderer.pdfData { ctx in
            let s = Schrijver(ctx: ctx, pagina: pagina, voet: d.voetnoten.first ?? "")
            s.tekst(d.titel, .systemFont(ofSize: 22, weight: .heavy), kleur: Schrijver.bosgroen, na: 2)
            s.tekst(d.adres, .systemFont(ofSize: 14, weight: .semibold), na: 2)
            s.tekst(d.datum, .systemFont(ofSize: 10), kleur: .darkGray, na: 14)

            for (sleutel, waarde) in d.kerncijfers { s.regel(sleutel, waarde) }
            s.ruimte(10)
            for r in d.samenvatting { s.tekst(r, .systemFont(ofSize: 11)) }

            if !d.waarschuwingen.isEmpty {
                s.kop("Let op")
                for w in d.waarschuwingen { s.tekst("• " + w, .systemFont(ofSize: 10)) }
            }

            s.kop("Ruimtes")
            for r in d.ruimten {
                let extra = r.opmerking.map { ", \($0)" } ?? ""
                s.regel("\(r.naam) (\(r.soort)\(extra))", "\(r.oppervlakte) · \(r.bron)")
            }

            s.kop("Puntentelling per rubriek")
            for r in d.rubrieken {
                s.regel(r.kop, r.punten, vet: true)
                for stap in r.stappen { s.tekst(stap, .systemFont(ofSize: 9), kleur: .darkGray, insprong: 12, na: 1) }
                s.tekst("Bron: " + r.bron, .italicSystemFont(ofSize: 8), kleur: .gray, insprong: 12, na: 6)
            }
            if !d.prijsopslag.isEmpty {
                s.kop("Prijsopslag")
                for p in d.prijsopslag { s.tekst(p, .systemFont(ofSize: 10)) }
            }

            if !plattegronden.isEmpty {
                s.kop("Plattegronden")
                for p in plattegronden { s.afbeelding(p) }
            }
            if !fotos.isEmpty {
                s.kop("Bewijsfoto's")
                for f in fotos { s.afbeelding(f) }
            }

            s.kop("Bronnen")
            for b in d.bronnen { s.tekst(b, .systemFont(ofSize: 9)) }
            s.ruimte(10)
            for v in d.voetnoten { s.tekst(v, .systemFont(ofSize: 10, weight: .semibold)) }
        }
    }

    /// Tekst doorlopend over pagina's zetten.
    final class Schrijver {
        let ctx: UIGraphicsPDFRendererContext
        let pagina: CGRect
        let voet: String
        let marge: CGFloat = 48
        /// Huisstijl C: koppen in bosgroen #17402E.
        static let bosgroen = UIColor(red: 0x17 / 255, green: 0x40 / 255, blue: 0x2E / 255, alpha: 1)
        var y: CGFloat = 0
        var nummer = 0

        init(ctx: UIGraphicsPDFRendererContext, pagina: CGRect, voet: String) {
            self.ctx = ctx; self.pagina = pagina; self.voet = voet
            nieuwePagina()
        }

        var breedte: CGFloat { pagina.width - 2 * marge }
        var onderkant: CGFloat { pagina.height - marge - 24 }

        func nieuwePagina() {
            ctx.beginPage()
            nummer += 1
            y = marge
            let attr: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 8), .foregroundColor: UIColor.gray]
            ("\(voet)   Pagina \(nummer)" as NSString)
                .draw(in: CGRect(x: marge, y: pagina.height - marge, width: breedte, height: 20), withAttributes: attr)
        }

        func ruimte(_ h: CGFloat) { y += h }

        func plek(_ h: CGFloat) { if y + h > onderkant { nieuwePagina() } }

        func tekst(_ s: String, _ font: UIFont, kleur: UIColor = .black, insprong: CGFloat = 0, na: CGFloat = 4) {
            let attr = NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: kleur])
            let b = breedte - insprong
            let h = ceil(attr.boundingRect(with: CGSize(width: b, height: .greatestFiniteMagnitude),
                                           options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil).height)
            plek(h)
            attr.draw(with: CGRect(x: marge + insprong, y: y, width: b, height: h),
                      options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
            y += h + na
        }

        func kop(_ s: String) {
            ruimte(10)
            plek(60)
            tekst(s, .systemFont(ofSize: 15, weight: .heavy), kleur: Self.bosgroen, na: 6)
        }

        func regel(_ links: String, _ rechts: String, vet: Bool = false) {
            let font = UIFont.systemFont(ofSize: 11, weight: vet ? .semibold : .regular)
            let rechtsBreedte: CGFloat = 170
            let la = NSAttributedString(string: links, attributes: [.font: font])
            let stijl = NSMutableParagraphStyle()
            stijl.alignment = .right
            let ra = NSAttributedString(string: rechts, attributes: [.font: font, .paragraphStyle: stijl])
            let lb = breedte - rechtsBreedte - 8
            let h = max(
                ceil(la.boundingRect(with: CGSize(width: lb, height: .greatestFiniteMagnitude), options: .usesLineFragmentOrigin, context: nil).height),
                ceil(ra.boundingRect(with: CGSize(width: rechtsBreedte, height: .greatestFiniteMagnitude), options: .usesLineFragmentOrigin, context: nil).height))
            plek(h)
            la.draw(with: CGRect(x: marge, y: y, width: lb, height: h), options: .usesLineFragmentOrigin, context: nil)
            ra.draw(with: CGRect(x: marge + breedte - rechtsBreedte, y: y, width: rechtsBreedte, height: h),
                    options: .usesLineFragmentOrigin, context: nil)
            y += h + 3
        }

        func afbeelding(_ b: Bijlage) {
            guard let beeld = UIImage(data: b.beeld), beeld.size.width > 0 else { return }
            let maxH: CGFloat = 300
            let schaal = min(breedte / beeld.size.width, maxH / beeld.size.height, 1.5)
            let w = beeld.size.width * schaal, h = beeld.size.height * schaal
            plek(h + 30)
            tekst(b.titel, .systemFont(ofSize: 11, weight: .semibold), na: 4)
            beeld.draw(in: CGRect(x: marge, y: y, width: w, height: h))
            y += h + 12
        }
    }
}
