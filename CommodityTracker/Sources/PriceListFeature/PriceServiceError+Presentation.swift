import Core
import Foundation

extension PriceServiceError {
    var title: LocalizedStringResource {
        switch self {
        case .offline: "You're offline"
        case .rateLimited: "Too many requests"
        case .server: "FRED is unavailable"
        case .unauthorized: "API key needed"
        case .badRequest: "Request rejected"
        case .decoding: "Unexpected response"
        case .noData: "No recent price"
        case .unknown: "Something went wrong"
        }
    }

    var explanation: LocalizedStringResource {
        switch self {
        case .offline: "Prices will appear once you're back online."
        case .rateLimited: "FRED is limiting requests. Wait a moment and try again."
        case .server: "FRED isn't responding right now. Try again soon."
        case .unauthorized: "Add a valid FRED API key to Config/Secrets.xcconfig, then rebuild the app."
        case .badRequest: "FRED didn't accept the request for this price."
        case .decoding: "FRED sent data this version of the app can't read."
        case .noData: "FRED doesn't have a recent value for this commodity."
        case .unknown: "The price couldn't be loaded. Try again."
        }
    }

    /// The API key is fixed at build time, so trying again can't fix a bad one.
    var isRetryable: Bool {
        self != .unauthorized
    }
}
