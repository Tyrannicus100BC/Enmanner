import Foundation

public enum EnmannerError: LocalizedError, Equatable {
    case manifestMissing(URL)
    case malformedManifest(String)
    case invalidManifest([String])
    case invalidInterpolation(String)
    case executableNotFound(String)
    case processAlreadyRunning
    case processLaunchFailed(String)
    case portAllocationFailed

    public var errorDescription: String? {
        switch self {
        case .manifestMissing(let url):
            return "Enmanner could not find enmanner.json at \(url.path)."
        case .malformedManifest(let detail):
            return "Enmanner could not read enmanner.json. \(detail)"
        case .invalidManifest(let issues):
            return "enmanner.json needs attention:\n• " + issues.joined(separator: "\n• ")
        case .invalidInterpolation(let token):
            return "The manifest uses an unsupported variable: \(token)."
        case .executableNotFound(let executable):
            return "Enmanner could not find “\(executable)” in the application environment."
        case .processAlreadyRunning:
            return "The application server is already running."
        case .processLaunchFailed(let detail):
            return "Enmanner could not start the application server. \(detail)"
        case .portAllocationFailed:
            return "Enmanner could not reserve a local network port."
        }
    }
}
