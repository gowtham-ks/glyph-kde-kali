#!/usr/bin/env python3
"""Checks for lib/glyphgen.py. Standard library only."""
import configparser, json, os, plistlib, struct, sys, tempfile, zlib
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "lib"))
import glyphgen as gg

failed = []
def check(cond, msg):
    if not cond:
        failed.append(msg); print("FAIL", msg)

cfg = gg.deep_merge(gg.DEFAULTS, {})
check(gg.validate(cfg) == [], "defaults validate")
check(gg.validate(gg.deep_merge(cfg, {"accent": "red"})) != [], "bad accent rejected")
check(gg.validate(gg.deep_merge(cfg, {"wallpaper": {"style": "x"}})) != [], "bad style rejected")
check(gg.on_color("#D71921") == "#FFFFFF" and gg.on_color("#F5A623") != "#FFFFFF", "contrast color choice")

for name, over in (("default", {}), ("amber", gg.PRESETS["amber"]), ("oled", gg.PRESETS["oled"])):
    c = gg.deep_merge(cfg, over)
    files = gg.text_files(c)
    with tempfile.TemporaryDirectory() as d:
        gg.write_files(files, d)
        need = {"Colors:Selection", "Colors:Tooltip", "Colors:Header", "ColorEffects:Inactive", "General", "WM"}
        for f in ("GlyphLite", "GlyphLiteLight"):
            cp = configparser.ConfigParser(interpolation=None, strict=True); cp.optionxform = str
            cp.read(os.path.join(d, "configs/color-schemes", f + ".colors"))
            check(need <= set(cp.sections()), f"{name}: {f} sections")
        for f in files:
            if f.endswith(".rasi"):
                t = files[f]; check(t.count("{") == t.count("}"), f"{name}: braces in {f}")

with tempfile.TemporaryDirectory() as d:
    ex = gg.export_files(cfg); gg.write_files(ex, d)
    j = json.load(open(os.path.join(d, "exports/windows-terminal.json")))
    check(len(j["schemes"]) == 2 and j["schemes"][0]["red"] == cfg["accent"], "windows terminal scheme")
    for k in ("dark", "light"):
        pl = plistlib.load(open(os.path.join(d, f"exports/iterm2-{k}.itermcolors"), "rb"))
        check("Ansi 15 Color" in pl and "Background Color" in pl, f"iterm2 {k}")
        json.load(open(os.path.join(d, f"exports/vscode-settings-{k}.json")))
        if sys.version_info >= (3, 11):
            import tomllib
            t = tomllib.load(open(os.path.join(d, f"exports/alacritty-{k}.toml"), "rb"))
            check(t["colors"]["normal"]["red"] == cfg["accent"] or k == "light", f"alacritty {k}")

for style in gg.STYLES:
    png = gg.wallpaper_png(gg.deep_merge(cfg, {"wallpaper": {"style": style}}), "dark", style, "320x180")
    check(png[:8] == b"\x89PNG\r\n\x1a\n", f"{style}: png signature")
    w, h = struct.unpack(">II", png[16:24]); check((w, h) == (320, 180), f"{style}: size")
    # decode IDAT to be sure the stream is valid
    i, idat = 8, b""
    while i < len(png):
        n = struct.unpack(">I", png[i:i + 4])[0]; tag = png[i + 4:i + 8]
        if tag == b"IDAT": idat += png[i + 8:i + 8 + n]
        i += 12 + n
    check(len(zlib.decompress(idat)) == 180 * (320 * 3 + 1), f"{style}: pixel data length")

print("unit tests:", "FAILED" if failed else "ok")
sys.exit(1 if failed else 0)
