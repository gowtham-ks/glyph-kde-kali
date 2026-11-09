# Changelog

## 1.4.0

- Layout is now fully configurable: `layout.*` settings (bar/dock on or off, positions, heights, floating, fit/fill, item lists) and seven presets via `glyph-lite-customize layout`
- The panel script is generated from your settings; `glyph-lite-layout apply` refuses to add a second copy, and `reapply` swaps in a changed layout (restore removes the backup so status is accurate)
- Settings pages for Glyph Island (12/24 h, date, date style, CPU dot, outline), Dot Clock (12/24 h, date) and Dot Calendar (week start)
- Test harness loads every settings page and checks that config keys used in QML exist in `main.xml` and on the settings page

## 1.3.0

- `glyph-lite-customize`: wizard, presets, `set`/`get`, `apply`, `preview`, `export`, `reset`; settings in `~/.config/glyph-lite/theme.conf`
- Everything (KDE scheme, Konsole, kitty, xfce4-terminal, rofi, GTK, fastfetch, wallpapers) is now generated from that one config by `lib/glyphgen.py`
- Accent color, dark/light palettes, wallpaper style (ring, plain, wave, spiral), ring count, dot size, size, font and corner radius are all configurable; text on the accent picks white or dark automatically
- Built-in pure-Python PNG renderer for wallpapers: cairosvg is no longer needed anywhere
- `export` writes theme files for Windows Terminal, iTerm2 (macOS), Alacritty, VS Code and X resources
- Unit tests for the generator, run by `validate.sh`

## 1.2.0

- New widgets: Glyph Island (pill for a panel with a popup), Dot Calendar, Dot Network, Dot Battery, Dot Media (playerctl)
- `glyph-lite-layout apply|restore`: floating top bar (pager, island, system tray) and floating bottom dock using stock Plasma applets, with a backup of your panels
- Optional `--lockscreen` (Glyph wallpaper on the KDE lock screen) and `--gtk` (GTK3/GTK4 color overrides, follow dark/light)
- Offscreen QML render test (`tests/qml/render.py`) with stubbed KDE modules; previews in `docs/widgets-preview.png`
- Installer installs every widget in `plasmoids/` and supports nested KDE config groups for undo

Not included: boot splash, login screen (SDDM) theme and a notification skin; they need root or native code and cannot be tested safely here.

## 1.1.0

- `setup.sh`: guided, beginner-friendly setup that detects your desktop, explains what will work, asks yes/no questions and previews before installing (`--yes`, `--check`)
- New desktop support: XFCE (wallpaper, xfce4-terminal), GNOME (wallpaper, dark/light), Plasma 5 (colors, wallpapers), and a safe fallback for any other desktop
- Wallpapers also saved to `~/.local/share/glyph-lite/wallpapers/` for manual use
- `START-HERE.md`: plain-language guide with a per-desktop table and fixes
- Installer no longer fails on non-KDE desktops; KDE-only steps are skipped with a clear message

## 1.0.0

Rewrite of glyph-kde-kali as a lightweight, distro-neutral pack aimed at Debian 13 +
KDE Plasma 6.3 over VNC (it should also work on Kali and other Plasma 6 systems).

- Dark and light modes, switchable with `glyph-lite-mode toggle`
- Two small Plasma 6 widgets: Glyph Dot Clock and Glyph Dot Meters (QML only, no daemon)
- Dot-ring wallpapers (ring and plain, dark and light) as ready-made Plasma wallpaper packages
- Color schemes now complete (Tooltip, Header, Complementary, Inactive effects included)
- Konsole, kitty, xfce4-terminal, rofi and fastfetch themes, all generated from one palette
- `--vnc-tune` and `--no-compositing` for software-rendered desktops
- Manifest-based uninstall that restores files and individual KDE keys, plus `--dry-run`
- No downloads, no git clones, no sudo (apt only with `--install-deps`)
- `validate.sh`, `tools/package.sh` and a CI workflow
- MIT license

Removed: the Kali dragon art (replaced by the ring motif), the bundled .deb build,
third-party font and wallpaper downloads.
