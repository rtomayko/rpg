#!/bin/sh
set -e
. rpg-sh-setup

[ "$*" ] || set -- '--help'; ARGV="$@"
USAGE '${PROGNAME} [-u] <package>...
Upgrade packages to the latest available version.

Options
  -u               Sync the remote package index to be sure the
                   latest version is available.'

# Update the package index. Force the update right now with the `-u`
# arg; otherwise, maybe update it based on the configured stale time.
if test "$1" = '-u'
then  rpg-sync
      shift
else  rpg-sync -s
fi

# Let `rpg-package-index` do the heavy lifting. We get back a list of
# matching gems and their current versions.
rpg-package-index -x "$@" |
while read package vers
do
    if test "$vers" = "X"
    then warn "$package not installed"
    else
        if rpg-install "$package" ">$vers" 2>&1
        then notice "$package upgraded to ..."
        else notice "$package is up to date at $vers"
        fi
    fi
done
