import Core
import Foundation
import Repository
@testable import PriceListFeature

actor FakePriceRepository: PriceRepository {
    private var results: [Commodity.ID: Result<Sourced<PriceObservation>, any Error>]
    private var historyResults: [Commodity.ID: Result<Sourced<[PriceObservation]>, any Error>] = [:]
    private(set) var requestedRanges: [TimeRange] = []

    init(_ results: [Commodity.ID: Result<Sourced<PriceObservation>, any Error>] = [:]) {
        self.results = results
    }

    func set(_ result: Result<Sourced<PriceObservation>, any Error>, for commodity: Commodity) {
        results[commodity.id] = result
    }

    func setHistory(_ result: Result<Sourced<[PriceObservation]>, any Error>, for commodity: Commodity) {
        historyResults[commodity.id] = result
    }

    func latest(for commodity: Commodity) throws -> Sourced<PriceObservation> {
        guard let result = results[commodity.id] else { throw PriceServiceError.noData }
        return try result.get()
    }

    func history(for commodity: Commodity, range: TimeRange) throws -> Sourced<[PriceObservation]> {
        requestedRanges.append(range)
        guard let result = historyResults[commodity.id] else {
            return Sourced(value: [], source: .live)
        }
        return try result.get()
    }
}
