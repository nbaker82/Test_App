import Core
import SwiftUI

public struct PriceListView: View {
    let model: PriceListModel

    @Namespace private var zoomNamespace

    public init(model: PriceListModel) {
        self.model = model
    }

    public var body: some View {
        NavigationStack {
            Group {
                if let failure = model.sharedFailure {
                    PriceFailureView(error: failure, retry: retry)
                } else {
                    List(model.rows) { row in
                        NavigationLink(value: row.commodity) {
                            PriceRowView(row: row)
                                .modifier(ZoomTransitionSource(id: row.id, namespace: zoomNamespace))
                        }
                        .listRowBackground(Color.priceCardBackground)
                    }
                    .scrollContentBackground(.hidden)
                    .refreshable(action: model.load)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.priceScreenBackground)
            .navigationTitle(Text("Commodities", bundle: #bundle))
            .navigationDestination(for: Commodity.self) { commodity in
                PriceDetailView(model: model.makeDetailModel(for: commodity))
                    .modifier(ZoomTransitionDestination(id: commodity.id, namespace: zoomNamespace))
            }
        }
        .task(model.load)
    }

    private func retry() {
        Task {
            await model.load()
        }
    }
}

#if DEBUG
#Preview("Prices") {
    PriceListView(model: PriceListModel(repository: SamplePriceRepository()))
}

#Preview("Missing API key") {
    PriceListView(model: PriceListModel(repository: SamplePriceRepository(failure: .unauthorized)))
}

#Preview("Offline") {
    PriceListView(model: PriceListModel(repository: SamplePriceRepository(failure: .offline)))
}
#endif
