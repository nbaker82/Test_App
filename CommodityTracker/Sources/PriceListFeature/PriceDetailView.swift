import Core
import SwiftUI

public struct PriceDetailView: View {
    @State private var model: PriceDetailModel
    @State private var selectedDate: Date?

    public init(model: PriceDetailModel) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PriceSpacing.extraLarge) {
            switch model.state {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let error):
                PriceFailureView(error: error, retry: retry)
            case .loaded(let result):
                if model.points.isEmpty {
                    ContentUnavailableView {
                        Label {
                            Text("No prices in this range", bundle: #bundle)
                        } icon: {
                            Image(systemName: "chart.line.downtrend.xyaxis")
                        }
                    }
                } else {
                    PriceDetailLoadedView(model: model, selectedDate: $selectedDate)
                }
                if case .cached(let savedAt) = result.source {
                    SavedPriceLabel(savedAt: savedAt)
                }
            }

            PriceRangePicker(model: model)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.priceScreenBackground)
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
