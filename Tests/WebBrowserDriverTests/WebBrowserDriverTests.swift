import Foundation
import Testing
import WebDriver

@testable import WebBrowserDriver

// let browser = Browser.msedge("/Users/felix/Downloads/edgedriver_mac64_m1/msedgedriver", msEdgePath: "/Volumes/Apps/Microsoft Edge.app/Contents/MacOS/Microsoft Edge")

@Test("Load a URL", arguments: ["https://example.com"])
func loadURL(url: String) async throws {
    let browser = Browser.chromium(nil, chromiumPath: nil)

    let webBrowserDriver = WebBrowserDriver(browser: browser, host: "127.0.0.1", port: 4444)
    let session = try webBrowserDriver.createSession()

    let url = try #require(URL(string: url))
    try session.url(url)

    let title = try session.title
    #expect(title == "Example Domain", "Title should be 'Example Domain', got '\(title)'")

    try session.delete()
}

@Test(
    "Find an element", arguments: [("https://example.com", "/html/body/div/h1", "Example Domain")])
func findElement(url: String, xpath: String, expectedText: String) async throws {
    let browser = Browser.chromium(nil, chromiumPath: nil)

    let webBrowserDriver = WebBrowserDriver(browser: browser, host: "127.0.0.1", port: 4444)
    let session = try webBrowserDriver.createSession()

    let url = try #require(URL(string: url))
    try session.url(url)

    let locator = ElementLocator.xpath(xpath)

    let element = try session.findElement(locator: locator)
    let text = try element.text
    #expect(text == expectedText, "Element text should be '\(expectedText)', got '\(text)'")

    try session.delete()
}
