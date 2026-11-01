import Foundation
import Testing
@testable import Core

private let usLocale = Locale(identifier: "en_US")

private func utcDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
    Calendar.utc.date(from: DateComponents(year: year, month: month, day: day))!
}

@Suite struct CatalogTests {
    @Test func containsTheFourVerifiedSeries() {
        #expect(Commodity.catalog.map(\.seriesID) == ["DCOILWTICO", "PMAIZMTUSDM", "PWHEAMTUSDM", "PSOYBUSDM"])
    }

    @Test func onlyOilIsDaily() {
        #expect(Commodity.catalog.filter { $0.frequency == .daily } == [.wti])
    }
}

@Suite struct TimeRangeTests {
    @Test func monthlySeriesOfferOnlyLongRanges() {
        #expect(TimeRange.available(for: .monthly) == [.oneYear, .fiveYears, .max])
    }

    @Test func dailySeriesOfferEveryRange() {
        #expect(TimeRange.available(for: .daily) == TimeRange.allCases)
    }

    @Test func maxHasNoStart() {
        #expect(TimeRange.max.start(endingAt: utcDate(2026, 11, 1)) == nil)
    }

    @Test func startsAreComputedInUTC() {
        let end = utcDate(2026, 9, 1)
        #expect(TimeRange.oneMonth.start(endingAt: end) == utcDate(2026, 8, 1))
        #expect(TimeRange.sixMonths.start(endingAt: end) == utcDate(2026, 3, 1))
        #expect(TimeRange.oneYear.start(endingAt: end) == utcDate(2025, 9, 1))
        #expect(TimeRange.fiveYears.start(endingAt: end) == utcDate(2021, 9, 1))
    }
}

@Suite struct PriceFormattingTests {
    @Test func roundsPricesToCents() {
        let price = Decimal(string: "236.9161241071429")!
        #expect(PriceFormatting.price(price, locale: usLocale) == "$236.92")
    }

    @Test func monthlyDateStaysInItsOwnMonth() {
        // Run the suite with TZ=America/Chicago to exercise the zone this guards against.
        #expect(PriceFormatting.date(utcDate(2026, 9, 1), frequency: .monthly, locale: usLocale) == "Sep 2026")
    }

    @Test func dailyDateIncludesTheDay() {
        #expect(PriceFormatting.date(utcDate(2026, 10, 27), frequency: .daily, locale: usLocale) == "Oct 27, 2026")
    }
}

@Suite struct PriceServiceErrorTests {
    @Test func onlyTransientFailuresAllowStaleData() {
        #expect(PriceServiceError.offline.allowsStaleFallback)
        #expect(PriceServiceError.rateLimited.allowsStaleFallback)
        #expect(PriceServiceError.server(status: 503).allowsStaleFallback)
        #expect(!PriceServiceError.unauthorized.allowsStaleFallback)
        #expect(!PriceServiceError.badRequest(message: nil).allowsStaleFallback)
        #expect(!PriceServiceError.decoding.allowsStaleFallback)
        #expect(!PriceServiceError.noData.allowsStaleFallback)
    }
}
