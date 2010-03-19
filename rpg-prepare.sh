#!/bin/sh
# TODO Documentation and cleanup
set -e
. rpg-sh-setup

[ "$*" ] || set -- '--help'; ARGV="$@"
USAGE '${PROGNAME} [-s <name>] <package> [[-v] <version>] ...
       ${PROGNAME} [-s <name>] <package>[/<version>]...
Prepare packages to be installed into an rpg environment later.

Options
  -s <name>   Give this prepared installation a name'

# TODO add rpg-prepare -e for editing an existing package list
session=session
while getopts s: opt
do case $opt in
   s)   session="$OPTARG";;
   ?)   helpthem;;
   esac
done
shift $(( $OPTIND - 1 ))

# Session Prep
# ------------
#
# We create a directory to hold files for this install session. Installing
# requires building multiple package lists and indexes from the set of installed
# and available packages and their dependencies and then taking a few passes
# through the dependency solver.

# See if we need to sync the index before doing anything.
rpg-sync -s

# Session directories are stored under `RPGDB` prefixed with an "@" for now. This
# should probably be moved to its own top-level directory.
RPGSESSION="$RPGDB"
sessiondir="$RPGSESSION/@$session"
packlist="$sessiondir/package-list"

# Get rid of any crusty session directory and then create a new one. It might be
# cool to add an `-e` option so that sessions could be edited to add or
# remove packages.
rm -rf "$sessiondir"
mkdir -p "$sessiondir"

# Store argv in a file so we can recalculate this session from the beginning.
notice "writing session argv"
for arg in "$@"
do echo "$arg"
done > "$sessiondir/argv"

# Create the master package list from the packages specified on the command
# line. Each line in the file has the format:
#
#     @user <package> <verspec> <version>
#
# As we go through the dep solve loop below, we'll add packages to this file
# for each dependency of each package we're installing (recursively). Lines
# corresponding to a dependency have the depending package name in the first
# field instead of `@user`.
notice "writing user package-list"
rpg-package-list "$@"        |
sort -u                      |
sed "s/^/@user /"            > "$packlist"

# Create the pre-existing package index. This is a simple list of all packages
# currently installed in the standard `<package> <version>` package index
# format. We try to resolve packages and dependencies against this list before
# the main release index.
notice "writing pre-existing package index"
rpg-package-index > "$sessiondir/pre-existing"

# Dependency Resolution
# ---------------------

# Tell the user we're about to begin.
numpacks=$(sed -n '$=' <"$packlist")
if test $numpacks -eq 1
then packname=$(head -1 "$packlist" |cut -d ' ' -f 2)
     heed "calculating dependencies for $packname ..."
else heed "calculating dependencies for $numpacks package(s) ..."
fi

cat </dev/null >"$sessiondir/solved"

changed=true
runcount=0
while $changed
do
    runcount=$(( runcount + 1 ))
    notice "this is depsolve run #$runcount"
    cat </dev/null >"$packlist+" # truncate

    cut -d ' ' -f 2- "$packlist"                             |
    sort -b -u                                               |
    rpg-solve -u "$sessiondir/solved" \
                 "$sessiondir/pre-existing"                  |
    sort -b >"$sessiondir/solved+"
    mv "$sessiondir/solved+" "$sessiondir/solved"

    grep -v -- ' -$' <"$sessiondir/solved"                   |
    xargs -P 4 -n 2 rpg-fetch >/dev/null

    grep -v -- ' -$' <"$sessiondir/solved"                   |
    while read package version
    do
        notice "adding $package $version deps to packlist"
        gemfile=$(rpg-fetch "$package" "$version")
        packagedir=$(rpg-package-register "$gemfile")
        rpg-dependencies "$package" "$version"               |
        sed "s/^/$package /"
    done                                                     |
    cat "$packlist" -                                        |
    sort -u >> "$packlist+"

    if cmp -s "$packlist" "$packlist+"
    then notice "package list did not change"
         changed=false
    else notice "package list changed"
         changed=true
    fi
    mv "$packlist+" "$packlist"
done

# Check for unsolved packages in our solved list. Unsolved packages have
# a dash "-" in their version field.
if badpacks=$(grep '\-$' <"$sessiondir"/solved)
then heed "$(echo "$badpacks" |sed -n '$=') package(s) failed to resolve:
$badpacks"
fi

# Note the number of packages that are now queued up for installation.
goodpacks=$(grep -v -- '\-$' <"$sessiondir"/solved)
heed "$(echo "$goodpacks" |sed -n '$=') package(s) ready for installation:
$goodpacks"
