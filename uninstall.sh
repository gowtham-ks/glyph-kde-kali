#!/usr/bin/env bash
# Restore everything Glyph Lite changed, using the manifest written by install.sh.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

if [ "${1:-}" = "--dry-run" ]; then DRY_RUN=1; fi
if [ ! -f "$GL_MANIFEST" ]; then warn "No manifest at $GL_MANIFEST: nothing to uninstall."; exit 0; fi

say "Restoring from $GL_MANIFEST"
kw="$(kw_bin)"
while IFS='|' read -r kind a b c d; do
  case "$kind" in
    file)   if [ "$DRY_RUN" = 1 ]; then dry "restore $a"; else cp -a "$b" "$a"; fi ;;
    new)    if [ "$DRY_RUN" = 1 ]; then dry "remove $a"; else rm -f "$a"; fi ;;
    dirbak) if [ "$DRY_RUN" = 1 ]; then dry "restore dir $a"; else rm -rf "$a"; cp -a "$b" "$a"; fi ;;
    newdir) if [ "$DRY_RUN" = 1 ]; then dry "remove dir $a"; else rm -rf "$a"; fi ;;
    kde)
      if [ "$DRY_RUN" = 1 ]; then dry "restore $a [$b] $c"
      elif [ -n "$kw" ]; then
        gargs=(); IFS='/' read -ra parts <<< "$b"
        for x in "${parts[@]}"; do gargs+=(--group "$x"); done
        if [ "$d" = "__ABSENT__" ]; then "$kw" --file "$a" "${gargs[@]}" --key "$c" --delete
        else "$kw" --file "$a" "${gargs[@]}" --key "$c" "$d"; fi
      fi ;;
    scheme)
      if [ "$DRY_RUN" = 1 ]; then dry "plasma-apply-colorscheme $a"
      elif have plasma-apply-colorscheme; then plasma-apply-colorscheme "$a" >/dev/null 2>&1 || true; fi ;;
  esac
done < <(tac "$GL_MANIFEST")

if [ "$DRY_RUN" != 1 ]; then
  rm -rf "$GL_STATE"
  reload_kwin
  refresh_plasma_cache
fi
say "Done. Your previous wallpaper is not restored automatically; pick it in System Settings."
say "Log out and back in if some colors still look off."
