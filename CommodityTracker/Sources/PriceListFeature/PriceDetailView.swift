import Core
import SwiftUI

public struct PriceDetailView: View {
    @State private var model: PriceDetailModel
    @State private var selectedDate: Date?

    public init(model: PriceDetailModel) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch model.state {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let error):
                PriceFailureView(error: error, retry: retry)
            case .loaded(let result) where model.points.isEmpty:
                ContentUnavailableView("No prices in this range", systemImage: "chart.line.downtrend.xyaxis")
                if case .cached(let savedAt) = result.source {
                    SavedPriceLabel(savedAt: savedAt)
                }
            case .loaded(let result):
                let selectedPoint = selectedDate.flatMap(model.point(nearest:))
                PriceDetailHeaderView(
                    commodity: model.commodity,
                    point: selectedPoint ?? model.points.last,
                    change: selectedPoint == nil ? model.change : nil
                )
                PriceChartView(points: model.points, selectedPoint: selectedPoint, selectedDate: $selectedDate)
                    .opacity(model.isUpdating ? 0.5 : 1)
                if case .cached(let savedAt) = result.source {
                    SavedPriceLabel(savedAt: savedAt)
                }
            }

            PriceRangePicker(model: model)
        }
        .padding()
        .navigationTitle(model.commodity.name)
        .task(id: model.selectedRange) {
            await model.load()
        }
    }

    private func retry() {
        Task {
            await model.load()
        }
    }
}

#if DEBUG
#Preview("Daily") {
    NavigationStack {
        PriceDetailView(model: PriceDetailModel(commodity: .wti, repository: SamplePriceRepository()))
    }
}

#Preview("Monthly") {
    NavigationStack {
        PriceDetailView(model: PriceDetailModel(commodity: .corn, repository: SamplePriceRepository()))
    }
}

#Preview("Offline") {
    NavigationStack {
        PriceDetailView(model: PriceDetailModel(commodity: .corn, repository: SamplePriceRepository(failure: .offline)))
    }
}
#endif
