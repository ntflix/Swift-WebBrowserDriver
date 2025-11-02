import Foundation

#if canImport(Network)
    import Network
#else
    import FoundationNetworking
#endif

// Manages a WebDriver server process (safaridriver, chromedriver, geckodriver, msedgedriver, etc.)
// or connects to an already-running service when reuseService is true.
public final class BrowserService {
    public struct ServiceError: Error {
        public let message: String
        public static let failedToAllocatePort = ServiceError(
            message: "Failed to allocate free port.")
        public static let missingPortForExternalService = ServiceError(
            message: "No executable configured and port not provided for external service.")
        public static let unsupportedPlatformForProcessManagement = ServiceError(
            message: "Process management is not supported on this platform.")
    }

    // Supported overridable env keys for driver executables.
    // Highest-precedence if provided.
    public static let safariEnvKey = "SE_SAFARIDRIVER"
    public static let chromeEnvKey = "SE_CHROMEDRIVER"
    public static let edgeEnvKey = "SE_MSEDGEDRIVER"
    public static let geckoEnvKey = "SE_GECKODRIVER"

    // Back-compat single key (still honoured).
    public static let driverPathEnvKey = "SE_SAFARIDRIVER"

    // Browser being controlled by this service.
    public let browser: Browser

    // Host and port where the service is reachable.
    // For managed processes, host defaults to 127.0.0.1 and port is auto-assigned (if 0).
    public var host: String
    public var port: Int

    // When true, we will not spawn a process and only point at an existing driver at host:port.
    public var reuseService: Bool

    // Extra args to pass to the driver executable.
    public var serviceArgs: [String]

    // Environment for spawned process.
    public var env: [String: String]

    // Optional logfile path for stdout/stderr redirection.
    public var logFile: String?

    // Resolved path to the driver executable (if we manage a process).
    // If nil, this instance will not spawn a process and requires reuseService == true with a valid host/port.
    public var executablePath: String?

    // Returns the current browser executable path (browser binary), if specified.
    public var browserExecutablePath: String? {
        browser.browserPath
    }

    private var process: Process?
    private var outputFileHandle: FileHandle?

    // Construct with optional executablePath override.
    // If no executablePath is provided, we try env vars, then Browser defaults.
    public init(
        browser: Browser,
        port: Int = 0,
        reuseService: Bool = false,
        serviceArgs: [String] = [],
        env: [String: String] = ProcessInfo.processInfo.environment,
        logFile: String? = nil,
        host: String = "127.0.0.1",
    ) throws {
        #if canImport(Network)
            if reuseService == false {
                throw ServiceError.unsupportedPlatformForProcessManagement
            }
        #endif

        self.browser = browser
        self.env = env
        self.host = host
        self.port = port
        self.reuseService = reuseService
        self.serviceArgs = serviceArgs
        self.logFile = logFile

        // Resolve driver path.
        self.executablePath = browser.driverPath
    }

    public var serviceURL: URL {
        URL(string: "http://\(host):\(port)")!
    }

    // Starts the driver process if we manage it, otherwise validates configuration for reuse.
    #if canImport(Network)
        public func start() async throws {
            // If we are reusing an existing service, ensure host/port are usable.
            if reuseService || executablePath == nil {
                // If we don't manage a process and port is 0, we cannot auto-allocate.
                if port == 0 {
                    throw ServiceError.missingPortForExternalService
                }
                return
            }

            // Choose a free port if none specified (0).
            if port == 0 {
                port = try await Self.findFreePort()
                throw ServiceError.missingPortForExternalService
            }

            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: executablePath!)

            // Build driver-appropriate arguments for port.
            var args = driverPortArguments(browser: browser, port: port)

            // Append browser executable path if available and needed by the specific driver.
            if let browserExec = browserExecutablePath {
                switch browser {
                #if os(macOS)
                    case .safari, .safariTechnologyPreview:
                        // safaridriver does not take a browser path argument.
                        break
                #endif
                case .chrome, .chromium:
                    args.append(contentsOf: ["--chrome-binary", browserExec])
                case .msedge:
                    args.append(contentsOf: ["--edge-binary", browserExec])
                case .firefox:
                    args.append(contentsOf: ["--binary", browserExec])
                }

            }
            if !serviceArgs.isEmpty {
                args += serviceArgs
            }
            proc.arguments = args
            proc.environment = env

            // Configure logging.
            if let logFile {
                if !FileManager.default.fileExists(atPath: logFile) {
                    FileManager.default.createFile(atPath: logFile, contents: nil, attributes: nil)
                }
                let fh = try FileHandle(forWritingTo: URL(fileURLWithPath: logFile))
                fh.seekToEndOfFile()
                outputFileHandle = fh
                proc.standardOutput = fh
                proc.standardError = fh
            } else {
                proc.standardOutput = FileHandle.nullDevice
                proc.standardError = FileHandle.nullDevice
            }

            // Run process.
            do {
                try proc.run()
            } catch {
                try? outputFileHandle?.close()
                outputFileHandle = nil
                throw ServiceError(
                    message:
                        "Failed to start driver for \(browser) at \(executablePath ?? "<none>"): \(error)"
                )
            }
            process = proc

            // Poll until the TCP port is connectable (0.01, 0.06, ..., max 0.5; up to ~70 tries).
            var count = 0
            while true {
                try assertProcessStillRunning()
                if isConnectable() { break }
                let sleepTime = min(0.01 + 0.05 * Double(count), 0.5)
                try await Task.sleep(nanoseconds: UInt64(sleepTime * 1_000_000_000))
                count += 1
                if count == 70 {
                    stop()
                    throw ServiceError(message: "Cannot connect to WebDriver at \(serviceURL).")
                }
            }
        }
    #endif

    public func stop() {
        // If reusing an existing service or we didn't start a process, do nothing.
        if reuseService || executablePath == nil { return }

        if let proc = process, proc.isRunning {
            proc.terminate()
            let deadline = Date().addingTimeInterval(2)
            while proc.isRunning && Date() < deadline {
                Thread.sleep(forTimeInterval: 0.05)
            }
            if proc.isRunning {
                proc.terminate()
            }
        }
        process = nil

        try? outputFileHandle?.close()
        outputFileHandle = nil
    }

    deinit { stop() }

    // MARK: - Internals

    private func assertProcessStillRunning() throws {
        if let proc = process, !proc.isRunning {
            throw ServiceError(
                message: "WebDriver process exited early with code \(proc.terminationStatus).")
        }
    }

    #if canImport(Network)
        private func isConnectable() -> Bool {
            Self.tcpConnect(host: host, port: port, timeout: 0.25)
        }
    #endif

    #if canImport(Network)
        private static func findFreePort() async throws -> Int {
            let listener = try NWListener(using: .tcp, on: .any)
            return try await withCheckedThrowingContinuation { continuation in
                listener.stateUpdateHandler = { state in
                    switch state {
                    case .ready:
                        if let port = listener.port {
                            continuation.resume(returning: Int(port.rawValue))
                        } else {
                            continuation.resume(throwing: ServiceError.failedToAllocatePort)
                        }
                        listener.cancel()
                    case .failed(let error):
                        continuation.resume(throwing: error)
                        listener.cancel()
                    default:
                        break
                    }
                }
                listener.newConnectionHandler = { _ in }
                listener.start(queue: .global())
            }
        }
    #endif

    #if canImport(Network)
        private static func tcpConnect(host: String, port: Int, timeout: TimeInterval) -> Bool {
            guard let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else { return false }
            let connection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: .tcp)

            let doneSem = DispatchSemaphore(value: 0)
            let readySem = DispatchSemaphore(value: 0)

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    readySem.signal()
                    doneSem.signal()
                case .failed(_), .cancelled:
                    doneSem.signal()
                default:
                    break
                }
            }

            connection.start(queue: .global())
            _ = doneSem.wait(timeout: .now() + timeout)
            connection.cancel()

            return readySem.wait(timeout: .now()) == .success
        }
    #endif

    private func driverPortArguments(browser: Browser, port: Int) -> [String] {
        switch browser {
        #if os(macOS)
            case .safari, .safariTechnologyPreview:
                // safaridriver uses "-p <port>"
                return ["-p", String(port)]
        #endif
        case .chrome, .chromium, .msedge:
            // chromedriver/msedgedriver use "--port=<port>"
            return ["--port=\(port)"]
        case .firefox:
            // geckodriver uses "--port <port>"
            return ["--port", String(port)]
        }
    }
}
