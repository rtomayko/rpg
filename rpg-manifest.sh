#!/bin/sh
set -e
. rpg-sh-setup

[ "$*" ] || set -- --help; ARGV="$@"
USAGE '${PROGNAME} <package>...
Show files installed for packages.'

for package in "$@"
do
    packagedir="$RPGDB/$package/active"
    if test -d "$packagedir"
    then cat "$packagedir/manifest"
    else warn "package not installed: $package"
         exit 1
    fi
done
