#!/bin/sh
set -e
. rpg-sh-setup

[ "$*" ] || set -- --help; ARGV="$@"
USAGE '${PROGNAME} [-a] <package>...
Show files installed for packages.

Options
  -a          Show absolute paths to files instead of abbreviating.'

abbreviate () {
    sed "
        s|^$RPGLIB/|lib/|
        s|^$RPGBIN/|bin/|
        s|^$RPGMAN/|man/|
    "
}

if test "$1" = '-a'
then filter='cat'
     shift
else filter='abbreviate'
fi

for package in "$@"
do
    packagedir="$RPGDB/$package/active"
    if test -d "$packagedir"
    then $filter < "$packagedir/manifest"
    else die "package not installed: $package"
    fi
done
