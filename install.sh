#!/bin/bash
# Installs Magic for the CURRENT user only. Does not need to be run as
# root itself — it uses sudo only for the two steps that genuinely need
# root (the privileged helper binary and the sudoers rule that lets you
# call it without a password). Safe to re-run; every step is idempotent.
#
# Before running this, edit the "EDIT THESE TWO LINES FOR YOUR HARDWARE"
# section in magic-helper (in this same directory) to match your wired
# network interface and NetworkManager connection name. See README.md.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
APPS_DIR="$HOME/.local/share/applications"
ICON_DIR="$HOME/.local/share/icons/hicolor/scalable/apps"
HELPER=/usr/local/libexec/magic-helper
SUDOERS_FILE=/etc/sudoers.d/magic

echo "== Checking dependencies =="
missing=()
python3 -c "import gi; gi.require_version('Gtk','4.0'); gi.require_version('Adw','1')" 2>/dev/null \
    || missing+=("gir1.2-gtk-4.0 / gir1.2-adw-1 (GTK4 + libadwaita GObject bindings)")
command -v nmcli >/dev/null || missing+=("network-manager")
command -v ethtool >/dev/null || missing+=("ethtool")
command -v systemctl >/dev/null || missing+=("systemd")
python3 -c "import gi; gi.require_version('Secret','1')" 2>/dev/null \
    || echo "  Note: gir1.2-secret-1 not found — Sunshine pairing/keyring features will be" \
            "disabled until you 'sudo apt install gir1.2-secret-1' (everything else works)."
if [ "${#missing[@]}" -gt 0 ]; then
    echo "Missing required packages:"
    printf '  - %s\n' "${missing[@]}"
    echo "Install them (Debian/Ubuntu-based) and re-run this script."
    exit 1
fi

echo "== Installing app files to $BIN_DIR, $APPS_DIR, $ICON_DIR =="
mkdir -p "$BIN_DIR" "$APPS_DIR" "$ICON_DIR"
install -m 0755 "$SCRIPT_DIR/magic" "$BIN_DIR/magic"
install -m 0644 "$SCRIPT_DIR/magic.svg" "$ICON_DIR/magic.svg"

cat > "$APPS_DIR/magic.desktop" <<EOF
[Desktop Entry]
Name=Magic
Comment=Toggle Away/Home power state for remote desktop access
Exec=$BIN_DIR/magic
Icon=magic
Terminal=false
Type=Application
StartupWMClass=com.jakobsax.Magic
Categories=Utility;
EOF

command -v gtk4-update-icon-cache >/dev/null && gtk4-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" >/dev/null 2>&1 || true
command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" >/dev/null 2>&1 || true

echo "== Installing the privileged helper (requires sudo) =="
sudo install -Dm755 "$SCRIPT_DIR/magic-helper" "$HELPER"

echo "== Installing a scoped passwordless sudo rule for that exact helper (requires sudo) =="
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
echo "$USER ALL=(root) NOPASSWD: $HELPER" > "$TMP"
if ! sudo visudo -c -f "$TMP" >/dev/null; then
    echo "Refusing to install: generated sudoers rule failed validation." >&2
    exit 1
fi
sudo install -m 0440 -o root -g root "$TMP" "$SUDOERS_FILE"

echo
echo "Done. Launch Magic from your application menu, or run: $BIN_DIR/magic"
echo "See README.md for what this installer changed and how to verify it."
