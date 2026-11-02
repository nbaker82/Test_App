import Core
import Foundation
import Networking
import Persistence
import PriceListFeature
import Repository

/// The one place that knows which concrete types the app runs on.
enum AppDependencies {
    static func makeRepository() async -> any PriceRepository {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-useSamplePrices") {
            return SamplePriceRepository()
        }
        #endif

        // With no key, FRED rejects the request and the screen explains what's missing.
        let service = FREDClient(apiKey: AppConfiguration.fredAPIKey ?? "")
        return CachingPriceRepository(service: service, cache: await makeCache())
    }

    /// Off the main actor because a model actor does its database work on the queue
    /// it was created on. The app still works without saved prices, so if the store
    /// can't be opened at all it falls back to memory rather than failing to launch.
    @concurrent
    private nonisolated static func makeCache() async -> any PriceCache {
        let url = URL.applicationSupportDirectory.appending(path: "CommodityTracker/prices.store")
        do {
            let container = try PriceStore.makeContainerResettingIfNeeded(at: url)
            return SwiftDataPriceCache(modelContainer: container)
        } catch {
            return InMemoryPriceCache()
        }
    }
}
