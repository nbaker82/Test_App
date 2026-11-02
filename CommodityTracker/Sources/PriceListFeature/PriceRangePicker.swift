import Core
import SwiftUI

struct PriceRangePicker: View {
    @Bindable var model: PriceDetailModel

    var body: some View {
        Picker(selection: $model.selectedRange) {
            ForEach(model.availableRanges, id: \.self) { range in
                Text(verbatim: range.rawValue)
                    .accessibilityLabel(Text(range.spokenName))
            }
        } label: {
            Text("Range", bundle: #bundle)
        }
        .pickerStyle(.segmented)
    }
}
