#!/bin/sh
set -e
. rpg-sh-setup

ARGV="$@"
USAGE '${PROGNAME} [-u] [<index>]...
Reads a package list on standard input and resolves to a list of concrete
versions using the <index>(es) specified. Multiple <index> arguments are
allowed. The main release index is used by default.

Options
  -u               Write only the best match for each package instead
                   of all matching versions.'

filter=cat
[ "$1" = '-u' ] && {
    shift
    filter='sort -u -k 1,1'
}

# Add the main release index at the end of the list of indexes to resolve
# against. We always fall back to release index currently. It might be nice
# to provide an option that disables this.
set -- "$@" "$RPGINDEX/release"

rpg-solve-fast "$@" | $filter

:
