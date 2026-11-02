import Foundation

extension LocalizedStringResource {
    /// Text from this package, which lives in its own bundle rather than the app's.
    static func priceFeature(_ key: String.LocalizationValue) -> LocalizedStringResource {
        LocalizedStringResource(key, bundle: .atURL(Bundle.module.bundleURL))
    }
}
