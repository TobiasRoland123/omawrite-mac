import AppKit
import SwiftUI

final class QuickOpenPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class QuickOpenManager: NSObject, NSWindowDelegate {
    static let shared = QuickOpenManager()

    private(set) var panel: QuickOpenPanel?
    private var viewModel: QuickOpenViewModel?
    private var localKeyMonitor: Any?

    private override init() {
        super.init()
    }

    func show() {
        if panel == nil {
            setupPanel()
        }

        guard let panel, let viewModel else { return }

        // Reset state
        viewModel.mode = .files
        viewModel.searchText = ""
        viewModel.selectedIndex = 0
        viewModel.directoriesStore.rescan()

        // Position window: center over the key window or screen
        if let keyWindow = NSApp.keyWindow, keyWindow !== panel {
            let keyFrame = keyWindow.frame
            let panelSize = panel.frame.size
            let x = keyFrame.midX - (panelSize.width / 2)
            let y = keyFrame.midY - (panelSize.height / 2) + 40
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            panel.center()
        }

        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        startKeyMonitoring()
    }

    func hide() {
        stopKeyMonitoring()
        panel?.orderOut(nil)
    }

    func toggle() {
        if panel?.isVisible == true {
            hide()
        } else {
            show()
        }
    }

    private func setupPanel() {
        let vm = QuickOpenViewModel()
        vm.onDismiss = { [weak self] in
            self?.hide()
        }
        self.viewModel = vm

        let panel = QuickOpenPanel(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 420),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.hasShadow = true
        panel.backgroundColor = .clear
        panel.delegate = self

        let hostingView = NSHostingView(rootView: QuickOpenView(viewModel: vm))
        panel.contentView = hostingView

        self.panel = panel
    }

    private func startKeyMonitoring() {
        stopKeyMonitoring()

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let panel = self.panel, panel.isKeyWindow, let vm = self.viewModel else {
                return event
            }

            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            // Escape
            if event.keyCode == 53 {
                self.hide()
                return nil
            }

            // Down Arrow
            if event.keyCode == 125 {
                vm.selectNext()
                return nil
            }

            // Up Arrow
            if event.keyCode == 126 {
                vm.selectPrevious()
                return nil
            }

            // Return / Enter
            if event.keyCode == 36 || event.keyCode == 76 {
                vm.openSelected()
                return nil
            }

            // Control + N / Control + P (standard readline)
            if flags == .control {
                if event.charactersIgnoringModifiers == "n" {
                    vm.selectNext()
                    return nil
                } else if event.charactersIgnoringModifiers == "p" {
                    vm.selectPrevious()
                    return nil
                }
            }

            // Command shortcuts
            if flags == .command {
                if event.charactersIgnoringModifiers == "d" {
                    vm.promptAddDirectory()
                    return nil
                } else if event.charactersIgnoringModifiers == "n" && vm.canCreateNewFile {
                    vm.createNewFile()
                    return nil
                } else if event.charactersIgnoringModifiers == "l" {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        vm.mode = (vm.mode == .files) ? .manageDirectories : .files
                    }
                    return nil
                }
            }

            // Command + Shift + O (system picker)
            if flags == [.command, .shift] && event.charactersIgnoringModifiers?.lowercased() == "o" {
                vm.openWithSystemPicker()
                return nil
            }

            return event
        }
    }

    private func stopKeyMonitoring() {
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
    }

    // MARK: - NSWindowDelegate
    func windowDidResignKey(_ notification: Notification) {
        // If an open panel or sheet is presented, don't immediately hide
        guard let panel, panel.attachedSheet == nil, viewModel?.isPresentingSystemPicker != true else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self, let panel = self.panel else { return }
            if !panel.isKeyWindow && NSApp.modalWindow == nil && self.viewModel?.isPresentingSystemPicker != true {
                self.hide()
            }
        }
    }
}
