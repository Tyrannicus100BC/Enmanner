import XCTest
@testable import EnmannerCore

final class DotEnvConfigurationTests: XCTestCase {
    func testLoadsTemplateAndPreservesUnmanagedContentWhenSaving() throws {
        let directory = try temporaryDirectory()
        let templateURL = directory.appendingPathComponent(".env.example")
        try Data(
            """
            # Shared defaults
            UNMANAGED=leave-me
            UNMANAGED_MULTILINE="left for the project's dotenv loader
            still unmanaged"
            export API_KEY="sample" # paste the team key
            ASSET_DIRECTORY=/tmp/assets

            """.utf8
        ).write(to: templateURL)

        let configuration = EnmannerManifest.UserConfiguration(
            template: ".env.example",
            fields: [
                .init(
                    key: "API_KEY",
                    label: "API key",
                    type: .secret,
                    required: true
                ),
                .init(
                    key: "ASSET_DIRECTORY",
                    label: "Asset directory",
                    type: .directory
                ),
                .init(
                    key: "FEATURE_ENABLED",
                    label: "Feature enabled",
                    type: .boolean
                )
            ]
        )
        let store = DotEnvConfigurationStore(
            projectURL: directory,
            configuration: configuration
        )

        let loaded = try store.load()
        XCTAssertEqual(loaded["API_KEY"], "sample")
        XCTAssertEqual(loaded["ASSET_DIRECTORY"], "/tmp/assets")
        XCTAssertNil(loaded["FEATURE_ENABLED"])

        try store.save([
            "API_KEY": "sk-value with spaces",
            "ASSET_DIRECTORY": "/Users/Shared/Assets",
            "FEATURE_ENABLED": "true"
        ])

        let saved = try String(
            contentsOf: directory.appendingPathComponent(".env"),
            encoding: .utf8
        )
        XCTAssertTrue(saved.contains("# Shared defaults"))
        XCTAssertTrue(saved.contains("UNMANAGED=leave-me"))
        XCTAssertTrue(
            saved.contains(
                "UNMANAGED_MULTILINE=\"left for the project's dotenv loader"
            )
        )
        XCTAssertTrue(
            saved.contains(
                #"export API_KEY="sk-value with spaces" # paste the team key"#
            )
        )
        XCTAssertTrue(saved.contains("ASSET_DIRECTORY=/Users/Shared/Assets"))
        XCTAssertTrue(saved.contains("FEATURE_ENABLED=true"))
        XCTAssertEqual(
            try store.load()["API_KEY"],
            "sk-value with spaces"
        )
    }

    func testRejectsDuplicateDeclaredKeys() throws {
        let directory = try temporaryDirectory()
        try Data("TOKEN=one\nTOKEN=two\n".utf8).write(
            to: directory.appendingPathComponent(".env")
        )
        let store = DotEnvConfigurationStore(
            projectURL: directory,
            configuration: .init(
                fields: [
                    .init(key: "TOKEN", label: "Token", type: .secret)
                ]
            )
        )

        XCTAssertThrowsError(try store.load()) { error in
            XCTAssertEqual(
                error as? DotEnvConfigurationError,
                .duplicateKey("TOKEN")
            )
        }
    }

    func testRejectsMalformedQuotedDeclaredValue() throws {
        let directory = try temporaryDirectory()
        try Data("TOKEN=\"unterminated\n".utf8).write(
            to: directory.appendingPathComponent(".env")
        )
        let store = DotEnvConfigurationStore(
            projectURL: directory,
            configuration: .init(
                fields: [
                    .init(key: "TOKEN", label: "Token", type: .secret)
                ]
            )
        )

        XCTAssertThrowsError(try store.load()) { error in
            XCTAssertEqual(
                error as? DotEnvConfigurationError,
                .unsupportedValue("TOKEN")
            )
        }
    }

    func testRejectsMissingRequiredAndMultilineValues() throws {
        let directory = try temporaryDirectory()
        let store = DotEnvConfigurationStore(
            projectURL: directory,
            configuration: .init(
                fields: [
                    .init(
                        key: "TOKEN",
                        label: "API key",
                        type: .secret,
                        required: true
                    )
                ]
            )
        )

        XCTAssertThrowsError(try store.save(["TOKEN": ""])) { error in
            XCTAssertEqual(
                error as? DotEnvConfigurationError,
                .missingRequiredValue("API key")
            )
        }
        XCTAssertThrowsError(try store.save(["TOKEN": "line1\nline2"])) {
            error in
            XCTAssertEqual(
                error as? DotEnvConfigurationError,
                .invalidValue("TOKEN")
            )
        }
    }

    func testNewDotEnvFileUsesPrivatePermissions() throws {
        let directory = try temporaryDirectory()
        let store = DotEnvConfigurationStore(
            projectURL: directory,
            configuration: .init(
                fields: [
                    .init(key: "VALUE", label: "Value")
                ]
            )
        )

        try store.save(["VALUE": "configured"])

        let attributes = try FileManager.default.attributesOfItem(
            atPath: directory.appendingPathComponent(".env").path
        )
        let permissions = attributes[.posixPermissions] as? NSNumber
        XCTAssertEqual(permissions?.intValue, 0o600)
        XCTAssertEqual(
            try String(
                contentsOf: directory.appendingPathComponent(".env"),
                encoding: .utf8
            ),
            "VALUE=configured\n"
        )
    }

    func testMaterializesTemplateWithoutOverwritingExistingFile() throws {
        let directory = try temporaryDirectory()
        let template = "# Local configuration\nTOKEN=\nOPTIONAL=example\n"
        try Data(template.utf8).write(
            to: directory.appendingPathComponent(".env.example")
        )
        let store = DotEnvConfigurationStore(
            projectURL: directory,
            configuration: .init(
                template: ".env.example",
                fields: [
                    .init(
                        key: "TOKEN",
                        label: "API key",
                        type: .secret,
                        required: true
                    )
                ]
            )
        )

        XCTAssertTrue(try store.materializeIfNeeded())
        XCTAssertEqual(
            try String(
                contentsOf: directory.appendingPathComponent(".env"),
                encoding: .utf8
            ),
            template
        )
        let attributes = try FileManager.default.attributesOfItem(
            atPath: directory.appendingPathComponent(".env").path
        )
        XCTAssertEqual(
            (attributes[.posixPermissions] as? NSNumber)?.intValue,
            0o600
        )
        XCTAssertEqual(
            try store.missingRequiredFields().map(\.label),
            ["API key"]
        )

        try Data("TOKEN=already-configured\n".utf8).write(
            to: directory.appendingPathComponent(".env")
        )
        XCTAssertFalse(try store.materializeIfNeeded())
        XCTAssertEqual(
            try store.missingRequiredFields().map(\.label),
            []
        )
        XCTAssertEqual(
            try String(
                contentsOf: directory.appendingPathComponent(".env"),
                encoding: .utf8
            ),
            "TOKEN=already-configured\n"
        )
    }

    func testPreservesCommentAfterInitiallyEmptyValue() throws {
        let directory = try temporaryDirectory()
        try Data("TOKEN= # supplied per developer\n".utf8).write(
            to: directory.appendingPathComponent(".env")
        )
        let store = DotEnvConfigurationStore(
            projectURL: directory,
            configuration: .init(
                fields: [
                    .init(key: "TOKEN", label: "Token", type: .secret)
                ]
            )
        )

        XCTAssertEqual(try store.load()["TOKEN"], "")
        try store.save(["TOKEN": "configured"])

        XCTAssertEqual(
            try String(
                contentsOf: directory.appendingPathComponent(".env"),
                encoding: .utf8
            ),
            "TOKEN=configured # supplied per developer\n"
        )
    }
}
