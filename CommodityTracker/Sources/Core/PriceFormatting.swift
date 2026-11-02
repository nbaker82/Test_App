import Foundation

public enum PriceFormatting {
    /// "$481.72"
    public static func price(_ value: Decimal, locale: Locale = .current) -> String {
        value.formatted(.currency(code: "USD").locale(locale))
    }

    /// A chart axis label, with less detail the longer the chart's span:
    /// "Oct 27" up to about two months, "Sep 2026" up to three years, then "2026".
    public static func axisDate(_ date: Date, span: TimeInterval, locale: Locale = .current) -> String {
        let day: TimeInterval = 24 * 60 * 60
        var style = Date.FormatStyle(locale: locale, calendar: .utc, timeZone: .gmt)
        if span <= 62 * day {
            style = style.month(.abbreviated).day()
        } else if span <= 3 * 366 * day {
            style = style.month(.abbreviated).year()
        } else {
            style = style.year()
        }
        return date.formatted(style)
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
