#!/bin/bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$project_dir/scripts/build.sh" "$@" --install

cli_dir=""
for candidate in "$HOME/.local/bin" /opt/homebrew/bin /usr/local/bin; do
    case ":$PATH:" in
        *":$candidate:"*)
            mkdir -p "$candidate" 2>/dev/null || continue
            if [[ -w "$candidate" ]]; then
                cli_dir="$candidate"
                break
            fi
            ;;
    esac
done

if [[ -z "$cli_dir" ]]; then
    cli_dir="$HOME/.local/bin"
    mkdir -p "$cli_dir"
fi

install -m 755 "$project_dir/scripts/omawrite" "$cli_dir/omawrite"
echo "Installed command line tool to $cli_dir/omawrite"

case ":$PATH:" in
    *":$cli_dir:"*) ;;
    *) echo "Add $cli_dir to your PATH to use the omawrite command." ;;
esac
