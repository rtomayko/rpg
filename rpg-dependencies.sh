#!/bin/sh
set -e
. rpg-sh-setup

test "$*" || set -- --help; ARGV="$@"
USAGE '${PROGNAME} [-r] [-t] [-p] <package> [<version>]
       ${PROGNAME} -a
Show package dependency information.

Options
  -a          Write dependency information for all installed packages
  -r          List dependencies recursively
  -t          List dependencies recursively in a tree
  -p          Include <package> name in output (default with -a)'

showall=false;recursive=false;tree=false;prefix=false
while getopts arpt opt
do
    case $opt in
    a) showall=true;;
    r) recursive=true;;
    p) prefix=true;;
    t) tree=true;;
    ?) helpthem
       exit 2;;
    esac
done
shift $(( $OPTIND - 1 ))

# With the `-a` argument, write all dependencies for all packages in the
# following format:
#
#     <source> <package> <verspec> <version>
#
# Where `<source>` is the name of the package that has a dependency
# on `<package>`. The `<verspec>` may be any valid version expression:
# `<`, `<=`, `=`, `>=`, `>`, or `~>`.
$showall && {
    test "$*" && { helpthem; exit 2; }
    grep '^runtime ' "$RPGDB"/*/active/dependencies 2>/dev/null |
    sed -e 's|^.*/\(.*\)/active/dependencies:runtime |\1 |'
    exit 0
}

# Find the package and write its dependencies in this format:
#
#     <package> <verspec> <version>
#
# Exit with failure if the package or package version is not found in the
# database.
package="$1"
version="${2:-active}"
packagedir="$RPGDB/$package"

test -d "$packagedir" || {
    warn "package not found: $package"
    exit 1
}

test -d "$packagedir/$version" || {
    warn "package version not found: $package $version"
    exit 1
}

sed -n 's|^runtime ||p' <"$packagedir/$version/dependencies" |
if $tree
then
    while read pack spec vers
    do
        echo "$pack $spec $vers"
        "$0" -r -t $pack |sed '
            s/^/|-- /
            s/-- |/   |/
        '
    done
else
    if $recursive
    then recurse="$0 -r"
         $prefix && recurse="$recurse -p"
    else recurse="true"
    fi

    while read pack spec vers
    do
        output="$pack $spec $vers"
        $prefix && output="$package $output"
        echo "$output"
        $recurse "$pack"
    done |
    sort -u
fi
