import SwiftUI

/// The view a detail screen zooms out of. Before iOS 18, and on macOS, navigation
/// uses the standard transition instead.
struct ZoomTransitionSource: ViewModifier {
    let id: String
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        #if os(iOS)
        if #available(iOS 18, *) {
            content.matchedTransitionSource(id: id, in: namespace)
        } else {
            content
        }
        #else
        content
        #endif
    }
}
