import Foundation

func capacity(_ kibibytes: Double) -> String {
    let gib = kibibytes / 1048576
    if gib >= 1024 { return String(format: "%.1fT", gib / 1024) }
    if gib < 1 { return String(format: "%.0fM", kibibytes / 1024) }
    return String(format: gib >= 100 ? "%.0fG" : "%.1fG", gib)
}
