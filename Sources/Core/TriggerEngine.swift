import Foundation
import Observation

@MainActor
@Observable
final class TriggerEngine {
    private(set) var triggers: [Trigger]
    private(set) var activeTriggerIds: Set<UUID> = []

    @ObservationIgnored private var worldState: WorldState = .empty
    @ObservationIgnored private var assertionToken: PowerAssertionToken?
    @ObservationIgnored private var activePolicy: WakePolicy?

    @ObservationIgnored private let assertions: PowerAssertionService
    @ObservationIgnored private let appObserver: AppActivityObserver
    @ObservationIgnored private let scheduleObserver: ScheduleObserver
    @ObservationIgnored private let powerObserver: PowerObserver
    @ObservationIgnored private let store: TriggerStore
    @ObservationIgnored private let logger: AppLogger

    init(
        assertions: PowerAssertionService,
        appObserver: AppActivityObserver,
        scheduleObserver: ScheduleObserver,
        powerObserver: PowerObserver,
        store: TriggerStore,
        logger: AppLogger
    ) {
        self.assertions = assertions
        self.appObserver = appObserver
        self.scheduleObserver = scheduleObserver
        self.powerObserver = powerObserver
        self.store = store
        self.logger = logger
        self.triggers = store.load()
    }

    var isAnyTriggerActive: Bool { !activeTriggerIds.isEmpty }

    func start() {
        worldState = WorldState(
            runningAppBundleIds: appObserver.currentSnapshot(),
            currentDate: scheduleObserver.currentDate(),
            powerSource: powerObserver.currentPowerSource()
        )
        appObserver.start { [weak self] running in
            self?.update { $0.runningAppBundleIds = running }
        }
        scheduleObserver.start { [weak self] date in
            self?.update { $0.currentDate = date }
        }
        powerObserver.start { [weak self] power in
            self?.update { $0.powerSource = power }
        }
        reevaluate()
    }

    func stop() {
        appObserver.stop()
        scheduleObserver.stop()
        powerObserver.stop()
        releaseAssertion()
    }

    func upsert(_ trigger: Trigger) {
        if let index = triggers.firstIndex(where: { $0.id == trigger.id }) {
            triggers[index] = trigger
        } else {
            triggers.append(trigger)
        }
        persistAndReevaluate()
    }

    func remove(id: UUID) {
        triggers.removeAll { $0.id == id }
        persistAndReevaluate()
    }

    func setEnabled(id: UUID, isEnabled: Bool) {
        guard let index = triggers.firstIndex(where: { $0.id == id }) else { return }
        guard triggers[index].isEnabled != isEnabled else { return }
        triggers[index].isEnabled = isEnabled
        persistAndReevaluate()
    }

    private func update(_ change: (inout WorldState) -> Void) {
        let oldState = worldState
        change(&worldState)
        guard oldState != worldState else { return }
        reevaluate()
    }

    private func persistAndReevaluate() {
        store.save(triggers)
        reevaluate()
    }

    private func reevaluate() {
        let satisfied = triggers.filter { $0.isSatisfied(by: worldState) }
        let newIds = Set(satisfied.map(\.id))
        if newIds != activeTriggerIds {
            activeTriggerIds = newIds
        }

        let desiredPolicy = strictestPolicy(of: satisfied)
        guard desiredPolicy != activePolicy else { return }

        if let desiredPolicy {
            acquireAssertion(policy: desiredPolicy)
        } else {
            releaseAssertion()
        }
    }

    private func strictestPolicy(of triggers: [Trigger]) -> WakePolicy? {
        guard !triggers.isEmpty else { return nil }
        return triggers.contains { $0.policy == .systemAndDisplay } ? .systemAndDisplay : .systemOnly
    }

    private func acquireAssertion(policy: WakePolicy) {
        releaseAssertion()
        do {
            assertionToken = try assertions.acquire(
                policy: policy,
                reason: "CafeUp trigger keeping Mac awake"
            )
            activePolicy = policy
            logger.info("Trigger assertion acquired (\(policy))")
        } catch {
            logger.error("Trigger assertion failed: \(error.localizedDescription)")
        }
    }

    private func releaseAssertion() {
        assertionToken?.release()
        assertionToken = nil
        activePolicy = nil
    }
}
