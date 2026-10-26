import Foundation

public struct ServerSnapshot: Equatable, Sendable {
    public let host: String
    public let readings: [GPUReading]
    public let fetchedAt: Date
    public let cpuPercent: Double?
    public let memory: MemoryReading?
    public let disks: [DiskReading]
    public let unavailableMetrics: [String]

    public var hasMetrics: Bool {
        !readings.isEmpty || cpuPercent != nil || memory != nil || !disks.isEmpty
    }

    public var totalDiskKiB: Double {
        disks.reduce(0) { $0 + $1.totalKiB }
    }

    public init(host: String, readings: [GPUReading], fetchedAt: Date = Date(),
                cpuPercent: Double? = nil, memory: MemoryReading? = nil,
                disks: [DiskReading] = [], unavailableMetrics: [String] = []) {
        self.host = host
        self.readings = readings
        self.fetchedAt = fetchedAt
        self.cpuPercent = cpuPercent
        self.memory = memory
        self.disks = disks
        self.unavailableMetrics = unavailableMetrics
    }
}
