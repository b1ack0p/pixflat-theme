# pixflat-theme

The Raspberry Pi OS desktop look for Debian: the official **PiXflat**, **PiXnoir**,
**PiXtrix**, **PiXonyx** and **PiX** themes with their icons, cursors, GTK
engines, fonts, wallpapers, sounds and panel layout. It works on LXDE, LXQt, Xfce, GNOME, Budgie,
Cinnamon, MATE, Openbox, labwc and (partially) KDE Plasma.

Only official packages from official repositories are used:
[archive.raspberrypi.org](https://archive.raspberrypi.org/debian/) for the
Raspberry Pi OS packages and Debian for everything else. Your system stays pure
Debian: no repository is added and no Debian package is replaced (see
[Debian safety](#debian-safety)).

| Script | Network | Installs from |
|--------|---------|---------------|
| `install.sh` | required | the newest official packages, downloaded and verified on the fly |
| `install-offline.sh` | not needed | the local package repository in [`packages/`](packages/) |

## Quick start

```sh
git clone https://github.com/b1ack0p/pixflat-theme.git
cd pixflat-theme
./install.sh                 # interactive: choose a theme, confirm, done
```

Offline, for example on a machine without internet access:

```sh
./install-offline.sh
```

Both scripts take the same options and detect everything themselves: the Debian
release, the architecture, the user and the desktop. Run them as your normal user;
they ask for `sudo` only to install packages, then apply the settings to your own
desktop. Under `sudo`, the settings go to the user who invoked `sudo` (or use
`--user NAME`).

## Themes

| Theme (`-t`) | Look | Font | Wallpaper | Needs |
|--------------|------|------|-----------|-------|
| `pixflat` (default) | light, Raspberry Pi OS Bookworm | Piboto (PibotoLt 12) | fisherman | Debian 12+ |
| `pixnoir` | dark, Raspberry Pi OS Bookworm | Piboto | fisherman | Debian 12+ |
| `pixtrix` | light, Raspberry Pi OS Trixie | Nunito Sans Light 12 | sunrise | Debian 13+ |
| `pixonyx` | dark, Raspberry Pi OS Trixie | Nunito Sans Light 12 | sunrise | Debian 13+ |
| `pix` | legacy, Raspberry Pi OS Buster/Bullseye | Piboto | fisherman | Debian 12+ |

The wallpapers are also available as 4K (3840×2160) sets with `--4k`.

## What each desktop gets

The values are the ones Raspberry Pi OS itself uses, taken from its
configuration packages (`raspberrypi-ui-mods`, `rpd-common`, `rpd-x-core`,
`rpd-wayland-core`).

| Desktop | Applied |
|---------|---------|
| LXDE | GTK theme, icons, cursor, font and colour scheme (lxsession); Openbox theme, fonts and title layout; PCManFM wallpaper and desktop colours; **panel at the top, 36 px, theme colours, Debian logo on the menu button** |
| Xfce | GTK theme, icons, cursor, font, **Xfwm4 theme generated from the official Openbox theme**, wallpaper, full-colour panel icons, top panel (36 px) with the Debian logo menu button |
| GNOME, Budgie | GTK 3 theme (applications and titlebars), icons, cursor, fonts, button layout, wallpaper, light/dark preference |
| Cinnamon, MATE | GTK theme, icons, cursor, fonts, wallpaper |
| LXQt | icons, cursor, Openbox theme, PCManFM-Qt wallpaper; GTK applications use the GTK theme |
| Openbox, labwc | window theme and fonts; labwc also cursor and GTK settings |
| KDE Plasma | icons and cursor (Plasma and Qt keep Breeze) |

Every desktop also gets the GTK 2/3/4 settings files, the default X11 cursor,
Liberation Mono as the Monospace font, and event sounds with the freedesktop
sound theme, all as in Raspberry Pi OS. GTK 4/libadwaita
applications get the theme's colours (see [GTK 2, 3 and 4](#gtk-2-3-and-4)); GNOME
Shell cannot be themed and keeps its default style.
The Raspberry Pi-specific panel plugins (`lxpanel-pi`, `wf-panel-pi`) are not
installed, because they would replace Debian's own panel. Your desktop keeps
Debian's panel, with the Raspberry Pi OS layout.

## GTK 2, 3 and 4

| Toolkit | Support |
|---------|---------|
| GTK 2 | Official theme with its engines: `pixflat` or `clearlookspix` from Raspberry Pi OS, `pixmap` from Debian's `gtk2-engines-pixbuf`. The installer reads each theme's `gtkrc` and installs every engine it uses. |
| GTK 3 | Official, complete theme (`gtk-3.0`) in every variant: the toolkit Raspberry Pi OS itself uses. |
| GTK 4 / libadwaita | No official GTK 4 theme exists, and libadwaita ignores themes. Instead, the theme's own GTK 3 palette is mapped onto the named colours that GTK 4 and libadwaita read from `~/.config/gtk-4.0/gtk.css`, so window, view, header bar, sidebar, popover and accent colours match. Widget shapes stay GTK 4's own. Skip with `--no-gtk4`. |

LXDE itself is GTK 2 on Debian 12 and GTK 3 on Debian 13 (lxpanel, pcmanfm,
lxsession, lxappearance, …); both are covered. No LXDE component uses GTK 4 yet;
GTK 4 applications running on LXDE get the colour layer above.

## Options

```
-t, --theme NAME     pixflat | pixnoir | pixtrix | pixonyx | pix
-d, --desktop LIST   auto (default), all, none, or e.g. lxde,xfce
-u, --user NAME      configure another user's desktop (needs sudo)
    --wallpaper W    a file in /usr/share/rpd-wallpaper (e.g. aurora) or a path
    --no-wallpaper   skip the wallpaper packages (about 27 or 45 MB)
    --4k             use the 4K wallpaper set instead (about 100 MB)
    --no-font        keep your current fonts
    --no-panel       keep your panel layout
    --no-gtk4        no GTK 4/libadwaita colour layer
    --lightdm        also theme the LightDM GTK greeter (login screen)
    --qt             make Qt applications follow the GTK theme
    --install-only   install packages only; --apply-only: apply settings only
    --check          show available updates; change nothing
    --uninstall      restore previous settings and remove what was installed
-y, --yes            non-interactive    -n, --dry-run    show, change nothing
```

Examples:

```sh
./install.sh -t pixtrix -y                       # PiXtrix on the current desktop
sudo ./install.sh -t pixnoir -d lxde,xfce --lightdm -y
./install.sh -n -t pixflat --4k                  # preview every step
./install.sh --uninstall
```

## How it works

1. **Picks the newest compatible packages:** Debian 12 uses the Raspberry Pi OS
   `bookworm` release, Debian 13 (and testing) `trixie`. Derivatives are matched
   by ABI generation, and `--suite` overrides it. Packages with binaries (themes,
   GTK 2 engines) always come from the matching release, so they are built against
   your system's libraries. Architecture-independent packages (icons, fonts,
   wallpapers) may come from a newer release, but only if all their dependencies
   are available on your Debian release.
2. **Verifies everything:** the archive's `InRelease` index must be signed by the
   Raspberry Pi Archive Signing Key (fingerprint
   `CF8A 1AF5 02A2 AA2D 763B AE7E 82B1 2992 7FA3 303E`, pinned in the script). Every
   package is checked against the SHA256 in that signed index.
3. **Adapts stale dependency names:** if an official package depends on a name
   Debian has since renamed (`gtk2-engines-clearlookspix` →
   `libgdk-pixbuf2.0-0`, gone in Debian 13), only its `Depends` field is rewritten
   to the successor (`libgdk-pixbuf-2.0-0`). APT still checks every dependency.
4. **Installs with APT**, after refreshing the APT lists so dependencies come from
   the current Debian point release and security updates. The official Debian
   packages the themes need are added, but only if they are missing:
   `gtk2-engines-pixbuf`, `gnome-icon-theme` or `adwaita-icon-theme-legacy`,
   `fonts-liberation` and `sound-theme-freedesktop`. The installed versions are
   verified afterwards.
5. **Adds a small generated package, `pixflat-theme-debian`,** on top of the
   untouched official packages:
   * `PiXflat-Debian` / `PiXtrix-Debian` icon themes. They inherit the official
     icons and add **43 cursor-name aliases** that the official cursor themes lack
     (`pointer`, `all-scroll`, `nesw-resize`, `grab`, the Qt hash names, …). Each
     alias is a symlink to an official cursor image, so links, resizing and
     drag-and-drop show the right cursor.
   * **Xfwm4 themes** for PiXflat, PiXnoir, PiXtrix, PiXonyx and PiX, generated from
     the colours and button bitmaps of the official Openbox themes.
   * with `--lightdm`, a LightDM GTK greeter configuration.
6. **Applies the settings** for the detected desktop, live when possible. Every file
   and setting it changes is backed up first (`~/.local/state/pixflat-theme`).

`--uninstall` restores every backed-up setting and file, removes
`pixflat-theme-debian` and, after asking, the packages the script installed.

## Updates

No APT source is added, so `apt upgrade` does not update the Raspberry Pi OS
packages. The installer does:

```sh
./install.sh --check     # list available updates, change nothing (no sudo needed)
./install.sh             # install them; the plan marks each package as new,
                         # an update (with the old version) or up to date
```

`--check` covers every component (themes, icons and cursors, GTK engines, fonts,
wallpapers, sounds). For the Debian packages it shows whether `apt upgrade` has
an update. A newer installed version is never downgraded. With
`install-offline.sh`, the same commands compare against `packages/`; refresh it
with `--update-packages` on a connected machine.

## Debian safety

The installer follows [DontBreakDebian](https://wiki.debian.org/DontBreakDebian):

* **No FrankenDebian:** no Raspberry Pi (or any other) APT source is added. Only
  individual, verified leaf packages are installed: themes, icons, fonts,
  wallpapers and GTK 2 theme engines.
* **Nothing from Debian is replaced:** the installer refuses any Raspberry Pi
  package whose name also exists in your APT sources. Packages the Raspberry Pi
  archive rebuilds from Debian (such as `gtk2-engines-pixbuf +rpt1`) are never
  used; Debian's own are.
* **Nothing is removed or upgraded as a side effect:** APT runs with
  `--no-remove`, installed packages are never upgraded, and older versions never
  replace newer ones.
* **Everything is tracked by dpkg:** no `make install`, no files copied into
  system directories. The generated `pixflat-theme-debian` package only adds files
  under `/usr/share` and is removed cleanly with APT. Libraries and engines pulled
  in as dependencies are marked automatic, so `apt autoremove` cleans them up.
* **Only verified content:** Raspberry Pi indexes are checked against the pinned
  archive key, Debian indexes against `debian-archive-keyring`, and every package
  against its SHA256.

## Offline installation

[`packages/`](packages/) is a local APT repository:

```
packages/
├── pool/
│   ├── themes/       pixflat-theme, pixtrix-theme, pix-theme
│   ├── icons/        pixflat-icons, pixtrix-icons, rpd-icons, gnome-icon-theme, adwaita-icon-theme-legacy
│   ├── fonts/        fonts-piboto, fonts-nunito-sans, fonts-liberation
│   ├── sounds/       sound-theme-freedesktop
│   ├── engines/      GTK 2 engines and runtime: gtk2-engines-*, libgtk2.0-*, libgdk-pixbuf*
│   └── wallpapers/   rpd-wallpaper, rpd-wallpaper-trixie and their 4K sets
├── dists/<release>/main/binary-<arch>/Packages
├── SHA256SUMS
└── VERSIONS.md       exact version and source of every package
```

It covers **bookworm** and **trixie** on **amd64, arm64, armhf and i386**: all
Raspberry Pi OS theme packages, plus every official Debian package they need
that is not part of a standard Debian desktop. The builder works out that list
from Debian's signed index. It takes the full dependency closure of the bundled
packages and subtracts the Debian base system (priority required, important and
standard) and the GTK 3 runtime that every desktop has. That leaves, for example,
the GTK 2 runtime, which GNOME, KDE and LXQt systems often lack, and the icon
fallback themes.

When installing, `install-offline.sh` computes the same closure for the chosen
theme and installs only the members that are missing.

`install-offline.sh` checks every file against `SHA256SUMS` and installs with
`apt-get --no-download`, so it never goes online. To refresh the repository from
the official sources, on a machine with internet access:

```sh
./install-offline.sh --update-packages
```

This checks the Raspberry Pi indexes against the pinned key and the Debian indexes
against `debian-archive-keyring`. Unchanged packages are reused, so only new
versions are downloaded. The repository is about 300 MB, most of it wallpapers.
The largest file, `rpd-wallpaper-trixie-4k`, is just under GitHub's 100 MiB file
limit.

## Requirements

Debian 12 or 13, or a derivative, on amd64, arm64, armhf or i386; bash 4.4+;
`sudo`; and `curl` or `wget` for the online installer. Everything else (`gpgv`,
`dpkg-deb`, `apt`) is part of every Debian installation.

## LightDM tips

* `--lightdm` sets the greeter theme, icons, font and wallpaper. Settings in
  `/etc/lightdm/lightdm-gtk-greeter.conf` (written by *LightDM GTK Greeter
  Settings*) take precedence.
* To show user pictures, set `greeter-hide-users=false` in `/etc/lightdm/lightdm.conf`.
* To use each user's wallpaper on the login screen, install `accountsservice` and
  enable *Use user wallpaper if available* in *LightDM GTK Greeter Settings*. The
  image must be readable outside your home directory, e.g. under
  `/usr/share/backgrounds/`.

## References and credits

The themes, icons, fonts, wallpapers and desktop defaults are the work of
[Raspberry Pi Ltd](https://www.raspberrypi.com/) and the Raspberry Pi desktop
team. Most of the desktop's UI work is by [@spl237](https://github.com/spl237).
This project only installs their official packages on Debian and adapts the
settings; all artwork belongs to its authors and is distributed under its own
licence (see `/usr/share/doc/<package>/copyright` after installation).

**Raspberry Pi OS**

* Package archive: <https://archive.raspberrypi.org/debian/>, with the package
  pool at <https://archive.raspberrypi.org/debian/pool/main/>
* Desktop source code: <https://github.com/raspberrypi-ui>
* Themes: [pixflat-theme](https://archive.raspberrypi.org/debian/pool/main/p/pixflat-theme/)
  (PiXflat, PiXnoir), [pixtrix-theme](https://archive.raspberrypi.org/debian/pool/main/p/pixtrix-theme/)
  (PiXtrix, PiXonyx), [pix-theme](https://archive.raspberrypi.org/debian/pool/main/p/pix-theme/) (PiX)
* Icons and cursors: [pixflat-icons](https://archive.raspberrypi.org/debian/pool/main/p/pixflat-icons/),
  [pixtrix-icons](https://archive.raspberrypi.org/debian/pool/main/p/pixtrix-icons/),
  [rpd-icons](https://archive.raspberrypi.org/debian/pool/main/r/rpd-icons/)
* GTK 2 engines: [gtk2-engines-pixflat](https://github.com/raspberrypi-ui/gtk2-engines-pixflat)
  ([packages](https://archive.raspberrypi.org/debian/pool/main/g/gtk2-engines-pixflat/)),
  [gtk2-engines-clearlookspix](https://archive.raspberrypi.org/debian/pool/main/g/gtk2-engines-clearlookspix/)
* Fonts: [fonts-piboto](https://archive.raspberrypi.org/debian/pool/main/f/fonts-piboto/),
  [fonts-nunito-sans](https://archive.raspberrypi.org/debian/pool/main/f/fonts-nunito-sans/)
* Wallpapers: [rpd-wallpaper](https://archive.raspberrypi.org/debian/pool/main/r/rpd-wallpaper/),
  [rpd-wallpaper-4k](https://archive.raspberrypi.org/debian/pool/main/r/rpd-wallpaper-4k/),
  [rpd-wallpaper-trixie](https://archive.raspberrypi.org/debian/pool/main/r/rpd-wallpaper-trixie/),
  [rpd-wallpaper-trixie-4k](https://archive.raspberrypi.org/debian/pool/main/r/rpd-wallpaper-trixie-4k/)
* Desktop defaults (fonts, colours, panel, window layout):
  [raspberrypi-ui-mods](https://github.com/raspberrypi-ui/raspberrypi-ui-mods) (Bookworm) and
  [rpd-metas](https://github.com/raspberrypi-ui/rpd-metas) (`rpd-common`, `rpd-x-core`,
  `rpd-wayland-core`; Trixie)
* Related desktop components, not installed:
  [lxpanel-pi](https://github.com/raspberrypi-ui/lxpanel-pi),
  [wf-panel-pi](https://github.com/raspberrypi-ui/wf-panel-pi),
  [pcmanfm-pi](https://github.com/raspberrypi-ui/pcmanfm-pi),
  [labwc](https://github.com/raspberrypi-ui/labwc),
  [openbox](https://github.com/raspberrypi-ui/openbox),
  [pi-greeter](https://github.com/raspberrypi-ui/pi-greeter)

**Debian**

* Archive: <https://deb.debian.org/debian/>, packages at <https://packages.debian.org/>
* [gtk2-engines-pixbuf and libgtk2.0-bin](https://packages.debian.org/source/stable/gtk+2.0),
  [gnome-icon-theme](https://packages.debian.org/stable/gnome-icon-theme),
  [adwaita-icon-theme-legacy](https://packages.debian.org/stable/adwaita-icon-theme-legacy),
  [fonts-liberation](https://packages.debian.org/stable/fonts-liberation),
  [sound-theme-freedesktop](https://packages.debian.org/stable/sound-theme-freedesktop)
* Debian logo on the menu button: [desktop-base](https://packages.debian.org/stable/desktop-base)
  (falls back to the logo in `debconf`)
* [DontBreakDebian](https://wiki.debian.org/DontBreakDebian), the guidelines this installer follows
