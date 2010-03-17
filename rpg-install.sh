#!/bin/sh
# TODO Documentation and cleanup
set -e
. rpg-sh-setup

[ "$*" ] || set -- '--help'; ARGV="$@"
USAGE '${PROGNAME} [-f] <package> [[-v] <version>] ...
       ${PROGNAME} [-f] <package>[/<version>]...
Install packages into rpg environment.

Options
  -f          Force package installation even if already installed'

RPGSESSION="$RPGDB/@session"
sessiondir="$RPGSESSION"
packlist="$sessiondir"/package-list

rm -rf "$sessiondir"
mkdir -p "$sessiondir"

notice "writing argv"
for a in "$@"
do echo "$a"
done > "$sessiondir"/argv

# Pass the -f argument on to `rpg-package-install` if given.
packageinstallargs=
test "$1" = -f && {
    packageinstallargs=-f
    shift
}

notice "writing user package-list"
rpg-parse-package-list "$@"  |
sed "s/^/@user /"            > "$packlist"

# see if we need to update the index
rpg update -s

# Tell the user we're about to begin.
numpacks=$(lc "$packlist")
heed "calculating dependencies for $numpacks package(s) ..."

notice "entering dep solve loop"
changed=true
runcount=0
while $changed
do
    runcount=$(( runcount + 1 ))
    notice "this is depsolve run #$runcount"
    cat </dev/null >"$packlist+"

    cut -d ' ' -f 2- "$packlist"                      |
    rpg-solve -u "$sessiondir/solved"                 |
    cut -f 1,3 -d ' '                                 |
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
        # diff "$packlist" "$packlist+" 1>&2 || true
        changed=true
    fi
    mv "$packlist+" "$packlist"
done

# Tell the user we're about to begin.
numpacks=$(lc "$packlist")
heed "installing $numpacks total package(s):
$(cat "$sessiondir"/solved)"

# echo "HERES THE PACKAGE LIST:"
# cat "$packlist"
#
# echo "HERES YOUR JANK:"
# cat "$sessiondir"/solved

cat "$sessiondir"/solved |
xargs -n 2 rpg-package-install $packageinstallargs

heed "installation complete"

true
