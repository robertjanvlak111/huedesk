# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[semantic versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2026-10-27

The widget was redrawn to look like the Hue app, and configuration moved into
a dedicated application.

### Added
- A settings application (`huedesk-settings`) with a live preview of the
  widget, covering theme, font, text size, density, corner rounding, card
  opacity, content toggles, position and bridge address.
- Light / dark / follow-the-desktop theming, independent of the Plasma theme.
- Room cards styled as brightness fill bars; drag across a card to dim it.
- A scrolling scene carousel that marks the scene currently active.
- Zone support alongside rooms.
- A bundled icon set, so the widget looks the same under any icon theme.
- Archivo SemiExpanded (SIL OFL 1.1) bundled as the default font, loaded with
  `FontLoader` so it needs no system installation.
- Unit tests for the colour conversions and the CLIP v2 model, run in Qt's
  JavaScript engine against the shipped `.js` files.
- `tools/render.py`, which renders the widget offscreen for documentation.
- `install.sh` and `uninstall.sh`.

### Changed
- The CLIP v2 join and the colour maths moved out of `HueBridge.qml` into
  `HueModel.js` and `HueColors.js` so they can be tested directly.
- The view no longer reads `Plasmoid.configuration`; `main.qml` passes values
  down, which is what makes the preview and the tests possible.

### Fixed
- Smart plugs no longer show a brightness slider, and a room containing only
  plugs no longer offers brightness.
- A room's expanded state survives a poll. Previously every refresh rebuilt
  the delegates and collapsed the room.
- The scene picker no longer shows the first scene when none is active.
- Polling pauses while a brightness control is being dragged.

## [1.0.0] - 2026-10-27

### Added
- First version: rooms, lights, scenes and brightness over the Hue CLIP v2
  API, with bridge discovery and pairing.
