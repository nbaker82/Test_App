import PriceListFeature
import SwiftUI

struct AppRootView: View {
    @State private var model: PriceListModel?

    var body: some View {
        if let model {
            PriceListView(model: model)
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.priceScreenBackground)
                .task(makeModel)
        }
    }

    private func makeModel() async {
        model = PriceListModel(repository: await AppDependencies.makeRepository())
    }
}
