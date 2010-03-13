#!/bin/sh
#/ Usage: pgem-build <path>
#/ Build native extensions for a package, writing the paths to new
#/ libraries to stdout. Exits truthfully except when an extension fails to
#/ build.
set -e

. pgem-sh-setup

path="$(cd "$1" && pwd)"

test -d "$path/ext" ||
exit 0

find "$path/ext" -name "extconf.rb" |
while read file
do
    log build "$(basename $path) $(basename $(dirname $file))"
    cd $(dirname $file)
    if (ruby extconf.rb &&
        make clean &&
        make) 1> build.log 2>&1
    then
        $PGEMSHOWBUILD && cat build.log 1>&2
        find "$(pwd)" -name "*.$(ruby_dlext)"
    else
        cat build.log 1>&2
    fi
done
