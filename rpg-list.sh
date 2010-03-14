#!/bin/sh
# The `rpg-list` program walks over the installed package database and
# writes a line with the `<package> <version>` to `stdout` for each installed
# package.
set -e
. rpg-sh-setup

ARGV="$@"
USAGE '${PROGNAME} [-x] [<glob>...]
List rpg installed packages.

Options
  -x               Include non-matching globs in output.

Only list packages matching <glob> when provided. With multiple <glob>s,
list packages matching any one of them.'

shownonmatch=false
test "$1" = '-x' && {
    shownonmatch=true
    shift
}

# With no `<globs>`, list everything.
[ "$*" ] || set -- '*'

# Switch into package database dir or bail out if it doesn't exist.
test -d "$RPGDB" &&
cd "$RPGDB" || exit 0

# Run over globs gives on the command line and locate matching
# installed packages. By default, nothing is written for glob patterns
# that don't match an installed package. The `-x` option changes this
# behavior so that a single line is output with the package version '-'.
for glob in "$@"
do
    matched=false
    for path in $(ls -1d $glob/active 2>/dev/null)
    do
        matched=true
        package=${path%/active}
        vers=$(readlink $path)
        printf "%-30s %s\n" $package $vers
    done

    if $shownonmatch && ! $matched
    then printf "%-30s %s\n" "$glob" "-"
    fi
done |

# It's possible for multiple globs to match the same package. Run the
# stream text through `sort -u` to sort the list and prevent dupes from
# showing up.
sort -u
