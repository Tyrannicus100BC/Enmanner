import Foundation

public struct EnmannerManifest: Codable, Equatable, Sendable {
    public let version: Int
    public let name: String
    public let identifier: String
    public let server: Server
    public let window: Window
    public let icon: String?

    public init(
        version: Int,
        name: String,
        identifier: String,
        server: Server,
        window: Window = Window(),
        icon: String? = nil
    ) {
        self.version = version
        self.name = name
        self.identifier = identifier
        self.server = server
        self.window = window
        self.icon = icon
    }

    public struct Server: Codable, Equatable, Sendable {
        public let command: [String]
        public let workingDirectory: String
        public let environment: [String: String]
        public let preferredPort: UInt16?
        public let readiness: Readiness

        public init(
            command: [String],
            workingDirectory: String = ".",
            environment: [String: String] = [:],
            preferredPort: UInt16? = nil,
            readiness: Readiness
        ) {
            self.command = command
            self.workingDirectory = workingDirectory
            self.environment = environment
            self.preferredPort = preferredPort
            self.readiness = readiness
        }

        private enum CodingKeys: String, CodingKey {
            case command
            case workingDirectory
            case environment
            case preferredPort
            case readiness
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            command = try container.decode([String].self, forKey: .command)
            workingDirectory = try container.decode(
                String.self,
                forKey: .workingDirectory
            )
            environment = try container.decodeIfPresent(
                [String: String].self,
                forKey: .environment
            ) ?? [:]
            preferredPort = try container.decodeIfPresent(
                UInt16.self,
                forKey: .preferredPort
            )
            readiness = try container.decode(Readiness.self, forKey: .readiness)
        }
    }

    public struct Readiness: Codable, Equatable, Sendable {
        public let url: String
        public let timeoutSeconds: Double
        public let acceptableStatusCodes: [Int]?
        public let contentTypeContains: String?
        public let bodyContains: String?

        public init(
            url: String,
            timeoutSeconds: Double = 30,
            acceptableStatusCodes: [Int]? = nil,
            contentTypeContains: String? = nil,
            bodyContains: String? = nil
        ) {
            self.url = url
            self.timeoutSeconds = timeoutSeconds
            self.acceptableStatusCodes = acceptableStatusCodes
            self.contentTypeContains = contentTypeContains
            self.bodyContains = bodyContains
        }
    }

    public struct Window: Codable, Equatable, Sendable {
        public enum Mode: String, Codable, Sendable {
            case embedded
            case browser

            public var launchesWindowless: Bool {
                self == .browser
            }

            public var keepsRunningAfterLastWindowClosed: Bool {
                true
            }
        }

        public let mode: Mode
        public let width: Double
        public let height: Double
        public let resizable: Bool

        public init(
            mode: Mode = .browser,
            width: Double = 1200,
            height: Double = 800,
            resizable: Bool = true
        ) {
            self.mode = mode
            self.width = width
            self.height = height
            self.resizable = resizable
        }
    }

}

public enum ManifestLoader {
    public static func load(from url: URL) throws -> EnmannerManifest {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw EnmannerError.manifestMissing(url)
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .useDefaultKeys
            return try decoder.decode(EnmannerManifest.self, from: data)
        } catch let error as EnmannerError {
            throw error
        } catch let error as DecodingError {
            throw decodingError(error)
        } catch {
            throw EnmannerError.malformedManifest(
                path: nil,
                detail: error.localizedDescription
            )
        }
    }

    private static func decodingError(_ error: DecodingError) -> EnmannerError {
        let path: String?
        let detail: String

        switch error {
        case .keyNotFound(let key, let context):
            path = codingPath(context.codingPath + [key])
            detail = "Missing required field."
        case .typeMismatch(let type, let context):
            path = codingPath(context.codingPath)
            detail = "Expected \(String(describing: type)). \(context.debugDescription)"
        case .valueNotFound(let type, let context):
            path = codingPath(context.codingPath)
            detail = "Expected \(String(describing: type)); found null."
        case .dataCorrupted(let context):
            path = codingPath(context.codingPath)
            detail = context.debugDescription
        @unknown default:
            path = nil
            detail = error.localizedDescription
        }

        return .malformedManifest(path: path, detail: detail)
    }

    private static func codingPath(_ keys: [CodingKey]) -> String? {
        let components = keys.map {
            $0.intValue.map(String.init) ?? $0.stringValue
        }
        return components.isEmpty ? nil : components.joined(separator: ".")
    }
}

public enum ManifestValidator {
    private static let identifierPattern =
        #"^[A-Za-z0-9][A-Za-z0-9-]*(\.[A-Za-z0-9][A-Za-z0-9-]*)+$"#
    private static let secretKeyPattern =
        #"(?i)(secret|token|password|api[_-]?key|private[_-]?key)"#

    public static func validate(_ manifest: EnmannerManifest, projectURL: URL) -> [String] {
        var issues: [String] = []
        let fileManager = FileManager.default

        if manifest.version != 2 {
            issues.append("version must be 2.")
        }
        if manifest.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("name must not be empty.")
        }
        if manifest.name == "." || manifest.name == ".." ||
            manifest.name.contains("/") || manifest.name.contains(":") ||
            manifest.name.rangeOfCharacter(from: .controlCharacters) != nil {
            issues.append("name contains characters that cannot be used for an app bundle.")
        }
        if manifest.identifier.range(
            of: identifierPattern,
            options: .regularExpression
        ) == nil {
            issues.append("identifier must look like a reverse-DNS identifier.")
        }
        if manifest.server.command.isEmpty ||
            manifest.server.command.first?.trimmingCharacters(in: .whitespaces).isEmpty != false {
            issues.append("server.command must contain an executable.")
        }
        if manifest.server.command.contains("-g") ||
            manifest.server.command.contains("--global") {
            issues.append("server.command must not depend on a global package installation.")
        }
        if manifest.server.readiness.timeoutSeconds <= 0 ||
            manifest.server.readiness.timeoutSeconds > 300 {
            issues.append("server.readiness.timeoutSeconds must be between 1 and 300.")
        }
        if let statusCodes = manifest.server.readiness.acceptableStatusCodes,
           statusCodes.isEmpty ||
            statusCodes.contains(where: { !(100...599).contains($0) }) {
            issues.append(
                "server.readiness.acceptableStatusCodes must contain HTTP status codes from 100 through 599."
            )
        }
        if manifest.server.readiness.contentTypeContains == "" {
            issues.append("server.readiness.contentTypeContains must not be empty.")
        }
        if manifest.server.readiness.bodyContains == "" {
            issues.append("server.readiness.bodyContains must not be empty.")
        }
        if let preferredPort = manifest.server.preferredPort,
           preferredPort < 1024 {
            issues.append("server.preferredPort must be between 1024 and 65535.")
        }
        if !(320...4096).contains(Int(manifest.window.width)) ||
            !(240...2160).contains(Int(manifest.window.height)) {
            issues.append("window dimensions are outside the supported range.")
        }

        do {
            let workingURL = try ProjectPaths.resolve(
                manifest.server.workingDirectory,
                inside: projectURL
            )
            var isDirectory: ObjCBool = false
            if !fileManager.fileExists(atPath: workingURL.path, isDirectory: &isDirectory) ||
                !isDirectory.boolValue {
                issues.append("server.workingDirectory does not exist or is not a directory.")
            }
        } catch {
            issues.append("server.workingDirectory must stay inside the project.")
        }

        let sampleVariables = [
            "ENMANNER_PORT": "49152",
            "ENMANNER_PROJECT_DIR": projectURL.path
        ]
        if let expanded = try? EnvironmentInterpolator.expand(
            manifest.server.readiness.url,
            variables: sampleVariables
        ), let url = URL(string: expanded) {
            let host = url.host?.lowercased()
            if url.scheme != "http" && url.scheme != "https" {
                issues.append("server.readiness.url must use http or https.")
            }
            if host != "127.0.0.1" && host != "localhost" && host != "::1" {
                issues.append("server.readiness.url must use a loopback host.")
            }
        } else {
            issues.append("server.readiness.url is not a valid URL.")
        }

        for (key, value) in manifest.server.environment {
            if key.range(of: secretKeyPattern, options: .regularExpression) != nil &&
                !value.contains("${") {
                issues.append("server.environment appears to contain a secret in \(key); keep secrets out of enmanner.json.")
            }
        }

        if let icon = manifest.icon {
            do {
                let iconURL = try ProjectPaths.resolve(icon, inside: projectURL)
                let supportedExtensions = ["icns", "icon"]
                if !supportedExtensions.contains(iconURL.pathExtension.lowercased()) {
                    issues.append("icon must be an .icon package or .icns file.")
                } else if !fileManager.fileExists(atPath: iconURL.path) {
                    issues.append("icon does not exist at \(icon).")
                }
            } catch {
                issues.append("icon must stay inside the project.")
            }
        }

        return issues
    }
}
