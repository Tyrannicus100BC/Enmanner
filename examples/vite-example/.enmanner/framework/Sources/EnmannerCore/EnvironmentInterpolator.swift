import Foundation

public enum EnvironmentInterpolator {
    private static let tokenPattern = #"\$\{([A-Z][A-Z0-9_]*)\}"#

    public static func expand(
        _ value: String,
        variables: [String: String]
    ) throws -> String {
        let regex = try NSRegularExpression(pattern: tokenPattern)
        let range = NSRange(value.startIndex..., in: value)
        let matches = regex.matches(in: value, range: range).reversed()
        var result = value

        for match in matches {
            guard let tokenRange = Range(match.range(at: 0), in: result),
                  let nameRange = Range(match.range(at: 1), in: result) else {
                continue
            }
            let token = String(result[tokenRange])
            let name = String(result[nameRange])
            guard let replacement = variables[name] else {
                throw EnmannerError.invalidInterpolation(token)
            }
            result.replaceSubrange(tokenRange, with: replacement)
        }

        if result.contains("${") {
            throw EnmannerError.invalidInterpolation(result)
        }
        return result
    }

    public static func expand(
        _ values: [String: String],
        variables: [String: String]
    ) throws -> [String: String] {
        try values.mapValues { try expand($0, variables: variables) }
    }
}
