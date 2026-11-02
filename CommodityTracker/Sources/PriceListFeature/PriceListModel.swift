import Core
import Observation
import Repository

@MainActor
@Observable
public final class PriceListModel {
    private nonisolated static let sparklineRange = TimeRange.oneYear
    private nonisolated static let maxSparklinePoints = 60

    public private(set) var rows: [PriceRow]

    private let repository: any PriceRepository

    public init(repository: any PriceRepository, commodities: [Commodity] = Commodity.catalog) {
        self.repository = repository
        rows = commodities.map { PriceRow(commodity: $0, state: .loading) }
    }

    /// Set when every row failed the same way, such as a missing API key,
    /// so the screen can say so once rather than repeating it on each row.
    public var sharedFailure: PriceServiceError? {
        guard case .failed(let failure)? = rows.first?.state,
              rows.allSatisfy({ $0.state == .failed(failure) })
        else { return nil }
        return failure
    }

    public func makeDetailModel(for commodity: Commodity) -> PriceDetailModel {
        PriceDetailModel(commodity: commodity, repository: repository)
    }

    /// Fetches every price at once, updating each row as its result arrives.
    /// Rows that already have a price keep showing it until the new one is in.
    public func load() async {
        let previousRows = rows
        for index in rows.indices {
            if case .failed = rows[index].state {
                rows[index].state = .loading
            }
        }

        let repository = repository
        await withTaskGroup(of: (Int, PriceRowState?, [ChartPoint]?).self) { group in
            for (index, row) in previousRows.enumerated() {
                let commodity = row.commodity
                group.addTask {
                    async let state = Self.fetchState(for: commodity, from: repository)
                    async let sparkline = Self.fetchSparkline(for: commodity, from: repository)
                    return (index, await state, await sparkline)
                }
            }
            for await (index, state, sparkline) in group {
                // A cancelled fetch has no answer, so put back what the row showed before.
                rows[index].state = state ?? previousRows[index].state
                rows[index].sparkline = sparkline ?? previousRows[index].sparkline
            }
        }
    }

    private nonisolated static func fetchState(
        for commodity: Commodity,
        from repository: any PriceRepository
    ) async -> PriceRowState? {
        do {
            return .loaded(try await repository.latest(for: commodity))
        } catch is CancellationError {
            return nil
        } catch let error as PriceServiceError {
            return .failed(error)
        } catch {
            return .failed(.unknown)
        }
    }

    /// The sparkline is a nice extra, so failing to load one never fails the row.
    private nonisolated static func fetchSparkline(
        for commodity: Commodity,
        from repository: any PriceRepository
    ) async -> [ChartPoint]? {
        guard let history = try? await repository.history(for: commodity, range: sparklineRange) else {
            return nil
        }
        return ChartPoint.points(from: history.value, maxCount: maxSparklinePoints)
    }
}
