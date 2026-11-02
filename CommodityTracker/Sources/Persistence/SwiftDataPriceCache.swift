import Core
import Foundation
import SwiftData

public enum PersistenceError: Error, Equatable, Sendable {
    case corruptValue(String)
}

public enum PriceStore {
    private static let schema = Schema([SeriesRecord.self, ObservationRecord.self])

    /// Creating containers at the same moment intermittently crashed the process with a
    /// segfault in parallel tests, and doing it one at a time stopped that.
    private static let creationLock = NSLock()

    /// A store at `url`, creating its folder if needed. Use a URL in the App Group
    /// container for a store the widget can also read.
    public static func makeContainer(at url: URL) throws -> ModelContainer {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        // Explicitly local: CloudKit doesn't allow the unique attributes the records rely on.
        let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        return try creationLock.withLock {
            try ModelContainer(for: schema, configurations: configuration)
        }
    }

    /// Opens the store, or deletes and recreates it if it can't be opened, such as after
    /// a schema change. That's safe because everything in it can be downloaded again.
    public static func makeContainerResettingIfNeeded(at url: URL) throws -> ModelContainer {
        do {
            return try makeContainer(at: url)
        } catch {
            for path in [url.path(), url.path() + "-wal", url.path() + "-shm"] {
                try? FileManager.default.removeItem(atPath: path)
            }
            return try makeContainer(at: url)
        }
    }

    public static func makeInMemoryContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try creationLock.withLock {
            try ModelContainer(for: schema, configurations: configuration)
        }
    }
}

/// Create this off the main actor. A model actor runs on the queue it was created on,
/// so one created on the main thread would do its database work there.
@ModelActor
public actor SwiftDataPriceCache: PriceCache {
    public func load(seriesID: String) throws -> CachedSeries? {
        var seriesDescriptor = FetchDescriptor<SeriesRecord>(
            predicate: #Predicate { $0.seriesID == seriesID }
        )
        seriesDescriptor.fetchLimit = 1
        guard let series = try modelContext.fetch(seriesDescriptor).first else { return nil }

        let observationDescriptor = FetchDescriptor<ObservationRecord>(
            predicate: #Predicate { $0.seriesID == seriesID },
            sortBy: [SortDescriptor(\.date)]
        )
        let observations = try modelContext.fetch(observationDescriptor).map { record in
            guard let value = Decimal(string: record.value) else {
                throw PersistenceError.corruptValue(record.key)
            }
            return PriceObservation(date: record.date, value: value)
        }
        return CachedSeries(observations: observations, savedAt: series.savedAt)
    }

    public func save(_ observations: [PriceObservation], seriesID: String, at date: Date) throws {
        do {
            try upsertSeries(seriesID: seriesID, savedAt: date)
            try upsertObservations(observations, seriesID: seriesID)
            try modelContext.save()
        } catch {
            // Otherwise these changes would stay pending and fail the next save as well.
            modelContext.rollback()
            throw error
        }
    }

    private func upsertSeries(seriesID: String, savedAt: Date) throws {
        var descriptor = FetchDescriptor<SeriesRecord>(
            predicate: #Predicate { $0.seriesID == seriesID }
        )
        descriptor.fetchLimit = 1
        if let series = try modelContext.fetch(descriptor).first {
            series.savedAt = savedAt
        } else {
            modelContext.insert(SeriesRecord(seriesID: seriesID, savedAt: savedAt))
        }
    }

    /// Updates matching rows directly. Leaving it to the unique attribute works too, but
    /// SwiftData resolves those conflicts row by row: 25 seconds to re-save 10,000 rows.
    private func upsertObservations(_ observations: [PriceObservation], seriesID: String) throws {
        let dates = observations.map(\.date)
        guard let first = dates.min(), let last = dates.max() else { return }

        let descriptor = FetchDescriptor<ObservationRecord>(
            predicate: #Predicate { $0.seriesID == seriesID && $0.date >= first && $0.date <= last }
        )
        var existing = Dictionary(
            try modelContext.fetch(descriptor).map { ($0.date, $0) },
            uniquingKeysWith: { current, _ in current }
        )
        for observation in observations {
            if let record = existing[observation.date] {
                let value = observation.value.description
                if record.value != value {
                    record.value = value
                }
            } else {
                let record = ObservationRecord(seriesID: seriesID, date: observation.date, value: observation.value)
                modelContext.insert(record)
                existing[observation.date] = record
            }
        }
    }
}
