#!/usr/bin/env bash
# Shared helpers for install.sh / uninstall.sh (sourced, not executed).

GL_CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
GL_DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
GL_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/glyph-lite"
GL_BACKUP="$GL_STATE/backup"
GL_MANIFEST="$GL_STATE/manifest"
DRY_RUN="${DRY_RUN:-0}"

C_RED=$'\033[38;2;215;25;33m'; C_DIM=$'\033[38;2;138;138;142m'; C_OFF=$'\033[0m'
say()  { printf '%s∷%s %s\n' "$C_RED" "$C_OFF" "$*"; }
warn() { printf '%s!%s %s\n' "$C_RED" "$C_OFF" "$*" >&2; }
dry()  { printf '%s  [dry-run]%s %s\n' "$C_DIM" "$C_OFF" "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

kw_bin() { if have kwriteconfig6; then echo kwriteconfig6; elif have kwriteconfig5; then echo kwriteconfig5; fi; }
kr_bin() { if have kreadconfig6; then echo kreadconfig6; elif have kreadconfig5; then echo kreadconfig5; fi; }

init_state() {
  [ "$DRY_RUN" = 1 ] && return 0
  mkdir -p "$GL_BACKUP"
  touch "$GL_MANIFEST"
}

# Is this path already recorded in the manifest? (field 2 = path)
tracked() {
  [ -f "$GL_MANIFEST" ] && awk -F'|' -v p="$1" '$2==p{f=1} END{exit !f}' "$GL_MANIFEST"
}

# Remember the original state of a file once, so uninstall can restore it.
track_file() {
  local f="$1"
  [ "$DRY_RUN" = 1 ] && return 0
  tracked "$f" && return 0
  if [ -e "$f" ]; then
    local b="$GL_BACKUP/$(printf '%s' "$f" | tr '/' '_')"
    cp -a "$f" "$b"
    printf 'file|%s|%s\n' "$f" "$b" >> "$GL_MANIFEST"
  else
    printf 'new|%s\n' "$f" >> "$GL_MANIFEST"
  fi
}

# Same for a directory (plasmoid / wallpaper package).
track_dir() {
  local d="$1"
  [ "$DRY_RUN" = 1 ] && return 0
  tracked "$d" && return 0
  if [ -e "$d" ]; then
    local b="$GL_BACKUP/$(printf '%s' "$d" | tr '/' '_')"
    cp -a "$d" "$b"
    printf 'dirbak|%s|%s\n' "$d" "$b" >> "$GL_MANIFEST"
  else
    printf 'newdir|%s\n' "$d" >> "$GL_MANIFEST"
  fi
}

install_file() { # src dest [mode]
  local src="$1" dest="$2" mode="${3:-644}"
  if [ "$DRY_RUN" = 1 ]; then dry "${src#"$SCRIPT_DIR"/} -> $dest"; return 0; fi
  track_file "$dest"
  mkdir -p "$(dirname "$dest")"
  install -m "$mode" "$src" "$dest"
}

# Write a KDE config key, remembering its previous value once.
kset() { # file group key value
  local f="$1" g="$2" k="$3" v="$4" kw kr old x
  local -a gargs=()
  IFS='/' read -ra _parts <<< "$g"
  for x in "${_parts[@]}"; do gargs+=(--group "$x"); done
  if [ "$DRY_RUN" = 1 ]; then dry "kwriteconfig --file $f --group '$g' --key $k $v"; return 0; fi
  kw="$(kw_bin)"; kr="$(kr_bin)"
  if [ -z "$kw" ]; then warn "kwriteconfig not found; skipped $f/$g/$k"; return 0; fi
  if ! awk -F'|' -v f="$f" -v g="$g" -v k="$k" '$1=="kde"&&$2==f&&$3==g&&$4==k{x=1} END{exit !x}' "$GL_MANIFEST" 2>/dev/null; then
    old="__ABSENT__"
    [ -n "$kr" ] && old="$("$kr" --file "$f" "${gargs[@]}" --key "$k" --default "__ABSENT__")"
    printf 'kde|%s|%s|%s|%s\n' "$f" "$g" "$k" "$old" >> "$GL_MANIFEST"
  fi
  "$kw" --file "$f" "${gargs[@]}" --key "$k" "$v"
}

reload_kwin() {
  [ "$DRY_RUN" = 1 ] && return 0
  have dbus-send && dbus-send --session --dest=org.kde.KWin --type=method_call /KWin org.kde.KWin.reconfigure >/dev/null 2>&1 || true
}

refresh_plasma_cache() {
  [ "$DRY_RUN" = 1 ] && return 0
  if have kbuildsycoca6; then kbuildsycoca6 >/dev/null 2>&1 || true; fi
}

# Sets DESK (plasma|xfce|gnome|other|unknown), SESSION_TYPE, PLASMA_VER, PLASMA_MAJOR, REMOTE (0/1).
detect_desktop() {
  SESSION_TYPE="${XDG_SESSION_TYPE:-unknown}"
  local cur="${XDG_CURRENT_DESKTOP:-}"
  cur="$(printf '%s' "$cur" | tr '[:upper:]' '[:lower:]')"
  case "$cur" in
    *kde*) DESK=plasma ;;
    *xfce*) DESK=xfce ;;
    *gnome*|*unity*|*ubuntu*) DESK=gnome ;;
    "") DESK=unknown ;;
    *) DESK=other ;;
  esac
  PLASMA_VER=""; PLASMA_MAJOR=0
  if have plasmashell; then
    PLASMA_VER="$(plasmashell --version 2>/dev/null | awk '{print $2}')"
    PLASMA_MAJOR="${PLASMA_VER%%.*}"
    case "$PLASMA_MAJOR" in ''|*[!0-9]*) PLASMA_MAJOR=0 ;; esac
  fi
  REMOTE=0
  if pgrep -f 'Xtigervnc|Xvnc|Xrdp|xrdp|x11vnc' >/dev/null 2>&1; then REMOTE=1; fi
}
