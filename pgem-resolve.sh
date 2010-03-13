#!/bin/sh
set -e

usage="Usage: pgem-resolve [-n <max>] <package> <expression>...
Write available package versions matching version <expression>s."

. pgem-sh-setup

# Parse options.
max=100
while getopts 1n: opt
do
    case $opt in
    n)   max="$OPTARG";;
    1)   max=1;;
    ?)   echo "$usage"
         exit 2;;
    esac
done

# Fast forward past option arguments.
shift $(($OPTIND - 1))

name="$1"; shift
test "$*" || {
    echo "$usage"
    exit 2
}
index="$PGEMDB/gemdb"

versions=$(
    grep "^$name " < "$index"    |
    cut -d ' ' -f 2              |
    head -$max                   |
    pgem-version-test - "$@"
) || true

# exit with success if we found at least one version, failure otherwise.
if test -n "$versions"
then echo "$versions"
else exit 1
fi
