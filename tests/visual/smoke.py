"""Instantiate every UI component and fail on any QML error.

The renderer only draws FullRepresentation. A broken binding anywhere else -
the panel's compact view, the pairing panel, the support message - would not
be caught by it, and the widget fails to load entirely when that happens.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QT_QUICK_BACKEND", "software")

from PySide6.QtCore import QUrl, QTimer  # noqa: E402
from PySide6.QtGui import QGuiApplication  # noqa: E402
from PySide6.QtQuick import QQuickView  # noqa: E402

REPO = Path(__file__).resolve().parent.parent.parent


def run() -> list[str]:
    app = QGuiApplication.instance() or QGuiApplication(sys.argv)
    view = QQuickView()
    view.resize(400, 700)
    view.setSource(QUrl.fromLocalFile(str(REPO / "tools" / "smoke.qml")))

    if view.status() == QQuickView.Error:
        return [e.toString() for e in view.errors()]

    view.show()

    problems: list[str] = []

    def collect() -> None:
        root = view.rootObject()
        if root is None:
            problems.append("smoke.qml produced no root object")
        else:
            raw = root.property("problems")
            found = raw.toVariant() if hasattr(raw, "toVariant") else (raw or [])
            problems.extend(found or [])
        app.quit()

    QTimer.singleShot(1200, collect)
    app.exec()
    view.hide()
    return problems


if __name__ == "__main__":
    found = run()
    for p in found:
        print("  FAIL ", p)
    if not found:
        print("  ok    every component instantiates")
    raise SystemExit(1 if found else 0)
