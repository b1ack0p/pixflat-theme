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
readonly DEBIAN_ARCHIVE="https://deb.debian.org/debian"
readonly DEBIAN_KEYRING="/usr/share/keyrings/debian-archive-keyring.gpg"
readonly OFFLINE_SUITES=(bookworm trixie)
readonly OFFLINE_ARCHES=(amd64 arm64 armhf i386)
readonly DE_SUPPORTED=(lxde lxqt xfce gnome budgie cinnamon mate openbox labwc kde)
readonly SESSION_PROCS=(lxsession xfce4-session lxqt-session gnome-shell budgie-panel
	cinnamon mate-session plasmashell labwc openbox xfwm4)

# Dependency names that no longer exist on newer Debian releases, mapped to
# their successors (first available candidate wins).
declare -rA DEP_RENAMES=(
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

# ---------------------------------------------------------------------------
# Options (O_*), theme (T_*), session (S_*) and host (H_*) state
# ---------------------------------------------------------------------------
O_ACTION="install"      # install | check | uninstall | update-packages
O_REPO=""              # offline repository; set by install-offline.sh
O_THEME=""
O_DESKTOPS="auto"
O_USER=""
O_SUITE=""
O_WALLPAPER=""
O_WITH_WALLPAPER=1
O_4K=0
O_PANEL=1
O_GTK4=1
O_WITH_FONT=1
O_LIGHTDM=0
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
APT_PKGS=()             # installed by name from the APT sources
declare -A PKG_VER=() PKG_FILE=() PKG_SHA=() PKG_SIZE=() PKG_SUITE=() PKG_AID=()
declare -A IDX_LOADED=() IDX_FAILED=() IN_SET=()
WORKDIR="" KEYRING="" DEP_INDEX="" BUILD_STAGE=""
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

Themes (-t):
  pixflat   Light, Raspberry Pi OS Bookworm (PiXflat + Piboto)           [default]
  pixnoir   Dark,  Raspberry Pi OS Bookworm (PiXnoir + Piboto)
  pixtrix   Light, Raspberry Pi OS Trixie   (PiXtrix + Nunito Sans)       Debian 13+
  pixonyx   Dark,  Raspberry Pi OS Trixie   (PiXonyx + Nunito Sans)       Debian 13+
  pix       Legacy Raspberry Pi OS Buster/Bullseye look (PiX)

Options:
  -t, --theme NAME        Theme to install and apply (see above).
  -d, --desktop LIST      Desktops to configure: auto (default), all, none, or a
                          comma list of: ${DE_SUPPORTED[*]}
  -u, --user NAME         User whose desktop is configured (default: the user
                          running the script, or \$SUDO_USER under sudo).
      --wallpaper W       Wallpaper file name in /usr/share/rpd-wallpaper, or a path.
      --no-wallpaper      Do not install or set the Raspberry Pi wallpapers.
      --4k                Use the 4K (3840x2160) wallpaper set instead (about 100 MB).
      --no-font           Do not install or set the Raspberry Pi UI font.
      --no-panel          Keep your panel as it is (default: Raspberry Pi OS layout
                          on LXDE and Xfce: top, 36 px, Debian logo menu button).
      --no-gtk4           Do not add the theme colours for GTK 4/libadwaita applications.
      --lightdm           Also theme the LightDM GTK greeter (login screen).
      --qt                Make Qt applications follow the GTK theme.
      --suite NAME        Raspberry Pi OS release to take packages from
                          (default: matched to this system; bookworm, trixie, ...).
      --install-only      Install system packages only, do not change settings.
      --apply-only        Only apply settings (themes must already be installed).
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
  ./${self}                        interactive
  ./${self} -t pixtrix -y          PiXtrix for the current desktop
  sudo ./${self} -t pixnoir -d lxde,xfce --lightdm -y
  ./${self} --apply-only -t pixflat
  ./${self} --uninstall
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
			-d|--desktop)   (( $# >= 2 )) || die "$opt needs a value"; O_DESKTOPS=${2,,}; shift ;;
			-u|--user)      (( $# >= 2 )) || die "$opt needs a value"; O_USER=$2; shift ;;
			--suite)        (( $# >= 2 )) || die "$opt needs a value"; O_SUITE=${2,,}; shift ;;
			--wallpaper)    (( $# >= 2 )) || die "$opt needs a value"; O_WALLPAPER=$2; shift ;;
			--no-wallpaper) O_WITH_WALLPAPER=0 ;;
			--4k)           O_4K=1 ;;
			--no-font)      O_WITH_FONT=0 ;;
			--no-panel)     O_PANEL=0 ;;
			--no-gtk4)      O_GTK4=0 ;;
			--lightdm)      O_LIGHTDM=1 ;;
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
	if [[ -n $O_THEME ]]; then
		case $O_THEME in pixflat|pixnoir|pixtrix|pixonyx|pix) ;; *) die "unknown theme '$O_THEME' (see --help)" ;; esac
	fi
	if [[ -n $O_SUITE ]] && ! _suite_rank "$O_SUITE" >/dev/null; then
		die "unsupported suite '$O_SUITE' (use one of: ${RPI_SUITES[*]})"
	fi
	if (( ! O_YES )) && { : </dev/tty; } 2>/dev/null; then O_INTERACTIVE=1; fi
}

# ---------------------------------------------------------------------------
# Theme definitions
# ---------------------------------------------------------------------------
# Set the T_* variables for a theme.
set_theme() {
	T_ID=$1
	case $T_ID in
		pixflat) T_GTK=PiXflat T_WM=PiXflat T_ICON_BASE=PiXflat T_ERA=bookworm T_DARK=0
		         T_DESC="PiXflat — light, Raspberry Pi OS Bookworm" ;;
		pixnoir) T_GTK=PiXnoir T_WM=PiXnoir T_ICON_BASE=PiXflat T_ERA=bookworm T_DARK=1
		         T_DESC="PiXnoir — dark, Raspberry Pi OS Bookworm" ;;
		pixtrix) T_GTK=PiXtrix T_WM=PiXtrix T_ICON_BASE=PiXtrix T_ERA=trixie T_DARK=0
		         T_DESC="PiXtrix — light, Raspberry Pi OS Trixie" ;;
		pixonyx) T_GTK=PiXonyx T_WM=PiXonyx T_ICON_BASE=PiXtrix T_ERA=trixie T_DARK=1
		         T_DESC="PiXonyx — dark, Raspberry Pi OS Trixie" ;;
		pix)     T_GTK=PiX T_WM=PiX T_ICON_BASE=PiX T_ERA=legacy T_DARK=0
		         T_DESC="PiX — legacy Raspberry Pi OS Buster/Bullseye" ;;
		*) die "unknown theme '$T_ID'" ;;
	esac
	case $T_ERA in
		trixie)
			T_THEME_PKGS=(pixtrix-theme pixtrix-icons gtk2-engines-pixflat)
			T_ICON_FALLBACK=adwaita-icon-theme-legacy
			T_FONT_PKG=fonts-nunito-sans T_FONT_FAMILY="Nunito Sans" T_FONT_WEIGHT=Light
			T_FONT="Nunito Sans Light 12"
			T_WALL_PKG=rpd-wallpaper-trixie T_WALL_DEFAULT=sunrise.jpg ;;
		*)
			if [[ $T_ERA == legacy ]]; then
				T_THEME_PKGS=(pix-theme rpd-icons gtk2-engines-clearlookspix)
			else
				T_THEME_PKGS=(pixflat-theme pixflat-icons gtk2-engines-pixflat)
			fi
			T_ICON_FALLBACK=gnome-icon-theme
			T_FONT_PKG=fonts-piboto T_FONT_FAMILY=PibotoLt T_FONT_WEIGHT=Normal
			T_FONT="PibotoLt 12"
			T_WALL_PKG=rpd-wallpaper T_WALL_DEFAULT=fisherman.jpg ;;
	esac
	# Values used by Raspberry Pi OS itself (raspberrypi-ui-mods / rpd-common)
	T_COLOR_SCHEME='selected_bg_color:#878791919b9b\nselected_fg_color:#f0f0f0f0f0f0\nbar_bg_color:#ededececebeb\nbar_fg_color:#000000000000\n'
	T_DESK_BG="#d6d6d3d3dede" T_DESK_FG="#e8e8e8e8e8e8" T_DESK_SHADOW="#d6d6d3d3dede"
	T_CURSOR_SIZE=24
	T_SOUND_THEME=freedesktop   # Raspberry Pi OS enables event sounds with the default theme
	if (( ! O_WITH_FONT )); then T_FONT="" T_FONT_FAMILY=""; fi
	if (( O_4K )); then T_WALL_PKG+=-4k T_WALL_DEFAULT=${T_WALL_DEFAULT%.jpg}_4k.jpg; fi
}

# Raspberry Pi OS packages the offline repository carries for a release.
_bundle_rpi_pkgs() {
	printf '%s\n' pixflat-theme pixflat-icons gtk2-engines-pixflat fonts-piboto rpd-wallpaper \
		rpd-wallpaper-4k pix-theme rpd-icons gtk2-engines-clearlookspix
	if [[ $1 == trixie ]]; then
		printf '%s\n' pixtrix-theme pixtrix-icons fonts-nunito-sans rpd-wallpaper-trixie rpd-wallpaper-trixie-4k
	fi
}
# Debian packages the themes need; the builder adds their missing dependencies.
_bundle_deb_pkgs() {
	printf '%s\n' gtk2-engines-pixbuf libgtk2.0-bin gnome-icon-theme sound-theme-freedesktop "$(_mono_font_pkg "$1")"
	if [[ $1 == trixie ]]; then printf '%s\n' adwaita-icon-theme-legacy; fi
}
# Debian package providing Liberation Mono, the Raspberry Pi OS monospace font.
_mono_font_pkg() { if [[ $1 == bookworm ]]; then echo fonts-liberation2; else echo fonts-liberation; fi; }

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
	if [[ -n $O_SUITE ]]; then
		H_SUITE=$O_SUITE
	else
		case $H_CODENAME in
			buster|bullseye|bookworm|trixie) H_SUITE=$H_CODENAME ;;
			forky|duke|sid)                  H_SUITE=trixie ;;
			*)  # Derivatives: match by ABI generation (64-bit time_t transition)
				if apt_has libglib2.0-0t64; then H_SUITE=trixie
				elif apt_has libglib2.0-0; then H_SUITE=bookworm
				else die "cannot determine a matching Raspberry Pi OS release; use --suite"
				fi ;;
		esac
	fi
	if [[ -n $O_REPO && ! -d $O_REPO/dists/$H_SUITE/main/binary-$H_ARCH ]]; then
		die "the offline repository has no packages for $H_SUITE/$H_ARCH (it has: $(_repo_contents))"
	fi
}

# Stop if the theme needs a newer Debian release.
check_theme_supported() {
	if [[ $T_ERA == trixie ]] && (( $(_suite_rank "$H_SUITE") < 3 )); then
		die "$T_GTK needs Debian 13 (trixie) or newer; choose pixflat or pixnoir on this system"
	fi
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
	if [[ -n $pid && -r /proc/$pid/environ ]]; then
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
		done </proc/"$pid"/environ
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

# Download a URL (or copy a local path) over HTTPS only.
# Usage: fetch URL|PATH OUTPUT [SHOW-PROGRESS]
fetch() {
	local url=$1 out=$2 progress=${3:-0}
	if [[ $url == /* ]]; then cp -- "$url" "$out"; return; fi
	debug "GET $url"
	if command -v curl >/dev/null; then
		local -a a=(-fL --proto '=https' --proto-redir '=https' --retry 3 --retry-delay 2 --connect-timeout 20 -o "$out")
		if (( progress )) && [[ -t 2 ]]; then a+=(--progress-bar); else a+=(-sS); fi
		curl "${a[@]}" "$url"
	elif command -v wget >/dev/null; then
		local -a a=(--https-only --tries=3 --timeout=20 -O "$out")
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
	fetch "$RPI_KEY_URL" "$WORKDIR/rpi.asc"
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
	fetch "$base/dists/$suite/main/binary-$arch/Packages.$comp" "$d/Packages-$arch.$comp"
	sha256_check "$d/Packages-$arch.$comp" "$sha"
	if [[ $comp == xz ]]; then xz -dc "$d/Packages-$arch.$comp"; else gzip -dc "$d/Packages-$arch.$comp"; fi >"$d/Packages-$arch"
	rm -f -- "$d/Packages-$arch.$comp"
	IDX_LOADED[$key]=1
}

# Print "version<TAB>arch<TAB>filename<TAB>sha256<TAB>size<TAB>depends" for the
# newest version of a package in one index.
# Usage: index_best ARCHIVE SUITE ARCH PACKAGE
index_best() {
	local aid=$1 suite=$2 arch=$3 pkg=$4 line best="" bv="" v
	while IFS= read -r line; do
		v=${line%%$'\t'*}
		if [[ -z $bv ]] || dpkg --compare-versions "$v" gt "$bv"; then bv=$v best=$line; fi
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
	[[ -n $best ]] && printf '%s\n' "$best"
}

# Succeed if every dependency in a Depends field can be satisfied on the target,
# counting renamed dependencies (DEP_RENAMES) as satisfied by their successor.
_deps_satisfiable() {
	local group alt r ok
	local -a groups alts
	IFS=, read -ra groups <<<"$1"
	for group in "${groups[@]}"; do
		[[ -n ${group//[[:space:]]/} ]] || continue
		ok=0
		IFS='|' read -ra alts <<<"$group"
		for alt in "${alts[@]}"; do
			alt=${alt%%(*}; alt=${alt%%:*}; alt=${alt//[[:space:]]/}
			if _dep_ok "$alt"; then ok=1; break; fi
			for r in ${DEP_RENAMES[$alt]:-}; do
				if _dep_ok "$r"; then ok=1; break 2; fi
			done
		done
		(( ok )) || return 1
	done
}

# Find the newest compatible version of a package and record it in PKG_*.
#  * From the target release: any package (its binaries match this system).
#  * From newer Raspberry Pi OS releases: architecture-independent packages
#    (icons, fonts, wallpapers) whose dependencies are all satisfiable here.
#  * Only if neither has it: older releases, then the armhf index, which lists
#    every Pi package.
# Offline, the local repository is the only source.
# Usage: resolve_pkg PACKAGE [ARCHIVE]
resolve_pkg() {
	local pkg=$1 aid=${2:-rpi} s x line best="" v a f sha z d
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
	for x in "$H_SUITE/$H_ARCH" "${newer[@]}"; do
		index_load "$aid" "${x%/*}" "${x#*/}" || continue
		line=$(index_best "$aid" "${x%/*}" "${x#*/}" "$pkg") || continue
		IFS=$'\t' read -r v a f sha z d <<<"$line"
		if [[ $x != "$H_SUITE/$H_ARCH" ]]; then
			if [[ $a != all ]] || ! _deps_satisfiable "$d"; then continue; fi
		fi
		if [[ -z $best ]] || dpkg --compare-versions "$v" gt "${best%%$'\t'*}"; then best="$line"$'\t'"${x%/*}"; fi
	done
	if [[ -z $best ]]; then
		for x in "${older[@]}"; do
			index_load "$aid" "${x%/*}" "${x#*/}" || continue
			line=$(index_best "$aid" "${x%/*}" "${x#*/}" "$pkg") || continue
			[[ $(cut -f2 <<<"$line") == all ]] || continue
			best="$line"$'\t'"${x%/*}"
			break
		done
	fi
	[[ -n $best ]] || return 1
	IFS=$'\t' read -r v a f sha z d s <<<"$best"
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
	fetch "$base/${PKG_FILE[$pkg]}" "$out" "$big"
	sha256_check "$out" "${PKG_SHA[$pkg]}"
	chmod 0644 "$out"
	printf '%s\n' "$out"
}

# Print the dependency closure of the roots within a Packages index: every
# package reachable through Depends and Pre-Depends, taking the first available
# alternative and resolving virtual packages through Provides.
#   BASE=priority  also start from the Debian base system (priority required,
#                  important and standard)
#   INSTALLED=1    skip dependencies that installed packages already satisfy
# Usage: _closure INDEX [ROOT]...
_closure() {
	local idx=$1 inst=/dev/null; shift
	if [[ ${INSTALLED:-} == 1 ]]; then
		inst=$WORKDIR/installed-names
		dpkg-query -W -f='${db:Status-Abbrev} ${Package} ${Provides}\n' 2>/dev/null \
			| awk '$1 ~ /^.i/ { $1 = ""; gsub(/\([^)]*\)|,/, " "); n = split($0, a, " "); for (i = 1; i <= n; i++) print a[i] }' \
			| sort -u >"$inst"
	fi
	ROOTS="$*" INST=$inst awk '
		function resolve(x) { if (x in real) return x; if (x in prov) return prov[x]; return "" }
		function clean(x) { gsub(/\(.*\)/, "", x); sub(/:[a-z0-9]+/, "", x); gsub(/[ \t]/, "", x); return x }
		BEGIN {
			while ((getline line < ENVIRON["INST"]) > 0) have[line] = 1
			RS = ""; FS = "\n"
		}
		{
			n = d = pr = ""
			for (i = 1; i <= NF; i++) {
				if ($i ~ /^Package: /) n = substr($i, 10)
				else if ($i ~ /^(Pre-)?Depends: /) { x = $i; sub(/^[^:]*: /, "", x); d = d (d == "" ? "" : ",") x }
				else if ($i ~ /^Provides: /) pr = substr($i, 11)
				else if ($i ~ /^Priority: /) pri = substr($i, 11)
			}
			if (n == "" || n in real) next
			real[n] = 1; deps[n] = d; prio[n] = pri; pri = ""
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
	if [[ -n $DEP_INDEX ]]; then grep -qxF -- "$1" "$DEP_INDEX"; else apt_has "$1"; fi
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
	DEPS=$deps awk '/^Depends:/ { print "Depends: " ENVIRON["DEPS"]; next } { print }' \
		"$dir/DEBIAN/control" >"$dir/DEBIAN/control.new"
	mv -- "$dir/DEBIAN/control.new" "$dir/DEBIAN/control"
	dpkg-deb --root-owner-group -b "$dir" "$out" >/dev/null
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
# Usage: _xpm_tile FILE WIDTH HEIGHT ROW CHAR=COLOUR...
_xpm_tile() {
	local file=$1 h=$3 row=$4 i; shift 4
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
		for n in 1 2 3 4 5; do _xpm_tile "$out/title-$n-$st.xpm" 2 "$H" "bb" "b=$bg"; done
		_xpm_tile "$out/top-left-$st.xpm"  3 "$H" "dbb" "d=$bd" "b=$bg"
		_xpm_tile "$out/top-right-$st.xpm" 3 "$H" "bbd" "d=$bd" "b=$bg"
		_xpm_tile "$out/left-$st.xpm"      3 2 "dcc" "d=$bd" "c=$cl"
		_xpm_tile "$out/right-$st.xpm"     3 2 "ccd" "d=$bd" "c=$cl"
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

# Create the "<Base>-Debian" icon theme, which inherits the official one.
# Usage: gen_icon_overlay BASE-NAME OUTPUT-DIR
gen_icon_overlay() {
	local base=$1 out=$2 bdir=$SYS_ROOT/usr/share/icons/$1 inh
	mkdir -p "$out"
	[[ -d $bdir/cursors ]] && _cursor_aliases "$bdir/cursors" "$out/cursors" "$base"
	inh=$(sed -n 's/^Inherits[[:space:]]*=[[:space:]]*//p' "$bdir/index.theme" | head -n1)
	inh=$(tr ',' '\n' <<<"$base,$inh,Adwaita,hicolor" | awk 'NF && !seen[$0]++' | paste -sd, -)
	cat >"$out/index.theme" <<EOF
[Icon Theme]
Name=$base (Debian)
Comment=Raspberry Pi OS $base icons and cursors with Debian compatibility names
Inherits=$inh
Example=folder
Directories=
EOF
}

# ---------------------------------------------------------------------------
# Generated package: pixflat-theme-debian
# ---------------------------------------------------------------------------

# Print the wallpaper file to use, or nothing.
_wallpaper_path() {
	local w=${O_WALLPAPER:-}
	if [[ -z $w ]]; then (( O_WITH_WALLPAPER )) || return 0; w=$T_WALL_DEFAULT; fi
	if [[ $w != */* ]]; then
		[[ $w == *.* ]] || w+=".jpg"
		w=/usr/share/rpd-wallpaper/$w
	fi
	printf '%s\n' "$w"
}

# Build pixflat-theme-debian from the installed official themes: Xfwm4 themes,
# icon overlays and, with --lightdm, the greeter settings. Prints its path.
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
	if (( O_LIGHTDM )); then
		local wall; wall=$(_wallpaper_path)
		mkdir -p "$stage/usr/share/lightdm/lightdm-gtk-greeter.conf.d"
		{
			printf '# Installed by %s: Raspberry Pi OS look for the LightDM GTK greeter\n[greeter]\n' "$APP_NAME"
			printf 'theme-name=%s\nicon-theme-name=%s-Debian\ncursor-theme-name=%s-Debian\ncursor-theme-size=%s\n' \
				"$T_GTK" "$T_ICON_BASE" "$T_ICON_BASE" "$T_CURSOR_SIZE"
			if [[ -n $T_FONT ]]; then printf 'font-name=%s\n' "$T_FONT"; fi
			if [[ -n $wall ]]; then printf 'background=%s\n' "$wall"; fi
		} >"$stage/usr/share/lightdm/lightdm-gtk-greeter.conf.d/60_$APP_NAME.conf"
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
 lack, and Xfwm4 themes generated from the official Openbox themes.
EOF
	{
		printf '#!/bin/sh\nset -e\nif [ "$1" = configure ] && command -v gtk-update-icon-cache >/dev/null; then\n'
		for f in "${icons[@]}"; do printf '\tgtk-update-icon-cache -q -t -f /usr/share/icons/%s || true\n' "$f"; done
		printf '\t:\nfi\n'
	} >"$stage/DEBIAN/postinst"
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
	for t in dpkg-deb gpgv base64 sha256sum awk sed gzip; do
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

# Decide what to install: FETCH_PKGS from verified .deb files and APT_PKGS by
# name from the APT sources. Installed packages are never upgraded.
resolve_all() {
	local p
	local -a wanted=("${T_THEME_PKGS[@]}") helpers
	(( O_WITH_FONT )) && wanted+=("$T_FONT_PKG")
	(( O_WITH_WALLPAPER )) && [[ $O_WALLPAPER != */* ]] && wanted+=("$T_WALL_PKG")
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
		if resolve_pkg "$p"; then
			FETCH_PKGS+=("$p")
		elif [[ $p == "$T_FONT_PKG" || $p == "$T_WALL_PKG" ]]; then
			warn "$p is not available for $H_SUITE; skipping it"
		else
			die "$p is not available for $H_SUITE/$H_ARCH"
		fi
	done

	# A Raspberry Pi package must never replace a package from the APT sources.
	for p in "${FETCH_PKGS[@]}"; do
		if [[ -n $(apt-cache madison "$p" 2>/dev/null) ]]; then
			die "refusing to install $p from Raspberry Pi OS: your APT sources provide a package with that name"
		fi
	done

	# Debian helpers: the GTK 2 pixmap engine, the icon theme the Pi icons
	# inherit, the monospace font, the sound theme and, for PiXflat icons,
	# libgtk2.0-bin.
	helpers=(gtk2-engines-pixbuf "$T_ICON_FALLBACK" "$(_mono_font_pkg "$H_SUITE")" sound-theme-freedesktop)
	[[ " ${T_THEME_PKGS[*]} " == *" pixflat-icons "* ]] && helpers+=(libgtk2.0-bin)
	(( O_QT )) && helpers+=(qt5-gtk-platformtheme qt6-gtk-platformtheme)
	APT_PKGS=()
	for p in "${helpers[@]}"; do
		[[ -n $(_installed_version "$p") ]] && continue
		if [[ -n $O_REPO ]] || apt_has "$p"; then APT_PKGS+=("$p"); fi
	done

	if [[ -n $O_REPO ]]; then
		# Offline: install every member of the selection's dependency closure that
		# the repository has and the system lacks; the rest is already installed.
		local -a roots=("${FETCH_PKGS[@]}" "${APT_PKGS[@]}")
		APT_PKGS=()
		while read -r p; do
			[[ -n ${PKG_VER[$p]:-} || -n $(_installed_version "$p") ]] && continue
			if resolve_pkg "$p"; then FETCH_PKGS+=("$p"); fi
		done < <(INSTALLED=1 _closure "$WORKDIR/index/local/$H_SUITE/Packages-$H_ARCH" "${roots[@]}")
		for p in "${roots[@]}"; do
			[[ -n ${PKG_VER[$p]:-} || -n $(_installed_version "$p") ]] || warn "$p is not in the offline repository; skipping it"
		done
	fi
	for p in "${FETCH_PKGS[@]}" "${APT_PKGS[@]}"; do IN_SET[$p]=1; done
	if (( O_LIGHTDM )) && [[ ! -x /usr/sbin/lightdm-gtk-greeter ]]; then
		warn "lightdm-gtk-greeter is not installed; the greeter configuration will be inactive"
	fi
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

# Record newly installed packages for --uninstall. Libraries and engines are
# marked automatic, so 'apt autoremove' removes them once unused.
_record_installed() {
	local p newly=() autos=()
	for p; do
		(( O_DRY_RUN )) || [[ -n $(_installed_version "$p") ]] || continue
		newly+=("$p")
		case $p in gtk2-engines-*|libgtk2.0-*|libgdk-pixbuf*|gnome-icon-theme|adwaita-icon-theme*|fonts-liberation*|sound-theme-*) autos+=("$p") ;; esac
	done
	(( ${#newly[@]} )) || return 0
	if (( ${#autos[@]} )); then as_root apt-mark auto "${autos[@]}" >/dev/null; fi
	as_root mkdir -p "$APP_SYS_STATE"
	(( O_DRY_RUN )) && return 0
	{ cat "$APP_SYS_STATE/installed-packages" 2>/dev/null || true; printf '%s\n' "${newly[@]}"; } \
		| sort -u | as_root tee "$APP_SYS_STATE/installed-packages.new" >/dev/null
	as_root mv -f "$APP_SYS_STATE/installed-packages.new" "$APP_SYS_STATE/installed-packages"
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

# Download, verify and install the packages, then build and install
# pixflat-theme-debian. APT never removes packages (--no-remove) and, offline,
# never downloads (--no-download).
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
			[[ -n $O_REPO ]] || f=$(compat_fix "$f")   # ./packages is adapted already
			files+=("$f")
		fi
	done
	(( O_DRY_RUN )) || _add_theme_engines files
	for p in "${FETCH_PKGS[@]}" "${APT_PKGS[@]}"; do
		[[ -n $(_installed_version "$p") ]] || before+=("$p")
	done
	if [[ -n $O_REPO ]]; then
		opts+=(--no-download -o "Dir::Cache::archives=$WORKDIR/archives/")
		_prime_apt_cache "${files[@]}"
	fi

	step "Installing packages"
	if (( ${#files[@]} + ${#APT_PKGS[@]} )); then
		if (( ! O_DRY_RUN )) && ! sim=$(LC_ALL=C apt-get install --simulate "${opts[@]}" "${files[@]}" "${APT_PKGS[@]}" 2>&1); then
			tail -n 15 <<<"$sim" >&2
			[[ -n $O_REPO ]] && warn "offline mode can only use packages that are installed or in ./packages"
			die "APT cannot install the packages on this system (see above)"
		fi
		as_root env DEBIAN_FRONTEND=noninteractive apt-get install "${opts[@]}" "${files[@]}" "${APT_PKGS[@]}"
	fi
	if (( O_DRY_RUN )); then ok "Raspberry Pi OS packages installed"; else _verify_installed; fi

	step "Building the Debian compatibility package ($APP_PKG)"
	if (( O_DRY_RUN )); then
		log "   [dry-run] generate cursor aliases and Xfwm4 themes; install $APP_PKG"
	else
		f=$(build_local_pkg)
		as_root env DEBIAN_FRONTEND=noninteractive apt-get install "${opts[@]}" "$f" >/dev/null
		ok "Installed $(basename "$f")"
	fi
	_record_installed "${before[@]}"
}

# ---------------------------------------------------------------------------
# Offline repository builder (install-offline.sh --update-packages)
# ---------------------------------------------------------------------------
# Print the component type of a package, also its folder in ./packages.
_pkg_category() {
	case $1 in
		sound-theme-*)               echo sounds ;;
		*icon-theme*|*-icons)        echo icons ;;
		*-theme)                     echo themes ;;
		fonts-*)                     echo fonts ;;
		gtk2-engines-*|libgtk2.0-*|libgdk-pixbuf*) echo engines ;;   # GTK 2 engines and runtime
		*wallpaper*)                 echo wallpapers ;;
		*)                           echo other ;;
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
	rpi=$(_bundle_rpi_pkgs trixie | paste -sd' ' -)
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

# Write the names and Provides of a Packages index, one per line.
_index_names() {
	awk '/^Package: / { print $2 }
		/^Provides: / {
			sub(/^Provides: /, ""); n = split($0, a, ",")
			for (i = 1; i <= n; i++) { x = a[i]; sub(/^[ \t]+/, "", x); sub(/[ \t(].*/, "", x); print x }
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

# Build ./packages (install-offline.sh --update-packages): for every release
# and architecture, the Raspberry Pi OS packages plus the Debian packages they
# need that a standard Debian desktop lacks. The result replaces ./packages
# only when complete.
build_offline_repo() {
	local dest=$O_REPO stage suite arch p f e idx deb base gtk3 i n=0
	local -a rpis debs got roots
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
			PKG_VER=() PKG_FILE=() PKG_SHA=() PKG_SIZE=() PKG_SUITE=() PKG_AID=() IN_SET=()
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
				f=$(compat_fix "$f")
				got+=("$f")
				_stage_pkg "$stage" "$idx" "$p" "$f"
				ok "$p ${PKG_VER[$p]} (Raspberry Pi OS ${PKG_SUITE[$p]})"
				for e in $(_engine_pkgs "$f"); do
					[[ -n ${IN_SET[$e]:-} ]] && continue
					IN_SET[$e]=1
					if _is_rpi_engine "$e"; then rpis+=("$e"); else debs+=("$e"); fi
				done
			done
			# Debian packages: the dependency closure of everything bundled, minus
			# what every Debian desktop has (base system plus the GTK 3 runtime)
			gtk3=libgtk-3-0t64
			[[ $suite == bookworm ]] && gtk3=libgtk-3-0
			base=$deb.base
			BASE=priority _closure "$deb" "$gtk3" librsvg2-common hicolor-icon-theme >"$base"
			mapfile -t roots < <(_deb_depnames "${got[@]}")
			mapfile -t debs < <(_closure "$deb" "${debs[@]}" "${roots[@]}" | grep -vxF -f "$base" \
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

# Set the theme, fonts and title layout in the <theme> section of an Openbox or
# labwc rc.xml. Openbox knows only Normal and Bold weights. labwc applies a
# <font> without place= everywhere, so one is added if none exists.
# Usage: _rc_theme FILE THEME [TITLE-LAYOUT]
_rc_theme() {
	local file=$1 theme=$2 layout=${3:-} weight=$T_FONT_WEIGHT add_font=0
	if [[ $file == */openbox/* ]]; then [[ $weight == Bold ]] || weight=Normal; else add_font=1; fi
	if (( O_DRY_RUN )); then log "   [dry-run] $file: theme=$theme font='${T_FONT_FAMILY:-unchanged}'"; return 0; fi
	_track_file "$file"
	if ! grep -q '<theme>' "$file"; then
		sed -i "s#</\(labwc\|openbox\)_config>#  <theme>\n    <name>$theme</name>\n  </theme>\n&#" "$file"
	fi
	TH=$theme FA=$T_FONT_FAMILY WE=$weight LA=$layout AF=$add_font awk '
		BEGIN { th = ENVIRON["TH"]; fa = ENVIRON["FA"]; we = ENVIRON["WE"]; la = ENVIRON["LA"] }
		/<theme>/ { in_t = 1 }
		in_t && /<font[ >]/ { in_f = 1; fonts = 1 }
		in_t && !in_f && !named && /<name>.*<\/name>/ { sub(/<name>.*<\/name>/, "<name>" th "</name>"); named = 1 }
		in_t && in_f && fa != "" && /<name>.*<\/name>/ { sub(/<name>.*<\/name>/, "<name>" fa "</name>") }
		in_t && in_f && fa != "" && /<size>.*<\/size>/ { sub(/<size>.*<\/size>/, "<size>12</size>") }
		in_t && in_f && fa != "" && /<weight>.*<\/weight>/ { sub(/<weight>.*<\/weight>/, "<weight>" we "</weight>") }
		in_t && la != "" && /<titleLayout>.*<\/titleLayout>/ { sub(/<titleLayout>.*<\/titleLayout>/, "<titleLayout>" la "</titleLayout>") }
		in_f && /<\/font>/ { in_f = 0 }
		/<\/theme>/ {
			if (in_t && !named) { print "    <name>" th "</name>"; named = 1 }
			if (in_t && !fonts && fa != "" && ENVIRON["AF"] == 1)
				print "    <font><name>" fa "</name><size>12</size><weight>" we "</weight></font>"
			in_t = 0
		}
		{ print }' "$file" | _write "$file"
}

# Apply the Raspberry Pi OS panel layout (from rpd-x-core) and the Debian logo
# menu button to a Debian lxpanel profile. Plugins are kept. The panel uses the
# GTK theme's colours (background=0, usefontcolor=0), as in Raspberry Pi OS.
_lxpanel_set() {
	local file=$1
	if (( O_DRY_RUN )); then log "   [dry-run] $file: top, 36 px, menu button ${A_LOGO:-unchanged}"; return 0; fi
	_track_file "$file"
	KV=$'edge=top\nalign=left\nmargin=0\nwidthtype=percent\nwidth=100\nheight=36\niconsize=36\ntransparent=0\nbackground=0\nusefontcolor=0' \
	IMG=$A_LOGO awk '
		function key(line) { sub(/^[ \t]*/, "", line); sub(/[ \t]*=.*/, "", line); return line }
		BEGIN { n = split(ENVIRON["KV"], kv, "\n"); for (i = 1; i <= n; i++) { split(kv[i], p, "="); val[p[1]] = p[2]; ord[i] = p[1] } }
		/^Global[ \t]*\{/ { g = 1; ind = "    "; print; next }
		g && /^[ \t]*\}/ {
			for (i = 1; i <= n; i++) if (!(ord[i] in done)) print ind ord[i] "=" val[ord[i]]
			g = 0
		}
		g && /=/ {
			match($0, /^[ \t]*/); ind = substr($0, 1, RLENGTH); k = key($0)
			if (k in val) { print ind k "=" val[k]; done[k] = 1; next }
		}
		/^[ \t]*type[ \t]*=[ \t]*menu[ \t]*$/ { m = 1 }
		m && ENVIRON["IMG"] != "" && key($0) == "image" {
			match($0, /^[ \t]*/); print substr($0, 1, RLENGTH) "image=" ENVIRON["IMG"]; m = 0; next
		}
		{ print }' "$file" | _write "$file"
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
		f=$SYS_ROOT/usr/share/themes/$T_GTK/gtk-3.0/$f
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
	if [[ -n $T_FONT ]]; then
		gs_str "$s" font-name "$T_FONT"
		gs_str "$s" document-font-name "$T_FONT"
	fi
}

# Write the GTK 2, 3 and 4 settings files and the default X11 cursor.
apply_gtk_files() {
	local f=$HOME/.config/gtk-3.0/settings.ini
	_ini_set "$f" Settings gtk-theme-name "$T_GTK" gtk-icon-theme-name "$A_ICONS" \
		gtk-cursor-theme-name "$A_CURSOR" gtk-cursor-theme-size "$T_CURSOR_SIZE"
	if [[ -n $T_FONT ]]; then _ini_set "$f" Settings gtk-font-name "$T_FONT"; fi
	if [[ -n $A_SOUND ]]; then
		_ini_set "$f" Settings gtk-sound-theme-name "$A_SOUND" gtk-enable-event-sounds 1 gtk-enable-input-feedback-sounds 1
	fi
	f=$HOME/.config/gtk-4.0/settings.ini
	_ini_set "$f" Settings gtk-icon-theme-name "$A_ICONS" gtk-cursor-theme-name "$A_CURSOR" \
		gtk-cursor-theme-size "$T_CURSOR_SIZE"
	if [[ -n $T_FONT ]]; then _ini_set "$f" Settings gtk-font-name "$T_FONT"; fi
	f=$HOME/.gtkrc-2.0
	_kv_set "$f" gtk-theme-name "$T_GTK" '"'
	_kv_set "$f" gtk-icon-theme-name "$A_ICONS" '"'
	_kv_set "$f" gtk-cursor-theme-name "$A_CURSOR" '"'
	_kv_set "$f" gtk-cursor-theme-size "$T_CURSOR_SIZE"
	if [[ -n $T_FONT ]]; then _kv_set "$f" gtk-font-name "$T_FONT" '"'; fi
	# Default X11 cursor for applications that do not use XSETTINGS
	_ini_set "$HOME/.icons/default/index.theme" "Icon Theme" Inherits "$A_CURSOR"
	ok "GTK 2/3/4 configuration files updated"
}

# LXDE: lxsession, Openbox, PCManFM desktop and lxpanel.
apply_de_lxde() {
	local sess=LXDE rc f i
	[[ $S_DESKTOP_SESSION == LXDE* && $S_DESKTOP_SESSION =~ ^[A-Za-z0-9._-]+$ ]] && sess=$S_DESKTOP_SESSION
	f=$HOME/.config/lxsession/$sess/desktop.conf
	_seed "$f" "/etc/xdg/lxsession/$sess/desktop.conf" /etc/xdg/lxsession/LXDE/desktop.conf || true
	_ini_set "$f" GTK sNet/ThemeName "$T_GTK" sNet/IconThemeName "$A_ICONS" \
		sGtk/CursorThemeName "$A_CURSOR" iGtk/CursorThemeSize "$T_CURSOR_SIZE" sGtk/ColorScheme "$T_COLOR_SCHEME"
	if [[ -n $T_FONT ]]; then _ini_set "$f" GTK sGtk/FontName "$T_FONT"; fi
	if [[ -n $A_SOUND ]]; then
		_ini_set "$f" GTK sNet/SoundThemeName "$A_SOUND" iNet/EnableEventSounds 1 iNet/EnableInputFeedbackSounds 1
	fi

	rc=$HOME/.config/openbox/${sess,,}-rc.xml
	if _seed "$rc" "/etc/xdg/openbox/$sess/rc.xml" /etc/xdg/openbox/LXDE/rc.xml /etc/xdg/openbox/rc.xml; then
		_rc_theme "$rc" "$T_WM" LIMC
	else
		warn "no Openbox configuration found for $sess; window theme not set"
	fi

	local items=("$HOME/.config/pcmanfm/$sess/desktop-items-0.conf")
	for i in "$HOME/.config/pcmanfm/$sess"/desktop-items-*.conf; do
		if [[ -e $i && $i != "${items[0]}" ]]; then items+=("$i"); fi
	done
	for i in "${items[@]}"; do
		_seed "$i" "/etc/xdg/pcmanfm/$sess/$(basename "$i")" "/etc/xdg/pcmanfm/LXDE/$(basename "$i")" || true
		_ini_set "$i" '*' desktop_bg "$T_DESK_BG" desktop_fg "$T_DESK_FG" desktop_shadow "$T_DESK_SHADOW"
		if [[ -n $T_FONT ]]; then _ini_set "$i" '*' desktop_font "$T_FONT"; fi
		if [[ -n $A_WALL ]]; then _ini_set "$i" '*' wallpaper_mode crop wallpaper "$A_WALL"; fi
	done
	if (( O_PANEL )); then
		f=$HOME/.config/lxpanel/$sess/panels/panel
		if _seed "$f" "/etc/xdg/lxpanel/$sess/panels/panel" /etc/xdg/lxpanel/LXDE/panels/panel; then
			_lxpanel_set "$f"
		else
			warn "no lxpanel configuration found; panel unchanged"
		fi
	fi
	if [[ -n ${DISPLAY:-} ]]; then
		if _running openbox; then run openbox --reconfigure || true; fi
		if [[ -n $A_WALL ]] && _running pcmanfm; then run pcmanfm --wallpaper-mode=crop --set-wallpaper="$A_WALL" || true; fi
		if (( O_PANEL )) && _running lxpanel; then run lxpanelctl restart || true; fi
	fi
	ok "LXDE configured (session '$sess')"
	A_NOTES+=("LXDE: log out and back in to load the new GTK theme, font and cursor.")
}

# LXQt: icons, cursor, Openbox and PCManFM-Qt wallpaper.
apply_de_lxqt() {
	_ini_set "$HOME/.config/lxqt/lxqt.conf" General icon_theme "$A_ICONS"
	_ini_set "$HOME/.config/lxqt/session.conf" Mouse cursor_theme "$A_CURSOR" cursor_size "$T_CURSOR_SIZE"
	local rc=$HOME/.config/openbox/lxqt-rc.xml
	if _seed "$rc" /etc/xdg/openbox/lxqt-rc.xml /usr/share/lxqt/openbox/rc.xml; then
		_rc_theme "$rc" "$T_WM" LIMC
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
	if [[ -n $T_FONT ]]; then xf_set xsettings /Gtk/FontName string "$T_FONT"; fi
	if [[ -n $A_SOUND ]]; then
		xf_set xsettings /Net/SoundThemeName string "$A_SOUND"
		xf_set xsettings /Net/EnableEventSounds bool true
		xf_set xsettings /Net/EnableInputFeedbackSounds bool true
	fi
	if [[ -f /usr/share/themes/$T_WM/xfwm4/themerc ]]; then
		xf_set xfwm4 /general/theme string "$T_WM"
	else
		warn "no Xfwm4 theme for $T_WM found; window borders unchanged"
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
	if (( O_PANEL )) && xfconf-query -c xfce4-panel -p /panels/panel-1/size >/dev/null 2>&1; then
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
		_rc_theme "$rc" "$T_WM" LIMC
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
			printf '<?xml version="1.0"?>\n<labwc_config>\n  <theme>\n    <name>%s</name>\n  </theme>\n</labwc_config>\n' "$T_WM" | _write "$rc"
		fi
	fi
	_rc_theme "$rc" "$T_WM"
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

# --check: list the installed Raspberry Pi OS packages (or those of -t THEME)
# with the newest compatible version, and the Debian helpers with their APT
# candidate. Changes nothing and needs no root rights.
do_check() {
	local p st cur cand n=0
	local -a pkgs=()
	preflight_tools
	[[ -z $O_REPO ]] || verify_repo
	pick_suite
	if [[ -n $O_THEME ]]; then
		set_theme "$O_THEME"
		pkgs=("${T_THEME_PKGS[@]}" "$T_FONT_PKG" "$T_WALL_PKG")
	else
		for p in $(_bundle_rpi_pkgs trixie); do
			if [[ -n $(_installed_version "$p") ]]; then pkgs+=("$p"); fi
		done
	fi
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
		fonts-liberation fonts-liberation2 sound-theme-freedesktop; do
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
		info "$n Raspberry Pi OS package(s) can be installed or updated: run $(_self_cmd)${O_THEME:+ -t $O_THEME}"
	else
		ok "The Raspberry Pi OS packages are up to date"
	fi
}

# ---------------------------------------------------------------------------
# Uninstall
# ---------------------------------------------------------------------------
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
	run_user_phase unapply_main
	local -a purge=()
	[[ -n $(_installed_version "$APP_PKG") ]] && purge+=("$APP_PKG")
	if (( ${#still[@]} )) && ask "Also remove the Raspberry Pi OS packages installed by this script" y; then
		purge+=("${still[@]}")
	fi
	if (( ${#purge[@]} )); then
		prepare_root
		as_root env DEBIAN_FRONTEND=noninteractive apt-get purge -y "${purge[@]}"
		as_root rm -rf -- "$APP_SYS_STATE"
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

# Ask which theme to install.
choose_theme() {
	local new_ok=1 ans def=1
	[[ -n $H_SUITE ]] && (( $(_suite_rank "$H_SUITE") < 3 )) && new_ok=0
	log ""
	log "  ${C_B}Select a theme${C_0}"
	log "   1) PiXflat   light · Raspberry Pi OS Bookworm"
	log "   2) PiXnoir   dark  · Raspberry Pi OS Bookworm"
	if (( new_ok )); then
		log "   3) PiXtrix   light · Raspberry Pi OS Trixie"
		log "   4) PiXonyx   dark  · Raspberry Pi OS Trixie"
	else
		log "   ${C_D}3) PiXtrix   light · Raspberry Pi OS Trixie   (needs Debian 13+)${C_0}"
		log "   ${C_D}4) PiXonyx   dark  · Raspberry Pi OS Trixie   (needs Debian 13+)${C_0}"
	fi
	log "   5) PiX       legacy · Raspberry Pi OS Buster/Bullseye"
	while :; do
		read -r -p "  Choice [$def]: " ans </dev/tty || ans=""
		case ${ans:-$def} in
			1) O_THEME=pixflat ;; 2) O_THEME=pixnoir ;; 5) O_THEME=pix ;;
			3) if (( new_ok )); then O_THEME=pixtrix; fi ;;
			4) if (( new_ok )); then O_THEME=pixonyx; fi ;;
		esac
		[[ -n $O_THEME ]] && break
		warn "please enter a number from the list"
	done
}

# Summarise what will be done.
print_plan() {
	local p total=0 wall src
	for p in "${FETCH_PKGS[@]}"; do total=$(( total + ${PKG_SIZE[$p]:-0} )); done
	wall=$(_wallpaper_path)
	step "Plan"
	log "  Theme        $T_DESC"
	log "  GTK / window $T_GTK / $T_WM (Openbox, labwc; Xfwm4 generated)"
	log "  Icons/cursor $T_ICON_BASE-Debian (official $T_ICON_BASE + cursor-name aliases)"
	log "  Font         ${T_FONT:-unchanged}"
	log "  Wallpaper    ${wall:-unchanged}"
	if (( O_DO_INSTALL )); then
		if [[ -n $O_REPO ]]; then src="the offline repository"; else src="$RPI_ARCHIVE"; fi
		log "  Packages     from $src ($H_SUITE, $H_ARCH), up to $(human_size "$total")"
		for p in "${FETCH_PKGS[@]}"; do _pkg_line "$p" "${PKG_VER[$p]}" "$(_pkg_status "$p")"; done
		for p in "${APT_PKGS[@]}"; do _pkg_line "$p" "(APT)" "new, from your Debian sources"; done
	fi
	if (( O_DO_APPLY )); then
		log "  User         ${S_USER:-none}"
		log "  Desktops     ${DESKTOPS[*]:-none detected (GTK configuration files only)}"
	fi
	local extras=()
	(( O_LIGHTDM )) && extras+=("LightDM greeter")
	(( O_QT )) && extras+=("Qt follows GTK")
	(( ${#extras[@]} )) && log "  Extras       ${extras[*]}"
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

# Entry point: parse options, then check, uninstall, rebuild ./packages, or
# install and apply a theme.
main() {
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
	case $O_ACTION in
		uninstall) do_uninstall; return 0 ;;
		check)     do_check; return 0 ;;
	esac

	detect_desktops
	if (( O_DO_INSTALL )); then
		preflight_tools
		[[ -z $O_REPO ]] || verify_repo
		pick_suite
	fi
	if [[ -z $O_THEME ]]; then
		if (( O_INTERACTIVE )); then choose_theme; else O_THEME=pixflat; fi
	fi
	if (( O_INTERACTIVE && O_DO_INSTALL && O_WITH_WALLPAPER && ! O_4K )) && [[ -z $O_WALLPAPER ]] \
		&& ask "Use the 4K wallpapers (about 100 MB instead of 26-45 MB)" n; then
		O_4K=1
	fi
	set_theme "$O_THEME"

	if (( O_DO_INSTALL )); then
		check_theme_supported
		if (( O_INTERACTIVE && ! O_LIGHTDM )) && [[ -x /usr/sbin/lightdm-gtk-greeter ]] \
			&& ask "Also theme the LightDM login screen" n; then
			O_LIGHTDM=1
		fi
		resolve_all
	fi

	print_plan
	ask "Proceed" y || die "aborted"

	if (( O_DO_INSTALL )); then
		prepare_root
		install_all
	fi
	if (( O_DO_APPLY )); then
		run_user_phase apply_main
	fi

	log ""
	ok "${C_B}Done.${C_0} $T_DESC is ready."
	if (( O_DO_INSTALL )) && [[ -z $O_REPO ]]; then info "Run this script again at any time to update to the latest packages."; fi
	info "To undo everything: $(_self_cmd) --uninstall"
}

# Run main unless this file is sourced (install-offline.sh sources it).
if [[ ${BASH_SOURCE[0]:-} == "$0" || -z ${BASH_SOURCE[0]:-} ]]; then
	main "$@"
fi
