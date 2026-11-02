import Core
import SwiftUI

struct PriceRangePicker: View {
    @Bindable var model: PriceDetailModel

    var body: some View {
        Picker("Range", selection: $model.selectedRange) {
            ForEach(model.availableRanges, id: \.self) { range in
                Text(verbatim: range.rawValue)
            }
        }
        .pickerStyle(.segmented)
    }
}
