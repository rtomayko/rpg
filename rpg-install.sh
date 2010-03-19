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
force=false
while getopts fs: opt
do case $opt in
   s)   session="$OPTARG";;
   f)   force=true;;
   ?)   helpthem;;
   esac
done
shift $(( $OPTIND - 1 ))

RPGSESSION="$RPGDB"
sessiondir="$RPGSESSION/@$session"
packlist="$sessiondir/package-list"
delta="$sessiondir/delta"
solved="$sessiondir/solved"

if test "$session" = "session" -a -d "$sessiondir"
then notice "rm'ing crusty session dir: $sessiondir"
     rm -rf "$sessiondir"
fi

if $force
then packageinstallargs=-f
     installfrom="$solved"
else packageinstallargs=
     installfrom="$delta"
fi

test -d "$sessiondir" || {
    trap "rm -rf '$sessiondir'" 0
    rpg-prepare -s "$session" "$@"
}

numpacks=$(grep -c . <"$installfrom")
if $force
then heed "installing $numpacks packages (forced)"
else heed "installing $numpacks packages"
fi

<"$installfrom" xargs -n 2 rpg-package-install $packageinstallargs

heed "installation complete"

true
