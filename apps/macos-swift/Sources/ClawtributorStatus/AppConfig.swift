import Foundation
import SwiftUI

enum OpenClawBrand {
    // #E81B25 — wordmark / brand red
    static let red = Color(red: 232.0 / 255.0, green: 27.0 / 255.0, blue: 37.0 / 255.0)
    // #FF4F40 — lobster body, used as the accent tint
    static let lobster = Color(red: 255.0 / 255.0, green: 79.0 / 255.0, blue: 64.0 / 255.0)

    static let lobsterImage: NSImage? = {
        let bundle = Bundle.main
        let candidates: [(String, String)] = [
            ("pixel-lobster", "svg"),
            ("pixel-lobster", "png")
        ]
        for (name, ext) in candidates {
            if let url = bundle.url(forResource: name, withExtension: ext, subdirectory: "OpenClaw"),
               let image = NSImage(contentsOf: url) {
                image.isTemplate = false
                return image
            }
        }
        return nil
    }()
}

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
