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
3. Category: **Plasma 6 Applets**. Getting this wrong is the usual reason a
   widget never shows up in *Get New Widgets*.
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

### Updating later

Upload the new `.plasmoid` to the **same** product and set the new version
number. Plasma compares it against the installed `metadata.json`, so the two
must agree.

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
