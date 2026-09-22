# Omawrite for Mac

A native macOS Markdown writing app, built in **Swift and SwiftUI**. Inspired by [omacom/omawrite](https://github.com/omacom/omawrite), with the original iA Writer Mono font and a quiet, centered writing surface.

## Build and install

Requires macOS 14 or later and a Swift 6 toolchain. Xcode Command Line Tools are sufficient; the full Xcode app is optional. There are no third-party package dependencies.

```sh
# Build locally
./scripts/build.sh
open build/Omawrite.app

# Install to /Applications (appears in Tinycast, Spotlight, and Launchpad)
./scripts/install.sh
```

The install script also adds an `omawrite` command to the first writable standard directory on your `PATH`. Use it to open a document from the terminal, with paths resolved relative to your current directory:

```sh
omawrite ../../notes/opencodex-chatgpt-mac-setup.md
```

The build script creates a locally signed `.app` for your Mac’s architecture, with its fonts and icon bundled. If `Omawrite.app` already exists in `/Applications`, running `./scripts/build.sh` will automatically keep `/Applications/Omawrite.app` updated.

App-icon source images live in `Sources/Omawrite/Resources/AppIcons`. The build uses `stone.png` by default; additional named PNGs can be selected with `OMAWRITE_APP_ICON=name ./scripts/build.sh` and exposed in Settings through `AppIconChoice`.

For a faster development build, use `./scripts/build.sh debug`. Open `Package.swift` in Xcode to browse and edit the project, if Xcode is installed. Launch the packaged app when testing Finder integration and document restoration.

## Writing

- Plain Markdown files, with multiple document windows and native Open, Save, Save As, and recent-file menus.
- Live styling for headings, emphasis, links, lists, quotes, and code. Inline markers stay visible in the current paragraph and recede elsewhere. “Show Markdown Syntax” makes all markers visible.
- Native selection, undo/redo, spellchecking, find/replace, and international text input through an AppKit text view hosted in SwiftUI.
- Bold, italic, link, and code shortcuts; list continuation; paste a URL over a selection to make a link.
- Word count, character count, reading time, and paragraph focus mode.
- System, light, and dark appearance, plus adjustable text size.
- macOS document autosave, draft restoration, versioning, and conflict protection. Native conflict dialogs offer Save Anyway, Revert, and Save As when another app has changed a file.
- Formatted printing and Save as PDF through the macOS print dialog.
- UTF-8 and UTF-16 with a byte-order mark; the original encoding and line-ending convention are retained when saving. Unsupported/binary files are rejected instead of decoded with replacement characters.

Use **Help → Welcome to Omawrite** for a sample document, or **Help → Keyboard Shortcuts** for the reference. A fresh document starts blank; placeholder text is never saved into it.

| Action | Shortcut |
| --- | --- |
| New / open | ⌘N / ⌘O |
| Save / save as | ⌘S / ⇧⌘S |
| Find / replace | ⌘F / ⌥⌘F |
| Next / previous match | ⌘G / ⇧⌘G |
| Bold / italic / link | ⌘B / ⌘I / ⌘K |
| Inline code | ⇧⌘K |
| Focus mode | ⇧⌘D |
| Show Markdown syntax | ⇧⌘M |
| Text size | ⌘+ / ⌘− / ⌘0 |
| Print / settings | ⌘P / ⌘, |

## Tests

```sh
./scripts/test.sh
```

Swift Testing covers Unicode-safe editing, Markdown formatting, list edge cases, link escaping, encoding and newline round trips, source-preserving styling, and formatted print output.

The test script also handles macro-plugin discovery in Command Line Tools releases where `swift test` does not find the bundled Swift Testing plugin automatically.

## Structure

- `Sources/Omawrite`: SwiftUI scenes, document integration, editor, appearance, and printing.
- `Sources/OmawriteCore`: UI-independent editing operations and text-file encoding.
- `Tests`: core and AppKit integration tests.
- `Support/Info.plist`: app identity and Markdown/plain-text file associations.
- `scripts/build.sh`: builds and packages the app without an Xcode project.
- `scripts/install.sh`: builds and installs the app to `/Applications`.

The editor is deliberately a Markdown source editor with visual styling, rather than a full WYSIWYG renderer. Images, HTML blocks, and complex tables remain editable source; they are not embedded previews. The printer formats text, headings, emphasis, links, lists, quotes, and code; it does not download images.

## Credits

This is an independent Mac implementation of Omawrite, based on the behavior of upstream commit `8f98892b26768236b2c20f4e637cf4b102d898bf`. It preserves the original’s focused layout, Markdown shortcuts, and typeface while using Apple’s native document and text systems.

The original project’s MIT license is retained in `LICENSE`. iA Writer Mono is bundled under the SIL Open Font License 1.1; see `Sources/Omawrite/Resources/Fonts/OFL.txt`.
