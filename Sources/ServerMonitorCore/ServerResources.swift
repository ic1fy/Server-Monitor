import Foundation

public struct MemoryReading: Equatable, Sendable {
    public let totalKiB: Double
    public let availableKiB: Double
    public var usedKiB: Double { max(0, totalKiB - availableKiB) }
    public var fraction: Double { totalKiB > 0 ? usedKiB / totalKiB : 0 }

    public init(totalKiB: Double, availableKiB: Double) {
        self.totalKiB = max(0, totalKiB)
        self.availableKiB = min(self.totalKiB, max(0, availableKiB))
    }
}

public struct DiskReading: Identifiable, Equatable, Sendable {
    public let mount: String
    public let totalKiB: Double
    public let usedKiB: Double
    public let availableKiB: Double
    public let usedPercent: Double
    public var id: String { mount }

    public init(mount: String, totalKiB: Double, usedKiB: Double, availableKiB: Double, usedPercent: Double) {
        self.mount = mount
        self.totalKiB = totalKiB
        self.usedKiB = usedKiB
        self.availableKiB = availableKiB
        self.usedPercent = usedPercent
    }
}

public enum ServerResourceParser {
    // Persistent local storage only; virtual, container and optical filesystems are omitted.
    private static let storageTypes: Set<String> = [
        "ext2", "ext3", "ext4", "xfs", "btrfs", "zfs", "f2fs", "bcachefs",
        "jfs", "reiserfs", "nilfs2", "vfat", "exfat", "ntfs", "ntfs3", "fuseblk"
    ]

    public static func parse(_ text: String, host: String) -> ServerSnapshot {
        var section = ""
        var gpuLines: [String] = []
        var disks: [DiskReading] = []
        var mounts = Set<String>()
        var cpu: Double?
        var memory: MemoryReading?

        for line in text.components(separatedBy: .newlines) {
            if line == "__GPU_BEGIN__" { section = "gpu"; continue }
            if line == "__DISK_BEGIN__" { section = "disk"; continue }
            if line == "__END__" { section = ""; continue }
            if line.hasPrefix("__CPU__ ") {
                if let value = finiteNumber(String(line.dropFirst(8))), (0...100).contains(value) { cpu = value }
                continue
            }
            if line.hasPrefix("__MEM__ ") {
                let values = line.split(whereSeparator: \.isWhitespace)
                if values.count == 3, let total = finiteNumber(String(values[1])), total > 0,
                   let available = finiteNumber(String(values[2])), available >= 0, available <= total {
                    memory = MemoryReading(totalKiB: total, availableKiB: available)
                }
                continue
            }
            if section == "gpu" { gpuLines.append(line) }
            if section == "disk", let disk = parseDisk(line), mounts.insert(disk.mount).inserted {
                disks.append(disk)
            }
        }
        let readings = (try? GPUCSVParser.parse(gpuLines.joined(separator: "\n"))) ?? []
        var unavailable: [String] = []
        if readings.isEmpty && gpuLines.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
            unavailable.append("GPU")
        }
        if cpu == nil { unavailable.append("CPU") }
        if memory == nil { unavailable.append("内存") }
        if disks.isEmpty { unavailable.append("磁盘") }
        return ServerSnapshot(host: host, readings: readings, cpuPercent: cpu, memory: memory,
                           disks: disks.sorted { $0.mount < $1.mount }, unavailableMetrics: unavailable)
    }

    private static func parseDisk(_ line: String) -> DiskReading? {
        // Keep the full mount path, including spaces, as the last field.
        let fields = line.split(maxSplits: 6, whereSeparator: \.isWhitespace).map(String.init)
        guard fields.count == 7,
              storageTypes.contains(fields[1]),
              !["/boot", "/boot/efi", "/efi"].contains(fields[6]),
              let total = finiteNumber(fields[2]), total > 0,
              let used = finiteNumber(fields[3]), used >= 0,
              let available = finiteNumber(fields[4]), available >= 0,
              let percent = finiteNumber(fields[5].replacingOccurrences(of: "%", with: "")) else { return nil }
        return DiskReading(mount: fields[6], totalKiB: total, usedKiB: used,
                           availableKiB: available, usedPercent: percent)
    }

    private static func finiteNumber(_ value: String) -> Double? {
        guard let number = Double(value.trimmingCharacters(in: .whitespaces)), number.isFinite else { return nil }
        return number
    }
}
