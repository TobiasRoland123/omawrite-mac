#!/bin/bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_dir"

configuration="release"
install_app=false

for arg in "$@"; do
    case "$arg" in
        debug|release)
            configuration="$arg"
            ;;
        --install|-i)
            install_app=true
            ;;
        *)
            echo "Usage: ./scripts/build.sh [debug|release] [--install]" >&2
            exit 1
            ;;
    esac
done

swift build -c "$configuration"
binary_dir="$(swift build -c "$configuration" --show-bin-path)"
app_dir="$project_dir/build/Omawrite.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
rm -f "$app_dir/Contents/Resources/AppIcon.png"
cp "$binary_dir/Omawrite" "$app_dir/Contents/MacOS/Omawrite"
cp Support/Info.plist "$app_dir/Contents/Info.plist"
ditto "$binary_dir/Omawrite_Omawrite.bundle" "$app_dir/Contents/Resources/Omawrite_Omawrite.bundle"
cp LICENSE "$app_dir/Contents/Resources/LICENSE"

icon_variant="${OMAWRITE_APP_ICON:-stone}"
icon_source="$project_dir/Sources/Omawrite/Resources/AppIcons/$icon_variant.png"
icon_build_dir="$project_dir/build/AppIcons/$icon_variant"
iconset="$icon_build_dir/AppIcon.iconset"
icon_file="$icon_build_dir/AppIcon.icns"
if [[ ! -f "$icon_source" ]]; then
    echo "Unknown app icon '$icon_variant'. Expected $icon_source" >&2
    exit 1
fi
if [[ ! -f "$icon_file" || scripts/make-icon.swift -nt "$icon_file" || "$icon_source" -nt "$icon_file" ]]; then
    mkdir -p "$icon_build_dir"
    swift scripts/make-icon.swift "$icon_source" "$iconset"
    iconutil -c icns "$iconset" -o "$icon_file"
fi
cp "$icon_file" "$app_dir/Contents/Resources/AppIcon.icns"
codesign --force --deep --sign - "$app_dir"
echo "Built $app_dir"

# Automatically update /Applications or ~/Applications if Omawrite was installed or --install was specified
if [[ "$install_app" == true || "${INSTALL:-0}" == "1" || -d "/Applications/Omawrite.app" ]]; then
    target_dir="/Applications"
    if [[ ! -w "$target_dir" ]]; then
        target_dir="$HOME/Applications"
        mkdir -p "$target_dir"
    fi
    ditto "$app_dir" "$target_dir/Omawrite.app"
    echo "Installed to $target_dir/Omawrite.app"
fi

echo "Launch with: open \"$app_dir\""
