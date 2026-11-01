import Foundation

extension Calendar {
    /// Observation dates are calendar dates, so all date math happens in UTC.
    /// In a local zone, Sep 1 00:00 UTC falls in August anywhere west of Greenwich.
    public static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()
}

public enum TimeRange: String, CaseIterable, Hashable, Sendable {
    case oneMonth = "1M"
    case sixMonths = "6M"
    case oneYear = "1Y"
    case fiveYears = "5Y"
    case max = "Max"

    /// Short ranges would hold only a point or two on a monthly series.
    public static func available(for frequency: Frequency) -> [TimeRange] {
        switch frequency {
        case .daily:
            allCases
        case .monthly:
            [.oneYear, .fiveYears, .max]
        }
    }

    /// The first date in the range, or nil for the full history.
    public func start(endingAt end: Date) -> Date? {
        let calendar = Calendar.utc
        switch self {
        case .oneMonth:
            return calendar.date(byAdding: .month, value: -1, to: end)
        case .sixMonths:
            return calendar.date(byAdding: .month, value: -6, to: end)
        case .oneYear:
            return calendar.date(byAdding: .year, value: -1, to: end)
        case .fiveYears:
            return calendar.date(byAdding: .year, value: -5, to: end)
        case .max:
            return nil
        }
    }
}
