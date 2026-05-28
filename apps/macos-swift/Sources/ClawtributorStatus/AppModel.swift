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
    @Published var selectedDays = 1
    @Published var isLoading = false
    @Published var loadingMessage = "Idle"
    @Published var errorMessage: String?

    private let keychain = KeychainStore()
    private let authService = GitHubAuthService()
    private let metricsService = GitHubMetricsService()
    private var authTask: Task<Void, Never>?
    private var metricsTask: Task<Void, Never>?
    private var metricsCache: [Int: GitHubMetrics] = [:]

    init() {
        token = keychain.readToken()
    }

    func signIn() {
        authTask?.cancel()
        authTask = Task {
            await authenticate()
        }
    }

    func refresh() {
        guard let token else { return }
        metricsTask?.cancel()
        metricsTask = Task {
            await loadMetrics(token: token)
        }
    }

    func selectRange(days: Int) {
        selectedDays = days
        if let cached = metricsCache[days] {
            metrics = cached
        }
        refresh()
    }

    func signOut() {
        cancelRequests()
        keychain.deleteToken()
        token = nil
        metrics = nil
        deviceCode = nil
        errorMessage = nil
        isLoading = false
        loadingMessage = "Idle"
        metricsCache.removeAll()
    }

    func shutdown() {
        cancelRequests()
    }

    private func cancelRequests() {
        authTask?.cancel()
        metricsTask?.cancel()
        authTask = nil
        metricsTask = nil
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
            authService.openVerificationPage(code.verificationUri, userCode: code.userCode)

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
            if error is CancellationError || Task.isCancelled { return }
            errorMessage = error.localizedDescription
        }
    }

    private func loadMetrics(token: String) async {
        let days = selectedDays
        isLoading = true
        loadingMessage = "Fetching GitHub activity"
        errorMessage = nil
        defer { isLoading = false }

        do {
            let fresh = try await metricsService.fetchMetrics(token: token, days: days)
            if days == selectedDays {
                metrics = fresh
            }
            metricsCache[days] = fresh
        } catch {
            if error is CancellationError || Task.isCancelled { return }
            errorMessage = error.localizedDescription
        }
    }
}
