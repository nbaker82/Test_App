import SwiftUI

/// Marks data that came from the cache rather than the network.
struct SavedPriceLabel: View {
    let savedAt: Date

    var body: some View {
        Label {
            Text("Saved \(savedAt, format: .relative(presentation: .named))")
        } icon: {
            Image(systemName: "clock.arrow.circlepath")
        }
        .font(.caption)
        .foregroundStyle(.orange)
    }
}
