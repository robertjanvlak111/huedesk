# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[semantic versioning](https://semver.org/spec/v2.0.0.html).

## [2.2.1] - 2026-10-28

### Fixed
- The release workflow could not build the archive: `tools/package.sh`
  resolved its output directory after changing into `package/`, so the
  relative path the workflow passes pointed at the wrong place. All three
  invocation forms are now exercised.

## [2.2.0] - 2026-10-28

### Added
- A one-time support message, shown once after 90 days of use and never
  again. It says so on screen. The date of first use is kept in the widget's
  own Plasma config; nothing is sent anywhere and the check is local.
- `tools/package.sh`, which builds the `.plasmoid` archive the KDE Store
  accepts, and a release workflow that attaches it to a GitHub release.
- Ko-fi link in the README and a Sponsor button on the repository.

### Fixed
- Every bundled icon rendered as a black silhouette, because `Kirigami.Icon`
  ignores its `color` when the source is a plain SVG file. On an unlit card
  that measured 1.36:1 against the background, which is to say invisible.
  Icons are now built at runtime with the fill baked in, and measure 5.7:1 or
  better. A test checks this.

## [2.1.0] - 2026-10-27

### Changed
- Brightness is now set by clicking a card at the level you want, or dragging
  across it. Ctrl+scroll nudges by 5%.
- Text colour is derived from the composited background a label sits on rather
  than from the theme, so a pale bulb no longer leaves dark text on a light
  card.

### Fixed
- Dragging a card to a particular percentage was unreliable: the enclosing
  list stole the gesture, and a 9px threshold meant the level jumped to the
  pointer only after the drag had already begun.
- Secondary text now clears WCAG AA 4.5:1 in both themes.

### Added
- A contrast regression test that renders both themes and measures every
  label against its own background.

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
