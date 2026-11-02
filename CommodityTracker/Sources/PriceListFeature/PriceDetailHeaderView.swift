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
        VStack(alignment: .leading, spacing: PriceSpacing.small) {
            Text(commodity.unit)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let point {
                let date = Text(PriceFormatting.date(point.date, frequency: commodity.frequency, locale: locale))
                    .foregroundStyle(.secondary)

                Text(PriceFormatting.price(point.observation.value, locale: locale))
                    .font(.largeTitle.monospacedDigit())
                    .bold()
                // Stacks at large text sizes, where side by side would split the percent mid-number.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: PriceSpacing.medium) {
                        date
                        if let change {
                            PriceChangeLabel(change: change)
                        }
                    }
                    VStack(alignment: .leading, spacing: PriceSpacing.small) {
                        date
                        if let change {
                            PriceChangeLabel(change: change)
                        }
                    }
                }
                .font(.subheadline)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
