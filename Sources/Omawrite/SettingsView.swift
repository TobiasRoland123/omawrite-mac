import SwiftUI
import AppKit

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }

            ShortcutsView()
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
        }
        .frame(width: 520, height: 620)
    }
}

private struct GeneralSettingsView: View {
    @AppStorage("appearance") private var appearance = AppearanceChoice.system.rawValue
    @AppStorage("fontSize") private var fontSize = 20.0
    @AppStorage("showSyntax") private var showSyntax = false
    @AppStorage("spellcheck") private var spellcheck = true
    @AppStorage(AppIconChoice.preferenceKey) private var appIcon = AppIconChoice.stone.rawValue
    @ObservedObject private var directoriesStore = LinkedDirectoriesStore.shared

    var body: some View {
        Form {
            Section("Writing") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Text size")
                        Spacer()
                        Text("\(Int(fontSize)) pt").foregroundStyle(.secondary).monospacedDigit()
                    }
                    Slider(value: $fontSize, in: 14...32, step: 1)
                        .accessibilityLabel("Editor text size")
                    Text("A little space to think.")
                        .font(Font(WriterFonts.font(size: fontSize)))
                        .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
                }
                Toggle("Check spelling as you type", isOn: $spellcheck)
                Toggle("Always show Markdown syntax", isOn: $showSyntax)
                Text("Otherwise, inline markers appear in the paragraph you’re editing and fade away elsewhere.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Linked Folders") {
                VStack(alignment: .leading, spacing: 10) {
                    if directoriesStore.directories.isEmpty {
                        Text("No folders linked yet. Link folders where you keep Markdown files to search and open them instantly with ⌘O.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        ForEach(directoriesStore.directories) { dir in
                            HStack {
                                Image(systemName: "folder.fill")
                                    .foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(dir.displayName).fontWeight(.medium)
                                    Text(dir.path)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                Spacer()
                                Text("\(dir.cachedFileCount) files")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.secondary)

                                Button {
                                    directoriesStore.removeDirectory(id: dir.id)
                                } label: {
                                    Image(systemName: "minus.circle")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                                .help("Remove linked folder")
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    HStack {
                        Button("Add Folder…") {
                            let panel = NSOpenPanel()
                            panel.canChooseFiles = false
                            panel.canChooseDirectories = true
                            panel.allowsMultipleSelection = true
                            panel.canCreateDirectories = true
                            panel.prompt = "Link Folder"
                            panel.message = "Choose folders where you keep your Markdown files and notes."
                            panel.begin { response in
                                guard response == .OK else { return }
                                for url in panel.urls {
                                    directoriesStore.addDirectory(url: url)
                                }
                            }
                        }

                        Spacer()

                        if !directoriesStore.directories.isEmpty {
                            Button("Rescan") {
                                directoriesStore.rescan()
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }

            Section("Appearance") {
                Picker("Theme", selection: $appearance) {
                    ForEach(AppearanceChoice.allCases) { choice in Text(choice.title).tag(choice.rawValue) }
                }
                .pickerStyle(.segmented)
            }

            Section("App Icon") {
                Picker("App icon", selection: $appIcon) {
                    ForEach(AppIconChoice.allCases) { choice in
                        HStack(spacing: 10) {
                            if let image = choice.image {
                                Image(nsImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 34, height: 34)
                            }
                            Text(choice.title)
                        }
                        .tag(choice.rawValue)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
                .onChange(of: appIcon) { _, value in
                    AppIconChoice(rawValue: value)?.apply()
                }
            }

            Section {
                HStack {
                    Text("Omawrite for Mac").fontWeight(.medium)
                    Spacer()
                    Text("1.0").foregroundStyle(.secondary)
                }
                Text("A quiet place for your words. Inspired by the original Omawrite.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
