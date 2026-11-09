#!/usr/bin/env python3
"""Regenerate every shipped theme file and wallpaper from the default settings.

    python3 tools/make_assets.py        # standard library only, no cairosvg needed
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "lib"))
import glyphgen as gg  # noqa: E402


def main():
    cfg = gg.deep_merge(gg.DEFAULTS, {})
    files = gg.text_files(cfg)
    files.update(gg.main_wallpapers(cfg))
    gg.write_files(files, ROOT)
    for k in ("dark", "light"):
        gg.write_files({f"docs/preview-{k}.png": gg.wallpaper_png(cfg, k, "ring", "960x540")}, ROOT)
    # drop SVG wallpapers from older versions
    wp = os.path.join(ROOT, "assets", "wallpapers")
    for f in os.listdir(wp):
        if f.endswith(".svg"):
            os.remove(os.path.join(wp, f))
    print("assets generated")


if __name__ == "__main__":
    main()
