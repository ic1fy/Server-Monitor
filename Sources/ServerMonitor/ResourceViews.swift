import ServerMonitorCore
import SwiftUI

struct ServerResourcesView: View {
    let snapshot: ServerSnapshot

    var body: some View {
        VStack(spacing: 8) {
            if !snapshot.readings.isEmpty {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 8) {
                    ForEach(snapshot.readings.sorted { $0.index < $1.index }) { reading in
                        GPUCardView(reading: reading)
                    }
                }
            }
            HStack(spacing: 10) {
                DashboardMetric(title: "CPU", value: snapshot.cpuPercent.map { "\(Int($0.rounded()))%" } ?? "—",
                                systemImage: "cpu", tint: Color(red: 0.04, green: 0.48, blue: 0.98),
                                progress: snapshot.cpuPercent.map { $0 / 100 })
                DashboardMetric(title: "内存", value: snapshot.memory.map { "\(capacity($0.usedKiB)) / \(capacity($0.totalKiB))" } ?? "—",
                                systemImage: "memorychip", tint: Color(red: 0.56, green: 0.36, blue: 0.94),
                                progress: snapshot.memory?.fraction)
            }
            if !snapshot.disks.isEmpty {
                DiskUsageView(disks: snapshot.disks)
            }
            if !snapshot.unavailableMetrics.isEmpty {
                Text("\(snapshot.unavailableMetrics.joined(separator: "、"))暂不可用")
                    .font(.system(size: 10.5)).foregroundStyle(.secondary)
            }
        }
    }
}

private struct DiskUsageView: View {
    let disks: [DiskReading]
    @State private var hoveredDiskID: DiskReading.ID?
    private let storageTint = Color(red: 0.10, green: 0.66, blue: 0.47)

    var body: some View {
        VStack(spacing: 10) {
            ForEach(disks) { disk in
                VStack(spacing: 5) {
                    HStack(spacing: 5) {
                        Image(systemName: "internaldrive").foregroundStyle(storageTint)
                        Text(title(for: disk))
                            .foregroundStyle(Color.primary.opacity(0.62))
                        if hoveredDiskID == disk.id {
                            Text("· \(disk.mount)")
                                .foregroundStyle(Color.primary.opacity(0.42))
                        }
                        Spacer()
                        Text("剩余 \(capacity(disk.availableKiB))")
                            .foregroundStyle(Color.primary.opacity(0.47))
                    }.font(.system(size: 10.5, weight: .medium))
                    HStack {
                        Text("\(capacity(disk.usedKiB)) / \(capacity(disk.totalKiB))")
                        Spacer()
                        Text("\(Int(disk.usedPercent))%")
                    }.font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit().foregroundStyle(Color.primary.opacity(0.80))
                    MetricProgressBar(progress: disk.usedPercent / 100,
                                      tint: disk.usedPercent >= 90 ? .orange : storageTint)
                }
                .onHover { isHovered in
                    hoveredDiskID = isHovered ? disk.id : nil
                }
                .help(disk.mount)
            }
        }
        .padding(10)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func title(for disk: DiskReading) -> String {
        guard disks.count > 1, let index = disks.firstIndex(where: { $0.id == disk.id }) else {
            return "磁盘"
        }
        return "磁盘 \(index + 1)"
    }
}
