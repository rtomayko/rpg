#!/bin/sh
set -e
usage="Usage: pgem-list [<glob>...]
List installed packages matching <glob>s or all packages with no <glob>s."
expr "$*" : '.*--help' >/dev/null &&
echo "$usage" && exit 2

. pgem-sh-setup

# With no <globs>, list everything.
[ "$*" ] || set -- '*'

# Run over globs gives on the command line and locate matching
# installed packages.
for glob in "$@"
do
    ls -1 "$PGEMDB"/$glob/active 2>/dev/null |
    while read path
    do
        name=$(basename $(dirname $path))
        vers=$(readlink $path)
        echo "$name $vers"
    done
done |

# Don't show packages multiple times.
sort -u
