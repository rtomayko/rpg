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
solved="$sessiondir/solved"
existing="$sessiondir/existing"
delta="$sessiondir/delta"

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
rpg-package-list "$@" |
sort -b -u            |
sed "s/^/@user /"     > "$packlist"

# Create the pre-existing package index. This is a simple list of all packages
# currently installed in the standard `<package> <version>` package index
# format. We try to resolve packages and dependencies against this list before
# the main release index.
notice "writing pre-existing package index"
rpg-package-index > "$existing"

# Create the existing dependencies package list from all dependencies of
# all existing installed packages but exclude dependencies of packages specified
# in master package list for this session.
notice "gathering existing dependencies"
alldeps=$(rpg-dependencies -a)

# Grab some stats and let 'em know we're about to begin.
numpacks=$(<"$packlist" sort -u -k2,2 |grep -c .)
if test $numpacks -eq 1
then packname=$(head -1 "$packlist" |cut -d ' ' -f 2)
     heed "calculating dependencies for $packname ..."
else heed "calculating dependencies for $numpacks package(s) ..."
fi

# Dependency Solving
# ------------------
#
# Dependency solving and conflict resolution works in multiple passes
# over the master package list. On each iteration, concrete package versions
# are resolved from the version requirements in the package list. Each resolved
# packages's dependency rules are then added to the master package list. If no
# rules are added to the master package list in an iteration then the solving is
# complete.

: >"$solved"
changed=true
runcount=0
while $changed
do
    runcount=$(( runcount + 1 ))
    notice "this is depsolve run #$runcount"

    # Prune packages we're installing now from the existing dependencies list.
    # Since these packages are being installed, we don't want the already
    # installed package versions's dependencies to come into play during
    # solving. The `-v` option `join(1)` causes only lines from our existing
    # dependencies list that cannot be paired with the master package list to be
    # included in the output.
    alldeps=$(
        echo "$alldeps" |sort                 |
        join -1 1 -2 2 -v 1                   \
             -o 1.1,1.2,1.3,1.4               \
             - "$packlist"                    |
        sort -b -k2,4
    )

    # Now take all dependencies for all existing packages that *aren't* being
    # installed here and add them to the master package list, retaining the
    # proper sort order.
    echo "$alldeps"                          |
    join -1 2 -2 2 -o 1.1,1.2,1.3,1.4        \
         - "$packlist"                       |
    sort -mbu -k 2,4 -k 1,1 "$packlist" -    >"$packlist+"

    # Solve all packages in the master package list and write the resulting
    # package index to the newly solved file (`solved+`). The solved file is
    # a sorted package index in `<name> <version>` format.
    cut -d ' ' -f 2- "$packlist+"            |
    uniq                                     |
    rpg-solve -u "$solved" "$existing"       >"$solved+"

    # Use `comm(1)` to select only those lines in the newly solved file that
    # were not present on the previous iteration, exclude packages that could
    # not be solved to a concrete version, and pass the remaining
    # package/version combos into `rpg-package-register` to fetch and enter
    # the package into the database. Using `xargs -P 8` allows as many as eight
    # concurrent fetch/register operations to run in parallel.
    comm -13 "$solved" "$solved+"            |
    grep -v ' -$'                            |
    xargs -P 8 -n 2 rpg-package-register     >/dev/null

    # Rebuild the master package list by concatenating the original user-
    # specified packages with all dependencies of all packages solved so far.
    # Make sure the newly built package list is sorted by the package name --
    # the `uniq` in the `rpg-solve` pipeline above relies on this.
    {
        grep '^@user' "$packlist"
        grep -v ' -$' "$solved+"             |
        xargs -P 4 -n 2 rpg-dependencies -p
    }  |sort -b -k 2,4                       >"$packlist+"

    # Check whether the package list has changed at all. If so, new rules were
    # added to the package list by dependencies. If not, we're done and can
    # leave the dep solve loop.
    if cmp -s "$packlist" "$packlist+"
    then changed=false
         notice "package list did not change"
    else changed=true
         notice "package list changed"
    fi

    mv "$packlist+" "$packlist"
    mv "$solved+" "$solved"
done

# Build a package list with only solved packages that are not already installed.
# This is our package install manifest and includes only packages that aren't
# already installed.
comm -13 "$existing" "$solved" >"$delta"

# Figure out how many packages were involved and how many packages need to be
# installed.
totalpacks=$(grep -c . <"$solved")
deltapacks=$(grep -c . <"$delta") || {
    heed "$totalpacks packages already installed and up to date."
    exit 0
}

# Calculate the total number of packages that are already installed.
freshpacks=$(( totalpacks - deltapacks ))
heed "$freshpacks of $totalpacks packages already installed up to date"

# Check for unsolved packages in our solved list. Unsolved packages have
# a dash "-" in their version field.
if badpacks=$(grep ' -$' "$delta")
then heed "$(echo "$badpacks" |grep -c .) packages failed to resolve:
$badpacks"
fi

# Note the number of packages that are now queued up for installation.
goodpacks=$(grep -v ' -$' "$delta")
heed "$(echo "$goodpacks" |grep -c .) packages ready for installation:
$goodpacks"
