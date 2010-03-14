#!/bin/sh
set -e
. rpg-sh-setup

ARGV="$@"
USAGE '${PROGNAME} [-u] [<glob>...]
List packages that can be upgraded.

Options
  -u               Sync the available package index before running.'

# rpg-status implements -u so just pass everything right on over.
rpg-status -p "$@" |
grep '^o'           |
while read _ package curvers newvers
do
    echo "$package $curvers -> $newvers"
done
