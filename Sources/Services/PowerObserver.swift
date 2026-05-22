import Foundation
import IOKit
import IOKit.ps

@MainActor
protocol PowerObserver: AnyObject {
    func start(onChange: @escaping @MainActor (PowerSource) -> Void)
    func stop()
    func currentPowerSource() -> PowerSource
}

@MainActor
final class IOPSPowerObserver: PowerObserver {
    private var runLoopSource: CFRunLoopSource?
    private var onChange: ((PowerSource) -> Void)?

    func start(onChange: @escaping @MainActor (PowerSource) -> Void) {
        stop()
        self.onChange = onChange
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let unmanagedSource = IOPSNotificationCreateRunLoopSource(
            { rawContext in
                guard let rawContext else { return }
                let observer = Unmanaged<IOPSPowerObserver>.fromOpaque(rawContext).takeUnretainedValue()
                MainActor.assumeIsolated { observer.fire() }
            },
            context
        ) else { return }
        let source = unmanagedSource.takeRetainedValue()
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
    }

    func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
        }
        runLoopSource = nil
        onChange = nil
    }

    func currentPowerSource() -> PowerSource {
        guard
            let infoCF = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
            let listCF = IOPSCopyPowerSourcesList(infoCF)?.takeRetainedValue()
        else {
            return .unknown
        }
        let list = listCF as [CFTypeRef]

        var isOnACPower = true
        var batteryPercentage: Int?

        for source in list {
            guard let dict = IOPSGetPowerSourceDescription(infoCF, source)?
                .takeUnretainedValue() as? [String: Any]
            else { continue }

            if let state = dict[kIOPSPowerSourceStateKey] as? String {
                isOnACPower = (state == kIOPSACPowerValue)
            }

            if let current = dict[kIOPSCurrentCapacityKey] as? Int,
               let maximum = dict[kIOPSMaxCapacityKey] as? Int,
               maximum > 0 {
                batteryPercentage = Int((Double(current) / Double(maximum)) * 100.0)
            }
        }

        return PowerSource(isOnACPower: isOnACPower, batteryPercentage: batteryPercentage)
    }

    private func fire() { onChange?(currentPowerSource()) }
}
