import Foundation
import SwiftData

@Model
final class SeriesRecord {
    @Attribute(.unique) var seriesID: String
    var savedAt: Date

    init(seriesID: String, savedAt: Date) {
        self.seriesID = seriesID
        self.savedAt = savedAt
    }
}

@Model
final class ObservationRecord {
    /// Series plus date, so a series can't hold two rows for one date.
    /// Compound #Unique would need iOS 18.
    @Attribute(.unique) var key: String
    var seriesID: String
    var date: Date
    /// Stored as a string so prices round-trip exactly instead of passing through a float.
    var value: String

    init(seriesID: String, date: Date, value: Decimal) {
        self.key = "\(seriesID)|\(date.timeIntervalSince1970)"
        self.seriesID = seriesID
        self.date = date
        self.value = value.description
    }
}
