#!/bin/sh
set -e
. rpg-sh-setup

[ "$*" ] || set -- "--help"; ARGV="$@"
USAGE '${PROGNAME} [-d] [-r] <package>
List dependencies for a package or gem file.

Options:
  -d               List development dependencies
  -r               List runtime dependencies

Only runtime dependencies are listed by default. If the -d option is given,
only development dependencies are listed, unless the -r option is also
given.'

# This is very similar to `gem dependency --pipe` but takes a filename or
# specific gem name instead of a search pattern.

pattern=

while test $# -gt 0
do
    case "$1" in
    --dev*|-d)  pattern="$pattern -e \.add_development"
                shift;;
    --run*|-r)  pattern="$pattern -e \.add_runtime"
                shift;;
            *)  break;;
    esac
done

: ${pattern:=-e \.add_runtime}

gem spec --ruby "$@"                                       |
grep -e 'add_\(runtime\|development\)_dependency'          |
grep $pattern                                              |
sed '
    s/^.*(%q<\([A-Za-z0-9_-]\{1,\}\)>, \["\(.*\)"\])/\1::\2/
    s/", "/, /
    s/ //
    s/::/ /
    '
