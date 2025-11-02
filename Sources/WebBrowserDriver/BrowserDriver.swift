import WebDriver

/// Coordinates communication with a browser instance using the W3C WebDriver protocol, handling lifecycle events and request forwarding.
///
/// Encapsulates a browser service alongside an HTTP-based WebDriver client to provide high-level automation capabilities for Safari.
///
/// - Note: Use `attach(port:)` when connecting to an already-running service, and `connect(service:)` when you need lifecycle management.
public final class WebBrowserDriver: WebDriver {
    public struct StartError: Error {
        public let message: String
        public let underlyingError: Error?

        public init(message: String, underlyingError: Error? = nil) {
            self.message = message
            self.underlyingError = underlyingError
        }
    }

    public static func connect(service: BrowserService) async throws -> WebBrowserDriver {
        // Start the service if we’re managing it.
        #if canImport(Network)
            if !service.reuseService {
                try await service.start()
            }
        #endif

        let http = HTTPWebDriver(endpoint: service.serviceURL, wireProtocol: .w3c)
        return WebBrowserDriver(httpWebDriver: http, service: service)
    }

    private let httpWebDriver: HTTPWebDriver
    private let service: BrowserService

    private init(httpWebDriver: HTTPWebDriver, service: BrowserService) {
        self.httpWebDriver = httpWebDriver
        self.service = service
    }

    public var wireProtocol: WireProtocol { .w3c }

    @discardableResult
    public func send<Req: Request>(_ request: Req) throws -> Req.Response {
        try httpWebDriver.send(request)
    }

    public func isInconclusiveInteraction(error: ErrorResponse.Status) -> Bool {
        httpWebDriver.isInconclusiveInteraction(error: error)
    }

    public func stop() {
        service.stop()
    }

    public static func makeSession(with browser: Browser) async throws -> Session {
        let service = try BrowserService(browser: browser)
        do {
            let driver = try await WebBrowserDriver.connect(service: service)
            do {
                let session = try Session.W3C.create(
                    webDriver: driver,
                    alwaysMatch: Capabilities(),
                    firstMatch: [browser.capabilities]
                )
                return session
            } catch {
                throw StartError(
                    message:
                        "Unable to create WebBrowserDriver session. Underlying error: \(error)",
                    underlyingError: error
                )
            }
        } catch {
            throw StartError(
                message: "WebBrowserDriver unavailable. Underlying error: \(error)",
                underlyingError: error
            )
        }
    }

    /// Create a session connected to an existing browser service at the given host and port.
    ///
    /// - Parameters:
    ///  - browser: The browser type to connect to.
    /// - host: The host where the browser service is running.
    /// - port: The port where the browser service is running.
    /// - Returns: A `Session` connected to the existing browser service.
    ///
    /// - Note: This method assumes that the browser service is already running and accessible at the specified host and port.
    /// Good for connecting to remote browser services (e.g. headless containers).
    public static func makeSession(with browser: Browser, host: String, port: Int) async throws
        -> Session
    {
        let service = try BrowserService(
            browser: browser, port: port, reuseService: true, host: host)
        let driver = try await WebBrowserDriver.connect(service: service)
        return try Session.W3C.create(
            webDriver: driver,
            alwaysMatch: Capabilities(),
            firstMatch: [browser.capabilities]
        )
    }
}
