import SwiftUI

struct MetricProgressBar: View {
    @Environment(\.colorScheme) private var colorScheme
    let progress: Double
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            let fraction = min(1, max(0, progress))
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(colorScheme == .dark ? 0.16 : 0.09))
                if fraction > 0 {
                    Capsule()
                        .fill(tint.gradient)
                        .frame(width: max(6, proxy.size.width * fraction))
                }
            }
        }
        .frame(height: 7)
        .animation(.easeInOut(duration: 0.25), value: progress)
    }
}

struct DashboardMetric: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color
    let progress: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                Text(title)
                    .foregroundStyle(Color.primary.opacity(0.46))
            }
            .font(.system(size: 9.5, weight: .medium))

            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.primary.opacity(0.80))
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            if let progress {
                MetricProgressBar(progress: progress, tint: tint)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 54)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.035))
        }
    }
}
