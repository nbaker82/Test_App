import SwiftUI

/// The move over the selected range. The arrow means direction doesn't rely on color alone.
struct PriceChangeLabel: View {
    let change: PriceChange

    var body: some View {
        Label {
            Text(change.fraction, format: .percent.precision(.fractionLength(1)).sign(strategy: .always()))
                .monospacedDigit()
        } icon: {
            Image(systemName: change.isUp ? "arrow.up.right" : "arrow.down.right")
        }
        .foregroundStyle(change.isUp ? Color.pricePositive : Color.priceNegative)
    }
}
