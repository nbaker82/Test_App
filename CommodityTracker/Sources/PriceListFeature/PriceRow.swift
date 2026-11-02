import Core

public struct PriceRow: Identifiable, Equatable, Sendable {
    public let commodity: Commodity
    public var state: PriceRowState
    var sparkline: [ChartPoint] = []

    public var id: Commodity.ID { commodity.id }
}
