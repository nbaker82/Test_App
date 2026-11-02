import Core
import Foundation

extension PriceServiceError {
    var title: LocalizedStringResource {
        switch self {
        case .offline: .priceFeature("You're offline")
        case .rateLimited: .priceFeature("Too many requests")
        case .server: .priceFeature("FRED is unavailable")
        case .unauthorized: .priceFeature("API key needed")
        case .badRequest: .priceFeature("Request rejected")
        case .decoding: .priceFeature("Unexpected response")
        case .noData: .priceFeature("No recent price")
        case .unknown: .priceFeature("Something went wrong")
        }
    }

    var explanation: LocalizedStringResource {
        switch self {
        case .offline: .priceFeature("Prices will appear once you're back online.")
        case .rateLimited: .priceFeature("FRED is limiting requests. Wait a moment and try again.")
        case .server: .priceFeature("FRED isn't responding right now. Try again soon.")
        case .unauthorized: .priceFeature("Add a valid FRED API key to Config/Secrets.xcconfig, then rebuild the app.")
        case .badRequest: .priceFeature("FRED didn't accept the request for this price.")
        case .decoding: .priceFeature("FRED sent data this version of the app can't read.")
        case .noData: .priceFeature("FRED doesn't have a recent value for this commodity.")
        case .unknown: .priceFeature("The price couldn't be loaded. Try again.")
        }
    }

    /// The API key is fixed at build time, so trying again can't fix a bad one.
    var isRetryable: Bool {
        self != .unauthorized
    }
}
