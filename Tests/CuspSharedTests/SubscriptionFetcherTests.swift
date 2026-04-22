import Foundation
import XCTest
@testable import CuspShared

final class SubscriptionFetcherTests: XCTestCase {
    override func tearDown() {
        MockSubscriptionURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testFetchBodySendsClashCompatibleHeaders() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockSubscriptionURLProtocol.self]
        let session = URLSession(configuration: config)

        MockSubscriptionURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "User-Agent"), "Clash Verge/2.0")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "*/*")

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "text/plain; charset=utf-8"]
            )!
            let data = Data("proxies:\n  - { name: Test, type: vless, server: example.com, port: 443, uuid: a, tls: true }".utf8)
            return (response, data)
        }

        let body = try await SubscriptionFetcher.fetchBody(
            from: "https://example.com/subscription",
            session: session
        )

        XCTAssertTrue(body.contains("proxies:"))
    }
}

private final class MockSubscriptionURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            XCTFail("Missing request handler")
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
