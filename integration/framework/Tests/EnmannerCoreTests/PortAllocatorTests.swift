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

    func testFallsBackWhenReusablePreferredPortHasListener() throws {
        let socket = try BoundLoopbackSocket(reuseAddress: true)
        defer { socket.close() }
        XCTAssertEqual(Darwin.listen(socket.descriptor, 1), 0)

        let allocated = try PortAllocator.allocateLoopbackPort(
            preferredPort: socket.port
        )

        XCTAssertNotEqual(allocated, socket.port)
    }

    func testDetectsOnlyListeningLoopbackPort() throws {
        let socket = try BoundLoopbackSocket()

        XCTAssertEqual(Darwin.listen(socket.descriptor, 1), 0)
        XCTAssertTrue(PortAllocator.isLoopbackPortListening(socket.port))
        socket.close()
        XCTAssertFalse(PortAllocator.isLoopbackPortListening(socket.port))
    }

    func testReusesPreferredPortAfterRecentAcceptedConnection() throws {
        let server = try BoundLoopbackSocket(reuseAddress: true)
        XCTAssertEqual(Darwin.listen(server.descriptor, 1), 0)

        let client = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        XCTAssertGreaterThanOrEqual(client, 0)
        defer { Darwin.close(client) }

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = server.port.bigEndian
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
        let connectResult = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(
                    client,
                    $0,
                    socklen_t(MemoryLayout<sockaddr_in>.size)
                )
            }
        }
        XCTAssertEqual(connectResult, 0)

        let accepted = Darwin.accept(server.descriptor, nil, nil)
        XCTAssertGreaterThanOrEqual(accepted, 0)
        Darwin.close(accepted)
        server.close()

        XCTAssertEqual(
            try PortAllocator.allocateLoopbackPort(preferredPort: server.port),
            server.port
        )
    }
}

private final class BoundLoopbackSocket {
    let descriptor: Int32
    let port: UInt16

    init(reuseAddress: Bool = false) throws {
        let localDescriptor = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard localDescriptor >= 0 else {
            throw EnmannerError.portAllocationFailed
        }

        if reuseAddress {
            var enabled: Int32 = 1
            guard Darwin.setsockopt(
                localDescriptor,
                SOL_SOCKET,
                SO_REUSEADDR,
                &enabled,
                socklen_t(MemoryLayout<Int32>.size)
            ) == 0 else {
                Darwin.close(localDescriptor)
                throw EnmannerError.portAllocationFailed
            }
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
