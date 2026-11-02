import Charts
import SwiftUI

/// The small graph on a row. Purely decorative for VoiceOver, because the row already
/// reads out the price and the detail screen has the full chart.
struct SparklineView: View {
    let points: [ChartPoint]

    var body: some View {
        Chart(points) { point in
            LineMark(x: .value("Date", point.date), y: .value("Price", point.plotValue))
                .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartYScale(domain: .automatic(includesZero: false))
        // Keeps the row's layout steady before there are enough points to draw a line.
        .opacity(points.count > 1 ? 1 : 0)
        .frame(width: 64, height: 28)
        .accessibilityHidden(true)
    }
}
