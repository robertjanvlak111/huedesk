# Publishing a release

## 1. Cut the release

Bump `KPlugin.Version` in `package/metadata.json` and add a `CHANGELOG.md`
entry, then:

```bash
python3 tests/run_tests.py          # must pass
./tools/package.sh                  # dist/com.rvlak.huedesk-<version>.plasmoid
git tag -a v<version> -m "v<version>"
git push origin v<version>
```

The tag triggers `.github/workflows/release.yml`, which rebuilds the archive
and attaches it to a GitHub release.

## 2. KDE Store

The store is where Plasma users actually find widgets: it is the same catalogue
behind **Add Widgets… → Get New Widgets…**, so a listing makes Hue Desk
installable without touching a terminal.

This has to be done by hand the first time — there is no API for creating a
listing.

1. Sign in at <https://store.kde.org> (an OpenDesktop account).
2. **Add Product**.
3. Category: **Plasma 6 Applets** (store category 706).

   *Get New Widgets* is configured by `/usr/share/knsrcfiles/plasmoids.knsrc`,
   which queries **Plasma 6 Extensions** (705). That is an umbrella: it returns
   everything listed under Applets, Clocks, Weather and the rest, so an item in
   706 does appear there. Listing under an unrelated category is what makes a
   widget invisible in the dialog.
4. Upload `dist/com.rvlak.huedesk-<version>.plasmoid`.
5. Fill in:
   - **Title**: Hue Desk
   - **Summary**: Control your Philips Hue lights from a widget on your desktop
   - **Description**: the top of `README.md` reads well here
   - **License**: MIT
   - **Version**: must match `metadata.json` exactly, or Plasma will not offer
     the update
   - **Link**: the GitHub repository
6. Add screenshots from `screenshots/`. The first one is the thumbnail, so
   lead with `widget-dark.png`.

### How users get updates

Upload the new `.plasmoid` to the **same** product page and raise the version
number. That is the whole mechanism:

- Plasma records which store item a widget came from when it is installed.
- Next time the user opens *Add Widgets… → Get New Widgets…*, it compares the
  store's version against theirs and offers an **Update** button.
- Discover shows the same updates.

Two rules, and nothing works without them:

1. **Same product page, every time.** A new product is a new item; people who
   installed the old one will never be offered it.
2. **The version must go up**, and `metadata.json` must carry the same number
   as the store listing. Plasma compares version strings, so 2.3.0 → 2.4.0
   works and re-uploading 2.3.0 does nothing.

People who installed with `git clone` and `install.sh` are not tracked by the
store; they update with `git pull && ./install.sh`.

### What the store will not take

A `.plasmoid` is a zip with `metadata.json` and `contents/` at its **root**.
Wrapping them in a folder is the most common rejection; `tools/package.sh`
checks the layout before it writes the file.

## 3. What about Flatpak, Flathub or Bazaar?

None of them apply. A plasmoid is QML loaded inside the `plasmashell` process;
Flatpak packages sandboxed applications, and there is no way to inject QML into
the host's shell from inside a sandbox. Bazaar (the Bazzite and Bluefin app
store) is a Flathub front end, so it inherits the same limitation.

Distribution routes that do work:

| Route | Audience |
| --- | --- |
| KDE Store | Plasma users, in-desktop via *Get New Widgets* |
| `git clone` + `./install.sh` | anyone, documented in the README |
| Distribution packaging (COPR, AUR) | users of those distributions |

A Flatpak would only make sense for a separate standalone application, which
is a different product rather than a packaging format for this one.
