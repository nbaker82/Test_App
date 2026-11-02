import Foundation

public protocol PriceService: Sendable {
    /// The newest observation that has a value.
    func latest(seriesID: String) async throws -> PriceObservation

    /// Observations oldest first. A nil `start` means the full history.
    func observations(seriesID: String, start: Date?) async throws -> [PriceObservation]
}

public enum PriceServiceError: Error, Equatable, Sendable {
    case offline
    case rateLimited
    case server(status: Int)
    case unauthorized
    case badRequest(message: String?)
    case decoding
    case noData
    case unknown

    /// Whether a saved price is a reasonable answer to this failure. Failures that
    /// retrying won't fix must stay visible instead of hiding behind old data.
    public var allowsStaleFallback: Bool {
        switch self {
        case .offline, .rateLimited, .server:
            true
        case .unauthorized, .badRequest, .decoding, .noData, .unknown:
            false
        }
    }
}
