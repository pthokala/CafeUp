import SwiftUI
import XCTest
@testable import CafeUp

/// These tests render `MenuBarView` outside of `MenuBarExtra` for visual verification.
/// The rendered image is saved to `/tmp/cafeup-snapshots/` so the developer can eyeball
/// the structure produced when a session is active — covers the three sleep toggles,
/// the prominent End Current Session row, the "Indeterminate time remaining" wording.
@MainActor
final class MenuBarViewSnapshotTests: XCTestCase {

    func test_renderActiveSessionMenu_savesToTmp() throws {
        let sut = makeSUT()
        sut.viewModel.startIndefinite()

        let menu = MenuBarView(
            viewModel: sut.viewModel,
            openSettings: {},
            openCustomDuration: {},
            openEndAtTime: {},
            pickApplication: { nil }
        )
        .frame(width: 360)
        .padding(8)
        .background(Color(nsColor: .windowBackgroundColor))

        try renderAndSave(menu, named: "active-indefinite")
    }

    func test_renderActiveSessionMenu_timed_savesToTmp() throws {
        let sut = makeSUT()
        sut.viewModel.start(duration: .seconds(15 * 60))

        let menu = MenuBarView(
            viewModel: sut.viewModel,
            openSettings: {},
            openCustomDuration: {},
            openEndAtTime: {},
            pickApplication: { nil }
        )
        .frame(width: 360)
        .padding(8)
        .background(Color(nsColor: .windowBackgroundColor))

        try renderAndSave(menu, named: "active-timed-15min")
    }

    func test_renderIdleMenu_savesToTmp() throws {
        let sut = makeSUT()

        let menu = MenuBarView(
            viewModel: sut.viewModel,
            openSettings: {},
            openCustomDuration: {},
            openEndAtTime: {},
            pickApplication: { nil }
        )
        .frame(width: 360)
        .padding(8)
        .background(Color(nsColor: .windowBackgroundColor))

        try renderAndSave(menu, named: "idle")
    }

    func test_activeSession_exposesAllThreeToggles_throughViewModel() {
        let sut = makeSUT()
        sut.viewModel.startIndefinite()

        // Flip each toggle through the same path the SwiftUI bindings use.
        sut.viewModel.policy.allowDisplaySleep = true
        XCTAssertTrue(sut.viewModel.policy.allowDisplaySleep)
        XCTAssertEqual(sut.assertions.lastPolicy?.allowDisplaySleep, true)

        sut.viewModel.policy.allowSystemSleepWhenLidClosed = false
        XCTAssertFalse(sut.viewModel.policy.allowSystemSleepWhenLidClosed)
        XCTAssertEqual(sut.assertions.lastPolicy?.allowSystemSleepWhenLidClosed, false)

        sut.viewModel.policy.allowScreenSaverAfter45Min = true
        XCTAssertTrue(sut.viewModel.policy.allowScreenSaverAfter45Min)
    }

    func test_endCurrentSession_stopsThroughViewModel() {
        let sut = makeSUT()
        sut.viewModel.startIndefinite()
        XCTAssertTrue(sut.viewModel.isManualSessionActive)

        sut.viewModel.stop()

        XCTAssertFalse(sut.viewModel.isManualSessionActive)
        XCTAssertEqual(sut.assertions.lastIssuedToken?.released, true)
    }

    // MARK: - Helpers

    private func renderAndSave<V: View>(_ view: V, named name: String) throws {
        let dir = URL(fileURLWithPath: "/tmp/cafeup-snapshots", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let nsImage = renderer.nsImage,
              let tiff = nsImage.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            XCTFail("Failed to render snapshot")
            return
        }
        let url = dir.appendingPathComponent("\(name).png")
        try png.write(to: url)
        print("Snapshot saved: \(url.path)")
    }

    private struct SUT {
        let viewModel: MenuBarViewModel
        let assertions: FakePowerAssertionService
    }

    private func makeSUT() -> SUT {
        let assertions = FakePowerAssertionService()
        let sessionEngine = SessionEngine(
            assertions: assertions,
            clock: FakeClock(),
            scheduler: FakeScheduler(),
            logger: SilentLogger()
        )
        let triggerEngine = TriggerEngine(
            assertions: FakePowerAssertionService(),
            appObserver: FakeAppActivityObserver(),
            scheduleObserver: FakeScheduleObserver(),
            powerObserver: FakePowerObserver(),
            store: InMemoryTriggerStore(initial: []),
            logger: SilentLogger()
        )
        let viewModel = MenuBarViewModel(
            engine: sessionEngine,
            triggerEngine: triggerEngine,
            tickScheduler: FakeScheduler()
        )
        return SUT(viewModel: viewModel, assertions: assertions)
    }
}
