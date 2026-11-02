import SwiftUI

struct PriceRowView: View {
    let row: PriceRow

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // Side by side runs out of room at the largest text sizes.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: PriceSpacing.medium))
            : AnyLayout(HStackLayout(alignment: .center, spacing: PriceSpacing.large))

        layout {
            VStack(alignment: .leading, spacing: PriceSpacing.tight) {
                Text(row.commodity.name)
                    .font(.headline)
                Text(row.commodity.unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                // Under the name so its width can't push the sparkline out of line with other rows.
                if case .loaded(let result) = row.state, case .cached(let savedAt) = result.source {
                    SavedPriceLabel(savedAt: savedAt)
                }
            }
            if !dynamicTypeSize.isAccessibilitySize {
                Spacer(minLength: 0)
                SparklineView(points: row.sparkline)
            }
            PriceRowStateView(state: row.state, frequency: row.commodity.frequency)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, PriceSpacing.small)
        .accessibilityElement(children: .combine)
    }
}
