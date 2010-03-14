#!/bin/sh
set -e
. rpg-sh-setup

[ "$*" ] || set -- "--help"; ARGV="$@"
USAGE '${PROGNAME} [-n <max>] [-p] <package> <expression>...
Write available package versions matching version <expression>s.

Options
  -n <max>         Write no more than <max> versions
  -p               Write output in rpg package list format'


max=100
packagelist=false
while getopts p1n: opt
do case $opt in
   n)   max="$OPTARG";;
   1)   max=1;;
   p)   packagelist=true;;
   ?)   helpthem;;
   esac
done
shift $(( $OPTIND - 1 ))

package="$1"; shift
[ "$*" ] || helpthem

index="$RPGINDEX/release"
test -f "$index" || rpg-update -s

versions=$(
    grep "^$package " < "$index"    |
    cut -d ' ' -f 2                 |
    rpg-version-test - "$@"         |
    head -$max
) || true

# Exit with success if we found at least one version, failure otherwise.
if test -n "$versions"
then if $packagelist
     then echo "$versions" | sed "s/^/$package = /"
     else echo "$versions"
     fi
else notice "$package did not match: $*"
     exit 1
fi
