"""Glyph Lite generator: one config in, every theme file out. Python 3.8+, standard library only.

The same code produces the files shipped in the zip (tools/make_assets.py) and the files
`glyph-lite-customize apply` writes after you change your settings.
"""
import copy
import json
import math
import os
import struct
import zlib

# --------------------------------------------------------------------------- config
DEFAULTS = {
    "accent": "#D71921",
    "dark": {"bg": "#0A0A0C", "panel": "#121215", "alt": "#1A1A1E", "fg": "#F0F0F2",
             "muted": "#8A8A8E", "grid": "#17171B"},
    "light": {"bg": "#F2F2F0", "panel": "#FFFFFF", "alt": "#E8E8E6", "fg": "#101012",
              "muted": "#6E6E72", "grid": "#DEDEDA"},
    "wallpaper": {"style": "ring", "rings": 5, "dot": 5.0, "grid": True, "size": "1920x1080"},
    "font": {"mono": "JetBrains Mono", "size": 11},
    "rofi": {"radius": 26, "width": 560},
    "mode": {"default": "dark"},
    "layout": {"bar": True, "dock": True, "bar_position": "top", "dock_position": "bottom",
               "bar_height": 32, "dock_height": 52, "floating": True, "length": "fit",
               "bar_items": "pager,spacer,island,spacer,tray", "dock_items": "tasks"},
}

# Tokens usable in layout.bar_items / layout.dock_items
LAYOUT_WIDGETS = {
    "pager": "org.kde.plasma.pager", "spacer": "org.kde.plasma.panelspacer", "island": "org.glyphlite.island",
    "tray": "org.kde.plasma.systemtray", "tasks": "org.kde.plasma.icontasks", "launcher": "org.kde.plasma.kickoff",
    "clock": "org.kde.plasma.digitalclock", "desktop": "org.kde.plasma.showdesktop",
    "separator": "org.kde.plasma.marginsseparator",
}

LAYOUT_PRESETS = {
    "default":   {},
    "bar-only":  {"dock": False},
    "dock-only": {"bar": False},
    "compact":   {"bar_height": 26, "dock_height": 44},
    "side-dock": {"dock_position": "left", "dock_height": 56},
    "classic":   {"dock": False, "floating": False, "length": "fill",
                  "bar_items": "launcher,tasks,spacer,island,spacer,tray"},
    "minimal":   {"dock": False, "bar_items": "island,spacer,tray"},
}

STYLES = ("ring", "plain", "wave", "spiral")

PRESETS = {
    "nothing-red": {"accent": "#D71921"},
    "ice":    {"accent": "#4FC3F7"},
    "mint":   {"accent": "#2ECC71"},
    "amber":  {"accent": "#F5A623"},
    "orange": {"accent": "#FF6A00"},
    "violet": {"accent": "#9B6DFF"},
    "pink":   {"accent": "#FF4B8B"},
    "oled":   {"dark": {"bg": "#000000", "panel": "#08080A", "alt": "#111114", "grid": "#101013"}},
    "soft":   {"dark": {"bg": "#141418", "panel": "#1B1B21", "alt": "#23232A", "grid": "#1E1E24"}},
}


def deep_merge(base, over):
    out = copy.deepcopy(base)
    for k, v in (over or {}).items():
        if isinstance(v, dict) and isinstance(out.get(k), dict):
            out[k] = deep_merge(out[k], v)
        else:
            out[k] = v
    return out


def is_hex(s):
    return isinstance(s, str) and len(s) == 7 and s[0] == "#" and all(c in "0123456789abcdefABCDEF" for c in s[1:])


def validate(cfg):
    """Return a list of human-readable problems (empty list = fine)."""
    bad = []
    if not is_hex(cfg["accent"]):
        bad.append("accent must look like #RRGGBB")
    for m in ("dark", "light"):
        for k, v in cfg[m].items():
            if not is_hex(v):
                bad.append(f"{m}.{k} must look like #RRGGBB")
    w = cfg["wallpaper"]
    if w["style"] not in STYLES:
        bad.append("wallpaper.style must be one of: " + ", ".join(STYLES))
    if not (1 <= int(w["rings"]) <= 8):
        bad.append("wallpaper.rings must be 1 to 8")
    if not (2.0 <= float(w["dot"]) <= 12.0):
        bad.append("wallpaper.dot must be 2 to 12")
    try:
        sw, sh = parse_size(w["size"])
        if not (640 <= sw <= 7680 and 360 <= sh <= 4320):
            bad.append("wallpaper.size must be between 640x360 and 7680x4320")
    except ValueError:
        bad.append("wallpaper.size must look like 1920x1080")
    if cfg["mode"]["default"] not in ("dark", "light"):
        bad.append("mode.default must be dark or light")
    if not (0 <= int(cfg["rofi"]["radius"]) <= 60):
        bad.append("rofi.radius must be 0 to 60")
    if not (6 <= int(cfg["font"]["size"]) <= 32):
        bad.append("font.size must be 6 to 32")
    lay = cfg["layout"]
    if lay["bar_position"] not in ("top", "bottom"):
        bad.append("layout.bar_position must be top or bottom")
    if lay["dock_position"] not in ("top", "bottom", "left", "right"):
        bad.append("layout.dock_position must be top, bottom, left or right")
    if not (20 <= int(lay["bar_height"]) <= 80):
        bad.append("layout.bar_height must be 20 to 80")
    if not (28 <= int(lay["dock_height"]) <= 128):
        bad.append("layout.dock_height must be 28 to 128")
    if lay["length"] not in ("fit", "fill"):
        bad.append("layout.length must be fit or fill")
    for k in ("bar_items", "dock_items"):
        for tok in [t.strip() for t in str(lay[k]).split(",") if t.strip()]:
            if tok not in LAYOUT_WIDGETS:
                bad.append(f"layout.{k}: unknown item '{tok}' (use: {', '.join(LAYOUT_WIDGETS)})")
    return bad


def parse_size(s):
    a, b = str(s).lower().split("x")
    return int(a), int(b)


# --------------------------------------------------------------------------- colors
def rgb_of(h):
    h = h.lstrip("#")
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def hex_of(c):
    return "#%02X%02X%02X" % tuple(max(0, min(255, int(round(x)))) for x in c)


def mix(a, b, t):
    ra, rb = rgb_of(a), rgb_of(b)
    return hex_of([ra[i] + (rb[i] - ra[i]) * t for i in range(3)])


def lighten(c, t):
    return mix(c, "#FFFFFF", t)


def darken(c, t):
    return mix(c, "#000000", t)


def luminance(c):
    def lin(v):
        v /= 255.0
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = (lin(x) for x in rgb_of(c))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def on_color(c):
    """Readable text color on top of `c`."""
    return "#FFFFFF" if luminance(c) < 0.38 else "#101012"


def commas(h):
    return ",".join(str(x) for x in rgb_of(h))


def palette(cfg, key):
    p = dict(cfg[key])
    acc = cfg["accent"]
    p.update(key=key, accent=acc, on_accent=on_color(acc), dot=p["fg"])
    if key == "dark":
        p.update(name="GlyphLite", label="Glyph Lite")
        red = [acc, lighten(acc, 0.22), acc, lighten(acc, 0.32)]
        ansi = [p["panel"], red[0], "#2ECC71", "#F5A623", "#5C9FD8", red[2], "#4AC2B8", p["fg"],
                "#55555A", red[1], "#58D68D", "#F8C471", "#85C1E9", red[3], "#76D7C4", "#FFFFFF"]
    else:
        p.update(name="GlyphLiteLight", label="Glyph Lite Light")
        ansi = [p["fg"], acc, "#1E8E4E", "#B8740A", "#2F6DA8", darken(acc, 0.15), "#1F8A82", "#C8C8C4",
                p["muted"], lighten(acc, 0.2), "#2ECC71", "#D18A14", "#4B8AC4", acc, "#2AA89E", p["bg"]]
    p["ansi"] = ansi
    return p


# --------------------------------------------------------------------------- text themes
def kde_block(name, p, bg, alt):
    return (f"[Colors:{name}]\nBackgroundAlternate={commas(alt)}\nBackgroundNormal={commas(bg)}\n"
            f"DecorationFocus={commas(p['accent'])}\nDecorationHover={commas(p['accent'])}\n"
            f"ForegroundActive={commas(p['accent'])}\nForegroundInactive={commas(p['muted'])}\n"
            f"ForegroundLink={commas(p['accent'])}\nForegroundNegative={commas(p['accent'])}\n"
            f"ForegroundNeutral=245,166,35\nForegroundNormal={commas(p['fg'])}\n"
            f"ForegroundPositive=46,204,113\nForegroundVisited={commas(p['muted'])}\n\n")


def kde_scheme(cfg, key):
    p = palette(cfg, key)
    dark = key == "dark"
    oa = commas(p["on_accent"])
    out = ("[ColorEffects:Disabled]\nColor=56,56,56\nColorAmount=0\nColorEffect=0\nContrastAmount=0.65\n"
           "ContrastEffect=1\nIntensityAmount=0.1\nIntensityEffect=2\n\n"
           "[ColorEffects:Inactive]\nChangeSelectionColor=true\nColor=112,111,110\nColorAmount=0.025\n"
           "ColorEffect=2\nContrastAmount=0.1\nContrastEffect=2\nEnable=false\nIntensityAmount=0\nIntensityEffect=0\n\n")
    out += kde_block("Button", p, p["alt"], p["panel"])
    out += kde_block("Complementary", p, p["panel"], p["bg"])
    out += kde_block("Header", p, p["panel"], p["bg"])
    out += ("[Colors:Selection]\nBackgroundAlternate=%s\nBackgroundNormal=%s\nDecorationFocus=%s\nDecorationHover=%s\n"
            "ForegroundActive=%s\nForegroundInactive=%s\nForegroundLink=%s\nForegroundNegative=%s\n"
            "ForegroundNeutral=%s\nForegroundNormal=%s\nForegroundPositive=%s\nForegroundVisited=%s\n\n"
            % (commas(darken(p["accent"], 0.15)), commas(p["accent"]), oa, oa, oa, oa, oa, oa, oa, oa, oa, oa))
    out += kde_block("Tooltip", p, p["alt"], p["panel"])
    out += kde_block("View", p, p["bg"] if dark else p["panel"], p["panel"] if dark else p["bg"])
    out += kde_block("Window", p, p["bg"], p["panel"])
    out += (f"[General]\nColorScheme={p['name']}\nName={p['label']}\nshadeSortColumn=true\n\n[KDE]\ncontrast=4\n\n"
            f"[WM]\nactiveBackground={commas(p['bg'])}\nactiveBlend={commas(p['accent'])}\n"
            f"activeForeground={commas(p['fg'])}\ninactiveBackground={commas(p['bg'])}\n"
            f"inactiveBlend={commas(p['alt'])}\ninactiveForeground={commas(p['muted'])}\n")
    return {f"configs/color-schemes/{p['name']}.colors": out}


def konsole(cfg, key):
    p = palette(cfg, key)
    out = f"[Background]\nColor={commas(p['bg'])}\n\n[BackgroundIntense]\nColor={commas(p['panel'])}\n\n"
    for i in range(8):
        out += f"[Color{i}]\nColor={commas(p['ansi'][i])}\n\n[Color{i}Intense]\nColor={commas(p['ansi'][i + 8])}\n\n"
    out += (f"[Foreground]\nColor={commas(p['fg'])}\n\n[ForegroundIntense]\nColor={commas(p['fg'])}\n\n"
            f"[General]\nBlur=false\nDescription={p['label']}\nOpacity=1\n")
    f = cfg["font"]
    prof = (f"[Appearance]\nColorScheme={p['name']}\nFont={f['mono']},{f['size']},-1,5,50,0,0,0,0,0\n\n"
            f"[General]\nName={p['label']}\nParent=FALLBACK/\n\n[Scrolling]\nHistorySize=5000\n")
    return {f"configs/konsole/{p['name']}.colorscheme": out, f"configs/konsole/{p['name']}.profile": prof}


def kitty(cfg, key):
    p = palette(cfg, key)
    out = f"# {p['label']} - generated by glyph-lite\n"
    out += (f"background {p['bg']}\nforeground {p['fg']}\ncursor {p['accent']}\ncursor_text_color {p['bg']}\n"
            f"selection_background {p['accent']}\nselection_foreground {p['on_accent']}\nurl_color {p['accent']}\n"
            f"active_border_color {p['accent']}\ninactive_border_color {p['alt']}\n"
            f"active_tab_background {p['accent']}\nactive_tab_foreground {p['on_accent']}\n"
            f"inactive_tab_background {p['panel']}\ninactive_tab_foreground {p['muted']}\n")
    out += "".join(f"color{i} {c}\n" for i, c in enumerate(p["ansi"]))
    return {f"configs/kitty/glyph-{key}.conf": out}


def xfce_terminal(cfg, key):
    p = palette(cfg, key)
    return {f"configs/xfce4-terminal/glyph-lite-{key}.theme":
            f"[Scheme]\nName={p['label']}\nColorForeground={p['fg']}\nColorBackground={p['bg']}\n"
            f"ColorCursor={p['accent']}\nColorSelection={p['accent']}\nColorSelectionUseDefault=FALSE\n"
            f"ColorPalette={';'.join(p['ansi'])}\n"}


def rofi(cfg, key):
    p = palette(cfg, key)
    r, f = cfg["rofi"], cfg["font"]
    out = f"""/* {p['label']} rofi theme - generated by glyph-lite */
* {{
    bg:        {p['bg']}F2;
    bg-alt:    {p['alt']}FF;
    fg:        {p['fg']}FF;
    muted:     {p['muted']}FF;
    accent:    {p['accent']}FF;
    on-accent: {p['on_accent']}FF;
    background-color: transparent;
    text-color: @fg;
    font: "{f['mono']} {f['size']}";
}}

window {{
    width: {int(r['width'])}px;
    background-color: @bg;
    border: 2px;
    border-color: @accent;
    border-radius: {int(r['radius'])}px;
    padding: 20px;
}}

mainbox {{ children: [inputbar, listview]; spacing: 14px; }}

inputbar {{
    children: [prompt, entry];
    background-color: @bg-alt;
    border-radius: 999px;
    padding: 12px 20px;
    spacing: 12px;
}}

prompt {{ text-color: @accent; }}
entry {{ placeholder: "SEARCH"; placeholder-color: @muted; }}

listview {{ lines: 7; columns: 1; fixed-height: false; scrollbar: false; spacing: 4px; }}

element {{ padding: 10px 16px; border-radius: {max(4, int(r['radius']) // 2)}px; spacing: 12px; }}
element-icon {{ size: 24px; }}
element-text {{ vertical-align: 0.5; text-color: inherit; }}
element selected.normal {{ background-color: @accent; text-color: @on-accent; }}
"""
    return {f"configs/rofi/glyph-{key}.rasi": out}


def gtk(cfg, key):
    p = palette(cfg, key)
    view = p["bg"] if key == "dark" else p["panel"]
    names = {
        "accent_color": p["accent"], "accent_bg_color": p["accent"], "accent_fg_color": p["on_accent"],
        "window_bg_color": p["bg"], "window_fg_color": p["fg"], "view_bg_color": view, "view_fg_color": p["fg"],
        "headerbar_bg_color": p["panel"], "headerbar_fg_color": p["fg"], "headerbar_border_color": p["alt"],
        "card_bg_color": p["panel"], "card_fg_color": p["fg"], "popover_bg_color": p["alt"],
        "popover_fg_color": p["fg"], "sidebar_bg_color": p["panel"], "sidebar_fg_color": p["fg"],
        "dialog_bg_color": p["panel"], "dialog_fg_color": p["fg"],
        "theme_bg_color": p["bg"], "theme_fg_color": p["fg"], "theme_base_color": view, "theme_text_color": p["fg"],
        "theme_selected_bg_color": p["accent"], "theme_selected_fg_color": p["on_accent"],
    }
    out = f"/* {p['label']} - generated by glyph-lite */\n" + "".join(f"@define-color {k} {v};\n" for k, v in names.items())
    return {f"configs/gtk/glyph-gtk-{key}.css": out}


# --------------------------------------------------------------------------- ring geometry (shared)
def ring_dots(cx, cy, n, r, rot=-math.pi / 2):
    return [(cx + r * math.cos(rot + 2 * math.pi * k / n), cy + r * math.sin(rot + 2 * math.pi * k / n), k / n)
            for k in range(n)]


def fastfetch_logo(cfg):
    cols, rows = 43, 21
    cx, cy = cols // 2, rows // 2
    grid = [[" "] * cols for _ in range(rows)]
    for ri, (r, n) in enumerate([(10, 84), (7, 56), (4, 30)]):
        for x, y, t in ring_dots(0, 0, n, r):
            gx, gy = int(round(cx + x * 2)), int(round(cy + y))
            if 0 <= gx < cols and 0 <= gy < rows:
                red = (ri == 1 and 0.55 <= t < 0.80) or (ri == 0 and 0.02 <= t < 0.06)
                grid[gy][gx] = "R" if red else "W"
    grid[cy][cx] = "R"
    lines = []
    for row in grid:
        line, last = "", ""
        for ch in row:
            if ch == " ":
                line += " "
                continue
            col = "$1" if ch == "R" else "$2"
            if col != last:
                line += col
                last = col
            line += "\u25cf"
        lines.append(line.rstrip())
    lines += ["", "$1" + "\u2237 G L Y P H  L I T E \u2237".center(cols).rstrip()]
    return {"configs/fastfetch/glyph-logo.txt": "\n".join(lines) + "\n"}


# --------------------------------------------------------------------------- tiny raster + PNG
class Canvas:
    def __init__(self, w, h, bg):
        self.w, self.h = w, h
        self.buf = bytearray(bytes(rgb_of(bg)) * (w * h))

    def dot(self, cx, cy, r, color, alpha=1.0):
        w, h, buf = self.w, self.h, self.buf
        cr, cg, cb = rgb_of(color)
        x0, x1 = max(0, int(cx - r - 1)), min(w - 1, int(cx + r + 1))
        y0, y1 = max(0, int(cy - r - 1)), min(h - 1, int(cy + r + 1))
        for y in range(y0, y1 + 1):
            dy = y + 0.5 - cy
            row = y * w * 3
            for x in range(x0, x1 + 1):
                d = math.sqrt((x + 0.5 - cx) ** 2 + dy * dy)
                cov = r - d + 0.5
                if cov <= 0:
                    continue
                a = (1.0 if cov > 1 else cov) * alpha
                i = row + x * 3
                buf[i] += int((cr - buf[i]) * a)
                buf[i + 1] += int((cg - buf[i + 1]) * a)
                buf[i + 2] += int((cb - buf[i + 2]) * a)

    def png(self):
        raw = b"".join(b"\x00" + bytes(self.buf[y * self.w * 3:(y + 1) * self.w * 3]) for y in range(self.h))

        def chunk(tag, data):
            c = struct.pack(">I", len(data)) + tag + data
            return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", self.w, self.h, 8, 2, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b""))


def wallpaper_png(cfg, key, style=None, size=None):
    p = palette(cfg, key)
    wc = cfg["wallpaper"]
    style = style or wc["style"]
    w, h = parse_size(size or wc["size"])
    s = w / 1920.0
    cv = Canvas(w, h, p["bg"])
    cx, cy = w / 2.0, h / 2.0
    dot = float(wc["dot"]) * s
    acc, fg = p["accent"], p["dot"]
    if wc.get("grid", True) or style == "plain":
        step = 24 * s
        gy = step / 2
        while gy < h:
            gx = step / 2
            while gx < w:
                cv.dot(gx, gy, max(0.8, 1.4 * s), p["grid"])
                gx += step
            gy += step
    if style == "ring":
        n = int(wc["rings"])
        outer, inner = 430 * s, 70 * s
        ops = [1.0, 0.8, 0.55, 0.35, 0.25, 0.2, 0.15, 0.12]
        for i in range(n):
            r = outer if n == 1 else outer - i * (outer - inner) / (n - 1)
            count = max(8, int(round(2 * math.pi * r / (24.1 * s * float(wc["dot"]) / 5.0))))
            for x, y, t in ring_dots(cx, cy, count, r):
                hot = (i == min(1, n - 1) and 0.55 <= t < 0.80) or (i == 0 and 0.02 <= t < 0.06)
                cv.dot(x, y, max(1.0, dot - 0.4 * s * i), acc if hot else fg, 1.0 if hot else ops[i])
        cv.dot(cx, cy, 9 * s, acc)
    elif style == "plain":
        for i in range(10):
            cv.dot(96 * s + i * 24 * s, h - 96 * s, 3.2 * s, fg, 0.5)
        cv.dot(96 * s + 10 * 24 * s, h - 96 * s, 3.8 * s, acc)
    elif style == "wave":
        step = 24 * s
        for row in range(-4, 5):
            y0 = cy + row * step * 1.7
            for c in range(int(w / step) + 1):
                x = c * step
                y = y0 + 22 * s * math.sin(x / (w / (2 * math.pi * 1.5)) + row * 0.6)
                hot = row == 1 and c % 9 == 0
                cv.dot(x, y, max(1.0, dot * (1 - abs(row) * 0.1) * (1.3 if hot else 1.0)), acc if hot else fg,
                       1.0 if hot else max(0.12, 1 - abs(row) * 0.2))
    elif style == "spiral":
        n = 520
        maxr = min(w, h) * 0.46
        c = maxr / math.sqrt(n)
        for i in range(1, n + 1):
            a = i * 2.399963229728653
            rad = c * math.sqrt(i)
            hot = i % 21 == 0
            cv.dot(cx + rad * math.cos(a), cy + rad * math.sin(a),
                   max(1.0, dot * (0.35 + 0.65 * rad / maxr)), acc if hot else fg, 1.0 if hot else 0.85)
    return cv.png()


# --------------------------------------------------------------------------- exports for other OSes / terminals
ANSI_NAMES = ["black", "red", "green", "yellow", "blue", "purple", "cyan", "white"]


def export_windows_terminal(cfg):
    out = {}
    for key in ("dark", "light"):
        p = palette(cfg, key)
        d = {"name": p["label"], "background": p["bg"], "foreground": p["fg"], "cursorColor": p["accent"],
             "selectionBackground": p["accent"]}
        for i, n in enumerate(ANSI_NAMES):
            d[n] = p["ansi"][i]
            d["bright" + n[0].upper() + n[1:]] = p["ansi"][i + 8]
        out[key] = d
    return {"exports/windows-terminal.json": json.dumps({"schemes": [out["dark"], out["light"]]}, indent=2) + "\n"}


def export_alacritty(cfg):
    files = {}
    for key in ("dark", "light"):
        p = palette(cfg, key)
        t = (f"# {p['label']} for Alacritty (import it from alacritty.toml)\n[colors.primary]\n"
             f"background = \"{p['bg']}\"\nforeground = \"{p['fg']}\"\n\n[colors.cursor]\n"
             f"text = \"{p['bg']}\"\ncursor = \"{p['accent']}\"\n\n[colors.selection]\n"
             f"text = \"{p['on_accent']}\"\nbackground = \"{p['accent']}\"\n\n[colors.normal]\n")
        t += "".join(f"{n} = \"{p['ansi'][i]}\"\n" for i, n in enumerate(n.replace("purple", "magenta") for n in ANSI_NAMES))
        t += "\n[colors.bright]\n" + "".join(
            f"{n} = \"{p['ansi'][i + 8]}\"\n" for i, n in enumerate(n.replace("purple", "magenta") for n in ANSI_NAMES))
        files[f"exports/alacritty-{key}.toml"] = t
    return files


def export_iterm(cfg):
    files = {}
    for key in ("dark", "light"):
        p = palette(cfg, key)

        def entry(name, hexc):
            r, g, b = (x / 255.0 for x in rgb_of(hexc))
            return (f"  <key>{name}</key>\n  <dict>\n"
                    f"    <key>Color Space</key><string>sRGB</string>\n"
                    f"    <key>Red Component</key><real>{r:.5f}</real>\n"
                    f"    <key>Green Component</key><real>{g:.5f}</real>\n"
                    f"    <key>Blue Component</key><real>{b:.5f}</real>\n  </dict>\n")
        body = "".join(entry(f"Ansi {i} Color", c) for i, c in enumerate(p["ansi"]))
        body += entry("Background Color", p["bg"]) + entry("Foreground Color", p["fg"])
        body += entry("Cursor Color", p["accent"]) + entry("Selection Color", p["accent"])
        files[f"exports/iterm2-{key}.itermcolors"] = (
            '<?xml version="1.0" encoding="UTF-8"?>\n'
            '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n'
            '<plist version="1.0">\n<dict>\n' + body + "</dict>\n</plist>\n")
    return files


def export_xresources(cfg):
    files = {}
    for key in ("dark", "light"):
        p = palette(cfg, key)
        t = (f"! {p['label']}\n*.background: {p['bg']}\n*.foreground: {p['fg']}\n*.cursorColor: {p['accent']}\n")
        t += "".join(f"*.color{i}: {c}\n" for i, c in enumerate(p["ansi"]))
        files[f"exports/Xresources-{key}"] = t
    return files


def export_vscode(cfg):
    files = {}
    for key in ("dark", "light"):
        p = palette(cfg, key)
        d = {"workbench.colorCustomizations": {
            "editor.background": p["bg"], "editor.foreground": p["fg"],
            "sideBar.background": p["panel"], "activityBar.background": p["panel"],
            "titleBar.activeBackground": p["panel"], "statusBar.background": p["accent"],
            "statusBar.foreground": p["on_accent"], "focusBorder": p["accent"],
            "button.background": p["accent"], "button.foreground": p["on_accent"],
            "terminal.background": p["bg"], "terminal.foreground": p["fg"],
            "terminalCursor.foreground": p["accent"]}}
        files[f"exports/vscode-settings-{key}.json"] = json.dumps(d, indent=2) + "\n"
    return files


EXPORTERS = {
    "windows-terminal": export_windows_terminal, "alacritty": export_alacritty, "iterm2": export_iterm,
    "xresources": export_xresources, "vscode": export_vscode,
}


# --------------------------------------------------------------------------- top level
def layout_js(cfg):
    """Plasma 6 panel script for the top bar and dock described in cfg['layout']."""
    lay = cfg["layout"]

    def panel(var, position, height, items):
        ids = [LAYOUT_WIDGETS[t.strip()] for t in str(items).split(",") if t.strip()]
        lines = [f"var {var} = new Panel();", f'{var}.location = "{position}";', f"{var}.height = {int(height)};",
                 f"trySet({var}, \"floating\", {'true' if lay['floating'] else 'false'});",
                 f'trySet({var}, "lengthMode", "{lay["length"]}");', f'trySet({var}, "alignment", "center");']
        lines.append("[" + ", ".join(f'"{i}"' for i in ids) + f"].forEach(function (id) {{ {var}.addWidget(id); }});")
        return "\n".join(lines) + "\n"

    out = ("// Glyph Lite layout - generated by glyph-lite-customize from [layout] in theme.conf.\n"
           "// Existing panels are left alone; `glyph-lite-layout restore` puts your old setup back.\n"
           "function trySet(obj, key, value) {\n"
           "    try { obj[key] = value; } catch (e) { /* not available on this Plasma version */ }\n}\n\n")
    if lay["bar"]:
        out += panel("bar", lay["bar_position"], lay["bar_height"], lay["bar_items"]) + "\n"
    if lay["dock"]:
        out += panel("dock", lay["dock_position"], lay["dock_height"], lay["dock_items"])
    return {"layout/glyph-layout.js": out}


def text_files(cfg):
    files = {}
    for key in ("dark", "light"):
        for fn in (kde_scheme, konsole, kitty, xfce_terminal, rofi, gtk):
            files.update(fn(cfg, key))
    files.update(fastfetch_logo(cfg))
    files.update(layout_js(cfg))
    return files


def wallpaper_files(cfg, size=None):
    out = {}
    for key, kn in (("dark", "Dark"), ("light", "Light")):
        out[f"assets/wallpapers/GlyphLite-{kn}-ring.png"] = wallpaper_png(cfg, key, "ring", size)
        out[f"assets/wallpapers/GlyphLite-{kn}-plain.png"] = wallpaper_png(cfg, key, "plain", size)
    return out


def main_wallpapers(cfg, size=None):
    """The 'ring' and 'plain' slots follow the configured style: slot ring = chosen style."""
    style = cfg["wallpaper"]["style"]
    out = {}
    for key, kn in (("dark", "Dark"), ("light", "Light")):
        out[f"assets/wallpapers/GlyphLite-{kn}-ring.png"] = wallpaper_png(cfg, key, style if style != "plain" else "ring", size)
        out[f"assets/wallpapers/GlyphLite-{kn}-plain.png"] = wallpaper_png(cfg, key, "plain", size)
    return out


def export_files(cfg, only=None):
    files = {}
    for name, fn in EXPORTERS.items():
        if only is None or name in only:
            files.update(fn(cfg))
    return files


def write_files(files, root):
    paths = []
    for rel, data in files.items():
        path = os.path.join(root, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "wb" if isinstance(data, bytes) else "w", **({} if isinstance(data, bytes) else {"encoding": "utf-8"})) as f:
            f.write(data)
        paths.append(path)
    return paths
