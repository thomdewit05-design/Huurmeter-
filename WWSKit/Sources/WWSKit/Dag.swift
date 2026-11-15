import Foundation

/// Een kalenderdag zonder tijdzone. Wordt in JSON geschreven als "jjjj-mm-dd".
/// Eigen type zodat termijnberekeningen niet afhangen van de tijdzone van het toestel.
public struct Dag: Codable, Hashable, Comparable, CustomStringConvertible, Sendable {
    public let jaar: Int
    public let maand: Int
    public let dag: Int

    public init(_ jaar: Int, _ maand: Int, _ dag: Int) {
        precondition((1...12).contains(maand), "maand buiten bereik")
        precondition((1...Dag.dagenInMaand(jaar, maand)).contains(dag), "dag buiten bereik")
        self.jaar = jaar
        self.maand = maand
        self.dag = dag
    }

    public init?(iso: String) {
        let delen = iso.split(separator: "-").compactMap { Int($0) }
        guard delen.count == 3,
              (1...12).contains(delen[1]),
              (1...Dag.dagenInMaand(delen[0], delen[1])).contains(delen[2]) else { return nil }
        self.init(delen[0], delen[1], delen[2])
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let s = try c.decode(String.self)
        guard let d = Dag(iso: s) else {
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Ongeldige datum '\(s)', verwacht jjjj-mm-dd")
        }
        self = d
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(iso)
    }

    public var iso: String { String(format: "%04d-%02d-%02d", jaar, maand, dag) }
    public var description: String { String(format: "%02d-%02d-%04d", dag, maand, jaar) }

    public static func < (a: Dag, b: Dag) -> Bool { a.dagnummer < b.dagnummer }

    static func isSchrikkeljaar(_ j: Int) -> Bool { (j % 4 == 0 && j % 100 != 0) || j % 400 == 0 }

    static func dagenInMaand(_ j: Int, _ m: Int) -> Int {
        switch m {
        case 2: return isSchrikkeljaar(j) ? 29 : 28
        case 4, 6, 9, 11: return 30
        default: return 31
        }
    }

    /// Juliaans dagnummer (proleptisch Gregoriaans).
    var dagnummer: Int {
        let a = (14 - maand) / 12
        let y = jaar + 4800 - a
        let m = maand + 12 * a - 3
        return dag + (153 * m + 2) / 5 + 365 * y + y / 4 - y / 100 + y / 400 - 32045
    }

    /// Tel maanden op; valt de dag buiten de nieuwe maand, dan de laatste dag van die maand.
    public func plusMaanden(_ n: Int) -> Dag {
        let totaal = (jaar * 12 + (maand - 1)) + n
        let j = totaal / 12
        let m = totaal % 12 + 1
        return Dag(j, m, min(dag, Dag.dagenInMaand(j, m)))
    }

    public func plusJaren(_ n: Int) -> Dag { plusMaanden(12 * n) }

    /// Tel dagen op (negatief: terug). Terugrekenen via het Juliaanse dagnummer (Fliegel & Van Flandern).
    public func plusDagen(_ n: Int) -> Dag {
        var l = dagnummer + n + 68569
        let nn = 4 * l / 146097
        l = l - (146097 * nn + 3) / 4
        let i = 4000 * (l + 1) / 1461001
        l = l - 1461 * i / 4 + 31
        let j = 80 * l / 2447
        let d = l - 2447 * j / 80
        l = j / 11
        let m = j + 2 - 12 * l
        let y = 100 * (nn - 49) + i + l
        return Dag(y, m, d)
    }

    /// Aantal dagen van `self` tot `ander` (positief als `ander` later is).
    public func dagen(tot ander: Dag) -> Int { ander.dagnummer - dagnummer }
}
