import Foundation
import Network

// Manages the safaridriver executable in a Selenium-like "Service" style.
public final class SafariService {
    public struct ServiceError: Error {
        public let message: String
        public static let failedToAllocatePort = ServiceError(message: "Failed to allocate free port.")
    }

    public static let defaultExecutablePath = "/usr/bin/safaridriver"
    public static let driverPathEnvKey = "SE_SAFARIDRIVER"

    public var path: String
    public var port: Int
    public var reuseService: Bool
    public var serviceArgs: [String]
    public var env: [String: String]
    public var logFile: String?

    private var process: Process?
    private var outputFileHandle: FileHandle?

    public init(
        executablePath: String? = nil,
        port: Int = 0,
        reuseService: Bool = false,
        serviceArgs: [String] = [],
        env: [String: String] = ProcessInfo.processInfo.environment,
        logFile: String? = nil
    ) {
        let envPath = env[Self.driverPathEnvKey]
        self.path = envPath ?? executablePath ?? Self.defaultExecutablePath
        self.port = port
        self.reuseService = reuseService
        self.serviceArgs = serviceArgs
        self.env = env
        self.logFile = logFile
    }

    public var serviceURL: URL {
        URL(string: "http://localhost:\(port)")!
    }

    public func start() async throws{
        // If reusing an already-running service, do nothing.
        if reuseService { return }

        // Choose a free port if none specified (0).
        if port == 0 {
            port = try await Self.findFreePort()
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: path)
        proc.arguments = ["-p", String(port)] + serviceArgs
        proc.environment = env

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

        do {
            try proc.run()
        } catch {
            try? outputFileHandle?.close()
            outputFileHandle = nil
            throw ServiceError(message: "Failed to start safaridriver at \(path): \(error)")
        }
        process = proc

        // Poll until connectable (0.01, 0.06, ..., max 0.5; up to ~70 tries).
        var count = 0
        while true {
            try assertProcessStillRunning()
            if isConnectable() { break }
            let sleepTime = min(0.01 + 0.05 * Double(count), 0.5)
            try await Task.sleep(nanoseconds: UInt64(sleepTime * 1_000_000_000))
            count += 1
            if count == 70 {
                stop()
                throw ServiceError(message: "Cannot connect to safaridriver at \(serviceURL).")
            }
        }
    }

    public func stop() {
        if reuseService { return }

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
            throw ServiceError(message: "safaridriver exited early with code \(proc.terminationStatus).")
        }
    }

    private func isConnectable() -> Bool {
        Self.tcpConnect(host: "127.0.0.1", port: port, timeout: 0.25)
    }

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
            listener.newConnectionHandler = { _ in
            }
            listener.start(queue: .global())
        }
    }

    private static func tcpConnect(host: String, port: Int, timeout: TimeInterval) -> Bool {
        guard let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else { return false }
        let connection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: .tcp)

        // Use separate semaphores to distinguish readiness without capturing mutable vars.
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

        // if readySem was signaled, connection succeeded
        return readySem.wait(timeout: .now()) == .success
    }
}
