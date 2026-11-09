#!/usr/bin/env bash
# Glyph Lite - guided setup for beginners.
#   ./setup.sh            ask a few simple questions, then install
#   ./setup.sh --yes      accept the recommended answers, no questions
#   ./setup.sh --check    only report what would work on this computer
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

YES=0; CHECK=0
for a in "$@"; do
  case "$a" in
    --yes|-y) YES=1 ;;
    --check) CHECK=1 ;;
    -h|--help) sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) warn "Unknown option: $a (try --help)"; exit 2 ;;
  esac
done

ask() { # question default(y/n) -> returns 0 for yes
  local q="$1" d="$2" a
  if [ "$YES" = 1 ]; then [ "$d" = y ]; return; fi
  read -r -p "$q [$([ "$d" = y ] && echo 'Y/n' || echo 'y/N')] " a || a=""
  a="${a:-$d}"; case "$a" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}

if [ "$(id -u)" -eq 0 ]; then warn "Please run this as your normal user (not root, no sudo). It asks for a password only if it needs one."; exit 1; fi

say "GLYPH LITE SETUP"
detect_desktop
# shellcheck disable=SC1091
[ -r /etc/os-release ] && . /etc/os-release
echo
echo "What I found on this computer:"
echo "  System:   ${PRETTY_NAME:-unknown}"
echo "  Desktop:  ${XDG_CURRENT_DESKTOP:-unknown}   (type: $SESSION_TYPE)"
[ -n "$PLASMA_VER" ] && echo "  Plasma:   $PLASMA_VER"
[ "$REMOTE" = 1 ] && echo "  Remote desktop (VNC/RDP) detected"
echo

# ---- what will work, in plain words
case "$DESK" in
  plasma)
    if [ "$PLASMA_MAJOR" -ge 6 ]; then
      echo "Good news: you get everything: colors, wallpapers, the two widgets, terminal, launcher and fastfetch themes."
      PLASMA_OK=1
    else
      echo "Your Plasma is older than version 6. You get the terminal, launcher, fastfetch, colors and wallpapers,"
      echo "but not the two widgets (they need Plasma 6)."
      PLASMA_OK=0
    fi ;;
  xfce)
    echo "XFCE detected (Kali's default). You get: wallpaper, terminal colors (xfce4-terminal, kitty), launcher and fastfetch themes."
    echo "The KDE-only parts (color scheme, widgets) are skipped automatically. To get those, log into a KDE Plasma session instead."
    PLASMA_OK=0 ;;
  gnome)
    echo "GNOME detected. You get: wallpaper, dark/light switch, kitty, launcher and fastfetch themes. KDE-only parts are skipped."
    PLASMA_OK=0 ;;
  *)
    echo "I could not tell which desktop you use. You still get the terminal, launcher and fastfetch themes,"
    echo "and the wallpapers are saved in ~/.local/share/glyph-lite/wallpapers/ for you to set by hand."
    PLASMA_OK=0 ;;
esac
echo
echo "Apps used by the themes:"
missing=()
for t in rofi kitty fastfetch; do
  if have "$t"; then echo "  [ok]       $t"; else echo "  [missing]  $t  (optional)"; missing+=("$t"); fi
done
echo
[ "$CHECK" = 1 ] && { say "Check finished. Nothing was changed."; exit 0; }

# ---- questions
ARGS=()
if ask "Use the DARK look? (answer n for light)" y; then ARGS+=(--dark); else ARGS+=(--light); fi

if [ "$DESK" = plasma ] && { [ "$REMOTE" = 1 ] && ask "You seem to be on a remote desktop. Turn off animations and blur to keep it fast?" y || \
     { [ "$REMOTE" = 0 ] && ask "Turn off animations and blur to save resources? (recommended only on slow computers)" n; }; }; then
  ARGS+=(--vnc-tune)
fi

if [ "${PLASMA_OK:-0}" = 1 ]; then
  if ask "Add the floating top bar (island) and bottom dock? This adds two panels; you can undo it later." n; then ARGS+=(--layout); fi
  if ask "Use the Glyph wallpaper on the lock screen too?" y; then ARGS+=(--lockscreen); fi
fi
if ask "Also recolor GTK apps (Firefox menus, Thunar, etc.) to match?" n; then ARGS+=(--gtk); fi

if [ ${#missing[@]} -gt 0 ] && have apt-get; then
  if ask "Install the missing apps (${missing[*]}) with apt? This will ask for your password." n; then ARGS+=(--install-deps); fi
fi

echo
say "Preview first (nothing is changed yet):"
"$SCRIPT_DIR/install.sh" --dry-run "${ARGS[@]}" 2>&1 | grep -c 'dry-run' | sed 's/^/  steps planned: /'
echo
if ! ask "Go ahead and install?" y; then say "Cancelled. Nothing was changed."; exit 0; fi

"$SCRIPT_DIR/install.sh" "${ARGS[@]}"
rc=$?
if [ $rc -eq 0 ] && [ "$YES" = 0 ] && ask "Pick your own accent color and wallpaper style now?" n; then "$HOME/.local/bin/glyph-lite-customize" wizard; fi
echo
if [ $rc -ne 0 ]; then warn "The installer stopped with an error. Nothing is half-installed that ./uninstall.sh cannot undo."; exit $rc; fi

say "All set. Handy things to know:"
echo "  Make it yours:      glyph-lite-customize wizard   (colors, wallpaper style, fonts, corners)"
echo "  Switch dark/light:  glyph-lite-mode toggle      (if 'command not found', log out and in once)"
echo "  Launcher:           rofi -show drun -theme glyph"
echo "  Fancy terminal info: fastfetch"
[ "$PLASMA_OK" = 1 ] && echo "  Widgets:            right-click the desktop > Add Widgets > search 'Glyph'"
[ "$PLASMA_OK" = 1 ] && echo "  Top bar + dock:     glyph-lite-layout apply   (undo: glyph-lite-layout restore)"
echo "  Undo everything:    ./uninstall.sh"
echo "  If something looks odd, log out and back in once. Help: START-HERE.md"
