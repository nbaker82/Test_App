import Core
import SwiftUI

struct PriceFailureView: View {
    let error: PriceServiceError
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label {
                Text(error.title)
            } icon: {
                Image(systemName: "exclamationmark.triangle")
            }
        } description: {
            Text(error.explanation)
        } actions: {
            if error.isRetryable {
                Button("Try Again", action: retry)
            }
        }
    }
}
