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

    /// Thins the series to at most `maxCount` points, because WTI's full history is around
    /// 10,000 rows. Keeps the first, the last, and each bucket's high and low. Even sampling
    /// would skip extremes like April 2020's negative oil price and misstate the chart.
    static func points(from observations: [PriceObservation], maxCount: Int) -> [ChartPoint] {
        guard observations.count > maxCount, maxCount >= 4 else {
            return observations.map(ChartPoint.init)
        }
        let lastIndex = observations.count - 1
        let interiorCount = lastIndex - 1
        let bucketCount = (maxCount - 2) / 2

        var indices = [0]
        for bucket in 0..<bucketCount {
            let bucketStart = 1 + bucket * interiorCount / bucketCount
            let bucketEnd = 1 + (bucket + 1) * interiorCount / bucketCount
            let range = bucketStart..<bucketEnd
            guard let low = range.min(by: { observations[$0].value < observations[$1].value }),
                  let high = range.max(by: { observations[$0].value < observations[$1].value })
            else { continue }
            indices.append(min(low, high))
            if low != high {
                indices.append(max(low, high))
            }
        }
        indices.append(lastIndex)
        return indices.map { ChartPoint(observation: observations[$0]) }
    }
}
