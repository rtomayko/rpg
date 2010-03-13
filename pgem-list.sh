#!/bin/sh
set -e
usage="Usage: pgem-list [-x] [<glob>...]
List installed packages matching <glob>s or all packages with no <glob>s.

Options
  -x                    Include non-matching globs in output."
expr "$*" : '.*--help' >/dev/null &&
echo "$usage" && exit 2

. pgem-sh-setup

shownonmatch=false
test "$1" = '-x' && {
    shownonmatch=true
    shift
}

# With no <globs>, list everything.
[ "$*" ] || set -- '*'

# Switch into package database dir or bail out if it doesn't exist.
test -d "$PGEMDB" &&
cd "$PGEMDB" || exit 0

# Run over globs gives on the command line and locate matching
# installed packages.
for glob in "$@"
do
    matched=false
    for path in $(ls -1 $glob/active 2>/dev/null)
    do
        matched=true
        package=${path%/active}
        vers=$(readlink $path)
        printf "%-30s %s\n" $package $vers
    done

    # Write a line of output for the failed glob with `-x`.
    if $shownonmatch && ! $matched
    then printf "%-30s %s\n" "$glob" "-"
    fi
done |

# Don't show packages multiple times.
sort -u
