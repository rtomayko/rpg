#!/bin/sh
set -e
. pgem-sh-setup

ARGV="$@"
USAGE '${PROGNAME} [-x] [<glob>...]
List pgem installed packages.

Options
  -x               Include non-matching globs in output.

Only list packages matching <glob> when provided. With multiple <glob>s,
list packages matching any one of them.'

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
