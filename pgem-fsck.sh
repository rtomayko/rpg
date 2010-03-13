#!/bin/sh
set -e
. pgem-sh-setup

ARGV="$@"
USAGE '${PROGNAME}
Verify integrity of the package db and release index.'

checking () {
    printf "checking %-35s" "$* ..."
}

diagnose () {
    if problems=$(command "$@" 2>&1)
    then ok
    else fail "$problems"
    fi
}


ok () {
    printf " OK"
    if test "$*"
    then printf " (%s)" "$*"
    fi
    printf "\n"
}

fail () { printf " FAIL\n[%s]\n" "$*"; }

checking "recent index readability"
diagnose test -r "$PGEMINDEX/release-recent"

checking "index readability"
diagnose test -r "$PGEMINDEX/release"

checking "recent index joinability"
diagnose sort -c -b -k 1,1 "$PGEMINDEX/release-recent"

checking "index joinability"
diagnose sh -c "
    cut -f 1 -d ' ' < '$PGEMINDEX/release' |
    sort -c -b -k 1,1
    "

checking "recent index data"
if lines=$(wc -l "$PGEMINDEX/release-recent" | sed 's/[^0-9]//g') &&
   test "$lines" -gt 0
then ok "$lines packages"
else fail "${lines:-no} packages"
fi

checking "index data"
if lines=$(wc -l "$PGEMINDEX/release" | sed 's/[^0-9]//g') &&
   test "$lines" -gt 0
then ok "$lines package versions"
else fail "${lines:-no} packages"
fi
