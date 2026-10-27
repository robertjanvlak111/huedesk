# Contributing

## Running from a checkout

```bash
./install.sh                       # installs and restarts Plasma
python3 tests/run_tests.py         # unit tests
python3 tools/render.py --theme dark --out /tmp/preview.png
```

To run the settings app against a checkout rather than the installed copy:

```bash
HUEDESK_PLASMOID_DIR=$PWD/package python3 settings-app/huedesk_settings.py
```

## Seeing QML errors

Plasma sends QML errors to the journal, not to the terminal. A widget that
loads with no visible output is not necessarily working:

```bash
plasmawindowed com.rvlak.huedesk &
journalctl --user -n 100 | grep plasmawindowed
```

`tools/render.py` is usually faster: it renders the real view offscreen with
mock data and prints QML errors directly.

## Where to put things

Logic that can be written without QML types belongs in
`package/contents/code/*.js`, where the tests can reach it. Anything in a
`.qml` file is only reachable by rendering.

Keep `FullRepresentation` and everything below it free of
`Plasmoid.configuration`. `main.qml` reads the config and passes values down.
That separation is what lets the preview and the tests instantiate the view.

## Two traps worth knowing

**Property shadowing.** Inside a component, `theme: theme` resolves to the
component's *own* `theme` property, not the outer object, and silently binds
null. Give the outer object a distinct id.

**Delegates are rebuilt on every poll.** State kept inside a `RoomCard` is
lost every few seconds. Put it on the view. See
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Tests

Add cases to `tests/js/test_*.js`. The harness gives you `test`, `ok` and
`equal`, plus `HueColors`, `HueModel` and `FIXTURE`
(`tests/fixtures/clipv2.json`). The fixture is synthetic — please do not
replace it with a dump of your own bridge, which would publish your home
layout.

## Before opening a pull request

- `python3 tests/run_tests.py` passes
- The widget loads with no QML errors in the journal
- Screenshots regenerated if the look changed:
  `python3 tools/render.py --theme dark --open r1 --out screenshots/widget-dark.png`
- No bridge key, bridge id, MAC address or personal light names in the diff
