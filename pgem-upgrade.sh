#!/bin/sh
set -e
. pgem-sh-setup

[ "$*" ] || set -- '--help'; ARGV="$@"
USAGE '${PROGNAME} [-u] <package>...
Upgrade packages to the latest available version.

Options
  -u               Update the remote package index to be sure the
                   latest version is available.'

# Update the package index. Force the update right now with the `-u`
# arg; otherwise, maybe update it based on the configured stale time.
if test "$1" = '-u'
then  pgem-update
      shift
else  pgem-update -s
fi

# Let pgem-list do the heavy lifting. We get back a list of matching
# gems and their current versions.
pgem list -x "$@" |
while read package vers
do
    if test "$vers" = "X"
    then warn "$package not installed"
    else
        if pgem-install "$package" ">$vers" 2>&1
        then notice "$package upgraded to ..."
        else notice "$package is up to date at $vers"
        fi
    fi
done
