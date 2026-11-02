import Core
import Foundation
import Repository
import Testing
@testable import PriceListFeature

private struct UnexpectedError: Error {}

private let observation = PriceObservation(date: Date(timeIntervalSince1970: 0), value: 100)
private let live = Sourced(value: observation, source: .live)
private let cached = Sourced(value: observation, source: .cached(savedAt: Date(timeIntervalSince1970: 60)))

@MainActor
@Suite struct PriceListModelTests {
    private func state(of commodity: Commodity, in model: PriceListModel) -> PriceRowState? {
        model.rows.first { $0.commodity == commodity }?.state
    }

    @Test func startsWithEveryCommodityLoading() {
        let model = PriceListModel(repository: FakePriceRepository())

        #expect(model.rows.map(\.commodity) == Commodity.catalog)
        #expect(model.rows.allSatisfy { $0.state == .loading })
        #expect(model.sharedFailure == nil)
    }

    @Test func rowsStayInCatalogOrderWithTheirOwnResults() async {
        let repository = FakePriceRepository([
            Commodity.corn.id: .success(live),
            Commodity.wheat.id: .success(cached),
        ])
        let model = PriceListModel(repository: repository, commodities: [.corn, .wheat])

        await model.load()

        #expect(model.rows.map(\.commodity) == [.corn, .wheat])
        #expect(state(of: .corn, in: model) == .loaded(live))
        #expect(state(of: .wheat, in: model) == .loaded(cached))
    }

    @Test func oneFailureDoesNotAffectOtherRows() async {
        let repository = FakePriceRepository([
            Commodity.corn.id: .success(live),
            Commodity.wheat.id: .failure(PriceServiceError.server(status: 500)),
        ])
        let model = PriceListModel(repository: repository, commodities: [.corn, .wheat])

        await model.load()

        #expect(state(of: .corn, in: model) == .loaded(live))
        #expect(state(of: .wheat, in: model) == .failed(.server(status: 500)))
        #expect(model.sharedFailure == nil)
    }

    @Test func sameFailureEverywhereIsShared() async {
        let repository = FakePriceRepository([
            Commodity.corn.id: .failure(PriceServiceError.unauthorized),
            Commodity.wheat.id: .failure(PriceServiceError.unauthorized),
        ])
        let model = PriceListModel(repository: repository, commodities: [.corn, .wheat])

        await model.load()

        #expect(model.sharedFailure == .unauthorized)
    }

    @Test func differentFailuresAreNotShared() async {
        let repository = FakePriceRepository([
            Commodity.corn.id: .failure(PriceServiceError.unauthorized),
            Commodity.wheat.id: .failure(PriceServiceError.offline),
        ])
        let model = PriceListModel(repository: repository, commodities: [.corn, .wheat])

        await model.load()

        #expect(model.sharedFailure == nil)
    }

    @Test func retryRecoversFromFailure() async {
        let repository = FakePriceRepository([Commodity.corn.id: .failure(PriceServiceError.offline)])
        let model = PriceListModel(repository: repository, commodities: [.corn])
        await model.load()
        await repository.set(.success(live), for: .corn)

        await model.load()

        #expect(state(of: .corn, in: model) == .loaded(live))
    }

    @Test func refreshFailureReplacesThePrice() async {
        let repository = FakePriceRepository([Commodity.corn.id: .success(live)])
        let model = PriceListModel(repository: repository, commodities: [.corn])
        await model.load()
        await repository.set(.failure(PriceServiceError.unauthorized), for: .corn)

        await model.load()

        #expect(state(of: .corn, in: model) == .failed(.unauthorized))
    }

    @Test func cancelledRefreshKeepsThePrice() async {
        let repository = FakePriceRepository([Commodity.corn.id: .success(live)])
        let model = PriceListModel(repository: repository, commodities: [.corn])
        await model.load()
        await repository.set(.failure(CancellationError()), for: .corn)

        await model.load()

        #expect(state(of: .corn, in: model) == .loaded(live))
    }

    @Test func cancelledRetryDoesNotLeaveASpinner() async {
        let repository = FakePriceRepository([Commodity.corn.id: .failure(PriceServiceError.offline)])
        let model = PriceListModel(repository: repository, commodities: [.corn])
        await model.load()
        await repository.set(.failure(CancellationError()), for: .corn)

        await model.load()

        #expect(state(of: .corn, in: model) == .failed(.offline))
    }

    @Test func sparklineShowsOneYearOfHistory() async {
        let repository = FakePriceRepository([Commodity.corn.id: .success(live)])
        await repository.setHistory(.success(Sourced(value: [observation], source: .live)), for: .corn)
        let model = PriceListModel(repository: repository, commodities: [.corn])

        await model.load()

        #expect(model.rows.first?.sparkline.map(\.observation) == [observation])
        #expect(await repository.requestedRanges == [.oneYear])
    }

    @Test func sparklineIsThinnedForLongDailySeries() async {
        let history = (0..<250).map { PriceObservation(date: Date(timeIntervalSince1970: Double($0) * 86_400), value: Decimal($0)) }
        let repository = FakePriceRepository([Commodity.wti.id: .success(live)])
        await repository.setHistory(.success(Sourced(value: history, source: .live)), for: .wti)
        let model = PriceListModel(repository: repository, commodities: [.wti])

        await model.load()

        let count = model.rows.first?.sparkline.count ?? 0
        #expect(count > 1 && count <= 60)
    }

    @Test func sparklineFailureLeavesThePriceAndPreviousLine() async {
        let repository = FakePriceRepository([Commodity.corn.id: .success(live)])
        await repository.setHistory(.success(Sourced(value: [observation], source: .live)), for: .corn)
        let model = PriceListModel(repository: repository, commodities: [.corn])
        await model.load()
        await repository.setHistory(.failure(PriceServiceError.offline), for: .corn)

        await model.load()

        #expect(state(of: .corn, in: model) == .loaded(live))
        #expect(model.rows.first?.sparkline.map(\.observation) == [observation])
    }

    @Test func detailModelIsForTheChosenCommodity() {
        let model = PriceListModel(repository: FakePriceRepository())

        #expect(model.makeDetailModel(for: .wheat).commodity == .wheat)
    }

    @Test func unexpectedErrorsBecomeUnknown() async {
        let repository = FakePriceRepository([Commodity.corn.id: .failure(UnexpectedError())])
        let model = PriceListModel(repository: repository, commodities: [.corn])

        await model.load()

        #expect(state(of: .corn, in: model) == .failed(.unknown))
    }
}
