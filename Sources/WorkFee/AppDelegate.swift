import AppKit
import SwiftUI
import WorkFeeCore

final class WorkWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class MoneyPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class FloatingHost: NSHostingView<FloatingView> {
    var restoreMain: (() -> Void)?

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(convert(point, from: superview)) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 { restoreMain?() }
        else { window?.performDrag(with: event) }
    }

    override func rightMouseDown(with event: NSEvent) {
        if let menu = menu { NSMenu.popUpContextMenu(menu, with: event, for: self) }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var model: AppModel!
    var mainWindow: WorkWindow!
    var floatingWindow: MoneyPanel!
    var settingsWindow: NSWindow?
    private var pendingSave: DispatchWorkItem?
    private var restoringFrames = true
    let verifying = ProcessInfo.processInfo.arguments.contains("--verify-ui")

    func applicationDidFinishLaunching(_ notification: Notification) {
        let directory: URL
        if verifying {
            directory = FileManager.default.temporaryDirectory.appendingPathComponent("WorkFee-verify-\(UUID().uuidString)")
        } else {
            directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("WorkFee", isDirectory: true)
        }
        let store = SettingsStore(directory: directory)
        let (settings, warning) = store.load()
        model = AppModel(settings: settings, store: store)
        installMenu()
        buildWindows()
        restoringFrames = false
        displayCurrentMode()
        model.startClock()
        if let warning = warning { showError(warning) }
        if verifying {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.verifyInterface() }
        }
    }

    private func buildWindows() {
        mainWindow = WorkWindow(contentRect: NSRect(x: 0, y: 0, width: 576, height: 488),
                                styleMask: [.borderless, .resizable, .miniaturizable], backing: .buffered, defer: false)
        mainWindow.title = "下班倒计时"
        mainWindow.contentMinSize = NSSize(width: 320, height: 272)
        mainWindow.isOpaque = false
        mainWindow.backgroundColor = .clear
        mainWindow.hasShadow = true
        mainWindow.isMovableByWindowBackground = true
        mainWindow.isReleasedWhenClosed = false
        mainWindow.delegate = self
        let actions = MainActions(
            floating: { [weak self] in self?.showFloating() },
            pin: { [weak self] in self?.togglePin() },
            settings: { [weak self] in self?.showSettings() },
            minimize: { [weak self] in self?.mainWindow.miniaturize(nil) },
            close: { NSApp.terminate(nil) }
        )
        mainWindow.contentView = NSHostingView(rootView: MainView(model: model, actions: actions))

        floatingWindow = MoneyPanel(contentRect: NSRect(x: 0, y: 0, width: 300, height: 100),
                                    styleMask: [.borderless, .resizable, .nonactivatingPanel], backing: .buffered, defer: false)
        floatingWindow.title = "今日已赚"
        floatingWindow.contentMinSize = NSSize(width: 160, height: 64)
        floatingWindow.isOpaque = false
        floatingWindow.backgroundColor = .clear
        floatingWindow.hasShadow = true
        floatingWindow.level = .floating
        floatingWindow.isFloatingPanel = true
        floatingWindow.hidesOnDeactivate = false
        floatingWindow.isReleasedWhenClosed = false
        floatingWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        floatingWindow.delegate = self
        let floatingHost = FloatingHost(rootView: FloatingView(model: model))
        floatingHost.restoreMain = { [weak self] in self?.showMain() }
        let menu = NSMenu()
        menu.addItem(menuItem("返回主窗口", action: #selector(showMain)))
        menu.addItem(menuItem("设置…", action: #selector(showSettings)))
        menu.addItem(.separator())
        menu.addItem(menuItem("退出", action: #selector(quit)))
        floatingHost.menu = menu
        floatingWindow.contentView = floatingHost

        restore(mainWindow, from: model.preferences.mainFrame)
        restore(floatingWindow, from: model.preferences.floatingFrame)
    }

    private func restore(_ window: NSWindow, from saved: SavedFrame?) {
        guard let saved = saved, saved.isFinite else { window.center(); return }
        let proposed = NSRect(x: saved.x, y: saved.y, width: saved.width, height: saved.height)
        guard let screen = NSScreen.screens.first(where: { $0.visibleFrame.intersects(proposed) }) ?? NSScreen.main else {
            window.center()
            return
        }
        let available = screen.visibleFrame
        let width = min(max(saved.width, window.contentMinSize.width), available.width)
        let height = min(max(saved.height, window.contentMinSize.height), available.height)
        let x = min(max(saved.x, available.minX), available.maxX - width)
        let y = min(max(saved.y, available.minY), available.maxY - height)
        window.setFrame(NSRect(x: x, y: y, width: width, height: height), display: false)
    }

    private func menuItem(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    private func installMenu() {
        let bar = NSMenu()
        let appItem = NSMenuItem()
        let menu = NSMenu(title: "下班倒计时")
        menu.addItem(menuItem("显示主窗口", action: #selector(showMain), key: "1"))
        menu.addItem(menuItem("金额悬浮窗", action: #selector(showFloating), key: "2"))
        menu.addItem(menuItem("设置…", action: #selector(showSettings), key: ","))
        menu.addItem(.separator())
        menu.addItem(menuItem("退出下班倒计时", action: #selector(quit), key: "q"))
        appItem.submenu = menu
        bar.addItem(appItem)
        NSApp.mainMenu = bar
    }

    func recordFrames(in settings: inout Preferences) {
        func saved(_ window: NSWindow) -> SavedFrame {
            let frame = window.frame
            return SavedFrame(x: frame.origin.x, y: frame.origin.y, width: frame.width, height: frame.height)
        }
        settings.mainFrame = saved(mainWindow)
        settings.floatingFrame = saved(floatingWindow)
    }

    func commit(_ settings: Preferences) throws {
        pendingSave?.cancel()
        var candidate = settings
        recordFrames(in: &candidate)
        try model.store.save(candidate)
        model.preferences = candidate
        model.previewTransparency = nil
        model.refresh()
        mainWindow.level = candidate.alwaysOnTop ? .floating : .normal
    }

    private func changeMode(floating: Bool) {
        var candidate = model.preferences
        candidate.floatingMode = floating
        do {
            try commit(candidate)
            displayCurrentMode()
        } catch { showError("设置保存失败。\n\(error.localizedDescription)") }
    }

    func displayCurrentMode() {
        mainWindow.level = model.preferences.alwaysOnTop ? .floating : .normal
        if model.preferences.floatingMode {
            mainWindow.orderOut(nil)
            floatingWindow.orderFrontRegardless()
        } else {
            floatingWindow.orderOut(nil)
            mainWindow.deminiaturize(nil)
            mainWindow.makeKeyAndOrderFront(nil)
            if !verifying { NSApp.activate(ignoringOtherApps: true) }
        }
    }

    @objc func showMain() { changeMode(floating: false) }
    @objc func showFloating() { changeMode(floating: true) }
    @objc func quit() { NSApp.terminate(nil) }

    @objc func togglePin() {
        var candidate = model.preferences
        candidate.alwaysOnTop.toggle()
        do { try commit(candidate) }
        catch { showError("置顶设置保存失败。\n\(error.localizedDescription)") }
    }

    @objc func showSettings() {
        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            return
        }
        model.previewTransparency = nil
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 510),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "设置"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.backgroundColor = NSColor(red: 1, green: 0.988, blue: 0.973, alpha: 1)
        window.level = model.preferences.floatingMode || model.preferences.alwaysOnTop ? .floating : .normal
        let view = SettingsView(model: model, save: { [weak self, weak window] candidate in
            guard let self = self else { return "应用正在关闭。" }
            do {
                try self.commit(candidate)
                window?.close()
                return nil
            } catch { return "保存失败。\(error.localizedDescription)" }
        }, cancel: { [weak window] in window?.close() })
        let host = NSHostingView(rootView: view)
        window.contentView = host
        window.setContentSize(host.fittingSize)
        window.center()
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowDidResize(_ notification: Notification) { windowGeometryChanged(notification) }
    func windowDidMove(_ notification: Notification) { windowGeometryChanged(notification) }

    private func windowGeometryChanged(_ notification: Notification) {
        guard !restoringFrames, let window = notification.object as? NSWindow,
              window === mainWindow || window === floatingWindow else { return }
        var candidate = model.preferences
        recordFrames(in: &candidate)
        model.preferences = candidate
        pendingSave?.cancel()
        let task = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            do { try self.model.store.save(self.model.preferences) }
            catch { self.showError("窗口位置保存失败。\n\(error.localizedDescription)") }
        }
        pendingSave = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: task)
    }

    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window === settingsWindow {
            model.previewTransparency = nil
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender === settingsWindow { return true }
        NSApp.terminate(nil)
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMain()
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        pendingSave?.cancel()
        if verifying { model.stopClock(); return .terminateNow }
        do {
            var candidate = model.preferences
            recordFrames(in: &candidate)
            try model.store.save(candidate)
            model.stopClock()
            return .terminateNow
        } catch {
            let alert = NSAlert()
            alert.messageText = "设置保存失败"
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: "仍然退出")
            alert.addButton(withTitle: "返回")
            return alert.runModal() == .alertFirstButtonReturn ? .terminateNow : .terminateCancel
        }
    }

    func showError(_ message: String) {
        if verifying { fputs("WorkFee error: \(message)\n", stderr); return }
        let alert = NSAlert()
        alert.messageText = "下班倒计时"
        alert.informativeText = message
        alert.runModal()
    }
}

@main
enum WorkFeeEntry {
    @MainActor static func main() {
        let application = NSApplication.shared
        application.setActivationPolicy(.regular)
        let delegate = AppDelegate()
        application.delegate = delegate
        withExtendedLifetime(delegate) { application.run() }
    }
}
