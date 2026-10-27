#!/usr/bin/env python3
"""Hue Desk Settings - a desktop app for configuring the Hue Desk widget.

Settings are written straight into the running widget through Plasma's
scripting D-Bus interface, so changes apply immediately without restarting
anything. Position is the one exception: Plasma stores applet geometry in a
containment key that the shell only re-reads at start-up, so moving the widget
asks for a shell restart.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

# --screenshot renders the window offscreen and exits, so documentation images
# can be produced without capturing anyone's desktop. The platform plugin must
# be chosen before Qt is imported, hence the argv peek up here.
_SCREENSHOT = ""
if "--screenshot" in sys.argv:
    _i = sys.argv.index("--screenshot")
    _SCREENSHOT = sys.argv[_i + 1] if _i + 1 < len(sys.argv) else ""
    del sys.argv[_i:_i + 2]
    os.environ["QT_QPA_PLATFORM"] = "offscreen"
    os.environ["QT_QUICK_BACKEND"] = "software"

from PySide6.QtCore import (Property, QObject, QUrl, Signal, Slot)
from PySide6.QtGui import QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuickControls2 import QQuickStyle

APPLET_ID = "com.rvlak.huedesk"
APP_DIR = Path(__file__).resolve().parent
# Where install.sh puts the plasmoid; overridable for running from a checkout.
PLASMOID_DIR = Path(
    os.environ.get(
        "HUEDESK_PLASMOID_DIR",
        Path.home() / ".local/share/plasma/plasmoids" / APPLET_ID,
    )
)

APPEARANCE_KEYS = {
    "themeMode": str, "fontFamily": str, "fontScale": int, "density": str,
    "cornerRadius": int, "cardOpacity": int,
}
CONTENT_KEYS = {
    "showHeader": bool, "showLights": bool, "showScenes": bool,
    "showZones": bool, "accentTint": bool,
}
BRIDGE_KEYS = {"bridgeIp": str, "appKey": str, "pollInterval": int}
ALL_KEYS = {**APPEARANCE_KEYS, **CONTENT_KEYS, **BRIDGE_KEYS}

DEFAULTS = {
    "themeMode": "auto", "fontFamily": "", "fontScale": 100, "density": "cosy",
    "cornerRadius": 14, "cardOpacity": 100, "showHeader": True,
    "showLights": True, "showScenes": True, "showZones": True,
    "accentTint": True, "bridgeIp": "", "appKey": "", "pollInterval": 10,
}


class PlasmaError(RuntimeError):
    pass


def run_script(js: str, timeout: int = 20) -> str:
    """Evaluate a snippet in plasmashell's scripting engine."""
    try:
        proc = subprocess.run(
            ["gdbus", "call", "--session",
             "--dest", "org.kde.plasmashell",
             "--object-path", "/PlasmaShell",
             "--method", "org.kde.PlasmaShell.evaluateScript", js],
            capture_output=True, text=True, timeout=timeout, check=False,
        )
    except FileNotFoundError as exc:
        raise PlasmaError("gdbus is not installed.") from exc
    except subprocess.TimeoutExpired as exc:
        raise PlasmaError("plasmashell did not respond.") from exc

    if proc.returncode != 0:
        raise PlasmaError((proc.stderr or "plasmashell refused the call").strip())

    out = proc.stdout.strip()
    # gdbus wraps the result as ('...',)
    if out.startswith("('") and out.endswith("',)"):
        out = out[2:-3]
    return out.replace("\\n", "\n").replace("\\'", "'")


class Backend(QObject):
    """Bridges QML to plasmashell and to the widget's configuration."""

    settingsChanged = Signal()
    statusChanged = Signal()
    widgetsChanged = Signal()

    def __init__(self) -> None:
        super().__init__()
        self._settings = dict(DEFAULTS)
        self._status = ""
        self._widgets: list[dict] = []
        self._geometry = {"x": 0, "y": 0, "width": 0, "height": 0}
        self.reload()

    # -- properties exposed to QML ---------------------------------------
    def _get_settings(self) -> "dict":
        return self._settings

    settings = Property("QVariant", _get_settings, notify=settingsChanged)

    def _get_status(self) -> str:
        return self._status

    status = Property(str, _get_status, notify=statusChanged)

    def _get_widgets(self) -> "list":
        return self._widgets

    widgets = Property("QVariant", _get_widgets, notify=widgetsChanged)

    def _get_geometry(self) -> "dict":
        return self._geometry

    geometry = Property("QVariant", _get_geometry, notify=widgetsChanged)

    def _get_ui_path(self) -> str:
        return QUrl.fromLocalFile(str(PLASMOID_DIR / "contents" / "ui")).toString()

    uiPath = Property(str, _get_ui_path, constant=True)

    def _get_app_path(self) -> str:
        return QUrl.fromLocalFile(str(APP_DIR)).toString()

    appPath = Property(str, _get_app_path, constant=True)

    def _get_installed(self) -> bool:
        return (PLASMOID_DIR / "metadata.json").exists()

    installed = Property(bool, _get_installed, constant=True)

    def _set_status(self, text: str) -> None:
        self._status = text
        self.statusChanged.emit()

    # -- plasma interaction ----------------------------------------------
    @Slot()
    def reload(self) -> None:
        """Read the widget list and the first widget's configuration."""
        keys = list(ALL_KEYS)
        js = """
        var out = [];
        var ds = desktops();
        for (var i = 0; i < ds.length; i++) {
            var ws = ds[i].widgets();
            for (var j = 0; j < ws.length; j++) {
                if (ws[j].type !== "%s") { continue; }
                ws[j].currentConfigGroup = ["General"];
                var cfg = {};
                var keys = %s;
                for (var k = 0; k < keys.length; k++) {
                    cfg[keys[k]] = ws[j].readConfig(keys[k]);
                }
                var g = ws[j].geometry;
                out.push({ id: ws[j].id, desktop: i, screen: ds[i].screen,
                           config: cfg,
                           geometry: { x: g.x, y: g.y, width: g.width, height: g.height } });
            }
        }
        print(JSON.stringify(out));
        """ % (APPLET_ID, json.dumps(keys))

        try:
            raw = run_script(js)
        except PlasmaError as exc:
            self._set_status(str(exc))
            return

        try:
            found = json.loads(raw)
        except json.JSONDecodeError:
            self._set_status("Could not read the widget configuration.")
            return

        self._widgets = found
        if not found:
            self._set_status("Hue Desk is not on your desktop yet.")
            self.widgetsChanged.emit()
            return

        cfg = found[0].get("config", {})
        merged = dict(DEFAULTS)
        for key, kind in ALL_KEYS.items():
            value = cfg.get(key)
            if value in (None, ""):
                # An unset key reads back empty; keep the documented default.
                if key not in ("fontFamily", "bridgeIp", "appKey"):
                    continue
            try:
                if kind is bool:
                    merged[key] = value in (True, "true", "True", 1, "1")
                elif kind is int:
                    merged[key] = int(value)
                else:
                    merged[key] = str(value)
            except (TypeError, ValueError):
                pass

        self._settings = merged
        self._geometry = found[0].get("geometry", self._geometry)
        self._set_status("")
        self.settingsChanged.emit()
        self.widgetsChanged.emit()

    @Slot(str, "QVariant")
    def setValue(self, key: str, value) -> None:
        """Write one key into every Hue Desk instance and apply it live."""
        if key not in ALL_KEYS:
            self._set_status(f"Unknown setting: {key}")
            return

        kind = ALL_KEYS[key]
        if kind is bool:
            value = bool(value)
            literal = "true" if value else "false"
        elif kind is int:
            value = int(value)
            literal = str(value)
        else:
            value = str(value)
            literal = json.dumps(value)

        if self._settings.get(key) == value:
            return
        self._settings[key] = value
        self.settingsChanged.emit()

        js = """
        var n = 0;
        var ds = desktops();
        for (var i = 0; i < ds.length; i++) {
            var ws = ds[i].widgets();
            for (var j = 0; j < ws.length; j++) {
                if (ws[j].type !== "%s") { continue; }
                ws[j].currentConfigGroup = ["General"];
                ws[j].writeConfig("%s", %s);
                ws[j].reloadConfig();
                n++;
            }
        }
        print(n);
        """ % (APPLET_ID, key, literal)

        try:
            count = run_script(js).strip()
        except PlasmaError as exc:
            self._set_status(str(exc))
            return
        self._set_status("" if count not in ("0", "") else
                         "Hue Desk is not on your desktop yet.")

    @Slot()
    def addToDesktop(self) -> None:
        js = """
        var d = desktops()[0];
        var w = d.addWidget("%s");
        print(w.id);
        """ % APPLET_ID
        try:
            run_script(js)
        except PlasmaError as exc:
            self._set_status(str(exc))
            return
        self._set_status("Added Hue Desk to your desktop.")
        self.reload()

    @Slot(int, int, int, int, result=bool)
    def applyGeometry(self, x: int, y: int, width: int, height: int) -> bool:
        """Position and size the widget.

        Plasma keeps desktop applet geometry in the containment's
        ItemGeometries key and only reads it at start-up; the scripting
        geometry setter is a no-op. So this rewrites the config with the shell
        stopped, then starts it again.
        """
        if not self._widgets:
            self._set_status("Hue Desk is not on your desktop yet.")
            return False

        applet_id = self._widgets[0]["id"]
        cfg = Path.home() / ".config/plasma-org.kde.plasma.desktop-appletsrc"
        if not cfg.exists():
            self._set_status("Could not find the Plasma applet configuration.")
            return False

        subprocess.run(["kquitapp6", "plasmashell"], capture_output=True, check=False)
        # Give the shell a moment to write out and exit before editing.
        for _ in range(40):
            if subprocess.run(["pgrep", "-x", "plasmashell"],
                              capture_output=True).returncode != 0:
                break
            QGuiApplication.processEvents()
            subprocess.run(["sleep", "0.25"], check=False)

        try:
            self._rewrite_geometry(cfg, applet_id, x, y, width, height)
        finally:
            subprocess.Popen(["kstart", "plasmashell"],
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

        self._set_status("Position applied; the desktop shell restarted.")
        return True

    @staticmethod
    def _rewrite_geometry(cfg: Path, applet_id: int,
                          x: int, y: int, width: int, height: int) -> None:
        """Replace this applet's entry in every ItemGeometries* key."""
        lines = cfg.read_text().splitlines()
        token = f"Applet-{applet_id}:"
        out = []
        for line in lines:
            if "=" in line and line.split("=", 1)[0].startswith("ItemGeometries"):
                key, value = line.split("=", 1)
                entries = [e for e in value.split(";") if e]
                entries = [e for e in entries if not e.startswith(token)]
                entries.append(f"{token}{x},{y},{width},{height},0")
                line = key + "=" + ";".join(entries) + ";"
            out.append(line)
        cfg.write_text("\n".join(out) + "\n")

    # Shown as the first entry of the font picker and meaning "use the font
    # bundled with the widget"; stored as an empty string.
    DEFAULT_FONT_LABEL = "Hue Desk default (Archivo SemiExpanded)"

    @Slot(result="QVariant")
    def fontFamilies(self) -> list:
        from PySide6.QtGui import QFontDatabase
        return [self.DEFAULT_FONT_LABEL] + sorted(set(QFontDatabase.families()))

    @Slot(result=str)
    def defaultFontLabel(self) -> str:
        return self.DEFAULT_FONT_LABEL

    @Slot()
    def openWidgetConfig(self) -> None:
        """Fall back to Plasma's own dialog for anything not covered here."""
        self._set_status("Right-click the widget and choose Configure Hue Desk.")


def main() -> int:
    # Without an explicit style the Basic one is used, which ignores the
    # desktop palette and renders dark-on-dark under a dark theme.
    preferred = os.environ.get("HUEDESK_STYLE")
    if not preferred:
        # PySide does not expose availableStyles(), so look for the KDE style
        # in Qt's QML import path and fall back to one that always ships.
        from PySide6.QtCore import QLibraryInfo
        qml_root = Path(QLibraryInfo.path(QLibraryInfo.LibraryPath.QmlImportsPath))
        preferred = ("org.kde.desktop"
                     if (qml_root / "org" / "kde" / "desktop").is_dir()
                     else "Fusion")
    QQuickStyle.setStyle(preferred)

    app = QGuiApplication(sys.argv)
    app.setApplicationName("Hue Desk Settings")
    app.setOrganizationName("huedesk")
    icon = PLASMOID_DIR / "contents" / "icons" / "bulb.svg"
    if icon.exists():
        app.setWindowIcon(QIcon(str(icon)))

    backend = Backend()
    engine = QQmlApplicationEngine()
    engine.rootContext().setContextProperty("backend", backend)
    engine.load(QUrl.fromLocalFile(str(APP_DIR / "ui" / "Main.qml")))
    if not engine.rootObjects():
        print("Failed to load the settings interface.", file=sys.stderr)
        return 1

    if _SCREENSHOT:
        from PySide6.QtCore import QTimer
        # PySide hands back the root ApplicationWindow typed as a plain
        # QWindow, which exposes neither grabWindow() nor contentItem(), so it
        # is re-wrapped as the QQuickWindow it actually is.
        import shiboken6
        from PySide6.QtQuick import QQuickWindow

        raw = engine.rootObjects()[0]
        window = shiboken6.wrapInstance(
            shiboken6.getCppPointer(raw)[0], QQuickWindow)

        # grabToImage() is asynchronous, so the result must outlive this scope.
        holder: dict = {}

        def grab(attempt: int = 0) -> None:
            item = window.contentItem()
            result = item.grabToImage() if item is not None else None
            if result is None:
                if attempt < 10:
                    QTimer.singleShot(300, lambda: grab(attempt + 1))
                else:
                    print("could not grab the window", file=sys.stderr)
                    app.quit()
                return

            holder["result"] = result

            def done() -> None:
                out = Path(_SCREENSHOT)
                out.parent.mkdir(parents=True, exist_ok=True)
                if result.saveToFile(str(out)):
                    image = result.image()
                    print(f"wrote {out} ({image.width()}x{image.height()})")
                else:
                    print("could not save screenshot", file=sys.stderr)
                app.quit()

            result.ready.connect(done)

        QTimer.singleShot(1500, grab)

    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())
