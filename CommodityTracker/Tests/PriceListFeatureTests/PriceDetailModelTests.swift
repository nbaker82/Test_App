import Core
import Foundation
import Repository
import Testing
@testable import PriceListFeature

private func day(_ number: Int, _ value: Decimal = 100) -> PriceObservation {
    PriceObservation(date: Date(timeIntervalSince1970: Double(number) * 86_400), value: value)
}

private let rows = [day(0, 100), day(1, 110), day(2, 125)]
private let liveRows = Sourced(value: rows, source: .live)

@MainActor
@Suite struct PriceDetailModelTests {
    private func makeModel(
        commodity: Commodity = .corn,
        history: Result<Sourced<[PriceObservation]>, any Error> = .success(liveRows)
    ) async -> (PriceDetailModel, FakePriceRepository) {
        let repository = FakePriceRepository()
        await repository.setHistory(history, for: commodity)
        return (PriceDetailModel(commodity: commodity, repository: repository), repository)
    }

    @Test func startsLoadingOneYear() async {
        let (model, _) = await makeModel()

        #expect(model.state == .loading)
        #expect(model.selectedRange == .oneYear)
    }

    @Test func rangesFollowTheCommodityFrequency() async {
        let (monthly, _) = await makeModel(commodity: .corn)
        let (daily, _) = await makeModel(commodity: .wti)

        #expect(monthly.availableRanges == [.oneYear, .fiveYears, .max])
        #expect(daily.availableRanges == TimeRange.allCases)
    }

    @Test func loadRequestsTheSelectedRange() async {
        let (model, repository) = await makeModel()
        model.selectedRange = .fiveYears

        await model.load()

        #expect(await repository.requestedRanges == [.fiveYears])
        #expect(model.state == .loaded(liveRows))
    }

    @Test func loadBuildsPointsAndChange() async throws {
        let (model, _) = await makeModel()

        await model.load()

        #expect(model.points.map(\.observation) == rows)
        #expect(!model.isUpdating)
        let change = try #require(model.change)
        #expect(abs(change.fraction - 0.25) < 0.000_001)
        #expect(change.isUp)
    }

    @Test func fallingPriceIsDown() async throws {
        let (model, _) = await makeModel(history: .success(Sourced(value: [day(0, 200), day(1, 150)], source: .live)))

        await model.load()

        let change = try #require(model.change)
        #expect(abs(change.fraction + 0.25) < 0.000_001)
        #expect(!change.isUp)
    }

    @Test func emptyRangeHasNoPointsOrChange() async {
        let (model, _) = await makeModel(history: .success(Sourced(value: [], source: .live)))

        await model.load()

        #expect(model.points.isEmpty)
        #expect(model.change == nil)
    }

    @Test func failureShowsAndClearsThePoints() async {
        let (model, repository) = await makeModel()
        await model.load()
        await repository.setHistory(.failure(PriceServiceError.unauthorized), for: .corn)

        await model.load()

        #expect(model.state == .failed(.unauthorized))
        #expect(model.points.isEmpty)
        #expect(!model.isUpdating)
    }

    @Test func retryRecovers() async {
        let (model, repository) = await makeModel(history: .failure(PriceServiceError.offline))
        await model.load()
        await repository.setHistory(.success(liveRows), for: .corn)

        await model.load()

        #expect(model.state == .loaded(liveRows))
    }

    @Test func cancelledLoadKeepsTheChart() async {
        let (model, repository) = await makeModel()
        await model.load()
        await repository.setHistory(.failure(CancellationError()), for: .corn)

        await model.load()

        #expect(model.state == .loaded(liveRows))
    }

    @Test func answerForAnOldRangeIsIgnored() async {
        let (model, repository) = await makeModel()
        let staleLoad = Task { await model.load() }
        model.selectedRange = .max
        await staleLoad.value
        // Whichever range staleLoad captured, the newest selection decides what's shown.
        await repository.setHistory(.success(Sourced(value: [day(9)], source: .live)), for: .corn)

        await model.load()

        #expect(model.state == .loaded(Sourced(value: [day(9)], source: .live)))
        #expect(!model.isUpdating)
    }

    @Test func nearestPointFollowsTheDrag() async {
        let (model, _) = await makeModel()
        await model.load()

        let nearest = model.point(nearest: day(1).date.addingTimeInterval(3_600))

        #expect(nearest?.observation == day(1, 110))
    }

    @Test func summaryDescribesARise() async {
        let (model, _) = await makeModel()
        await model.load()

        #expect(model.chartSummary(locale: Locale(identifier: "en_US")) == "Up 25.0%, from $100.00 to $125.00")
    }

    @Test func summaryDescribesAFall() async {
        let (model, _) = await makeModel(history: .success(Sourced(value: [day(0, 200), day(1, 150)], source: .live)))
        await model.load()

        #expect(model.chartSummary(locale: Locale(identifier: "en_US")) == "Down 25.0%, from $200.00 to $150.00")
    }

    @Test func summaryOfOnePointIsItsPrice() async {
        let (model, _) = await makeModel(history: .success(Sourced(value: [day(0, 200)], source: .live)))
        await model.load()

        #expect(model.chartSummary(locale: Locale(identifier: "en_US")) == "$200.00")
    }

    @Test func summaryOfNoPointsIsEmpty() async {
        let (model, _) = await makeModel()

        #expect(model.chartSummary(locale: Locale(identifier: "en_US")).isEmpty)
    }

    @Test func noPointsMeansNoNearestPoint() async {
        let (model, _) = await makeModel()

        #expect(model.point(nearest: .now) == nil)
    }
}

@Suite struct ChartPointTests {
    private let series = (0..<1_000).map { day($0, Decimal($0)) }

    @Test func shortSeriesIsUnchanged() {
        #expect(ChartPoint.points(from: rows, maxCount: 10).map(\.observation) == rows)
    }

    @Test func longSeriesIsCappedKeepingBothEnds() {
        let points = ChartPoint.points(from: series, maxCount: 60)

        #expect(points.count <= 60)
        #expect(points.count > 30)
        #expect(points.first?.observation == series.first)
        #expect(points.last?.observation == series.last)
    }

    @Test func extremesSurviveThinning() {
        var spiky = (0..<10_000).map { day($0, 50) }
        spiky[3_333] = day(3_333, 145)
        spiky[7_777] = day(7_777, -36)

        let values = ChartPoint.points(from: spiky, maxCount: 500).map(\.observation.value)

        #expect(values.contains(145))
        #expect(values.contains(-36))
    }

    @Test func flatSeriesDoesNotRepeatPoints() {
        let flat = (0..<1_000).map { day($0, 5) }

        let dates = ChartPoint.points(from: flat, maxCount: 60).map(\.date)

        #expect(Set(dates).count == dates.count)
    }

    @Test func thinnedSeriesStaysInOrderWithoutDuplicates() {
        let dates = ChartPoint.points(from: series, maxCount: 500).map(\.date)

        #expect(dates == dates.sorted())
        #expect(Set(dates).count == dates.count)
    }

    @Test func emptySeriesIsEmpty() {
        #expect(ChartPoint.points(from: [], maxCount: 10).isEmpty)
    }

    @Test func plotValueMatchesThePrice() {
        let point = ChartPoint(observation: day(0, Decimal(string: "236.5")!))

        #expect(point.plotValue == 236.5)
    }
}

@Suite struct PriceChangeTests {
    @Test func needsTwoPoints() {
        #expect(PriceChange(observations: [day(0)]) == nil)
        #expect(PriceChange(observations: []) == nil)
    }

    @Test func zeroStartHasNoPercentage() {
        #expect(PriceChange(observations: [day(0, 0), day(1, 5)]) == nil)
    }

    @Test func unchangedPriceCountsAsUp() throws {
        let change = try #require(PriceChange(observations: [day(0, 5), day(1, 5)]))

        #expect(change.fraction == 0)
        #expect(change.isUp)
    }
}
