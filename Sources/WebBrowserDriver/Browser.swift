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
        _ driverPath: String?,
        chromePath: String? = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")
    case msedge(
        _ driverPath: String?,
        msEdgePath: String? = "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge")
    case firefox(
        _ driverPath: String?,
        firefoxPath: String? = "/Applications/Firefox.app/Contents/MacOS/firefox")
    case chromium(
        _ driverPath: String?,
        chromiumPath: String? = "/Applications/Chromium.app/Contents/MacOS/Chromium")

    public var driverPath: String? {
        switch self {
        #if os(macOS)
            case .safari(let path), .safariTechnologyPreview(let path): return path
        #endif
        case .chrome(let path, _), .msedge(let path, _), .firefox(let path, _),
            .chromium(let path, _):
            return path
        }
    }

    public var browserPath: String? {
        switch self {
        #if os(macOS)
            case .safari, .safariTechnologyPreview: return nil
        #endif
        case .chrome(_, let path), .msedge(_, let path), .firefox(_, let path),
            .chromium(_, let path):
            return path
        }
    }

    public var capabilities: Capabilities {
        let capabilities = Capabilities()
        switch self {
        case .msedge(_, let msEdgePath):
            let msEdgeOptions = Capabilities.EdgeOptions()
            if let msEdgePath {
                msEdgeOptions.binary = msEdgePath
            }
            capabilities.msEdgeOptions = msEdgeOptions
        case .chrome(_, let chromePath), .chromium(_, let chromePath):
            let chromeOptions = Capabilities.ChromeOptions()
            if let chromePath {
                chromeOptions.binary = chromePath
            }
            capabilities.chromeOptions = chromeOptions
        case .firefox(_, let firefoxPath):
            let firefoxOptions = Capabilities.FirefoxOptions()
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
