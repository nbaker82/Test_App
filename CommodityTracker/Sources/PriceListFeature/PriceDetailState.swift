import Core
import Repository

enum PriceDetailState: Equatable, Sendable {
    case loading
    case loaded(Sourced<[PriceObservation]>)
    case failed(PriceServiceError)
}
