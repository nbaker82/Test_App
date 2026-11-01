# CommodityTracker

FRED commodity prices: WTI crude, corn, wheat and soybeans.

| Module | Depends on | Holds |
| --- | --- | --- |
| `Core` | nothing | Catalog, observations, `PriceService`, `PriceCache`, errors, time ranges, formatting |
| `Networking` | `Core` | `FREDClient` |
| `Repository` | `Core` | `CachingPriceRepository`, `InMemoryPriceCache` |
| `Persistence` | `Core` | `SwiftDataPriceCache`, `PriceStore` |

Run the tests in UTC and in a zone west of Greenwich, since date handling is the easiest thing to break:

```bash
swift test
```

```bash
TZ=America/Chicago swift test
```

To also call the real API, which needs a [free FRED key](https://fred.stlouisfed.org/docs/api/api_key.html):

```bash
FRED_API_KEY=your_key swift test --filter LiveFREDTests
```

The app reads its key from `Config/Secrets.xcconfig`, which git ignores. Copy `Config/Secrets.example.xcconfig` to get started. The key is built into the app's `Info.plist`, which is fine for a demo but can be extracted from a shipped app.

## Offline behavior

Offline, rate-limited and server failures return the last saved price, marked `.cached(savedAt:)`. A bad key, bad request, undecodable response or empty series is thrown even when saved data exists.

## Persistence

```swift
let container = try PriceStore.makeContainer(at: storeURL)
let cache = SwiftDataPriceCache(modelContainer: container)
let repository = CachingPriceRepository(service: FREDClient(apiKey: apiKey), cache: cache)
```

- Create `SwiftDataPriceCache` off the main actor, or its database work runs on the main thread.
- Put `storeURL` in the App Group container if the widget needs to read the store.
- The store is local only, because CloudKit doesn't allow its unique attributes.
- Nothing migrates yet. It only holds re-downloadable data, so if `makeContainer` throws after a schema change, delete the store and start again.
- `load` reads a series' whole history, around 10,000 rows for WTI. A widget should get a dedicated latest-price query rather than use it.

## Fixtures

`corn_monthly.json` and `error_*_api_key.json` are real FRED responses. Files named `synthetic_*` are hand-written.

## Not yet verified against live FRED

- Series IDs other than corn were checked in Postman, but those responses weren't kept here.
- The body of a 400 response.
- `"."` values, which are assumed to appear in the daily WTI series.
