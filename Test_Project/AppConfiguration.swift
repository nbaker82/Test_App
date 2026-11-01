import Foundation

enum AppConfiguration {
    /// Set in Config/Secrets.xcconfig. Nil when no key has been added.
    static var fredAPIKey: String? {
        let key = Bundle.main.object(forInfoDictionaryKey: "FREDAPIKey") as? String
        return key?.isEmpty == false ? key : nil
    }
}
