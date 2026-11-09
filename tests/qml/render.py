#!/usr/bin/env python3
"""Render every Glyph Lite widget offscreen with stubbed KDE modules.

Checks that each QML file loads without errors and that drawing code runs, and
writes PNGs to tests/qml/out/. Needs: pip install pyside6-essentials pillow
"""
import os, re, shutil, sys, tempfile
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QT_QUICK_BACKEND", "software")
from PySide6.QtCore import QObject, QTimer, QUrl, Qt, QMetaObject, Q_ARG
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlComponent, QQmlEngine
from PySide6.QtQuick import QQuickView

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(HERE, "out")
os.makedirs(OUT, exist_ok=True)

CASES = {  # id: (size, sample data fed to parse())
    "org.glyphlite.dotclock":    ((360, 190), None),
    "org.glyphlite.dotmeters":   ((420, 190), "1000 2000\n8000000 2000000\n 37%"),
    "org.glyphlite.dotcalendar": ((300, 270), None),
    "org.glyphlite.dotnetwork":  ((340, 120), "5000000 1000000"),
    "org.glyphlite.dotbattery":  ((200, 200), "64 Discharging"),
    "org.glyphlite.dotmedia":    ((340, 140), "Playing|Nothing Ear|Dot Matrix Dreams"),
    "org.glyphlite.island":      ((200, 36),  "1000 2000\n8000000 2000000\n 37%"),
}
FULL_ISLAND = ("org.glyphlite.island-popup", (380, 300))

CFG_STUB = "({ use24h: true, showDate: true, dateStyle: 0, showCpuDot: true, showBorder: true, weekStart: 0 })"

def check_config_pages(app, tmp):
    """Load every configGeneral.qml / config.qml with stubbed KDE modules."""
    bad = []
    for pid in sorted(os.listdir(os.path.join(ROOT, "plasmoids"))):
        ui = os.path.join(ROOT, "plasmoids", pid, "contents")
        for rel in ("ui/configGeneral.qml", "config/config.qml"):
            src = os.path.join(ui, rel)
            if not os.path.exists(src):
                continue
            text = open(src).read()
            text = re.sub(r"Kirigami\.FormData\.label:\s*(?:i18n\()?\"[^\"]*\"\)?\s*;?", "", text)
            text = text.replace("i18n(", "qsTr(")
            dst = os.path.join(tmp, pid + "-" + os.path.basename(src))
            open(dst, "w").write(text)
            eng = QQmlEngine()
            eng.addImportPath(os.path.join(HERE, "stubs"))
            comp = QQmlComponent(eng, QUrl.fromLocalFile(dst))
            obj = comp.create()
            errs = [e.toString() for e in comp.errors()]
            if obj is None and not errs:
                errs = ["component could not be created"]
            print(("FAIL " if errs else "ok   ") + pid + "/" + rel)
            if errs:
                bad += errs
                [print("   ", e) for e in errs]
    return bad

def prepare(pid, tmp):
    src = os.path.join(ROOT, "plasmoids", pid, "contents", "ui")
    dst = os.path.join(tmp, pid)
    shutil.copytree(src, dst)
    p = os.path.join(dst, "main.qml")
    for name in os.listdir(dst):
        if name.endswith(".qml"):
            fp = os.path.join(dst, name)
            lines = [l for l in open(fp).read().splitlines() if "Plasmoid.backgroundHints" not in l]
            text = "\n".join(lines) + "\n"
            text = text.replace("target: Plasmoid.configuration", "target: null")
            text = text.replace("Plasmoid.configuration", CFG_STUB)
            open(fp, "w").write(text)
    return p

def main():
    app = QGuiApplication(sys.argv)
    failures = []
    jobs = [(pid, size, data, False) for pid, (size, data) in CASES.items()]
    jobs.append(("org.glyphlite.island", FULL_ISLAND[1], "1000 2000\n8000000 2000000\n 37%", True))
    tmp = tempfile.mkdtemp()
    for pid, (w, h), data, popup in jobs:
        path = prepare(pid, tmp) if not os.path.exists(os.path.join(tmp, pid)) else os.path.join(tmp, pid, "main.qml")
        view = QQuickView()
        view.engine().addImportPath(os.path.join(HERE, "stubs"))
        view.setColor("#0A0A0C")
        view.setResizeMode(QQuickView.SizeRootObjectToView)
        view.resize(w, h)
        view.setSource(QUrl.fromLocalFile(path))
        errs = [e.toString() for e in view.errors()]
        root = view.rootObject()
        if errs or root is None:
            failures.append((pid, errs or ["no root object"]))
            print("FAIL", pid); [print("   ", e) for e in errs]
            continue
        if popup:
            root.setProperty("preferredRepresentation", root.property("fullRepresentation"))
        root.setProperty("width", w); root.setProperty("height", h)
        if data is not None and root.metaObject().indexOfMethod("parse(QVariant)") >= 0:
            # parse twice so rate/cpu deltas have a baseline
            QMetaObject.invokeMethod(root, "parse", Qt.DirectConnection, Q_ARG("QVariant", data))
            if pid in ("org.glyphlite.dotmeters", "org.glyphlite.island"):
                QMetaObject.invokeMethod(root, "parse", Qt.DirectConnection, Q_ARG("QVariant", "1200 4000\n8000000 2000000\n 37%"))
            if pid == "org.glyphlite.dotnetwork":
                QMetaObject.invokeMethod(root, "parse", Qt.DirectConnection, Q_ARG("QVariant", "5004096 1000300"))
        view.show()
        name = pid.split(".")[-1] + ("-popup" if popup else "")
        def grab(v=view, n=name):
            v.grabWindow().save(os.path.join(OUT, n + ".png"))
            v.hide()
            loop.quit()
        from PySide6.QtCore import QEventLoop
        loop = QEventLoop()
        QTimer.singleShot(700, grab)
        loop.exec()
        print("ok  ", name)
    cfg_bad = check_config_pages(app, tmp)
    if failures or cfg_bad:
        sys.exit(1)

main()
