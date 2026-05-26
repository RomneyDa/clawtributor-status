import AppKit
import Foundation

@MainActor
final class GitHubAuthService {
    func requestDeviceCode() async throws -> DeviceCodeResponse {
        var request = URLRequest(url: AppConfig.deviceCodeURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "client_id": AppConfig.githubClientId,
            "scope": AppConfig.oauthScope
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)
        return try JSONDecoder().decode(DeviceCodeResponse.self, from: data)
    }

    func pollForToken(deviceCode: String) async throws -> DeviceTokenResponse {
        var request = URLRequest(url: AppConfig.accessTokenURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "client_id": AppConfig.githubClientId,
            "device_code": deviceCode,
            "grant_type": "urn:ietf:params:oauth:grant-type:device_code"
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)
        return try JSONDecoder().decode(DeviceTokenResponse.self, from: data)
    }

    func openVerificationPage(_ url: String) {
        guard let verificationURL = URL(string: url) else { return }
        NSWorkspace.shared.open(verificationURL)
    }

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AppError.message("GitHub returned an unexpected auth response.")
        }
    }
}
