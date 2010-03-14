#!/bin/sh
set -e
. pgem-sh-setup

[ "$*" ] || set -- "--help"; ARGV="$@"
USAGE '${PROGNAME} [-n <max>] <package> <expression>...
Write available package versions matching version <expression>s.'

max=100
while getopts 1n: opt
do case $opt in
   n)   max="$OPTARG";;
   1)   max=1;;
   ?)   helpthem;;
   esac
done
shift $(( $OPTIND - 1 ))

package="$1"; shift
[ "$*" ] || helpthem

index="$PGEMINDEX/release"
pgem-update -s

versions=$(
    grep "^$package " < "$index"    |
    cut -d ' ' -f 2                 |
    pgem-version-test - "$@"        |
    head -$max
) || true

# Exit with success if we found at least one version, failure otherwise.
if test -n "$versions"
then echo "$versions"
else exit 1
fi
