#!/bin/sh
#/ Usage: pgem-deps [-d|-r] <gem>
#/ List dependencies for a specific <gem> by name or gem file.
#/
#/ Options:
#/   -d, --development       List development dependencies
#/   -r, --runtime           List runtime dependencies
#/
#/ Only runtime dependencies are listed by default. If the --development
#/ option is given, only development dependencies are listed, unless the
#/ --runtime option is also given.

# NOTE: This is very similar to `gem dependency --pipe` but takes a
# filename or specific gem name instead of a search pattern.

pattern=

while test $# -gt 0
do
    case "$1" in
        --dev*|-d)
            pattern="$pattern -e \.add_development"
            shift
            ;;
        --run*|-r)
            pattern="$pattern -e \.add_runtime"
            shift
            ;;
        --help)
            cat "$0" | grep '^#/' | cut -c4-
            exit
            ;;
        *)
            break
            ;;
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
