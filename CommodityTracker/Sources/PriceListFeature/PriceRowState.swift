import Core
import Repository

public enum PriceRowState: Equatable, Sendable {
    case loading
    case loaded(Sourced<PriceObservation>)
    case failed(PriceServiceError)
}
