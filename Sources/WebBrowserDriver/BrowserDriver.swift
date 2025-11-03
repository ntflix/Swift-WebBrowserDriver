import Foundation
import WebDriver

/// Coordinates communication with a browser instance using the W3C WebDriver protocol, handling request forwarding.
///
/// Encapsulates a browser service alongside an HTTP-based WebDriver client to provide high-level automation capabilities for Safari.
public final class WebBrowserDriver: WebDriver {
    public var wireProtocol: WireProtocol { .w3c }
    private let browser: Browser
    private let httpWebDriver: WebDriver

    public init(browser: Browser, host: String, port: Int) {
        let endpointURL = URL(string: "http://\(host):\(port)")!
        self.browser = browser
        self.httpWebDriver = HTTPWebDriver(
            endpoint: endpointURL,
            wireProtocol: .w3c
        )
    }

    @discardableResult
    public func send<Req: Request>(_ request: Req) throws -> Req.Response {
        try httpWebDriver.send(request)
    }

    public func isInconclusiveInteraction(error: ErrorResponse.Status) -> Bool {
        httpWebDriver.isInconclusiveInteraction(error: error)
    }

    /// Create a session.
    ///
    /// - Returns: A `Session` connected to the existing browser service.
    public func createSession() throws
        -> Session
    {
        return try Session.W3C.create(
            webDriver: self.httpWebDriver,
            alwaysMatch: Capabilities(),
            firstMatch: [self.browser.capabilities]
        )
    }
}
