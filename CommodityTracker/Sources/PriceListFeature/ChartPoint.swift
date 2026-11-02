import Core
import Foundation

/// An observation ready to plot. Charts need a Double, while the exact Decimal stays
/// available for showing the price.
struct ChartPoint: Identifiable, Equatable, Sendable {
    let observation: PriceObservation
    let plotValue: Double

    var id: Date { observation.date }
    var date: Date { observation.date }

    init(observation: PriceObservation) {
        self.observation = observation
        plotValue = NSDecimalNumber(decimal: observation.value).doubleValue
    }

    /// Evenly thins the series to at most `maxCount` points, always keeping the first and
    /// last. WTI's full history is around 10,000 rows, far more than a chart can show.
    static func points(from observations: [PriceObservation], maxCount: Int) -> [ChartPoint] {
        guard observations.count > maxCount, maxCount > 1 else {
            return observations.map(ChartPoint.init)
        }
        let step = Double(observations.count - 1) / Double(maxCount - 1)
        return (0..<maxCount).map { index in
            ChartPoint(observation: observations[Int((Double(index) * step).rounded())])
        }
    }
}
