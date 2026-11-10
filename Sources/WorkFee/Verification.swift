import AppKit
import Darwin
import WorkFeeCore

extension AppDelegate {
    func verifyInterface() {
        do {
            let directory = URL(fileURLWithPath: ProcessInfo.processInfo.environment["WORKFEE_VERIFY_OUTPUT"] ?? NSTemporaryDirectory())
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
                if !condition() { throw NSError(domain: "WorkFee.Verify", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
                print("PASS \(message)")
            }
            func pump() { RunLoop.main.run(until: Date().addingTimeInterval(0.2)) }
            func capture(_ window: NSWindow, _ name: String) throws {
                pump()
                guard let view = window.contentView,
                      let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
                    throw NSError(domain: "WorkFee.Verify", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot render own window"])
                }
                view.cacheDisplay(in: view.bounds, to: bitmap)
                guard let data = bitmap.representation(using: .png, properties: [:]) else {
                    throw NSError(domain: "WorkFee.Verify", code: 3)
                }
                try data.write(to: directory.appendingPathComponent(name))
            }
            try require(mainWindow.isVisible && !floatingWindow.isVisible, "main window launches")
            let sizes: [(CGFloat, CGFloat, String)] = [(576, 488, "main"), (320, 272, "compact"), (1000, 400, "wide"), (400, 800, "tall")]
            for (width, height, name) in sizes {
                mainWindow.setContentSize(NSSize(width: width, height: height))
                try capture(mainWindow, "\(name).png")
                try require(abs(mainWindow.frame.width - width) < 1, "resize \(name)")
            }
            let mainFrame = mainWindow.frame
            showFloating()
            pump()
            try require(floatingWindow.isVisible && !mainWindow.isVisible, "floating mode switches windows")
            try require(floatingWindow.level == .floating && !floatingWindow.hidesOnDeactivate, "floating mode stays above apps")
            floatingWindow.setContentSize(NSSize(width: 280, height: 96))
            try capture(floatingWindow, "floating.png")
            model.previewTransparency = 100
            try capture(floatingWindow, "floating-transparent.png")
            try require(model.backgroundOpacity == 0, "background reaches full transparency")
            model.previewTransparency = nil
            try require(model.backgroundOpacity == 1, "cancelled preview restores opacity")
            let before = model.preferences
            showMain()
            pump()
            try require(mainWindow.frame == mainFrame && mainWindow.isVisible, "main size survives mode switch")
            showFloating()
            pump()
            try require(abs(floatingWindow.frame.width - 280) < 1, "floating size survives mode switch")
            var candidate = model.preferences
            candidate.backgroundTransparency = 45
            try commit(candidate)
            let (saved, warning) = model.store.load()
            try require(warning == nil && saved.floatingMode && saved.backgroundTransparency == 45, "mode and transparency persist")
            try require(saved.mainFrame == before.mainFrame && saved.floatingFrame?.width == 280, "independent geometry persists")
            showSettings()
            pump()
            try require(settingsWindow?.isVisible == true, "settings open from floating mode")
            settingsWindow?.close()
            try require(model.previewTransparency == nil, "closing settings cancels preview")
            var live = model.preferences
            live.startMinutes = 0
            live.endMinutes = 1439
            live.monthlyIncome = 100_000
            try commit(live)
            let first = model.snapshot.earned
            RunLoop.main.run(until: Date().addingTimeInterval(2.2))
            try require(model.snapshot.earned > first, "real timer updates earnings")
            try "PASS macOS application verification\n".write(to: directory.appendingPathComponent("verification.txt"), atomically: true, encoding: .utf8)
            NSApp.terminate(nil)
        } catch {
            fputs("FAIL UI verification: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }
}
