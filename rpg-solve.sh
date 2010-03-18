#!/bin/sh
# The `rpg-solve` program finds the best version of packages
#
# The input must be a valid `<package> <operator> <version>` package list.
#
# The input must be sorted.
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

# Run ourself and then `sort | uniq` the output down to the best
# match if the `-u` option was given.
maxvers=
[ "$1" = '-u' ] && {
    shift
    maxvers='-n 1'
}

# Add the main release index at the end of the list of indexes to resolve
# against. We always fall back to release index currently. It might be nice
# to provide an option that disables this.
set -- "$@" "$RPGINDEX/release"

current=
expression=
failed=0
failedpacks=

resolve () {
    if test -n "$current"
    then
        found=false
        for index in "$@"
        do
           if rpg-resolve -f "$index" -p $maxvers "$current" "$expression"
           then found=true
                break
           else continue
           fi
        done

        if ! $found
        then failed=$(( $failed + 1 ))
             failedpacks="$failedpacks, $current"
             echo "$current -"
             notice "failed to resolve $current $expression"
        fi
        current=
        expression=
    fi
    return 0
}

while read package op version
do
    if test "$current" != "$package"
    then resolve "$@"
         current="$package"
         expression="$op$version"
    else expression="$expression,$op$version"
    fi
done

resolve "$@"

test $failed -gt 0 &&
notice "failed to resolve $failed package(s): ${failedpacks#,}"

:
