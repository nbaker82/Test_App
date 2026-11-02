public enum Frequency: String, Hashable, Sendable {
    case daily
    case monthly
}

public struct Commodity: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let seriesID: String
    public let frequency: Frequency
    public let unit: String

    public init(id: String, name: String, seriesID: String, frequency: Frequency, unit: String) {
        self.id = id
        self.name = name
        self.seriesID = seriesID
        self.frequency = frequency
        self.unit = unit
    }
}

extension Commodity {
    public static let wti = Commodity(
        id: "wti", name: "WTI Crude Oil", seriesID: "DCOILWTICO",
        frequency: .daily, unit: "USD per barrel"
    )
    public static let corn = Commodity(
        id: "corn", name: "Corn", seriesID: "PMAIZMTUSDM",
        frequency: .monthly, unit: "USD per metric ton"
    )
    public static let wheat = Commodity(
        id: "wheat", name: "Wheat", seriesID: "PWHEAMTUSDM",
        frequency: .monthly, unit: "USD per metric ton"
    )
    public static let soybeans = Commodity(
        id: "soybeans", name: "Soybeans", seriesID: "PSOYBUSDM",
        frequency: .monthly, unit: "USD per metric ton"
    )

    public static let catalog: [Commodity] = [.wti, .corn, .wheat, .soybeans]
}
