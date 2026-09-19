#!/usr/bin/env bash
#
# pixflat-theme — the Raspberry Pi OS desktop look for Debian (offline installer)
#
# Installs the official Raspberry Pi OS desktop themes from the local package
# repository in ./packages, without network access. It accepts the same
# options as install.sh (see --help).
#
# To refresh ./packages from the official repositories, run on a machine with
# internet access:
#
#     ./install-offline.sh --update-packages
#
# The installation logic is shared with install.sh, which must be in the same
# directory.

set -Eeuo pipefail

dir=$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")
if [[ ! -f $dir/install.sh ]]; then
	echo "install-offline.sh: install.sh must be in the same directory" >&2
	exit 1
fi

# shellcheck source=install.sh
source "$dir/install.sh"
O_REPO=$dir/packages
main "$@"
