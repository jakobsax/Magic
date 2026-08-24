#!/bin/bash
# Reverts everything install.sh changed and removes Magic's installed
# files. Safe to run directly. This is the repo copy — it does not
# delete itself, only the files install.sh put outside this directory.
set -euo pipefail

echo "[Uninstall] Reverting system power/network state and removing the privileged helper..."
if [ -x /usr/local/libexec/magic-helper ]; then
    sudo -n /usr/local/libexec/magic-helper uninstall 2>/dev/null \
        || sudo /usr/local/libexec/magic-helper uninstall
else
    echo "  (helper already gone — reverting manually; edit these to match your hardware" \
         "if you changed them from the defaults)"
    sudo systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target
    sudo nmcli connection modify "Wired connection 1" 802-3-ethernet.wake-on-lan default
    sudo nmcli device reapply eno1 2>/dev/null || sudo nmcli connection up "Wired connection 1" || true
fi

echo "[Uninstall] Removing the passwordless sudo rule..."
sudo rm -f /etc/sudoers.d/magic

echo "[Uninstall] Clearing saved Sunshine credentials from the keyring (if any)..."
python3 - <<'PYEOF' 2>/dev/null || true
import gi
gi.require_version("Secret", "1")
from gi.repository import Secret
schema = Secret.Schema.new(
    "com.jakobsax.Magic.Sunshine", Secret.SchemaFlags.NONE,
    {"service": Secret.SchemaAttributeType.STRING},
)
Secret.password_clear_sync(schema, {"service": "sunshine-webui"}, None)
PYEOF

echo "[Uninstall] Deleting installed application files..."
rm -f ~/.local/share/applications/magic.desktop
rm -f ~/Desktop/magic.desktop
rm -f ~/.local/share/icons/hicolor/scalable/apps/magic.svg
rm -rf ~/.config/magic
rm -f ~/.local/bin/magic

echo "Uninstallation complete."
