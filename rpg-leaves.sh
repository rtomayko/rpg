#!/bin/sh
set -e
. rpg-sh-setup

ARGV="$@"
USAGE '${PROGNAME}
List installed packages that no other package depends on.'

: ${TMPDIR:=/tmp}

index=$(mktemp -t $PROGNAME)
trap "rm -f $index" 0

rpg-package-index   |
cut -d ' ' -f 1     |
sort > "$index"

rpg-dependencies -a |
cut -d ' ' -f 2     |
sort                |
comm -31 - "$index"
