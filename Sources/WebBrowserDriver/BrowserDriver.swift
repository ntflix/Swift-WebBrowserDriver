import Foundation
import Logging
import WebDriver

/// Coordinates communication with a browser instance using the W3C WebDriver protocol, handling request forwarding.
///
/// Encapsulates a browser service alongside an HTTP-based WebDriver client to provide high-level automation capabilities for Safari.
public final class WebBrowserDriver: WebDriver {
    public var wireProtocol: WireProtocol { .w3c }
    private let browser: Browser
    private let httpWebDriver: WebDriver
    private let logger: Logger

    public init(browser: Browser, host: String, port: Int, logger: Logger) throws {
        let endpointURL = URL(string: "http://\(host):\(port)")!
        self.browser = browser
        self.logger = logger
        self.httpWebDriver = HTTPWebDriver(
            endpoint: endpointURL,
            wireProtocol: .w3c
        )
    }

    @discardableResult
    public func send<Req: Request>(_ request: Req) async throws -> Req.Response {
        self.logger.debug("Sending request: \(request)")
        return try await httpWebDriver.send(request)
    }

    public func isInconclusiveInteraction(error: ErrorResponse.Status) -> Bool {
        httpWebDriver.isInconclusiveInteraction(error: error)
    }

    /// Create a session.
    ///
    /// - Returns: A `Session` connected to the existing browser service.
    public func createSession() async throws
        -> Session
    {
        self.logger.debug("Creating session with browser: \(self.browser) and capabilities: \(self.browser.capabilities)")
        return try await Session.W3C.create(
            webDriver: self.httpWebDriver,
            alwaysMatch: Capabilities(),
            firstMatch: [self.browser.capabilities]
        )
    }
}
