import SwiftUI
import AppKit

struct EnergyListView: View {
    @ObservedObject var monitor: EnergyMonitor
    var onSelect: (AppEnergy) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if monitor.topApps.isEmpty {
                Text("No Apps Using Significant Energy")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Text("Using Significant Energy")
                    .font(.subheadline.weight(.semibold))
                ForEach(monitor.topApps) { app in
                    Button { onSelect(app) } label: {
                        EnergyRow(app: app)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct EnergyRow: View {
    let app: AppEnergy

    var body: some View {
        HStack(spacing: 8) {
            iconView
                .frame(width: 18, height: 18)
            Text(app.displayName)
                .font(.callout)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
            Text(badgeText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var iconView: some View {
        if let icon = app.icon {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
        } else {
            Image(systemName: "app.dashed")
                .foregroundStyle(.secondary)
        }
    }

    private var badgeText: String {
        switch app.powerImpact {
        case 50...: return "High"
        case 10..<50: return "Medium"
        default: return String(format: "%.0f", app.powerImpact)
        }
    }
}
