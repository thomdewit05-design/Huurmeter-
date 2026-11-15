import Foundation

/// Nederlandse getalnotatie (1.234,56) zonder NumberFormatter, zodat de uitkomst op elk platform gelijk is.
public enum Getalnotatie {
    /// Vast aantal decimalen, half naar boven afgerond.
    public static func nl(_ x: Double, decimalen: Int) -> String {
        let factor = pow(10, Double(decimalen))
        let afgerond = (abs(x) * factor + 0.5 + 1e-9).rounded(.down) / factor
        let tekst = String(format: "%.\(decimalen)f", afgerond)
        let delen = tekst.split(separator: ".", omittingEmptySubsequences: false)
        var heel = String(delen[0])
        var groepen: [String] = []
        while heel.count > 3 {
            groepen.insert(String(heel.suffix(3)), at: 0)
            heel = String(heel.dropLast(3))
        }
        groepen.insert(heel, at: 0)
        var s = groepen.joined(separator: ".")
        if delen.count > 1 { s += "," + delen[1] }
        return (x < 0 && afgerond > 0 ? "-" : "") + s
    }

    /// Hoogstens `maxDecimalen` decimalen, zonder overbodige nullen.
    public static func nl(_ x: Double, maxDecimalen: Int) -> String {
        var s = nl(x, decimalen: maxDecimalen)
        if s.contains(",") {
            while s.hasSuffix("0") { s.removeLast() }
            if s.hasSuffix(",") { s.removeLast() }
        }
        return s
    }
}
