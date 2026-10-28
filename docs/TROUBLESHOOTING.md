# Troubleshooting

## The widget does not appear in "Add Widgets"

Plasma caches the widget list at start-up.

```bash
kquitapp6 plasmashell && kstart plasmashell
```

Search for **Hue**, not `huedesk`. Plasma matches whole words in the name, and
the widget is called "Hue Desk".

Check it is installed at all:

```bash
kpackagetool6 --type Plasma/Applet --list | grep huedesk
```

## Pairing says the link button was not pressed

The bridge only issues an application key for about 30 seconds after its round
button is pressed. Press it, then choose **Pair** within that window.

## "Cannot reach the bridge"

Find your bridge:

```bash
curl -s https://discovery.meethue.com/
```

That returns the address Philips last saw for your bridge. Check it answers:

```bash
curl -s http://<address>/api/0/config
```

If that prints a JSON block with a `bridgeid`, the bridge is reachable and the
address in the settings app is simply wrong.

## "The bridge rejected the request. Re-pair Hue Desk."

The application key is no longer valid — usually because the bridge was reset
or the key was removed in the Hue app. Clear the key in the settings app (or
in Plasma's own dialog) and pair again.

## Lights react slowly, or changes made elsewhere take a while to show

Hue Desk polls. Lower **Refresh every** in the settings app; 5 seconds is the
minimum. The bridge is rate-limited, so very frequent polling across several
apps can make it reject requests.

## The widget is behind my windows

Desktop widgets are drawn on the desktop, below every window. Use **Show
Desktop** (Meta+D by default), or put the widget in a panel instead, where it
becomes an icon with a pop-up.

## A room shows no brightness

A room containing only smart plugs has nothing to dim. Plugs report
`dimming: false`, so the card is on/off only. This is intentional.

## `kpackagetool6` says "Plugin  is not installed"

The message is misleading: it means the tool could not open the `.plasmoid`
**file**, not that a plugin is missing. It reads the plugin name out of the
archive, and with no archive to read it reports an empty name — hence the
double space in the message.

Almost always you are in a different directory from the file:

```bash
ls *.plasmoid                     # is it actually here?
kpackagetool6 --type Plasma/Applet --upgrade "$PWD/com.rvlak.huedesk-2.3.0.plasmoid"
```

Use `--upgrade` when the widget is already installed and `--install` when it
is not; `--install` refuses to overwrite an existing copy.

## Collecting diagnostics

QML errors go to the journal, not the terminal:

```bash
journalctl --user -n 200 | grep -i plasmashell | grep -i huedesk
```

To run the widget in a window of its own, which makes errors easier to see:

```bash
plasmawindowed com.rvlak.huedesk
```

Do not paste `~/.config/plasma-org.kde.plasma.desktop-appletsrc` into a bug
report: it contains your bridge application key.
