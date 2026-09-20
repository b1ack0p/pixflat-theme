#!/usr/bin/env bash
#
# pixflat-theme — the Raspberry Pi OS desktop look for Debian (online installer)
#
# Installs the official Raspberry Pi OS desktop themes (PiXflat, PiXnoir,
# PiXtrix, PiXonyx, PiX) with their icons, cursors, fonts and wallpapers, and
# applies them to LXDE, LXQt, Xfce, GNOME, Budgie, Cinnamon, MATE, Openbox,
# labwc and, partially, KDE Plasma.
#
# Principles:
#  * Official sources only: archive.raspberrypi.org for the themes, Debian for
#    everything else. Indexes are verified by GPG, packages by SHA256.
#  * Debian stays Debian: no APT source is added, no Debian package is replaced,
#    removed or upgraded, and everything is installed through dpkg.
#  * Every changed user setting is backed up; --uninstall restores it.
#
# install-offline.sh uses this file as a library and installs the same
# packages from the local repository in ./packages.
#
# Usage: ./install.sh [OPTIONS]    (see --help)

set -Eeuo pipefail
umask 022

if [[ -z ${BASH_VERSINFO:-} ]] || (( BASH_VERSINFO[0] * 100 + BASH_VERSINFO[1] < 404 )); then
	echo "pixflat-theme: bash 4.4 or newer is required" >&2
	exit 1
fi

readonly APP_NAME="pixflat-theme"
readonly APP_VERSION="2.0.0"
readonly APP_PKG="pixflat-theme-debian"
readonly APP_SYS_STATE="/var/lib/pixflat-theme"
readonly RPI_ARCHIVE="https://archive.raspberrypi.org/debian"
readonly RPI_KEY_URL="${RPI_ARCHIVE}/raspberrypi.gpg.key"
readonly RPI_KEY_FPR="CF8A1AF502A2AA2D763BAE7E82B129927FA3303E"
readonly RPI_SUITES=(trixie bookworm bullseye buster)   # newest first
# Raspberry Pi OS package carrying the login screen wallpaper (Trixie only). It
# is downloaded and verified like the others but never installed: only the
# images and their licence are copied into pixflat-theme-debian.
readonly ART_PKG="rpd-common"
readonly ART_SUITE="trixie"
readonly DEBIAN_ARCHIVE="https://deb.debian.org/debian"
readonly DEBIAN_KEYRING="/usr/share/keyrings/debian-archive-keyring.gpg"
readonly OFFLINE_SUITES=(bullseye bookworm trixie)
# Raspberry Pi OS theme packages built per architecture but holding no compiled
# code: any Raspberry Pi OS release's build for this architecture can be used.
readonly DATA_PKGS=(pixflat-theme pixtrix-theme pix-theme)
readonly OFFLINE_ARCHES=(amd64 arm64 armhf i386)
readonly DE_SUPPORTED=(lxde lxqt xfce gnome budgie cinnamon mate openbox labwc kde)
readonly SESSION_PROCS=(lxsession xfce4-session lxqt-session gnome-shell budgie-panel
	cinnamon mate-session plasmashell labwc openbox xfwm4)

# Dependency names missing on some Debian releases, mapped to the package that
# provides them there (first available candidate wins): successors on newer
# releases, and on older ones the package the icons were split from.
declare -rA DEP_RENAMES=(
	[adwaita-icon-theme-legacy]="adwaita-icon-theme"
	[libgdk-pixbuf2.0-0]="libgdk-pixbuf-2.0-0"
	[libglib2.0-0]="libglib2.0-0t64"
	[libgtk2.0-0]="libgtk2.0-0t64"
	[libatk1.0-0]="libatk1.0-0t64"
	[libpng12-0]="libpng16-16t64 libpng16-16"
)

# Cursor names that toolkits request, mapped to equivalents that may exist in
# the official cursor themes. Missing names become symlinks to official files.
readonly CURSOR_ALIASES=(
	"default:left_ptr arrow"            "left_ptr:default arrow"
	"pointer:hand2 hand1 hand"          "hand1:pointer hand2"          "hand2:pointer hand1"
	"help:question_arrow left_ptr_help" "question_arrow:help"          "left_ptr_help:help"
	"context-menu:left_ptr"             "progress:left_ptr_watch half_busy"
	"half_busy:progress left_ptr_watch" "left_ptr_watch:progress"      "wait:watch"   "watch:wait"
	"cell:plus crosshair cross"         "crosshair:cross tcross"       "text:xterm ibeam"
	"xterm:text"                        "vertical-text:text xterm"     "copy:dnd-copy"
	"dnd-copy:copy"                     "alias:dnd-link link copy"     "link:alias dnd-link copy"
	"dnd-link:alias link copy"          "move:fleur dnd-move"          "dnd-move:move fleur"
	"fleur:move size_all all-scroll"    "all-scroll:fleur size_all move" "size_all:fleur all-scroll"
	"pointer-move:move fleur"           "not-allowed:crossed_circle forbidden no-drop"
	"no-drop:dnd-no-drop not-allowed"   "dnd-no-drop:no-drop not-allowed"
	"crossed_circle:not-allowed"        "forbidden:not-allowed"        "dnd-none:dnd-move move"
	"grab:openhand hand1"               "openhand:grab hand1"          "grabbing:closedhand closehand fleur"
	"closedhand:grabbing"               "closehand:grabbing"
	"col-resize:sb_h_double_arrow ew-resize" "row-resize:sb_v_double_arrow ns-resize"
	"ew-resize:sb_h_double_arrow h_double_arrow size_hor col-resize"
	"ns-resize:sb_v_double_arrow v_double_arrow size_ver row-resize"
	"h_double_arrow:ew-resize sb_h_double_arrow" "v_double_arrow:ns-resize sb_v_double_arrow"
	"sb_h_double_arrow:ew-resize"       "sb_v_double_arrow:ns-resize"
	"size_hor:ew-resize sb_h_double_arrow" "size_ver:ns-resize sb_v_double_arrow"
	"nesw-resize:fd_double_arrow size_bdiag ne-resize sw-resize top_right_corner"
	"nwse-resize:bd_double_arrow size_fdiag nw-resize se-resize top_left_corner"
	"fd_double_arrow:nesw-resize"       "bd_double_arrow:nwse-resize"
	"size_bdiag:nesw-resize"            "size_fdiag:nwse-resize"
	"n-resize:top_side"    "s-resize:bottom_side"    "e-resize:right_side"   "w-resize:left_side"
	"top_side:n-resize"    "bottom_side:s-resize"    "right_side:e-resize"   "left_side:w-resize"
	"ne-resize:top_right_corner"    "nw-resize:top_left_corner"
	"se-resize:bottom_right_corner" "sw-resize:bottom_left_corner"
	"top_right_corner:ne-resize"    "top_left_corner:nw-resize"
	"bottom_right_corner:se-resize" "bottom_left_corner:sw-resize"
	"left_tee:left_side"   "right_tee:right_side"   "top_tee:top_side"      "bottom_tee:bottom_side"
	"ul_angle:top_left_corner"      "ur_angle:top_right_corner"
	"ll_angle:bottom_left_corner"   "lr_angle:bottom_right_corner"
	"zoom-in:plus cell"    "zoom-out:zoom-in"
	# Hashed names used by Qt and older X11 toolkits
	"00008160000006810000408080010102:ns-resize"   "028006030e0e7ebffc7f7070c0600140:ew-resize"
	"03b6e0fcb3499374a867c041f52298f0:not-allowed" "08e8e1c95fe2fc01f976f1e063a24ccd:progress"
	"1081e37283d90000800003c07f3ef6bf:copy"        "14fef782d02440884392942c11205230:col-resize"
	"2870a09082c103050810ffdffffe0204:row-resize"  "3085a0e285430894940527032f8b26df:alias"
	"3ecb610c1bf2410f44200f48c40d3599:progress"    "4498f0e0c1937ffe01fd06f973665830:move"
	"5c6cd98b3f3ebcb1f9c7f1c204630408:help"        "6407b0e94181790501fd1e167b474872:copy"
	"640fb0e74195791501fd1ed57b41487f:alias"       "9081237383d90e509aa00f00170e968f:move"
	"9d800788f1b08800ae810202380a0822:pointer"     "a2a266d0498c3104214a47bd64ab0fc8:alias"
	"b66166c04f8c3109214a4fbd64a50fc8:copy"        "c7088f0f3e6c8088236ef8e1e3e70000:nwse-resize"
	"d9ce0ab605698f320427677b458ad60b:help"        "e29285e634086352946a0e7090d73106:pointer"
	"fcf1c3c7cd4491d801f1e1c78f100000:nesw-resize"
)

# Icon names Debian's panel applets request, mapped to the Raspberry Pi OS icons
# its own panel plugins show, so the notification area looks the same: sound
# (lxpanel volume), network (nm-applet) and Bluetooth (blueman). Missing names
# become symlinks to official images; a leading "!" also overrides the name
# where the theme maps it to something Raspberry Pi OS's panel does not show.
# Secure connections show the plain signal icon, as on Raspberry Pi OS.
readonly ICON_ALIASES=(
	"audio-volume-high-panel:audio-volume-high"     "audio-volume-medium-panel:audio-volume-medium"
	"audio-volume-low-panel:audio-volume-low"       "audio-volume-muted-panel:audio-volume-muted"
	"nm-secure-lock:network-wireless-encrypted"    "nm-device-wired-secure:nm-device-wired"
	"nm-signal-00-secure:nm-signal-00"              "nm-signal-25-secure:nm-signal-25"
	"nm-signal-50-secure:nm-signal-50"              "nm-signal-75-secure:nm-signal-75"
	"nm-signal-100-secure:nm-signal-100"
	"inode-directory:folder"                        "folder-open:folder"
	"media-optical:media-removable"                 "drive-optical:media-removable"
	"drive-removable-media:media-removable"         "media-flash:media-removable"
	"network-wired:network-transmit-receive"        "network-wireless:network-wireless-connected-100"
	"network-workgroup:network"                     "network-server:network"
	"blueman:bluetooth-active"                      "blueman-tray:bluetooth-active"
	"blueman-active:bluetooth-online"               "blueman-disabled:bluetooth-offline"
	"bluetooth-symbolic:bluetooth-active"           "!bluetooth-disabled:bluetooth-offline"
	"!bluetooth-disabled-symbolic:bluetooth-offline" "bluetooth-disconnected-symbolic:bluetooth-inactive"
)

# ---------------------------------------------------------------------------
# Options (O_*), theme (T_*), session (S_*) and host (H_*) state
# ---------------------------------------------------------------------------
O_ACTION="install"      # install | check | uninstall | update-packages
O_REPO=""              # offline repository; set by install-offline.sh
O_THEME=""              # theme to apply; empty = ask at the end
O_ICONS=""              # icon set to apply; empty = the theme's own
O_ONLY=""               # install only this theme family; empty = all
O_DESKTOPS="auto"
O_USER=""
O_SUITE=""
O_WALLPAPER=""
O_WITH_WALLPAPER=1
O_4K=0
O_PANEL=1
O_GTK4=1
O_PI_PANEL=0            # 1 when Raspberry Pi's own panel (lxpanel-pi) is used
O_FM=1
O_PI_FM=0               # 1 when Raspberry Pi's own file manager is used
O_WITH_FONT=1
O_LIGHTDM=-1           # -1 = when Debian's LightDM GTK greeter is installed
O_QT=0
O_DO_INSTALL=1
O_DO_APPLY=1
O_YES=0
O_DRY_RUN=0
O_VERBOSE=0
O_INTERACTIVE=0

S_USER="" S_UID="" S_HOME="" S_PROC="" S_DBUS="" S_DISPLAY="" S_WAYLAND="" S_XAUTH=""
S_RUNTIME="" S_XDG_DESKTOP="" S_DESKTOP_SESSION=""
H_ARCH="" H_ID="" H_LIKE="" H_CODENAME="" H_PRETTY="" H_SUITE=""
DESKTOPS=()
FETCH_PKGS=()           # installed from verified .deb files
DEP_PKGS=()             # of those, offline, the ones installed only as dependencies
APT_PKGS=()             # installed by name from the APT sources
declare -A PKG_VER=() PKG_FILE=() PKG_SHA=() PKG_SIZE=() PKG_SUITE=() PKG_AID=()
declare -A IDX_LOADED=() IDX_FAILED=() IN_SET=()
WORKDIR="" KEYRING="" DEP_INDEX="" BUILD_STAGE="" LOG_FILE=""
ARGV=()
SYS_ROOT=""             # filesystem root the package builder reads themes from (tests)

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------
C_B="" C_D="" C_R="" C_G="" C_Y="" C_BL="" C_0=""

# Enable colours when stderr is a terminal and NO_COLOR is unset.
init_colors() {
	if [[ -t 2 && -z ${NO_COLOR:-} && ${TERM:-dumb} != dumb ]]; then
		C_B=$'\e[1m' C_D=$'\e[2m' C_R=$'\e[31m' C_G=$'\e[32m' C_Y=$'\e[33m' C_BL=$'\e[34m' C_0=$'\e[0m'
	fi
}
# Messages, all on stderr: plain, information, success, warning, fatal error,
# section heading and verbose-only detail.
log()   { printf '%s\n' "$*" >&2; }
info()  { printf '%s::%s %s\n' "$C_BL" "$C_0" "$*" >&2; }
ok()    { printf '%s✔%s %s\n' "$C_G" "$C_0" "$*" >&2; }
warn()  { printf '%s!%s %s\n' "$C_Y" "$C_0" "$*" >&2; }
die()   { printf '%s✘ error:%s %s\n' "$C_R" "$C_0" "$*" >&2; exit 1; }
step()  { printf '\n%s==>%s %s%s%s\n' "$C_BL" "$C_0" "$C_B" "$*" "$C_0" >&2; }
debug() { if (( O_VERBOSE )); then printf '%s   %s%s\n' "$C_D" "$*" "$C_0" >&2; fi; }

# Quote arguments for display.
_q() { local a out=""; for a; do out+="${out:+ }$(printf '%q' "$a")"; done; printf '%s' "$out"; }

# Run a command; in dry-run mode, only print it.
run() {
	if (( O_DRY_RUN )); then printf '%s   [dry-run] %s%s\n' "$C_D" "$(_q "$@")" "$C_0" >&2; return 0; fi
	debug "$(_q "$@")"
	"$@"
}
# Run a command as root, through sudo when needed.
as_root() { if (( EUID == 0 )); then run "$@"; else run sudo -- "$@"; fi; }

# Ask a yes/no question; without a terminal, return the default.
# Usage: ask QUESTION y|n
ask() {
	local q=$1 def=$2 ans hint="[y/N]"
	[[ $def == y ]] && hint="[Y/n]"
	if (( ! O_INTERACTIVE )); then [[ $def == y ]]; return; fi
	read -r -p "$(printf '%s?%s %s %s ' "$C_BL" "$C_0" "$q" "$hint")" ans </dev/tty || ans=""
	ans=${ans,,}
	[[ -z $ans ]] && ans=$def
	[[ $ans == y || $ans == yes ]]
}

# Format a byte count, e.g. 27MB.
human_size() { numfmt --to=iec --suffix=B "${1:-0}" 2>/dev/null || printf '%s bytes' "${1:-0}"; }

# Print the command that runs this installer again.
_self_cmd() {
	if [[ -f $0 ]]; then printf '%s\n' "$0"; else printf 'install.sh\n'; fi
}

# Print the help text.
usage() {
	local self mode
	self=$(basename -- "$(_self_cmd)")
	if [[ -n $O_REPO ]]; then mode="Offline installer: installs from ./packages, no network needed."
	else mode="Online installer: downloads the latest official packages."; fi
	cat <<EOF
${APP_NAME} ${APP_VERSION} — the Raspberry Pi OS desktop look for Debian
${mode}

Usage: ${self} [OPTIONS]

Installs every theme compatible with this Debian release, then asks which look
to apply. Detected automatically: Debian release, architecture, user, desktop.

Themes:
  pixflat   Light, Raspberry Pi OS Bookworm (PiXflat + Piboto)     default on Debian 12
  pixnoir   Dark,  Raspberry Pi OS Bookworm (PiXnoir + Piboto)
  pixtrix   Light, Raspberry Pi OS Trixie   (PiXtrix + Nunito Sans) default on Debian 13+
  pixonyx   Dark,  Raspberry Pi OS Trixie   (PiXonyx + Nunito Sans)
  pix       Legacy Raspberry Pi OS Buster/Bullseye look (PiX)

Options:
  -t, --theme NAME        Theme to apply, without asking.
      --icons NAME        Icon set to apply: pixflat, pixtrix or pix
                          (default: the theme's own).
      --only NAME         Install only this theme's family, not all themes.
  -d, --desktop LIST      Desktops to configure instead of the detected one: all,
                          none, or a comma list of: ${DE_SUPPORTED[*]}
  -u, --user NAME         User whose desktop is configured (default: the user
                          running the script, or \$SUDO_USER under sudo).
      --wallpaper W       Wallpaper file name in /usr/share/rpd-wallpaper, or a path.
      --no-wallpaper      Do not install or set the Raspberry Pi wallpapers.
      --4k                Use the 4K (3840x2160) wallpaper set instead (about 100 MB).
      --no-font           Do not install or set the Raspberry Pi UI font.
      --no-panel          Keep your panel and application menu (default: the
                          Raspberry Pi OS layout).
      --no-file-manager   Keep Debian's file manager for the desktop and folders
                          (default: Raspberry Pi's, installed beside it on Debian 13).
      --no-gtk4           Do not add the theme colours for GTK 4/libadwaita applications.
      --no-lightdm        Keep the login screen as it is (default: the Raspberry Pi
                          OS style, when the LightDM GTK greeter is installed).
      --qt                Make Qt applications follow the GTK theme.
      --suite NAME        Raspberry Pi OS release to take packages from
                          (default: matched to this system; bookworm, trixie, ...).
      --install-only      Install system packages only, do not change settings.
      --apply-only        Only choose and apply a look (themes already installed).
      --check             Show available updates for the installed packages; change nothing.
      --uninstall         Restore the previous settings and remove what was installed.
EOF
	if [[ -n $O_REPO ]]; then cat <<EOF
      --update-packages   Rebuild ./packages from the official repositories
                          (needs internet; run it on a connected machine).
EOF
	fi
	cat <<EOF
  -y, --yes               Non-interactive; accept the defaults.
  -n, --dry-run           Show what would be done without changing anything.
  -v, --verbose           Print every command.
  -h, --help              Show this help.
  -V, --version           Show the version.

Examples:
  ./${self}                        install all themes, then choose the look
  ./${self} -y                     no questions: the theme matching this Debian
  ./${self} -t pixnoir --icons pixtrix   a specific look, without asking
  ./${self} --apply-only           switch the look later
  ./${self} --check                list available updates
  ./${self} --uninstall            undo everything
EOF
}

# Parse the command line into the O_* options.
parse_args() {
	local opt val
	while (( $# )); do
		opt=$1 val=""
		if [[ $opt == --*=* ]]; then val=${opt#*=}; opt=${opt%%=*}; set -- "$opt" "$val" "${@:2}"; fi
		case $opt in
			-t|--theme)     (( $# >= 2 )) || die "$opt needs a value"; O_THEME=${2,,}; shift ;;
			--icons)        (( $# >= 2 )) || die "$opt needs a value"; O_ICONS=${2,,}; shift ;;
			--only)         (( $# >= 2 )) || die "$opt needs a value"; O_ONLY=${2,,}; shift ;;
			-d|--desktop)   (( $# >= 2 )) || die "$opt needs a value"; O_DESKTOPS=${2,,}; shift ;;
			-u|--user)      (( $# >= 2 )) || die "$opt needs a value"; O_USER=$2; shift ;;
			--suite)        (( $# >= 2 )) || die "$opt needs a value"; O_SUITE=${2,,}; shift ;;
			--wallpaper)    (( $# >= 2 )) || die "$opt needs a value"; O_WALLPAPER=$2; shift ;;
			--no-wallpaper) O_WITH_WALLPAPER=0 ;;
			--4k)           O_4K=1 ;;
			--no-font)      O_WITH_FONT=0 ;;
			--no-panel)     O_PANEL=0 ;;
			--no-file-manager) O_FM=0 ;;
			--no-gtk4)      O_GTK4=0 ;;
			--no-lightdm)   O_LIGHTDM=0 ;;
			--qt)           O_QT=1 ;;
			--install-only) O_DO_APPLY=0 ;;
			--apply-only)   O_DO_INSTALL=0 ;;
			--check)        O_ACTION=check ;;
			--uninstall|--remove) O_ACTION=uninstall ;;
			--update-packages)
				[[ -n $O_REPO ]] || die "--update-packages belongs to install-offline.sh"
				O_ACTION=update-packages ;;
			-y|--yes)       O_YES=1 ;;
			-n|--dry-run)   O_DRY_RUN=1 ;;
			-v|--verbose)   O_VERBOSE=1 ;;
			-h|--help)      usage; exit 0 ;;
			-V|--version)   echo "$APP_NAME $APP_VERSION"; exit 0 ;;
			*) die "unknown option: $opt (see --help)" ;;
		esac
		shift
	done
	(( O_DO_INSTALL || O_DO_APPLY )) || die "--install-only and --apply-only are mutually exclusive"
	local t
	for t in "$O_THEME" "$O_ONLY"; do
		case $t in ""|pixflat|pixnoir|pixtrix|pixonyx|pix) ;; *) die "unknown theme '$t' (see --help)" ;; esac
	done
	case $O_ICONS in ""|pixflat|pixtrix|pix) ;; *) die "unknown icon set '$O_ICONS' (use pixflat, pixtrix or pix)" ;; esac
	if [[ -n $O_SUITE ]] && ! _suite_rank "$O_SUITE" >/dev/null; then
		die "unsupported suite '$O_SUITE' (use one of: ${RPI_SUITES[*]})"
	fi
	if (( ! O_YES )) && { : </dev/tty; } 2>/dev/null; then O_INTERACTIVE=1; fi
}

# ---------------------------------------------------------------------------
# Theme definitions
# ---------------------------------------------------------------------------
# Set the T_* variables for a theme. --icons may choose another icon set.
set_theme() {
	# T_GTK names the GTK theme and the Openbox, labwc and Xfwm4 themes alike
	case $1 in
		pixflat) T_GTK=PiXflat T_ICON_BASE=PiXflat T_ERA=bookworm T_DARK=0
		         T_DESC="PiXflat — light, Raspberry Pi OS Bookworm" ;;
		pixnoir) T_GTK=PiXnoir T_ICON_BASE=PiXflat T_ERA=bookworm T_DARK=1
		         T_DESC="PiXnoir — dark, Raspberry Pi OS Bookworm" ;;
		pixtrix) T_GTK=PiXtrix T_ICON_BASE=PiXtrix T_ERA=trixie T_DARK=0
		         T_DESC="PiXtrix — light, Raspberry Pi OS Trixie" ;;
		pixonyx) T_GTK=PiXonyx T_ICON_BASE=PiXtrix T_ERA=trixie T_DARK=1
		         T_DESC="PiXonyx — dark, Raspberry Pi OS Trixie" ;;
		pix)     T_GTK=PiX T_ICON_BASE=PiX T_ERA=legacy T_DARK=0
		         T_DESC="PiX — legacy Raspberry Pi OS Buster/Bullseye" ;;
		*) die "unknown theme '$1'" ;;
	esac
	if [[ $T_ERA == trixie ]]; then
		T_FONT_FAMILY="Nunito Sans" T_FONT_WEIGHT=Light T_FONT="Nunito Sans Light 12" T_WALL_DEFAULT=sunrise.jpg
	else
		T_FONT_FAMILY=PibotoLt T_FONT_WEIGHT=Normal T_FONT="PibotoLt 12" T_WALL_DEFAULT=fisherman.jpg
	fi
	case $O_ICONS in pixflat) T_ICON_BASE=PiXflat ;; pixtrix) T_ICON_BASE=PiXtrix ;; pix) T_ICON_BASE=PiX ;; esac
	# Values used by Raspberry Pi OS itself (raspberrypi-ui-mods / rpd-common)
	T_COLOR_SCHEME='selected_bg_color:#878791919b9b\nselected_fg_color:#f0f0f0f0f0f0\nbar_bg_color:#ededececebeb\nbar_fg_color:#000000000000\n'
	T_DESK_BG="#d6d6d3d3dede" T_DESK_FG="#e8e8e8e8e8e8" T_DESK_SHADOW="#d6d6d3d3dede"
	T_CURSOR_SIZE=24
	T_SOUND_THEME=freedesktop   # Raspberry Pi OS enables event sounds with the default theme
	if (( ! O_WITH_FONT )); then T_FONT="" T_FONT_FAMILY=""; fi
}

# Print the Raspberry Pi OS package that provides a theme or an icon set.
_theme_pkg() {
	case $1 in
		pixflat|pixnoir) echo pixflat-theme ;;
		pixtrix|pixonyx) echo pixtrix-theme ;;
		pix)             echo pix-theme ;;
	esac
}
_icons_pkg() { case $1 in pixflat) echo pixflat-icons ;; pixtrix) echo pixtrix-icons ;; pix) echo rpd-icons ;; esac; }

# Print the Raspberry Pi OS packages one theme family needs (--only).
_family_pkgs() {
	case $1 in
		pixflat|pixnoir) echo pixflat-theme pixflat-icons gtk2-engines-pixflat fonts-piboto rpd-wallpaper rpd-wallpaper-4k pi-greeter ;;
		pixtrix|pixonyx) echo pixtrix-theme pixtrix-icons gtk2-engines-pixflat fonts-nunito-sans rpd-wallpaper-trixie rpd-wallpaper-trixie-4k pi-greeter ;;
		pix)             echo pix-theme rpd-icons gtk2-engines-clearlookspix fonts-piboto rpd-wallpaper rpd-wallpaper-4k pi-greeter ;;
	esac
}

# Raspberry Pi OS packages the offline repository carries for a release: every
# theme, and Raspberry Pi's panel (built for Debian 13) on Debian 13.
_bundle_rpi_pkgs() {
	printf '%s\n' pixflat-theme pixflat-icons gtk2-engines-pixflat fonts-piboto rpd-wallpaper \
		rpd-wallpaper-4k pix-theme rpd-icons gtk2-engines-clearlookspix pi-greeter \
		pixtrix-theme pixtrix-icons fonts-nunito-sans rpd-wallpaper-trixie rpd-wallpaper-trixie-4k
	if (( $(_suite_rank "$1") >= 3 )); then _pi_panel_pkgs; _pi_fm_pkgs "$1"; fi
}
# Raspberry Pi's own file manager, which draws the desktop and the folder
# windows of Raspberry Pi OS. It is built for Debian 13 only, and is installed
# beside Debian's file manager, never in its place (see fm_coinstall).
_pi_fm_pkgs() {
	if (( $(_suite_rank "$1") >= 3 )); then printf '%s\n' pcmanfm-pi; fi
}
# Raspberry Pi's own panel (Debian 13 and later) with the plugins that work on
# Debian, its Shutdown dialog (log out, reboot, shut down; at the end of the
# menu) and its Run dialog (in Accessories). Left out: updater and power (need
# Raspberry Pi system tools or hardware) and network (needs a Raspberry Pi
# rebuild of a Debian library; nm-applet shows the same icons in the tray).
_pi_panel_pkgs() {
	printf '%s\n' lxpanel-pi lpplug-menu lpplug-volumepulse lpplug-bluetooth lpplug-magnifier \
		lpplug-ejecter pplug-ejecter-data lpplug-clock lpplug-batt pishutdown gui-runcmd
}

# Debian packages the themes need; the builder adds their missing dependencies.
_bundle_deb_pkgs() {
	printf '%s\n' gtk2-engines-pixbuf libgtk2.0-bin gnome-icon-theme sound-theme-freedesktop "$(_mono_font_pkg "$1")" \
		"$(_nm_applet_pkg "$1")" debian-reference-common debian-reference-en
	# blueman only where Debian's panel is used; Raspberry Pi's panel (Debian 13)
	# has its own Bluetooth plugin
	if (( $(_suite_rank "$1") >= 3 )); then printf '%s\n' adwaita-icon-theme-legacy; else printf '%s\n' blueman; fi
}
# Debian package providing nm-applet (network-manager-gnome is transitional
# from Debian 13).
_nm_applet_pkg() { if (( $(_suite_rank "$1") < 3 )); then echo network-manager-gnome; else echo network-manager-applet; fi; }
# Debian package providing Liberation Mono, the Raspberry Pi OS monospace font.
_mono_font_pkg() { if (( $(_suite_rank "$1") < 3 )); then echo fonts-liberation2; else echo fonts-liberation; fi; }

# ---------------------------------------------------------------------------
# Host, user and desktop detection
# ---------------------------------------------------------------------------
# Print the age rank of a release (higher is newer); fail if unknown.
_suite_rank() {
	case $1 in buster) echo 0 ;; bullseye) echo 1 ;; bookworm) echo 2 ;; trixie) echo 3 ;; *) return 1 ;; esac
}

# Print a field of /etc/os-release.
_os_release() { sed -n "s/^$1=//p" /etc/os-release | head -n1 | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'\$//"; }

# Succeed if APT knows a package, or a package providing it.
apt_has() {
	local out
	out=$(LC_ALL=C apt-cache showpkg "$1" 2>/dev/null) || return 1
	awk '
		/^Versions:/          { s = "v";  next }
		/^Reverse Provides:/  { s = "rp"; next }
		/^[A-Z][A-Za-z ]*:/   { s = "";   next }
		(s == "v" || s == "rp") && NF { found = 1 }
		END { exit !found }' <<<"$out"
}

# Detect the architecture and the distribution.
detect_host() {
	if ! command -v dpkg >/dev/null || ! command -v apt-get >/dev/null; then
		die "this installer needs a Debian-based system (dpkg/apt not found)"
	fi
	H_ARCH=$(dpkg --print-architecture)
	if [[ -r /etc/os-release ]]; then
		H_ID=$(_os_release ID)
		H_LIKE=$(_os_release ID_LIKE)
		H_CODENAME=$(_os_release VERSION_CODENAME)
		H_PRETTY=$(_os_release PRETTY_NAME)
	fi
	if [[ $H_ID != debian && " $H_LIKE " != *" debian "* && " $H_LIKE " != *" ubuntu "* ]]; then
		warn "untested distribution '${H_PRETTY:-unknown}', continuing anyway"
	fi
}

# Choose the Raspberry Pi OS release that matches this system.
pick_suite() {
	case $H_ARCH in
		amd64|arm64|armhf|i386) ;;
		*) die "architecture '$H_ARCH' is not published by archive.raspberrypi.org (amd64, arm64, armhf, i386)" ;;
	esac
	H_SUITE=${O_SUITE:-$(_host_suite)} || die "cannot determine a matching Raspberry Pi OS release; use --suite"
	if [[ -n $O_REPO && ! -d $O_REPO/dists/$H_SUITE/main/binary-$H_ARCH ]]; then
		die "the offline repository has no packages for $H_SUITE/$H_ARCH (it has: $(_repo_contents))"
	fi
}

# Print the Raspberry Pi OS release matching this system; fail if unknown.
_host_suite() {
	case $H_CODENAME in
		buster|bullseye|bookworm|trixie) echo "$H_CODENAME" ;;
		forky|duke|sid)                  echo trixie ;;
		*)  # Derivatives: match by ABI generation (64-bit time_t transition)
			if apt_has libglib2.0-0t64; then echo trixie
			elif apt_has libglib2.0-0; then echo bookworm
			else return 1; fi ;;
	esac
}

# Print the theme matching this Debian release: the Raspberry Pi OS Trixie look
# (PiXtrix) on Debian 13 and newer, the Bookworm look (PiXflat) otherwise.
_default_theme() {
	local suite=${H_SUITE:-$(_host_suite || echo bookworm)}
	if (( $(_suite_rank "$suite" 2>/dev/null || echo 0) >= 3 )); then echo pixtrix; else echo pixflat; fi
}

# Determine the user whose desktop is configured.
resolve_user() {
	if [[ -n $O_USER ]]; then
		S_USER=$O_USER
	elif (( EUID == 0 )); then
		S_USER=${SUDO_USER:-}
		if [[ -z $S_USER && -n ${PKEXEC_UID:-} ]]; then S_USER=$(id -nu "$PKEXEC_UID" 2>/dev/null || true); fi
		[[ $S_USER == root ]] && S_USER=""
	else
		S_USER=$(id -un)
	fi
	[[ -n $S_USER ]] || return 0
	local ent
	ent=$(getent passwd "$S_USER") || die "unknown user '$S_USER'"
	S_UID=$(cut -d: -f3 <<<"$ent")
	S_HOME=$(cut -d: -f6 <<<"$ent")
	[[ -d $S_HOME ]] || die "home directory of '$S_USER' ($S_HOME) does not exist"
	if (( EUID != 0 && EUID != S_UID )); then
		die "configuring another user's desktop requires root (run with sudo)"
	fi
}

# Read the target user's session environment, so settings apply live even
# through sudo or SSH.
find_session_env() {
	[[ -n $S_USER ]] || return 0
	if (( EUID == S_UID )); then
		S_DBUS=${DBUS_SESSION_BUS_ADDRESS:-} S_DISPLAY=${DISPLAY:-} S_WAYLAND=${WAYLAND_DISPLAY:-}
		S_XAUTH=${XAUTHORITY:-} S_RUNTIME=${XDG_RUNTIME_DIR:-}
		S_XDG_DESKTOP=${XDG_CURRENT_DESKTOP:-} S_DESKTOP_SESSION=${DESKTOP_SESSION:-}
	fi
	local p pid="" line
	if command -v pgrep >/dev/null; then
		for p in "${SESSION_PROCS[@]}"; do
			pid=$(pgrep -u "$S_UID" -n -x "$p" 2>/dev/null || true)
			if [[ -n $pid ]]; then S_PROC=$p; break; fi
		done
	fi
	if [[ -n $pid ]]; then   # unreadable for protected processes: then nothing is read
		while IFS= read -r -d '' line; do
			case $line in
				DBUS_SESSION_BUS_ADDRESS=*) [[ -n $S_DBUS ]]    || S_DBUS=${line#*=} ;;
				DISPLAY=*)                  [[ -n $S_DISPLAY ]] || S_DISPLAY=${line#*=} ;;
				WAYLAND_DISPLAY=*)          [[ -n $S_WAYLAND ]] || S_WAYLAND=${line#*=} ;;
				XAUTHORITY=*)               [[ -n $S_XAUTH ]]   || S_XAUTH=${line#*=} ;;
				XDG_RUNTIME_DIR=*)          [[ -n $S_RUNTIME ]] || S_RUNTIME=${line#*=} ;;
				XDG_CURRENT_DESKTOP=*)      [[ -n $S_XDG_DESKTOP ]] || S_XDG_DESKTOP=${line#*=} ;;
				DESKTOP_SESSION=*)          [[ -n $S_DESKTOP_SESSION ]] || S_DESKTOP_SESSION=${line#*=} ;;
			esac
		done < <(cat -- "/proc/$pid/environ" 2>/dev/null || true)
	fi
	if [[ -z $S_RUNTIME && -d /run/user/$S_UID ]]; then S_RUNTIME=/run/user/$S_UID; fi
	if [[ -z $S_DBUS && -n $S_RUNTIME && -S $S_RUNTIME/bus ]]; then S_DBUS="unix:path=$S_RUNTIME/bus"; fi
}

# Map a session or process name to a supported desktop.
_map_desktop() {
	case ${1,,} in
		lxde|lxde-pi*|lxsession)                 echo lxde ;;
		lxqt|lxqt-session)                       echo lxqt ;;
		xfce|xfce4|xfce4-session|xfwm4|xubuntu)  echo xfce ;;
		budgie*)                                 echo budgie ;;
		gnome*|ubuntu*|pop|unity)                echo gnome ;;
		x-cinnamon|cinnamon*)                    echo cinnamon ;;
		mate*)                                   echo mate ;;
		kde|plasma*)                             echo kde ;;
		labwc*)                                  echo labwc ;;
		openbox*)                                echo openbox ;;
		*) return 1 ;;
	esac
}

# List the supported desktops that have an installed session.
_installed_desktops() {
	local f names n de
	for f in /usr/share/xsessions/*.desktop /usr/share/wayland-sessions/*.desktop; do
		[[ -e $f ]] || continue
		names=$(sed -n 's/^DesktopNames=//p' "$f" | head -n1)
		for n in ${names//;/ } "$(basename "$f" .desktop)"; do
			if de=$(_map_desktop "$n"); then echo "$de"; break; fi
		done
	done | awk '!seen[$0]++'
}

# Choose the desktops to configure: requested, running, or installed.
detect_desktops() {
	DESKTOPS=()
	local tok de
	case $O_DESKTOPS in
		none) return 0 ;;
		all)  mapfile -t DESKTOPS < <(_installed_desktops); return 0 ;;
		auto) ;;
		*)
			for tok in ${O_DESKTOPS//,/ }; do
				[[ " ${DE_SUPPORTED[*]} " == *" $tok "* ]] || die "unsupported desktop '$tok' (supported: ${DE_SUPPORTED[*]})"
				[[ " ${DESKTOPS[*]} " == *" $tok "* ]] || DESKTOPS+=("$tok")
			done
			return 0 ;;
	esac
	for tok in ${S_XDG_DESKTOP//:/ }; do
		if de=$(_map_desktop "$tok"); then DESKTOPS=("$de"); return 0; fi
	done
	if [[ -n $S_PROC ]] && de=$(_map_desktop "$S_PROC"); then DESKTOPS=("$de"); return 0; fi
	mapfile -t DESKTOPS < <(_installed_desktops)
}

# ---------------------------------------------------------------------------
# Repositories: signed indexes, package resolution, download, verification.
# Archive identifiers:
#   rpi     archive.raspberrypi.org, checked against the pinned key
#   debian  deb.debian.org, checked against debian-archive-keyring
#   local   the offline repository in ./packages, checked by SHA256SUMS
# ---------------------------------------------------------------------------

# Print the base URL or path of an archive.
_archive_url() {
	case $1 in rpi) printf '%s\n' "$RPI_ARCHIVE" ;; debian) printf '%s\n' "$DEBIAN_ARCHIVE" ;; local) printf '%s\n' "$O_REPO" ;; esac
}

# Download from an official archive (or copy a local path). Only HTTPS URLs of
# the Raspberry Pi and Debian archives are accepted, and redirects are refused,
# so nothing can come from another host.
# Usage: fetch URL|PATH OUTPUT [SHOW-PROGRESS]
fetch() {
	local url=$1 out=$2 progress=${3:-0}
	if [[ $url == /* ]]; then cp -- "$url" "$out"; return; fi
	[[ $url == "$RPI_ARCHIVE"/* || $url == "$DEBIAN_ARCHIVE"/* ]] || die "refusing to download from an unofficial source: $url"
	debug "GET $url"
	if command -v curl >/dev/null; then
		local -a a=(-f --proto '=https' --max-redirs 0 --retry 3 --retry-delay 2 --connect-timeout 20 -o "$out")
		if (( progress )) && [[ -t 2 ]]; then a+=(--progress-bar); else a+=(-sS); fi
		curl "${a[@]}" "$url"
	elif command -v wget >/dev/null; then
		local -a a=(--https-only --max-redirect=0 --tries=3 --timeout=20 -O "$out")
		if (( progress )) && [[ -t 2 ]]; then a+=(-q --show-progress); else a+=(-q); fi
		wget "${a[@]}" "$url"
	else
		die "curl or wget is required"
	fi
}

# Stop unless a file has the expected SHA256.
sha256_check() {
	local got
	got=$(sha256sum "$1" | cut -d' ' -f1)
	[[ $got == "$2" ]] || die "checksum mismatch for $(basename "$1") (expected $2, got $got)"
}

# Fetch the Raspberry Pi archive key and convert it to a gpgv keyring.
setup_keyring() {
	[[ -n $KEYRING ]] && return 0
	fetch "$RPI_KEY_URL" "$WORKDIR/rpi.asc" || die "cannot download the Raspberry Pi archive key from $RPI_KEY_URL"
	# Dearmor without gpg: decode the base64 body of the armored key.
	awk '/^-----BEGIN PGP PUBLIC KEY BLOCK-----/ { b = 1; next }
		/^-----END PGP PUBLIC KEY BLOCK-----/ { b = 0 }
		b { sub(/\r$/, "") } b && NF && !/^[A-Za-z-]+: / && !/^=/' "$WORKDIR/rpi.asc" \
		| base64 -d >"$WORKDIR/rpi.gpg" 2>/dev/null || die "could not decode the Raspberry Pi archive key"
	[[ -s $WORKDIR/rpi.gpg ]] || die "the Raspberry Pi archive key is empty"
	KEYRING=$WORKDIR/rpi.gpg
}

# Verify an InRelease file and write its signed content. Raspberry Pi indexes
# must be signed by the pinned key, Debian indexes by debian-archive-keyring.
# Usage: verify_inrelease ARCHIVE IN OUT
verify_inrelease() {
	local aid=$1 in=$2 out=$3 status keyring fpr
	if [[ $aid == rpi ]]; then keyring=$KEYRING; else keyring=$DEBIAN_KEYRING; fi
	rm -f -- "$out"
	status=$(gpgv --status-fd 1 --keyring "$keyring" --output "$out" "$in" 2>/dev/null) || true
	if grep -qE '^\[GNUPG:\] (BADSIG|EXPSIG|REVKEYSIG)' <<<"$status" || ! grep -q '^\[GNUPG:\] VALIDSIG' <<<"$status"; then
		die "signature verification failed for $in"
	fi
	if [[ $aid == rpi ]]; then
		fpr=$(awk '$2 == "VALIDSIG" { print $NF }' <<<"$status")
		grep -qxi "$RPI_KEY_FPR" <<<"$fpr" || die "$in is not signed by the Raspberry Pi archive key"
	fi
	[[ -s $out ]] || die "no signed content in $in"
}

# Load and verify the package index of an archive, release and architecture.
# Usage: index_load ARCHIVE SUITE ARCH
index_load() {
	local aid=$1 suite=$2 arch=$3 key="$1/$2/$3" d="$WORKDIR/index/$1/$2" base comp="" sha="" c
	[[ -n ${IDX_LOADED[$key]:-} ]] && return 0
	[[ -z ${IDX_FAILED[$key]:-} ]] || return 1
	mkdir -p "$d"
	base=$(_archive_url "$aid")
	debug "loading $key index"
	if [[ $aid == local ]]; then
		if [[ ! -f $base/dists/$suite/main/binary-$arch/Packages ]]; then IDX_FAILED[$key]=1; return 1; fi
		cp -- "$base/dists/$suite/main/binary-$arch/Packages" "$d/Packages-$arch"
		IDX_LOADED[$key]=1
		return 0
	fi
	if [[ ! -f $d/Release ]]; then
		if ! fetch "$base/dists/$suite/InRelease" "$d/InRelease"; then IDX_FAILED[$key]=1; return 1; fi
		verify_inrelease "$aid" "$d/InRelease" "$d/Release"
	fi
	for c in xz gz; do
		[[ $c == xz ]] && ! command -v xz >/dev/null && continue
		sha=$(awk -v f="main/binary-$arch/Packages.$c" '
			/^SHA256:/ { s = 1; next } /^[^ ]/ { s = 0 } s && $3 == f { print $1; exit }' "$d/Release")
		if [[ -n $sha ]]; then comp=$c; break; fi
	done
	if [[ -z $comp ]]; then debug "no $arch index in $aid/$suite"; IDX_FAILED[$key]=1; return 1; fi
	fetch "$base/dists/$suite/main/binary-$arch/Packages.$comp" "$d/Packages-$arch.$comp" \
		|| die "cannot download the $suite/$arch package index from $base"
	sha256_check "$d/Packages-$arch.$comp" "$sha"
	if [[ $comp == xz ]]; then xz -dc "$d/Packages-$arch.$comp"; else gzip -dc "$d/Packages-$arch.$comp"; fi >"$d/Packages-$arch"
	rm -f -- "$d/Packages-$arch.$comp"
	IDX_LOADED[$key]=1
}

# Print "version<TAB>arch<TAB>filename<TAB>sha256<TAB>size<TAB>depends" for every
# version of a package in one index, newest first.
# Usage: index_candidates ARCHIVE SUITE ARCH PACKAGE
index_candidates() {
	local aid=$1 suite=$2 arch=$3 pkg=$4 line v i
	local -a lines=()
	while IFS= read -r line; do
		v=${line%%$'\t'*}
		for (( i = ${#lines[@]}; i > 0; i-- )); do
			dpkg --compare-versions "$v" gt "${lines[i-1]%%$'\t'*}" || break
			lines[i]=${lines[i-1]}
		done
		lines[i]=$line
	done < <(awk -v p="$pkg" 'BEGIN { RS = ""; FS = "\n" }
		{
			n = v = a = f = s = z = d = ""
			for (i = 1; i <= NF; i++) {
				if ($i ~ /^Package: /)                n = substr($i, 10)
				else if ($i ~ /^Version: /)           v = substr($i, 10)
				else if ($i ~ /^Architecture: /)      a = substr($i, 15)
				else if ($i ~ /^Filename: /)          f = substr($i, 11)
				else if ($i ~ /^SHA256: /)            s = substr($i, 9)
				else if ($i ~ /^Size: /)              z = substr($i, 7)
				else if ($i ~ /^(Pre-)?Depends: /)    { x = $i; sub(/^[^:]*: /, "", x); d = d (d == "" ? "" : ", ") x }
			}
			if (n == p && f != "" && s != "") print v "\t" a "\t" f "\t" s "\t" z "\t" d
		}' "$WORKDIR/index/$aid/$suite/Packages-$arch")
	if (( ${#lines[@]} )); then printf '%s\n' "${lines[@]}"; fi
}

# Compare two Debian versions with a Depends operator (<<, <=, =, >=, >>).
_vcmp() {
	local op
	case $2 in '<<') op=lt ;; '<='|'<') op=le ;; '=') op=eq ;; '>='|'>') op=ge ;; '>>') op=gt ;; *) return 1 ;; esac
	dpkg --compare-versions "$1" "$op" "$3"
}

# Set AV to the versions of a package available on the target: the install
# set, the installed version and APT candidate, or, when building ./packages,
# the Debian index. "*" stands for a virtual package of unknown version.
declare -A AVAIL=()
_avail() {
	local n=$1
	if [[ -z ${AVAIL[$n]+set} ]]; then
		if [[ -n ${IN_SET[$n]:-} ]]; then
			AVAIL[$n]=${PKG_VER[$n]:-*}
		elif [[ -n $DEP_INDEX ]]; then
			AVAIL[$n]=$(awk -v n="$n" '$1 == n { print ($2 == "" ? "*" : $2) }' "$DEP_INDEX" | paste -sd' ' -)
		else
			AVAIL[$n]=$(printf '%s %s' "$(_installed_version "$n")" \
				"$(LC_ALL=C apt-cache policy "$n" 2>/dev/null | awk '/Candidate:/ && $2 != "(none)" { print $2 }')" | xargs)
			if [[ -z ${AVAIL[$n]} ]] && apt_has "$n"; then AVAIL[$n]="*"; fi
		fi
	fi
	AV=${AVAIL[$n]}
}

# Succeed if every dependency in a Depends field, including its version
# constraint, can be satisfied on the target. A dependency Debian renamed
# (DEP_RENAMES) counts as satisfied by its successor.
_deps_satisfiable() {
	local group alt name op ver r v ok
	local -a groups alts avs
	IFS=, read -ra groups <<<"$1"
	for group in "${groups[@]}"; do
		[[ -n ${group//[[:space:]]/} ]] || continue
		ok=0
		IFS='|' read -ra alts <<<"$group"
		for alt in "${alts[@]}"; do
			name=${alt%%(*} op="" ver=""
			name=${name%%:*}; name=${name//[[:space:]]/}
			if [[ $alt =~ \(([\<\>=]+)[[:space:]]*([^\)[:space:]]+)\) ]]; then op=${BASH_REMATCH[1]} ver=${BASH_REMATCH[2]}; fi
			for r in "$name" ${DEP_RENAMES[$name]:-}; do
				_avail "$r"
				read -ra avs <<<"$AV"   # no glob expansion of "*"
				for v in "${avs[@]}"; do
					if [[ -z $op || $v == "*" ]] || _vcmp "$v" "$op" "$ver"; then ok=1; break 3; fi
				done
			done
		done
		(( ok )) || return 1
	done
}

# Find the newest compatible version of a package and record it in PKG_*.
# A version is compatible when all its dependencies, including versions, are
# available on this Debian release, so a package that needs a Raspberry Pi
# rebuild of a Debian package is skipped for an older version that does not.
#  * From the target release: any architecture (binaries match this system).
#  * From newer Raspberry Pi OS releases: architecture-independent packages
#    (icons, fonts, wallpapers), and the theme packages without compiled code
#    (DATA_PKGS) built for this architecture.
#  * Only if neither has it: older releases, then the armhf index, which lists
#    every Pi package.
# Offline, the local repository is the only source and is used as built.
# Usage: resolve_pkg PACKAGE [ARCHIVE]
resolve_pkg() {
	local pkg=$1 aid=${2:-rpi} s x line best="" best_v="" skipped="" v a f sha z d
	[[ -n $O_REPO && $O_ACTION != update-packages ]] && aid=local
	local -a newer=() older=()
	if [[ $aid == rpi ]]; then
		for s in "${RPI_SUITES[@]}"; do
			if (( $(_suite_rank "$s") > $(_suite_rank "$H_SUITE") )); then newer+=("$s/$H_ARCH")
			elif (( $(_suite_rank "$s") < $(_suite_rank "$H_SUITE") )); then older+=("$s/$H_ARCH"); fi
		done
		if [[ $H_ARCH != armhf ]]; then
			for s in "${RPI_SUITES[@]}"; do
				if (( $(_suite_rank "$s") <= $(_suite_rank "$H_SUITE") )); then older+=("$s/armhf"); fi
			done
		fi
	fi
	for x in "$H_SUITE/$H_ARCH" "${newer[@]}" "${older[@]}"; do
		[[ -n $best && " ${older[*]} " == *" $x "* ]] && break   # older releases are only a fallback
		index_load "$aid" "${x%/*}" "${x#*/}" || continue
		while IFS= read -r line; do
			IFS=$'\t' read -r v a f sha z d <<<"$line"
			[[ $x == "$H_SUITE/$H_ARCH" || $a == all ]] \
				|| { [[ $a == "$H_ARCH" && " ${DATA_PKGS[*]} " == *" $pkg "* ]]; } || break
			if [[ $aid != local ]] && ! _deps_satisfiable "$d"; then
				[[ -n $skipped ]] || skipped=$v
				continue
			fi
			# The release goes first: read merges empty tab-separated fields (depends)
			if [[ -z $best_v ]] || dpkg --compare-versions "$v" gt "$best_v"; then best="${x%/*}"$'\t'"$line" best_v=$v; fi
			break
		done < <(index_candidates "$aid" "${x%/*}" "${x#*/}" "$pkg")
	done
	if [[ -z $best ]]; then
		[[ -n $skipped ]] && warn "$pkg $skipped needs packages that Debian does not provide; no compatible version found"
		return 1
	fi
	IFS=$'\t' read -r s v a f sha z d <<<"$best"
	if [[ -n $skipped ]] && dpkg --compare-versions "$skipped" gt "$v"; then
		warn "$pkg $skipped needs packages that Debian does not provide; using $v"
	fi
	PKG_VER[$pkg]=$v PKG_FILE[$pkg]=$f PKG_SHA[$pkg]=$sha PKG_SIZE[$pkg]=${z:-0}
	PKG_SUITE[$pkg]=$s PKG_AID[$pkg]=$aid
}

# Download a resolved package, verify it and print its local path. When
# refreshing ./packages, an unchanged file there is reused.
download_pkg() {
	local pkg=$1 out big=0 base
	out="$WORKDIR/debs/$(basename "${PKG_FILE[$pkg]}")"
	base=$(_archive_url "${PKG_AID[$pkg]}")
	mkdir -p "$WORKDIR/debs"
	if [[ ! -f $out && $O_ACTION == update-packages && -d $O_REPO/pool ]]; then
		local old
		old=$(find "$O_REPO/pool" -type f -name "$(basename "$out")" -print -quit)
		if [[ -n $old ]]; then cp -- "$old" "$out"; fi
	fi
	if [[ -f $out ]] && [[ $(sha256sum "$out" | cut -d' ' -f1) == "${PKG_SHA[$pkg]}" ]]; then
		printf '%s\n' "$out"; return 0
	fi
	(( ${PKG_SIZE[$pkg]:-0} > 5000000 )) && big=1
	if [[ ${PKG_AID[$pkg]} != local ]]; then
		info "Downloading $pkg ${PKG_VER[$pkg]} ($(human_size "${PKG_SIZE[$pkg]}"))"
	fi
	fetch "$base/${PKG_FILE[$pkg]}" "$out" "$big" || die "cannot download $pkg from $base"
	sha256_check "$out" "${PKG_SHA[$pkg]}"
	chmod 0644 "$out"
	printf '%s\n' "$out"
}

# Print the dependency closure of the roots within a Packages index: every
# package reachable through Depends and Pre-Depends, taking the first available
# alternative and resolving virtual packages through Provides.
#   BASE=priority  also start from the Debian base system (priority required,
#                  important and standard)
#   RECOMMENDS=1   also follow Recommends, as APT does by default
#   INSTALLED=1    skip dependencies that installed packages already satisfy
#   HAVE=FILE      skip dependencies satisfied by the names in FILE
# Usage: _closure INDEX [ROOT]...
_closure() {
	local idx=$1 inst=${HAVE:-/dev/null}; shift
	if [[ ${INSTALLED:-} == 1 ]]; then
		inst=$WORKDIR/installed-names
		dpkg-query -W -f='${db:Status-Abbrev} ${Package} ${Provides}\n' 2>/dev/null \
			| awk '$1 ~ /^.i/ { $1 = ""; gsub(/\([^)]*\)|,/, " "); n = split($0, a, " "); for (i = 1; i <= n; i++) print a[i] }' \
			| sort -u >"$inst"
	fi
	ROOTS="$*" INST=$inst RECOMMENDS=${RECOMMENDS:-} awk '
		function resolve(x) { if (x in real) return x; if (x in prov) return prov[x]; return "" }
		function clean(x) { gsub(/\(.*\)/, "", x); sub(/:[a-z0-9]+/, "", x); gsub(/[ \t]/, "", x); return x }
		BEGIN {
			while ((getline line < ENVIRON["INST"]) > 0) have[line] = 1
			RS = ""; FS = "\n"
		}
		{
			n = d = pr = pri = ""
			for (i = 1; i <= NF; i++) {
				if ($i ~ /^Package: /) n = substr($i, 10)
				else if ($i ~ /^(Pre-)?Depends: / || (ENVIRON["RECOMMENDS"] == "1" && $i ~ /^Recommends: /)) {
					x = $i; sub(/^[^:]*: /, "", x); d = d (d == "" ? "" : ",") x
				}
				else if ($i ~ /^Provides: /) pr = substr($i, 11)
				else if ($i ~ /^Priority: /) pri = substr($i, 11)
			}
			if (n == "" || n in real) next
			real[n] = 1; deps[n] = d; prio[n] = pri
			m = split(pr, a, ","); for (j = 1; j <= m; j++) { v = clean(a[j]); if (v != "" && !(v in prov)) prov[v] = n }
		}
		END {
			if (ENVIRON["BASE"] == "priority") for (p in prio) if (prio[p] ~ /^(required|important|standard)$/) q[++tail] = p
			nr = split(ENVIRON["ROOTS"], r, " "); for (i = 1; i <= nr; i++) { x = resolve(r[i]); if (x != "") q[++tail] = x }
			head = 1
			while (head <= tail) {
				p = q[head++]; if (p in done) continue; done[p] = 1; print p
				c = split(deps[p], alts, ",")
				for (k = 1; k <= c; k++) {
					na = split(alts[k], o, "|"); sat = 0
					for (j = 1; j <= na; j++) if (clean(o[j]) in have) sat = 1
					if (sat) continue
					for (j = 1; j <= na; j++) { x = resolve(clean(o[j])); if (x != "") { if (!(x in done)) q[++tail] = x; break } }
				}
			}
		}' "$idx" | sort -u
}

# Print the dependency names of .deb files (all alternatives).
_deb_depnames() {
	local f
	for f; do dpkg-deb -f "$f" Pre-Depends Depends 2>/dev/null | sed 's/^[A-Za-z-]*: //'; done \
		| tr ',|' '\n' | sed 's/(.*//; s/:.*//; s/[[:space:]]//g' | awk 'NF' | sort -u
}

# Print the packages providing the GTK 2 engines that the gtkrc files in the
# given .deb files use.
_engine_pkgs() {
	local f e
	for f; do
		dpkg-deb --fsys-tarfile "$f" 2>/dev/null | tar -xO --wildcards '*/gtk-2.0/gtkrc' 2>/dev/null \
			| sed -n 's/^[[:space:]]*engine[[:space:]]*"\([^"]*\)".*/\1/p' || true
	done | sort -u | while read -r e; do
		case $e in
			pixmap)        echo gtk2-engines-pixbuf ;;
			pixflat)       echo gtk2-engines-pixflat ;;
			clearlookspix) echo gtk2-engines-clearlookspix ;;
			murrine)       echo gtk2-engines-murrine ;;
			adwaita)       echo gnome-themes-extra ;;
			xfce)          echo gtk2-engines-xfce ;;
			oxygen-gtk)    echo gtk2-engines-oxygen ;;
			clearlooks|crux|glide|hcengine|industrial|mist|redmond95|thinice) echo gtk2-engines ;;
			*) warn "unknown GTK 2 engine '$e' in a theme; GTK 2 applications may look wrong" ;;
		esac
	done | sort -u
}
# Succeed for GTK 2 engines published only by Raspberry Pi OS.
_is_rpi_engine() { [[ $1 == gtk2-engines-pixflat || $1 == gtk2-engines-clearlookspix ]]; }

# Succeed if a dependency can be satisfied on the target: by the install set,
# by the APT sources, or, when building ./packages, by the Debian index.
_dep_ok() {
	[[ -n ${IN_SET[$1]:-} ]] && return 0
	if [[ -n $DEP_INDEX ]]; then awk -v n="$1" '$1 == n { f = 1; exit } END { exit !f }' "$DEP_INDEX"; else apt_has "$1"; fi
}

# Rewrite dependency names that Debian has since renamed (see DEP_RENAMES).
# Only the Depends field changes. Prints the path of the package to install.
compat_fix() {
	local deb=$1 deps names n c repl changed=0 re dir out
	deps=$(dpkg-deb -f "$deb" Depends)
	[[ -n $deps ]] || { printf '%s\n' "$deb"; return 0; }
	names=$(tr ',|' '\n' <<<"$deps" | sed 's/(.*//; s/:.*//; s/[[:space:]]//g' | awk 'NF' | sort -u)
	for n in $names; do
		_dep_ok "$n" && continue
		repl=""
		for c in ${DEP_RENAMES[$n]:-}; do
			if _dep_ok "$c"; then repl=$c; break; fi
		done
		[[ -n $repl ]] || die "$(basename "$deb") depends on '$n', which is not available for $H_SUITE/$H_ARCH"
		re=${n//./\\.}
		re=${re//+/\\+}
		deps=$(sed -E "s/(^|[ ,|])${re}([ ,(|:]|\$)/\\1${repl}\\2/g" <<<"$deps")
		info "Compatibility: $(dpkg-deb -f "$deb" Package) depends on $n -> $repl"
		changed=1
	done
	if (( ! changed )); then printf '%s\n' "$deb"; return 0; fi
	dir="$WORKDIR/repack/$(basename "$deb" .deb)"
	out="$WORKDIR/debs/$(basename "$deb" .deb)+debcompat.deb"
	rm -rf -- "$dir"; mkdir -p "$(dirname "$dir")"
	dpkg-deb -R "$deb" "$dir"
	# Keep the original timestamps, so the same input gives an identical file.
	local stamp
	stamp=$(stat -c %Y "$dir/DEBIAN/control")
	DEPS=$deps awk '/^Depends:/ { print "Depends: " ENVIRON["DEPS"]; next } { print }' \
		"$dir/DEBIAN/control" >"$dir/DEBIAN/control.new"
	mv -- "$dir/DEBIAN/control.new" "$dir/DEBIAN/control"
	touch -d "@$stamp" "$dir/DEBIAN/control" "$dir/DEBIAN"
	SOURCE_DATE_EPOCH=$stamp dpkg-deb --root-owner-group -b "$dir" "$out" >/dev/null
	chmod 0644 "$out"
	printf '%s\n' "$out"
}

# Raspberry Pi's file manager ships as a drop-in replacement for Debian's: the
# same program name, the same data files, and Breaks/Replaces on pcmanfm, so
# APT would remove it. Repack it to run beside Debian's instead, as
# pcmanfm-pi: the program is installed under that name, its data directory is
# renamed (the path is rewritten inside the program, in place, so the file
# keeps its layout), and the files Debian's package already provides (the
# toolbar icons, which are identical, and the translations, which the same
# message domain covers) are left out. Debian's file manager is untouched, so
# a Debian upgrade cannot collide with it. Prints the path to install.
fm_coinstall() {
	local deb=$1 dir out stamp
	local from=/usr/share/pcmanfm/    # the data directory compiled into it
	local to=/usr/share/pcmanpi/      # same length, so it replaces it in place
	[[ $(dpkg-deb -f "$deb" Package) == pcmanfm-pi ]] || { printf '%s\n' "$deb"; return 0; }
	dir="$WORKDIR/repack/$(basename "$deb" .deb)"
	out="$WORKDIR/debs/$(basename "$deb" .deb)+beside.deb"
	rm -rf -- "$dir"; mkdir -p "$(dirname "$dir")" "$WORKDIR/debs"
	dpkg-deb -R "$deb" "$dir"
	stamp=$(stat -c %Y "$dir/DEBIAN/control")
	[[ -f $dir/usr/bin/pcmanfm ]] || die "$(basename "$deb") does not contain /usr/bin/pcmanfm"
	FROM=$from TO=$to perl -0777 -pe 'BEGIN { binmode STDIN; binmode STDOUT }
		s/\Q$ENV{FROM}\E/$ENV{TO}/g' <"$dir/usr/bin/pcmanfm" >"$dir/usr/bin/pcmanfm-pi"
	chmod 0755 "$dir/usr/bin/pcmanfm-pi"
	rm -f -- "$dir/usr/bin/pcmanfm"
	mv -- "$dir$from" "$dir$to"
	sed -E 's/^(Exec|TryExec)=pcmanfm/\1=pcmanfm-pi/' "$dir/usr/share/applications/pcmanfm.desktop" \
		>"$dir/usr/share/applications/pcmanfm-pi.desktop"
	rm -f -- "$dir/usr/share/applications/pcmanfm.desktop"
	mv -- "$dir/usr/share/man/man1/pcmanfm.1.gz" "$dir/usr/share/man/man1/pcmanfm-pi.1.gz"
	rm -rf -- "${dir:?}/usr/share/locale" "${dir:?}/usr/share/icons" "${dir:?}/etc"
	# Its conffile and maintainer script belong to the files left out above
	rm -f -- "$dir/DEBIAN/conffiles" "$dir/DEBIAN/postinst"
	sed -i -E '/^(Breaks|Replaces|Conflicts|Provides):/d' "$dir/DEBIAN/control"
	( cd "$dir" && find . -path ./DEBIAN -prune -o -type f -print0 | sort -z \
		| xargs -0r md5sum | sed 's| \./| |' >DEBIAN/md5sums )
	chmod 0644 "$dir/DEBIAN/md5sums"
	find "$dir" -exec touch -d "@$stamp" {} +
	SOURCE_DATE_EPOCH=$stamp dpkg-deb --root-owner-group -b "$dir" "$out" >/dev/null
	chmod 0644 "$out"
	printf '%s\n' "$out"
}

# Print the installed version of a package, or nothing.
_installed_version() {
	{ dpkg-query -W -f='${db:Status-Abbrev} ${Version}\n' "$1" 2>/dev/null || true; } | awk '$1 ~ /^.i/ { print $2 }'
}

# List the releases and architectures in the offline repository.
_repo_contents() {
	local d out=""
	for d in "$O_REPO"/dists/*/main/binary-*; do
		[[ -d $d ]] || continue
		d=${d#"$O_REPO"/dists/}
		out+="${out:+, }${d%%/*}/${d##*binary-}"
	done
	printf '%s\n' "${out:-nothing}"
}

# ---------------------------------------------------------------------------
# Xfwm4 themes, generated from the official Openbox themes
# ---------------------------------------------------------------------------

# Print an Openbox theme colour as #rrggbb, or the default.
# Usage: _ob_color THEMERC KEY DEFAULT
_ob_color() {
	local v
	v=$(awk -v k="$2" '{ key = $0; sub(/:.*/, "", key) }
		tolower(key) == tolower(k) { v = $0; sub(/^[^:]*:[ \t]*/, "", v); sub(/[ \t\r]+$/, "", v) }
		END { print v }' "$1")
	if [[ $v =~ ^#[0-9A-Fa-f]{6}$ ]]; then printf '%s\n' "${v,,}"
	elif [[ $v =~ ^#([0-9A-Fa-f])([0-9A-Fa-f])([0-9A-Fa-f])$ ]]; then
		printf '#%s%s%s%s%s%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" \
			"${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}" "${BASH_REMATCH[3]}" | tr 'A-F' 'a-f'
	else printf '%s\n' "$3"; fi
}

# Blend two colours. Usage: _mix #rrggbb #rrggbb PERCENT-OF-SECOND
_mix() {
	local a=${1#\#} b=${2#\#} p=$3 out="#" i
	for i in 0 2 4; do
		printf -v out '%s%02x' "$out" $(( (16#${a:i:2} * (100 - p) + 16#${b:i:2} * p) / 100 ))
	done
	printf '%s\n' "$out"
}

# Repeat a character. Usage: _rep CHAR COUNT
_rep() { local s; printf -v s '%*s' "$2" ''; printf '%s' "${s// /$1}"; }

# Write an XPM image. Usage: _xpm FILE CHAR=COLOUR... -- ROW...
_xpm() {
	local file=$1 p i; shift
	local -a pal=()
	while [[ $1 != -- ]]; do pal+=("$1"); shift; done; shift
	{
		printf '/* XPM */\nstatic char * xpm[] = {\n"%d %d %d 1",\n' "${#1}" "$#" "${#pal[@]}"
		for p in "${pal[@]}"; do printf '"%s c %s",\n' "${p%%=*}" "${p#*=}"; done
		for (( i = 1; i <= $#; i++ )); do
			if (( i < $# )); then printf '"%s",\n' "${!i}"; else printf '"%s"};\n' "${!i}"; fi
		done
	} >"$file"
}

# Write an XPM image of identical rows.
# Usage: _xpm_tile FILE HEIGHT ROW CHAR=COLOUR...
_xpm_tile() {
	local file=$1 h=$2 row=$3 i; shift 3
	local -a rows=()
	for (( i = 0; i < h; i++ )); do rows+=("$row"); done
	_xpm "$file" "$@" -- "${rows[@]}"
}

# Print an XBM bitmap as rows of '#' (set) and '.' (clear).
_xbm_rows() {
	local f=$1 w h x y b bpr row
	w=$(sed -n 's/^#define[[:space:]]\{1,\}[^[:space:]]*_width[[:space:]]\{1,\}\([0-9]\{1,\}\).*/\1/p' "$f")
	h=$(sed -n 's/^#define[[:space:]]\{1,\}[^[:space:]]*_height[[:space:]]\{1,\}\([0-9]\{1,\}\).*/\1/p' "$f")
	[[ -n $w && -n $h ]] || return 1
	local -a bytes
	mapfile -t bytes < <(sed '/^#define/d' "$f" | grep -oiE '0x[0-9a-f]{1,2}')
	bpr=$(( (w + 7) / 8 ))
	(( ${#bytes[@]} >= bpr * h )) || return 1
	for (( y = 0; y < h; y++ )); do
		row=""
		for (( x = 0; x < w; x++ )); do
			b=$(( bytes[y * bpr + x / 8] ))
			if (( (b >> (x % 8)) & 1 )); then row+="#"; else row+="."; fi
		done
		printf '%s\n' "$row"
	done
}

# Print a button glyph from an Openbox bitmap, or a built-in one.
# Usage: _glyph OPENBOX-DIR XBM-NAME|builtin:NAME
_glyph() {
	local dir=$1 name=$2
	if [[ $name != builtin:* && -f $dir/$name.xbm ]] && _xbm_rows "$dir/$name.xbm"; then return 0; fi
	case ${name#builtin:} in
		shade*_toggled*) printf '%s\n' "########" "########" "........" "..####.." "..####.." "...##..." "...##..." "........" ;;
		shade*)          printf '%s\n' "########" "########" "........" "........" "........" "........" "........" "........" ;;
		stick*_toggled*) printf '%s\n' "........" "..####.." ".######." ".######." ".######." ".######." "..####.." "........" ;;
		stick*)          printf '%s\n' "........" "..####.." ".##..##." ".#....#." ".#....#." ".##..##." "..####.." "........" ;;
		menu*)           printf '%s\n' "........" "........" "########" "########" ".######." "..####.." "...##..." "........" ;;
		*)               printf '%s\n' "........" ;;
	esac
}

# Write a button image with the glyph from stdin centred on it.
# Usage: _xpm_button FILE WIDTH HEIGHT BG FG
_xpm_button() {
	local file=$1 w=$2 h=$3 bg=$4 fg=$5 gw gh ox oy y line
	local -a g=() rows=()
	mapfile -t g
	gh=${#g[@]} gw=${#g[0]}
	ox=$(( (w - gw) / 2 )) oy=$(( (h - gh) / 2 ))
	for (( y = 0; y < h; y++ )); do
		if (( y >= oy && y < oy + gh )); then
			line="$(_rep . "$ox")${g[y - oy]}$(_rep . $(( w - gw - ox )))"
			rows+=("${line//#/+}")
		else
			rows+=("$(_rep . "$w")")
		fi
	done
	_xpm "$file" ".=$bg" "+=$fg" -- "${rows[@]}"
}

# Generate an Xfwm4 theme from the colours and bitmaps of an Openbox theme.
# Usage: gen_xfwm4 OPENBOX-DIR OUTPUT-DIR THEME-NAME
gen_xfwm4() {
	local src=$1 out=$2 name=$3 rc=$1/themerc
	[[ -f $rc ]] || return 1
	local a_bg a_fg a_btn i_bg i_fg i_btn a_bd i_bd a_cl i_cl
	a_bg=$(_ob_color "$rc" window.active.title.bg.color '#87919b')
	a_fg=$(_ob_color "$rc" window.active.label.text.color '#f0f0f0')
	a_btn=$(_ob_color "$rc" window.active.button.unpressed.image.color "$a_fg")
	i_bg=$(_ob_color "$rc" window.inactive.title.bg.color '#eeefee')
	i_fg=$(_ob_color "$rc" window.inactive.label.text.color '#70747d')
	i_btn=$(_ob_color "$rc" window.inactive.button.unpressed.image.color "$i_fg")
	a_bd=$(_ob_color "$rc" window.active.border.color '#d0d0d0')
	i_bd=$(_ob_color "$rc" window.inactive.border.color "$a_bd")
	a_cl=$(_ob_color "$rc" window.active.client.color "$i_bg")
	i_cl=$(_ob_color "$rc" window.inactive.client.color "$a_cl")

	local H=26 W=26 n st bg fg bd cl
	mkdir -p "$out"
	for st in active inactive; do
		if [[ $st == active ]]; then bg=$a_bg fg=$a_btn bd=$a_bd cl=$a_cl; else bg=$i_bg fg=$i_btn bd=$i_bd cl=$i_cl; fi
		for n in 1 2 3 4 5; do _xpm_tile "$out/title-$n-$st.xpm" "$H" "bb" "b=$bg"; done
		_xpm_tile "$out/top-left-$st.xpm"  "$H" "dbb" "d=$bd" "b=$bg"
		_xpm_tile "$out/top-right-$st.xpm" "$H" "bbd" "d=$bd" "b=$bg"
		_xpm_tile "$out/left-$st.xpm"      2 "dcc" "d=$bd" "c=$cl"
		_xpm_tile "$out/right-$st.xpm"     2 "ccd" "d=$bd" "c=$cl"
		_xpm "$out/bottom-$st.xpm"       "d=$bd" "c=$cl" -- "cc" "cc" "dd"
		_xpm "$out/bottom-left-$st.xpm"  "d=$bd" "c=$cl" -- "dcc" "dcc" "ddd"
		_xpm "$out/bottom-right-$st.xpm" "d=$bd" "c=$cl" -- "ccd" "ccd" "ddd"
	done

	# Xfwm4 button name -> Openbox bitmap
	local -A ob=([close]=close [hide]=iconify [maximize]=max [maximize-toggled]=max_toggled
		[menu]=menu [shade]=builtin:shade [shade-toggled]=builtin:shade_toggled
		[stick]=builtin:stick [stick-toggled]=builtin:stick_toggled)
	local b glyph hover
	for b in "${!ob[@]}"; do
		glyph=${ob[$b]} hover="${ob[$b]}_hover"
		[[ $glyph != builtin:* && ! -f $src/$hover.xbm ]] && hover=$glyph
		_glyph "$src" "$glyph" | _xpm_button "$out/$b-active.xpm"   "$W" "$H" "$a_bg" "$a_btn"
		_glyph "$src" "$glyph" | _xpm_button "$out/$b-inactive.xpm" "$W" "$H" "$i_bg" "$i_btn"
		_glyph "$src" "$hover" | _xpm_button "$out/$b-prelight.xpm" "$W" "$H" "$(_mix "$a_bg" "$a_btn" 18)" "$a_btn"
		_glyph "$src" "$hover" | _xpm_button "$out/$b-pressed.xpm"  "$W" "$H" "$(_mix "$a_bg" "$a_btn" 32)" "$a_btn"
	done

	cat >"$out/themerc" <<EOF
# Xfwm4 theme generated from the official Raspberry Pi OS "$name" Openbox theme
# by $APP_NAME $APP_VERSION. It is regenerated on every install; do not edit.
active_text_color=$a_fg
inactive_text_color=$i_fg
title_alignment=center
full_width_title=true
title_shadow_active=false
title_shadow_inactive=false
title_horizontal_offset=0
title_vertical_offset_active=0
title_vertical_offset_inactive=0
button_offset=0
button_spacing=0
maximized_offset=0
EOF
}

# ---------------------------------------------------------------------------
# Icon overlay "<Base>-Debian": the official theme plus cursor-name aliases
# ---------------------------------------------------------------------------

# Print the other Raspberry Pi OS icon sets an icon set borrows from: only the
# legacy PiX does, from PiXflat, the set closest to it in style. The others
# keep the fallback the official theme itself names (GNOME, Adwaita), so no set
# is mixed with icons from another era.
_icon_fallbacks() {
	case $1 in PiX) echo PiXflat ;; esac
}

# Link each missing cursor name to an equivalent official cursor. Repeated
# passes let aliases build on each other.
# Usage: _cursor_aliases BASE-CURSOR-DIR OUT-DIR BASE-NAME
_cursor_aliases() {
	local basecur=$1 outcur=$2 base=$3 pass entry name c made
	mkdir -p "$outcur"
	for pass in 1 2 3 4 5; do
		made=0
		for entry in "${CURSOR_ALIASES[@]}"; do
			name=${entry%%:*}
			[[ -e $basecur/$name || -L $outcur/$name ]] && continue
			for c in ${entry#*:}; do
				if [[ -e $basecur/$c ]]; then ln -s "../../$base/cursors/$c" "$outcur/$name"; made=1; break
				elif [[ -L $outcur/$c ]]; then ln -s "$c" "$outcur/$name"; made=1; break
				fi
			done
		done
		(( made )) || break
	done
	debug "$base: $(find "$outcur" -type l | wc -l) cursor aliases (pass $pass)"
}

# Link the icon names Debian's applets request to the official images, at
# every size the base theme has. Names the base theme already has are kept,
# unless marked with "!".
# Usage: _icon_aliases BASE-DIR OUT-DIR BASE-NAME
_icon_aliases() {
	local bdir=$1 out=$2 base=$3 entry name target rel f n i force
	local -a pairs=("${ICON_ALIASES[@]}")
	local -A have=() imgs=()
	# nm-applet's connecting animation frames and VPN frames
	for n in 01 02 03; do for i in $(seq -w 1 11); do pairs+=("nm-stage$n-connecting$i:network-idle"); done; done
	for i in $(seq -w 1 14); do pairs+=("nm-vpn-connecting$i:nm-vpn-active-lock"); done
	# Generic file names: the official sets carry the old GNOME names
	# (gnome-mime-application-pdf), today's file managers ask for the current
	# ones (application-pdf), so each old name also answers to the new one.
	pairs+=("application-octet-stream:unknown"    "application-x-generic:unknown"
		"text-plain:text-x-generic"              "application-x-zerosize:empty"
		"inode-x-empty:empty"                    "inode-directory:folder"
		"application-x-sharedlib:application-x-executable"
		"application-x-firmware:unknown"         "application-certificate:unknown"
		# Office documents, which file managers ask for by their long names
		"application-vnd.openxmlformats-officedocument.wordprocessingml.document:x-office-document"
		"application-vnd.openxmlformats-officedocument.spreadsheetml.sheet:x-office-spreadsheet"
		"application-vnd.openxmlformats-officedocument.presentationml.presentation:x-office-presentation"
		"application-vnd.ms-word:x-office-document"   "application-msword:x-office-document"
		"application-vnd.ms-excel:x-office-spreadsheet"
		"application-vnd.ms-powerpoint:x-office-presentation"
		"application-vnd.oasis.opendocument.spreadsheet:x-office-spreadsheet"
		"application-vnd.oasis.opendocument.presentation:x-office-presentation"
		"application-vnd.oasis.opendocument.graphics:x-office-drawing")
	while IFS= read -r rel; do
		f=${rel##*/}; f=${f%.*}
		have[$f]=1
		imgs[$f]+="$rel "
	done < <(cd "$bdir" && find . -mindepth 3 \( -name '*.png' -o -name '*.svg' \) -printf '%P\n')
	for f in "${!imgs[@]}"; do
		[[ $f == gnome-mime-* ]] && pairs+=("${f#gnome-mime-}:$f")
	done
	for entry in "${pairs[@]}"; do
		name=${entry%%:*} target=${entry#*:} force=0
		if [[ $name == '!'* ]]; then name=${name#!} force=1; fi
		[[ -n ${imgs[$target]:-} ]] || continue
		if [[ -n ${have[$name]:-} ]] && (( ! force )); then continue; fi
		for rel in ${imgs[$target]}; do
			mkdir -p "$out/${rel%/*}"
			ln -sfn "../../../$base/$rel" "$out/${rel%/*}/$name.${rel##*.}"
		done
	done
}

# Show the Debian logo wherever the theme shows the Raspberry Pi logo
# ("start-here", "distributor-logo"), e.g. on the Raspberry Pi menu button.
# The images come from Debian's desktop-base, else from debconf.
# Usage: _logo_aliases OUT-DIR
_logo_aliases() {
	local out=$1 f dir size ext n found=0
	for f in /usr/share/icons/desktop-base/*/emblems/emblem-debian.png \
		/usr/share/icons/desktop-base/scalable/emblems/emblem-debian.svg; do
		[[ -f $f ]] || continue
		size=${f#/usr/share/icons/desktop-base/}; size=${size%%/*}
		dir=$out/$size/places ext=${f##*.}
		mkdir -p "$dir"
		for n in start-here distributor-logo; do ln -sfn "$f" "$dir/$n.$ext"; done
		found=1
	done
	if (( ! found )) && [[ -f /usr/share/pixmaps/debian-logo.png ]]; then
		mkdir -p "$out/48x48/places"
		for n in start-here distributor-logo; do ln -sfn /usr/share/pixmaps/debian-logo.png "$out/48x48/places/$n.png"; done
	fi
}

# Create the "<Base>-Debian" icon theme, which inherits the official one and
# adds cursor and icon name aliases.
# Usage: gen_icon_overlay BASE-NAME OUTPUT-DIR
gen_icon_overlay() {
	local base=$1 out=$2 bdir=$SYS_ROOT/usr/share/icons/$1 inh d
	local -a dirs=()
	mkdir -p "$out"
	[[ -d $bdir/cursors ]] && _cursor_aliases "$bdir/cursors" "$out/cursors" "$base"
	_icon_aliases "$bdir" "$out" "$base"
	_logo_aliases "$out"
	mapfile -t dirs < <(cd "$out" && find . -mindepth 2 -maxdepth 2 -type d ! -path './cursors*' -printf '%P\n' | sort)
	debug "$base: icon aliases in ${#dirs[@]} directories"
	inh=$(sed -n 's/^Inherits[[:space:]]*=[[:space:]]*//p' "$bdir/index.theme" | head -n1)
	# An icon a set lacks comes from the other Raspberry Pi OS sets first, so
	# that it still looks like Raspberry Pi OS instead of GNOME's fallback
	local pi="" d
	for d in $(_icon_fallbacks "$base"); do
		[[ -f $SYS_ROOT/usr/share/icons/$d/index.theme ]] && pi+="$d,"
	done
	inh=$(tr ',' '\n' <<<"$base,$pi$inh,Adwaita,hicolor" | awk 'NF && !seen[$0]++' | paste -sd, -)
	{
		printf '[Icon Theme]\nName=%s (Debian)\n' "$base"
		printf 'Comment=Raspberry Pi OS %s icons and cursors with Debian compatibility names\n' "$base"
		printf 'Inherits=%s\nExample=folder\nDirectories=%s\n' "$inh" "$(IFS=,; echo "${dirs[*]}")"
		for d in "${dirs[@]}"; do   # each directory's section: the official theme's, or a new one
			printf '\n'
			if grep -qxF "[$d]" "$bdir/index.theme"; then
				D="[$d]" awk '$0 == ENVIRON["D"] { p = 1; print; next } /^\[/ { p = 0 } p && NF' "$bdir/index.theme"
			elif [[ $d == scalable/* ]]; then
				printf '[%s]\nContext=Places\nSize=48\nMinSize=8\nMaxSize=512\nType=Scalable\n' "$d"
			else
				printf '[%s]\nContext=Places\nSize=%s\nType=Fixed\n' "$d" "${d%%x*}"
			fi
		done
	} >"$out/index.theme"
}

# ---------------------------------------------------------------------------
# Generated package: pixflat-theme-debian
# ---------------------------------------------------------------------------

# Print the wallpaper file to use, or nothing. The theme's default wallpaper
# comes in the requested resolution if installed, else in the other one.
_wallpaper_path() {
	local w=${O_WALLPAPER:-} std uhd
	if [[ -z $w ]]; then
		(( O_WITH_WALLPAPER )) || return 0
		std=/usr/share/rpd-wallpaper/$T_WALL_DEFAULT uhd=${std%.jpg}_4k.jpg
		if (( O_4K )); then w=$uhd; [[ -f $w || ! -f $std ]] || w=$std
		else w=$std; [[ -f $w || ! -f $uhd ]] || w=$uhd; fi
	fi
	if [[ $w != */* ]]; then
		[[ $w == *.* ]] || w+=".jpg"
		w=/usr/share/rpd-wallpaper/$w
	fi
	printf '%s\n' "$w"
}

# Resolve the newest $ART_PKG for this architecture, without the dependency
# check (it is never installed). Usage: _art_resolve ARCHIVE
_art_resolve() {
	local aid=$1 line v a f sha z d
	index_load "$aid" "$ART_SUITE" "$H_ARCH" || return 1
	line=$(index_candidates "$aid" "$ART_SUITE" "$H_ARCH" "$ART_PKG" | head -n1)
	[[ -n $line ]] || return 1
	IFS=$'\t' read -r v a f sha z d <<<"$line"
	PKG_VER[$ART_PKG]=$v PKG_FILE[$ART_PKG]=$f PKG_SHA[$ART_PKG]=$sha PKG_SIZE[$ART_PKG]=${z:-0}
	PKG_SUITE[$ART_PKG]=$ART_SUITE PKG_AID[$ART_PKG]=$aid
}

# Unpack the Raspberry Pi OS login screen wallpapers (light and dark) and their
# licence from the official $ART_PKG package into $WORKDIR/login.
_login_art() {
	local aid=rpi deb x=$WORKDIR/art
	if [[ -n $O_REPO ]]; then aid=local; else setup_keyring; fi
	_art_resolve "$aid" || return 1
	deb=$(download_pkg "$ART_PKG")
	rm -rf -- "$x"; mkdir -p "$x" "$WORKDIR/login"
	dpkg-deb --fsys-tarfile "$deb" | tar -x -C "$x" --wildcards './usr/share/rpd-wallpaper/RPiSystem*.png' \
		"./usr/share/doc/$ART_PKG/copyright" || return 1
	install -m 0644 "$x"/usr/share/rpd-wallpaper/RPiSystem*.png "$WORKDIR/login/"
	install -m 0644 "$x/usr/share/doc/$ART_PKG/copyright" "$WORKDIR/login/copyright"
}

# Unpack the login screen wallpaper and report the result. It runs in a
# subshell, so that a failed download does not stop the installation.
_get_login_art() {
	if ( _login_art ) 2>/dev/null; then ok "Login screen wallpaper from $ART_PKG (unpacked, not installed)"
	else warn "$ART_PKG is not available; the login screen uses its background colour"; fi
}

# Build pixflat-theme-debian from the installed official themes: Xfwm4 themes,
# icon overlays and the login screen style. Prints its path.
# shellcheck disable=SC2016  # maintainer scripts contain a literal $1
build_local_pkg() {
	local stage=$WORKDIR/localpkg t b f ver icons=()
	rm -rf -- "$stage"; mkdir -p "$stage/DEBIAN"
	for t in PiXflat PiXnoir PiXtrix PiXonyx PiX; do
		[[ -f $SYS_ROOT/usr/share/themes/$t/openbox-3/themerc ]] || continue
		gen_xfwm4 "$SYS_ROOT/usr/share/themes/$t/openbox-3" "$stage/usr/share/themes/$t/xfwm4" "$t"
		debug "generated Xfwm4 theme for $t"
	done
	for b in PiXflat PiXtrix PiX; do
		[[ -f $SYS_ROOT/usr/share/icons/$b/index.theme ]] || continue
		gen_icon_overlay "$b" "$stage/usr/share/icons/$b-Debian"
		icons+=("$b-Debian")
	done
	local art=/usr/share/$APP_PKG/login greeter=/usr/share/lightdm/lightdm-gtk-greeter.conf.d/60_$APP_NAME.conf \
		seat=/usr/share/lightdm/lightdm.conf.d/60_$APP_NAME.conf
	if (( O_LIGHTDM )) && [[ -n ${T_GTK:-} ]]; then
		# The Raspberry Pi OS login screen (pi-greeter.conf) with Debian's GTK
		# greeter: its wallpaper (the dark one for dark themes), a centred login
		# box, the user list, the theme, icons and font, and the Debian logo as
		# the default user picture.
		local logo bg=#d6d3de img=RPiSystem.png
		(( T_DARK )) && img=RPiSystem_dark.png
		logo=$(_greeter_logo || true)
		mkdir -p "$stage$art" "$stage${greeter%/*}" "$stage${seat%/*}"
		# Downloaded now, else kept from the installed package (--apply-only)
		if cp -- "$WORKDIR"/login/* "$stage$art/" 2>/dev/null || cp -- "$art"/* "$stage$art/" 2>/dev/null; then
			[[ -f $stage$art/$img ]] || img=RPiSystem.png
			[[ -f $stage$art/$img ]] && bg=$art/$img
		else
			warn "the Raspberry Pi OS login screen wallpaper is unavailable; using its background colour"
		fi
		{
			printf '# Installed by %s: the Raspberry Pi OS login screen style\n[greeter]\n' "$APP_NAME"
			printf 'theme-name=%s\nicon-theme-name=%s-Debian\ncursor-theme-name=%s-Debian\ncursor-theme-size=%s\n' \
				"$T_GTK" "$T_ICON_BASE" "$T_ICON_BASE" "$T_CURSOR_SIZE"
			if [[ -n $T_FONT ]]; then printf 'font-name=%s\n' "$T_FONT"; fi
			printf 'xft-antialias=true\nxft-hintstyle=hintfull\nxft-rgba=rgb\n'
			printf 'background=%s\nuser-background=false\nposition=50%%,center 50%%,center\nindicators=~spacer\n' "$bg"
			if [[ -n $logo ]]; then printf 'default-user-image=%s\n' "$logo"; fi
		} >"$stage$greeter"
		# Raspberry Pi OS lists the users to choose from (pi-greeter's postinst)
		# and, where its own greeter is installed, uses it
		{
			printf '# Installed by %s: list users, as Raspberry Pi OS does\n[Seat:*]\ngreeter-hide-users=false\n' "$APP_NAME"
			if _pi_greeter_ok; then printf 'greeter-session=pi-greeter-x\n'; fi
		} >"$stage$seat"
	elif (( O_LIGHTDM )); then
		# No look chosen (--install-only): keep the installed login screen style
		for f in "$greeter" "$seat" "$art"; do
			if [[ -e $f ]]; then mkdir -p "$stage${f%/*}"; cp -a -- "$f" "$stage$f"; fi
		done
	fi

	ver="${APP_VERSION}+$(date -u +%Y%m%d%H%M%S)"
	cat >"$stage/DEBIAN/control" <<EOF
Package: $APP_PKG
Version: $ver
Architecture: all
Maintainer: $APP_NAME installer <root@localhost>
Section: x11
Priority: optional
Enhances: pixflat-theme, pixflat-icons, pixtrix-theme, pixtrix-icons, pix-theme, rpd-icons
Description: Debian compatibility layer for the Raspberry Pi OS desktop themes
 Generated locally by $APP_NAME $APP_VERSION from the installed official
 Raspberry Pi OS packages: aliases for cursor names the official cursor themes
 lack, Xfwm4 themes generated from the official Openbox themes, and the
 Raspberry Pi OS login screen style for the LightDM GTK greeter.
EOF
	{
		printf '#!/bin/sh\nset -e\nif [ "$1" = configure ] && command -v gtk-update-icon-cache >/dev/null; then\n'
		for f in "${icons[@]}"; do printf '\tgtk-update-icon-cache -q -t -f /usr/share/icons/%s || true\n' "$f"; done
		printf '\t:\nfi\n'
		# Raspberry Pi's panel reads the application menu only when it starts:
		# restart running panels when packages add or remove applications.
		cat <<'EOF_TRIG'
if [ "$1" = triggered ] && command -v pgrep >/dev/null; then
	for pid in $(pgrep -x lxpanel-pi || true); do
		u=$(ps -o user= -p "$pid" | tr -d ' ')
		d=$( { tr '\0' '\n' <"/proc/$pid/environ"; } 2>/dev/null | sed -n 's/^DISPLAY=//p')
		x=$( { tr '\0' '\n' <"/proc/$pid/environ"; } 2>/dev/null | sed -n 's/^XAUTHORITY=//p')
		[ -n "$u" ] && [ -n "$d" ] || continue
		runuser -u "$u" -- env DISPLAY="$d" ${x:+XAUTHORITY=$x} lxpanelctl-pi restart >/dev/null 2>&1 || true
	done
fi
EOF_TRIG
	} >"$stage/DEBIAN/postinst"
	printf 'interest-noawait /usr/share/applications\n' >"$stage/DEBIAN/triggers"
	{
		printf '#!/bin/sh\nset -e\nif [ "$1" = remove ] || [ "$1" = purge ]; then\n'
		for f in "${icons[@]}"; do
			printf '\trm -f /usr/share/icons/%s/icon-theme.cache\n\trmdir /usr/share/icons/%s 2>/dev/null || true\n' "$f" "$f"
		done
		printf '\t:\nfi\n'
	} >"$stage/DEBIAN/postrm"
	chmod 0755 "$stage/DEBIAN/postinst" "$stage/DEBIAN/postrm"
	dpkg-deb --root-owner-group -Zxz -b "$stage" "$WORKDIR/${APP_PKG}_${ver}_all.deb" >/dev/null
	chmod 0644 "$WORKDIR/${APP_PKG}_${ver}_all.deb"
	printf '%s\n' "$WORKDIR/${APP_PKG}_${ver}_all.deb"
}

# ---------------------------------------------------------------------------
# System installation
# ---------------------------------------------------------------------------
# Stop if a required tool is missing.
preflight_tools() {
	local t missing=()
	for t in dpkg-deb gpgv base64 sha256sum awk sed gzip perl; do
		command -v "$t" >/dev/null || missing+=("$t")
	done
	if [[ -z $O_REPO || $O_ACTION == update-packages ]] && ! command -v curl >/dev/null && ! command -v wget >/dev/null; then
		missing+=(curl)
	fi
	(( ${#missing[@]} == 0 )) || die "missing tools: ${missing[*]} (install them with apt)"
}

# Obtain root rights through sudo, once, before installing.
prepare_root() {
	(( EUID == 0 )) && return 0
	command -v sudo >/dev/null || die "root privileges are needed: run as root or install sudo"
	(( O_DRY_RUN )) && return 0
	info "Administrator rights are needed to install packages"
	sudo -v || die "sudo authentication failed"
}

# Stop unless every file of the offline repository matches SHA256SUMS.
verify_repo() {
	[[ -f $O_REPO/SHA256SUMS ]] || die "no offline repository in $O_REPO (run install-offline.sh --update-packages on a connected machine)"
	step "Verifying the offline repository"
	(cd -- "$O_REPO" && sha256sum --quiet --strict -c SHA256SUMS) || die "the offline repository is damaged (SHA256SUMS mismatch)"
	ok "All files in $(basename -- "$O_REPO")/ match SHA256SUMS"
}

# Decide what to install: every theme compatible with this release (or, with
# --only, one theme family), as FETCH_PKGS from verified .deb files, and the
# Debian helpers they need as APT_PKGS by name. Installed packages are never
# upgraded.
resolve_all() {
	local p fam="" walls=0
	local -a wanted=() helpers=()
	[[ -n $O_ONLY ]] && fam=" $(_family_pkgs "$O_ONLY") "
	(( O_WITH_WALLPAPER )) && [[ $O_WALLPAPER != */* ]] && walls=1
	while read -r p; do
		[[ -z $fam || $fam == *" $p "* ]] || continue
		case $p in
			fonts-*)           (( O_WITH_FONT )) || continue ;;
			pi-greeter)        if (( ! O_LIGHTDM )) || [[ -z $(_installed_version lightdm) ]]; then continue; fi ;;
			rpd-wallpaper*-4k) (( walls && O_4K )) || continue ;;
			rpd-wallpaper*)    (( walls && ! O_4K )) || continue ;;
		esac
		wanted+=("$p")
	done < <(_bundle_rpi_pkgs "$H_SUITE" | grep -vxF -f <(_pi_panel_pkgs; _pi_fm_pkgs "$H_SUITE"))
	# Raspberry Pi's own panel, on Debian 13 and later where Debian's LXDE panel
	# is installed (it replaces that panel in the LXDE session)
	if (( O_PANEL && $(_suite_rank "$H_SUITE") >= 3 )) && [[ -n $(_installed_version lxpanel) ]]; then
		mapfile -t -O "${#wanted[@]}" wanted < <(_pi_panel_pkgs)
	fi
	# Raspberry Pi's own file manager, where Debian's is installed; it is
	# repacked to run beside it, as pcmanfm-pi (see fm_coinstall)
	if (( O_FM )) && [[ -n $(_installed_version pcmanfm) ]]; then
		mapfile -t -O "${#wanted[@]}" wanted < <(_pi_fm_pkgs "$H_SUITE")
	fi
	if [[ -n $O_ONLY && " ${wanted[*]} " != *" $(_theme_pkg "$O_ONLY") "* ]]; then
		die "$O_ONLY is not available for Debian $H_SUITE/$H_ARCH"
	fi

	if [[ -n $O_REPO ]]; then
		step "Resolving packages from the offline repository ($H_SUITE, $H_ARCH)"
	else
		step "Resolving the latest official packages ($H_SUITE, $H_ARCH)"
		setup_keyring
		index_load rpi "$H_SUITE" "$H_ARCH" || die "cannot download the $H_SUITE package index from $RPI_ARCHIVE"
		ok "Package index signature verified (Raspberry Pi Archive Signing Key)"
	fi
	FETCH_PKGS=()
	for p in "${wanted[@]}"; do IN_SET[$p]=1; done
	for p in "${wanted[@]}"; do
		if resolve_pkg "$p"; then FETCH_PKGS+=("$p"); else warn "$p is not available for $H_SUITE/$H_ARCH; skipping it"; fi
	done
	[[ " ${FETCH_PKGS[*]} " == *-theme\ * ]] || die "no theme packages are available for $H_SUITE/$H_ARCH"

	# A Raspberry Pi package must never replace a package from the APT sources.
	for p in "${FETCH_PKGS[@]}"; do
		if [[ -n $(apt-cache madison "$p" 2>/dev/null) ]]; then
			die "refusing to install $p from Raspberry Pi OS: your APT sources provide a package with that name"
		fi
	done

	# Debian helpers: the GTK 2 pixmap engine, the sound theme, the monospace
	# font, and the icon themes the Pi icons inherit.
	helpers=(gtk2-engines-pixbuf sound-theme-freedesktop)
	(( O_WITH_FONT )) && helpers+=("$(_mono_font_pkg "$H_SUITE")")
	[[ " ${FETCH_PKGS[*]} " == *" pixflat-icons "* ]] && helpers+=(libgtk2.0-bin gnome-icon-theme)
	[[ " ${FETCH_PKGS[*]} " == *" rpd-icons "* ]] && helpers+=(gnome-icon-theme)
	[[ " ${FETCH_PKGS[*]} " == *" pixtrix-icons "* ]] && helpers+=(adwaita-icon-theme-legacy)
	(( O_QT )) && helpers+=(qt5-gtk-platformtheme qt6-gtk-platformtheme)
	# Tray applets the LXDE panel needs, only where the service they control is
	# already installed, so network and Bluetooth management stay unchanged:
	# nm-applet for the network icon (neither panel has a network plugin that
	# works on Debian), and blueman for Bluetooth unless Raspberry Pi's panel,
	# which has its own Bluetooth plugin, is used.
	if (( O_PANEL )) && [[ " ${DESKTOPS[*]} " == *" lxde "* ]]; then
		if [[ -n $(_installed_version network-manager) ]]; then   # derivatives may name it differently
			for p in "$(_nm_applet_pkg "$H_SUITE")" network-manager-gnome; do
				if [[ -n $O_REPO ]] || apt_has "$p"; then helpers+=("$p"); break; fi
			done
		fi
		if [[ -n $(_installed_version bluez) && " ${FETCH_PKGS[*]} " != *" lxpanel-pi "* ]]; then helpers+=(blueman); fi
		# The Help menu of Raspberry Pi OS: Debian Reference
		helpers+=(debian-reference-common debian-reference-en)
	fi
	APT_PKGS=()
	for p in "${helpers[@]}"; do
		[[ " ${APT_PKGS[*]} " == *" $p "* || -n $(_installed_version "$p") ]] && continue
		if [[ -n $O_REPO ]] || apt_has "$p"; then APT_PKGS+=("$p"); fi
	done

	if [[ -n $O_REPO ]]; then
		# Offline: install every member of the selection's dependency closure that
		# the repository has and the system lacks; the rest is already installed.
		local -a roots=("${FETCH_PKGS[@]}" "${APT_PKGS[@]}")
		APT_PKGS=()
		while read -r p; do
			[[ -n ${PKG_VER[$p]:-} || -n $(_installed_version "$p") ]] && continue
			if resolve_pkg "$p"; then FETCH_PKGS+=("$p") DEP_PKGS+=("$p"); fi
		done < <(INSTALLED=1 _closure "$WORKDIR/index/local/$H_SUITE/Packages-$H_ARCH" "${roots[@]}")
		for p in "${roots[@]}"; do
			[[ -n ${PKG_VER[$p]:-} || -n $(_installed_version "$p") ]] || warn "$p is not in the offline repository; skipping it"
		done
	fi
	for p in "${FETCH_PKGS[@]}" "${APT_PKGS[@]}"; do IN_SET[$p]=1; done
}

# Refresh the APT lists, so dependencies come from the current Debian point
# release and security updates; stop if a Debian helper is unavailable.
_apt_ready() {
	local p
	[[ -n $O_REPO ]] && return 0
	info "Refreshing APT package lists"
	as_root apt-get update -q >/dev/null || die "apt-get update failed"
	for p in "${APT_PKGS[@]}"; do
		apt_has "$p" || die "the Debian package '$p' is not available from your APT sources"
	done
}

# Add every GTK 2 engine that the downloaded themes use but nothing installs.
# Usage: _add_theme_engines FILES-ARRAY-NAME
_add_theme_engines() {
	local -n _files=$1
	local e f
	for e in $(_engine_pkgs "${_files[@]}"); do
		[[ -n ${IN_SET[$e]:-} || -n $(_installed_version "$e") ]] && continue
		IN_SET[$e]=1
		if [[ -n $O_REPO ]] || _is_rpi_engine "$e"; then
			if ! resolve_pkg "$e"; then warn "GTK 2 engine $e is not available; GTK 2 applications may look wrong"; continue; fi
			f=$(download_pkg "$e")
			[[ -n $O_REPO ]] || f=$(compat_fix "$f")
			_files+=("$f")
			FETCH_PKGS+=("$e")
		elif apt_has "$e"; then
			APT_PKGS+=("$e")
		else
			continue
		fi
		info "Adding GTK 2 engine $e required by the theme"
	done
}

# Offline: place the verified files in a private APT archive cache under APT's
# own names. APT then uses them even when the APT sources list the same
# version, instead of trying to download it.
_prime_apt_cache() {
	local f
	mkdir -p "$WORKDIR/archives/partial"
	for f; do
		cp -- "$f" "$WORKDIR/archives/$(dpkg-deb -f "$f" Package)_$(dpkg-deb -f "$f" Version | sed 's/:/%3a/')_$(dpkg-deb -f "$f" Architecture).deb"
	done
}

# Record newly installed packages for --uninstall. Only packages that another
# installed package depends on are marked automatic (the GTK 2 engines and
# runtime the themes and icons depend on and, offline, every dependency), as
# APT marks the dependencies it installs itself. Everything else, such as the
# panel plugins, fallback icons, fonts and sounds, which nothing depends on,
# stays manual, so 'apt autoremove' never removes it.
_record_installed() {
	local p newly=() autos=()
	for p; do
		(( O_DRY_RUN )) || [[ -n $(_installed_version "$p") ]] || continue
		newly+=("$p")
		case $p in gtk2-engines-*|libgtk2.0-*|libgdk-pixbuf*) autos+=("$p") ;;
			*) if [[ " ${DEP_PKGS[*]} " == *" $p "* ]]; then autos+=("$p"); fi ;;
		esac
	done
	_fix_auto_marks
	(( ${#newly[@]} )) || return 0
	if (( ${#autos[@]} )); then as_root apt-mark auto "${autos[@]}" >/dev/null; fi
	as_root mkdir -p "$APP_SYS_STATE"
	(( O_DRY_RUN )) && return 0
	{ cat "$APP_SYS_STATE/installed-packages" 2>/dev/null || true; printf '%s\n' "${newly[@]}"; } \
		| sort -u | as_root tee "$APP_SYS_STATE/installed-packages.new" >/dev/null
	as_root mv -f "$APP_SYS_STATE/installed-packages.new" "$APP_SYS_STATE/installed-packages"
}

# Version 2.0.0 marked packages automatic that nothing depends on, so 'apt
# autoremove' offered to remove them. Mark those this script installed manual.
_fix_auto_marks() {
	local -a fix=()
	[[ -f $APP_SYS_STATE/installed-packages ]] || return 0
	mapfile -t fix < <(apt-mark showauto 2>/dev/null \
		| grep -xE 'lpplug-.*|pplug-.*|gnome-icon-theme|adwaita-icon-theme-legacy|fonts-liberation2?|sound-theme-freedesktop' \
		| grep -xF -f "$APP_SYS_STATE/installed-packages" || true)
	if (( ${#fix[@]} )); then as_root apt-mark manual "${fix[@]}" >/dev/null; fi
}

# Print the state of a resolved package on this system: new, an update, or
# current. A newer installed version is never downgraded.
_pkg_status() {
	local cur from=""
	cur=$(_installed_version "$1")
	[[ ${PKG_SUITE[$1]:-$H_SUITE} == "$H_SUITE" || ${PKG_AID[$1]:-} == local ]] || from=" (from ${PKG_SUITE[$1]})"
	if [[ -z $cur ]]; then echo "new$from"
	elif dpkg --compare-versions "$cur" lt "${PKG_VER[$1]}"; then echo "update from $cur$from"
	elif dpkg --compare-versions "$cur" eq "${PKG_VER[$1]}"; then echo "up to date"
	else echo "installed $cur is newer; kept"; fi
}

# Print one package line of a status table.
_pkg_line() { printf '    %-11s %-28s %-18s %s\n' "$(_pkg_category "$1")" "$1" "$2" "$3" >&2; }

# Warn about any package that is missing or older than resolved after APT ran.
_verify_installed() {
	local p cur bad=0
	for p in "${FETCH_PKGS[@]}" "${APT_PKGS[@]}"; do
		cur=$(_installed_version "$p")
		if [[ -z $cur ]]; then
			warn "$p is not installed"; bad=1
		elif [[ -n ${PKG_VER[$p]:-} ]] && dpkg --compare-versions "$cur" lt "${PKG_VER[$p]}"; then
			warn "$p $cur is installed, older than ${PKG_VER[$p]}"; bad=1
		fi
	done
	(( bad )) || ok "Installed versions verified"
}

# Stop unless every package in APT's plan comes from an official source: the
# verified files ("local-deb") or the Debian archive (on a derivative, its own
# archive). This keeps third-party and Raspberry Pi rebuilds of Debian packages
# out, even if such a source is configured.
# Usage: _check_origins APT-SIMULATION-OUTPUT
_check_origins() {
	local line pkg origins own=Debian
	[[ $H_ID == debian ]] || own=${H_ID^}
	while IFS= read -r line; do
		pkg=$(awk '{ print $2 }' <<<"$line")
		origins=$(sed -E 's/^Inst [^ ]+ (\[[^]]*\] )?\([^ ]+ ([^[]*)\[.*/\2/' <<<"$line")
		if [[ $origins != *local-deb* && $origins != *Debian* && $origins != *"$own"* ]]; then
			die "refusing to install $pkg from '${origins% }': Debian packages must come from Debian"
		fi
	done < <(grep '^Inst ' <<<"$1")
}

# Download, verify and install the packages. APT never removes packages
# (--no-remove) and, offline, never downloads (--no-download).
install_all() {
	local p f cur sim
	local -a files=() before=() opts=(-y --no-remove -o Dpkg::Use-Pty=0)
	if [[ -n $O_REPO ]]; then step "Preparing packages"; else step "Downloading and verifying packages"; fi
	(( O_DRY_RUN )) || _apt_ready
	for p in "${FETCH_PKGS[@]}"; do
		cur=$(_installed_version "$p")
		if [[ -n $cur ]] && dpkg --compare-versions "$cur" ge "${PKG_VER[$p]}"; then
			ok "$p $cur is already installed and up to date"
		elif (( O_DRY_RUN )); then
			log "   [dry-run] fetch $(_archive_url "${PKG_AID[$p]}")/${PKG_FILE[$p]}"
		else
			f=$(download_pkg "$p")
			[[ -n $O_REPO ]] || f=$(fm_coinstall "$(compat_fix "$f")")   # ./packages is adapted already
			files+=("$f")
		fi
	done
	(( O_DRY_RUN )) || _add_theme_engines files
	if (( O_LIGHTDM && O_DO_APPLY )); then
		if (( O_DRY_RUN )); then log "   [dry-run] unpack the login screen wallpaper from $ART_PKG (not installed)"
		else _get_login_art; fi
	fi
	for p in "${FETCH_PKGS[@]}" "${APT_PKGS[@]}"; do
		[[ -n $(_installed_version "$p") ]] || before+=("$p")
	done
	if [[ -n $O_REPO ]]; then
		# Offline: only what is needed, never downloads (recommended packages
		# outside ./packages would otherwise be fetched from the APT sources)
		opts+=(--no-download --no-install-recommends -o "Dir::Cache::archives=$WORKDIR/archives/")
		_prime_apt_cache "${files[@]}"
	fi

	step "Installing packages"
	if (( ${#files[@]} + ${#APT_PKGS[@]} )); then
		if (( ! O_DRY_RUN )); then
			if ! sim=$(LC_ALL=C apt-get install --simulate "${opts[@]}" "${files[@]}" "${APT_PKGS[@]}" 2>&1); then
				tail -n 15 <<<"$sim" >&2
				[[ -n $O_REPO ]] && warn "offline mode can only use packages that are installed or in ./packages"
				die "APT cannot install the packages on this system (see above)"
			fi
			_check_origins "$sim"
		fi
		as_root env DEBIAN_FRONTEND=noninteractive apt-get install "${opts[@]}" "${files[@]}" "${APT_PKGS[@]}"
	fi
	if (( O_DRY_RUN )); then ok "Raspberry Pi OS packages installed"; else _verify_installed; fi

	_record_installed "${before[@]}"
}

# Build and install pixflat-theme-debian for the installed themes and the
# chosen look's login screen.
install_local_pkg() {
	local f
	step "Building the Debian compatibility package ($APP_PKG)"
	if (( O_DRY_RUN )); then
		log "   [dry-run] generate icon overlays, Xfwm4 themes and the login screen style; install $APP_PKG"
		return 0
	fi
	# --apply-only on a system installed without the login screen wallpaper
	if (( O_LIGHTDM )) && [[ -n ${T_GTK:-} && ! -d $WORKDIR/login && ! -d /usr/share/$APP_PKG/login ]]; then
		_get_login_art
	fi
	f=$(build_local_pkg)
	as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-remove -o Dpkg::Use-Pty=0 "$f" >/dev/null
	ok "Installed $(basename "$f")"
}

# Succeed if Raspberry Pi's own greeter is installed and can run here.
_pi_greeter_ok() {
	[[ -x /usr/sbin/pi-greeter && -f /usr/share/xgreeters/pi-greeter-x.desktop ]] || return 1
	! ldd /usr/sbin/pi-greeter 2>/dev/null | grep -q 'not found'
}

# Set up Raspberry Pi's own login screen: its greeter program shows the same
# login box, so only its settings (pi-greeter.conf) are adapted: the Debian
# logo instead of the Raspberry Pi one, the login wallpaper this script
# unpacked, and the chosen theme, icons and font. The original file is kept and
# --uninstall puts it back.
install_greeter_conf() {
	local conf=/etc/lightdm/pi-greeter.conf img=RPiSystem.png logo wall
	_pi_greeter_ok || return 0
	(( T_DARK )) && img=RPiSystem_dark.png
	logo=$(_greeter_logo || true)
	wall=/usr/share/$APP_PKG/login/$img
	[[ -f $wall ]] || wall=/usr/share/$APP_PKG/login/RPiSystem.png
	step "Setting up the Raspberry Pi OS login screen (pi-greeter)"
	if (( O_DRY_RUN )); then log "   [dry-run] $conf: Debian logo, wallpaper, $T_GTK, $T_FONT"; return 0; fi
	as_root mkdir -p "$APP_SYS_STATE"
	if [[ -f $conf && ! -f $APP_SYS_STATE/pi-greeter.conf.orig ]]; then
		as_root cp -a -- "$conf" "$APP_SYS_STATE/pi-greeter.conf.orig"
	fi
	{
		printf '# Written by %s %s: the Raspberry Pi OS login screen with Debian branding.\n' "$APP_NAME" "$APP_VERSION"
		printf '# The original file is in %s.\n[greeter]\n' "$APP_SYS_STATE/pi-greeter.conf.orig"
		if [[ -n $logo ]]; then printf 'default-user-image=%s\n' "$logo"; fi
		printf 'desktop_bg=%s\n' "$T_DESK_BG"
		if [[ -f $wall ]]; then printf 'wallpaper=%s\nwallpaper_mode=crop\n' "$wall"; fi
		printf 'gtk-theme-name=%s\ngtk-icon-theme-name=%s-Debian\n' "$T_GTK" "$T_ICON_BASE"
		if [[ -n $T_FONT ]]; then printf 'gtk-font-name=%s\n' "$T_FONT"; fi
	} | as_root tee "$conf" >/dev/null
	ok "Login screen: Raspberry Pi's own greeter, with the Debian logo"
}

# ---------------------------------------------------------------------------
# Offline repository builder (install-offline.sh --update-packages)
# ---------------------------------------------------------------------------
# Print the component type of a package, also its folder in ./packages.
_pkg_category() {
	case $1 in
		sound-theme-*)               echo sounds ;;
		pi-greeter)                  echo greeter ;;
		pcmanfm-pi)                  echo files ;;
		lxpanel-pi|lpplug-*|pplug-*|pishutdown|gui-runcmd|debian-reference-*|network-manager-gnome|network-manager-applet|nm-connection-editor|blueman) echo panel ;;
		*icon-theme*|*-icons)        echo icons ;;
		*-theme)                     echo themes ;;
		fonts-*)                     echo fonts ;;
		gtk2-engines-*|libgtk2.0-*|libgdk-pixbuf*) echo engines ;;   # GTK 2 engines and runtime
		*wallpaper*|"$ART_PKG")      echo wallpapers ;;
		*)                           echo dependencies ;;
	esac
}

# Print the Packages index entry of a .deb file.
# Usage: _stanza DEB FILENAME-IN-REPOSITORY
_stanza() {
	local deb=$1 rel=$2 f v
	for f in Package Version Architecture Pre-Depends Depends Recommends Suggests Conflicts Breaks \
		Replaces Provides Enhances Installed-Size Maintainer Section Priority Multi-Arch Source; do
		v=$(dpkg-deb -f "$deb" "$f" 2>/dev/null) || continue
		if [[ -n $v ]]; then printf '%s: %s\n' "$f" "$v"; fi
	done
	printf 'Filename: %s\nSize: %s\nSHA256: %s\n' "$rel" "$(stat -c %s "$deb")" "$(sha256sum "$deb" | cut -d' ' -f1)"
	printf 'Description: %s\n\n' "$(dpkg-deb -f "$deb" Description | head -n1)"
}

# Write VERSIONS.md: the build date and the version, releases and origin of
# every package in the repository.
# shellcheck disable=SC2016  # Markdown backticks
_write_versions() {
	local dir=$1 rpi
	rpi=$({ _bundle_rpi_pkgs trixie; echo "$ART_PKG"; } | paste -sd' ' -)
	{
		printf '# Package versions\n\n'
		printf 'Built by `install-offline.sh --update-packages` (%s %s) on %s from\n' "$APP_NAME" "$APP_VERSION" "$(date -u '+%Y-%m-%d %H:%M UTC')"
		printf '%s and %s. Every file is listed in `SHA256SUMS`.\n\n' "$RPI_ARCHIVE" "$DEBIAN_ARCHIVE"
		printf '| Package | Version | Releases | Source |\n|---|---|---|---|\n'
		RPI=" $rpi " awk 'BEGIN { RS = ""; FS = "\n" }
			{
				p = v = ""
				for (i = 1; i <= NF; i++) {
					if ($i ~ /^Package: /) p = substr($i, 10)
					else if ($i ~ /^Version: /) v = substr($i, 10)
				}
				o = index(ENVIRON["RPI"], " " p " ") ? "Raspberry Pi OS" : "Debian"
				split(FILENAME, s, "/"); print p "\t" v "\t" s[length(s) - 3] "\t" o
			}' "$dir"/dists/*/main/binary-*/Packages \
			| sort -u | awk -F'\t' '
				{ k = $1 "\t" $2; if (!(k in r)) { ord[++n] = k; r[k] = $3; src[k] = $4 } else if (index(r[k], $3) == 0) r[k] = r[k] ", " $3 }
				END { for (i = 1; i <= n; i++) { split(ord[i], a, "\t"); printf "| %s | %s | %s | %s |\n", a[1], a[2], r[ord[i]], src[ord[i]] } }'
	} >"$dir/VERSIONS.md"
}

# Write SHA256SUMS for every file of the repository.
# shellcheck disable=SC2094  # SHA256SUMS is excluded from its own listing
_write_checksums() {
	(cd -- "$1" && find . -type f ! -name SHA256SUMS -printf '%P\n' | LC_ALL=C sort | xargs -d '\n' sha256sum >SHA256SUMS)
}

# Write "name version" for every package of a Packages index, and "name" or
# "name version" for every virtual package it provides.
_index_names() {
	awk 'BEGIN { RS = ""; FS = "\n" }
		{
			n = v = pr = ""
			for (i = 1; i <= NF; i++) {
				if ($i ~ /^Package: /) n = substr($i, 10)
				else if ($i ~ /^Version: /) v = substr($i, 10)
				else if ($i ~ /^Provides: /) pr = substr($i, 11)
			}
			print n " " v
			m = split(pr, a, ",")
			for (j = 1; j <= m; j++) {
				x = a[j]; pv = ""
				if (match(x, /\(= *[^)]+\)/)) { pv = substr(x, RSTART + 1, RLENGTH - 2); sub(/^= */, "", pv) }
				sub(/^[ \t]+/, "", x); sub(/[ \t(].*/, "", x)
				print x (pv == "" ? "" : " " pv)
			}
		}' "$1" | sort -u
}

# Add a .deb file to the staging repository and its index.
# Usage: _stage_pkg STAGE INDEX-DIR PACKAGE FILE
_stage_pkg() {
	local rel
	rel=pool/$(_pkg_category "$3")/$(basename "$4")
	[[ -f $1/$rel ]] || install -D -m 0644 "$4" "$1/$rel"
	_stanza "$1/$rel" "$rel" >>"$2/Packages"
}

# Print, sorted, what a Debian desktop installation of an edition (lxde, xfce,
# gnome, kde, cinnamon, mate, lxqt) has: the base system and the desktop task
# with recommended packages. Usage: _desktop_base INDEX EDITION
_desktop_base() {
	RECOMMENDS=1 BASE=priority _closure "$1" task-desktop "task-$2-desktop" | LC_ALL=C sort -u
}

# Print the Debian packages that the given Debian packages and .deb files need
# and a baseline lacks. Names the baseline has, or provides, satisfy any
# alternative. Usage: _bundle_closure INDEX BASELINE [PACKAGE]... -- [DEB]...
_bundle_closure() {
	local idx=$1 base=$2 have=$2.have
	local -a pkgs=() roots=()
	shift 2
	while (( $# )) && [[ $1 != -- ]]; do pkgs+=("$1"); shift; done
	(( $# )) && shift
	awk 'NR == FNR { b[$1] = 1; next }
		/^Package: / { p = $2 } /^Provides: / && (p in b) {
			sub(/^Provides: /, ""); n = split($0, a, ",")
			for (i = 1; i <= n; i++) { x = a[i]; sub(/^[ \t]+/, "", x); sub(/[ \t(].*/, "", x); print x }
		}' "$base" "$idx" | cat - "$base" | sort -u >"$have"
	if (( $# )); then mapfile -t roots < <(_deb_depnames "$@"); fi
	HAVE=$have _closure "$idx" "${pkgs[@]}" "${roots[@]}" | grep -vxF -f "$base" || true
}

# Build ./packages (install-offline.sh --update-packages): for every release
# and architecture, the Raspberry Pi OS packages plus the Debian packages they
# need that a standard Debian desktop lacks. The result replaces ./packages
# only when complete.
build_offline_repo() {
	local dest=$O_REPO stage suite arch p f e idx deb i n=0
	local -a rpis debs got lx_debs all_debs lx_got all_got
	preflight_tools
	[[ -r $DEBIAN_KEYRING ]] || die "$DEBIAN_KEYRING is missing (install debian-archive-keyring)"
	step "Building the offline repository from the official repositories"
	log "  Raspberry Pi OS  $RPI_ARCHIVE"
	log "  Debian           $DEBIAN_ARCHIVE"
	log "  Releases         ${OFFLINE_SUITES[*]}"
	log "  Architectures    ${OFFLINE_ARCHES[*]}"
	log "  Destination      $dest"
	ask "Proceed" y || die "aborted"
	setup_keyring
	stage=$(mktemp -d "$(dirname -- "$dest")/.packages.XXXXXX")
	BUILD_STAGE=$stage   # cleanup() removes it if the build fails
	mkdir -p "$stage/pool"
	for suite in "${OFFLINE_SUITES[@]}"; do
		for arch in "${OFFLINE_ARCHES[@]}"; do
			step "$suite / $arch"
			H_SUITE=$suite H_ARCH=$arch
			PKG_VER=() PKG_FILE=() PKG_SHA=() PKG_SIZE=() PKG_SUITE=() PKG_AID=() IN_SET=() AVAIL=()
			index_load debian "$suite" "$arch" || die "cannot load the Debian $suite/$arch index"
			deb=$WORKDIR/index/debian/$suite/Packages-$arch
			DEP_INDEX=$deb.names
			_index_names "$deb" >"$DEP_INDEX"
			mapfile -t rpis < <(_bundle_rpi_pkgs "$suite")
			mapfile -t debs < <(_bundle_deb_pkgs "$suite")
			for p in "${rpis[@]}" "${debs[@]}"; do IN_SET[$p]=1; done
			idx=$stage/dists/$suite/main/binary-$arch
			mkdir -p "$idx"
			: >"$idx/Packages"
			# Raspberry Pi OS packages, plus any GTK 2 engine their gtkrc files use
			got=() i=0
			while (( i < ${#rpis[@]} )); do
				p=${rpis[i]} i=$(( i + 1 ))
				resolve_pkg "$p" rpi || die "$p is not available for $suite/$arch"
				f=$(download_pkg "$p")
				f=$(fm_coinstall "$(compat_fix "$f")")
				got+=("$f")
				_stage_pkg "$stage" "$idx" "$p" "$f"
				ok "$p ${PKG_VER[$p]} (Raspberry Pi OS ${PKG_SUITE[$p]})"
				for e in $(_engine_pkgs "$f"); do
					[[ -n ${IN_SET[$e]:-} ]] && continue
					IN_SET[$e]=1
					if _is_rpi_engine "$e"; then rpis+=("$e"); else debs+=("$e"); fi
				done
			done
			# The login screen wallpaper source; never installed, so its
			# dependencies are not bundled
			if [[ $suite == "$ART_SUITE" ]]; then
				_art_resolve rpi || die "$ART_PKG is not available for $suite/$arch"
				f=$(download_pkg "$ART_PKG")
				_stage_pkg "$stage" "$idx" "$ART_PKG" "$f"
				ok "$ART_PKG ${PKG_VER[$ART_PKG]} (Raspberry Pi OS $suite; login screen wallpaper)"
			fi
			# Debian packages: the dependency closure of everything bundled, minus
			# what Debian's desktop installations already have (the base system
			# and the desktop task with its recommended packages, as the Debian
			# installer sets them up). What only the LXDE desktop uses (Raspberry
			# Pi's panel, the tray applets) is left out when Debian's LXDE desktop
			# has it; what every theme needs, when every Debian desktop has it.
			_desktop_base "$deb" lxde >"$deb.lxde"
			cp -- "$deb.lxde" "$deb.all"
			for e in xfce gnome kde cinnamon mate lxqt; do
				_desktop_base "$deb" "$e" | LC_ALL=C comm -12 "$deb.all" - >"$deb.tmp"
				mv -- "$deb.tmp" "$deb.all"
			done
			lx_debs=() all_debs=() lx_got=() all_got=()
			for p in "${debs[@]}"; do
				case $p in "$(_nm_applet_pkg "$suite")"|blueman|debian-reference-*) lx_debs+=("$p") ;; *) all_debs+=("$p") ;; esac
			done
			for f in "${got[@]}"; do
				if _pi_panel_pkgs | grep -qxF "$(dpkg-deb -f "$f" Package)"; then lx_got+=("$f"); else all_got+=("$f"); fi
			done
			mapfile -t debs < <({ _bundle_closure "$deb" "$deb.all" "${all_debs[@]}" -- "${all_got[@]}"
				_bundle_closure "$deb" "$deb.lxde" "${lx_debs[@]}" -- "${lx_got[@]}"; } | LC_ALL=C sort -u \
				| while read -r p; do [[ " ${rpis[*]} " == *" $p "* ]] || echo "$p"; done)
			for p in "${debs[@]}"; do
				resolve_pkg "$p" debian || die "$p is not available in Debian $suite/$arch"
				f=$(download_pkg "$p")
				_stage_pkg "$stage" "$idx" "$p" "$f"
				ok "$p ${PKG_VER[$p]} (Debian $suite)"
			done
			n=$(( n + 1 ))
		done
	done
	DEP_INDEX=""
	_write_versions "$stage"
	_write_checksums "$stage"
	chmod -R u=rwX,go=rX "$stage"
	if [[ -e $dest ]]; then rm -rf -- "$dest.old"; mv -- "$dest" "$dest.old"; fi
	mv -- "$stage" "$dest"
	BUILD_STAGE=""
	rm -rf -- "$dest.old"
	ok "Offline repository ready: $dest ($(du -sh -- "$dest" | cut -f1), $(find "$dest/pool" -name '*.deb' | wc -l) packages, $n indexes)"
}

# ---------------------------------------------------------------------------
# Per-user settings. These functions run as the target user. Every changed
# file is backed up and every changed setting recorded in the state directory,
# so that unapply_main can restore them.
# ---------------------------------------------------------------------------

# Print the state directory.
_st() { printf '%s\n' "${XDG_STATE_HOME:-$HOME/.local/state}/$APP_NAME"; }

# Create the state directory, recording parent folders it creates.
_state_init() {
	A_STATE=$(_st)
	(( O_DRY_RUN )) && return 0
	local new
	new=$(_missing_dirs "$(dirname "$A_STATE")")
	mkdir -p "$A_STATE/files"
	touch "$A_STATE/keys" "$A_STATE/created" "$A_STATE/created-dirs" "$A_STATE/restore.sh"
	if [[ -n $new ]]; then printf '%s\n' "$new" >>"$A_STATE/created-dirs"; fi
}

# Print the missing directories of a path below $HOME, deepest first.
_missing_dirs() {
	local d=$1
	while [[ ! -d $d && $d == "$HOME"/* ]]; do printf '%s\n' "${d#"$HOME"/}"; d=$(dirname "$d"); done
}

# Back up a file, or record it as new, before it is first changed.
_track_file() {
	(( O_DRY_RUN )) && return 0
	local path=$1 rel=${1#"$HOME"/}
	grep -qxF "file:$rel" "$A_STATE/keys" && return 0
	if [[ -e $path || -L $path ]]; then
		mkdir -p "$(dirname "$A_STATE/files/$rel")"
		cp -a -- "$path" "$A_STATE/files/$rel"
	else
		printf '%s\n' "$rel" >>"$A_STATE/created"
		_missing_dirs "$(dirname "$path")" >>"$A_STATE/created-dirs"
	fi
	printf 'file:%s\n' "$rel" >>"$A_STATE/keys"
}

# Succeed only the first time a one-time step runs for this user, so later
# runs (updates, look changes) keep the user's own changes to what it set up.
# Usage: _once STEP
_once() {
	(( O_DRY_RUN )) && return 0
	grep -qxF "once:$1" "$A_STATE/keys" && return 1
	printf 'once:%s\n' "$1" >>"$A_STATE/keys"
}

# Record, once per setting, the command that restores its original value.
# Usage: _track_cmd KEY COMMAND
_track_cmd() {
	(( O_DRY_RUN )) && return 0
	grep -qxF "$1" "$A_STATE/keys" && return 0
	printf '%s\n' "$2" >>"$A_STATE/restore.sh"
	printf '%s\n' "$1" >>"$A_STATE/keys"
}

# Replace a file's content with stdin, keeping its inode and permissions.
_write() {
	local tmp
	tmp=$(mktemp)
	cat >"$tmp"
	mkdir -p "$(dirname "$1")"
	cat "$tmp" >"$1"
	rm -f "$tmp"
}

# Set keys in a section of an INI file, creating them as needed.
# Usage: _ini_set FILE SECTION KEY VALUE [KEY VALUE]...
_ini_set() {
	local file=$1 sec=$2; shift 2
	if (( O_DRY_RUN )); then
		while (( $# >= 2 )); do log "   [dry-run] $file: [$sec] $1=$2"; shift 2; done
		return 0
	fi
	_track_file "$file"
	while (( $# >= 2 )); do
		{ [[ -f $file ]] && cat -- "$file"; true; } \
			| S="[$sec]" K=$1 V=$2 awk '
				BEGIN { s = ENVIRON["S"]; k = ENVIRON["K"]; v = ENVIRON["V"] }
				/^[ \t]*\[.*\][ \t]*$/ {
					if (ins && !done) { print k "=" v; done = 1 }
					h = $0; gsub(/^[ \t]+|[ \t]+$/, "", h); ins = (h == s)
				}
				ins && !done && index($0, "=") {
					kk = substr($0, 1, index($0, "=") - 1); gsub(/^[ \t]+|[ \t]+$/, "", kk)
					if (kk == k) { print k "=" v; done = 1; next }
				}
				{ print }
				END { if (!done) { if (!ins) { if (NR) print ""; print s } print k "=" v } }' \
			| _write "$file"
		shift 2
	done
}

# Set a key in a "key=value" file without sections.
# Usage: _kv_set FILE KEY VALUE [QUOTE-CHAR]
_kv_set() {
	local file=$1 key=$2 val=$3 quote=${4:-}
	if (( O_DRY_RUN )); then log "   [dry-run] $file: $key=$quote$val$quote"; return 0; fi
	_track_file "$file"
	{ [[ -f $file ]] && cat -- "$file"; true; } \
		| K=$key V="$quote$val$quote" awk '
			BEGIN { k = ENVIRON["K"]; v = ENVIRON["V"] }
			index($0, "=") {
				kk = substr($0, 1, index($0, "=") - 1); gsub(/^[ \t]+|[ \t]+$/, "", kk)
				if (kk == k) { if (!done) print k "=" v; done = 1; next }
			}
			{ print }
			END { if (!done) print k "=" v }' \
		| _write "$file"
}

# Replace or append a block between marker comments.
# Usage: _block_set FILE TAG CONTENT
_block_set() {
	local file=$1 tag=$2 content=$3 b e
	case $file in *.css) b="/* >>> $tag >>> */" e="/* <<< $tag <<< */" ;; *) b="# >>> $tag >>>" e="# <<< $tag <<<" ;; esac
	if (( O_DRY_RUN )); then log "   [dry-run] $file: update block '$tag'"; return 0; fi
	_track_file "$file"
	{ [[ -f $file ]] && cat -- "$file"; true; } \
		| B=$b E=$e C=$content awk '
			$0 == ENVIRON["B"] { skip = 1; next }
			$0 == ENVIRON["E"] { skip = 0; next }
			!skip { print }
			END { print ENVIRON["B"]; print ENVIRON["C"]; print ENVIRON["E"] }' \
		| _write "$file"
}

# Copy the first existing system default into place, if the file is missing.
# Usage: _seed FILE DEFAULT...
_seed() {
	local dst=$1 src
	shift
	[[ -e $dst ]] && return 0
	for src; do
		if [[ -f $src ]]; then
			if (( O_DRY_RUN )); then log "   [dry-run] copy $src -> $dst"; return 0; fi
			_track_file "$dst"
			mkdir -p "$(dirname "$dst")"
			cp -- "$src" "$dst"
			return 0
		fi
	done
	return 1
}

# Replace the first <TAG>…</TAG> element of an Openbox or labwc rc.xml with
# CONTENT, or add CONTENT before the closing root tag if there is none.
# Usage: _xml_block FILE TAG CONTENT
_xml_block() {
	T=$2 C=$3 awk '
		BEGIN { t = ENVIRON["T"] }
		!done && $0 ~ "<" t "[ >]" { skip = 1 }
		skip { if ($0 ~ "</" t ">") { print ENVIRON["C"]; skip = 0; done = 1 }; next }
		!done && /<\/(openbox|labwc)_config>/ { print ENVIRON["C"]; done = 1 }
		{ print }' "$1" | _write "$1"
}

# Set <CHILD>VALUE</CHILD> inside the <PARENT> element, adding it if missing.
# Usage: _xml_child FILE PARENT CHILD VALUE
_xml_child() {
	P=$2 C=$3 V=$4 awk '
		BEGIN { p = ENVIRON["P"]; c = ENVIRON["C"]; el = "<" c ">" ENVIRON["V"] "</" c ">" }
		$0 ~ "<" p ">" { in_p = 1 }
		in_p && !done && $0 ~ "<" c ">.*</" c ">" { sub("<" c ">.*</" c ">", el); done = 1 }
		in_p && !done && $0 ~ "</" p ">" { match($0, /^[ \t]*/); print substr($0, 1, RLENGTH) "  " el; done = 1 }
		$0 ~ "</" p ">" { in_p = 0 }
		{ print }' "$1" | _write "$1"
}

# Print <font> elements for the given places, as Raspberry Pi OS sets them
# (theme font, size 12). With --no-font, the file's current fonts are kept.
# Usage: _xml_fonts FILE PLACE...
_xml_fonts() {
	local file=$1 p; shift
	if [[ -z $T_FONT_FAMILY ]]; then
		sed -n '/<theme>/,/<\/theme>/{/<font/,/<\/font>/p}' "$file"
		return 0
	fi
	for p; do
		printf '    <font place="%s">\n      <name>%s</name>\n      <size>12</size>\n      <weight>%s</weight>\n      <slant>Normal</slant>\n    </font>\n' \
			"$p" "$T_FONT_FAMILY" "$T_FONT_WEIGHT"
	done
}

# Apply the Raspberry Pi OS Openbox settings (lxde-pi-rc.xml / rpd-rc.xml):
# the <theme> section with round corners and invisible handles, and, unless
# THEME-ONLY is set, one desktop and the focus and placement settings.
# Usage: _openbox_rc FILE [THEME-ONLY]
_openbox_rc() {
	local file=$1 theme_only=${2:-0} fonts
	if (( O_DRY_RUN )); then log "   [dry-run] $file: Raspberry Pi OS Openbox settings, theme $T_GTK"; return 0; fi
	_track_file "$file"
	fonts=$(_xml_fonts "$file" ActiveWindow InactiveWindow MenuHeader MenuItem ActiveOnScreenDisplay InactiveOnScreenDisplay)
	_xml_block "$file" theme "$(printf '  <theme>\n    <name>%s</name>\n    <titleLayout>LIMC</titleLayout>\n    <keepBorder>yes</keepBorder>\n    <roundCorners>yes</roundCorners>\n    <invisibleHandles>yes</invisibleHandles>\n    <animateIconify>yes</animateIconify>\n%s\n  </theme>' "$T_GTK" "$fonts")"
	(( theme_only )) && return 0
	_xml_child "$file" desktops number 1
	_xml_child "$file" focus focusDesktop yes
	_xml_child "$file" placement monitor Any
}

# Apply the Raspberry Pi OS labwc look (rpd-wayland-core rc.xml): the <theme>
# section, window snapping and the window switcher.
_labwc_rc() {
	local file=$1 fonts
	if (( O_DRY_RUN )); then log "   [dry-run] $file: Raspberry Pi OS labwc settings, theme $T_GTK"; return 0; fi
	_track_file "$file"
	fonts=$(_xml_fonts "$file" ActiveWindow InactiveWindow OnScreenDisplay MenuItem)
	_xml_block "$file" theme "$(printf '  <theme>\n    <name>%s</name>\n    <cornerRadius>0</cornerRadius>\n    <keepBorder>yes</keepBorder>\n%s\n    <dropShadows>yes</dropShadows>\n    <titlebar>\n      <layout>:iconify,max,close</layout>\n    </titlebar>\n  </theme>' "$T_GTK" "$fonts")"
	# Window snapping and the window switcher, as in Raspberry Pi OS
	_xml_block "$file" snapping '  <snapping>
    <range>0</range>
    <topMaximize>no</topMaximize>
  </snapping>'
	_xml_block "$file" windowSwitcher '  <windowSwitcher show="yes" preview="yes" outlines="yes" allWorkspaces="no">
    <fields>
      <field content="icon" width="5%" />
      <field content="title" width="95%" />
    </fields>
  </windowSwitcher>'
}

# Print the first installed application launcher (.desktop file) of a list.
_launcher() {
	local id
	for id; do
		if [[ -f /usr/share/applications/$id ]]; then printf '%s\n' "$id"; return 0; fi
	done
	return 1
}

# Print the parts of the Raspberry Pi OS panel (raspberrypi-ui-mods /
# rpd-x-core) that both panel programs share. Usage: _panel_global [KEY=VALUE]...
_panel_global() {
	printf '# lxpanel <profile> config file. Manually editing is not recommended.\n'
	printf '# Use preference dialog in lxpanel to adjust config when you can.\n'
	printf '# %s: the Raspberry Pi OS panel layout. Edit it in the panel\n' "$APP_NAME"
	printf '# preferences; this file is then left alone.\n\n'
	printf 'Global {\n'
	printf '  %s\n' edge=top align=left margin=0 widthtype=percent width=100 height=36 transparent=0 \
		tintcolor=#000000 alpha=0 autohide=0 heightwhenhidden=2 setdocktype=1 setpartialstrut=1 \
		usefontcolor=0 fontsize=12 fontcolor=#ffffff usefontsize=0 background=0 \
		backgroundfile=/usr/share/lxpanel/images/background.png iconsize=36 monitor=0 "$@"
	printf '}\n'
}
# Usage: _panel_plugin TYPE [CONFIG-LINE]...
_panel_plugin() {
	local t=$1; shift
	printf 'Plugin {\n  type=%s\n' "$t"
	[[ $t == taskbar ]] && printf '  expand=1\n'
	printf '  Config {\n'
	if (( $# )); then printf '    %s\n' "$@"; fi
	printf '  }\n}\n'
}
# The launchers for web browser, file manager and terminal, then the taskbar.
_panel_tasks() {
	local id
	local -a buttons=()
	for id in "$(_launcher x-www-browser.desktop lxde-x-www-browser.desktop firefox-esr.desktop chromium.desktop)" \
		"$(_launcher pcmanfm-pi.desktop pcmanfm.desktop)" "$(_launcher x-terminal-emulator.desktop lxterminal.desktop lxde-x-terminal-emulator.desktop)"; do
		if [[ -n $id ]]; then buttons+=("Button {" "  id=$id" "}"); fi
	done
	_panel_plugin space Size=4
	_panel_plugin launchbar "${buttons[@]}"
	_panel_plugin space Size=8
	_panel_plugin taskbar tooltips=1 IconsOnly=0 ShowAllDesks=0 UseMouseWheel=1 UseUrgencyHint=1 FlatButton=0 \
		MaxTaskWidth=200 spacing=1 GroupedTasks=0
	_panel_plugin space Size=2
}

# Write the Raspberry Pi OS panel for Debian's lxpanel: menu with the Debian
# logo, launchers, taskbar, tray, volume, clock and battery. Pi-only plugins
# have no Debian counterpart; network and Bluetooth appear in the tray through
# Debian's applets.
_lxpanel_write() {
	local file=$1 plugins='/usr/lib/*/lxpanel/plugins'
	if (( O_DRY_RUN )); then log "   [dry-run] $file: Raspberry Pi OS panel layout"; return 0; fi
	_track_file "$file"
	{
		_panel_global point_at_menu=0
		_panel_plugin menu "image=${A_LOGO:-start-here}" "system {" "}" "separator {" "}" \
			"item {" "  image=system-run" "  command=run" "}" "separator {" "}" \
			"item {" "  image=system-shutdown" "  command=logout" "}"
		[[ $T_ERA == trixie ]] && _panel_plugin separator
		_panel_tasks
		_panel_plugin tray
		if compgen -G "$plugins/volume.so" >/dev/null; then _panel_plugin space Size=2; _panel_plugin volume; fi
		_panel_plugin space Size=2
		_panel_plugin dclock ClockFmt=%R 'TooltipFmt=%A %x' BoldFont=0 IconOnly=0 CenterText=1
		if compgen -G "$plugins/batt.so" >/dev/null; then _panel_plugin space Size=2; _panel_plugin batt HideIfNoBattery=1; fi
	} | _write "$file"
}

# Write the Raspberry Pi OS 13 panel (rpd-x-core) for Raspberry Pi's own panel
# program, without the plugins that do not work on Debian (power, updater,
# network). The tray takes the network plugin's place, between Bluetooth and
# volume, as nm-applet shows the network icon there.
_pi_panel_write() {
	local file=$1 p
	if (( O_DRY_RUN )); then log "   [dry-run] $file: Raspberry Pi OS panel (lxpanel-pi)"; return 0; fi
	_track_file "$file"
	{
		_panel_global point_at_menu=0
		_panel_plugin smenu
		_panel_plugin separator
		_panel_tasks
		_panel_plugin ejecter
		for p in bluetooth tray volumepulse clock batt magnifier; do _panel_plugin space Size=2; _panel_plugin "$p"; done
	} | _write "$file"
}

# Keep only the Raspberry Pi OS set of notification icons in the LXDE panel:
# hide, for this user, autostarted tray applets that Raspberry Pi OS does not
# have (clipboard managers) or whose job a Raspberry Pi plugin does (volume;
# Bluetooth when Raspberry Pi's panel is used), and a second PolicyKit
# authentication agent, which the session refuses. They stay installed; the
# standard "Hidden=true" autostart override is used. Each applet is hidden
# once, the first time it is seen, so an applet the user enables again later
# is left alone.
_hide_extra_applets() {
	local f id
	local -a pats=(volumeicon pasystray pnmixer diodon clipit parcellite)
	(( O_PI_PANEL )) && pats+=(blueman)
	# A second PolicyKit authentication agent makes the session show "an
	# authentication agent already exists for the given subject"; LXDE's own
	# (lxpolkit, started by the session) is the one that stays.
	[[ -x /usr/bin/lxpolkit ]] && pats+=(polkit-gnome-authentication-agent mate-polkit polkit-mate xfce-polkit)
	for id in "${pats[@]}"; do
		for f in /etc/xdg/autostart/"$id"*.desktop; do
			[[ -f $f ]] || continue
			f=$HOME/.config/autostart/${f##*/}
			[[ -f $f ]] && continue   # the user's own autostart choice
			if (( O_DRY_RUN )); then log "   [dry-run] hide tray applet ${f##*/}"; continue; fi
			_once "applet:${f##*/}" || continue
			_track_file "$f"
			printf '[Desktop Entry]\nType=Application\nName=%s\nHidden=true\n' "${f##*/}" | _write "$f"
		done
	done
}

# Bind the Openbox keys of Raspberry Pi OS (rpd-x-core rpd-rc.xml) that control
# Raspberry Pi's panel: menu, Run and Shutdown dialogs, Bluetooth, magnifier
# and volume. Debian's bindings for these keys call lxpanelctl, which that
# panel does not answer; a key the user has bound to something else is kept.
# Usage: _pi_panel_keys RC-XML
_pi_panel_keys() {
	local file=$1 k c
	local -a keys=(
		"Super_L|lxpanelctl-pi command smenu menu"   "C-Escape|lxpanelctl-pi command smenu menu"
		"A-F1|lxpanelctl-pi command smenu menu"      "A-F2|gui-runcmd"   "W-r|gui-runcmd"
		"C-A-End|pishutdown"   "C-A-Delete|pishutdown"
		"C-A-B|lxpanelctl-pi command bluetooth menu" "C-A-M|lxpanelctl-pi command magnifier toggle"
		"XF86AudioRaiseVolume|lxpanelctl-pi command volumepulse volu"
		"XF86AudioLowerVolume|lxpanelctl-pi command volumepulse vold"
		"XF86AudioMute|lxpanelctl-pi command volumepulse mute"
	)
	if (( O_DRY_RUN )); then log "   [dry-run] $file: Raspberry Pi OS panel keys"; return 0; fi
	_track_file "$file"
	for k in "${keys[@]}"; do
		c=${k#*|} k=${k%%|*}
		K=$k C=$c awk '
			function flush() { if (blk ~ /lxpanelctl[ <]/ || blk ~ /amixer|pactl|wpctl/) print nb; else print blk; done = 1 }
			BEGIN {
				k = "<keybind key=\"" ENVIRON["K"] "\""
				nb = "    <keybind key=\"" ENVIRON["K"] "\">\n      <action name=\"Execute\">\n        <command>" ENVIRON["C"] "</command>\n      </action>\n    </keybind>"
			}
			!done && index($0, k) { blk = $0; inb = 1; if ($0 ~ /<\/keybind>/) { inb = 0; flush() }; next }
			inb { blk = blk "\n" $0; if ($0 ~ /<\/keybind>/) { inb = 0; flush() }; next }
			!done && /<\/keyboard>/ { print nb; done = 1 }
			{ print }' "$file" | _write "$file"
	done
}

# The legacy PiX theme has no panel colours or panel styling of its own, which
# leaves panel buttons framed and the tray without a colour to match. Give the
# theme what the newer Raspberry Pi themes have, in a copy for this user that
# loads the official theme first, so that it is complete whichever way it is
# chosen (this script or the appearance settings).
_pix_gtk_panel() {
	local src=/usr/share/themes/PiX/gtk-3.0/gtk.css f=$HOME/.themes/PiX/gtk-3.0/gtk.css
	[[ -f $src ]] || return 0
	if (( O_DRY_RUN )); then log "   [dry-run] $f: panel colours and style for PiX"; return 0; fi
	_track_file "$f"
	cat <<EOF_PIX | _write "$f"
/* Written by $APP_NAME: the official PiX theme, plus the panel colours and
   style the newer Raspberry Pi OS themes have. */
@import url("$src");

@define-color bar_bg_color @theme_bg_color;
@define-color bar_fg_color @theme_fg_color;

#PanelToplevel { color: @bar_fg_color; background-color: @bar_bg_color; }
#PanelToplevel button { padding: 2px 3px; background-image: none; border: 0px; }
#PanelToplevel button, #PanelToplevel:backdrop button > box > label {
  color: @bar_fg_color; background-color: @bar_bg_color; -gtk-icon-shadow: none; -gtk-icon-effect: none; }
#PanelToplevel button:hover, #PanelToplevel button:checked:hover {
  background-color: shade(@bar_bg_color, 0.877); }
#PanelToplevel button:checked { background-color: shade(@bar_bg_color, 0.843); }
#launchbar button { padding: 0px; }
EOF_PIX
}

# Raspberry Pi OS lists Debian Reference in the Help menu (its own copy of the
# entry, in raspi-ui-overrides); Debian's entry says Accessories. Override it
# for this user, so the Help menu holds what it holds on Raspberry Pi OS.
_help_menu_entry() {
	local src=/usr/share/applications/debian-reference-common.desktop f
	[[ -f $src ]] || return 0
	f=$HOME/.local/share/applications/${src##*/}
	if (( O_DRY_RUN )); then log "   [dry-run] $f: Debian Reference in the Help menu"; return 0; fi
	_track_file "$f"
	awk '/^Categories=/ { print "Categories=Help;"; found = 1; next }
		{ print }
		END { if (!found) print "Categories=Help;" }' "$src" | _write "$f"
}

# CSS for Raspberry Pi's panel, written for every theme, because the user can
# change the theme in the appearance settings at any time:
#  * its tray does not clear an icon before redrawing it at a new size, so
#    nm-applet's icon would show its previous image through; an opaque
#    background in the panel colour hides it;
#  * the legacy PiX theme has no panel styling, so its buttons keep the frame
#    and padding of ordinary buttons and cut the icons off. Only the geometry
#    is set here, so the Raspberry Pi themes keep their own colours.
_pi_panel_css() {
	_pix_gtk_panel
	_block_set "$HOME/.config/gtk-3.0/gtk.css" "$APP_NAME-panel" \
		"/* Tray icons on the Raspberry Pi panel: opaque, in the panel colour */
window > image { background-color: @bar_bg_color; }
/* Panel buttons: flat and with the Raspberry Pi OS spacing, so that icons fit
   (the legacy PiX theme styles no panel of its own) */
#PanelToplevel button { padding: 2px 3px; margin: 0px; border: 0px; background-image: none; }
#PanelToplevel button image { -gtk-icon-shadow: none; -gtk-icon-effect: none; }
#launchbar button { padding: 0px; }
#tray, #tray * { padding: 0px; margin: 0px; border: 0px; }"
}

# Start the given panel program in the LXDE session instead of the current one.
# Usage: _lxsession_panel SESSION PROGRAM
_lxsession_panel() {
	local file=$HOME/.config/lxsession/$1/autostart
	_seed "$file" "/etc/xdg/lxsession/$1/autostart" /etc/xdg/lxsession/LXDE/autostart || true
	if (( O_DRY_RUN )); then log "   [dry-run] $file: start $2"; return 0; fi
	_track_file "$file"
	{ [[ -f $file ]] && cat -- "$file"; true; } | P=$2 awk '
		/^@?lxpanel(-pi)?([ \t]|$)/ { if (!done) print "@" ENVIRON["P"]; done = 1; next }
		{ print }
		END { if (!done) print "@" ENVIRON["P"] }' | _write "$file"
}

# Draw the desktop with the given file manager in the LXDE session.
# Usage: _lxsession_desktop SESSION PROGRAM
_lxsession_desktop() {
	local file=$HOME/.config/lxsession/$1/autostart
	_seed "$file" "/etc/xdg/lxsession/$1/autostart" /etc/xdg/lxsession/LXDE/autostart || true
	if (( O_DRY_RUN )); then log "   [dry-run] $file: draw the desktop with $2"; return 0; fi
	_track_file "$file"
	{ [[ -f $file ]] && cat -- "$file"; true; } | P="@$2 --desktop --profile $1" awk '
		/^@?pcmanfm(-pi)?([ \t]|$)/ { if (!done) print ENVIRON["P"]; done = 1; next }
		{ print }
		END { if (!done) print ENVIRON["P"] }' | _write "$file"
}

# Write the file manager settings of Raspberry Pi OS (pcmanfm-pi's
# pcmanfm.conf). Usage: _fm_conf FILE SESSION
_fm_conf() {
	local f=$1
	_seed "$f" "/etc/xdg/pcmanfm/$2/pcmanfm.conf" /etc/xdg/pcmanfm/LXDE/pcmanfm.conf /etc/xdg/pcmanfm/default/pcmanfm.conf || true
	# Defaults for monitors without their own desktop-items file
	_ini_set "$f" desktop desktop_bg "$T_DESK_BG" desktop_fg "$T_DESK_FG" desktop_shadow "$T_DESK_SHADOW" show_wm_menu 0
	if [[ -n $A_WALL ]]; then _ini_set "$f" desktop wallpaper_mode crop wallpaper "$A_WALL"; fi
	_ini_set "$f" ui always_show_tabs 0 max_tab_chars 32 win_width 640 win_height 480 splitter_pos 150 \
		view_mode icon show_hidden 0 sort "name;ascending;" columns "name;size;mtime;" \
		toolbar "newtab;navigation;home;" show_statusbar 1 pathbar_mode_buttons 0
	# Raspberry Pi OS leaves removable media to the panel's eject plugin
	_ini_set "$f" volume mount_on_startup 0 mount_removable 0 autorun 0
	_ini_set "$f" config bm_open_method 0
	if (( O_PI_FM )); then
		# Raspberry Pi's file manager keeps in this file what Debian's keeps in
		# libfm.conf: its own menus, side pane and icon sizes
		_ini_set "$f" config cutdown_menus 1 real_expanders 1 single_click 0 use_trash 1 confirm_del 1 \
			thumbnail_local 1 thumbnail_max 2048 terminal "x-terminal-emulator %s"
		_ini_set "$f" ui big_icon_size 48 small_icon_size 24 thumbnail_size 80 pane_icon_size 24 show_thumbnail 1
		_ini_set "$f" places places_home 1 places_desktop 0 places_root 1 places_computer 0 places_trash 0 \
			places_applications 0 places_network 0 places_unmounted 1 places_volmounts 1
	else
		_ini_set "$f" ui side_pane_mode places
	fi
}

# Make Raspberry Pi's file manager the one the desktop uses: the default for
# folders and the Desktop Preferences dialog, and the only File Manager entry
# in the application menu (Debian's is hidden for this user, not removed).
_pi_fm_entries() {
	local d=$HOME/.local/share/applications f=/usr/share/applications/pcmanfm-desktop-pref.desktop
	if (( O_DRY_RUN )); then log "   [dry-run] default file manager: pcmanfm-pi"; return 0; fi
	# Its menu entry, named and filed as Raspberry Pi OS names and files it
	# (rpd-common's raspi-ui-overrides): "File Manager", in Accessories
	if [[ -f /usr/share/applications/pcmanfm-pi.desktop && ! -e $d/pcmanfm-pi.desktop ]] && _once fm:launcher; then
		_track_file "$d/pcmanfm-pi.desktop"
		sed -E 's/^Name=.*/Name=File Manager/; s/^Categories=.*/Categories=FileTools;FileManager;Utility;Core;GTK;/' \
			/usr/share/applications/pcmanfm-pi.desktop | _write "$d/pcmanfm-pi.desktop"
	fi
	if [[ ! -e $d/pcmanfm.desktop ]] && _once fm:menu-entry; then
		_track_file "$d/pcmanfm.desktop"
		printf '[Desktop Entry]\nType=Application\nName=PCMan File Manager\nExec=pcmanfm %%U\nNoDisplay=true\n' \
			| _write "$d/pcmanfm.desktop"
	fi
	if [[ -f $f && ! -e $d/${f##*/} ]] && _once fm:desktop-pref; then
		_track_file "$d/${f##*/}"
		sed -E 's/^(Exec|TryExec)=pcmanfm/\1=pcmanfm-pi/' "$f" | _write "$d/${f##*/}"
	fi
	_ini_set "$HOME/.config/mimeapps.list" 'Default Applications' inode/directory pcmanfm-pi.desktop
}

# Write the Raspberry Pi OS application menu for LXDE: its category order,
# names and icons, with separators before Help and Preferences, and the Run
# and Shutdown dialogs at the end. Category
# names that match Debian's (lxmenu-data) keep Debian's translations.
_lxde_menu_write() {
	local ddir=$HOME/.local/share/desktop-directories menu=$HOME/.config/menus/lxde-applications.menu
	local entry id name icon cat deb f
	local -a cats=(
		"development|Programming|applications-development|Development|lxde-development"
		"education|Education|applications-engineering|Education|lxde-education"
		"science|Science|applications-science|Science|lxde-science"
		"office|Office|applications-office|Office|lxde-office"
		"network|Internet|applications-internet|Network|lxde-network"
		"audio-video|Sound & Video|applications-multimedia|AudioVideo|lxde-audio-video"
		"graphics|Graphics|applications-graphics|Graphics|lxde-graphics"
		"game|Games|applications-games|Game|lxde-game"
		"other|Other|applications-other||lxde-other"
		"system-tools|System Tools|applications-system|System|lxde-system"
		"utility|Accessories|applications-accessories|Utility|lxde-utility"
		"help|Help|gnome-help|Help|"
		"settings|Preferences|preferences-desktop|Settings|lxde-settings"
	)
	if (( O_DRY_RUN )); then log "   [dry-run] $menu: Raspberry Pi OS menu layout"; return 0; fi
	_track_file "$menu"
	{
		printf '<?xml version="1.0"?>\n<!DOCTYPE Menu PUBLIC "-//freedesktop//DTD Menu 1.0//EN"\n'
		printf ' "http://www.freedesktop.org/standards/menu-spec/menu-1.0.dtd">\n'
		printf '<!-- %s: the Raspberry Pi OS application menu -->\n<Menu>\n  <Name>Applications</Name>\n' "$APP_NAME"
		printf '  <Directory>lxde-menu-applications.directory</Directory>\n  <DefaultAppDirs/>\n  <DefaultDirectoryDirs/>\n  <DefaultMergeDirs/>\n'
		for entry in "${cats[@]}"; do
			IFS='|' read -r id name icon cat deb <<<"$entry"
			printf '  <Menu>\n    <Name>%s</Name>\n    <Directory>%s-%s.directory</Directory>\n' "$id" "$APP_NAME" "$id"
			if [[ $id == utility ]]; then   # Run is at the end of the menu instead
				printf '    <Include>\n      <Category>%s</Category>\n    </Include>\n' "$cat"
				printf '    <Exclude>\n      <Filename>gui-runcmd.desktop</Filename>\n    </Exclude>\n  </Menu>\n'
			elif [[ -n $cat ]]; then
				printf '    <Include>\n      <Category>%s</Category>\n    </Include>\n  </Menu>\n' "$cat"
			else
				printf '    <OnlyUnallocated/>\n    <Include>\n      <All/>\n    </Include>\n  </Menu>\n'
			fi
		done
		printf '  <Include>\n    <Category>Applications</Category>\n    <Filename>gui-runcmd.desktop</Filename>\n  </Include>\n  <Layout>\n'
		for id in development education science office network audio-video graphics game other system-tools utility; do
			printf '    <Menuname>%s</Menuname>\n' "$id"
		done
		printf '    <Merge type="menus"/>\n    <Separator/>\n    <Menuname>help</Menuname>\n    <Separator/>\n'
		printf '    <Menuname>settings</Menuname>\n    <Separator/>\n    <Filename>gui-runcmd.desktop</Filename>\n'
		printf '    <Filename>pishutdown.desktop</Filename>\n    <Merge type="files"/>\n  </Layout>\n</Menu>\n'
	} | _write "$menu"
	for entry in "${cats[@]}"; do
		IFS='|' read -r id name icon cat deb <<<"$entry"
		f=$ddir/$APP_NAME-$id.directory
		_track_file "$f"
		{
			printf '[Desktop Entry]\nType=Directory\nName=%s\nIcon=%s\n' "$name" "$icon"
			deb=/usr/share/desktop-directories/$deb.directory
			if [[ -f $deb ]] && [[ $(sed -n 's/^Name=//p' "$deb") == "$name" ]]; then grep '^Name\[' "$deb" || true; fi
		} | _write "$f"
	done
}

# Print the Debian logo for the menu button, from packages every Debian desktop
# has: desktop-base (emblem-debian), else debconf (debian-logo).
_logo_path() {
	local f
	for f in /usr/share/icons/desktop-base/64x64/emblems/emblem-debian.png \
		/usr/share/icons/hicolor/64x64/emblems/emblem-debian.png \
		/usr/share/icons/desktop-base/48x48/emblems/emblem-debian.png \
		/usr/share/icons/hicolor/48x48/emblems/emblem-debian.png \
		/usr/share/pixmaps/debian-logo.png; do
		if [[ -f $f ]]; then printf '%s\n' "$f"; return 0; fi
	done
	return 1
}

# Print a large Debian logo for the login screen's default user picture.
_greeter_logo() {
	local f
	for f in /usr/share/icons/desktop-base/128x128/emblems/emblem-debian.png \
		/usr/share/icons/hicolor/128x128/emblems/emblem-debian.png \
		/usr/share/icons/desktop-base/scalable/emblems/emblem-debian.svg; do
		if [[ -f $f ]]; then printf '%s\n' "$f"; return 0; fi
	done
	_logo_path
}

# Offer only the adapted icon sets in theme choosers (LXAppearance, Xfce
# Appearance): a copy of the official index.theme with "Hidden=true" in the
# user's icon directory keeps the official sets working and inheritable, but
# out of the lists, where picking one would lose the Debian logo, the extra
# cursor names and the notification icons Debian's applets use.
_hide_official_icons() {
	local b f o inh
	for b in PiXflat PiXtrix PiX; do
		[[ -f /usr/share/icons/$b-Debian/index.theme && -f /usr/share/icons/$b/index.theme ]] || continue
		f=$HOME/.local/share/icons/$b/index.theme
		if (( O_DRY_RUN )); then log "   [dry-run] $f: hide $b in theme choosers"; continue; fi
		_track_file "$f"
		# The copy also inherits the other Raspberry Pi sets before GNOME, so
		# even the official set shows Raspberry Pi icons for names it lacks
		# (nm-applet's network icons, for example) when something selects it.
		# The adapted set comes first, so the official set answers to the same
		# names (the Debian logo, the cursor names and the icon names Debian's
		# applets and file managers use), then the other Raspberry Pi sets.
		inh="$b-Debian,"
		for o in $(_icon_fallbacks "$b"); do
			[[ -d /usr/share/icons/$o ]] && inh+="$o,"
		done
		{ I=$inh awk '/^Hidden=/ { next }
			/^Inherits[[:space:]]*=/ { sub(/^Inherits[[:space:]]*=[[:space:]]*/, ""); print "Inherits=" ENVIRON["I"] $0; found = 1; next }
			{ print }
			END { if (!found) print "Inherits=" ENVIRON["I"] "gnome,Adwaita,hicolor" }' "/usr/share/icons/$b/index.theme"
		  printf 'Hidden=true\n'; } | _write "$f"
	done
}

# Map Monospace to Liberation Mono, as Raspberry Pi OS does.
apply_mono_font() {
	grep -qiF "Liberation Mono" <<<"$(fc-list : family 2>/dev/null)" || return 0
	local f=$HOME/.config/fontconfig/conf.d/31-$APP_NAME-mono.conf
	if (( O_DRY_RUN )); then log "   [dry-run] $f: Monospace -> Liberation Mono"; return 0; fi
	_track_file "$f"
	cat <<'EOF_FC' | _write "$f"
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<!-- pixflat-theme: Monospace is Liberation Mono, as in Raspberry Pi OS -->
<fontconfig>
	<match target="pattern">
		<test name="family"><string>Monospace</string></test>
		<edit name="family" mode="assign" binding="same"><string>Liberation Mono</string></edit>
	</match>
</fontconfig>
EOF_FC
}

# Print a literal colour that the theme's GTK 3 stylesheets define.
_theme_color() {
	local f v
	for f in gtk-colours.css gtk-contained.css gtk.css; do
		f=${SYS_ROOT:-}/usr/share/themes/$T_GTK/gtk-3.0/$f
		[[ -f $f ]] || continue
		v=$(sed -n "s/^[[:space:]]*@define-color[[:space:]]\{1,\}$1[[:space:]]\{1,\}\([^;]*\);.*/\1/p" "$f" | head -n1)
		if [[ $v =~ ^(#[0-9A-Fa-f]{3,8}|rgba?\([0-9.,[:space:]%]+\)|[a-z]+)$ ]]; then printf '%s\n' "$v"; return 0; fi
	done
	return 1
}

# GTK 4 colour layer. No official theme ships gtk-4.0, and libadwaita ignores
# themes, but both read named colours from ~/.config/gtk-4.0/gtk.css. The
# theme's GTK 3 palette is mapped onto them, as @define-color names and, for
# GTK 4.16 and newer (libadwaita 1.6+), as CSS variables.
apply_gtk4_colors() {
	local -a map=(
		accent_color:theme_selected_bg_color accent_bg_color:theme_selected_bg_color
		accent_fg_color:theme_selected_fg_color
		window_bg_color:theme_bg_color       window_fg_color:theme_fg_color
		view_bg_color:theme_base_color       view_fg_color:theme_text_color
		headerbar_bg_color:theme_bg_color    headerbar_fg_color:theme_fg_color
		sidebar_bg_color:theme_bg_color      sidebar_fg_color:theme_fg_color
		card_bg_color:theme_base_color       card_fg_color:theme_text_color
		dialog_bg_color:theme_bg_color       dialog_fg_color:theme_fg_color
		popover_bg_color:theme_base_color    popover_fg_color:theme_text_color
		theme_bg_color:theme_bg_color        theme_fg_color:theme_fg_color
		theme_base_color:theme_base_color    theme_text_color:theme_text_color
		theme_selected_bg_color:theme_selected_bg_color
		theme_selected_fg_color:theme_selected_fg_color
	)
	local m c defs="" vars="" gtk4
	for m in "${map[@]}"; do
		c=$(_theme_color "${m#*:}") || continue
		defs+="@define-color ${m%%:*} $c;"$'\n'
		[[ ${m%%:*} == theme_* ]] || vars+="  --${m%%:*}: $c;"$'\n'
	done
	vars=${vars//_/-}
	if [[ -z $defs ]]; then debug "no GTK 3 palette found in $T_GTK"; return 0; fi
	local css="/* Raspberry Pi OS $T_GTK colours for GTK 4 and libadwaita applications,
   generated from the official theme's GTK 3 palette */
${defs%$'\n'}"
	gtk4=$(_installed_version libgtk-4-1)
	if [[ -n $gtk4 ]] && dpkg --compare-versions "$gtk4" ge 4.16; then
		css+=$'\n'":root {"$'\n'"${vars%$'\n'}"$'\n'"}"
	fi
	_block_set "$HOME/.config/gtk-4.0/gtk.css" "$APP_NAME" "$css"
	ok "GTK 4/libadwaita colours set from the $T_GTK palette"
}

# Succeed if a GSettings key exists.
_gs_ok() { gsettings writable "$1" "$2" >/dev/null 2>&1; }
# Set a GSettings key, recording its old value. Usage: gs_set SCHEMA KEY VALUE
gs_set() {
	command -v gsettings >/dev/null || return 0
	_gs_ok "$1" "$2" || { debug "gsettings: no $1 $2"; return 0; }
	local old
	old=$(gsettings get "$1" "$2" 2>/dev/null) || return 0
	_track_cmd "gs:$1:$2" "$(_q gsettings set "$1" "$2" "$old")"
	run gsettings set "$1" "$2" "$3" || warn "could not set $1 $2"
}
# Set a GSettings string key. Usage: gs_str SCHEMA KEY STRING
gs_str() { gs_set "$1" "$2" "'${3//\'/\\\'}'"; }

# Set an Xfconf property, recording its old value.
# Usage: xf_set CHANNEL PROPERTY TYPE VALUE
xf_set() {
	local old
	if old=$(xfconf-query -c "$1" -p "$2" 2>/dev/null); then
		_track_cmd "xf:$1:$2" "$(_q xfconf-query -c "$1" -p "$2" -s "$old")"
		run xfconf-query -c "$1" -p "$2" -s "$4" || warn "could not set $1 $2"
	else
		_track_cmd "xf:$1:$2" "$(_q xfconf-query -c "$1" -p "$2" -r)"
		run xfconf-query -c "$1" -p "$2" -n -t "$3" -s "$4" || warn "could not set $1 $2"
	fi
}

# Set a KDE configuration key, recording its old value.
# Usage: kde_set FILE GROUP KEY VALUE
kde_set() {
	local w r old
	w=$(command -v kwriteconfig6 || command -v kwriteconfig5 || true)
	r=$(command -v kreadconfig6 || command -v kreadconfig5 || true)
	[[ -n $w && -n $r ]] || { warn "kwriteconfig not found; skipping KDE $3"; return 0; }
	old=$("$r" --file "$1" --group "$2" --key "$3" 2>/dev/null || true)
	if [[ -n $old ]]; then
		_track_cmd "kde:$1:$2:$3" "$(_q "$w" --file "$1" --group "$2" --key "$3" "$old")"
	else
		_track_cmd "kde:$1:$2:$3" "$(_q "$w" --file "$1" --group "$2" --key "$3" --delete)"
	fi
	run "$w" --file "$1" --group "$2" --key "$3" "$4"
}

# Succeed if the user runs a process of that name.
_running() { pgrep -u "$(id -u)" -x "$1" >/dev/null 2>&1; }

# Set the theme, icons, cursor and fonts in a GNOME-style interface schema.
_gs_interface() {
	local s=$1
	gs_str "$s" gtk-theme "$T_GTK"
	gs_str "$s" icon-theme "$A_ICONS"
	gs_str "$s" cursor-theme "$A_CURSOR"
	gs_set "$s" cursor-size "$T_CURSOR_SIZE"
	gs_str "$s" font-antialiasing rgba
	gs_str "$s" font-hinting full
	gs_str "$s" font-rgba-order rgb
	if [[ -n $T_FONT ]]; then
		gs_str "$s" font-name "$T_FONT"
		gs_str "$s" document-font-name "$T_FONT"
	fi
}

# Write the GTK 2, 3 and 4 settings files and the default X11 cursor, with the
# Raspberry Pi OS toolbar, icon size and font rendering settings.
apply_gtk_files() {
	local f=$HOME/.config/gtk-3.0/settings.ini
	_ini_set "$f" Settings gtk-theme-name "$T_GTK" gtk-icon-theme-name "$A_ICONS" \
		gtk-cursor-theme-name "$A_CURSOR" gtk-cursor-theme-size "$T_CURSOR_SIZE"
	if [[ -n $T_FONT ]]; then _ini_set "$f" Settings gtk-font-name "$T_FONT"; fi
	if [[ -n $A_SOUND ]]; then
		_ini_set "$f" Settings gtk-sound-theme-name "$A_SOUND" gtk-enable-event-sounds 1 gtk-enable-input-feedback-sounds 1
	fi
	_ini_set "$f" Settings gtk-toolbar-style GTK_TOOLBAR_BOTH_HORIZ gtk-toolbar-icon-size GTK_ICON_SIZE_LARGE_TOOLBAR \
		gtk-icon-sizes gtk-large-toolbar=24,24 gtk-button-images 0 gtk-menu-images 0 \
		gtk-xft-antialias 1 gtk-xft-hinting 1 gtk-xft-hintstyle hintfull gtk-xft-rgba rgb
	f=$HOME/.config/gtk-4.0/settings.ini
	_ini_set "$f" Settings gtk-icon-theme-name "$A_ICONS" gtk-cursor-theme-name "$A_CURSOR" \
		gtk-cursor-theme-size "$T_CURSOR_SIZE" \
		gtk-xft-antialias 1 gtk-xft-hinting 1 gtk-xft-hintstyle hintfull gtk-xft-rgba rgb
	if [[ -n $T_FONT ]]; then _ini_set "$f" Settings gtk-font-name "$T_FONT"; fi
	f=$HOME/.gtkrc-2.0
	_kv_set "$f" gtk-theme-name "$T_GTK" '"'
	_kv_set "$f" gtk-icon-theme-name "$A_ICONS" '"'
	_kv_set "$f" gtk-cursor-theme-name "$A_CURSOR" '"'
	_kv_set "$f" gtk-cursor-theme-size "$T_CURSOR_SIZE"
	if [[ -n $T_FONT ]]; then _kv_set "$f" gtk-font-name "$T_FONT" '"'; fi
	_kv_set "$f" gtk-toolbar-style GTK_TOOLBAR_BOTH_HORIZ
	_kv_set "$f" gtk-toolbar-icon-size GTK_ICON_SIZE_LARGE_TOOLBAR
	_kv_set "$f" gtk-icon-sizes "gtk-large-toolbar=24,24" '"'
	_kv_set "$f" gtk-button-images 0
	_kv_set "$f" gtk-menu-images 0
	_kv_set "$f" gtk-xft-antialias 1
	_kv_set "$f" gtk-xft-hinting 1
	_kv_set "$f" gtk-xft-hintstyle hintfull '"'
	_kv_set "$f" gtk-xft-rgba rgb '"'
	# Default X11 cursor for applications that do not use XSETTINGS
	_ini_set "$HOME/.icons/default/index.theme" "Icon Theme" Inherits "$A_CURSOR"
	ok "GTK 2/3/4 configuration files updated"
}

# LXDE, as in Raspberry Pi OS: session and GTK settings, Openbox, desktop,
# file manager and icon sizes, panel and application menu.
apply_de_lxde() {
	local sess=LXDE rc f i
	[[ $S_DESKTOP_SESSION == LXDE* && $S_DESKTOP_SESSION =~ ^[A-Za-z0-9._-]+$ ]] && sess=$S_DESKTOP_SESSION
	f=$HOME/.config/lxsession/$sess/desktop.conf
	_seed "$f" "/etc/xdg/lxsession/$sess/desktop.conf" /etc/xdg/lxsession/LXDE/desktop.conf || true
	# The [GTK] section of the Raspberry Pi OS desktop.conf
	_ini_set "$f" GTK sNet/ThemeName "$T_GTK" sNet/IconThemeName "$A_ICONS" \
		sGtk/CursorThemeName "$A_CURSOR" iGtk/CursorThemeSize "$T_CURSOR_SIZE" sGtk/ColorScheme "$T_COLOR_SCHEME" \
		iGtk/ToolbarStyle 3 iGtk/ToolbarIconSize 3 sGtk/IconSizes gtk-large-toolbar=24,24 \
		iGtk/ButtonImages 0 iGtk/MenuImages 0 iGtk/AutoMnemonics 1 iGtk/EnableMnemonics 1 \
		iXft/Antialias 1 iXft/Hinting 1 sXft/HintStyle hintfull sXft/RGBA rgb
	if [[ -n $T_FONT ]]; then _ini_set "$f" GTK sGtk/FontName "$T_FONT"; fi
	if [[ -n $A_SOUND ]]; then
		_ini_set "$f" GTK sNet/SoundThemeName "$A_SOUND" iNet/EnableEventSounds 1 iNet/EnableInputFeedbackSounds 1
	fi

	rc=$HOME/.config/openbox/${sess,,}-rc.xml
	if _seed "$rc" "/etc/xdg/openbox/$sess/rc.xml" /etc/xdg/openbox/LXDE/rc.xml /etc/xdg/openbox/rc.xml; then
		_openbox_rc "$rc"
	else
		warn "no Openbox configuration found for $sess; window theme not set"
	fi

	# Desktop preferences (PCManFM), as in Raspberry Pi OS: the same wallpaper,
	# colours and font on every monitor; trash and drive icons on the first one.
	local d=$HOME/.config/pcmanfm/$sess n
	local items=("$d/desktop-items-0.conf" "$d/desktop-items-1.conf")
	for i in "$d"/desktop-items-*.conf; do
		if [[ -e $i && " ${items[*]} " != *" $i "* ]]; then items+=("$i"); fi
	done
	for i in "${items[@]}"; do
		n=${i##*-}; n=${n%.conf}
		_seed "$i" "/etc/xdg/pcmanfm/$sess/${i##*/}" "/etc/xdg/pcmanfm/LXDE/${i##*/}" || true
		_ini_set "$i" '*' desktop_bg "$T_DESK_BG" desktop_fg "$T_DESK_FG" desktop_shadow "$T_DESK_SHADOW" \
			show_wm_menu 0 sort "mtime;ascending;" show_documents 0 \
			show_trash $(( n == 0 )) show_mounts $(( n == 0 ))
		if [[ -n $T_FONT ]]; then _ini_set "$i" '*' desktop_font "$T_FONT"; fi
		if [[ -n $A_WALL ]]; then _ini_set "$i" '*' wallpaper_mode crop wallpaper_common 1 wallpaper "$A_WALL"; fi
	done
	# File manager. Debian's reads the session profile; Raspberry Pi's fork
	# takes its window settings from the 'default' profile whatever profile it
	# runs with, so both files are written.
	_fm_conf "$HOME/.config/pcmanfm/$sess/pcmanfm.conf" "$sess"
	if (( O_PI_FM )); then _fm_conf "$HOME/.config/pcmanfm/default/pcmanfm.conf" "$sess"; fi
	# Icon sizes for Debian's file manager, which keeps them in libfm.conf
	f=$HOME/.config/libfm/libfm.conf
	_seed "$f" /etc/xdg/libfm/libfm.conf || true
	_ini_set "$f" config cutdown_menus 1 real_expanders 1 single_click 0 use_trash 1 confirm_del 1 \
		thumbnail_local 1 thumbnail_max 2048
	_ini_set "$f" ui big_icon_size 48 small_icon_size 24 thumbnail_size 80 pane_icon_size 24 show_thumbnail 1
	_ini_set "$f" places places_home 1 places_desktop 0 places_root 1 places_computer 0 places_trash 0 \
		places_applications 0 places_network 0 places_unmounted 1 places_volmounts 1

	# Panel and menu: set up on the first installation only, so plugins the
	# user adds or removes later are kept. Extra tray applets are hidden once each.
	local panel=$HOME/.config/lxpanel/$sess/panels/panel
	(( O_PI_PANEL )) && panel=$HOME/.config/lxpanel-pi/panels/panel
	# The panel is written on the first installation, and afterwards while it is
	# still the one written here (the marker is gone once the user edits it in
	# the panel preferences, which rewrite the file).
	if (( O_PANEL )) && { _once lxde-panel-2 || grep -qF "# $APP_NAME:" "$panel" 2>/dev/null; }; then
		if (( O_PI_PANEL )); then   # Debian 13 and later: Raspberry Pi's own panel
			_pi_panel_write "$panel"
			_lxsession_panel "$sess" lxpanel-pi
		else
			_lxpanel_write "$panel"
		fi
		ok "Panel layout written ($(basename "$panel"): Raspberry Pi OS)"
		_lxde_menu_write
	elif (( O_PANEL )) && grep -qF "<!-- $APP_NAME:" "$HOME/.config/menus/lxde-applications.menu" 2>/dev/null; then
		_lxde_menu_write   # still the installer's menu (not edited by a menu editor): keep it current
		ok "Application menu updated (Raspberry Pi OS categories, Run and Shutdown)"
	fi
	if (( O_PANEL )); then _help_menu_entry; fi
	if (( O_PANEL && O_PI_PANEL )) && [[ -f $rc ]]; then _pi_panel_keys "$rc"; fi
	if (( O_PANEL && O_PI_PANEL )); then _pi_panel_css; ok "Raspberry Pi panel style for $T_GTK applied (tray icons, buttons)"; fi
	if (( O_PANEL )); then _hide_extra_applets; fi
	# Raspberry Pi's file manager draws the desktop and opens the folders
	local fm=pcmanfm
	if (( O_PI_FM )); then
		fm=pcmanfm-pi
		_lxsession_desktop "$sess" "$fm"
		_pi_fm_entries
		ok "Raspberry Pi file manager set up (desktop, folders and Desktop Preferences)"
	fi
	if [[ -n ${DISPLAY:-} ]]; then
		if _running openbox; then run openbox --reconfigure || true; fi
		# Restart the desktop: it keeps its settings in memory, so the new font,
		# colours and wallpaper (and the Desktop Preferences dialog) would
		# otherwise only follow at the next login
		if _running pcmanfm || _running pcmanfm-pi; then
			run pcmanfm --desktop-off 2>/dev/null || true
			if (( O_PI_FM )); then run pcmanfm-pi --desktop-off 2>/dev/null || true; fi
			run setsid -f "$fm" --desktop --profile "$sess" || true
			ok "Desktop restarted with the new settings"
		fi
		if (( O_PANEL && ! O_PI_PANEL )) && _running lxpanel; then run lxpanelctl restart || true; fi
		if (( O_PANEL && O_PI_PANEL )) && _running lxpanel-pi; then
			run lxpanelctl-pi restart || true
			ok "Raspberry Pi panel restarted"
		fi
	fi
	ok "LXDE configured (session '$sess')"
	if (( O_PI_PANEL && O_PANEL )); then
		A_NOTES+=("LXDE: log out and back in to load the new theme, font, cursor and the Raspberry Pi panel.")
	else
		A_NOTES+=("LXDE: log out and back in to load the new theme, font and cursor.")
	fi
}

# LXQt: icons, cursor, Openbox and PCManFM-Qt wallpaper.
apply_de_lxqt() {
	_ini_set "$HOME/.config/lxqt/lxqt.conf" General icon_theme "$A_ICONS"
	_ini_set "$HOME/.config/lxqt/session.conf" Mouse cursor_theme "$A_CURSOR" cursor_size "$T_CURSOR_SIZE"
	local rc=$HOME/.config/openbox/lxqt-rc.xml
	if _seed "$rc" /etc/xdg/openbox/lxqt-rc.xml /usr/share/lxqt/openbox/rc.xml; then
		_openbox_rc "$rc" 1
		if [[ -n ${DISPLAY:-} ]] && _running openbox; then run openbox --reconfigure || true; fi
	fi
	if [[ -n $A_WALL ]]; then
		_ini_set "$HOME/.config/pcmanfm-qt/lxqt/settings.conf" Desktop Wallpaper "$A_WALL" WallpaperMode zoom
		if _running pcmanfm-qt; then run pcmanfm-qt --set-wallpaper "$A_WALL" --wallpaper-mode zoom || true; fi
	fi
	ok "LXQt configured (icons, cursor, Openbox, wallpaper; GTK applications use the GTK theme)"
	A_NOTES+=("LXQt: Qt widgets keep the LXQt style; log out and back in to refresh the cursor.")
}

# Xfce: xsettings, Xfwm4, wallpaper, panel and panel CSS.
apply_de_xfce() {
	command -v xfconf-query >/dev/null || { warn "xfconf-query not found; skipping Xfce"; return 0; }
	xfconf-query -c xsettings -l >/dev/null 2>&1 || { warn "cannot reach the Xfce settings daemon; skipping Xfce (rerun with --apply-only inside Xfce)"; return 0; }
	xf_set xsettings /Net/ThemeName string "$T_GTK"
	xf_set xsettings /Net/IconThemeName string "$A_ICONS"
	xf_set xsettings /Gtk/CursorThemeName string "$A_CURSOR"
	xf_set xsettings /Gtk/CursorThemeSize int "$T_CURSOR_SIZE"
	xf_set xsettings /Gtk/ToolbarStyle string both-horiz
	xf_set xsettings /Gtk/IconSizes string gtk-large-toolbar=24,24
	xf_set xsettings /Gtk/ButtonImages bool false
	xf_set xsettings /Gtk/MenuImages bool false
	xf_set xsettings /Xft/Antialias int 1
	xf_set xsettings /Xft/Hinting int 1
	xf_set xsettings /Xft/HintStyle string hintfull
	xf_set xsettings /Xft/RGBA string rgb
	if [[ -n $T_FONT ]]; then xf_set xsettings /Gtk/FontName string "$T_FONT"; fi
	if [[ -n $A_SOUND ]]; then
		xf_set xsettings /Net/SoundThemeName string "$A_SOUND"
		xf_set xsettings /Net/EnableEventSounds bool true
		xf_set xsettings /Net/EnableInputFeedbackSounds bool true
	fi
	if [[ -f /usr/share/themes/$T_GTK/xfwm4/themerc ]]; then
		xf_set xfwm4 /general/theme string "$T_GTK"
	else
		warn "no Xfwm4 theme for $T_GTK found; window borders unchanged"
	fi
	if [[ -n $T_FONT ]]; then xf_set xfwm4 /general/title_font string "$T_FONT"; fi
	xf_set xfwm4 /general/title_alignment string center
	xf_set xfwm4 /general/button_layout string "|HMC"   # Raspberry Pi OS: no window-menu button
	if [[ -n $A_WALL ]]; then
		local props p n=0
		props=$(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep -E '^/backdrop/.*/last-image$' || true)
		for p in $props; do
			xf_set xfce4-desktop "$p" string "$A_WALL"
			xf_set xfce4-desktop "${p%/last-image}/image-style" int 5
			n=$(( n + 1 ))
		done
		(( n )) || warn "no Xfce desktop backdrop found; open Desktop settings once and rerun to set the wallpaper"
	fi
	local css='/* Full-colour icons on the Xfce panel, like the Raspberry Pi OS panel */
.xfce4-panel image { -gtk-icon-style: regular; }'
	if (( ! T_DARK )); then
		css+='
/* PiXflat-style desktop icon labels */
XfdesktopIconView.view .label, .xfdesktop-icon-view.view .label { background: #ededed; color: black; text-shadow: none; }
XfdesktopIconView.view .label:active, .xfdesktop-icon-view.view .label:active { background: #87919b; color: white; }'
	fi
	_block_set "$HOME/.config/gtk-3.0/gtk.css" "$APP_NAME" "$css"
	if (( O_PANEL )) && xfconf-query -c xfce4-panel -p /panels/panel-1/size >/dev/null 2>&1 && _once xfce-panel; then
		xf_set xfce4-panel /panels/panel-1/position string "p=6;x=0;y=0"   # top, like Raspberry Pi OS
		xf_set xfce4-panel /panels/panel-1/size uint 36
		local plug id
		while read -r plug id; do
			case $id in applicationsmenu|whiskermenu)
				[[ -n $A_LOGO ]] && xf_set xfce4-panel "$plug/button-icon" string "$A_LOGO" ;;
			esac
		done < <(xfconf-query -c xfce4-panel -p /plugins -l -v 2>/dev/null | grep -E '^/plugins/plugin-[0-9]+ ' || true)
	fi
	ok "Xfce configured"
	A_NOTES+=("Xfce: restart the panel (xfce4-panel -r) or log in again to pick up the panel CSS.")
}

# GNOME: interface, window buttons and wallpaper.
apply_de_gnome() {
	_gs_interface org.gnome.desktop.interface
	if (( T_DARK )); then gs_str org.gnome.desktop.interface color-scheme prefer-dark
	else gs_str org.gnome.desktop.interface color-scheme default; fi
	gs_str org.gnome.desktop.wm.preferences button-layout "appmenu:minimize,maximize,close"
	if [[ -n $A_SOUND ]]; then
		gs_str org.gnome.desktop.sound theme-name "$A_SOUND"
		gs_set org.gnome.desktop.sound event-sounds true
		gs_set org.gnome.desktop.sound input-feedback-sounds true
	fi
	if [[ -n $T_FONT ]]; then gs_str org.gnome.desktop.wm.preferences titlebar-font "$T_FONT"; fi
	if [[ -n $A_WALL ]]; then
		gs_str org.gnome.desktop.background picture-uri "file://$A_WALL"
		gs_str org.gnome.desktop.background picture-uri-dark "file://$A_WALL"
		gs_str org.gnome.desktop.background picture-options zoom
		gs_str org.gnome.desktop.screensaver picture-uri "file://$A_WALL"
	fi
	ok "GNOME settings applied"
	A_NOTES+=("GNOME: GTK 3 applications and window titlebars use $T_GTK; GNOME Shell and GTK 4/libadwaita applications keep the Adwaita style.")
}

# Budgie uses the GNOME settings.
apply_de_budgie() {
	apply_de_gnome
	A_NOTES+=("Budgie: the panel keeps its own theme.")
}

# Cinnamon: interface, window buttons and wallpaper.
apply_de_cinnamon() {
	_gs_interface org.cinnamon.desktop.interface
	gs_str org.cinnamon.desktop.wm.preferences button-layout ":minimize,maximize,close"
	if [[ -n $T_FONT ]]; then gs_str org.cinnamon.desktop.wm.preferences titlebar-font "$T_FONT"; fi
	if [[ -n $A_WALL ]]; then
		gs_str org.cinnamon.desktop.background picture-uri "file://$A_WALL"
		gs_str org.cinnamon.desktop.background picture-options zoom
	fi
	ok "Cinnamon settings applied"
	A_NOTES+=("Cinnamon: the panel/desktop theme and window borders keep the Cinnamon style.")
}

# MATE: interface, cursor and wallpaper.
apply_de_mate() {
	gs_str org.mate.interface gtk-theme "$T_GTK"
	gs_str org.mate.interface icon-theme "$A_ICONS"
	if [[ -n $T_FONT ]]; then
		gs_str org.mate.interface font-name "$T_FONT"
		gs_str org.mate.Marco.general titlebar-font "$T_FONT"
	fi
	if [[ -n $A_SOUND ]]; then
		gs_str org.mate.sound theme-name "$A_SOUND"
		gs_set org.mate.sound event-sounds true
		gs_set org.mate.sound input-feedback-sounds true
	fi
	gs_str org.mate.font-rendering antialiasing rgba
	gs_str org.mate.font-rendering hinting full
	gs_str org.mate.font-rendering rgba-order rgb
	gs_str org.mate.peripherals-mouse cursor-theme "$A_CURSOR"
	gs_set org.mate.peripherals-mouse cursor-size "$T_CURSOR_SIZE"
	if [[ -n $A_WALL ]]; then
		gs_str org.mate.background picture-filename "$A_WALL"
		gs_str org.mate.background picture-options zoom
	fi
	ok "MATE settings applied"
	A_NOTES+=("MATE: Marco window borders keep their theme (Raspberry Pi OS ships no Metacity theme).")
}

# Openbox on its own: window theme and fonts.
apply_de_openbox() {
	local rc=$HOME/.config/openbox/rc.xml
	if _seed "$rc" /etc/xdg/openbox/rc.xml; then
		_openbox_rc "$rc"
		if [[ -n ${DISPLAY:-} ]] && _running openbox; then run openbox --reconfigure || true; fi
		ok "Openbox configured"
	else
		warn "no Openbox rc.xml found; skipping Openbox"
	fi
}

# labwc: window theme, fonts, cursor and the GTK settings used on Wayland.
apply_de_labwc() {
	local rc=$HOME/.config/labwc/rc.xml
	if [[ ! -e $rc ]]; then
		if (( O_DRY_RUN )); then log "   [dry-run] create $rc"
		else
			_track_file "$rc"
			printf '<?xml version="1.0"?>\n<labwc_config>\n</labwc_config>\n' | _write "$rc"
		fi
	fi
	_labwc_rc "$rc"
	_kv_set "$HOME/.config/labwc/environment" XCURSOR_THEME "$A_CURSOR"
	_kv_set "$HOME/.config/labwc/environment" XCURSOR_SIZE "$T_CURSOR_SIZE"
	_gs_interface org.gnome.desktop.interface   # GTK reads these on Wayland
	if [[ -n ${LABWC_PID:-} ]]; then run labwc --reconfigure || true; fi
	ok "labwc configured"
	A_NOTES+=("labwc: set the wallpaper in your background tool (e.g. swaybg -m fill -i ${A_WALL:-<file>}).")
}

# KDE Plasma: icons and cursor.
apply_de_kde() {
	kde_set kdeglobals Icons Theme "$A_ICONS"
	kde_set kcminputrc Mouse cursorTheme "$A_CURSOR"
	kde_set kcminputrc Mouse cursorSize "$T_CURSOR_SIZE"
	ok "KDE Plasma: icons and cursor set"
	A_NOTES+=("KDE Plasma: only icons, cursor and GTK applications are themed; Plasma and Qt keep Breeze.")
}

# --qt: let Qt applications use the GTK theme after the next login.
apply_qt_env() {
	if [[ " ${DESKTOPS[*]} " == *" lxqt "* || " ${DESKTOPS[*]} " == *" kde "* ]]; then
		warn "--qt skipped: LXQt and KDE manage the Qt platform theme themselves"
		return 0
	fi
	_kv_set "$HOME/.config/environment.d/90-$APP_NAME.conf" QT_QPA_PLATFORMTHEME gtk3
	_block_set "$HOME/.xsessionrc" "$APP_NAME" "export QT_QPA_PLATFORMTHEME=gtk3"
	ok "Qt applications will follow the GTK theme after the next login"
}

# Apply every setting for the target user.
apply_main() {
	A_NOTES=()
	_state_init
	A_ICONS=$T_ICON_BASE A_CURSOR=$T_ICON_BASE
	if [[ -f /usr/share/icons/$T_ICON_BASE-Debian/index.theme ]] || (( O_DRY_RUN )); then
		A_ICONS=$T_ICON_BASE-Debian A_CURSOR=$T_ICON_BASE-Debian
	fi
	[[ -d /usr/share/themes/$T_GTK ]] || (( O_DRY_RUN )) || warn "theme $T_GTK is not installed; run without --apply-only first"
	A_WALL=$(_wallpaper_path)
	if [[ -n $A_WALL && ! -f $A_WALL ]] && (( ! O_DRY_RUN )); then
		warn "wallpaper $A_WALL not found; wallpaper not changed"
		A_WALL=""
	fi
	if [[ -n $T_FONT ]] && (( ! O_DRY_RUN )) && ! grep -qiF "$T_FONT_FAMILY" <<<"$(fc-list : family 2>/dev/null)"; then
		warn "font '$T_FONT_FAMILY' is not installed; applications will fall back to the default font"
	fi

	A_LOGO=$(_logo_path || true)
	A_SOUND=""
	if [[ -f /usr/share/sounds/$T_SOUND_THEME/index.theme ]] || (( O_DRY_RUN )); then A_SOUND=$T_SOUND_THEME; fi

	step "Applying $T_DESC for $(id -un)"
	apply_gtk_files
	_hide_official_icons
	ok "Icons and cursors: $A_ICONS (the official sets are hidden in theme choosers)"
	if (( O_GTK4 )); then apply_gtk4_colors; fi
	if (( O_WITH_FONT )); then apply_mono_font; fi
	local de
	for de in "${DESKTOPS[@]}"; do "apply_de_$de"; done
	if (( O_QT )); then apply_qt_env; fi
	if (( ${#A_NOTES[@]} )); then
		log ""
		for de in "${A_NOTES[@]}"; do info "$de"; done
	fi
	return 0
}

# Restore the target user's previous settings and files.
unapply_main() {
	local st rel
	st=$(_st)
	if [[ ! -d $st ]]; then info "No saved settings for $(id -un)"; return 0; fi
	step "Restoring the previous desktop settings of $(id -un)"
	if [[ -s $st/restore.sh ]]; then
		if (( O_DRY_RUN )); then sed 's/^/   [dry-run] /' "$st/restore.sh" >&2
		else bash "$st/restore.sh" 2>/dev/null || warn "some settings could not be restored"; fi
	fi
	while IFS= read -r rel; do
		[[ $rel == file:* ]] || continue
		rel=${rel#file:}
		if grep -qxF "$rel" "$st/created"; then
			run rm -f -- "$HOME/$rel"
		elif [[ -e $st/files/$rel || -L $st/files/$rel ]]; then
			run cp -a -- "$st/files/$rel" "$HOME/$rel"
		fi
	done <"$st/keys"
	local -a dirs=()
	if [[ -f $st/created-dirs ]]; then   # deepest first
		mapfile -t dirs < <(awk 'NF && !seen[$0]++ { print gsub("/", "/") "\t" $0 }' "$st/created-dirs" | sort -rn | cut -f2-)
	fi
	run rm -rf -- "$st"
	for rel in "${dirs[@]}"; do
		if [[ -d $HOME/$rel ]]; then run rmdir --ignore-fail-on-non-empty -- "$HOME/$rel"; fi
	done
	ok "Previous settings restored"
}

# Run apply_main or unapply_main as the target user, inside their session
# when possible. The functions and settings are passed in a generated script.
run_user_phase() {
	local fn=$1 f
	if [[ -z $S_USER ]]; then
		warn "no target user; skipping per-user settings (use --user NAME)"
		return 0
	fi
	f=$WORKDIR/user-phase.sh
	{
		printf '#!/usr/bin/env bash\nset -Eeuo pipefail\numask 022\n'
		# shellcheck disable=SC2046
		declare -p $(compgen -v | grep -E '^(APP|RPI|O|T|S|H|C)_') DESKTOPS
		declare -f
		printf '%s\n' "$fn"
	} >"$f"
	chmod 0644 "$f"
	local -a envv=(HOME="$S_HOME" USER="$S_USER" LOGNAME="$S_USER" LANG="${LANG:-C.UTF-8}"
		PATH="/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin")
	[[ -n $S_RUNTIME ]] && envv+=(XDG_RUNTIME_DIR="$S_RUNTIME")
	[[ -n $S_DBUS ]] && envv+=(DBUS_SESSION_BUS_ADDRESS="$S_DBUS")
	[[ -n $S_DISPLAY ]] && envv+=(DISPLAY="$S_DISPLAY")
	[[ -n $S_WAYLAND ]] && envv+=(WAYLAND_DISPLAY="$S_WAYLAND")
	[[ -n $S_XAUTH ]] && envv+=(XAUTHORITY="$S_XAUTH")
	[[ -n $S_XDG_DESKTOP ]] && envv+=(XDG_CURRENT_DESKTOP="$S_XDG_DESKTOP")
	[[ -n ${LABWC_PID:-} ]] && envv+=(LABWC_PID="$LABWC_PID")
	if [[ -n ${XDG_STATE_HOME:-} ]] && (( EUID == S_UID )); then envv+=(XDG_STATE_HOME="$XDG_STATE_HOME"); fi
	local -a cmd=(bash "$f")
	if [[ -z $S_DBUS ]] && command -v dbus-run-session >/dev/null; then
		warn "no running desktop session found for $S_USER; settings are written for the next login"
		cmd=(dbus-run-session -- bash "$f")
	fi
	if (( EUID == S_UID )); then
		env "${envv[@]}" "${cmd[@]}"
	else
		runuser -u "$S_USER" -- env "${envv[@]}" "${cmd[@]}"
	fi
}

# ---------------------------------------------------------------------------
# Update check
# ---------------------------------------------------------------------------

# --check: list the installed Raspberry Pi OS packages with the newest
# compatible version, and the Debian helpers with their APT
# candidate. Changes nothing and needs no root rights.
do_check() {
	local p st cur cand n=0
	local -a pkgs=()
	preflight_tools
	[[ -z $O_REPO ]] || verify_repo
	pick_suite
	for p in $(_bundle_rpi_pkgs trixie); do
		if [[ -n $(_installed_version "$p") ]]; then pkgs+=("$p"); fi
	done
	if (( ${#pkgs[@]} == 0 )); then info "No Raspberry Pi OS theme packages are installed."; return 0; fi
	if [[ -z $O_REPO ]]; then
		setup_keyring
		index_load rpi "$H_SUITE" "$H_ARCH" || die "cannot download the $H_SUITE package index from $RPI_ARCHIVE"
	fi
	for p in "${pkgs[@]}"; do IN_SET[$p]=1; done

	step "Raspberry Pi OS packages ($H_SUITE, $H_ARCH)"
	for p in "${pkgs[@]}"; do
		if ! resolve_pkg "$p"; then _pkg_line "$p" "-" "not available"; continue; fi
		st=$(_pkg_status "$p")
		_pkg_line "$p" "${PKG_VER[$p]}" "$st"
		[[ $st == "up to date" || $st == installed* ]] || n=$(( n + 1 ))
	done

	step "Debian packages (updated by APT)"
	for p in gtk2-engines-pixbuf libgtk2.0-bin gnome-icon-theme adwaita-icon-theme-legacy \
		fonts-liberation fonts-liberation2 sound-theme-freedesktop network-manager-applet \
		network-manager-gnome blueman; do
		cur=$(_installed_version "$p")
		[[ -n $cur ]] || continue
		cand=$(LC_ALL=C apt-cache policy "$p" 2>/dev/null | awk '/Candidate:/ { print $2 }')
		if [[ -n $cand && $cand != "(none)" ]] && dpkg --compare-versions "$cur" lt "$cand"; then
			_pkg_line "$p" "$cur" "update to $cand with apt upgrade"
		else
			_pkg_line "$p" "$cur" "up to date"
		fi
	done
	[[ -n $O_REPO ]] || info "Debian versions are as of your last 'apt update'."

	log ""
	if (( n )); then
		info "$n Raspberry Pi OS package(s) can be updated: run $(_self_cmd)"
	else
		ok "The Raspberry Pi OS packages are up to date"
	fi
}

# ---------------------------------------------------------------------------
# Uninstall
# ---------------------------------------------------------------------------
# Print the part of a package set that APT can purge without removing any
# other package. Members that other installed software depends on are left
# out; APT's own simulation decides.
_safe_purge_set() {
	local -a set=("$@") extra=() keep=()
	local sim e
	while (( ${#set[@]} )); do
		sim=$(LC_ALL=C apt-get -s purge "${set[@]}" 2>/dev/null) || return 1
		mapfile -t extra < <(awk '/^(Purg|Remv) / { sub(/:.*/, "", $2); print $2 }' <<<"$sim" \
			| grep -vxF -f <(printf '%s\n' "${set[@]}") || true)
		if (( ${#extra[@]} == 0 )); then printf '%s\n' "${set[@]}"; return 0; fi
		# Keep the members those packages depend on, then try again
		mapfile -t keep < <(for e in "${extra[@]}"; do dpkg-query -W -f='${Pre-Depends}, ${Depends}\n' "$e" 2>/dev/null; done \
			| tr ',|' '\n' | sed 's/(.*//; s/:.*//; s/[[:space:]]//g' | grep -xF -f <(printf '%s\n' "${set[@]}") | sort -u || true)
		(( ${#keep[@]} )) || return 1   # the dependency is indirect; remove nothing
		mapfile -t set < <(printf '%s\n' "${set[@]}" | grep -vxF -f <(printf '%s\n' "${keep[@]}") || true)
	done
}

# Restore the user's settings and remove what the installer added.
do_uninstall() {
	local -a pkgs=() still=()
	local p
	if [[ -f $APP_SYS_STATE/installed-packages ]]; then mapfile -t pkgs <"$APP_SYS_STATE/installed-packages"; fi
	for p in "${pkgs[@]}"; do [[ -n $(_installed_version "$p") ]] && still+=("$p"); done
	step "Uninstall"
	[[ -n $S_USER ]] && log "  Restore desktop settings of: $S_USER"
	[[ -n $(_installed_version "$APP_PKG") ]] && log "  Remove package:              $APP_PKG"
	(( ${#still[@]} )) && log "  Packages installed by this script: ${still[*]}"
	ask "Continue" y || die "aborted"
	if [[ -f $APP_SYS_STATE/pi-greeter.conf.orig ]]; then
		prepare_root
		as_root cp -a -- "$APP_SYS_STATE/pi-greeter.conf.orig" /etc/lightdm/pi-greeter.conf
		ok "Restored the previous /etc/lightdm/pi-greeter.conf"
	fi
	run_user_phase unapply_main
	local -a purge=() remove=() keep=()
	local forget=0
	[[ -n $(_installed_version "$APP_PKG") ]] && purge+=("$APP_PKG")
	if (( ${#still[@]} )) && ask "Also remove the packages installed by this script" y; then
		mapfile -t remove < <(_safe_purge_set "${still[@]}" || true)
		for p in "${still[@]}"; do [[ " ${remove[*]} " == *" $p "* ]] || keep+=("$p"); done
		if (( ${#keep[@]} )); then info "Kept, because other installed software needs them: ${keep[*]}"; fi
		purge+=("${remove[@]}")
		forget=1
	fi
	if (( ${#purge[@]} || forget )); then prepare_root; fi
	if (( ${#purge[@]} )); then as_root env DEBIAN_FRONTEND=noninteractive apt-get purge -y "${purge[@]}"; fi
	# Packages kept for other software are left to APT: marked automatic, they go
	# with 'apt autoremove' once nothing needs them. The record is then done with.
	if (( forget )); then
		if (( ${#keep[@]} )); then as_root apt-mark auto "${keep[@]}" >/dev/null; fi
		as_root rm -rf -- "$APP_SYS_STATE"
	fi
	if (( ${#remove[@]} + ${#keep[@]} )); then
		info "Run 'sudo apt autoremove' to remove dependencies that are no longer needed."
	fi
	ok "Uninstalled"
}

# ---------------------------------------------------------------------------
# Interactive UI
# ---------------------------------------------------------------------------
# Print the title.
banner() {
	log ""
	log "${C_B}  ${APP_NAME} ${APP_VERSION}${C_0} — the Raspberry Pi OS desktop look for Debian"
	if [[ -n $O_REPO ]]; then log "${C_D}  Offline installer · packages from $(basename -- "$O_REPO")/${C_0}"
	else log "${C_D}  Online installer · official packages from archive.raspberrypi.org${C_0}"; fi
}

# Succeed if a package is installed, or about to be installed in a dry run.
_have_pkg() {
	[[ -n $(_installed_version "$1") ]] && return 0
	(( O_DRY_RUN )) && [[ " ${FETCH_PKGS[*]} " == *" $1 "* ]]
}

# Show a numbered menu and set REPLY to the chosen index (from 0).
# Usage: _menu PROMPT DEFAULT-NUMBER ALLOW-ZERO ITEM...
_menu() {
	local prompt=$1 def=$2 zero=$3 ans i; shift 3
	for i in $(seq 1 $#); do log "   $i) ${!i}"; done
	(( zero )) && log "   0) Keep my current desktop"
	while :; do
		read -r -p "  $prompt [$def]: " ans </dev/tty || ans=""
		ans=${ans:-$def}
		if (( zero )) && [[ $ans == 0 ]]; then REPLY=-1; return 0; fi
		if [[ $ans =~ ^[0-9]+$ ]] && (( ans >= 1 && ans <= $# )); then REPLY=$(( ans - 1 )); return 0; fi
		warn "please enter a number from the list"
	done
}

# Choose the theme and icon set to apply among the installed ones. -t and
# --icons choose without asking; with -y (or without a terminal) the theme
# matching the Debian release is used. Fails if the user keeps the desktop.
choose_look() {
	local id i def=1 dflt
	local -a ids=() icons=() items=()
	dflt=$(_default_theme)
	for id in pixflat pixnoir pixtrix pixonyx pix; do
		if _have_pkg "$(_theme_pkg "$id")"; then ids+=("$id"); fi
	done
	(( ${#ids[@]} )) || die "no Raspberry Pi OS theme is installed; run $(_self_cmd) without --apply-only"
	for id in pixflat pixtrix pix; do
		if _have_pkg "$(_icons_pkg "$id")"; then icons+=("$id"); fi
	done

	if [[ -n $O_THEME ]]; then
		[[ " ${ids[*]} " == *" $O_THEME "* ]] || die "theme $O_THEME is not installed (installed: ${ids[*]})"
	elif (( ! O_INTERACTIVE )); then
		O_THEME=$dflt
		[[ " ${ids[*]} " == *" $O_THEME "* ]] || O_THEME=${ids[0]}
	else
		step "Select the theme"
		for i in "${!ids[@]}"; do
			set_theme "${ids[i]}"
			items+=("$T_DESC")
			[[ ${ids[i]} == "$dflt" ]] && def=$(( i + 1 ))
		done
		_menu "Theme" "$def" 1 "${items[@]}"
		(( REPLY >= 0 )) || return 1
		O_THEME=${ids[REPLY]}
	fi

	if [[ -n $O_ICONS ]]; then
		[[ " ${icons[*]} " == *" $O_ICONS "* ]] || die "icon set $O_ICONS is not available (available: ${icons[*]})"
	elif (( O_INTERACTIVE && ${#icons[@]} > 1 )); then
		set_theme "$O_THEME"
		step "Select the icons and cursors"
		items=() def=1
		for i in "${!icons[@]}"; do
			case ${icons[i]} in
				pixflat) items+=("PiXflat — Raspberry Pi OS Bookworm") ;;
				pixtrix) items+=("PiXtrix — Raspberry Pi OS Trixie") ;;
				pix)     items+=("PiX — legacy Raspberry Pi OS") ;;
			esac
			[[ ${icons[i]} == "${T_ICON_BASE,,}" ]] && def=$(( i + 1 ))
		done
		_menu "Icons" "$def" 0 "${items[@]}"
		O_ICONS=${icons[REPLY]}
	fi
	set_theme "$O_THEME"
}

# Summarise what will be installed.
print_plan() {
	local p id total=0 src themes=""
	for p in "${FETCH_PKGS[@]}"; do total=$(( total + ${PKG_SIZE[$p]:-0} )); done
	for id in pixflat pixnoir pixtrix pixonyx pix; do
		[[ " ${FETCH_PKGS[*]} " == *" $(_theme_pkg "$id") "* ]] && themes+="${themes:+, }$id"
	done
	if [[ -n $O_REPO ]]; then src="the offline repository"; else src="$RPI_ARCHIVE"; fi
	step "Plan"
	log "  Themes       $themes (the look is chosen after installation)"
	log "  Packages     from $src ($H_SUITE, $H_ARCH), up to $(human_size "$total")"
	for p in "${FETCH_PKGS[@]}"; do _pkg_line "$p" "${PKG_VER[$p]}" "$(_pkg_status "$p")"; done
	for p in "${APT_PKGS[@]}"; do _pkg_line "$p" "(APT)" "new, from your Debian sources"; done
	if (( O_DO_APPLY )); then
		log "  User         ${S_USER:-none}"
		log "  Desktops     ${DESKTOPS[*]:-none detected (GTK configuration files only)}"
	fi
	(( O_DRY_RUN )) && log "  ${C_Y}Dry run: nothing will be changed${C_0}"
	return 0
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
# Remove temporary files on exit.
cleanup() {
	if [[ -n $WORKDIR && -d $WORKDIR ]]; then rm -rf -- "$WORKDIR"; fi
	if [[ -n $BUILD_STAGE && -d $BUILD_STAGE ]]; then rm -rf -- "$BUILD_STAGE"; fi
}

# Copy everything this run prints to a log of its own in the target user's home
# (~/pixflat-theme-DATE-TIME.log, without colours), after a header describing
# the system, so that a run can be reviewed or shared when something looks
# wrong.
_start_log() {
	local log
	printf -v log '%s/%s-%(%Y%m%d-%H%M%S)T.log' "${S_HOME:-$HOME}" "$APP_NAME" -1
	{ : >>"$log"; } 2>/dev/null || return 0
	if (( EUID == 0 )) && [[ -n $S_UID ]]; then chown "$S_UID" "$log" 2>/dev/null || true; fi
	{
		printf '\n===== %s %s, %s =====\n' "$APP_NAME" "$APP_VERSION" "$(date '+%Y-%m-%d %H:%M:%S %Z')"
		printf 'Command:  %s %s\n' "$0" "$(_q "${ARGV[@]}")"
		printf 'System:   %s (%s), %s\n' "${H_PRETTY:-unknown}" "${H_CODENAME:-?}" "$H_ARCH"
		printf 'User:     %s (uid %s), running as uid %s\n' "${S_USER:-none}" "${S_UID:-?}" "$EUID"
		printf 'Session:  %s (XDG_CURRENT_DESKTOP=%s, DESKTOP_SESSION=%s, display %s)\n' "${S_PROC:-none}" \
			"${S_XDG_DESKTOP:-}" "${S_DESKTOP_SESSION:-}" "${S_DISPLAY:-${S_WAYLAND:-none}}"
		printf 'Packages: %s\n' "$(dpkg-query -W -f='${db:Status-Abbrev} ${Package}=${Version}\n' lxpanel lxpanel-pi \
			lpplug-menu pishutdown gui-runcmd network-manager network-manager-applet network-manager-gnome bluez \
			lightdm lightdm-gtk-greeter "$APP_PKG" 2>/dev/null | awk '$1 ~ /^.i/ { print $2 }' | paste -sd' ' -)"
	} >>"$log"
	# Every line is written with the date and time, without colours
	exec > >(tee -a >(sed -u 's/\x1b\[[0-9;]*m//g' \
		| while IFS= read -r line; do printf '%(%Y-%m-%d %H:%M:%S)T  %s\n' -1 "$line"; done >>"$log")) 2>&1
	LOG_FILE=$log
}

# Report what the desktop ended up with: the menu and panel files, their
# Raspberry Pi entries and the panel in use. It goes to the log as well, and is
# the first thing to look at when the desktop does not match.
_log_state() {
	local h=${S_HOME:-} m f v
	[[ -n $h && -d $h ]] || return 0
	log ""
	log "  Desktop state"
	m=$h/.config/menus/lxde-applications.menu
	if [[ -f $m ]]; then
		v=$(grep -o 'gui-runcmd.desktop\|pishutdown.desktop' "$m" | sort -u | paste -sd'+' - || true)
		log "    menu       $m: $(grep -c '<Menu>' "$m") categories, ${v:-no Run or Shutdown entry}"
	else
		log "    menu       $m: not written"
	fi
	for f in "$h/.config/lxpanel-pi/panels/panel" "$h/.config/lxpanel"/*/panels/panel; do
		[[ -f $f ]] || continue
		v=$(grep -h '^[ \t]*type=' "$f" | sed 's/^[ \t]*type=//' | paste -sd' ' - || true)
		log "    panel      $f:"
		log "               $(grep -hE '^[ \t]*(height|iconsize|edge|width)=' "$f" | tr -d ' \t' | paste -sd' ' - || true)"
		log "               ${v:-no plugins}"
	done
	v=$(pgrep -a -u "${S_UID:-$UID}" -x 'lxpanel|lxpanel-pi' 2>/dev/null | paste -sd'; ' - || true)
	log "    running    ${v:-no panel process}"
	v=$(grep -h lxpanel "$h/.config/lxsession"/*/autostart 2>/dev/null | paste -sd' ' - || true)
	log "    autostart  ${v:-nothing for lxpanel}"
	v=""
	for f in gui-runcmd pishutdown debian-reference-common; do
		[[ -f /usr/share/applications/$f.desktop ]] && v+="$f "
	done
	log "    entries    ${v:-none installed}"
	v=$(grep -h pcmanfm "$h/.config/lxsession"/*/autostart 2>/dev/null | paste -sd' ' - || true)
	f=$(sed -n 's/^inode\/directory=//p' "$h/.config/mimeapps.list" 2>/dev/null || true)
	log "    files      $([[ -x /usr/bin/pcmanfm-pi ]] && echo 'pcmanfm-pi installed' || echo "Debian's pcmanfm"), desktop: ${v:-nothing}, folders: ${f:-unset}"
	v=$(sed -n 's/^gtk-icon-theme-name=//p' "$h/.config/gtk-3.0/settings.ini" 2>/dev/null || true)
	log "    icons      ${v:-not set} (GTK 3)"
	v=$(sed -n 's/^sNet\/ThemeName=//p; s/^sNet\/IconThemeName=/icons /p' "$h/.config/lxsession"/*/desktop.conf 2>/dev/null | paste -sd', ' - || true)
	log "    session    ${v:-no LXDE session settings}"
	v=$(pgrep -a -u "${S_UID:-$UID}" -f 'polkit.*agent|lxpolkit' 2>/dev/null | sed 's/^[0-9]* //' | paste -sd'; ' - || true)
	log "    polkit     ${v:-no authentication agent}"
}

# Entry point: parse options, then check, uninstall, rebuild ./packages, or
# install and apply a theme.
main() {
	ARGV=("$@")
	init_colors
	parse_args "$@"
	banner
	WORKDIR=$(mktemp -d "${TMPDIR:-/tmp}/$APP_NAME.XXXXXX")
	chmod 0755 "$WORKDIR"
	trap cleanup EXIT
	trap 'die "interrupted"' INT TERM

	if [[ $O_ACTION == update-packages ]]; then
		build_offline_repo
		return 0
	fi
	detect_host
	resolve_user
	find_session_env
	_start_log
	case $O_ACTION in
		uninstall) do_uninstall; return 0 ;;
		check)     do_check; return 0 ;;
	esac

	detect_desktops
	if (( O_LIGHTDM < 0 )); then O_LIGHTDM=$([[ -x /usr/sbin/lightdm-gtk-greeter ]] && echo 1 || echo 0); fi
	if (( O_DO_INSTALL )); then
		preflight_tools
		[[ -z $O_REPO ]] || verify_repo
		pick_suite
		resolve_all
		print_plan
		ask "Proceed" y || die "aborted"
		prepare_root
		install_all
	fi

	# Choose the look now that the themes are installed, then build the
	# compatibility package (it includes the login screen theme) and apply.
	local applied=0
	if [[ -x /usr/bin/lxpanel-pi ]] || { (( O_DRY_RUN )) && [[ " ${FETCH_PKGS[*]} " == *" lxpanel-pi "* ]]; }; then O_PI_PANEL=1; fi
	if (( O_FM )) && { [[ -x /usr/bin/pcmanfm-pi ]] || { (( O_DRY_RUN )) && [[ " ${FETCH_PKGS[*]} " == *" pcmanfm-pi "* ]]; }; }; then O_PI_FM=1; fi
	if (( O_DO_APPLY )) && choose_look; then applied=1; fi
	if (( O_DO_INSTALL || (applied && O_LIGHTDM) )); then
		prepare_root
		install_local_pkg
		if (( O_LIGHTDM )); then install_greeter_conf; fi
	fi
	if (( applied )); then run_user_phase apply_main; fi

	log ""
	if (( applied )); then ok "${C_B}Done.${C_0} $T_DESC is applied."
	else ok "${C_B}Done.${C_0} The Raspberry Pi OS themes are installed."; fi
	info "Change the look any time: $(_self_cmd) --apply-only (GTK theme and icons also in your desktop's appearance settings)."
	if (( O_DO_INSTALL )); then info "Check for updates: $(_self_cmd) --check"; fi
	info "Undo everything: $(_self_cmd) --uninstall"
	_log_state
	if [[ -n ${LOG_FILE:-} ]]; then info "Log of this run: $LOG_FILE"; fi
}

# Run main unless this file is sourced (install-offline.sh sources it).
if [[ ${BASH_SOURCE[0]:-} == "$0" || -z ${BASH_SOURCE[0]:-} ]]; then
	main "$@"
fi
