# Swift-SafariDriver

A layer over [the excellent `swift-webdriver`](https://github.com/thebrowsercompany/swift-webdriver) to expose Safari's `safaridriver` as a service.

Don't rely on this to work.

## Example Usage (from test suite)

### Load a URL

```swift
@Test("Load a URL", arguments: ["https://example.com"])
func loadURL(url: String) async throws {
    let session = try await SafariDriver.makeSafariDriverSession()

    let url = try #require(URL(string: url))
    try session.url(url)

    let title = try session.title
    #expect(title == "Example Domain", "Title should be 'Example Domain', got '\(title)'")

    try session.delete()
}
```

### Load a URL and Find an Element

```swift
@Test("Find an element", arguments: [("https://example.com", "/html/body/div/h1", "Example Domain")])
func findElement(url: String, xpath: String, expectedText: String) async throws {
    let session = try await SafariDriver.makeSafariDriverSession()

    let url = try #require(URL(string: url))
    try session.url(url)

    let locator = ElementLocator.xpath(xpath)

    let element = try session.findElement(locator: locator)
    let text = try element.text
    #expect(text == expectedText, "Element text should be '\(expectedText)', got '\(text)'")

    try session.delete()
}
```

## Importing

Inside your `package.swift`:

```swift
let package = Package(
    name: ...,
    products: ...,
    dependencies: [
        .package(url: "https://github.com/ntflix/Swift-SafariDriver", branch: "main")
    ],
    targets: [
        .target(
            ...,
            dependencies: [
                .product(name: "SafariDriver", package: "swift-safaridriver")
            ]
        )
    ]
)
```
