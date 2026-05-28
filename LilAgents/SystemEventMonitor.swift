import AppKit
import Network
import IOKit.ps

class SystemEventMonitor {
    static let shared = SystemEventMonitor()

    var onLowBattery: ((Int) -> Void)?       // percent
    var onNetworkLost: (() -> Void)?
    var onNetworkRestored: (() -> Void)?

    private let pathMonitor = NWPathMonitor()
    private var wasOnline = true
    private var lowBatteryAlertFired = false
    private var batteryTimer: Timer?
    private let lowThreshold = 15

    func start() {
        // Network
        pathMonitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            DispatchQueue.main.async {
                guard let self else { return }
                if !online && self.wasOnline {
                    self.wasOnline = false
                    self.onNetworkLost?()
                } else if online && !self.wasOnline {
                    self.wasOnline = true
                    self.onNetworkRestored?()
                }
            }
        }
        pathMonitor.start(queue: .global(qos: .utility))

        // Battery — check every minute
        batteryTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkBattery()
        }
    }

    private func checkBattery() {
        guard let pct = batteryPercent() else { return }
        if pct <= lowThreshold && !lowBatteryAlertFired {
            lowBatteryAlertFired = true
            onLowBattery?(pct)
        } else if pct > lowThreshold + 5 {
            lowBatteryAlertFired = false
        }
    }

    func batteryPercent() -> Int? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef],
              let src = list.first,
              let desc = IOPSGetPowerSourceDescription(info, src)?.takeRetainedValue() as? [String: Any],
              let cap = desc[kIOPSCurrentCapacityKey] as? Int,
              let max = desc[kIOPSMaxCapacityKey] as? Int,
              max > 0 else { return nil }
        return Int((Float(cap) / Float(max)) * 100)
    }
}
