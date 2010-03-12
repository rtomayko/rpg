#!/bin/sh
#/ Usage: pgem-resolve [-n <max>] <name> <version>
#/ Write package versions matching the <version> spec.
set -e

. pgem-sh-setup

# Parse options.
max=100
while getopts 1n: opt
do
    case $opt in
    n)   max="$OPTARG";;
    1)   max=1;;
    ?)   echo "Usage: $(basename $0): [-n <max>] <name> <version>"
         exit 2;;
    esac
done

# Fast forward past option arguments.
shift $(($OPTIND - 1))

index="$PGEMDB/gemdb"
name="$1"
vers="${2:->=0}"
count=0

grep -e "^$name " < "$index" |
cut -d ' ' -f 2 |
while read v
do
    if pgem-version-test "$v" "$vers"
    then echo "$v"
         count=$(($count + 1))
         test $count -eq $max && break
    elif test $count -gt 0
    then break
    fi
done
