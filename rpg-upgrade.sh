#!/bin/sh
set -e
. rpg-sh-setup

ARGV="$@"
USAGE '${PROGNAME} [-u] [<package>...]
Upgrade packages to the latest available version. With no <package>, upgrade
all outdated packages.

Options
  -u               Sync the remote package index to be sure the latest version
                   is available.'

# Update the package index. Force the update right now with the `-u`
# arg; otherwise, maybe update it based on the configured stale time.
if test "$1" = '-u'
then  rpg-sync
      shift
else  rpg-sync -s
fi

# Have `rpg-list` generate a list of all installed package with parseable
# output. Grab only outdated packages and pass them all to `rpg-install`.
rpg-list -p "$@"             |
awk '/^o / { print $2, $4 }' |
xargs rpg-install
