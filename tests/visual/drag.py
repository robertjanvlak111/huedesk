"""Drive a real drag across a room card with synthetic mouse events.

This exists because a brightness drag has a subtle failure mode that is
invisible to a screenshot: if anything writes to the view model while the
gesture runs, the Repeater rebuilds its delegates, the card under the pointer
is destroyed and the mouse grab is lost. Every movement then behaves like a
fresh click.

The test asserts the delegate survives the gesture and that the level tracks
the pointer continuously.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QT_QUICK_BACKEND", "software")

from PySide6.QtCore import QPoint, QUrl, Qt  # noqa: E402
from PySide6.QtGui import QGuiApplication  # noqa: E402
from PySide6.QtQuick import QQuickView  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402
import shiboken6  # noqa: E402

REPO = Path(__file__).resolve().parent.parent.parent


def find(root, name):
    if root.objectName() == name:
        return root
    for child in root.childItems():
        hit = find(child, name)
        if hit is not None:
            return hit
    return None


def run() -> list[str]:
    failures: list[str] = []
    app = QGuiApplication.instance() or QGuiApplication(sys.argv)

    view = QQuickView()
    view.setResizeMode(QQuickView.SizeRootObjectToView)
    view.resize(420, 640)
    view.setInitialProperties({"themeMode": "dark", "openRooms": []})
    view.setSource(QUrl.fromLocalFile(str(REPO / "tools" / "preview.qml")))
    if view.status() == QQuickView.Error:
        return [f"preview failed to load: "
                f"{'; '.join(e.toString() for e in view.errors())}"]
    view.show()
    QTest.qWait(400)

    root = view.rootObject()
    card = find(root, "roomCard")
    if card is None:
        return ["no roomCard delegate found"]

    scene_pos = card.mapToScene(QPoint(0, 0).toPointF())
    x0, y0 = int(scene_pos.x()), int(scene_pos.y())
    w, h = int(card.width()), int(card.height())
    mid_y = y0 + h // 2

    start_level = card.property("level")
    print(f"    card geometry x={x0} y={y0} w={w} h={h} start level={start_level}")

    # Press near the left, then sweep right in small steps.
    QTest.mousePress(view, Qt.LeftButton, Qt.NoModifier, QPoint(x0 + 30, mid_y))
    levels = []
    for frac in (0.25, 0.4, 0.55, 0.7, 0.85):
        QTest.mouseMove(view, QPoint(x0 + int(w * frac), mid_y))
        QTest.qWait(16)
        # A QML-owned delegate has no QObject parent, so liveness has to be
        # checked at the C++ level.
        if not shiboken6.isValid(card):
            failures.append("the card was destroyed mid-drag "
                            "(the model was written to during the gesture)")
            break
        levels.append(card.property("level"))

    QTest.mouseMove(view, QPoint(x0 + int(w * 0.85), mid_y))
    QTest.qWait(16)
    QTest.mouseRelease(view, Qt.LeftButton, Qt.NoModifier,
                       QPoint(x0 + int(w * 0.85), mid_y))
    QTest.qWait(250)

    if not failures:
        if len(levels) < 5:
            failures.append(f"only {len(levels)} of 5 drag steps registered")
        elif levels != sorted(levels):
            failures.append(f"level did not track the pointer: {levels}")
        elif len(set(levels)) < 4:
            failures.append(f"level barely moved across the drag: {levels}")
        elif levels[-1] < 70:
            failures.append(f"dragging to 85% of the card gave {levels[-1]}%")
        elif start_level == levels[0] and len(set(levels)) == 1:
            failures.append("level never changed")

    # The bridge should have been driven, and only through the live setter
    # while the gesture ran.
    mock = None
    for child in root.children():
        if child.metaObject().className().startswith("MockBridge"):
            mock = child
            break
    if mock is not None:
        # QML arrays come back as QJSValue; toVariant() gives plain Python.
        raw = mock.property("calls")
        calls = raw.toVariant() if hasattr(raw, "toVariant") else (raw or [])
        names = [c.get("name") for c in (calls or [])]
        if "setGroupBrightness" not in names:
            failures.append(f"no committing call on release; saw {names}")
        if any(n == "setGroupBrightness" for n in names[:-1]):
            failures.append(f"model-writing call during the drag: {names}")

    view.hide()
    return failures


if __name__ == "__main__":
    problems = run()
    for p in problems:
        print("  FAIL ", p)
    print("  ok    drag tracks the pointer" if not problems else "")
    raise SystemExit(1 if problems else 0)
