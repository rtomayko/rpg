#!/bin/sh
#/ Usage: pgem-uninstall <name>
#/ Uninstall package <name>
set -e

test $# -gt 1 && {
    echo "$@" |
    xargs -n 1 pgem uninstall
    exit
}

. pgem-sh-setup

name="$1"

# Get the manifest file going.
dbdir="$PGEMDB/$name"
manifest="$dbdir/active"

# Bail out if the db doesn't have this package or the package
# isn't active.
test -d "$dbdir" -a -L "$manifest" ||
abort "$name is not installed"

# Grab the currently installed version from the active symlink.
vers=$(readlink $manifest)

# Remove all files installed by this package
cat "$dbdir/active" |
grep -v '^#' |
xargs -n 1 unlink

# Unlink the active symlink
unlink $manifest

log uninstall "$name $vers"
