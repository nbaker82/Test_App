import Core
import Foundation
import Testing
@testable import Networking

private let liveAPIKey = ProcessInfo.processInfo.environment["FRED_API_KEY"]

/// Calls the real API, so these only run with FRED_API_KEY set:
/// FRED_API_KEY=your_key swift test --filter LiveFREDTests
@Suite(.enabled(if: liveAPIKey != nil, "Set FRED_API_KEY to call the live API"))
struct LiveFREDTests {
    private var client: FREDClient { FREDClient(apiKey: liveAPIKey ?? "") }

    @Test(arguments: Commodity.catalog)
    func latestPriceIsRecentAndPositive(commodity: Commodity) async throws {
        let latest = try await client.latest(seriesID: commodity.seriesID)

        #expect(latest.value > 0)
        let oneYearAgo = try #require(TimeRange.oneYear.start(endingAt: Date()))
        #expect(latest.date > oneYearAgo)
    }

    @Test(arguments: Commodity.catalog)
    func historyIsOldestFirstAndStartsInRange(commodity: Commodity) async throws {
        let start = try #require(TimeRange.fiveYears.start(endingAt: Date()))

        let history = try await client.observations(seriesID: commodity.seriesID, start: start)

        #expect(!history.isEmpty)
        #expect(history.map(\.date) == history.map(\.date).sorted())
        // FRED includes the month containing the start date, so a monthly series can begin before it.
        let startOfMonth = try #require(Calendar.utc.dateInterval(of: .month, for: start)?.start)
        #expect(history.first.map { $0.date >= startOfMonth } == true)
    }

    @Test func unknownSeriesIsABadRequest() async {
        await #expect {
            try await client.latest(seriesID: "NOT_A_REAL_SERIES")
        } throws: { error in
            guard case PriceServiceError.badRequest(let message?) = error else { return false }
            return !message.isEmpty
        }
    }

    @Test func emptyKeyIsUnauthorized() async {
        let client = FREDClient(apiKey: "")

        await #expect(throws: PriceServiceError.unauthorized) {
            try await client.latest(seriesID: Commodity.wti.seriesID)
        }
    }

    @Test func unregisteredKeyIsUnauthorized() async {
        let client = FREDClient(apiKey: "abcdefghijklmnopqrstuvwxyz123456")

        await #expect(throws: PriceServiceError.unauthorized) {
            try await client.latest(seriesID: Commodity.wti.seriesID)
        }
    }
}
