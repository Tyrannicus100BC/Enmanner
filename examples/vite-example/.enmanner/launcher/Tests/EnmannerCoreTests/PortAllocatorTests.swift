import Darwin
import XCTest
@testable import EnmannerCore

final class PortAllocatorTests: XCTestCase {
    func testUsesAvailablePreferredPort() throws {
        let availablePort = try PortAllocator.allocateLoopbackPort()

        XCTAssertEqual(
            try PortAllocator.allocateLoopbackPort(preferredPort: availablePort),
            availablePort
        )
    }

    func testFallsBackWhenPreferredPortIsOccupied() throws {
        let socket = try BoundLoopbackSocket()
        defer { socket.close() }

        let allocated = try PortAllocator.allocateLoopbackPort(
            preferredPort: socket.port
        )

        XCTAssertNotEqual(allocated, socket.port)
    }
}

private final class BoundLoopbackSocket {
    let descriptor: Int32
    let port: UInt16

    init() throws {
        let localDescriptor = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard localDescriptor >= 0 else {
            throw EnmannerError.portAllocationFailed
        }

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = 0
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
        let bindResult = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(
                    localDescriptor,
                    $0,
                    socklen_t(MemoryLayout<sockaddr_in>.size)
                )
            }
        }
        guard bindResult == 0 else {
            Darwin.close(localDescriptor)
            throw EnmannerError.portAllocationFailed
        }

        var boundAddress = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let nameResult = withUnsafeMutablePointer(to: &boundAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(localDescriptor, $0, &length)
            }
        }
        guard nameResult == 0 else {
            Darwin.close(localDescriptor)
            throw EnmannerError.portAllocationFailed
        }
        descriptor = localDescriptor
        port = UInt16(bigEndian: boundAddress.sin_port)
    }

    func close() {
        Darwin.close(descriptor)
    }
}
