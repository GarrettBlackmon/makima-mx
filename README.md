# makima-mx

A Quickshell-based UI for [makima](https://github.com/cyber-sushi/makima) — remap
your Logitech MX Master 3/3S buttons interactively, with per-app overrides and
named profiles per app.

[![makima-mx demo](https://img.youtube.com/vi/E22ZDPkKVSw/maxresdefault.jpg)](https://www.youtube.com/watch?v=E22ZDPkKVSw)



## What it does

- Visual mouse with clickable buttons for rebinding
- Multi-key capture (e.g. Shift+/) with auto-save on release
- Named profiles per app (`Default`, `PvP`, `Skilling`, …)
- Per-app overrides (always-on; uses makima's `device::wm-class.toml` convention)
- Drag-to-reorder app pills · custom display names · custom icons
- Live status: active app (focused-window aware), makima daemon health, device
  connection
- **Chord profile switcher**: hold Back+Forward and scroll to flip through the
  focused app's profiles in an on-screen overlay, release to apply (see below)
- Auto-themes to DMS / Matugen colors when available

## Requirements

**Required:**
- [makima](https://github.com/cyber-sushi/makima) — the daemon doing the actual
  remapping (`paru -S makima` or build from source)
- [quickshell](https://quickshell.outfoxxed.me) ≥ 0.3
- A Logitech MX Master 3 or 3S (other Logitech mice probably work but BTN code
  mappings may differ — see `MakimaService.qml > buttonCodeOf`)

**Recommended:**
- [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) — for
  live Matugen colors. Without it, makima-mx uses a built-in dark scheme.
- Hyprland — for the live "Active: <app>" indicator. Other Wayland compositors
  work for everything else; the status bar just won't show the focused app.

**Assumed:**
- makima runs as a user systemd service (`systemctl --user start makima`)
- Bash + `awk` available (used by the device-detection probe)

## Install

### Per-user (any distro)

```sh
git clone https://github.com/GarrettBlackmon/makima-mx ~/projects/makima-mx
cd ~/projects/makima-mx
./scripts/install-local.sh        # adds launcher + .desktop + icons
makima-mx                         # launch (or pick it from your app menu)
```

Uninstall: `./scripts/uninstall-local.sh` (preserves your saved bindings).

### Arch / paru

```sh
git clone https://github.com/GarrettBlackmon/makima-mx
cd makima-mx
makepkg -si
```

### Just run it without installing

```sh
quickshell -p ./shell.qml
```

State lives in `$XDG_CONFIG_HOME/makima-mx/profiles.json` (defaults to
`~/.config/makima-mx/`). makima's per-device TOMLs are written to
`$XDG_CONFIG_HOME/makima/`.

The first time you save a binding, makima-mx will back up your existing global
TOML to `<deviceName>.toml.makima-mx-backup`.

## Device detection

On startup, makima-mx parses `/proc/bus/input/devices` looking for the first
entry whose Name contains `Logitech` or `MX Master` and that has a `mouseN`
handler. The Name field becomes the basename for makima's TOML files. If your
device shows under a different name (e.g. via a non-Logitech BT adapter), edit
`profiles.json` and set `deviceName` manually.

The probe re-runs every 5s, so unplugging or pairing the mouse updates the
top-right status dot live.

## Profile switcher (chord)

Hold **Back + Forward** together and a small overlay appears listing the
profiles of whatever app is focused (falling back to Global). Scroll to move
the selection while holding, then release both buttons: if you landed on a
different profile it is written out and makima is restarted once. Releasing on
the current profile is a no-op, so you can peek at the list freely.

While the chord is held the switcher is *modal*: scrolling moves the highlight
only, nothing leaks to the app underneath (no zooming your game), and the
cursor freezes until you release.

How it works, since makima itself can't do this: makima holds an exclusive
grab on the mouse, and its `[commands]` combos can't treat remapped buttons as
modifiers. So `scripts/chord-watch.py` (spawned by the shell, restarted if it
dies) detects the chord out-of-band via the `EVIOCGKEY` state ioctl, which the
kernel answers even for grabbed devices. Scroll detents are read from makima's
own virtual pointer device, which is also grabbed for the duration of the hold
to keep the menu modal. The helper prints `DOWN` / `SCROLL ±1` / `UP` lines
that drive the overlay.

Requirements: your user in the `input` group (for makima's virtual device
nodes; most makima setups already have this) and `python3` (stdlib only).

Debug/scripting entry points, no mouse needed:

```sh
qs ipc -p ~/projects/makima-mx/shell.qml call switcher begin   # open overlay
qs ipc -p ~/projects/makima-mx/shell.qml call switcher next    # move selection
qs ipc -p ~/projects/makima-mx/shell.qml call switcher commit  # apply + close
```

Known wart: the two chord buttons still fire their bound actions once on
press, because makima emits them before the chord is detectable. Pick your
chord-button bindings with that in mind.

## Limitations

- **MX Master 3/3S only** — button mappings (`BTN_SIDE`/`BTN_EXTRA`/`BTN_FORWARD`)
  are hardcoded for these. The Mode-shift and Thumb-wheel buttons are not yet
  wired (need evtest output to identify their evdev codes).
- **Captures keyboard keys only** — chord combos like Shift+/ work; chaining
  modifier-only or mouse-button targets is TBD.
- **Light theme** — Theme.qml currently only reads DMS's `dark` palette. Switch
  to `light` would need a one-line change + mode detection.

## Layout / file map

| File | Purpose |
|---|---|
| `shell.qml` | App entry, top bar, layout, modal hosting |
| `MakimaService.qml` | State, persistence, TOML I/O, device probe, daemon probe |
| `ProfileSwitcher.qml` | Chord-driven profile switcher overlay + IPC |
| `scripts/chord-watch.py` | Chord/scroll watcher (EVIOCGKEY + virtual-device reader) |
| `MouseDisplay.qml` | Mouse image + clickable overlays |
| `BindingsList.qml` | Right-hand binding rows |
| `CaptureModal.qml` | Key-capture popup |
| `NameProfileModal.qml` | New-profile naming |
| `AppPickerModal.qml` | Add-app picker (lists current Hyprland windows) |
| `IconEditModal.qml` | Per-app icon + display-name editor |
| `Theme.qml` | Matugen-aware color singleton |
| `KeyMap.js` | Qt.Key_* → KEY_* mapping for makima |
| `assets/mouse.png` | Product shot (1000×1000 RGBA), upscaled with Real-ESRGAN |
| `assets/fonts/MaterialSymbolsRounded.ttf` | Material Symbols (for the globe icon) |

## License

Mouse image: Logitech product shot, included under fair use.
Material Symbols: Apache 2.0.
Code: MIT
