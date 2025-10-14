import WebDriver

public final class SafariDriver: WebDriver {
    public struct StartError: Error {
        public let message: String
    }

    public static func attach(port: Int) async throws -> SafariDriver {
        let service = SafariService(port: port, reuseService: true)
        return try await connect(service: service)
    }

    public static func connect(service: SafariService) async throws -> SafariDriver {
        // Start the service if we’re managing it.
        if !service.reuseService {
            try await service.start()
        }
        let http = HTTPWebDriver(endpoint: service.serviceURL, wireProtocol: .w3c)
        return SafariDriver(httpWebDriver: http, service: service)
    }

    private let httpWebDriver: HTTPWebDriver
    private let service: SafariService

    private init(httpWebDriver: HTTPWebDriver, service: SafariService) {
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

    public func close() throws {
        // Close the managed service unless it’s marked as reusable.
        service.stop()
    }

    public static func makeSafariDriverSession() async throws -> Session {
        let service = SafariService(port: 0, reuseService: false, logFile: "/tmp/safaridriver.log")
        do {
            let driver = try await SafariDriver.connect(service: service)
            do {
                let session = try Session(
                    webDriver: driver,
                    capabilities: Capabilities()
                )
                return session
            } catch {
                // Session creation failed — treat as environment-dependent and skip dependents.
                throw StartError(message: "Unable to create SafariDriver session. Make sure `safaridriver --enable` has been run. Underlying error: \(error)")
            }
        } catch {
            // Could not connect to safaridriver — skip dependents.
            throw StartError(message: "SafariDriver unavailable. Run `safaridriver --enable` once to enable it. Underlying error: \(error)")
        }
    }
}