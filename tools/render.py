#!/usr/bin/env python3
"""Render Hue Desk offscreen to a PNG.

Used to produce the README screenshots and to check layout changes without
capturing the desktop. Needs PySide6 and the Plasma QML modules, both of
which come with a normal Plasma 6 install plus python3-pyside6.

    python3 tools/render.py --theme dark --out screenshots/dark.png
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

# Must be set before the Qt classes are imported.
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QT_QUICK_BACKEND", "software")

from PySide6.QtCore import QUrl, QTimer, Qt  # noqa: E402
from PySide6.QtGui import QGuiApplication  # noqa: E402
from PySide6.QtQuick import QQuickView  # noqa: E402

REPO = Path(__file__).resolve().parent.parent


def main() -> int:
    ap = argparse.ArgumentParser(description="Render Hue Desk offscreen.")
    ap.add_argument("--theme", default="dark", choices=["dark", "light"])
    ap.add_argument("--density", default="cosy",
                    choices=["compact", "cosy", "comfortable"])
    ap.add_argument("--font-scale", type=int, default=100)
    ap.add_argument("--font-family", default="")
    ap.add_argument("--radius", type=int, default=14)
    ap.add_argument("--width", type=int, default=420)
    ap.add_argument("--height", type=int, default=640)
    ap.add_argument("--open", default="", help="comma-separated room ids to expand")
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    app = QGuiApplication(sys.argv)
    view = QQuickView()
    view.setResizeMode(QQuickView.SizeRootObjectToView)
    view.resize(args.width, args.height)

    props = {
        "themeMode": args.theme,
        "density": args.density,
        "fontScale": args.font_scale,
        "fontFamily": args.font_family,
        "cornerRadius": args.radius,
        "openRooms": [r for r in args.open.split(",") if r],
    }
    view.setInitialProperties(props)
    view.setSource(QUrl.fromLocalFile(str(REPO / "tools" / "preview.qml")))

    if view.status() == QQuickView.Error:
        for err in view.errors():
            print(err.toString(), file=sys.stderr)
        return 1

    view.show()

    result = {"code": 1}

    def grab() -> None:
        image = view.grabWindow()
        if image.isNull():
            print("grabWindow() returned a null image", file=sys.stderr)
            result["code"] = 1
        else:
            out = Path(args.out)
            out.parent.mkdir(parents=True, exist_ok=True)
            result["code"] = 0 if image.save(str(out)) else 1
            if result["code"] == 0:
                print(f"wrote {out} ({image.width()}x{image.height()})")
        app.quit()

    # One event-loop turn so bindings settle and images load before grabbing.
    QTimer.singleShot(600, grab)
    app.exec()
    return result["code"]


if __name__ == "__main__":
    raise SystemExit(main())
