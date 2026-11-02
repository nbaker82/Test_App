import Core
import SwiftUI

/// The price side of a row: a spinner, the price with its date, or why it's missing.
struct PriceRowStateView: View {
    let state: PriceRowState
    let frequency: Frequency

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale

    var body: some View {
        switch state {
        case .loading:
            ProgressView()
                .accessibilityLabel(Text("Loading price", bundle: #bundle))
        case .loaded(let result):
            // The row stacks vertically at the largest text sizes, so the price lines up with the name.
            VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: PriceSpacing.tight) {
                Text(PriceFormatting.price(result.value.value, locale: locale))
                    .font(.title3.monospacedDigit())
                    .bold()
                Text(PriceFormatting.date(result.value.date, frequency: frequency, locale: locale))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .failed(let error):
            Label {
                Text(error.title)
            } icon: {
                Image(systemName: "exclamationmark.triangle")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}
