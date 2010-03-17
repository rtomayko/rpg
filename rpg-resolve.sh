#!/bin/sh
set -e
. rpg-sh-setup

[ "$*" ] || set -- "--help"; ARGV="$@"
USAGE '${PROGNAME} [-f <file>] [-n <max>] [-p] <package> <expression>...
Write available package versions matching version <expression>s.

Options
  -f <file>        Package index to resolve versions against; the main
                   release index is used when not specified.
  -n <max>         Write no more than <max> versions.
  -p               Include package name in output.'

max=100
packagelist=false
while getopts p1f:n: opt
do case $opt in
   f)   index="$OPTARG";;
   n)   max="$OPTARG";;
   1)   max=1;;
   p)   packagelist=true;;
   ?)   helpthem;;
   esac
done
shift $(( $OPTIND - 1 ))

package="$1"; shift
[ "$*" ] || helpthem

# Use the default release index with no `-f` option, and sync it if it
# doesn't exist. If we were given an explicit index file, exit with failure
# if it doesn't exist.
if test -z "$index"
then index="$RPGINDEX/release"
     test -f "$index" || rpg-sync -s
else test -f "$index"
fi

versions=$(
    grep "^$package " < "$index"    |
    cut -d ' ' -f 2                 |
    rpg-version-test - "$@"         |
    head -$max
) || true

# Exit with success if we found at least one version, failure otherwise.
if test -n "$versions"
then notice "hit $package $* in ${index##*/}"
     if $packagelist
     then echo "$versions" | sed "s/^/$package /"
     else echo "$versions"
     fi
else notice "miss $package $* in ${index##*/}"
     exit 1
fi
