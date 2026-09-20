# pixflat-theme

The Raspberry Pi OS desktop look for Debian: the official **PiXflat**, **PiXnoir**,
**PiXtrix**, **PiXonyx** and **PiX** themes with their icons, cursors, fonts,
wallpapers, sounds, panel, file manager and login screen. It works on LXDE, LXQt,
Xfce, GNOME, Budgie, Cinnamon, MATE, Openbox, labwc and, partly, KDE Plasma.

Everything comes from the two official archives:
[archive.raspberrypi.org](https://archive.raspberrypi.org/debian/) for the
Raspberry Pi OS packages, Debian for the rest. Your system stays Debian: no
repository is added and no Debian package is replaced or removed (see
[Debian safety](#debian-safety)).

| Script | Internet | Installs from |
|--------|----------|---------------|
| `install.sh` | required | the newest official packages, downloaded and verified as it runs |
| `install-offline.sh` | not needed | the local repository in [`packages/`](packages/) |

## Quick start

```sh
git clone https://github.com/b1ack0p/pixflat-theme.git
cd pixflat-theme
./install.sh                 # install every theme, then choose the look
./install.sh -y              # or no questions at all
```

Without internet access, use `./install-offline.sh` instead. Run either as your
normal user: it asks for `sudo` only to install packages.

No options are needed. Both scripts detect your Debian release, architecture,
user and desktop session themselves, install every theme your release supports,
and ask at the end which look to apply.

## Themes

| Theme (`-t`) | Look | Font | Wallpaper |
|--------------|------|------|-----------|
| `pixflat` | light, Raspberry Pi OS Bookworm (default on Debian 12) | Piboto | fisherman |
| `pixnoir` | dark, Raspberry Pi OS Bookworm | Piboto | fisherman |
| `pixtrix` | light, Raspberry Pi OS Trixie (default on Debian 13) | Nunito Sans Light | sunrise |
| `pixonyx` | dark, Raspberry Pi OS Trixie | Nunito Sans Light | sunrise |
| `pix` | legacy, Raspberry Pi OS Buster/Bullseye | Piboto | fisherman |

Every theme is installed on every supported release (about 76 MB, mostly
wallpapers) and any theme can be combined with any icon set:

```sh
./install.sh -t pixnoir --icons pixtrix   # a specific look, without asking
./install.sh --apply-only                 # switch the look later, downloads nothing
./install.sh --only pixflat               # install one family instead of all
```

Your desktop's appearance settings (LXAppearance, Xfce Appearance, …) list the
installed themes as well, but change only the GTK theme and icons;
`--apply-only` switches the whole look, including fonts, wallpaper, panel and
window borders.

## What you get

The settings are the ones Raspberry Pi OS itself uses, taken from its own
configuration packages (`raspberrypi-ui-mods` for Bookworm, `rpd-common`,
`rpd-x-core` and `rpd-wayland-core` for Trixie).

| Area | What is applied |
|------|-----------------|
| Fonts | the Raspberry Pi OS UI font at 12 pt, Liberation Mono for monospace |
| Rendering | antialiasing, full hinting, subpixel order; 24 px cursors and toolbar icons; no icons in menus and buttons |
| Windows | the theme's Openbox and labwc settings: title bar layout, round corners, invisible resize handles, window placement |
| Panel (LXDE, Debian 13) | **Raspberry Pi's own panel** in its own layout: menu, launchers, taskbar, tray, eject, Bluetooth, volume, clock, battery, magnifier, and its Run and Shutdown dialogs, with the Raspberry Pi OS keyboard shortcuts |
| Panel (LXDE, Debian 11 and 12) | Debian's panel, in the same layout and size |
| Notification icons | the Raspberry Pi OS icons for sound, network and Bluetooth, so Debian's applets look like Raspberry Pi's plugins |
| Application menu (LXDE) | the Raspberry Pi OS categories and order, with Help, Preferences, Run and Shutdown at the end |
| File manager | **Raspberry Pi's own file manager** on Debian 13, installed beside Debian's, with the Raspberry Pi OS window, toolbar and side pane settings; on Debian 11 and 12 Debian's file manager gets the same settings |
| Desktop | the wallpaper, desktop colours and font, trash and drive icons |
| Login screen | **Raspberry Pi's own greeter**, with its layout, background and colours, when LightDM is installed |
| Sounds | event sounds with the freedesktop sound theme |

On other desktops the same GTK theme, icons, cursor, fonts and wallpaper are
applied through that desktop's own settings:

| Desktop | Applied |
|---------|---------|
| Xfce | theme, icons, cursor, fonts, wallpaper, top panel, and an **Xfwm4 theme generated from the official Openbox theme** |
| GNOME, Budgie | GTK 3 theme, icons, cursor, fonts, button layout, wallpaper, light/dark preference |
| Cinnamon, MATE | theme, icons, cursor, fonts, wallpaper |
| LXQt | icons, cursor, Openbox theme, wallpaper (GTK applications use the GTK theme) |
| Openbox, labwc | the window settings above; labwc also cursor and GTK settings |
| KDE Plasma | icons and cursor (Plasma and Qt keep Breeze) |

### Small additions

Raspberry Pi OS's own packages assume a Raspberry Pi, so a few things are added
to make them fit Debian:

* The **Debian logo** replaces the Raspberry Pi logo on the menu button and the
  login screen, whichever icon set is selected.
* **Icon and cursor names** the official sets lack are added, so Debian's
  applets, dialogs and file manager show Raspberry Pi artwork instead of
  fallback icons.
* The **panel reloads** when you pick another icon set in *Customize Look and
  Feel*, which the panel does not notice by itself.
* **Title bar buttons** all grow on hover, including the middle button of a
  maximised window.
* **Xfwm4 themes** are generated for Xfce, and a **colour layer** for GTK 4 and
  libadwaita applications, which cannot use the theme itself (`--no-gtk4` skips it).

Panel, menu and tray are set up on the **first installation only**, so plugins
and applets you add or remove later are kept when you update or change the look.

## Options

All options are optional; they override what is detected.

```
-t, --theme NAME     theme to apply: pixflat | pixnoir | pixtrix | pixonyx | pix
    --icons NAME     icon set to apply: pixflat | pixtrix | pix (default: the theme's own)
    --only NAME      install only this theme's family instead of all themes
-d, --desktop LIST   other desktops than the detected one: all, none, or e.g. lxde,xfce
-u, --user NAME      configure another user's desktop (needs sudo)
    --wallpaper W    a file in /usr/share/rpd-wallpaper (e.g. aurora) or a path
    --no-wallpaper   skip the wallpaper packages (about 27 or 45 MB)
    --4k             use the 4K wallpaper set instead (about 100 MB)
    --no-font        keep your current fonts
    --no-panel       keep your panel and application menu
    --no-file-manager  keep Debian's file manager as the only one
    --no-gtk4        no GTK 4/libadwaita colour layer
    --no-lightdm     keep the login screen as it is
    --qt             make Qt applications follow the GTK theme
    --suite NAME     Raspberry Pi OS release to take packages from (default: matched to your Debian)
    --install-only   install packages only; --apply-only: choose and apply a look only
    --check          show available updates; change nothing
    --uninstall      restore previous settings and remove what was installed
-y, --yes            non-interactive    -n, --dry-run    show, change nothing
-v, --verbose        print every command
```

Each run writes a log, `~/pixflat-theme-DATE-TIME.log`, with every step and the
state of the desktop afterwards. It is the first place to look when something
is not as expected.

## Updating

No APT source is added, so `apt upgrade` does not update the Raspberry Pi OS
packages. Running the installer again does: it always checks the official
archive, and installs every package that has a newer version.

```sh
./install.sh --check     # list available updates, change nothing (no sudo needed)
./install.sh             # install them; each package is shown as new, an update, or up to date
```

A newer installed version is never downgraded. With `install-offline.sh` the
same commands compare against `packages/`; refresh it on a connected machine
with `./install-offline.sh --update-packages`.

## Uninstalling

```sh
./install.sh --uninstall
```

This restores every setting and file that was changed, removes the generated
package and, after asking, the packages the installer added. A package that
other software has come to need is kept — APT's own simulation decides — so
uninstalling never removes anything else.

## Debian safety

The installer follows Debian's
[DontBreakDebian](https://wiki.debian.org/DontBreakDebian) guidelines.

* **No FrankenDebian.** No Raspberry Pi (or other) APT source is added. Only
  individual, verified packages are installed: themes, icons, fonts, wallpapers,
  GTK 2 engines and, on Debian 13, Raspberry Pi's panel and file manager.
* **Nothing from Debian is replaced.** Any Raspberry Pi package whose name also
  exists in your APT sources is refused. Raspberry Pi's file manager, the one
  package that would replace a Debian one, is repacked to run beside it under
  its own program name, so nothing of Debian's is removed or overwritten.
* **Nothing is removed or upgraded as a side effect.** APT runs with
  `--no-remove`, installed packages are never upgraded, and older versions never
  replace newer ones.
* **Everything is tracked by dpkg.** No files are copied into system
  directories; the additions ship as a generated package, `pixflat-theme-debian`,
  which APT removes cleanly.
* **Only official sources.** Downloads are limited to
  `https://archive.raspberrypi.org/` and `https://deb.debian.org/`; other
  addresses, plain HTTP and redirects are refused. Before installing, the
  installer checks where APT would take each package from and refuses anything
  that is not Debian's or one of the verified files.
* **Only verified content.** Raspberry Pi indexes are checked against the
  Raspberry Pi Archive Signing Key pinned in the script
  (`CF8A 1AF5 02A2 AA2D 763B AE7E 82B1 2992 7FA3 303E`), Debian indexes against
  `debian-archive-keyring`, and every package against its SHA256.
* **Your settings are backed up** before they are changed, and restored by
  `--uninstall`.

## How it chooses packages

1. **The matching release:** Debian 11 uses the Raspberry Pi OS `bullseye`
   packages, Debian 12 `bookworm`, Debian 13 and newer `trixie`. Packages that
   contain compiled code always come from the matching release, so they are
   built against your libraries. Icons, fonts, wallpapers and themes hold no
   compiled code and may come from any release, so every theme works everywhere.
2. **Only what Debian can satisfy:** a version is used only if every dependency,
   with its version, is available from Debian. Raspberry Pi's own rebuilds of
   Debian packages (version suffix `+rpt`) are never installed.
3. **Renamed dependencies:** where an official package names a library Debian has
   since renamed, only its `Depends` field is rewritten to the current name. APT
   still checks every dependency.

## Offline repository

[`packages/`](packages/) is a small APT repository covering Debian 11, 12 and 13
on amd64, arm64, armhf and i386: the Raspberry Pi OS packages and the official
Debian packages they need that a Debian desktop installation does not already
have (about 320 MB, mostly wallpapers). `VERSIONS.md` lists the exact version and
source of every file, and `install-offline.sh` checks each one against
`SHA256SUMS` and installs with APT without going online.

Rebuild it on a machine with internet access:

```sh
./install-offline.sh --update-packages
```

Unchanged packages are reused, so only new versions are downloaded. On a system
without a desktop installation, use the online installer instead.

## Requirements

Debian 11 or newer, or a derivative, on amd64, i386, arm64 or armhf; bash 4.4 or
newer; `sudo`; and `curl` or `wget` for the online installer. Everything else
(`gpgv`, `dpkg-deb`, `apt`) is part of every Debian installation.

## Login screen notes

* The login screen uses Raspberry Pi's greeter, selected in a drop-in file of
  `pixflat-theme-debian` and configured in `/etc/lightdm/pi-greeter.conf`. The
  original file is kept and restored by `--uninstall`; settings in
  `/etc/lightdm/lightdm.conf` take precedence.
* Where that greeter cannot run, Debian's LightDM GTK greeter is styled to look
  as close as possible instead.
* The user list is shown, as in Raspberry Pi OS. To hide it again, set
  `greeter-hide-users=true` in `/etc/lightdm/lightdm.conf`.

## Where the packages come from

**Raspberry Pi OS**: <https://archive.raspberrypi.org/debian/>
(signed indexes in [`dists/`](https://archive.raspberrypi.org/debian/dists/),
packages in [`pool/main/`](https://archive.raspberrypi.org/debian/pool/main/))

| Component | Packages |
|-----------|----------|
| Themes | [pixflat-theme](https://archive.raspberrypi.org/debian/pool/main/p/pixflat-theme/) (PiXflat, PiXnoir), [pixtrix-theme](https://archive.raspberrypi.org/debian/pool/main/p/pixtrix-theme/) (PiXtrix, PiXonyx), [pix-theme](https://archive.raspberrypi.org/debian/pool/main/p/pix-theme/) (PiX) |
| Icons and cursors | [pixflat-icons](https://archive.raspberrypi.org/debian/pool/main/p/pixflat-icons/), [pixtrix-icons](https://archive.raspberrypi.org/debian/pool/main/p/pixtrix-icons/), [rpd-icons](https://archive.raspberrypi.org/debian/pool/main/r/rpd-icons/) |
| GTK 2 engines | [gtk2-engines-pixflat](https://archive.raspberrypi.org/debian/pool/main/g/gtk2-engines-pixflat/), [gtk2-engines-clearlookspix](https://archive.raspberrypi.org/debian/pool/main/g/gtk2-engines-clearlookspix/) |
| Fonts | [fonts-piboto](https://archive.raspberrypi.org/debian/pool/main/f/fonts-piboto/), [fonts-nunito-sans](https://archive.raspberrypi.org/debian/pool/main/f/fonts-nunito-sans/) |
| Panel (Debian 13) | [lxpanel-pi](https://archive.raspberrypi.org/debian/pool/main/l/lxpanel-pi/) with its plugins, [pishutdown](https://archive.raspberrypi.org/debian/pool/main/p/pishutdown/), [gui-runcmd](https://archive.raspberrypi.org/debian/pool/main/g/gui-runcmd/) |
| File manager (Debian 13) | [pcmanfm-pi](https://archive.raspberrypi.org/debian/pool/main/p/pcmanfm-pi/) |
| Login screen | [pi-greeter](https://archive.raspberrypi.org/debian/pool/main/p/pi-greeter/) |
| Wallpapers | [rpd-wallpaper](https://archive.raspberrypi.org/debian/pool/main/r/rpd-wallpaper/), [rpd-wallpaper-trixie](https://archive.raspberrypi.org/debian/pool/main/r/rpd-wallpaper-trixie/) and their 4K sets; the login screen wallpaper comes from [rpd-common](https://archive.raspberrypi.org/debian/pool/main/r/rpd-metas/), which is unpacked but never installed |

The desktop settings are the values from
[raspberrypi-ui-mods](https://archive.raspberrypi.org/debian/pool/main/r/raspberrypi-ui-mods/)
(Bookworm) and [rpd-metas](https://archive.raspberrypi.org/debian/pool/main/r/rpd-metas/)
(Trixie). Those packages configure a Raspberry Pi system, so they are never
installed; only their values are applied.

**Debian**: your APT sources, or <https://deb.debian.org/debian/> when building `packages/`

| Component | Packages |
|-----------|----------|
| GTK 2 engine and runtime | [gtk2-engines-pixbuf, libgtk2.0-bin, libgtk2.0-0](https://packages.debian.org/source/stable/gtk+2.0) |
| Icon fallback themes | [gnome-icon-theme](https://packages.debian.org/stable/gnome-icon-theme), [adwaita-icon-theme-legacy](https://packages.debian.org/stable/adwaita-icon-theme-legacy) |
| Fonts | [fonts-liberation](https://packages.debian.org/stable/fonts-liberation) |
| Sounds | [sound-theme-freedesktop](https://packages.debian.org/stable/sound-theme-freedesktop) |
| Help menu | [debian-reference-common](https://packages.debian.org/stable/debian-reference-common), [debian-reference-en](https://packages.debian.org/stable/debian-reference-en) |
| Tray applets | [network-manager-applet](https://packages.debian.org/stable/network-manager-applet), [blueman](https://packages.debian.org/stable/blueman), installed only if NetworkManager or BlueZ is |
| Debian logo | [desktop-base](https://packages.debian.org/stable/desktop-base), already part of a Debian desktop |

## Credits

The themes, icons, fonts, wallpapers and desktop settings are the work of
[Raspberry Pi Ltd](https://www.raspberrypi.com/) and the Raspberry Pi desktop
team. This project only installs their official packages on Debian and applies
their settings. All artwork belongs to its authors and keeps its own licence
(see `/usr/share/doc/<package>/copyright` after installation).
