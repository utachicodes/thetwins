import AppKit

class GlobalShortcut {
    static let shared = GlobalShortcut()
    var onTriggered: (() -> Void)?
    private var monitor: Any?

    func start() {
        guard AXIsProcessTrusted() else {
            let opts = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
            AXIsProcessTrustedWithOptions(opts as CFDictionary)
            // Retry once per minute until granted
            DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in self?.start() }
            return
        }
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // ⌘⇧Space (keyCode 49)
            guard event.keyCode == 49,
                  event.modifierFlags.contains(.command),
                  event.modifierFlags.contains(.shift) else { return }
            DispatchQueue.main.async { self?.onTriggered?() }
        }
    }

    func stop() {
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
    }

    deinit { stop() }
}
