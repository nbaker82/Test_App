import Foundation

public enum PriceFormatting {
    /// "$481.72"
    public static func price(_ value: Decimal, locale: Locale = .current) -> String {
        value.formatted(.currency(code: "USD").locale(locale))
    }

    /// "Oct 27, 2026" for daily series, "Sep 2026" for monthly ones.
    public static func date(_ date: Date, frequency: Frequency, locale: Locale = .current) -> String {
        var style = Date.FormatStyle(locale: locale, calendar: .utc, timeZone: .gmt)
        switch frequency {
        case .daily:
            style = style.month(.abbreviated).day().year()
        case .monthly:
            style = style.month(.abbreviated).year()
        }
        return date.formatted(style)
    }
}
