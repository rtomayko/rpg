#!/bin/sh
# The `rpg-solve` program finds the best version of packages
# 
# The input must be a valid `<package> <operator> <version>` package list.
#
# The input must be sorted.
set -e 
. rpg-sh-setup

ARGV="$@"
USAGE '${PROGNAME}
Reads a package list on stdin and outputs a concrete package list

Options
  -u               Write the best match for each package, instead of all
                   matching versions.
'

# Run ourself and then `sort | uniq` the output down to the best
# match if the `-u` option was given.
[ "$1" = '-u' ] && {
    shift
    "$0" "$@" |
    sort -u -b -k1,1
    exit
}

# Done parsing args.
[ "$*" ] && { helpthem; exit 2; }


current=
expression=
failed=0
failedpacks=

resolve () {
    if test -n "$current"
    then
        rpg-resolve -p "$current" "$expression" || {
            failed=$(( $failed + 1 ))
            echo "$current != *"
            notice "failed to resolve $current $expression"
        }
        current=
        expression=
     fi
     return 0
}

while read package op version
do
    if test "$current" != "$package"
    then
        resolve
        current="$package"
        expression="$op$version"
    else
        expression="$expression,$op$version"
    fi
done

resolve

notice "failed to resolve $failed package(s): $failedpacks"

:
