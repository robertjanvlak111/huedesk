# Architecture

## Why curl, and not XMLHttpRequest

Hue bridges serve the CLIP v2 API over HTTPS with a **self-signed**
certificate. QML's `XMLHttpRequest` has no way to relax certificate
verification, so every v2 call would fail. Hue Desk therefore shells out to
`curl` through Plasma's `executable` data engine
(`org.kde.plasma.plasma5support`).

The older v1 API is reachable over plain HTTP and would avoid this, but
Signify has said v1 [will be blocked once every bridge carries a signed
certificate](https://developers.meethue.com/new-hue-api/), so the widget is
built on v2 and only touches v1 for pairing — the one thing v2 cannot do.

### Batching

The data engine keys each request by its command string, so two identical
concurrent calls would collide. `HueBridge._run()` prefixes every command with
a throwaway `HUEREQ=<n>` variable to keep them distinct.

A poll is a single `curl` invocation with five URLs and
`-w '\n__HSPLIT__\n'`, which writes that separator after each transfer. One
process per poll instead of five:

```
curl -sk -m 8 -H 'hue-application-key: …' -w '\n__HSPLIT__\n' \
  …/resource/room …/resource/zone …/resource/grouped_light \
  …/resource/light …/resource/scene
```

`HueModel.splitBatch()` splits the result and returns `null` for any chunk
that is missing, malformed, or an error body rather than a `data` array.

## The room-to-light join

This is the part of CLIP v2 that is easy to get wrong.

- A **room** lists its members as **device** ids.
- A **light** points back at its device through `owner.rid`.
- A **zone** lists **light** ids directly.

So rooms are joined by indexing lights by `owner.rid`, while zones match on
the light id itself. `HueModel._buildGroup()` handles both, and drops any
group that ends up with no members or has no `grouped_light` service.

## Why the logic is in .js files

`HueColors.js` and `HueModel.js` are plain JavaScript with no QML types. QML
imports them directly, and `tests/run_tests.py` loads the very same files into
Qt's `QJSEngine`. The tests exercise shipped code rather than a copy.

Each file ends with a `module.exports` tail guarded by `typeof module`, which
is inert under QML and lets Node run them too.

## State that must outlive a poll

Every poll replaces `groups`, `lights` and `scenes` with new arrays. A
`Repeater` bound to a JavaScript array destroys and rebuilds its delegates
when that array changes, so **anything stored in a delegate is lost every few
seconds**. Two consequences shaped the design:

- Which rooms are expanded lives in `FullRepresentation.expandedIds`, not in
  `RoomCard`.
- `ComboBox` resets its own `currentIndex` when its model is replaced, which
  is why the scene picker re-applies the active index instead of relying on a
  binding.

While a brightness control is being dragged, `HueBridge.suspended` is raised
and `refresh()` returns early, so a poll cannot tear the delegate out from
under the gesture.

## Optimistic updates

Dragging a card calls `setGroupBrightness(id, value, true)`, which updates the
view model only. The real request goes out on release, and again through a
180 ms timer during long drags. After any command a 900 ms timer reconciles
against the bridge.

## Theming

`Theme.qml` resolves every colour, metric and font from the widget's own
configuration rather than from Kirigami, which is what allows the widget to be
dark while the desktop is light. `auto` falls back to the luminance of
`Kirigami.Theme.backgroundColor`.

The icons in `package/contents/icons/` are bundled deliberately: Breeze has no
`lightbulb-symbolic`, `sofa-symbolic` or `bed-symbolic`, and a widget that
other people install should not depend on their icon theme.

## The view has no Plasmoid dependency

`FullRepresentation` and everything under it take plain properties.
`main.qml` is the only file that reads `Plasmoid.configuration`. That is what
lets `tools/render.py` and the settings app's live preview instantiate the
real widget outside plasmashell.

## The settings app

`settings-app/huedesk_settings.py` writes configuration into the running
widget through Plasma's scripting D-Bus interface:

```js
widget.currentConfigGroup = ["General"];
widget.writeConfig(key, value);
widget.reloadConfig();
```

`reloadConfig()` makes the live widget pick the value up immediately.

**Position is the exception.** Plasma stores desktop applet geometry in the
containment's `ItemGeometries-<resolution>` key and only reads it at start-up;
the scripting `geometry` setter silently does nothing, and `Qt.rect` is not
even defined in that engine. Setting a position therefore stops plasmashell,
rewrites the key, and starts it again.
