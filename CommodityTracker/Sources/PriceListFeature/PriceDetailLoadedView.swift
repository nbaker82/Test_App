import SwiftUI

/// The header and chart. When the window is short, as in landscape, the header moves
/// beside the chart so the chart keeps its height.
struct PriceDetailLoadedView: View {
    let model: PriceDetailModel
    @Binding var selectedDate: Date?

    @Environment(\.locale) private var locale
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        let selectedPoint = selectedDate.flatMap(model.point(nearest:))
        let layout = verticalSizeClass == .compact
            ? AnyLayout(HStackLayout(alignment: .top, spacing: PriceSpacing.extraLarge))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: PriceSpacing.extraLarge))

        layout {
            PriceDetailHeaderView(
                commodity: model.commodity,
                point: selectedPoint ?? model.points.last,
                change: selectedPoint == nil ? model.change : nil
            )
            PriceChartView(
                points: model.points,
                selectedPoint: selectedPoint,
                summary: model.chartSummary(locale: locale),
                selectedDate: $selectedDate
            )
            .opacity(model.isUpdating ? 0.5 : 1)
        }
    }
}
