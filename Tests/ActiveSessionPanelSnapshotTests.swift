import SwiftUI
import XCTest
@testable import CafeUp

@MainActor
final class ActiveSessionPanelSnapshotTests: XCTestCase {

    func test_snapshot_timedSession_default() throws {
        let sut = makeSUT()
        sut.viewModel.start(duration: .seconds(13 * 60 + 47))

        let panel = ActiveSessionPanel(viewModel: sut.viewModel, onEnd: {})
            .background(Color(nsColor: .windowBackgroundColor))

        try renderAndSave(panel, named: "panel-timed-default")
    }

    func test_snapshot_timedSession_defaultPolicy() throws {
        let sut = makeSUT()
        sut.viewModel.start(duration: .seconds(13 * 60 + 47))
        // Default policy: display stays on, system may sleep when the lid is closed,
        // screen saver disabled. Only the middle toggle is on.
        sut.viewModel.policy.allowDisplaySleep = false
        sut.viewModel.policy.allowSystemSleepWhenLidClosed = true
        sut.viewModel.policy.allowScreenSaverAfter45Min = false

        let panel = ActiveSessionPanel(viewModel: sut.viewModel, onEnd: {})
            .background(Color(nsColor: .windowBackgroundColor))

        try renderAndSave(panel, named: "panel-default-policy")
    }

    func test_snapshot_indefiniteSession() throws {
        let sut = makeSUT()
        sut.viewModel.startIndefinite()

        let panel = ActiveSessionPanel(viewModel: sut.viewModel, onEnd: {})
            .background(Color(nsColor: .windowBackgroundColor))

        try renderAndSave(panel, named: "panel-indefinite")
    }

    func test_snapshot_allTogglesOn() throws {
        let sut = makeSUT()
        sut.viewModel.start(duration: .seconds(30 * 60))
        sut.viewModel.policy.allowDisplaySleep = true
        sut.viewModel.policy.allowSystemSleepWhenLidClosed = true
        sut.viewModel.policy.allowScreenSaverAfter45Min = true

        let panel = ActiveSessionPanel(viewModel: sut.viewModel, onEnd: {})
            .background(Color(nsColor: .windowBackgroundColor))

        try renderAndSave(panel, named: "panel-all-on")
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
    }

    private func makeSUT() -> SUT {
        // Use a real-wall-clock so sessionStatusLine's `Date()` math produces a
        // realistic "Xm Ys remaining" instead of clamping to zero.
        let sessionEngine = SessionEngine(
            assertions: FakePowerAssertionService(),
            clock: SystemClock(),
            scheduler: FakeScheduler(),
            logger: SilentLogger(),
            alertSounds: FakeSessionAlertSounds()
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
        return SUT(viewModel: viewModel)
    }
}
