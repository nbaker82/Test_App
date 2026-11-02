import Charts
import Core
import SwiftUI

struct PriceChartView: View {
    let points: [ChartPoint]
    let selectedPoint: ChartPoint?
    /// What VoiceOver reads for the chart as a whole.
    let summary: String
    @Binding var selectedDate: Date?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale

    private var span: TimeInterval {
        guard let first = points.first?.date, let last = points.last?.date else { return 0 }
        return last.timeIntervalSince(first)
    }

    /// A label this close to the edge would be clipped, leaving a stray "2" or "Au…".
    private func isNearTrailingEdge(_ date: Date) -> Bool {
        guard let last = points.last?.date else { return false }
        return last.timeIntervalSince(date) < span * 0.12
    }

    var body: some View {
        Chart {
            ForEach(points) { point in
                LineMark(x: .value("Date", point.date), y: .value("Price", point.plotValue))
                    .foregroundStyle(.tint)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
            if let selectedPoint {
                RuleMark(x: .value("Selected date", selectedPoint.date))
                    .foregroundStyle(.secondary)
                PointMark(x: .value("Date", selectedPoint.date), y: .value("Price", selectedPoint.plotValue))
                    .foregroundStyle(.tint)
            }
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartXSelection(value: $selectedDate)
        .chartXAxis {
            // Fewer labels at the largest text sizes, where four would truncate to "Fe…".
            AxisMarks(values: .automatic(desiredCount: dynamicTypeSize.isAccessibilitySize ? 2 : 4)) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    // Formatted here because the default label uses the device's time zone,
                    // which shows Sep 1 UTC as August anywhere west of Greenwich.
                    if let date = value.as(Date.self), !isNearTrailingEdge(date) {
                        Text(PriceFormatting.axisDate(
                            date,
                            span: span,
                            isCompact: dynamicTypeSize.isAccessibilitySize,
                            locale: locale
                        ))
                    }
                }
            }
        }
        // One summary rather than up to 500 separate points to swipe through.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Price history", bundle: #bundle))
        .accessibilityValue(summary)
    }
}
