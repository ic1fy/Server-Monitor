import Foundation

public struct GPUReading: Identifiable, Equatable, Sendable {
    public let index: Int
    public let name: String
    public let uuid: String
    public let utilizationPercent: Double
    public let memoryUsedMiB: Double
    public let memoryTotalMiB: Double

    public var id: String { uuid }

    public var memoryFraction: Double {
        guard memoryTotalMiB > 0 else { return 0 }
        return min(1, max(0, memoryUsedMiB / memoryTotalMiB))
    }

    public init(
        index: Int,
        name: String,
        uuid: String,
        utilizationPercent: Double,
        memoryUsedMiB: Double,
        memoryTotalMiB: Double
    ) {
        self.index = index
        self.name = name
        self.uuid = uuid
        self.utilizationPercent = utilizationPercent
        self.memoryUsedMiB = memoryUsedMiB
        self.memoryTotalMiB = memoryTotalMiB
    }
}

public enum GPUCSVParserError: LocalizedError, Equatable {
    case noReadings
    case invalidRow(String)

    public var errorDescription: String? {
        switch self {
        case .noReadings:
            return "nvidia-smi 没有返回 GPU 数据"
        case let .invalidRow(row):
            return "无法解析 GPU 数据：\(row)"
        }
    }
}

public enum GPUCSVParser {
    public static func parse(_ text: String) throws -> [GPUReading] {
        var readings: [GPUReading] = []

        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            let fields = line
                .split(separator: ",", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

            // SSH login banners and MOTDs are ignored. A line that starts like a
            // GPU row is treated strictly so format changes remain visible.
            guard fields.count == 6 else {
                if Int(fields.first ?? "") != nil {
                    throw GPUCSVParserError.invalidRow(line)
                }
                continue
            }

            guard
                let index = Int(fields[0]),
                let utilization = parseRequiredNumber(fields[3]),
                let memoryUsed = parseRequiredNumber(fields[4]),
                let memoryTotal = parseRequiredNumber(fields[5])
            else {
                throw GPUCSVParserError.invalidRow(line)
            }

            readings.append(
                GPUReading(
                    index: index,
                    name: fields[1],
                    uuid: fields[2],
                    utilizationPercent: min(100, max(0, utilization)),
                    memoryUsedMiB: max(0, memoryUsed),
                    memoryTotalMiB: max(0, memoryTotal)
                )
            )
        }

        guard !readings.isEmpty else {
            throw GPUCSVParserError.noReadings
        }
        return readings.sorted { $0.index < $1.index }
    }

    private static func parseRequiredNumber(_ value: String) -> Double? {
        guard let number = Double(value), number.isFinite else { return nil }
        return number
    }

}
