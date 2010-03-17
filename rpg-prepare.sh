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

notice "writing argv"
for arg in "$@"
do echo "$arg"
done > "$sessiondir"/argv

notice "writing user package-list"
rpg-package-list "$@"        |
sed "s/^/@user /"            > "$packlist"

# see if we need to sync the index
rpg-sync -s

# Tell the user we're about to begin.
numpacks=$(lc "$packlist")
if test $numpacks -eq 1
then packname=$(head -1 "$packlist" | cut -d ' ' -f 2)
     heed "calculating dependencies for $packname ..."
else heed "calculating dependencies for $numpacks package(s) ..."
fi

changed=true
runcount=0
while $changed
do
    runcount=$(( runcount + 1 ))
    notice "this is depsolve run #$runcount"
    cat </dev/null >"$packlist+"

    cut -d ' ' -f 2- "$packlist"                      |
    rpg-solve -u "$sessiondir/solved"                 |
    sort -b                                           |
    tee "$sessiondir/solved+"                         |
    xargs -P 4 -n 2 rpg-fetch >/dev/null

    mv "$sessiondir/solved+" "$sessiondir/solved"

    cat "$sessiondir/solved"                          |
    while read package version
    do
        gemfile=$(rpg-fetch "$package" "$version")
        packagedir=$(rpg-package-register "$gemfile")

        notice "adding $package $version deps to packlist"
        grep '^runtime ' < "$packagedir"/dependencies |
        cut -d ' ' -f 2-                              |
        sed "s/^/$package /"                          |
        cat "$packlist" -
    done |
    sort -b -u -k 2,4 >> "$packlist+"

    if cmp -s "$packlist" "$packlist+"
    then
        notice "package list did not change"
        changed=false
    else
        notice "package list changed"
        changed=true
    fi
    mv "$packlist+" "$packlist"
done

# Tell the user we're about to begin.
numpacks=$(lc "$packlist")
heed "$numpacks package(s) ready for installation:
$(cat "$sessiondir"/solved)"
