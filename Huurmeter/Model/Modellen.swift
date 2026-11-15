import Foundation
import SwiftData
import WWSKit
import HuurmeterCore

// Datamodel volgens spec §7. Enums worden als tekst bewaard, zodat een latere app-versie
// oude gegevens altijd kan lezen.

@Model
final class Woning {
    var postcode: String = ""
    var huisnummer: String = ""
    var straat: String = ""
    var plaats: String = ""
    var gemeente: String?
    var verblijfsobjectId: String?
    var bouwjaar: Int?
    var typeRaw: String?
    var kaleHuur: Double?
    var contractStart: Date?
    var wozWaarde: Double?
    var wozPeildatum: Date?
    var energielabelRaw: String?
    var energieIndex: Double?
    /// Datum van opname van het energielabel (bepaalt de geldigheid van tien jaar).
    var labelDatum: Date?
    var energieprestatievergoeding: Bool = false
    var koelingInLabel: Bool = false
    /// Lokale herinneringen (termijn aanvangshuur, jaarlijkse huurverhoging).
    var herinneringenAan: Bool = false
    var aangemaakt: Date = Date()
    var gewijzigd: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \Ruimte.woning) var ruimten: [Ruimte] = []
    @Relationship(deleteRule: .cascade, inverse: \Voorziening.woning) var voorzieningen: [Voorziening] = []
    @Relationship(deleteRule: .cascade, inverse: \Berekening.woning) var berekeningen: [Berekening] = []
    @Relationship(deleteRule: .cascade, inverse: \Gebrek.woning) var gebreken: [Gebrek] = []

    init() {}

    var woningtype: Woningtype? {
        get { typeRaw.flatMap(Woningtype.init(rawValue:)) }
        set { typeRaw = newValue?.rawValue; geraakt() }
    }

    var energielabel: Energielabel? {
        get { energielabelRaw.flatMap(Energielabel.init(rawValue:)) }
        set { energielabelRaw = newValue?.rawValue; geraakt() }
    }

    var adres: AdresGegevens {
        AdresGegevens(postcode: postcode, huisnummer: huisnummer, straat: straat, plaats: plaats,
                      gemeente: gemeente, bouwjaar: bouwjaar, verblijfsobjectId: verblijfsobjectId)
    }

    var titel: String {
        let a = adres.weergave
        return a.isEmpty ? "Nieuwe woning" : a
    }

    var gesorteerdeRuimten: [Ruimte] { ruimten.sorted { ($0.volgorde, $0.naam) < ($1.volgorde, $1.naam) } }

    var laatsteBerekening: Berekening? { berekeningen.max { $0.datum < $1.datum } }

    func geraakt() { gewijzigd = Date() }

    // MARK: Antwoorden van scherm 5

    func voorziening(_ sleutel: String) -> Voorziening? { voorzieningen.first { $0.sleutel == sleutel } }

    func antwoord(_ sleutel: String) -> Double {
        voorziening(sleutel)?.waarde ?? Vragenlijst.standaarden[sleutel] ?? 0
    }

    func zetAntwoord(_ sleutel: String, _ waarde: Double, rubriek: String) {
        if let v = voorziening(sleutel) {
            v.waarde = waarde
        } else {
            voorzieningen.append(Voorziening(rubriek: rubriek, sleutel: sleutel, waarde: waarde))
        }
        geraakt()
    }

    // MARK: Omzetten naar de rekenlogica

    var concept: WoningConcept {
        var antwoorden: [String: Double] = [:]
        for v in voorzieningen { antwoorden[v.sleutel] = v.waarde }
        return WoningConcept(
            adres: adres, bouwjaar: bouwjaar, woningtype: woningtype, kaleHuur: kaleHuur,
            contractStart: contractStart.map { Dag($0) },
            ruimten: gesorteerdeRuimten.map(\.concept), antwoorden: antwoorden,
            energielabel: energielabel, energieIndex: energieIndex,
            labelOpnamedatum: labelDatum.map { Dag($0) },
            energieprestatievergoeding: energieprestatievergoeding, koelingInLabel: koelingInLabel,
            wozWaarde: wozWaarde, wozPeildatum: wozPeildatum.map { Dag($0) })
    }

    func neemAdresOver(_ a: AdresGegevens) {
        postcode = Postcode(a.postcode)?.waarde ?? a.postcode
        huisnummer = a.huisnummer
        straat = a.straat
        plaats = a.plaats
        gemeente = a.gemeente
        verblijfsobjectId = a.verblijfsobjectId
        if let j = a.bouwjaar { bouwjaar = j }
        geraakt()
    }
}

@Model
final class Ruimte {
    var naam: String = ""
    var soortRaw: String = RuimteSoort.vertrek.rawValue
    var functieRaw: String?
    var oppervlakte: Double = 0
    /// "scan" of "handmatig"; komt in het dossier.
    var bronRaw: String = MeetBron.handmatig.rawValue
    var verwarmd: Bool = true
    var verkoeling: Bool = false
    var zolderZonderVasteTrap: Bool = false
    /// Vloeroppervlak uit de laatste scan (m²), nil als niet gescand.
    var gescandeOppervlakte: Double?
    /// Schuin dak of verlaagd plafond aangegeven door de gebruiker (RoomPlan herkent dit niet betrouwbaar).
    var schuinDak: Bool = false
    /// Af te trekken m²: deel met plafond lager dan 1,50 m en schachten/koven.
    var aftrek: Double = 0
    @Attribute(.externalStorage) var plattegrond: Data?
    var volgorde: Int = 0
    var woning: Woning?

    init(naam: String, functie: RuimteFunctie, volgorde: Int) {
        self.naam = naam
        self.functieRaw = functie.rawValue
        self.soortRaw = RuimteConcept.standaardSoort(voor: functie).rawValue
        self.verwarmd = functie != .berging && functie != .garage && functie != .zolder
        self.volgorde = volgorde
    }

    var soort: RuimteSoort {
        get { RuimteSoort(rawValue: soortRaw) ?? .vertrek }
        set { soortRaw = newValue.rawValue }
    }

    var functie: RuimteFunctie? {
        get { functieRaw.flatMap(RuimteFunctie.init(rawValue:)) }
        set { functieRaw = newValue?.rawValue }
    }

    var bron: MeetBron {
        get { MeetBron(rawValue: bronRaw) ?? .handmatig }
        set { bronRaw = newValue.rawValue }
    }

    /// Neemt een scan over: gemeten vloer, plattegrond en de voorgestelde WWS-oppervlakte.
    func neemScanOver(_ scan: ScanResultaat, plattegrond: Data?) {
        gescandeOppervlakte = scan.vloeroppervlakte
        self.plattegrond = plattegrond
        herberekenUitScan()
    }

    /// Na een scan: oppervlakte = gescande vloer min de opgegeven aftrek. Markeert de waarde als gescand.
    func herberekenUitScan() {
        guard let g = gescandeOppervlakte else { return }
        oppervlakte = Inmeting.voorstel(gescand: g, aftrek: aftrek)
        bron = .scan
        woning?.geraakt()
    }

    var concept: RuimteConcept {
        RuimteConcept(naam: naam, soort: soort, functie: functie, oppervlakte: oppervlakte,
                      verwarmd: soort == .buitenruimte ? false : verwarmd,
                      verkoeling: soort == .vertrek && verkoeling,
                      zolderZonderVasteTrap: soort == .overigeRuimte && zolderZonderVasteTrap, bron: bron)
    }
}

@Model
final class Voorziening {
    var rubriek: String = ""
    var sleutel: String = ""
    var waarde: Double = 0
    @Attribute(.externalStorage) var foto: Data?
    var woning: Woning?

    init(rubriek: String, sleutel: String, waarde: Double) {
        self.rubriek = rubriek
        self.sleutel = sleutel
        self.waarde = waarde
    }
}

@Model
final class Berekening {
    var regelsetJaar: Int = 0
    var puntenPerRubriek: [String: Double] = [:]
    var totaal: Int = 0
    var maxHuur: Double?
    var datum: Date = Date()
    var woning: Woning?

    init(uitkomst: Uitkomst) {
        regelsetJaar = uitkomst.regelsetJaar
        totaal = uitkomst.totaal
        maxHuur = uitkomst.maximaleHuur
        var p: [String: Double] = [:]
        for r in uitkomst.rubrieken { p[r.nummer] = r.punten }
        puntenPerRubriek = p
    }

    func zelfdeAls(_ u: Uitkomst) -> Bool {
        regelsetJaar == u.regelsetJaar && totaal == u.totaal && maxHuur == u.maximaleHuur
            && puntenPerRubriek == Dictionary(uniqueKeysWithValues: u.rubrieken.map { ($0.nummer, $0.punten) })
    }
}

/// De regelset die vandaag geldt (nil als de app geen regelbestand voor vandaag heeft).
enum HuidigeRegels {
    static var regels: Regelset? { try? RegelsetBibliotheek.regelset(op: Dag(Date())) }
}

/// Functie 9: een gebrek dat de huurder bijhoudt, met meld- en hersteldatum en foto's.
@Model
final class Gebrek {
    var titel: String = ""
    var omschrijving: String = ""
    var ruimte: String = ""
    var categorieRaw: String?
    var ontdekt: Date = Date()
    var gemeld: Date?
    var verholpen: Date?
    @Attribute(.externalStorage) var fotos: [Data] = []
    var woning: Woning?

    init(titel: String = "") { self.titel = titel }

    var categorie: Gebrekcategorie? {
        get { categorieRaw.flatMap(Gebrekcategorie.init(rawValue:)) }
        set { categorieRaw = newValue?.rawValue }
    }

    var open: Bool { verholpen == nil }
}
