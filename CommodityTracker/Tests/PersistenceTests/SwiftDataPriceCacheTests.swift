import Core
import Foundation
import Repository
import SwiftData
import Testing
@testable import Persistence

private func utcDate(_ year: Int, _ month: Int, _ day: Int = 1) -> Date {
    Calendar.utc.date(from: DateComponents(year: year, month: month, day: day))!
}

private func observation(_ year: Int, _ month: Int, _ value: String) -> PriceObservation {
    PriceObservation(date: utcDate(year, month), value: Decimal(string: value)!)
}

private let firstSave = utcDate(2026, 10, 23)
private let secondSave = utcDate(2026, 10, 24)

/// A store on disk, removed when the test ends.
private func withStoreURL(_ body: (URL) async throws -> Void) async throws {
    let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    try await body(folder.appending(path: "nested/prices.store"))
}

private func makeCache() throws -> SwiftDataPriceCache {
    SwiftDataPriceCache(modelContainer: try PriceStore.makeInMemoryContainer())
}

@Suite struct SwiftDataPriceCacheTests {
    @Test func unknownSeriesLoadsNil() async throws {
        let cache = try makeCache()

        #expect(try await cache.load(seriesID: "S") == nil)
    }

    @Test func pricesRoundTripExactly() async throws {
        let cache = try makeCache()
        let price = observation(2026, 9, "236.9161241071429")

        try await cache.save([price], seriesID: "S", at: firstSave)

        let stored = try await cache.load(seriesID: "S")
        #expect(stored == CachedSeries(observations: [price], savedAt: firstSave))
    }

    @Test func savesMergeByDateAndSortOldestFirst() async throws {
        let cache = try makeCache()
        try await cache.save([observation(2026, 9, "1"), observation(2026, 7, "2")], seriesID: "S", at: firstSave)
        try await cache.save([observation(2026, 8, "3"), observation(2026, 9, "4")], seriesID: "S", at: secondSave)

        let stored = try await cache.load(seriesID: "S")

        #expect(stored?.observations == [observation(2026, 7, "2"), observation(2026, 8, "3"), observation(2026, 9, "4")])
        #expect(stored?.savedAt == secondSave)
    }

    @Test func revisedValueReplacesAfterItWasLoaded() async throws {
        let cache = try makeCache()
        try await cache.save([observation(2026, 9, "1")], seriesID: "S", at: firstSave)
        _ = try await cache.load(seriesID: "S")

        try await cache.save([observation(2026, 9, "2")], seriesID: "S", at: secondSave)

        let stored = try await cache.load(seriesID: "S")
        #expect(stored == CachedSeries(observations: [observation(2026, 9, "2")], savedAt: secondSave))
    }

    @Test func duplicateDatesInOneSaveKeepTheLast() async throws {
        let cache = try makeCache()

        try await cache.save([observation(2026, 9, "1"), observation(2026, 9, "2")], seriesID: "S", at: firstSave)

        let stored = try await cache.load(seriesID: "S")
        #expect(stored?.observations == [observation(2026, 9, "2")])
    }

    @Test func savingOneRowLeavesTheRestOfTheHistory() async throws {
        let cache = try makeCache()
        let history = [observation(2026, 7, "1"), observation(2026, 8, "2"), observation(2026, 9, "3")]
        try await cache.save(history, seriesID: "S", at: firstSave)

        try await cache.save([observation(2026, 8, "9")], seriesID: "S", at: secondSave)

        let stored = try await cache.load(seriesID: "S")
        #expect(stored?.observations == [observation(2026, 7, "1"), observation(2026, 8, "9"), observation(2026, 9, "3")])
    }

    @Test func seriesAreKeptApart() async throws {
        let cache = try makeCache()
        try await cache.save([observation(2026, 9, "1")], seriesID: "A", at: firstSave)
        try await cache.save([observation(2026, 9, "2")], seriesID: "B", at: secondSave)

        #expect(try await cache.load(seriesID: "A") == CachedSeries(observations: [observation(2026, 9, "1")], savedAt: firstSave))
        #expect(try await cache.load(seriesID: "B") == CachedSeries(observations: [observation(2026, 9, "2")], savedAt: secondSave))
    }

    @Test func matchesTheInMemoryCacheOnEmptySaves() async throws {
        let swiftData = try makeCache()
        let inMemory = InMemoryPriceCache()

        try await swiftData.save([], seriesID: "S", at: firstSave)
        await inMemory.save([], seriesID: "S", at: firstSave)

        let swiftDataResult = try await swiftData.load(seriesID: "S")
        let inMemoryResult = await inMemory.load(seriesID: "S")
        #expect(swiftDataResult == inMemoryResult)
    }

    @Test func corruptValueThrows() async throws {
        let container = try PriceStore.makeInMemoryContainer()
        let cache = SwiftDataPriceCache(modelContainer: container)
        try await cache.save([], seriesID: "S", at: firstSave)
        let context = ModelContext(container)
        let record = ObservationRecord(seriesID: "S", date: utcDate(2026, 9), value: 1)
        record.value = "not a number"
        context.insert(record)
        try context.save()

        await #expect(throws: PersistenceError.corruptValue(record.key)) {
            try await cache.load(seriesID: "S")
        }
    }
}

@Suite struct RelaunchTests {
    @Test func pricesSurviveReopeningTheStore() async throws {
        try await withStoreURL { url in
            let rows = [observation(2026, 8, "221.3034955803572"), observation(2026, 9, "236.9161241071429")]
            do {
                let cache = SwiftDataPriceCache(modelContainer: try PriceStore.makeContainer(at: url))
                try await cache.save(rows, seriesID: "S", at: firstSave)
            }

            let reopened = SwiftDataPriceCache(modelContainer: try PriceStore.makeContainer(at: url))

            let stored = try await reopened.load(seriesID: "S")
            #expect(stored == CachedSeries(observations: rows, savedAt: firstSave))
        }
    }

    @Test func savesMergeAcrossReopens() async throws {
        try await withStoreURL { url in
            do {
                let cache = SwiftDataPriceCache(modelContainer: try PriceStore.makeContainer(at: url))
                try await cache.save([observation(2026, 8, "1"), observation(2026, 9, "2")], seriesID: "S", at: firstSave)
            }

            let reopened = SwiftDataPriceCache(modelContainer: try PriceStore.makeContainer(at: url))
            try await reopened.save([observation(2026, 9, "3")], seriesID: "S", at: secondSave)

            let stored = try await reopened.load(seriesID: "S")
            #expect(stored == CachedSeries(observations: [observation(2026, 8, "1"), observation(2026, 9, "3")], savedAt: secondSave))
        }
    }

    @Test func largeSeriesSavesAndReloads() async throws {
        try await withStoreURL { url in
            let rows = (0..<10_000).map { day in
                PriceObservation(
                    date: Calendar.utc.date(byAdding: .day, value: day, to: utcDate(1986, 1))!,
                    value: Decimal(day) + Decimal(string: "0.25")!
                )
            }
            let cache = SwiftDataPriceCache(modelContainer: try PriceStore.makeContainer(at: url))

            try await cache.save(rows, seriesID: "DCOILWTICO", at: firstSave)
            try await cache.save(rows, seriesID: "DCOILWTICO", at: secondSave)

            let stored = try await cache.load(seriesID: "DCOILWTICO")
            #expect(stored?.observations == rows)
        }
    }
}

private struct FailingService: PriceService {
    let price: PriceObservation?

    func latest(seriesID: String) throws -> PriceObservation {
        guard let price else { throw PriceServiceError.offline }
        return price
    }

    func observations(seriesID: String, start: Date?) throws -> [PriceObservation] {
        throw PriceServiceError.offline
    }
}

@Suite struct RepositoryIntegrationTests {
    @Test func savedPriceIsServedOfflineAfterARelaunch() async throws {
        try await withStoreURL { url in
            let price = observation(2026, 9, "236.9161241071429")
            do {
                let cache = SwiftDataPriceCache(modelContainer: try PriceStore.makeContainer(at: url))
                let online = CachingPriceRepository(service: FailingService(price: price), cache: cache, now: { firstSave })
                _ = try await online.latest(for: .corn)
            }

            let cache = SwiftDataPriceCache(modelContainer: try PriceStore.makeContainer(at: url))
            let offline = CachingPriceRepository(service: FailingService(price: nil), cache: cache, now: { secondSave })

            let result = try await offline.latest(for: .corn)

            #expect(result == Sourced(value: price, source: .cached(savedAt: firstSave)))
        }
    }
}
