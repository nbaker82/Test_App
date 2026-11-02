import SwiftUI

/// The screen that zooms out of a `ZoomTransitionSource` with the same ID.
struct ZoomTransitionDestination: ViewModifier {
    let id: String
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        #if os(iOS)
        if #available(iOS 18, *) {
            content.navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            content
        }
        #else
        content
        #endif
    }
}
