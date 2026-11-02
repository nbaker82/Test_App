import Core
import Foundation

struct FREDObservationsResponse: Decodable {
    let observations: [FREDObservationDTO]
}

struct FREDObservationDTO: Decodable {
    let date: String
    let value: String

    /// FRED sends "." for a date with no value, such as a market holiday. That maps to nil.
    func toObservation() throws -> PriceObservation? {
        guard value != "." else { return nil }
        // Decimal(string:) accepts a valid prefix ("12abc" is 12), so validate with Double first.
        guard Double(value)?.isFinite == true,
              let decimal = Decimal(string: value),
              let parsedDate = try? Date(date, strategy: FREDDate.style)
        else {
            throw PriceServiceError.decoding
        }
        return PriceObservation(date: parsedDate, value: decimal)
    }
}

struct FREDErrorBody: Decodable {
    let errorMessage: String?

    enum CodingKeys: String, CodingKey {
        case errorMessage = "error_message"
    }
}

enum FREDDate {
    /// "2026-09-01", in UTC.
    static let style = Date.ISO8601FormatStyle(timeZone: .gmt).year().month().day()
}
