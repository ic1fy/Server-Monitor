import Foundation
import ServerMonitorCore

func check(_ value: @autoclosure () -> Bool, _ message: String) {
    precondition(value(), message)
}
let rows = (0..<8).reversed().map { "\($0), NVIDIA A100, GPU-\($0), \($0 * 10), 1024, 81920" }.joined(separator: "\n")
let readings = try GPUCSVParser.parse("Welcome\n" + rows)
check(readings.count == 8 && readings.map(\.index) == Array(0..<8), "Dynamic GPU count and sorting")
let single = try GPUCSVParser.parse("0, NVIDIA A100, GPU-0, 10, 1024, 81920")
check(single.count == 1, "One GPU")
for invalid in ["", "0, bad, GPU-0, nan, 0, 81920", "0, bad, GPU-0, 10, inf, 81920", "0, bad"] {
    do { _ = try GPUCSVParser.parse(invalid); fatalError("Accepted invalid GPU data") }
    catch is GPUCSVParserError {}
}
let payload = """
Welcome to the server
__GPU_BEGIN__
\(rows)
__END__
__CPU__ 35.5
__MEM__ 1000000 650000
__DISK_BEGIN__
Filesystem Type 1024-blocks Used Available Capacity Mounted on
        efivarfs efivarfs 304 49 251 17% /sys/firmware/efi/efivars
        tmpfs tmpfs 1000000 100 999900 1% /tmp
        overlay overlay 1000000 200000 800000 20% /var/lib/docker/overlay2/test/merged
        /dev/loop0 squashfs 10000 10000 0 100% /snap/core/1
        /dev/sr0 iso9660 10000 10000 0 100% /media/cdrom
/dev/sda2 ext4 200000 6000 190000 4% /boot/efi
/dev/sda3 ext4 500000 100000 400000 20% /boot
/dev/sdc1 ext4 200000 6000 190000 4% /efi
/dev/sda1 ext4 1000000 200000 750000 22% /
/dev/sdb1 ext4 2000000 500000 1500000 25% /data sets
/dev/sdb1 ext4 2000000 500000 1500000 25% /data sets
__END__
"""
let snapshot = ServerResourceParser.parse(payload, host: "test")
check(snapshot.readings.count == 8, "All GPUs retained")
check(snapshot.cpuPercent == 35.5, "CPU percentage")
check(snapshot.memory?.usedKiB == 350000, "Available memory excludes reclaimable cache")
check(snapshot.disks.count == 2, "Boot partitions hidden; system and data mounts retained without duplicates")
check(snapshot.disks[1].mount == "/data sets", "Mount paths with spaces")
check(snapshot.disks[0].availableKiB == 750000 && snapshot.disks[0].usedPercent == 22, "df available and percentage preserved")
check(snapshot.unavailableMetrics.isEmpty, "All resources available")
check(snapshot.hasMetrics, "Valid metrics accepted")
check(snapshot.totalDiskKiB == 3000000, "Summary adds mounted disk capacities")
check(!ServerResourceParser.parse("Welcome", host: "empty").hasMetrics, "SSH banners are not successful metrics")
let partial = ServerResourceParser.parse("__CPU__ 12\n__MEM__ 100 40", host: "cpu-only")
check(partial.cpuPercent == 12 && partial.memory?.usedKiB == 60, "Non-GPU resources survive missing nvidia-smi")
check(partial.hasMetrics, "CPU-only servers remain valid")
check(partial.unavailableMetrics == ["磁盘"], "GPU is optional on CPU-only servers")
let malformedGPU = ServerResourceParser.parse("__GPU_BEGIN__\n0, bad\n__END__\n__CPU__ 10", host: "gpu-error")
check(malformedGPU.unavailableMetrics.contains("GPU"), "Malformed GPU output remains visible")
let invalid = ServerResourceParser.parse("__CPU__ nan\n__MEM__ 100 101\n__DISK_BEGIN__\n/dev/a ext4 nan 0 0 0% /", host: "bad")
check(invalid.cpuPercent == nil && invalid.memory == nil && invalid.disks.isEmpty, "Invalid values cannot reach UI")
print("Core verification passed: GPU counts, malformed data, CPU, memory, disks and partial results")
