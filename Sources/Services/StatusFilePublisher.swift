import Foundation
import Observation

/// Observes CafeUp's runtime state via the Observation framework and pushes
/// each change to a `StatusWriter`.
///
/// ## How observation is wired
/// We don't pass `@Observable` references in directly — instead, the caller
/// supplies a `snapshot` closure that *reads* observable properties (e.g.
/// `engine.current`, `viewModel.policy`). Reading those properties inside
/// `withObservationTracking`'s body registers them as dependencies; when any
/// changes, `onChange` fires once and we re-establish tracking.
///
/// ## Why this is lightweight
/// - No timer, no polling — the publisher does nothing between state changes.
/// - `onChange` fires at most once per tracking cycle, so a burst of property
///   writes coalesces into a single re-observe-and-write cycle on the next
///   runloop turn.
/// - The writer itself dedupes unchanged payloads (see `FileSystemStatusWriter`).
///
/// ## Lifecycle
/// - `start()` performs the initial write so the file exists on first launch.
/// - `flushNow()` writes synchronously; call from `applicationWillTerminate`
///   *after* stopping the session so the final "inactive" snapshot lands on
///   disk even when pending main-actor Tasks don't get drained.
@MainActor
final class StatusFilePublisher {
    private let snapshot: () -> StatusSnapshot
    private let writer: StatusWriter
    private var isStarted = false

    init(snapshot: @escaping () -> StatusSnapshot, writer: StatusWriter) {
        self.snapshot = snapshot
        self.writer = writer
    }

    /// Begin observing. Safe to call multiple times — second and later calls
    /// are no-ops.
    func start() {
        guard !isStarted else { return }
        isStarted = true
        observe()
    }

    /// Write the current snapshot synchronously, bypassing the observation
    /// loop. Use when you need a guaranteed final write before process exit.
    func flushNow() {
        writer.write(snapshot())
    }

    private func observe() {
        withObservationTracking {
            // Reading observable properties inside `snapshot()` registers
            // them as dependencies for this tracking cycle.
            writer.write(snapshot())
        } onChange: { [weak self] in
            // `onChange` fires once per cycle, on whatever queue the mutation
            // happened on. We re-enter `observe()` on the main actor so the
            // next read+write happens in the right isolation context.
            Task { @MainActor [weak self] in
                self?.observe()
            }
        }
    }
}
