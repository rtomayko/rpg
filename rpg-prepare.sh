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

RPGSESSION="$RPGDB"
sessiondir="$RPGSESSION/@$session"
packlist="$sessiondir"/package-list

# TODO add rpg-prepare -a for adding packages to an existing session.
rm -rf "$sessiondir"
mkdir -p "$sessiondir"

# see if we need to sync the index
rpg-sync -s

# Master Package List
# -------------------

notice "writing argv"
for arg in "$@"
do echo "$arg"
done > "$sessiondir"/argv

notice "writing user package-list"
rpg-package-list "$@"        |
sort -u                      |
sed "s/^/@user /"            > "$packlist"

# Installed Index and Existing Dependencies Package List
# ------------------------------------------------------

notice "creating installed packages index"
rpg-package-index > "$sessiondir"/installed-index

# TODO write package name in deps file so this can be a straight cat
notice "create existing dependencies package list"
for deps in "$RPGDB"/*/active/dependencies
do
    pack=$(basename ${deps%/active/dependencies})
    grep ^runtime < "$deps"                         |
    sed "s|^runtime|$pack|"
done                                                |
sort -u                                             |
join -11 -22 -v 1 -o 1.1,1.2,1.3,1.4 - "$packlist"  |
tee "$sessiondir/installed-deps"                    |
sort -k 2,4 > "$sessiondir/installed-deps-packs"

# Dependency Resolution
# ---------------------

# Tell the user we're about to begin.
numpacks=$(sed -n '$=' <"$packlist")
if test $numpacks -eq 1
then packname=$(head -1 "$packlist" | cut -d ' ' -f 2)
     heed "calculating dependencies for $packname ..."
else heed "calculating dependencies for $numpacks package(s) ..."
fi

cat </dev/null >"$sessiondir"/solved

changed=true
runcount=0
while $changed
do
    runcount=$(( runcount + 1 ))
    notice "this is depsolve run #$runcount"
    cat </dev/null >"$packlist+"

    # rebuild deps package list
    if test -f "$sessiondir/solved"
    then
        join -v 2 -o 2.1,2.2,2.3,2.4 "$sessiondir/solved" "$sessiondir"/installed-deps |
        tee "$sessiondir/installed-deps+" |
        sort -k 2,4 > "$sessiondir/installed-deps-packs"
        mv "$sessiondir"/installed-deps+ "$sessiondir"/installed-deps
    fi

    # add deps for installed packages
    join -12 -22 -o 2.1,2.2,2.3,2.4                   \
            "$packlist" "$sessiondir"/installed-deps-packs  |
    cat "$packlist" -                                 |
    tee "$sessiondir"/merged-package-list             |
    cut -d ' ' -f 2-                                  |
    sort -u                                           |
    rpg-solve -u "$sessiondir/solved"                 \
                 "$sessiondir/installed-index"        |
    sort -b                                           |
    tee "$sessiondir/solved+"                         |
    grep -v -- ' -$'                                  |
    xargs -P 4 -n 2 rpg-fetch >/dev/null

    mv "$sessiondir/solved+" "$sessiondir/solved"

    cat "$sessiondir/solved"                          |
    while read package version
    do
        test "$version" = '-' && { cat "$packlist"; continue; }
        gemfile=$(rpg-fetch "$package" "$version")
        packagedir=$(rpg-package-register "$gemfile")

        notice "adding $package $version deps to packlist"
        grep '^runtime ' < "$packagedir"/dependencies |
        sed "s/^runtime/$package/"                    |
        cat "$packlist" -
    done |
    sort -b -u -k 2,4 >> "$packlist+"

    if cmp -s "$packlist" "$packlist+"
    then notice "package list did not change"
         changed=false
    else notice "package list changed"
         changed=true
    fi
    mv "$packlist+" "$packlist"
done

# Tell the user we're about to begin.
if badpacks=$(grep '\-$' <"$sessiondir"/solved)
then heed "$(echo "$badpacks" |sed -n '$=') package(s) failed to resolve:
$badpacks"
fi

goodpacks=$(grep -v -- '\-$' <"$sessiondir"/solved)
heed "$(echo "$goodpacks" |sed -n '$=') package(s) ready for installation:
$goodpacks"
