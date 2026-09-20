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
./install.sh                 # install all themes, then choose the look
./install.sh -y              # or no questions at all
```

Offline, for example on a machine without internet access:

```sh
./install-offline.sh
```

No options are needed. Both scripts detect everything themselves:

| Detected | How |
|----------|-----|
| Debian release | `/etc/os-release`: Debian 11 uses the Raspberry Pi OS bullseye packages, Debian 12 bookworm, Debian 13 and newer trixie; derivatives are matched by library generation |
| Architecture | amd64, arm64, armhf or i386, from `dpkg` |
| User | you, or the user who invoked `sudo` |
| Desktop | the session you are logged into; if none is running, every desktop installed |
| Themes | every theme is installed, on every release; the look is chosen at the end (the default is the matching Raspberry Pi OS release: PiXtrix on Debian 13, PiXflat on Debian 12) |

Run them as your normal user. They ask for `sudo` only to install packages, then
apply the settings to your own desktop.

## Themes

| Theme (`-t`) | Look | Font | Wallpaper | Needs |
|--------------|------|------|-----------|-------|
| `pixflat` | light, Raspberry Pi OS Bookworm (default on Debian 12) | Piboto (PibotoLt 12) | fisherman | Debian 11+ |
| `pixnoir` | dark, Raspberry Pi OS Bookworm | Piboto | fisherman | Debian 11+ |
| `pixtrix` | light, Raspberry Pi OS Trixie (default on Debian 13) | Nunito Sans Light 12 | sunrise | Debian 11+ |
| `pixonyx` | dark, Raspberry Pi OS Trixie | Nunito Sans Light 12 | sunrise | Debian 11+ |
| `pix` | legacy, Raspberry Pi OS Buster/Bullseye | Piboto | fisherman | Debian 11+ |

All themes compatible with your Debian release are installed (about 76 MB on
Debian 13, most of it wallpapers). At the end, the installer asks which look to
apply: a theme, then an icon and cursor set (the theme's own by default, or any
other installed set). `0` keeps your current desktop. With `-y` the theme matching
your release is applied without asking.

Change the look at any time without downloading anything:

```sh
./install.sh --apply-only        # the same menus again; fonts, wallpaper and windows follow the theme
```

Your desktop's appearance settings (e.g. LXAppearance, Xfce Appearance) also list
the installed themes, but change only the GTK theme and icons. `--apply-only`
switches the whole look, and restarts the panel and desktop so the new icons
show at once; a set picked in an appearance tool reaches the panel only when it
restarts (`lxpanelctl-pi restart`, or the next login), because neither panel
program watches the icon theme. Those tools are meant to list only the adapted
icon sets (**PiXflat (Debian)**, **PiXtrix (Debian)**, **PiX (Debian)**), which
add the Debian logo, the extra cursors and the notification icons Debian's
applets use. Where a tool lists an official set anyway, picking it still shows
the Debian logo: the menu button icon of that set is replaced for your user.

Use `--only NAME` to install a single theme family instead, and `--4k` for the 4K
(3840×2160) wallpaper sets.

## Choosing a look

Any theme can be combined with any installed icon and cursor set. Pick them in
the menus at the end of the installation, or directly:

| Command | Theme | Icons and cursors |
|---------|-------|-------------------|
| `./install.sh -t pixflat` | PiXflat (light) | PiXflat |
| `./install.sh -t pixnoir` | PiXnoir (dark) | PiXflat |
| `./install.sh -t pixtrix` | PiXtrix (light) | PiXtrix |
| `./install.sh -t pixonyx` | PiXonyx (dark) | PiXtrix |
| `./install.sh -t pix` | PiX (legacy) | PiX |
| `./install.sh -t pixonyx --icons pixflat` | PiXonyx | PiXflat |
| `./install.sh -t pixnoir --icons pixtrix` | PiXnoir | PiXtrix |

Add `--apply-only` to switch an installed system without installing anything.
Everything that belongs to the look is applied automatically with it, exactly as
Raspberry Pi OS sets it: fonts and font sizes, font rendering, icon and cursor
sizes, window borders, corners and title bar, panel, application menu, file
manager and wallpaper. The font follows the theme: Piboto for PiXflat, PiXnoir
and PiX, Nunito Sans for PiXtrix and PiXonyx.

## What is applied

The values are the ones Raspberry Pi OS itself uses, taken from its
configuration packages (`raspberrypi-ui-mods` for Bookworm, `rpd-common`,
`rpd-x-core` and `rpd-wayland-core` for Trixie). Debian's own programs are used,
except on Debian 13, where Raspberry Pi's own panel with its Shutdown and Run
dialogs (LXDE) and its file manager are installed (they are built for Debian 13).
Raspberry Pi's system tools are never installed, and no Debian package is ever
replaced: the file manager is repacked to run beside Debian's.

| Area | Raspberry Pi OS settings applied |
|------|----------------------------------|
| Fonts | UI font at 12 pt (PibotoLt, or Nunito Sans Light), window titles and menus at 12 pt, Monospace as Liberation Mono |
| Rendering and sizes | antialiasing, full hinting, RGB subpixel order; cursor 24 px; toolbar icons 24 px with text beside; no icons in menus and buttons |
| Windows (Openbox, labwc) | theme, title bar with title, minimise, maximise and close (no window menu), round corners and invisible resize handles (Openbox), one desktop, window placement; labwc also drop shadows, window snapping and the window switcher layout |
| Scaling | Raspberry Pi OS sets no DPI or scale factor, so neither does the installer: your display scaling is kept |
| Panel (LXDE, Debian 13) | **Raspberry Pi's own panel** (`lxpanel-pi`) with its plugins: menu (Debian logo), launchers for web browser, file manager and terminal, taskbar, tray, eject, Bluetooth, volume, clock, battery (laptops) and magnifier, in the Raspberry Pi OS order and geometry (top, 36 px, 36 px icons, theme colours); Raspberry Pi's Run and Shutdown dialogs (`gui-runcmd`, `pishutdown`: log out, reboot, shut down) at the end of the menu; the network icon (`nm-applet`) in the network plugin's place, between Bluetooth and volume; only the updater and power plugins are left out (they need Raspberry Pi system tools or hardware), and the network plugin (it needs a Raspberry Pi rebuild of a Debian library); the Raspberry Pi OS keys: Super or Ctrl+Esc for the menu, Alt+F2 to run, Ctrl+Alt+Del for Shutdown, Ctrl+Alt+B for Bluetooth, Ctrl+Alt+M for the magnifier, the volume keys. The menu is reloaded whenever packages add or remove applications (Raspberry Pi's panel reads it only when it starts). |
| Panel (LXDE, Debian 11 and 12) | Debian's panel with the same layout and geometry: menu (Debian logo), launchers, taskbar, tray, volume, clock (`HH:MM`), battery (laptops) |
| Notification icons | the Raspberry Pi OS icons for sound, network and Bluetooth (the legacy PiX icons take the ones they lack from PiXflat): Debian's volume plugin, `nm-applet` and `blueman` show the same images as the Raspberry Pi panel plugins (Wi-Fi strength, wired, offline, connecting, VPN, Bluetooth on/off); secured connections show the plain signal icon, as in Raspberry Pi OS. On the Raspberry Pi panel, tray icons get an opaque background in the panel colour, because that panel's tray does not clear an icon before redrawing it (without it, `nm-applet` showed a doubled icon) |
| Tray applets (LXDE) | `nm-applet` for the network icon is installed if NetworkManager is; `blueman` for Bluetooth if BlueZ is, on Debian 11 and 12 (the Raspberry Pi panel on Debian 13 has its own Bluetooth plugin). Tray applets Raspberry Pi OS does not show (clipboard managers such as Diodon, other volume applets, `blueman` with the Raspberry Pi panel) are hidden once for your user, not removed; enable one again in *Desktop Session Settings* and it stays |
| Login screen | when LightDM is installed (`--no-lightdm` to skip): **Raspberry Pi's own greeter** (`pi-greeter`), so the login box, its layout and the background are the same as on Raspberry Pi OS. Its settings match the official `pi-greeter.conf` (background colour, the `RPiSystem` wallpaper cropped, theme, icons and font), with the Debian logo instead of the Raspberry Pi one. The original `/etc/lightdm/pi-greeter.conf` is kept and restored by `--uninstall`. Where that greeter cannot run, Debian's LightDM GTK greeter is styled to look as close as possible instead |
| Application menu (LXDE) | Raspberry Pi OS categories and order: Programming, Education, Science, Office, Internet, Sound & Video, Graphics, Games, Other, System Tools, Accessories, then Help, Preferences, Run and Shutdown; Help holds Debian Reference (`debian-reference-common`), as Raspberry Pi OS puts its documentation there; empty categories are hidden until an application of that category is installed. The menu is kept up to date by later runs unless you edit it with a menu editor |
| File manager (PCManFM, Debian 13) | **Raspberry Pi's own file manager** (`pcmanfm-pi`), which draws the desktop and opens your folders, with its Sort menu, its side pane (places and folder tree), its view buttons (icons, list, compact, thumbnails) and its toolbar. It ships as a replacement for Debian's file manager (same program name, same data files), so the installer repacks it to run **beside** Debian's instead, as `pcmanfm-pi`: the program is installed under that name and its data directory is renamed, and the files Debian's package already provides (the identical toolbar icons, the translations of the same message domain) are left out. Debian's `pcmanfm` is neither removed nor changed, so a Debian upgrade cannot collide with it. Debian's file manager stays available, and `--no-file-manager` keeps it as the only one |
| File manager settings | the settings of Raspberry Pi OS 13, key for key: 640×480 window, side pane at 150, icon view with thumbnails, new tab/navigation/home toolbar, status bar, single click off, trash and delete confirmation on; icons 48 px, small and side pane icons 24 px, thumbnails 80 px; places: home, root and drives; removable media left to the panel's eject plugin. They are written for both file managers, so Debian 11 and 12, where Raspberry Pi's is not built, get the same settings in Debian's |
| Desktop | wallpaper, desktop colours and font, trash and drive icons, no documents icon; the desktop is restarted so the settings (and the Desktop Preferences dialog) follow at once |
| Sounds | event and input feedback sounds with the freedesktop sound theme |

On other desktops the same GTK, font, icon and cursor settings are applied
through their own settings system:

| Desktop | Applied |
|---------|---------|
| Xfce | GTK theme, icons, cursor, fonts and rendering, **Xfwm4 theme generated from the official Openbox theme**, wallpaper, top panel (36 px) with the Debian logo menu button, full-colour panel icons |
| GNOME, Budgie | GTK 3 theme (applications and title bars), icons, cursor, fonts and rendering, button layout, wallpaper, light/dark preference |
| Cinnamon, MATE | GTK theme, icons, cursor, fonts and rendering, wallpaper |
| LXQt | icons, cursor, Openbox theme, PCManFM-Qt wallpaper; GTK applications use the GTK theme |
| Openbox, labwc | the Raspberry Pi OS window settings above; labwc also cursor and GTK settings |
| KDE Plasma | icons and cursor (Plasma and Qt keep Breeze) |

The panel and application menu are set up on the **first installation only**,
and each extra tray applet is hidden only once. Plugins and applets you add or
remove later are kept when you update or change the look. Every change to your settings is backed up first; `--uninstall`
restores them (and switches back to Debian's panel and file manager). Use
`--no-panel` to keep your panel and menu, `--no-file-manager` to keep Debian's
file manager as the only one, and `--no-font` to keep your fonts.

Updater and power plugins are not used: they need Raspberry Pi system tools or
hardware. Raspberry Pi OS has no battery icon set, so desktop power managers
(`xfce4-power-manager`, GNOME, MATE) keep Debian's battery icons; the Raspberry Pi
panel's battery plugin draws its own.

## GTK 2, 3 and 4

| Toolkit | Support |
|---------|---------|
| GTK 2 | Official theme with its engines: `pixflat` or `clearlookspix` from Raspberry Pi OS, `pixmap` from Debian's `gtk2-engines-pixbuf`. The installer reads each theme's `gtkrc` and installs every engine it uses. |
| GTK 3 | Official, complete theme (`gtk-3.0`) in every variant: the toolkit Raspberry Pi OS itself uses. The legacy PiX theme has no panel colours or panel styling of its own, which left panel icons cut off and buttons framed; it gets what the newer themes have, in a copy for your user that loads the official theme first, so it is complete however you select it. |
| GTK 4 / libadwaita | No official GTK 4 theme exists, and libadwaita ignores themes. Instead, the theme's own GTK 3 palette is mapped onto the named colours that GTK 4 and libadwaita read from `~/.config/gtk-4.0/gtk.css`, so window, view, header bar, sidebar, popover and accent colours match. Widget shapes stay GTK 4's own. Skip with `--no-gtk4`. |

LXDE itself is GTK 2 on Debian 12 and GTK 3 on Debian 13 (lxpanel, pcmanfm,
lxsession, lxappearance, …); both are covered. No LXDE component uses GTK 4 yet;
GTK 4 applications running on LXDE get the colour layer above.

## Options

All options are optional; they override what is detected.

```
-t, --theme NAME     theme to apply, without asking: pixflat | pixnoir | pixtrix | pixonyx | pix
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

Examples:

```sh
./install.sh                     # install all themes, then choose the look
./install.sh -y                  # no questions: the theme matching your Debian
./install.sh -n                  # preview every step, change nothing
./install.sh -t pixnoir --icons pixtrix   # a specific look, without asking
./install.sh --apply-only        # switch the look later
./install.sh --only pixflat --4k # one theme family, 4K wallpapers
./install.sh -d all              # every installed desktop
./install.sh --check             # list available updates
./install.sh --uninstall         # undo everything
```

## How it works

1. **Picks the newest compatible packages:** Debian 11 uses the Raspberry Pi OS
   `bullseye` release, Debian 12 `bookworm`, Debian 13 and newer `trixie`. Derivatives are matched
   by ABI generation, and `--suite` overrides it. Packages with binaries (themes,
   GTK 2 engines) always come from the matching release, so they are built against
   your system's libraries. Architecture-independent packages (icons, fonts,
   wallpapers) and the theme packages, which hold no compiled code, may come
   from any release, so every theme works on every Debian release. Either way, a version is only used
   if all its dependencies, including their versions, are available from Debian.
2. **Verifies everything:** the archive's `InRelease` index must be signed by the
   Raspberry Pi Archive Signing Key (fingerprint
   `CF8A 1AF5 02A2 AA2D 763B AE7E 82B1 2992 7FA3 303E`, pinned in the script). Every
   package is checked against the SHA256 in that signed index.
3. **Adapts stale dependency names:** if an official package depends on a name
   Debian has since renamed (for example, `gtk2-engines-clearlookspix` depends on
   `libgdk-pixbuf2.0-0`, which Debian 13 no longer has), only its `Depends` field
   is rewritten to the successor (`libgdk-pixbuf-2.0-0`). APT still checks every
   dependency.
4. **Installs with APT**, after refreshing the APT lists so dependencies come from
   the current Debian point release and security updates. The official Debian
   packages the themes need are added, but only if they are missing:
   `gtk2-engines-pixbuf`, `gnome-icon-theme` or `adwaita-icon-theme-legacy`,
   `fonts-liberation` and `sound-theme-freedesktop`, and for the LXDE tray
   `nm-applet` and `blueman` (see above). The installed versions are verified
   afterwards.
5. **Adds a small generated package, `pixflat-theme-debian`,** on top of the
   untouched official packages:
   * `PiXflat-Debian` / `PiXtrix-Debian` / `PiX-Debian` icon themes. They inherit
     the official icons and add **43 cursor-name aliases** that the official cursor
     themes lack (`pointer`, `all-scroll`, `nesw-resize`, `grab`, the Qt hash
     names, …), the icon names Debian's panel applets use for sound, network and
     Bluetooth, and the current names for every icon the official sets carry under
     the old GNOME naming (`gnome-mime-application-pdf` also answers to
     `application-pdf`), plus the common file types (office documents, plain text,
     unknown files). Each alias is a symlink to an official image. The
     legacy PiX also takes icons it lacks from PiXflat, the set closest to it in
     style; otherwise each set keeps the fallback its own theme names (GNOME,
     Adwaita), so no set is mixed with icons from another era. The official sets
     get the same names and fallbacks through a copy of their `index.theme` in
     your home, so the icons are the same whichever set is selected.
   * **Xfwm4 themes** for PiXflat, PiXnoir, PiXtrix, PiXonyx and PiX, generated from
     the colours and button bitmaps of the official Openbox themes.
   * the Raspberry Pi OS login screen style for the LightDM GTK greeter, with the
     Raspberry Pi login wallpapers (`RPiSystem.png`, `RPiSystem_dark.png`) and
     their licence, taken from the official `rpd-common` package. That package is
     downloaded and verified, never installed.
6. **Applies the settings** for the detected desktop, live when possible. Every file
   and setting it changes is backed up first (`~/.local/state/pixflat-theme`).

Every run writes its own log, `~/pixflat-theme-DATE-TIME.log` (the system, the
session, the packages, every step with a timestamp, and the desktop state
afterwards), which is the first place to look when something is not as
expected.

`--uninstall` restores every backed-up setting and file, removes
`pixflat-theme-debian` and, after asking, the packages the script installed.
A package that other installed software has come to need is kept: APT's own
simulation decides, so uninstalling never removes anything else. Kept packages
are marked automatic, and `apt autoremove` removes them once nothing needs them.

## Updates

No APT source is added, so `apt upgrade` does not update the Raspberry Pi OS
packages. The installer does:

```sh
./install.sh --check     # list available updates, change nothing (no sudo needed)
./install.sh             # install them; the plan marks each package as new,
                         # an update (with the old version) or up to date
```

`--check` covers every component (themes, icons and cursors, GTK engines, fonts,
wallpapers, panel, sounds, tray applets). For the Debian packages it shows whether `apt upgrade` has
an update. A newer installed version is never downgraded. With
`install-offline.sh`, the same commands compare against `packages/`; refresh it
with `--update-packages` on a connected machine.

## Debian safety

The installer follows [DontBreakDebian](https://wiki.debian.org/DontBreakDebian):

* **No FrankenDebian:** no Raspberry Pi (or any other) APT source is added. Only
  individual, verified leaf packages are installed: themes, icons, fonts,
  wallpapers, GTK 2 theme engines and, on Debian 13, Raspberry Pi's file manager
  and, with LXDE, its panel, plugins and Shutdown and Run dialogs.
* **Nothing from Debian is replaced:** the installer refuses any Raspberry Pi
  package whose name also exists in your APT sources. Packages the Raspberry Pi
  archive rebuilds from Debian (such as `gtk2-engines-pixbuf +rpt1`) are never
  used; Debian's own are. Raspberry Pi's file manager, the one package that
  declares `Breaks`/`Replaces` on a Debian package (`pcmanfm`), is repacked to
  run beside it as `pcmanfm-pi`, with its own program name and data directory
  and without those fields, so it neither removes nor overwrites anything of
  Debian's.
* **Nothing is removed or upgraded as a side effect:** APT runs with
  `--no-remove`, installed packages are never upgraded, and older versions never
  replace newer ones.
* **Everything is tracked by dpkg:** no `make install`, no files copied into
  system directories. The generated `pixflat-theme-debian` package only adds files
  under `/usr/share` and is removed cleanly with APT. Only packages that another
  installed package depends on (GTK 2 engines and runtime; offline, every
  dependency) are marked automatic, so `apt autoremove` cleans them up once unused
  and never removes the panel plugins, icons, fonts or sounds.
* **Only official sources:** downloads are limited to `https://archive.raspberrypi.org/`
  and `https://deb.debian.org/`; any other address, plain HTTP and redirects are
  refused. Before installing, the installer checks where APT would take each
  package from. On Debian, anything that is not from Debian or from the verified
  Raspberry Pi files is refused, even if another source is configured.
* **Only verified content:** Raspberry Pi indexes are checked against the pinned
  archive key, Debian indexes against `debian-archive-keyring`, and every package
  against its SHA256.
* **Only Debian's own packages:** some Raspberry Pi OS updates depend on Pi rebuilds of
  Debian packages (version suffix `+rpt`). Such a version is skipped for the newest
  version that works with Debian's packages, and the installer says so. Pi rebuilds
  of Debian packages are never installed.

## Offline installation

[`packages/`](packages/) is a local APT repository:

```
packages/
├── pool/
│   ├── themes/       pixflat-theme, pixtrix-theme, pix-theme
│   ├── icons/        pixflat-icons, pixtrix-icons, rpd-icons, gnome-icon-theme, adwaita-icon-theme-legacy
│   ├── fonts/        fonts-piboto, fonts-nunito-sans, fonts-liberation
│   ├── sounds/       sound-theme-freedesktop
│   ├── panel/        lxpanel-pi, plugins, pishutdown, gui-runcmd (Debian 13), nm-applet, blueman (Debian 11, 12)
│   ├── dependencies/ libraries the themes and applets need that a Debian desktop lacks
│   ├── engines/      GTK 2 engines and runtime: gtk2-engines-*, libgtk2.0-*, libgdk-pixbuf*
│   ├── greeter/      pi-greeter (Raspberry Pi's own login screen)
│   └── wallpapers/   rpd-wallpaper, rpd-wallpaper-trixie, their 4K sets, and rpd-common
│                     (only for the login screen wallpaper; never installed)
├── dists/<release>/main/binary-<arch>/Packages
├── SHA256SUMS
└── VERSIONS.md       exact version and source of every package
```

It covers **bullseye**, **bookworm** and **trixie** (Debian 11, 12, 13; newer
Debian releases use trixie) on **amd64, arm64, armhf and i386**: all
Raspberry Pi OS theme packages, plus every official Debian package they need
that a Debian desktop installation does not already have. The builder works out
that list from Debian's signed index: the full dependency closure of the bundled
packages, minus what the Debian installer's desktop installation sets up (the
base system and the desktop task with its recommended packages). What only
LXDE uses (Raspberry Pi's panel, the tray applets) is left out when Debian's
LXDE desktop has it; what every theme needs, only when every Debian desktop
(LXDE, Xfce, GNOME, KDE, Cinnamon, MATE, LXQt) has it. That leaves only a few
packages per release, such as the GTK 2 runtime, which not every desktop has.
On a minimal system, without a desktop task, use the online installer.

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
versions are downloaded. The repository is about 350 MB, most of it wallpapers.
The largest file, `rpd-wallpaper-trixie-4k`, is just under GitHub's 100 MiB file
limit.

## Requirements

Debian 11 or newer, or a derivative, on amd64 or i386 (x86) or arm64 or armhf (ARM); bash 4.4+;
`sudo`; and `curl` or `wget` for the online installer. Everything else (`gpgv`,
`dpkg-deb`, `apt`) is part of every Debian installation.

## LightDM tips

* The login screen uses Raspberry Pi's greeter, selected in a drop-in file of
  `pixflat-theme-debian` (`/usr/share/lightdm/lightdm.conf.d/60_pixflat-theme.conf`),
  and configured in `/etc/lightdm/pi-greeter.conf`. Settings in
  `/etc/lightdm/lightdm.conf` take precedence.
* Without that greeter, Debian's LightDM GTK greeter is styled instead, through
  `/usr/share/lightdm/lightdm-gtk-greeter.conf.d/60_pixflat-theme.conf`; settings
  in `/etc/lightdm/lightdm-gtk-greeter.conf` (written by *LightDM GTK Greeter
  Settings*) take precedence.
* The user list is shown, as in Raspberry Pi OS
  (`/usr/share/lightdm/lightdm.conf.d/60_pixflat-theme.conf`). To hide it again,
  set `greeter-hide-users=true` in `/etc/lightdm/lightdm.conf`.
* To use each user's wallpaper on the login screen, install `accountsservice` and
  enable *Use user wallpaper if available* in *LightDM GTK Greeter Settings*. The
  image must be readable outside your home directory, e.g. under
  `/usr/share/backgrounds/`.

## Package sources

The installers download only from these two official archives. Every link
below points to the packages themselves.

**Raspberry Pi OS**: <https://archive.raspberrypi.org/debian/>
(signed indexes in [`dists/`](https://archive.raspberrypi.org/debian/dists/),
package files in [`pool/main/`](https://archive.raspberrypi.org/debian/pool/main/))

| Component | Packages |
|-----------|----------|
| Themes | [pixflat-theme](https://archive.raspberrypi.org/debian/pool/main/p/pixflat-theme/) (PiXflat, PiXnoir), [pixtrix-theme](https://archive.raspberrypi.org/debian/pool/main/p/pixtrix-theme/) (PiXtrix, PiXonyx), [pix-theme](https://archive.raspberrypi.org/debian/pool/main/p/pix-theme/) (PiX) |
| Icons and cursors | [pixflat-icons](https://archive.raspberrypi.org/debian/pool/main/p/pixflat-icons/), [pixtrix-icons](https://archive.raspberrypi.org/debian/pool/main/p/pixtrix-icons/), [rpd-icons](https://archive.raspberrypi.org/debian/pool/main/r/rpd-icons/) |
| GTK 2 engines | [gtk2-engines-pixflat](https://archive.raspberrypi.org/debian/pool/main/g/gtk2-engines-pixflat/), [gtk2-engines-clearlookspix](https://archive.raspberrypi.org/debian/pool/main/g/gtk2-engines-clearlookspix/) |
| Fonts | [fonts-piboto](https://archive.raspberrypi.org/debian/pool/main/f/fonts-piboto/), [fonts-nunito-sans](https://archive.raspberrypi.org/debian/pool/main/f/fonts-nunito-sans/) |
| Panel (Debian 13) | [lxpanel-pi](https://archive.raspberrypi.org/debian/pool/main/l/lxpanel-pi/), plugins [menu](https://archive.raspberrypi.org/debian/pool/main/p/pplug-menu/), [volume](https://archive.raspberrypi.org/debian/pool/main/p/pplug-volumepulse/), [Bluetooth](https://archive.raspberrypi.org/debian/pool/main/p/pplug-bluetooth/), [eject](https://archive.raspberrypi.org/debian/pool/main/p/pplug-ejecter/), [clock](https://archive.raspberrypi.org/debian/pool/main/p/pplug-clock/), [battery](https://archive.raspberrypi.org/debian/pool/main/p/pplug-batt/), [magnifier](https://archive.raspberrypi.org/debian/pool/main/l/lpplug-magnifier/), Shutdown dialog [pishutdown](https://archive.raspberrypi.org/debian/pool/main/p/pishutdown/), Run dialog [gui-runcmd](https://archive.raspberrypi.org/debian/pool/main/g/gui-runcmd/) |
| Login screen | [pi-greeter](https://archive.raspberrypi.org/debian/pool/main/p/pi-greeter/) (Raspberry Pi's own LightDM greeter) |
| Wallpapers | [rpd-wallpaper](https://archive.raspberrypi.org/debian/pool/main/r/rpd-wallpaper/), [rpd-wallpaper-4k](https://archive.raspberrypi.org/debian/pool/main/r/rpd-wallpaper-4k/), [rpd-wallpaper-trixie](https://archive.raspberrypi.org/debian/pool/main/r/rpd-wallpaper-trixie/), [rpd-wallpaper-trixie-4k](https://archive.raspberrypi.org/debian/pool/main/r/rpd-wallpaper-trixie-4k/); login screen wallpaper from [rpd-common](https://archive.raspberrypi.org/debian/pool/main/r/rpd-metas/) (unpacked, not installed; BSD-3-Clause) |

The desktop settings (fonts, colours, panel and window layout) are the values from
the Raspberry Pi OS configuration packages
[raspberrypi-ui-mods](https://archive.raspberrypi.org/debian/pool/main/r/raspberrypi-ui-mods/)
(Bookworm) and [rpd-metas](https://archive.raspberrypi.org/debian/pool/main/r/rpd-metas/)
(`rpd-common`, `rpd-x-core`, `rpd-wayland-core`; Trixie). These packages are not
installed; the installer applies their values to your desktop.

**Debian**: your APT sources, or <https://deb.debian.org/debian/> when building `packages/`

| Component | Packages |
|-----------|----------|
| GTK 2 engine and runtime | [gtk2-engines-pixbuf, libgtk2.0-bin, libgtk2.0-0](https://packages.debian.org/source/stable/gtk+2.0) |
| Icon fallback themes | [gnome-icon-theme](https://packages.debian.org/stable/gnome-icon-theme), [adwaita-icon-theme-legacy](https://packages.debian.org/stable/adwaita-icon-theme-legacy) |
| Fonts | [fonts-liberation](https://packages.debian.org/stable/fonts-liberation) |
| Sounds | [sound-theme-freedesktop](https://packages.debian.org/stable/sound-theme-freedesktop) |
| Help menu | [debian-reference-common](https://packages.debian.org/stable/debian-reference-common), [debian-reference-en](https://packages.debian.org/stable/debian-reference-en) (Debian Reference, as in Raspberry Pi OS) |
| Tray applets | [network-manager-applet](https://packages.debian.org/stable/network-manager-applet) (Debian 13; [network-manager-gnome](https://packages.debian.org/bookworm/network-manager-gnome) on Debian 12), [blueman](https://packages.debian.org/stable/blueman) (only if NetworkManager or BlueZ is installed) |
| Debian logo on the menu button | [desktop-base](https://packages.debian.org/stable/desktop-base), already installed on Debian desktops (falls back to the logo in `debconf`) |

## Credits

The themes, icons, fonts, wallpapers and desktop settings are the work of
[Raspberry Pi Ltd](https://www.raspberrypi.com/) and the Raspberry Pi desktop team
(most of the desktop's UI work is by spl237). This project only installs their
official packages on Debian and adapts the settings. All artwork belongs to its
authors and is distributed under its own licence (see
`/usr/share/doc/<package>/copyright` after installation).

This installer follows Debian's [DontBreakDebian](https://wiki.debian.org/DontBreakDebian)
guidelines.
