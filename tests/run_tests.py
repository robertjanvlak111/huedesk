#!/usr/bin/env python3
"""Run the Hue Desk unit tests.

The widget's pure logic lives in plain .js files that QML imports directly.
These run them in Qt's own JavaScript engine (QJSEngine, the same family QML
uses), so the tests exercise the shipped files rather than a reimplementation.

    python3 tests/run_tests.py            # all suites
    python3 tests/run_tests.py colors     # only matching suites
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

try:
    from PySide6.QtCore import QCoreApplication
    from PySide6.QtQml import QJSEngine
except ImportError:
    print("PySide6 is required to run the tests:\n"
          "  Fedora:  sudo dnf install python3-pyside6\n"
          "  pip:     pip install pyside6", file=sys.stderr)
    raise SystemExit(2)

ROOT = Path(__file__).resolve().parent.parent
CODE = ROOT / "package" / "contents" / "code"
TESTS = ROOT / "tests" / "js"
FIXTURE = ROOT / "tests" / "fixtures" / "clipv2.json"

# A tiny xUnit shim. Kept in the runner so the .js suites stay dependency-free.
HARNESS = """
var __results = [];
var __current = null;

function test(name, fn) {
    __current = { name: name, failures: [] };
    try {
        fn();
    } catch (e) {
        __current.failures.push("threw: " + e);
    }
    __results.push(__current);
    __current = null;
}

function ok(value, message) {
    if (!value) {
        __current.failures.push(message || "expected a truthy value");
    }
}

function equal(actual, expected, message) {
    if (actual !== expected) {
        __current.failures.push(
            (message ? message + ": " : "") +
            "expected " + JSON.stringify(expected) +
            " but got " + JSON.stringify(actual));
    }
}
"""


def load_module(engine: QJSEngine, path: Path, name: str) -> None:
    """Evaluate one of the shipped .js files into the engine's globals.

    `.pragma library` is a QML loader directive, not JavaScript, so it is
    stripped. The Node export tail is inert here because `module` is undefined.
    """
    source = path.read_text()
    source = "\n".join(
        line for line in source.splitlines()
        if not line.strip().startswith(".pragma")
    )
    result = engine.evaluate(source, str(path))
    if result.isError():
        raise SystemExit(
            f"{name}: {path.name}:{result.property('lineNumber').toInt()}: "
            f"{result.toString()}")


def main() -> int:
    # QJSEngine needs a Qt application object to exist first.
    app = QCoreApplication.instance() or QCoreApplication(sys.argv)
    _ = app

    patterns = [a.lower() for a in sys.argv[1:]]
    suites = sorted(TESTS.glob("test_*.js"))
    if patterns:
        suites = [s for s in suites if any(p in s.stem.lower() for p in patterns)]
    if not suites:
        print("No matching test suites.", file=sys.stderr)
        return 2

    total = failed = 0

    for suite in suites:
        engine = QJSEngine()
        engine.installExtensions(QJSEngine.Extension.ConsoleExtension)

        load_module(engine, CODE / "HueColors.js", suite.stem)
        load_module(engine, CODE / "HueModel.js", suite.stem)

        # The modules are plain function declarations; expose them under the
        # names the suites use.
        engine.evaluate("""
            var HueColors = { xyToHex: xyToHex, mirekToHex: mirekToHex,
                              stateToHex: stateToHex, hexToXy: hexToXy };
            var HueModel = { buildModel: buildModel, splitBatch: splitBatch };
        """)
        engine.globalObject().setProperty(
            "FIXTURE", engine.evaluate("(" + FIXTURE.read_text() + ")"))
        engine.evaluate(HARNESS)

        result = engine.evaluate(suite.read_text(), str(suite))
        if result.isError():
            print(f"\n  {suite.name}: could not run: {result.toString()}")
            failed += 1
            total += 1
            continue

        results = json.loads(engine.evaluate("JSON.stringify(__results)").toString())
        print(f"\n{suite.stem}")
        for case in results:
            total += 1
            if case["failures"]:
                failed += 1
                print(f"  FAIL  {case['name']}")
                for message in case["failures"]:
                    print(f"          {message}")
            else:
                print(f"  ok    {case['name']}")

    visual_failed = run_contrast_suite(patterns)

    print(f"\n{total - failed}/{total} unit assertions passed")
    return 1 if (failed or visual_failed) else 0


def run_contrast_suite(patterns) -> bool:
    """Render the widget and check text contrast against its own background.

    The card background is whatever colour the lights are, so text colour is
    derived at runtime. This guards the result: every label must clear the
    WCAG AA 4.5:1 bar in both themes.
    """
    if patterns and not any("contrast" in p or "visual" in p for p in patterns):
        return False

    try:
        from PIL import Image  # noqa: F401
    except ImportError:
        print("\ncontrast: skipped (needs Pillow: pip install pillow)")
        return False

    sys.path.insert(0, str(ROOT / "tests"))
    from visual.contrast import measure

    render = ROOT / "tools" / "render.py"
    out_dir = ROOT / ".preview"
    out_dir.mkdir(exist_ok=True)

    print("\ncontrast (WCAG AA, 4.5:1)")
    failed = False
    for theme in ("dark", "light"):
        target = out_dir / f"contrast-{theme}.png"
        proc = subprocess.run(
            [sys.executable, str(render), "--theme", theme, "--open", "r1",
             "--width", "400", "--height", "600", "--out", str(target)],
            capture_output=True, text=True)
        if proc.returncode != 0 or not target.exists():
            print(f"  FAIL  {theme}: could not render ({proc.stderr.strip()[:120]})")
            failed = True
            continue

        worst, rows = measure(target, quiet=True)
        if worst is None:
            print(f"  FAIL  {theme}: no text found in the render")
            failed = True
            continue

        for label, ratio in rows:
            if ratio < 4.5:
                print(f"  FAIL  {theme}: {label} is {ratio:.2f}:1")
                failed = True
        if worst >= 4.5:
            print(f"  ok    {theme}: worst label {worst:.2f}:1")
    return failed


if __name__ == "__main__":
    raise SystemExit(main())
