import Foundation

/// Stappenplannen voor de Huurcommissie, ingelezen uit `rules/huurcommissie-procedures.json`.
/// Alle termijnen en bedragen komen uit het Burgerlijk Wetboek en de huurprijsregels; zie `bronnen`.
public struct Stappenplannen: Codable, Sendable {
    public let bronnen: [String: Regelset.Bron]
    public let leges: Leges
    public let bezwaarRechter: Weken
    public let procedures: [Procedure]

    public struct Leges: Codable, Sendable {
        public let huurder: Double
        public let verhuurder: Double
        public let bron: String
    }

    public struct Weken: Codable, Sendable {
        public let weken: Int
        public let bron: String
    }

    public struct Stap: Codable, Sendable, Hashable {
        public let titel: String
        public let tekst: String
        public let bron: String?
    }

    /// Een termijn gerekend vanaf een ankerdatum. `naDagVolgend`: de termijn begint op de dag na het anker
    /// ("na de aanvang van de dag volgend op die waarop", BW 7:257).
    public struct Termijnregel: Codable, Sendable, Hashable {
        public let maanden: Int?
        public let weken: Int?
        public let dagen: Int?
        public let maandenVanafVandaag: Int?
        public let naDagVolgend: Bool?
        public let bron: String

        public func datum(vanaf anker: Dag) -> Dag {
            var d = (naDagVolgend ?? false) ? anker.plusDagen(1) : anker
            if let m = maanden { d = d.plusMaanden(m) }
            if let w = weken { d = d.plusDagen(7 * w) }
            if let n = dagen { d = d.plusDagen(n) }
            return d
        }
    }

    public struct Procedure: Codable, Sendable, Identifiable, Hashable {
        public let id: String
        public let titel: String
        public let situatie: String
        /// Omschrijving van de datum waar de termijnen vanaf tellen.
        public let anker: String
        public let vroegste: Termijnregel?
        public let uiterste: Termijnregel
        public let overzichtUiterlijk: Termijnregel?
        public let stappen: [Stap]
    }

    public func procedure(_ id: String) -> Procedure? { procedures.first { $0.id == id } }

    public static func laad() throws -> Stappenplannen {
        guard let url = Bundle.module.url(forResource: "huurcommissie-procedures", withExtension: "json", subdirectory: "rules") else {
            throw WWSFout.geenRegelset("geen stappenplannen voor de Huurcommissie")
        }
        return try JSONDecoder().decode(Stappenplannen.self, from: Data(contentsOf: url))
    }
}

/// Uitkomst van een stappenplan voor een concrete datum.
public struct StappenplanTermijnen: Sendable, Equatable {
    /// Vroegste datum waarop het verzoek kan (gebreken), of de vroegste ingangsdatum van een voorstel (huurverlaging).
    public let vroegst: Dag?
    /// Laatste dag waarop het verzoek of bezwaar kan.
    public let uiterlijk: Dag
    /// Uiterste datum waarop de verhuurder het servicekostenoverzicht moest geven.
    public let overzichtUiterlijk: Dag?
    public let dagenOver: Int
    public var verlopen: Bool { dagenOver < 0 }
}

public extension Stappenplannen.Procedure {
    func termijnen(anker: Dag, vandaag: Dag) -> StappenplanTermijnen {
        let uiterlijk = uiterste.datum(vanaf: anker)
        var vroegst: Dag?
        if let v = vroegste {
            if let m = v.maandenVanafVandaag { vroegst = vandaag.plusMaanden(m) } else { vroegst = v.datum(vanaf: anker) }
        }
        return StappenplanTermijnen(vroegst: vroegst, uiterlijk: uiterlijk,
                                    overzichtUiterlijk: overzichtUiterlijk?.datum(vanaf: anker),
                                    dagenOver: vandaag.dagen(tot: uiterlijk))
    }
}
