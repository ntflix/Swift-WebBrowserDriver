public enum BrowserError: Error {
    case invalidBrowser(name: String)
}

public struct StartError: Error {
    public let message: String
    public let underlyingError: Error?

    public init(message: String, underlyingError: Error? = nil) {
        self.message = message
        self.underlyingError = underlyingError
    }
}
