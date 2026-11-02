import Core
import Foundation

extension TimeRange {
    /// What VoiceOver reads, because "1M" and "5Y" are unclear out loud.
    var spokenName: LocalizedStringResource {
        switch self {
        case .oneMonth: .priceFeature("1 month")
        case .sixMonths: .priceFeature("6 months")
        case .oneYear: .priceFeature("1 year")
        case .fiveYears: .priceFeature("5 years")
        case .max: .priceFeature("All history")
        }
    }
}
