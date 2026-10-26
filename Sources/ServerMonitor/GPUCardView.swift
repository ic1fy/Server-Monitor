import ServerMonitorCore
import SwiftUI

struct GPUCardView: View {
    @Environment(\.colorScheme) private var colorScheme
    let reading: GPUReading
    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("GPU \(reading.index)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.primary.opacity(0.87))
                Text(compactGPUName(reading.name))
                    .font(.system(size: 10.5)).foregroundStyle(Color.primary.opacity(0.43))
                    .lineLimit(1).help(reading.name)
                Spacer(minLength: 4)
            }
            HStack(spacing: 7) {
                DashboardMetric(title: "利用率", value: "\(Int(reading.utilizationPercent.rounded()))%",
                                systemImage: "gauge.with.dots.needle.50percent", tint: Color(red: 0.04, green: 0.48, blue: 0.98),
                                progress: reading.utilizationPercent / 100)
                DashboardMetric(title: "显存", value: "\(formatGiB(reading.memoryUsedMiB)) / \(formatGiB(reading.memoryTotalMiB))G",
                                systemImage: "memorychip", tint: Color(red: 0.56, green: 0.36, blue: 0.94),
                                progress: reading.memoryFraction)
            }
        }
        .padding(10).frame(maxWidth: .infinity).frame(height: 102)
        .background {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.075 : 0.045))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.055), lineWidth: 0.5)
        }
        .accessibilityElement(children: .combine)
    }
}

private func compactGPUName(_ name: String) -> String {
    name
        .replacingOccurrences(of: "NVIDIA ", with: "")
        .replacingOccurrences(of: "-SXM4", with: "")
}

private func formatGiB(_ mebibytes: Double) -> String {
    let gibibytes = mebibytes / 1024
    if gibibytes >= 10 {
        return String(format: "%.0f", gibibytes)
    }
    return String(format: "%.1f", gibibytes)
}
