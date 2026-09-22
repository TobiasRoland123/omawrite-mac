import Testing
@testable import Omawrite

struct KeyboardShortcutTests {
    @Test func shortcutConfigurationHasUniqueIdentifiers() {
        let shortcuts = KeyboardShortcutConfig.sections.flatMap(\.shortcuts)
        #expect(Set(shortcuts.map(\.id)).count == shortcuts.count)
    }

    @Test func shortcutLabelsUseMacModifierOrder() {
        #expect(KeyboardShortcutConfig.findAndReplace.keyLabels == ["⌥", "⌘", "F"])
        #expect(KeyboardShortcutConfig.fullScreen.keyLabels == ["⌃", "⌘", "F"])
        #expect(KeyboardShortcutConfig.systemOpen.keyLabels == ["⇧", "⌘", "O"])
        #expect(KeyboardShortcutConfig.shortcutOverview.keyLabels == ["⌥", "⌘", "K"])
    }
}
