#!/bin/sh
set -e
. rpg-sh-setup

[ "$*" ] || set -- --help; ARGV="$@"
USAGE '${PROGNAME} <package>...
Uninstall packages from local system.'

# If more than one package was given, re-exec for each package:
test $# -gt 1 && {
    echo "$@" | xargs -n 1 rpg-uninstall
    exit $?
}

package="$1"
packagedir="$RPGDB/$package"
manifest="$packagedir/active/manifest"

# Bail out if the db doesn't have this package or the package
# isn't active.
test -d "$packagedir" -a -f "$manifest" || {
    warn "$name is not installed"
    exit 1
}

# Grab the currently installed version from the active symlink.
version=$(readlink "$packagedir/active")
notice "$package $version"

# Remove all files installed by this package
grep -v '^#' <"$packagedir/active/manifest" |
if $RPGVERBOSE
then
    while read file
    do notice "$file [unlink]"
       echo "$file"
    done
else
    cat
fi |
xargs -P 4 -n 1 unlink

# Cleanup empty directories
find $RPGLIB -depth -type d -empty -exec rmdir {} \;

# Unlink the active symlink
unlink "$packagedir/active"

true
