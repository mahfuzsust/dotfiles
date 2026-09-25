#!/usr/bin/env zsh
set -e

FIRA_CODE_NERD_ZIP_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/FiraCode.zip"
FONT_DIR="$HOME/Library/Fonts"
MARKER_FONT="$FONT_DIR/FiraCodeNerdFontMono-Regular.ttf"

if [[ -f "$MARKER_FONT" ]]; then
    echo "fonts: Fira Code Nerd Font Mono already installed"
    exit 0
fi

if ! command -v unzip >/dev/null 2>&1; then
    echo "fonts: unzip not found; install unzip or re-run after brew bundle" >&2
    exit 1
fi

tmpdir="$(mktemp -d)"
cleanup() {
    rm -rf "$tmpdir"
}
trap cleanup EXIT

echo "fonts: downloading Fira Code Nerd Font Mono (v3.5.1)..."
curl -fsSL "$FIRA_CODE_NERD_ZIP_URL" -o "$tmpdir/FiraCode.zip"
unzip -q "$tmpdir/FiraCode.zip" 'FiraCodeNerdFontMono-*.ttf' -d "$tmpdir"

mono_fonts=("$tmpdir"/FiraCodeNerdFontMono-*.ttf(N))
if (( ${#mono_fonts[@]} == 0 )); then
    echo "fonts: no FiraCodeNerdFontMono fonts in archive" >&2
    exit 1
fi

mkdir -p "$FONT_DIR"
for font in "${mono_fonts[@]}"; do
    install -m 644 "$font" "$FONT_DIR/${font:t}"
done

echo "fonts: installed Fira Code Nerd Font Mono to $FONT_DIR"
