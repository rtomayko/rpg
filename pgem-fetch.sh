#!/bin/sh
#/ Usage: pgem-fetch <name> [<version>]
#/ Fetch a gem to the cache and write the gems name and version.
#/ If a gem matching the name and version already exists, no network
#/ operations need be performed.
set -e

. pgem-sh-setup

name="$1"
vers="${2:->=0}"

mkdir -p "$PGEMCACHE"
cd "$PGEMCACHE"

if test -n "$vers"
then
    for havever in $(
        ls -1 $name-[0-9]*.gem 2>/dev/null |
        sed 's/^.*-\([0-9].*\)\.gem/\1/' |
        sort -rn)
    do
        if pgem version-test "$havever" "$vers"
        then
            log fetch "$name $vers [cached]"
            echo "$PGEMCACHE/$name-${havever}.gem"
            exit
        fi
    done
fi

log fetch "$name" "$vers"
output=$(gem fetch -v "$vers" "$name") ||
exit 1

output=${output#Downloaded }
test -n "$output" ||
exit 1

echo "$PGEMCACHE/$output.gem"
