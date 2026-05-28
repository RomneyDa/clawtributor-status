import Foundation

enum AppError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let message): message
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var token: String?
    @Published var metrics: GitHubMetrics?
    @Published var deviceCode: DeviceCodeResponse?
    @Published var selectedDays = 90
    @Published var isLoading = false
    @Published var loadingMessage = "Idle"
    @Published var errorMessage: String?

    private let keychain = KeychainStore()
    private let authService = GitHubAuthService()
    private let metricsService = GitHubMetricsService()

    init() {
        token = keychain.readToken()
    }

    func signIn() {
        Task {
            await authenticate()
        }
    }

    func refresh() {
        guard let token else { return }
        Task {
            await loadMetrics(token: token)
        }
    }

    func selectRange(days: Int) {
        selectedDays = days
        refresh()
    }

    func signOut() {
        keychain.deleteToken()
        token = nil
        metrics = nil
        deviceCode = nil
        errorMessage = nil
    }

    private func authenticate() async {
        isLoading = true
        loadingMessage = "Requesting GitHub login"
        errorMessage = nil
        defer { isLoading = false }

        do {
            let code = try await authService.requestDeviceCode()
            deviceCode = code
            loadingMessage = "Waiting for GitHub authorization"
            authService.openVerificationPage(code.verificationUri)

            var delay = code.interval
            let expiresAt = Date().addingTimeInterval(TimeInterval(code.expiresIn))
            while Date() < expiresAt {
                try await Task.sleep(for: .seconds(delay))
                let response = try await authService.pollForToken(deviceCode: code.deviceCode)
                if let accessToken = response.accessToken {
                    keychain.saveToken(accessToken)
                    token = accessToken
                    deviceCode = nil
                    await loadMetrics(token: accessToken)
                    return
                }
                if response.error == "authorization_pending" {
                    continue
                }
                if response.error == "slow_down" {
                    delay += 5
                    continue
                }
                throw AppError.message(response.errorDescription ?? response.error ?? "GitHub login failed.")
            }
            throw AppError.message("GitHub login expired. Start login again.")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadMetrics(token: String) async {
        isLoading = true
        loadingMessage = "Fetching GitHub activity"
        errorMessage = nil
        defer { isLoading = false }

        do {
            metrics = try await metricsService.fetchMetrics(token: token, days: selectedDays)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
