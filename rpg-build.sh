#!/bin/sh
set -e
. rpg-sh-setup

[ "$*" ] || set -- '--help'
ARGV="$@"
USAGE '${PROGNAME} <path>
Build native extensions for a package.

The paths to newly built libraries are written on standard output. Exits with
success if the build succeeds, failure otherwise.'

path="$(cd "$1" && pwd)"

test -d "$path/ext" ||
exit 0

find "$path/ext" -name "extconf.rb" |
while read file
do
    heed "$(basename $path) $(basename $(dirname $file))"
    cd $(dirname $file)
    if (ruby extconf.rb &&
        { make clean || true; } &&
        make) 1> build.log 2>&1
    then
        $RPGSHOWBUILD && cat build.log 1>&2
        find "$(pwd)" -name "*.$(ruby_dlext)"
    else
        cat build.log 1>&2
    fi
done
