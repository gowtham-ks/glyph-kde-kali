#!/usr/bin/env bash
# Glyph Lite installer. User-level only: no sudo (except --install-deps), no downloads.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

MODE=dark; STYLE=ring; VNC=0; NO_COMP=0; WIDGETS=1; DEPS=0; LAYOUT=0; LOCK=0; GTK=0

usage() {
  cat <<'U'
Glyph Lite installer

  ./install.sh [options]

  --dark | --light     starting mode (default: dark)
  --plain              plain dot-grid wallpaper instead of the ring
  --vnc-tune           low-resource tweaks: no animations, no blur, Baloo off
  --no-compositing     also turn KWin compositing off (implies --vnc-tune)
  --no-widgets         skip the two Plasma widgets
  --layout             add the floating top bar (island) and bottom dock (Plasma 6, running session)
  --lockscreen         use the Glyph wallpaper on the KDE lock screen
  --gtk                apply Glyph colors to GTK3/GTK4 apps
  --install-deps       apt-get install missing rofi/kitty/fastfetch/fonts (uses sudo)
  --dry-run            show what would happen, change nothing
  -h, --help           this help

Undo everything with ./uninstall.sh
U
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dark) MODE=dark ;;
    --light) MODE=light ;;
    --plain) STYLE=plain ;;
    --vnc-tune) VNC=1 ;;
    --no-compositing) NO_COMP=1; VNC=1 ;;
    --no-widgets) WIDGETS=0 ;;
    --install-deps) DEPS=1 ;;
    --layout) LAYOUT=1 ;;
    --lockscreen) LOCK=1 ;;
    --gtk) GTK=1 ;;
    --dry-run) DRY_RUN=1 ;;
    -h|--help) usage; exit 0 ;;
    *) warn "Unknown option: $1"; usage; exit 2 ;;
  esac
  shift
done

say "GLYPH LITE $(cat VERSION)"
[ "$DRY_RUN" = 1 ] && say "dry run: nothing will be changed"

if [ "$(id -u)" -eq 0 ]; then warn "Run as your normal user, not root."; exit 1; fi

# ---------------------------------------------------------------- environment
# shellcheck disable=SC1091
[ -r /etc/os-release ] && . /etc/os-release
say "System:  ${PRETTY_NAME:-unknown}"
say "Session: ${XDG_SESSION_TYPE:-unknown} / ${XDG_CURRENT_DESKTOP:-unknown}"

PLASMA6=0
if have plasmashell; then
  pv="$(plasmashell --version 2>/dev/null | awk '{print $2}')"
  say "Plasma:  ${pv:-unknown}"
  case "${pv:-}" in 6.*) PLASMA6=1 ;; esac
fi
[ "$PLASMA6" = 1 ] || say "Plasma 6 not found: KDE-only parts (widgets) are skipped. This is normal on XFCE or GNOME."
case "${XDG_SESSION_TYPE:-}" in x11|"") say "X11 session: blur/transparency may be limited; --vnc-tune is recommended over VNC." ;; esac

if [ "$DEPS" = 1 ]; then
  missing=()
  for pkg in rofi kitty fastfetch fonts-jetbrains-mono; do
    dpkg -s "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
  done
  if [ ${#missing[@]} -gt 0 ]; then
    say "Installing: ${missing[*]}"
    if [ "$DRY_RUN" = 1 ]; then dry "sudo apt-get install -y ${missing[*]}"
    else sudo apt-get install -y "${missing[@]}" || warn "apt-get failed; install them manually."
    fi
  fi
fi
for t in rofi kitty fastfetch; do have "$t" || warn "$t not installed: its theme is installed anyway and works once you add it."; done

init_state

# ---------------------------------------------------------------- KDE color schemes
say "Color schemes"
for s in GlyphLite GlyphLiteLight; do
  install_file "configs/color-schemes/$s.colors" "$GL_DATA/color-schemes/$s.colors"
done

# ---------------------------------------------------------------- terminals
say "Konsole, kitty, xfce4-terminal"
for f in GlyphLite.colorscheme GlyphLite.profile GlyphLiteLight.colorscheme GlyphLiteLight.profile; do
  install_file "configs/konsole/$f" "$GL_DATA/konsole/$f"
done
for m in dark light; do
  install_file "configs/kitty/glyph-$m.conf" "$GL_CONF/kitty/glyph-$m.conf"
  install_file "configs/xfce4-terminal/glyph-lite-$m.theme" "$GL_DATA/xfce4/terminal/colorschemes/glyph-lite-$m.theme"
  install_file "configs/rofi/glyph-$m.rasi" "$GL_CONF/rofi/glyph-$m.rasi"
done
if [ "$DRY_RUN" != 1 ]; then
  track_file "$GL_CONF/kitty/glyph.conf"
  track_file "$GL_CONF/rofi/glyph.rasi"
  track_file "$GL_CONF/kitty/kitty.conf"
  mkdir -p "$GL_CONF/kitty"
  touch "$GL_CONF/kitty/kitty.conf"
  grep -q '^include glyph.conf' "$GL_CONF/kitty/kitty.conf" || printf '\n# glyph-lite\ninclude glyph.conf\n' >> "$GL_CONF/kitty/kitty.conf"
else
  dry "append 'include glyph.conf' to $GL_CONF/kitty/kitty.conf"
fi

# ---------------------------------------------------------------- fastfetch, launcher
say "fastfetch, launcher"
install_file configs/fastfetch/glyph-logo.txt "$GL_CONF/fastfetch/glyph-logo.txt"
if [ "$DRY_RUN" = 1 ]; then
  dry "configs/fastfetch/config.jsonc.in -> $GL_CONF/fastfetch/config.jsonc"
else
  tmp="$(mktemp)"; sed "s|@CONF@|$GL_CONF|g" configs/fastfetch/config.jsonc.in > "$tmp"
  install_file "$tmp" "$GL_CONF/fastfetch/config.jsonc"; rm -f "$tmp"
fi
install_file configs/applications/glyph-launcher.desktop "$GL_DATA/applications/glyph-launcher.desktop"

# ---------------------------------------------------------------- wallpapers (Plasma packages)
say "Wallpapers"
wp() { # package-name label png
  local dir="$GL_DATA/wallpapers/$1"
  if [ "$DRY_RUN" = 1 ]; then dry "wallpaper package $1"; return 0; fi
  track_dir "$dir"
  mkdir -p "$dir/contents/images"
  cp -f "assets/wallpapers/$3" "$dir/contents/images/1920x1080.png"
  cat > "$dir/metadata.json" <<J
{
  "KPlugin": { "Id": "$1", "Name": "$2", "Authors": [{ "Name": "Glyph Lite" }], "License": "MIT" },
  "KPackageStructure": "Wallpaper/Images"
}
J
}
wp GlyphLite-Dark        "Glyph Lite Dark"        GlyphLite-Dark-ring.png
wp GlyphLite-Dark-Plain  "Glyph Lite Dark Plain"  GlyphLite-Dark-plain.png
wp GlyphLite-Light       "Glyph Lite Light"       GlyphLite-Light-ring.png
wp GlyphLite-Light-Plain "Glyph Lite Light Plain" GlyphLite-Light-plain.png

# ---------------------------------------------------------------- generic wallpaper copies (XFCE, GNOME, anything else)
say "Wallpaper files"
install_file assets/wallpapers/GlyphLite-Dark-ring.png   "$GL_DATA/glyph-lite/wallpapers/GlyphLite-Dark.png"
install_file assets/wallpapers/GlyphLite-Dark-plain.png  "$GL_DATA/glyph-lite/wallpapers/GlyphLite-Dark-Plain.png"
install_file assets/wallpapers/GlyphLite-Light-ring.png  "$GL_DATA/glyph-lite/wallpapers/GlyphLite-Light.png"
install_file assets/wallpapers/GlyphLite-Light-plain.png "$GL_DATA/glyph-lite/wallpapers/GlyphLite-Light-Plain.png"
if [ "$DRY_RUN" != 1 ] && have xfce4-terminal; then track_file "$GL_CONF/xfce4/terminal/terminalrc"; fi

# ---------------------------------------------------------------- widgets
if [ "$WIDGETS" = 1 ] && [ "$PLASMA6" = 1 ]; then
  say "Plasma widgets"
  for pdir in plasmoids/*/; do
    id="$(basename "$pdir")"
    dest="$GL_DATA/plasma/plasmoids/$id"
    if [ "$DRY_RUN" = 1 ]; then dry "plasmoid $id"; continue; fi
    track_dir "$dest"
    rm -rf "$dest"; mkdir -p "$(dirname "$dest")"
    cp -a "plasmoids/$id" "$dest"
  done
fi

# ---------------------------------------------------------------- mode switcher
install_file bin/glyph-lite-mode "$HOME/.local/bin/glyph-lite-mode" 755
install_file bin/glyph-lite-layout "$HOME/.local/bin/glyph-lite-layout" 755
install_file bin/glyph-lite-customize "$HOME/.local/bin/glyph-lite-customize" 755
install_file lib/glyphgen.py "$GL_DATA/glyph-lite/lib/glyphgen.py"
install_file layout/glyph-layout.js "$GL_DATA/glyph-lite/layout/glyph-layout.js"
for m in dark light; do
  install_file "configs/gtk/glyph-gtk-$m.css" "$GL_CONF/gtk-4.0/glyph-gtk-$m.css"
  install_file "configs/gtk/glyph-gtk-$m.css" "$GL_CONF/gtk-3.0/glyph-gtk-$m.css"
done
if [ "$GTK" = 1 ]; then
  say "GTK colors"
  if [ "$DRY_RUN" = 1 ]; then dry "enable GTK3/GTK4 overrides"
  else
    track_file "$GL_CONF/gtk-4.0/gtk.css"; track_file "$GL_CONF/gtk-3.0/gtk.css"
    track_file "$GL_STATE/gtk-enabled"; touch "$GL_STATE/gtk-enabled"
  fi
fi

# ---------------------------------------------------------------- apply
say "Applying $MODE mode"
if [ "$DRY_RUN" != 1 ]; then
  kr="$(kr_bin)"
  if [ -n "$kr" ] && ! grep -q '^scheme|' "$GL_MANIFEST" 2>/dev/null; then
    printf 'scheme|%s\n' "$("$kr" --file kdeglobals --group General --key ColorScheme --default BreezeDark)" >> "$GL_MANIFEST"
  fi
fi
[ -n "$(kw_bin)" ] && kset konsolerc "Desktop Entry" DefaultProfile "GlyphLite.profile"
if [ "$DRY_RUN" = 1 ]; then dry "glyph-lite-mode $MODE $STYLE"
else bash "$SCRIPT_DIR/bin/glyph-lite-mode" "$MODE" "$STYLE" || warn "mode switch reported a problem (themes are still installed)"
fi

if [ "$LOCK" = 1 ]; then
  if [ -n "$(kw_bin)" ]; then
    say "Lock screen wallpaper"
    kset kscreenlockerrc "Greeter/Wallpaper/org.kde.image/General" Image "file://$GL_DATA/glyph-lite/wallpapers/GlyphLite-$([ "$MODE" = light ] && echo Light || echo Dark).png"
  else warn "--lockscreen needs KDE tools; skipped."; fi
fi

# ---------------------------------------------------------------- VNC / low-resource tuning
if [ "$VNC" = 1 ] && [ -z "$(kw_bin)" ]; then
  warn "--vnc-tune needs KDE tools (kwriteconfig); skipped on this desktop."
elif [ "$VNC" = 1 ]; then
  say "Low-resource tuning"
  kset kdeglobals KDE AnimationDurationFactor 0
  kset kwinrc Plugins blurEnabled false
  kset kwinrc Plugins contrastEnabled false
  kset baloofilerc "Basic Settings" Indexing-Enabled false
  [ "$NO_COMP" = 1 ] && kset kwinrc Compositing Enabled false
  reload_kwin
fi

refresh_plasma_cache

if [ "$LAYOUT" = 1 ]; then
  if [ "$PLASMA6" != 1 ]; then warn "--layout needs Plasma 6; skipped."
  elif [ "$DRY_RUN" = 1 ]; then dry "glyph-lite-layout apply"
  else
    say "Adding top bar and dock (backup kept; undo with: glyph-lite-layout restore)"
    PATH="$HOME/.local/bin:$PATH" bash "$SCRIPT_DIR/bin/glyph-lite-layout" apply || warn "Layout step failed; the rest is installed."
  fi
fi

echo
say "Done."
[ "$PLASMA6" = 1 ] && [ "$WIDGETS" = 1 ] && echo '  - Add widgets: right-click desktop > Add Widgets > search "Glyph" (clock, meters, calendar, network, battery, media, island)'
[ "$PLASMA6" = 1 ] && [ "$LAYOUT" = 0 ] && echo '  - Top bar + dock: glyph-lite-layout apply   (undo: glyph-lite-layout restore)'
cat <<'N'
  - Make it yours: glyph-lite-customize wizard   (accent color, wallpaper style, fonts, more)
  - Switch look: glyph-lite-mode toggle     (make sure ~/.local/bin is on your PATH)
  - Launcher:    rofi -show drun -theme glyph   (bind it to a shortcut)
  - Terminal:    kitty / Konsole pick the theme up automatically; for xfce4-terminal
                 choose "Glyph Lite" under Preferences > Colors > Presets
  - Undo:        ./uninstall.sh
N
