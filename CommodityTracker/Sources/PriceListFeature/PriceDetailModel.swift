import Core
import Foundation
import Observation
import Repository

@MainActor
@Observable
public final class PriceDetailModel {
    private static let maxChartPoints = 500

    public let commodity: Commodity
    public let availableRanges: [TimeRange]
    public var selectedRange: TimeRange = .oneYear

    private(set) var state: PriceDetailState = .loading {
        didSet { updateDerivedValues() }
    }
    /// True while a new range loads over the chart that's already showing.
    private(set) var isUpdating = false
    // Stored rather than computed because the view reads them on every frame of a drag.
    private(set) var points: [ChartPoint] = []
    private(set) var change: PriceChange?

    private let repository: any PriceRepository

    public init(commodity: Commodity, repository: any PriceRepository) {
        self.commodity = commodity
        self.repository = repository
        availableRanges = TimeRange.available(for: commodity.frequency)
    }

    public func load() async {
        let range = selectedRange
        let previousState = state
        if case .failed = state {
            state = .loading
        }
        isUpdating = true

        let newState = await fetchState(for: range)

        // The range may have changed while this was loading, and only the newest answer counts.
        guard range == selectedRange, !Task.isCancelled else { return }
        state = newState ?? previousState
        isUpdating = false
    }

    func point(nearest date: Date) -> ChartPoint? {
        points.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
    }

    private func fetchState(for range: TimeRange) async -> PriceDetailState? {
        do {
            return .loaded(try await repository.history(for: commodity, range: range))
        } catch is CancellationError {
            return nil
        } catch let error as PriceServiceError {
            return .failed(error)
        } catch {
            return .failed(.unknown)
        }
    }

    private func updateDerivedValues() {
        guard case .loaded(let result) = state else {
            points = []
            change = nil
            return
        }
        points = ChartPoint.points(from: result.value, maxCount: Self.maxChartPoints)
        change = PriceChange(observations: result.value)
    }
}
