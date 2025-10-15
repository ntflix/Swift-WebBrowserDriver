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
        if !service.reuseService {
            try await service.start()
        }
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
        let service = BrowserService(browser: browser)
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
                    message: "Unable to create WebBrowserDriver session. Underlying error: \(error)",
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
}