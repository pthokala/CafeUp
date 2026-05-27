import XCTest
@testable import CafeUp

@MainActor
final class URLCommandRouterTests: XCTestCase {

    // MARK: - Happy path: start

    func test_start_withoutMinutes_isIndefinite() {
        let (router, handler) = makeSUT()
        let outcome = router.handle(url("cafeup://start"))
        XCTAssertEqual(outcome, .accepted(.startIndefinite))
        XCTAssertEqual(handler.calls, [.startIndefinite])
    }

    func test_start_withMinutes_dispatchesTimed() {
        let (router, handler) = makeSUT()
        let outcome = router.handle(url("cafeup://start?minutes=30"))
        XCTAssertEqual(outcome, .accepted(.startTimed(minutes: 30)))
        XCTAssertEqual(handler.calls, [.startTimed(minutes: 30)])
    }

    func test_start_minutesAtLowerBound_accepted() {
        let (router, handler) = makeSUT()
        let outcome = router.handle(url("cafeup://start?minutes=1"))
        XCTAssertEqual(outcome, .accepted(.startTimed(minutes: 1)))
        XCTAssertEqual(handler.calls, [.startTimed(minutes: 1)])
    }

    func test_start_minutesAtUpperBound_accepted() {
        let (router, _) = makeSUT()
        let outcome = router.handle(url("cafeup://start?minutes=1440"))
        XCTAssertEqual(outcome, .accepted(.startTimed(minutes: 1440)))
    }

    // MARK: - Edge cases: start

    func test_start_minutesZero_rejected() {
        let (router, handler) = makeSUT()
        let outcome = router.handle(url("cafeup://start?minutes=0"))
        XCTAssertEqual(outcome, .rejected(.parameterOutOfRange(name: "minutes", value: "0", allowed: "1…1440")))
        XCTAssertTrue(handler.calls.isEmpty)
    }

    func test_start_minutesNegative_rejected() {
        let (router, _) = makeSUT()
        let outcome = router.handle(url("cafeup://start?minutes=-5"))
        XCTAssertEqual(outcome, .rejected(.parameterOutOfRange(name: "minutes", value: "-5", allowed: "1…1440")))
    }

    func test_start_minutesAboveMax_rejected() {
        let (router, _) = makeSUT()
        let outcome = router.handle(url("cafeup://start?minutes=1441"))
        XCTAssertEqual(outcome, .rejected(.parameterOutOfRange(name: "minutes", value: "1441", allowed: "1…1440")))
    }

    func test_start_minutesNonNumeric_rejected() {
        let (router, handler) = makeSUT()
        let outcome = router.handle(url("cafeup://start?minutes=abc"))
        XCTAssertEqual(outcome, .rejected(.invalidParameter(name: "minutes", value: "abc")))
        XCTAssertTrue(handler.calls.isEmpty)
    }

    func test_start_emptyMinutesValue_treatedAsAbsent() {
        // `?minutes=` parses as nil-or-empty; treat as if not supplied.
        let (router, handler) = makeSUT()
        let outcome = router.handle(url("cafeup://start?minutes="))
        XCTAssertEqual(outcome, .accepted(.startIndefinite))
        XCTAssertEqual(handler.calls, [.startIndefinite])
    }

    func test_start_repeatedMinutesKey_usesFirst() {
        let (router, handler) = makeSUT()
        let outcome = router.handle(url("cafeup://start?minutes=15&minutes=999"))
        XCTAssertEqual(outcome, .accepted(.startTimed(minutes: 15)))
        XCTAssertEqual(handler.calls, [.startTimed(minutes: 15)])
    }

    func test_start_unknownQueryParam_ignored() {
        // Forward-compat: unknown params must not break valid commands.
        let (router, _) = makeSUT()
        let outcome = router.handle(url("cafeup://start?foo=bar&minutes=10"))
        XCTAssertEqual(outcome, .accepted(.startTimed(minutes: 10)))
    }

    // MARK: - Happy path: stop

    func test_stop_dispatches() {
        let (router, handler) = makeSUT()
        let outcome = router.handle(url("cafeup://stop"))
        XCTAssertEqual(outcome, .accepted(.stop))
        XCTAssertEqual(handler.calls, [.stop])
    }

    func test_stop_ignoresQueryParams() {
        let (router, _) = makeSUT()
        let outcome = router.handle(url("cafeup://stop?confirm=yes"))
        XCTAssertEqual(outcome, .accepted(.stop))
    }

    // MARK: - Happy path: policy

    func test_policy_singleField_displayTrue() {
        let (router, handler) = makeSUT()
        let outcome = router.handle(url("cafeup://policy?display=true"))
        let expected = PolicyUpdate(allowDisplaySleep: true)
        XCTAssertEqual(outcome, .accepted(.updatePolicy(expected)))
        XCTAssertEqual(handler.calls, [.updatePolicy(expected)])
    }

    func test_policy_allThreeFields() {
        let (router, _) = makeSUT()
        let outcome = router.handle(
            url("cafeup://policy?display=true&lidClosed=false&screensaver=true")
        )
        let expected = PolicyUpdate(
            allowDisplaySleep: true,
            allowSystemSleepWhenLidClosed: false,
            allowScreenSaverAfter45Min: true
        )
        XCTAssertEqual(outcome, .accepted(.updatePolicy(expected)))
    }

    func test_policy_boolCaseInsensitive() {
        let (router, _) = makeSUT()
        let outcome = router.handle(url("cafeup://policy?display=TRUE&lidClosed=False"))
        let expected = PolicyUpdate(
            allowDisplaySleep: true,
            allowSystemSleepWhenLidClosed: false
        )
        XCTAssertEqual(outcome, .accepted(.updatePolicy(expected)))
    }

    // MARK: - Edge cases: policy

    func test_policy_noParameters_rejected() {
        let (router, handler) = makeSUT()
        let outcome = router.handle(url("cafeup://policy"))
        XCTAssertEqual(outcome, .rejected(.noPolicyParameters))
        XCTAssertTrue(handler.calls.isEmpty)
    }

    func test_policy_onlyUnknownParameters_rejected() {
        let (router, _) = makeSUT()
        let outcome = router.handle(url("cafeup://policy?foo=true"))
        XCTAssertEqual(outcome, .rejected(.noPolicyParameters))
    }

    func test_policy_invalidBoolValue_rejected() {
        let (router, handler) = makeSUT()
        let outcome = router.handle(url("cafeup://policy?display=yes"))
        XCTAssertEqual(outcome, .rejected(.invalidParameter(name: "display", value: "yes")))
        XCTAssertTrue(handler.calls.isEmpty)
    }

    func test_policy_invalidNumericValue_rejected() {
        let (router, _) = makeSUT()
        let outcome = router.handle(url("cafeup://policy?lidClosed=1"))
        XCTAssertEqual(outcome, .rejected(.invalidParameter(name: "lidClosed", value: "1")))
    }

    func test_policy_emptyValueTreatedAsAbsent() {
        // `?display=&lidClosed=true` — display is absent (empty), lidClosed is set.
        let (router, _) = makeSUT()
        let outcome = router.handle(url("cafeup://policy?display=&lidClosed=true"))
        let expected = PolicyUpdate(allowSystemSleepWhenLidClosed: true)
        XCTAssertEqual(outcome, .accepted(.updatePolicy(expected)))
    }

    func test_policy_unknownAndValidFieldsMixed() {
        let (router, _) = makeSUT()
        let outcome = router.handle(url("cafeup://policy?foo=bar&display=false&baz=1"))
        let expected = PolicyUpdate(allowDisplaySleep: false)
        XCTAssertEqual(outcome, .accepted(.updatePolicy(expected)))
    }

    // MARK: - URL-level rejections

    func test_wrongScheme_rejected() {
        let (router, handler) = makeSUT()
        let outcome = router.handle(url("http://start"))
        XCTAssertEqual(outcome, .rejected(.wrongScheme("http")))
        XCTAssertTrue(handler.calls.isEmpty)
    }

    func test_schemeIsCaseInsensitive() {
        let (router, _) = makeSUT()
        let outcome = router.handle(url("CAFEUP://stop"))
        XCTAssertEqual(outcome, .accepted(.stop))
    }

    func test_commandIsCaseInsensitive() {
        let (router, _) = makeSUT()
        let outcome = router.handle(url("cafeup://STOP"))
        XCTAssertEqual(outcome, .accepted(.stop))
    }

    func test_unknownCommand_rejected() {
        let (router, _) = makeSUT()
        let outcome = router.handle(url("cafeup://restart"))
        XCTAssertEqual(outcome, .rejected(.unknownCommand("restart")))
    }

    func test_missingCommand_rejected() {
        // `cafeup://` has no host.
        let (router, _) = makeSUT()
        let outcome = router.handle(url("cafeup://"))
        XCTAssertEqual(outcome, .rejected(.missingCommand))
    }

    func test_schemeOnlyNoSlashes_rejected() {
        // `cafeup:` (no //) is missing host — URLComponents won't expose one.
        let (router, _) = makeSUT()
        let outcome = router.handle(url("cafeup:"))
        XCTAssertEqual(outcome, .rejected(.missingCommand))
    }

    // MARK: - Handler errors surface as handlerFailed

    func test_handlerError_returnsHandlerFailed() {
        let handler = FakeAgentCommandHandler()
        handler.errorToThrow = IntentError.notRegistered
        let router = URLCommandRouter(handler: handler, logger: SilentLogger())

        let outcome = router.handle(url("cafeup://start"))
        guard case .handlerFailed(let cmd, _) = outcome else {
            return XCTFail("Expected .handlerFailed, got \(outcome)")
        }
        XCTAssertEqual(cmd, .startIndefinite)
    }

    // MARK: - Multiple URLs in succession (idempotence / no state leakage)

    func test_routerHasNoStateAcrossCalls() {
        let (router, handler) = makeSUT()
        router.handle(url("cafeup://start"))
        router.handle(url("cafeup://stop"))
        router.handle(url("cafeup://start?minutes=5"))
        XCTAssertEqual(handler.calls, [
            .startIndefinite,
            .stop,
            .startTimed(minutes: 5)
        ])
    }

    // MARK: - Helpers

    private func makeSUT() -> (URLCommandRouter, FakeAgentCommandHandler) {
        let handler = FakeAgentCommandHandler()
        let router = URLCommandRouter(handler: handler, logger: SilentLogger())
        return (router, handler)
    }

    private func url(_ s: String) -> URL {
        URL(string: s)!
    }
}
