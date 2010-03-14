#!/bin/sh
set -e
. pgem-sh-setup

ARGV="$@"
USAGE '${PROGNAME} [-u] [<glob>...]
List packages that can be upgraded.

Options
  -u               Sync the available package index before running.'

# pgem-status implements -u so just pass everything right on over.
pgem-status -p "$@" |
grep '^o'           |
while read _ package curvers newvers
do
    echo "$package $curvers -> $newvers"
done
