import Foundation
import WWSKit

/// Zet wat de gebruiker heeft ingevuld om naar de invoer van WWSKit.
public enum Invoerbouwer {
    public enum Ontbreekt: Error, Equatable, CustomStringConvertible {
        case bouwjaar, woningtype, ruimten

        public var description: String {
            switch self {
            case .bouwjaar: return "Vul het bouwjaar in (scherm Adres)."
            case .woningtype: return "Kies het type woning (scherm Huur)."
            case .ruimten: return "Voeg minstens één kamer toe (scherm Ruimtes)."
            }
        }
    }

    public static func invoer(_ c: WoningConcept, regels: Regelset) throws -> WoningInvoer {
        guard let bouwjaar = c.bouwjaar else { throw Ontbreekt.bouwjaar }
        guard let type = c.woningtype else { throw Ontbreekt.woningtype }
        guard c.ruimten.contains(where: { $0.soort == .vertrek && $0.oppervlakte > 0 }) else { throw Ontbreekt.ruimten }

        var w = WoningInvoer(bouwjaar: bouwjaar, woningtype: type)
        w.ruimten = c.ruimten.map {
            RuimteInvoer(naam: $0.naam, soort: $0.soort, functie: $0.functie, oppervlakte: $0.oppervlakte,
                         verwarmd: $0.verwarmd, verkoeling: $0.verkoeling,
                         zolderZonderVasteTrap: $0.zolderZonderVasteTrap, bron: $0.bron)
        }
        w.verwarmdeOpenKeukens = c.ja("verwarming.openKeuken") ? 1 : 0
        w.keukens = keukens(c, regels: regels)
        w.sanitaireRuimten = sanitair(c, regels: regels)
        w.energie = EnergieInvoer(label: c.energielabel, energieIndex: c.energielabel == nil ? c.energieIndex : nil,
                                  opnamedatum: c.labelOpnamedatum,
                                  energieprestatievergoeding: c.energieprestatievergoeding,
                                  koelingInLabel: c.koelingInLabel)
        w.kostenGehandicaptenvoorzieningen = max(0, c.antwoord("gehandicapten.kosten"))

        if c.antwoord("gemBuiten.oppervlakte") > 0 {
            w.gemeenschappelijkeBuitenruimten = [GemeenschappelijkeBuitenruimteInvoer(
                naam: "Gedeelde buitenruimte", oppervlakte: c.antwoord("gemBuiten.oppervlakte"),
                adressen: max(1, c.aantal("gemBuiten.adressen")))]
        }
        if c.antwoord("gemVertrek.oppervlakte") > 0 {
            w.gemeenschappelijkeRuimten.append(GemeenschappelijkeRuimteInvoer(
                naam: "Gedeelde woonruimte", soort: .vertrek, oppervlakte: c.antwoord("gemVertrek.oppervlakte"),
                verwarmd: c.ja("gemVertrek.verwarmd"), adressen: max(1, c.aantal("gemVertrek.adressen"))))
        }
        if c.antwoord("gemOverig.oppervlakte") > 0 {
            w.gemeenschappelijkeRuimten.append(GemeenschappelijkeRuimteInvoer(
                naam: "Gedeelde berging", soort: .overigeRuimte, oppervlakte: c.antwoord("gemOverig.oppervlakte"),
                adressen: max(1, c.aantal("gemOverig.adressen"))))
        }
        let p1 = c.aantal("parkeren.typeI"), p2 = c.aantal("parkeren.typeII"), p3 = c.aantal("parkeren.typeIII")
        if p1 + p2 + p3 > 0 {
            w.parkeerruimten = [ParkeerruimteInvoer(
                naam: "Gedeeld parkeren", plekkenTypeI: p1, plekkenTypeII: p2, plekkenTypeIII: p3,
                oppervlakteTypeI: p1 > 0 ? c.antwoord("parkeren.oppervlakteTypeI") : 0,
                plekkenMetLaadpaal: min(c.aantal("parkeren.laadpalen"), p1 + p2 + p3),
                adressen: max(1, c.aantal("parkeren.adressen")))]
        }

        w.woz = WozInvoer(waarde: c.wozWaarde, waardepeildatum: c.wozWaarde == nil ? nil : c.wozPeildatum)
        w.coropAmsterdamOfUtrecht = c.ja("coropAmsterdamUtrecht")
        w.zorgwoning = c.ja("zorgwoning")
        w.videoAanbelfunctie = c.ja("videoAanbel")
        switch c.aantal("monument") {
        case 1: w.monument = .rijksmonument
        case 2: w.monument = .gemeentelijkOfProvinciaal
        default: w.monument = .geen
        }
        w.beschermdStadsOfDorpsgezicht = c.ja("beschermdGezicht")
        w.ingebruiknameDatum = Dag(getal: c.antwoord("nieuwbouw.ingebruikname"))
        w.bouwGestartVoor2028 = c.ja("nieuwbouw.bouwVoor2028")
        w.contractStart = c.contractStart
        w.kaleHuur = c.kaleHuur
        return w
    }

    static func keukens(_ c: WoningConcept, regels: Regelset) -> [KeukenInvoer] {
        let lengte = c.antwoord("keuken.aanrecht")
        guard lengte > 0 || !c.ja("keuken.basisniveau") else { return [] }
        var v: [String: Int] = [:]
        for sleutel in regels.rubrieken.r5.voorzieningen.keys {
            let n = c.aantal("keuken.\(sleutel)")
            if n > 0 { v[sleutel] = n }
        }
        return [KeukenInvoer(voldoetAanBasisniveau: c.ja("keuken.basisniveau"), aanrechtLengte: lengte, voorzieningen: v)]
    }

    static func sanitair(_ c: WoningConcept, regels: Regelset) -> [SanitaireRuimteInvoer] {
        var lijst: [SanitaireRuimteInvoer] = []
        let staand = c.aantal("toilet.staand"), hangend = c.aantal("toilet.hangend")
        // Elke aparte toiletruimte is een eigen ruimte; de wastafel staat in de eerste.
        for i in 0..<(staand + hangend) {
            lijst.append(SanitaireRuimteInvoer(
                naam: "Toilet \(i + 1)", soort: .toiletruimte,
                staandeToiletten: i < staand ? 1 : 0, hangendeToiletten: i < staand ? 0 : 1,
                wastafels: i == 0 && c.ja("toilet.wastafel") ? 1 : 0))
        }
        let badkamers = min(Vragenlijst.maximumBadkamers, c.aantal("badkamers"))
        for i in stride(from: 1, through: badkamers, by: 1) {
            let p = "badkamer\(i)"
            var v: [String: Int] = [:]
            for sleutel in regels.rubrieken.r6.voorzieningenBadruimte.keys {
                let n = c.aantal("\(p).\(sleutel)")
                if n > 0 { v[sleutel] = n }
            }
            lijst.append(SanitaireRuimteInvoer(
                naam: "Badkamer \(i)", soort: .badkamer,
                staandeToiletten: c.ja("\(p).toiletStaand") ? 1 : 0, hangendeToiletten: c.ja("\(p).toiletHangend") ? 1 : 0,
                wastafels: c.aantal("\(p).wastafels"), meerpersoonswastafels: c.aantal("\(p).meerpersoonswastafels"),
                douches: c.aantal("\(p).douches"), baden: c.aantal("\(p).baden"),
                voldoetAanEisenBadruimte: c.ja("\(p).voldoetEisen"), voorzieningen: v))
        }
        for i in 0..<c.aantal("wastafels.overig") {
            lijst.append(SanitaireRuimteInvoer(naam: "Kamer met wastafel \(i + 1)", soort: .anders, wastafels: 1))
        }
        return lijst
    }
}
