#!/bin/sh
# TODO Documentation and cleanup
set -e
. rpg-sh-setup

[ "$*" ] || set -- '--help'; ARGV="$@"
USAGE '${PROGNAME} [-f] <package> [[-v] <version>] ...
       ${PROGNAME} [-f] <package>[/<version>]...
       ${PROGNAME} [-f] -s <name>
Install packages into rpg environment.

Options
  -f          Force package installation even if already installed
  -s <name>   Install from a session created with rpg-prepare'

session=session
packageinstallargs=
while getopts fs: opt
do case $opt in
   s)   session="$OPTARG";;
   f)   packageinstallargs=-f;;
   ?)   helpthem;;
   esac
done
shift $(( $OPTIND - 1 ))

RPGSESSION="$RPGDB"
sessiondir="$RPGSESSION/@$session"
packlist="$sessiondir/package-list"
solved="$sessiondir/solved"

if test -f "$sessiondir"
then numpacks=$(lc "$solved")
     heed "$numpacks package(s):
     $(cat "$solved")"
else trap "rm -rf '$sessiondir'" 0
     rpg-prepare -s "$session" "$@"
fi

cat "$solved" |
xargs -n 2 rpg-package-install $packageinstallargs

heed "installation complete"

true
