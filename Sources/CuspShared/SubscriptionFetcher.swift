import Foundation

public enum SubscriptionFetcher {
    public static func fetchBody(
        from urlString: String,
        session: URLSession = .shared
    ) async throws -> String {
        guard let url = URL(string: urlString) else {
            throw FetchError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Clash Verge/2.0", forHTTPHeaderField: "User-Agent")
        request.setValue("*/*", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw FetchError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw FetchError.httpStatus(httpResponse.statusCode)
        }
        guard let body = String(data: data, encoding: .utf8) else {
            throw FetchError.unreadableSubscription
        }

        return body
    }

    public enum FetchError: Swift.Error, Equatable {
        case invalidURL
        case invalidResponse
        case httpStatus(Int)
        case unreadableSubscription
    }
}
