import Foundation

enum AppConfig {
    static let appName = "Clawtributor Status"
    static let targetOrganization = "openclaw"
    static let githubClientId = "Ov23liweZPNo3mh79yx7"
    static let deviceCodeURL = URL(string: "https://github.com/login/device/code")!
    static let accessTokenURL = URL(string: "https://github.com/login/oauth/access_token")!
    static let graphqlURL = URL(string: "https://api.github.com/graphql")!
    static let oauthScope = "read:user"
}

enum SharedContract {
    static func query(named name: String) throws -> String {
        if let bundleURL = Bundle.main.url(forResource: name, withExtension: "graphql", subdirectory: "SharedContract/queries") {
            return try String(contentsOf: bundleURL, encoding: .utf8)
        }

        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let fallbackURL = cwd
            .appendingPathComponent("../../packages/github-contract/queries")
            .appendingPathComponent("\(name).graphql")
            .standardizedFileURL
        return try String(contentsOf: fallbackURL, encoding: .utf8)
    }
}
