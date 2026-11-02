import Core
import Foundation
import Testing
@testable import Networking

private actor StubTransport: HTTPTransport {
    private let result: Result<(Data, Int), any Error>
    private(set) var requests: [URLRequest] = []

    init(_ result: Result<(Data, Int), any Error>) {
        self.result = result
    }

    func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        let (data, status) = try result.get()
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        return (data, response)
    }
}

private func fixture(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
    return try Data(contentsOf: url)
}

private func utcDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
    Calendar.utc.date(from: DateComponents(year: year, month: month, day: day))!
}

private func queryItems(_ request: URLRequest?) throws -> [String: String] {
    let url = try #require(request?.url)
    let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
}

@Suite struct FREDClientTests {
    @Test func decodesTheRealCornResponse() async throws {
        let transport = StubTransport(.success((try fixture("corn_monthly"), 200)))
        let client = FREDClient(apiKey: "test-key", transport: transport)

        let latest = try await client.latest(seriesID: "PMAIZMTUSDM")

        #expect(latest.date == utcDate(2026, 9, 1))
        #expect(latest.value == Decimal(string: "236.9161241071429"))
    }

    @Test func latestSkipsMissingValues() async throws {
        let transport = StubTransport(.success((try fixture("synthetic_wti_with_missing"), 200)))
        let client = FREDClient(apiKey: "test-key", transport: transport)

        let latest = try await client.latest(seriesID: "DCOILWTICO")

        #expect(latest.date == utcDate(2026, 10, 27))
        #expect(latest.value == Decimal(string: "103.37"))
    }

    @Test func latestRequestsNewestRowsFirst() async throws {
        let transport = StubTransport(.success((try fixture("corn_monthly"), 200)))
        let client = FREDClient(apiKey: "test-key", transport: transport)

        _ = try await client.latest(seriesID: "PMAIZMTUSDM")

        let items = try queryItems(await transport.requests.first)
        #expect(items["series_id"] == "PMAIZMTUSDM")
        #expect(items["api_key"] == "test-key")
        #expect(items["file_type"] == "json")
        #expect(items["sort_order"] == "desc")
        #expect(items["limit"] == "10")
    }

    @Test func latestThrowsNoDataWhenEveryValueIsMissing() async throws {
        let body = Data(#"{"observations":[{"date":"2026-10-28","value":"."}]}"#.utf8)
        let client = FREDClient(apiKey: "test-key", transport: StubTransport(.success((body, 200))))

        await #expect(throws: PriceServiceError.noData) {
            try await client.latest(seriesID: "DCOILWTICO")
        }
    }

    @Test func observationsSendTheStartDateInUTC() async throws {
        let transport = StubTransport(.success((try fixture("corn_monthly"), 200)))
        let client = FREDClient(apiKey: "test-key", transport: transport)

        _ = try await client.observations(seriesID: "PMAIZMTUSDM", start: utcDate(2025, 9, 1))

        let items = try queryItems(await transport.requests.first)
        #expect(items["observation_start"] == "2025-09-01")
        #expect(items["sort_order"] == "asc")
    }

    @Test func fullHistorySendsNoStartDate() async throws {
        let transport = StubTransport(.success((try fixture("corn_monthly"), 200)))
        let client = FREDClient(apiKey: "test-key", transport: transport)

        _ = try await client.observations(seriesID: "PMAIZMTUSDM", start: nil)

        let items = try queryItems(await transport.requests.first)
        #expect(items["observation_start"] == nil)
    }

    @Test func malformedValueIsADecodingError() async throws {
        let body = Data(#"{"observations":[{"date":"2026-10-28","value":"12abc"}]}"#.utf8)
        let client = FREDClient(apiKey: "test-key", transport: StubTransport(.success((body, 200))))

        await #expect(throws: PriceServiceError.decoding) {
            try await client.latest(seriesID: "DCOILWTICO")
        }
    }

    @Test func unexpectedShapeIsADecodingError() async throws {
        let body = Data(#"{"unexpected":true}"#.utf8)
        let client = FREDClient(apiKey: "test-key", transport: StubTransport(.success((body, 200))))

        await #expect(throws: PriceServiceError.decoding) {
            try await client.latest(seriesID: "DCOILWTICO")
        }
    }
}

@Suite struct FREDClientErrorMappingTests {
    private func expect(status: Int, body: Data = Data(), maps expected: PriceServiceError) async {
        let client = FREDClient(apiKey: "test-key", transport: StubTransport(.success((body, status))))
        await #expect(throws: expected) {
            try await client.latest(seriesID: "DCOILWTICO")
        }
    }

    @Test func authStatuses() async {
        await expect(status: 401, maps: .unauthorized)
        await expect(status: 403, maps: .unauthorized)
    }

    @Test func unregisteredAPIKeyReportedAsA400() async throws {
        await expect(status: 400, body: try fixture("error_bad_api_key"), maps: .unauthorized)
    }

    @Test func malformedAPIKeyReportedAsA400() async throws {
        await expect(status: 400, body: try fixture("error_malformed_api_key"), maps: .unauthorized)
    }

    @Test func badRequestKeepsTheMessage() async throws {
        await expect(
            status: 400,
            body: try fixture("synthetic_error_bad_request"),
            maps: .badRequest(message: "Bad Request. The series does not exist.")
        )
    }

    @Test func rateLimit() async {
        await expect(status: 429, maps: .rateLimited)
    }

    @Test func serverError() async {
        await expect(status: 503, maps: .server(status: 503))
    }

    @Test func transportFailureIsOffline() async {
        let client = FREDClient(
            apiKey: "test-key",
            transport: StubTransport(.failure(URLError(.notConnectedToInternet)))
        )
        await #expect(throws: PriceServiceError.offline) {
            try await client.latest(seriesID: "DCOILWTICO")
        }
    }

    @Test func cancellationStaysCancellation() async {
        let client = FREDClient(apiKey: "test-key", transport: StubTransport(.failure(URLError(.cancelled))))
        await #expect(throws: CancellationError.self) {
            try await client.latest(seriesID: "DCOILWTICO")
        }
    }
}
