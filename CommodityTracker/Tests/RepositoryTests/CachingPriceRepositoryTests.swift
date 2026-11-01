import Core
import Foundation
import Testing
@testable import Repository

private actor StubService: PriceService {
    var latestResult: Result<PriceObservation, any Error>
    var historyResult: Result<[PriceObservation], any Error>
    private(set) var requestedStarts: [Date?] = []

    init(
        latest: Result<PriceObservation, any Error> = .failure(PriceServiceError.noData),
        history: Result<[PriceObservation], any Error> = .failure(PriceServiceError.noData)
    ) {
        latestResult = latest
        historyResult = history
    }

    func setLatest(_ result: Result<PriceObservation, any Error>) {
        latestResult = result
    }

    func setHistory(_ result: Result<[PriceObservation], any Error>) {
        historyResult = result
    }

    func latest(seriesID: String) throws -> PriceObservation {
        try latestResult.get()
    }

    func observations(seriesID: String, start: Date?) throws -> [PriceObservation] {
        requestedStarts.append(start)
        return try historyResult.get()
    }
}

private func utcDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
    Calendar.utc.date(from: DateComponents(year: year, month: month, day: day))!
}

private func observation(_ year: Int, _ month: Int, _ value: Decimal) -> PriceObservation {
    PriceObservation(date: utcDate(year, month, 1), value: value)
}

private let savedAt = utcDate(2026, 10, 23)

private func makeRepository(_ service: StubService, cache: InMemoryPriceCache = InMemoryPriceCache()) -> CachingPriceRepository {
    CachingPriceRepository(service: service, cache: cache, now: { savedAt })
}

@Suite struct LatestPriceTests {
    @Test func liveResultIsReturnedAndSaved() async throws {
        let price = observation(2026, 9, 236.92)
        let cache = InMemoryPriceCache()
        let repository = makeRepository(StubService(latest: .success(price)), cache: cache)

        let result = try await repository.latest(for: .corn)

        #expect(result == Sourced(value: price, source: .live))
        #expect(await cache.load(seriesID: Commodity.corn.seriesID)?.observations == [price])
    }

    @Test(arguments: [
        PriceServiceError.offline,
        .rateLimited,
        .server(status: 503),
    ])
    func transientFailureReturnsTheSavedPrice(error: PriceServiceError) async throws {
        let price = observation(2026, 9, 236.92)
        let service = StubService(latest: .success(price))
        let repository = makeRepository(service)
        _ = try await repository.latest(for: .corn)
        await service.setLatest(.failure(error))

        let result = try await repository.latest(for: .corn)

        #expect(result == Sourced(value: price, source: .cached(savedAt: savedAt)))
    }

    @Test(arguments: [
        PriceServiceError.unauthorized,
        .badRequest(message: "nope"),
        .decoding,
        .noData,
    ])
    func permanentFailureIsNotHiddenBySavedData(error: PriceServiceError) async throws {
        let service = StubService(latest: .success(observation(2026, 9, 236.92)))
        let repository = makeRepository(service)
        _ = try await repository.latest(for: .corn)
        await service.setLatest(.failure(error))

        await #expect(throws: error) {
            try await repository.latest(for: .corn)
        }
    }

    @Test func transientFailureWithEmptyCacheRethrows() async {
        let repository = makeRepository(StubService(latest: .failure(PriceServiceError.offline)))

        await #expect(throws: PriceServiceError.offline) {
            try await repository.latest(for: .corn)
        }
    }

    @Test func cachesAreKeptPerSeries() async throws {
        let service = StubService(latest: .success(observation(2026, 9, 236.92)))
        let repository = makeRepository(service)
        _ = try await repository.latest(for: .corn)
        await service.setLatest(.failure(PriceServiceError.offline))

        await #expect(throws: PriceServiceError.offline) {
            try await repository.latest(for: .wheat)
        }
    }

    @Test func cancellationPassesThrough() async throws {
        let service = StubService(latest: .success(observation(2026, 9, 236.92)))
        let repository = makeRepository(service)
        _ = try await repository.latest(for: .corn)
        await service.setLatest(.failure(CancellationError()))

        await #expect(throws: CancellationError.self) {
            try await repository.latest(for: .corn)
        }
    }
}

@Suite struct HistoryTests {
    private let rows = [
        observation(2020, 9, 150),
        observation(2026, 8, 221.30),
        observation(2026, 9, 236.92),
    ]

    @Test func liveHistoryRequestsTheRangeStart() async throws {
        let service = StubService(history: .success(rows))
        let repository = makeRepository(service)

        let result = try await repository.history(for: .corn, range: .oneYear)

        #expect(result == Sourced(value: rows, source: .live))
        #expect(await service.requestedStarts == [utcDate(2025, 10, 23)])
    }

    @Test func maxRequestsFullHistory() async throws {
        let service = StubService(history: .success(rows))
        let repository = makeRepository(service)

        _ = try await repository.history(for: .corn, range: .max)

        #expect(await service.requestedStarts == [nil])
    }

    @Test func offlineHistoryIsFilteredToTheRange() async throws {
        let service = StubService(history: .success(rows))
        let repository = makeRepository(service)
        _ = try await repository.history(for: .corn, range: .max)
        await service.setHistory(.failure(PriceServiceError.offline))

        let result = try await repository.history(for: .corn, range: .oneYear)

        #expect(result == Sourced(value: Array(rows.suffix(2)), source: .cached(savedAt: savedAt)))
    }

    @Test func offlineWithNothingInRangeRethrows() async throws {
        let service = StubService(history: .success([observation(2020, 9, 150)]))
        let repository = makeRepository(service)
        _ = try await repository.history(for: .corn, range: .max)
        await service.setHistory(.failure(PriceServiceError.offline))

        await #expect(throws: PriceServiceError.offline) {
            try await repository.history(for: .corn, range: .oneYear)
        }
    }
}

@Suite struct InMemoryPriceCacheTests {
    @Test func savesMergeByDateAndSortOldestFirst() async {
        let cache = InMemoryPriceCache()
        await cache.save([observation(2026, 9, 1), observation(2026, 7, 2)], seriesID: "S", at: savedAt)
        await cache.save([observation(2026, 8, 3), observation(2026, 9, 4)], seriesID: "S", at: savedAt)

        let stored = await cache.load(seriesID: "S")

        #expect(stored?.observations == [observation(2026, 7, 2), observation(2026, 8, 3), observation(2026, 9, 4)])
    }

    @Test func unknownSeriesLoadsNil() async {
        #expect(await InMemoryPriceCache().load(seriesID: "S") == nil)
    }
}
