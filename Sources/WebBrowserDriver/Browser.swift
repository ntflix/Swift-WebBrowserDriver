import WebDriver

/// Represents supported web browsers for automation, including platform-specific cases.
///
/// - Note: The `.safari` and `.safariTechnologyPreview` cases are only available on macOS.
/// - Usage: Specify which browser and driver path to use when launching or controlling a browser instance.
public enum Browser: Sendable {
    #if os(macOS)
        case safari(driverPath: String? = "/usr/bin/safaridriver")
        case safariTechnologyPreview(
            driverPath: String? =
                "/Applications/Safari Technology Preview.app/Contents/MacOS/safaridriver")
    #endif
    case chrome(
        _ driverPath: String? = nil,
        chromePath: String? = nil,
        args: [String] = ["--headless", "--disable-gpu", "--no-sandbox"]
    )
    case msedge(
        _ driverPath: String? = nil,
        msEdgePath: String? = nil,
        args: [String] = ["--headless", "--disable-gpu", "--no-sandbox"]
    )
    case firefox(
        _ driverPath: String? = nil,
        firefoxPath: String? = nil,
        args: [String] = ["-headless"]
    )
    case chromium(
        _ driverPath: String? = nil,
        chromiumPath: String? = nil,
        args: [String] = ["--headless", "--disable-gpu", "--no-sandbox"]
    )

    public var driverPath: String? {
        switch self {
        #if os(macOS)
            case .safari(let path), .safariTechnologyPreview(let path): return path
        #endif
        case .chrome(let path, _, _), .msedge(let path, _, _), .firefox(let path, _, _),
            .chromium(let path, _, _):
            return path
        }
    }

    public var browserPath: String? {
        switch self {
        #if os(macOS)
            case .safari, .safariTechnologyPreview: return nil
        #endif
        case .chrome(_, let path, _), .msedge(_, let path, _), .firefox(_, let path, _),
            .chromium(_, let path, _):
            return path
        }
    }

    public var capabilities: Capabilities {
        let capabilities = Capabilities()
        switch self {

        case .msedge(_, let msEdgePath, let args):
            let msEdgeOptions =
                try! Capabilities.EdgeOptions.create(with: args) as! Capabilities.EdgeOptions

            if let msEdgePath {
                msEdgeOptions.binary = msEdgePath
            }
            capabilities.msEdgeOptions = msEdgeOptions

        case .chrome(_, let chromePath, let args), .chromium(_, let chromePath, let args):
            let chromeOptions =
                try! Capabilities.ChromeOptions.create(with: args) as! Capabilities.ChromeOptions

            if let chromePath {
                chromeOptions.binary = chromePath
            }
            capabilities.chromeOptions = chromeOptions

        case .firefox(_, let firefoxPath, let args):
            let firefoxOptions =
                try! Capabilities.FirefoxOptions.create(with: args) as! Capabilities.FirefoxOptions

            if let firefoxPath {
                firefoxOptions.binary = firefoxPath
            }
            capabilities.firefoxOptions = firefoxOptions

        default:
            break
        }
        return capabilities
    }

    public static var allChoices: [String] {
        var cases: [String] = []
        #if os(macOS)
            cases.append("safari")
            cases.append("safariTechnologyPreview")
        #endif
        cases.append("chrome")
        cases.append("msedge")
        cases.append("firefox")
        cases.append("chromium")

        return cases
    }

    public init(from string: String, driverPath: String? = nil, browserPath: String? = nil) throws {
        switch string.lowercased() {
        #if os(macOS)
            case "safari":
                self = .safari(driverPath: driverPath ?? "/usr/bin/safaridriver")
            case "safaritechnologypreview":
                self = .safariTechnologyPreview(
                    driverPath: driverPath
                        ?? "/Applications/Safari Technology Preview.app/Contents/MacOS/safaridriver"
                )
        #endif
        case "chrome":
            self = .chrome(driverPath ?? "/usr/local/bin/chromedriver", chromePath: browserPath)
        case "msedge":
            self = .msedge(driverPath ?? "/usr/local/bin/edgedriver", msEdgePath: browserPath)
        case "firefox":
            self = .firefox(driverPath ?? "/usr/local/bin/geckodriver", firefoxPath: browserPath)
        case "chromium":
            self = .chromium(driverPath ?? "/usr/local/bin/chromedriver", chromiumPath: browserPath)
        default:
            throw BrowserError.invalidBrowser(name: string)
        }
    }
}
