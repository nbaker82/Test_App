import Core
import SwiftUI

/// The price at the top of the detail screen: the latest one, or the point being dragged over.
struct PriceDetailHeaderView: View {
    let commodity: Commodity
    let point: ChartPoint?
    /// Hidden during a drag, because it describes the whole range rather than that point.
    let change: PriceChange?

    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(commodity.unit)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let point {
                Text(PriceFormatting.price(point.observation.value, locale: locale))
                    .font(.largeTitle.weight(.bold).monospacedDigit())
                HStack(spacing: 8) {
                    Text(PriceFormatting.date(point.date, frequency: commodity.frequency, locale: locale))
                        .foregroundStyle(.secondary)
                    if let change {
                        Label {
                            Text(change.fraction, format: .percent.precision(.fractionLength(1)).sign(strategy: .always()))
                                .monospacedDigit()
                        } icon: {
                            Image(systemName: change.isUp ? "arrow.up.right" : "arrow.down.right")
                        }
                        .foregroundStyle(change.isUp ? .green : .red)
                    }
                }
                .font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
