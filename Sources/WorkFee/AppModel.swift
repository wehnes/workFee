import AppKit
import Combine
import WorkFeeCore

@MainActor
final class AppModel: ObservableObject {
    @Published var preferences: Preferences
    @Published var snapshot: PayrollSnapshot
    @Published var previewTransparency: Int?
    let store: SettingsStore
    private var timer: Timer?
    private var wakeObserver: NSObjectProtocol?

    init(settings: Preferences, store: SettingsStore) {
        self.preferences = settings
        self.snapshot = Payroll.calculate(settings, now: Date())
        self.store = store
    }

    var backgroundOpacity: Double {
        1 - Double(previewTransparency ?? preferences.backgroundTransparency) / 100
    }

    func startClock() {
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        snapshot = Payroll.calculate(preferences, now: Date())
    }

    func stopClock() {
        timer?.invalidate()
        timer = nil
        if let observer = wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            wakeObserver = nil
        }
    }
}
