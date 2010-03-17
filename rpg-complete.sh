#!/bin/sh
set -e
. rpg-sh-setup

ARGV="$@"
USAGE '${PROGNAME} <type> <prefix>
Command line completion for rpg.

The <type> must be one of:
   commands   List rpg commands matching <prefix>
   available  List available packages matching <prefix>
   installed  List installed packages matching <prefix>'

commands () {
    for p in "$libexecdir"/rpg-$1*
    do  test -x "$p" && echo ${p##*/rpg-}
    done
}

installed () {
    rpg-package-index $1\* | cut -d ' ' -f 1
}

available () {
    grep -e "^$1[^ ]* " < "$RPGINDEX/release-recent" |
    cut -d ' ' -f 1 |
    head -1000
}

versions () {
    grep -e "^$1 " < "$RPGINDEX/release" |
    cut -d ' ' -f 2
}

"$@"
