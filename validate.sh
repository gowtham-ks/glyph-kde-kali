#!/usr/bin/env bash
# Static checks for Glyph Lite. Runs anywhere with bash + python3; uses shellcheck,
# qmllint and desktop-file-validate when they are installed.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
fail=0
ok()  { printf '  ok    %s\n' "$*"; }
bad() { printf '  FAIL  %s\n' "$*"; fail=1; }

echo "shell syntax"
for f in install.sh uninstall.sh setup.sh validate.sh lib/common.sh bin/glyph-lite-mode bin/glyph-lite-layout tools/package.sh; do
  if bash -n "$f" 2>/dev/null; then ok "$f"; else bad "$f"; fi
done
if command -v shellcheck >/dev/null; then
  shellcheck -x -S warning install.sh uninstall.sh lib/common.sh bin/glyph-lite-mode && ok shellcheck || bad shellcheck
fi

echo "python"
for f in bin/glyph-lite-customize lib/glyphgen.py tools/make_assets.py tests/test_glyphgen.py tests/qml/render.py; do
  if python3 -m py_compile "$f" 2>/dev/null; then ok "$f"; else bad "$f"; fi
done
if python3 tests/test_glyphgen.py >/tmp/glt-unit.log 2>&1; then ok "unit tests"; else bad "unit tests (see /tmp/glt-unit.log)"; fi

echo "data files"
python3 - <<'PY' || fail=1
import configparser, glob, json, os, re, sys, xml.dom.minidom as md
bad = 0
def fail(msg):
    global bad; bad = 1; print("  FAIL ", msg)

for f in glob.glob("plasmoids/*/metadata.json"):
    d = json.load(open(f)); pid = d["KPlugin"]["Id"]
    if pid != os.path.basename(os.path.dirname(f)): fail(f"{f}: Id {pid} != directory")
    if not os.path.exists(os.path.join(os.path.dirname(f), "contents/ui/main.qml")): fail(f"{f}: no main.qml")
import xml.etree.ElementTree as ET
for d in glob.glob("plasmoids/*/"):
    xmlp = os.path.join(d, "contents/config/main.xml")
    used = set()
    for q in glob.glob(os.path.join(d, "contents/ui/*.qml")):
        used |= set(re.findall(r"Plasmoid\.configuration\.([A-Za-z0-9_]+)", open(q).read()))
    if os.path.exists(xmlp):
        ns = {"k": "http://www.kde.org/standards/kcfg/1.0"}
        names = {e.get("name") for e in ET.parse(xmlp).getroot().iter("{http://www.kde.org/standards/kcfg/1.0}entry")}
        if used - names: fail(f"{d}: QML uses config keys missing from main.xml: {sorted(used - names)}")
        page = os.path.join(d, "contents/ui/configGeneral.qml")
        if os.path.exists(page):
            cfgs = set(re.findall(r"cfg_([A-Za-z0-9_]+)", open(page).read()))
            if names - cfgs: fail(f"{d}: settings page lacks controls for {sorted(names - cfgs)}")
    elif used:
        fail(f"{d}: uses Plasmoid.configuration but has no contents/config/main.xml")
print("  ok    plasmoid metadata and settings")

for f in glob.glob("assets/wallpapers/*.svg"):
    try: md.parse(f)
    except Exception as e: fail(f"{f}: {e}")
print("  ok    svg")

need = {"ColorEffects:Disabled","ColorEffects:Inactive","Colors:Button","Colors:Complementary","Colors:Header",
        "Colors:Selection","Colors:Tooltip","Colors:View","Colors:Window","General","WM"}
for f in glob.glob("configs/color-schemes/*.colors"):
    c = configparser.ConfigParser(interpolation=None, strict=True); c.optionxform = str; c.read(f)
    miss = need - set(c.sections())
    if miss: fail(f"{f}: missing {sorted(miss)}")
print("  ok    color schemes")

for f in glob.glob("configs/rofi/*.rasi"):
    t = open(f).read()
    if t.count("{") != t.count("}"): fail(f"{f}: unbalanced braces")
for f in glob.glob("plasmoids/*/contents/**/*.qml", recursive=True):
    t = re.sub(r'"(?:\\.|[^"\\])*"', '""', open(f).read())
    if t.count("{") != t.count("}") or t.count("(") != t.count(")"): fail(f"{f}: unbalanced brackets")
print("  ok    rasi / qml brackets")

t = open("configs/fastfetch/config.jsonc.in").read().replace("@CONF@", "/x")
try: json.loads(t)
except Exception as e: fail(f"fastfetch config: {e}")
print("  ok    fastfetch config")

for f in glob.glob("configs/applications/*.desktop"):
    t = open(f).read()
    for k in ("Type=", "Name=", "Exec="):
        if k not in t: fail(f"{f}: missing {k}")
    if "~" in t: fail(f"{f}: '~' is not expanded in Exec")
print("  ok    desktop entry")
sys.exit(bad)
PY

if python3 -c "import PySide6" 2>/dev/null; then
  python3 tests/qml/render.py >/dev/null 2>&1 && ok "qml render test (offscreen)" || bad "qml render test"
fi
if command -v qmllint >/dev/null; then
  for f in plasmoids/*/contents/ui/*.qml; do qmllint "$f" >/dev/null 2>&1 && ok "qmllint $f" || bad "qmllint $f"; done
fi
if command -v desktop-file-validate >/dev/null; then
  desktop-file-validate configs/applications/*.desktop && ok desktop-file-validate || bad desktop-file-validate
fi

[ "$fail" = 0 ] && echo "ALL CHECKS PASSED" || echo "SOME CHECKS FAILED"
exit "$fail"
