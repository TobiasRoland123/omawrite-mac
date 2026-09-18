import SwiftUI
import AppKit

struct QuickOpenView: View {
    @ObservedObject var viewModel: QuickOpenViewModel
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isSearchFocused: Bool

    private var theme: PaperTheme {
        PaperTheme(dark: colorScheme == .dark)
    }

    init(viewModel: QuickOpenViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header: Search Bar & Actions
            headerView

            Divider().opacity(0.15)

            // Content Area: Files list or Directories manager
            if viewModel.mode == .manageDirectories {
                manageDirectoriesView
            } else if viewModel.directoriesStore.directories.isEmpty {
                emptyDirectoriesView
            } else {
                filesListView
            }

            Divider().opacity(0.15)

            // Footer: Keyboard Shortcuts
            footerView
        }
        .frame(width: 620, height: 420)
        .background(Color(nsColor: theme.background))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(nsColor: theme.marker).opacity(0.25), lineWidth: 1)
        )
        .onAppear {
            isSearchFocused = true
            viewModel.directoriesStore.rescan()
        }
    }

    // MARK: - Header
    private var headerView: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color(nsColor: theme.muted))

            TextField("Search files in linked folders (or type to create)…", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .font(Font(WriterFonts.font(size: 15)))
                .focused($isSearchFocused)
                .foregroundStyle(Color(nsColor: theme.foreground))

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color(nsColor: theme.muted))
                }
                .buttonStyle(.plain)
            }

            if !viewModel.directoriesStore.directories.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        viewModel.mode = (viewModel.mode == .files) ? .manageDirectories : .files
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.mode == .manageDirectories ? "doc.text.magnifyingglass" : "folder")
                        Text(viewModel.mode == .manageDirectories ? "Back to Search" : "\(viewModel.directoriesStore.directories.count) Folders")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(nsColor: theme.codeBackground))
                    .clipShape(Capsule())
                    .foregroundStyle(Color(nsColor: theme.muted))
                }
                .buttonStyle(.plain)
                .help("Toggle Folder Management")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Files List
    private var filesListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    let files = viewModel.filteredFiles

                    if files.isEmpty && viewModel.canCreateNewFile {
                        // Option to create file
                        createFileRow
                    } else if files.isEmpty {
                        VStack(spacing: 8) {
                            Spacer(minLength: 40)
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 30))
                                .foregroundStyle(Color(nsColor: theme.muted))
                            Text("No files matching \"\(viewModel.searchText)\"")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color(nsColor: theme.muted))
                            Spacer(minLength: 40)
                        }
                    } else {
                        ForEach(Array(files.enumerated()), id: \.element.id) { index, file in
                            fileRow(file: file, isSelected: index == viewModel.selectedIndex)
                                .id(file.id)
                                .onTapGesture {
                                    viewModel.open(file: file)
                                }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .onChange(of: viewModel.selectedIndex) { _, newIndex in
                let files = viewModel.filteredFiles
                if newIndex >= 0 && newIndex < files.count {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        proxy.scrollTo(files[newIndex].id, anchor: .center)
                    }
                }
            }
        }
    }

    private func fileRow(file: IndexedFile, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.text")
                .font(.system(size: 13))
                .foregroundStyle(Color(nsColor: isSelected ? theme.accent : theme.muted))
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(Font(WriterFonts.font(size: 13.5, bold: isSelected)))
                    .foregroundStyle(Color(nsColor: theme.foreground))
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(file.directoryName)
                        .fontWeight(.semibold)
                    if file.relativePath != file.name {
                        Text("›")
                        Text(file.relativePath)
                    }
                }
                .font(.system(size: 10.5))
                .foregroundStyle(Color(nsColor: theme.muted))
                .lineLimit(1)
            }

            Spacer()

            Text(file.relativeModifiedString)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color(nsColor: theme.muted))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color(nsColor: theme.selection) : Color.clear)
        )
        .overlay(
            isSelected ?
                HStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(nsColor: theme.accent))
                        .frame(width: 3)
                        .padding(.vertical, 4)
                    Spacer()
                } : nil
        )
        .contentShape(Rectangle())
    }

    private var createFileRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color(nsColor: theme.accent))
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("Create")
                        .foregroundStyle(Color(nsColor: theme.foreground))
                    Text("\"\(viewModel.newFileNamePreview)\"")
                        .fontWeight(.semibold)
                        .foregroundStyle(Color(nsColor: theme.accent))
                }
                .font(Font(WriterFonts.font(size: 13.5)))

                Text("in \(viewModel.primaryDirectory?.displayName ?? "linked folder")")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color(nsColor: theme.muted))
            }

            Spacer()

            Text("⏎ to create")
                .font(.system(size: 11, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(nsColor: theme.codeBackground))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .foregroundStyle(Color(nsColor: theme.muted))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: theme.selection))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.createNewFile()
        }
    }

    // MARK: - Empty State (No Linked Folders)
    private var emptyDirectoriesView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "folder.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(Color(nsColor: theme.muted))

            VStack(spacing: 6) {
                Text("No Linked Folders")
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundStyle(Color(nsColor: theme.foreground))

                Text("Link the folders where you keep your notes or Markdown files\nto search and open them at lightning speed using the keyboard.")
                    .font(.system(size: 12))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(nsColor: theme.muted))
                    .lineSpacing(3)
            }

            HStack(spacing: 12) {
                Button {
                    viewModel.promptAddDirectory()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "folder.badge.plus")
                        Text("Link Folder… (⌘D)")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color(nsColor: theme.accent))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.openWithSystemPicker()
                } label: {
                    Text("Browse with System Picker (⇧⌘O)")
                        .font(.system(size: 12))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color(nsColor: theme.codeBackground))
                        .foregroundStyle(Color(nsColor: theme.foreground))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(24)
    }

    // MARK: - Manage Directories View
    private var manageDirectoriesView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Linked Directories")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(nsColor: theme.foreground))

                Spacer()

                Button {
                    viewModel.promptAddDirectory()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Add Folder… (⌘D)")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(nsColor: theme.accent))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            ScrollView {
                VStack(spacing: 6) {
                    ForEach(viewModel.directoriesStore.directories) { dir in
                        HStack(spacing: 10) {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(Color(nsColor: theme.accent))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(dir.displayName)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color(nsColor: theme.foreground))

                                Text(dir.path)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(Color(nsColor: theme.muted))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }

                            Spacer()

                            Text("\(dir.cachedFileCount) files")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(Color(nsColor: theme.muted))

                            Button {
                                viewModel.removeDirectory(dir)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color(nsColor: theme.muted))
                            }
                            .buttonStyle(.plain)
                            .help("Remove linked directory")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(nsColor: theme.codeBackground).opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Footer
    private var footerView: some View {
        HStack(spacing: 14) {
            shortcutKeyHint("↑↓", label: "Navigate")
            shortcutKeyHint("⏎", label: "Open")
            shortcutKeyHint("⌘D", label: "Link Folder")
            if viewModel.canCreateNewFile {
                shortcutKeyHint("⌘N", label: "New File")
            }
            shortcutKeyHint("esc", label: "Dismiss")

            Spacer()

            Button {
                viewModel.openWithSystemPicker()
            } label: {
                Text("System Picker (⇧⌘O)")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color(nsColor: theme.muted))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(nsColor: theme.codeBackground).opacity(0.3))
    }

    private func shortcutKeyHint(_ key: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .padding(.horizontal, 4)
                .padding(.vertical, 1.5)
                .background(Color(nsColor: theme.marker).opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 3))

            Text(label)
                .font(.system(size: 10.5))
                .foregroundStyle(Color(nsColor: theme.muted))
        }
    }
}
