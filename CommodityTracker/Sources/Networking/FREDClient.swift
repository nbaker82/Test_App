import Core
import Foundation

public struct FREDClient: PriceService {
    /// Enough rows to reach a real value past a run of "." days, like a long holiday weekend.
    private static let latestLookback = 10

    private let apiKey: String
    private let transport: any HTTPTransport
    private let baseURL: URL

    public init(
        apiKey: String,
        transport: any HTTPTransport = URLSession.shared,
        baseURL: URL = URL(string: "https://api.stlouisfed.org/fred/series/observations")!
    ) {
        self.apiKey = apiKey
        self.transport = transport
        self.baseURL = baseURL
    }

    public func latest(seriesID: String) async throws -> PriceObservation {
        let observations = try await fetch(seriesID: seriesID, parameters: [
            "sort_order": "desc",
            "limit": String(Self.latestLookback),
        ])
        guard let newest = observations.first else { throw PriceServiceError.noData }
        return newest
    }

    public func observations(seriesID: String, start: Date?) async throws -> [PriceObservation] {
        var parameters = ["sort_order": "asc"]
        if let start {
            parameters["observation_start"] = start.formatted(FREDDate.style)
        }
        return try await fetch(seriesID: seriesID, parameters: parameters)
    }

    private func fetch(seriesID: String, parameters: [String: String]) async throws -> [PriceObservation] {
        let request = try makeRequest(seriesID: seriesID, parameters: parameters)
        let (data, response) = try await send(request)
        guard let http = response as? HTTPURLResponse else { throw PriceServiceError.decoding }
        try Self.validate(status: http.statusCode, body: data)
        do {
            return try JSONDecoder()
                .decode(FREDObservationsResponse.self, from: data)
                .observations
                .compactMap { try $0.toObservation() }
        } catch {
            throw PriceServiceError.decoding
        }
    }

    private func makeRequest(seriesID: String, parameters: [String: String]) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw PriceServiceError.badRequest(message: nil)
        }
        let allParameters = parameters.merging([
            "series_id": seriesID,
            "api_key": apiKey,
            "file_type": "json",
        ]) { _, required in required }
        components.queryItems = allParameters
            .sorted { $0.key < $1.key }
            .map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components.url else {
            throw PriceServiceError.badRequest(message: nil)
        }
        return URLRequest(url: url)
    }

    /// Maps transport failures here so a URLError, whose userInfo holds the request URL
    /// and therefore the API key, never reaches a log or the UI.
    private func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await transport.send(request)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch is URLError {
            throw PriceServiceError.offline
        }
    }

    private static func validate(status: Int, body: Data) throws {
        switch status {
        case 200..<300:
            return
        case 401, 403:
            throw PriceServiceError.unauthorized
        case 429:
            throw PriceServiceError.rateLimited
        case 400..<500:
            let message = (try? JSONDecoder().decode(FREDErrorBody.self, from: body))?.errorMessage
            // FRED reports a bad key as a 400, so only the message tells it apart.
            if message?.contains("api_key") == true {
                throw PriceServiceError.unauthorized
            }
            throw PriceServiceError.badRequest(message: message)
        default:
            throw PriceServiceError.server(status: status)
        }
    }
}
