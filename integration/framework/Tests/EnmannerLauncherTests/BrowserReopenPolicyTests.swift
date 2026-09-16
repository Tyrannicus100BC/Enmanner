import XCTest
@testable import EnmannerLauncher

final class BrowserReopenPolicyTests: XCTestCase {
    func testFastDoubleClickAfterActivation() {
        var policy = BrowserReopenPolicy()
        policy.willBecomeActive(at: 10)
        XCTAssertTrue(policy.consumeReopen(at: 10.01))
        XCTAssertFalse(policy.consumeReopen(at: 10.08))
    }

    func testReopenBeforeActivationDoesNotSwallowSecondClick() {
        var policy = BrowserReopenPolicy()
        XCTAssertTrue(policy.consumeReopen(at: 10))
        policy.willBecomeActive(at: 10.01)
        XCTAssertFalse(policy.consumeReopen(at: 10.08))
    }

    func testSlowSecondClickStillOpensBrowser() {
        var policy = BrowserReopenPolicy()
        policy.willBecomeActive(at: 10)
        XCTAssertTrue(policy.consumeReopen(at: 10.01))
        XCTAssertFalse(policy.consumeReopen(at: 11))
    }

    func testActivationWithoutReopenAllowsLaterDockClick() {
        var policy = BrowserReopenPolicy()
        policy.willBecomeActive(at: 10)
        XCTAssertFalse(policy.consumeReopen(at: 11))
    }

    func testResigningActiveRearmsOnlyOneForegroundClick() {
        var policy = BrowserReopenPolicy()
        policy.willBecomeActive(at: 10)
        XCTAssertTrue(policy.consumeReopen(at: 10.01))
        XCTAssertFalse(policy.consumeReopen(at: 10.08))
        policy.didResignActive()
        XCTAssertTrue(policy.consumeReopen(at: 10.10))
        policy.willBecomeActive(at: 10.11)
        XCTAssertFalse(policy.consumeReopen(at: 10.18))
    }
}
