# Magic

A small GTK4/libadwaita desktop app that toggles a Linux desktop between two
power states — **Home** (normal sleep/lock) and **Away** (stays fully awake,
Wake-on-LAN armed) — for remote access via [Tailscale](https://tailscale.com/)
+ [Sunshine](https://github.com/LizardByte/Sunshine) +
[Moonlight](https://moonlight-stream.org/), without leaving the machine
permanently unable to sleep when you're actually home.

This was built for a specific machine's setup and is shared here as a
reference/starting point, not a polished general-purpose release. **Read
this whole file before installing** — it changes system sleep behavior and
grants your user a scoped passwordless `sudo` rule.

## What it does

- **Home Mode** (default): normal ACPI sleep/suspend and screen lock after
  idle timeouts you set, Wake-on-LAN off.
- **Away Mode**: sleep/suspend/hibernate/screen-lock all disabled so the box
  stays reachable over Tailscale continuously; Wake-on-LAN armed on your
  wired interface as a fallback if the machine ever loses power outright.
  Requires the Ethernet cable to be connected to turn on. If the cable is
  later unplugged while Away Mode is active *and the app is open*, it
  reverts to Home Mode automatically. Nothing runs in the background when
  the app is closed — it's not a daemon.
- Optional: pair new Moonlight clients directly from the app (device name +
  PIN) instead of opening Sunshine's web UI, using credentials stored in
  GNOME Keyring.

## Prerequisites

**OS**: A systemd + NetworkManager Linux distro running the
[COSMIC desktop](https://github.com/pop-os/cosmic-epoch) (Wayland). Built
and tested on PikaOS; should work unmodified on Pop!\_OS COSMIC or other
COSMIC-based distros with the same component names. Porting to a different
desktop environment would require replacing the idle/lock config path (see
"How idle timeouts work" below) with whatever that DE uses.

**Packages**:
- `python3`, `gir1.2-gtk-4.0`, `gir1.2-adw-1` (GTK4 + libadwaita — required)
- `gir1.2-secret-1` (GNOME Keyring bindings — optional, only needed for
  Sunshine pairing/credentials; everything else works without it)
- `network-manager`, `ethtool`, `systemd`, `sudo`

**Apps this tethers together** (all installed/configured separately, not by
this repo):
- [Tailscale](https://tailscale.com/) — the remote network. Install and log
  in before this is useful.
- [Sunshine](https://github.com/LizardByte/Sunshine) — the game-stream host.
  Install it, and visit its local web UI once (`https://localhost:47990`)
  to set an admin username/password before using Magic's pairing feature.
- [Moonlight](https://moonlight-stream.org/) — the client, on whatever
  device you're connecting *from*.
- A NIC that supports Wake-on-LAN over the wired interface, with WoL
  enabled in BIOS/UEFI (`Power On By PCI-E/PCIe` or similar) if you want
  the "wake from a full power-off" fallback to actually work — the OS-level
  flag Magic sets isn't sufficient on its own for that case, only for
  waking from suspend.

## Before you install: edit two lines for your hardware

`magic-helper` and `magic` both hardcode a network interface name and
NetworkManager connection name near the top (`IFACE` / `CONN`), defaulted
to `eno1` / `"Wired connection 1"` — whatever this was built against. Find
yours and edit both files to match:

```
ip -o link show | cut -d: -f2          # interface name
nmcli -t -f NAME,DEVICE connection show  # connection name
```

These two values must match exactly in both files.

## Install

```
git clone https://github.com/jakobsax/Magic.git
cd Magic
# edit magic-helper and magic as described above
./install.sh
```

`install.sh` does **not** run as root. It only shells out to `sudo` for the
two steps that need it, and tells you before each:

1. Copies `magic` → `~/.local/bin/magic`, the icon and a `.desktop` launcher
   into your user's `~/.local/share/...` — no root, no system-wide changes.
2. Installs `magic-helper` → `/usr/local/libexec/magic-helper` (root-owned,
   `0755`). This is the *only* file that runs as root, and it does exactly
   four fixed things: mask/unmask the four sleep-related systemd targets,
   and set `wake-on-lan` to `magic`/`default` on the one NIC connection you
   configured above. It takes no free-form input — only the literal
   arguments `away`, `home`, or `uninstall`.
3. Installs `/etc/sudoers.d/magic`, a single line granting your user
   passwordless `sudo` for *only* that exact helper path — validated with
   `visudo -c` before being written, so a bad rule can never be installed.
   Nothing else gains passwordless sudo.

Review `install.sh` and `magic-helper` yourself before running — they're
short and it's worth it, since one of them touches sudoers.

### Why sudo instead of polkit/pkexec

The original design used `pkexec` with a polkit policy (the "correct",
more standard approach — a real auth prompt each time rather than a
standing passwordless rule). On the system this was built on, COSMIC's
polkit agent (`cosmic-osd`) has a bug that intermittently — and on one
occasion, consistently — dismisses every polkit authentication request
(`Unknown prefix: 'polkit-agent-helper-1:'` in its logs when parsing a PAM
response), which made the app hang or fail unpredictably. Switching to a
narrowly-scoped sudoers rule sidesteps that agent entirely. If your
`cosmic-osd` doesn't have this bug, pkexec + a polkit policy is the more
conventional choice and you're welcome to swap it back — the helper script
itself doesn't care which mechanism invokes it.

## Using it

- **Menu → Preferences**: set Home Mode's screen-off/lock and suspend
  timeouts (minutes), and the Sunshine host/port Magic talks to.
- **Menu → Sunshine Credentials**: one-time entry of your Sunshine web UI
  username/password, stored in GNOME Keyring (needs `gir1.2-secret-1`).
- **Device Name / PIN fields**: when Moonlight shows a pairing PIN on a new
  device, type a name and that PIN here and press *Pair Device* instead of
  opening Sunshine's web page. The device name field remembers the last one
  you used.
- **Away Mode switch**: requires Ethernet connected to turn on; asks for
  confirmation since it disables all sleep/lock. Turning it off is
  immediate, no confirmation.
- **Menu → Help**: an in-app copy of the operating notes above.
- **Menu → Uninstall Magic**: same as running `uninstall.sh`.

## How idle timeouts work (and why they're not a systemd unit)

`cosmic-idle` — COSMIC's screen-lock/idle-suspend daemon — is spawned
directly by `cosmic-session` as a child process, not started through its
own systemd unit. Masking `cosmic-idle.service` (an earlier, incorrect
approach) does nothing. The real, live-reloaded config lives at
`~/.config/cosmic/com.system76.CosmicIdle/v1/{screen_off_time,suspend_on_ac_time}`
— the exact files `cosmic-settings`' Power panel itself edits (confirmed
from its source), storing milliseconds as RON `Some(N)` / `None`. Magic
writes these directly, so there's never a mismatch between what Magic shows
and what System Settings shows.

## Uninstall

```
./uninstall.sh
```

Reverts sleep/lock/Wake-on-LAN to normal, removes the sudoers rule and the
root helper, clears any saved Sunshine credentials from the keyring, and
deletes the installed app files. Does not touch this repo directory itself.

## Privacy / what's *not* in this repo

No credentials, tokens, or certificates are ever written to disk by Magic
— Sunshine credentials live only in GNOME Keyring. No hostnames, Tailscale
IPs/device names, or hardware identifiers from the original machine are
referenced anywhere in this code; the only hardware-specific values are the
two `IFACE`/`CONN` lines you're expected to edit before installing.

## Disclaimer

Personal utility, shared as-is for future reference. It runs a root-owned
script via sudo and edits systemd sleep targets, NetworkManager connection
settings, and COSMIC's idle config — read the scripts before trusting them
on a machine you care about.
