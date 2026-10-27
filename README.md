# Hue Desk

A Philips Hue widget that lives on your KDE Plasma desktop, styled after the
Hue app rather than a settings dialog. Rooms are brightness bars you drag,
scenes sit in a carousel, and everything is always visible — no tray icon, no
pop-up.

![Hue Desk in dark and light themes](screenshots/widget-dark.png)

| Dark | Light | Compact |
| --- | --- | --- |
| ![Dark](screenshots/widget-dark.png) | ![Light](screenshots/widget-light.png) | ![Compact](screenshots/widget-compact.png) |

It talks to your bridge directly over your own network. Nothing leaves your
LAN, and there is no account, cloud service or telemetry.

## Install

**You need:** KDE Plasma 6, `curl`, and — for the settings app — PySide6.

```bash
git clone https://github.com/rvlak/huedesk.git
cd huedesk
./install.sh
```

The installer checks your system, copies the widget into
`~/.local/share/plasma/plasmoids/`, installs the settings app, and restarts
Plasma so the widget shows up. It needs no root and writes only inside your
home directory.

If PySide6 is missing, the widget still installs; only the settings app is
skipped. To add it:

| Distribution | Command |
| --- | --- |
| Fedora, Bazzite, Nobara | `sudo dnf install python3-pyside6` |
| Arch, EndeavourOS | `sudo pacman -S pyside6` |
| Debian, Ubuntu, KDE neon | `sudo apt install python3-pyside6` |
| openSUSE | `sudo zypper install python3-pyside6` |

### Then

1. Right-click your desktop → **Add Widgets…**
2. Search for **Hue Desk** and drag it onto the desktop
3. Press the round button on your Hue bridge, then choose **Pair** in the widget

Pairing is a one-time step. The bridge only hands out a key while that button
is pressed, which is how it knows you are physically there.

## Settings

Launch **Hue Desk Settings** from your application menu, or run
`huedesk-settings`. Changes apply to the running widget as you make them, and
the preview on the right is the real widget, loaded from the installed files.

![Settings app](screenshots/settings.png)

| | |
| --- | --- |
| **Theme** | Light, dark, or follow the desktop |
| **Font and text size** | Archivo SemiExpanded by default, or any installed family, 75–150% |
| **Density** | Compact, cosy or comfortable spacing |
| **Corner rounding, card opacity** | Match your desktop's look |
| **Content** | Show or hide the header, individual lights, scenes, zones |
| **Position and size** | Exact coordinates, or just drag the widget |
| **Bridge** | Address and how often to poll |

Everything is also in Plasma's own dialog: right-click the widget →
**Configure Hue Desk**.

> Moving the widget from the settings app restarts Plasma's desktop shell,
> because Plasma only reads widget geometry at start-up. Your open windows are
> unaffected. Dragging the widget on the desktop avoids the restart.

## How it works

Hue Desk uses the bridge's **CLIP v2** API over HTTPS. Bridges use a
self-signed certificate, which QML's `XMLHttpRequest` rejects outright, so
requests are made with `curl` through Plasma's executable data engine. One
batched call per poll fetches rooms, zones, grouped lights, lights and scenes.

Pairing is the single exception: it uses the older v1 endpoint over plain
HTTP, which is the only way a bridge will issue an application key.

```
package/contents/
  code/HueBridge.qml    transport, pairing, commands
  code/HueModel.js      CLIP v2 resources -> view model   (pure, tested)
  code/HueColors.js     xy / mirek -> RGB                 (pure, tested)
  ui/Theme.qml          every colour, metric and font
  ui/RoomCard.qml       a room as a brightness bar
```

More detail in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Tests

```bash
python3 tests/run_tests.py
```

The pure logic lives in plain `.js` files that QML imports directly, and the
tests run those exact files in Qt's JavaScript engine — not a reimplementation
of them. Only PySide6 is needed.

## Troubleshooting

**The widget is not in "Add Widgets".** Plasma caches that list. Restart the
shell: `kquitapp6 plasmashell && kstart plasmashell`. Search for `Hue`, not
`huedesk`.

**"Press the round button on your bridge, then try again."** The bridge only
issues a key for about 30 seconds after the button is pressed. Press it and
choose Pair again.

**"Cannot reach the bridge."** Check the address in the settings app. Find it
with `curl -s https://discovery.meethue.com/`.

More in [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

## A note on the application key

Your bridge key is stored in Plasma's applet configuration
(`~/.config/plasma-org.kde.plasma.desktop-appletsrc`) in plain text, the same
as any other Plasma widget's settings. It only grants control of lights on
your own network, but it is not secret storage. Do not paste that file into a
bug report.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Bug reports and patches are welcome.

## Typography

Hue Desk ships with **Archivo SemiExpanded** by Omnibus-Type, under the
[SIL Open Font License 1.1](package/contents/fonts/OFL.txt). It is a grotesque
drawn for legibility at interface sizes, and its semi-expanded width gives the
open, airy feel of the Hue app.

The font is bundled rather than merely requested, so the widget looks the same
on every machine. Pick any installed family instead in the settings app.

## License

Hue Desk is [MIT](LICENSE). The bundled font is SIL OFL 1.1 and keeps its own
[licence file](package/contents/fonts/OFL.txt).

Not affiliated with, endorsed by, or connected to Signify or Philips. "Philips
Hue" is their trademark; this is an independent project that talks to the
bridge's documented local API.
