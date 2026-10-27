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

    print(f"\n{total - failed}/{total} passed")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
