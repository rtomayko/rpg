#!/bin/sh
set -e
. pgem-sh-setup

ARGV="$@"
USAGE '${PROGNAME} <name>
Uninstall package from pgem environment.'

test $# -gt 1 && {
    echo "$@" |
    xargs -n 1 pgem uninstall
    exit
}

name="$1"

# Get the manifest file going.
dbdir="$PGEMDB/$name"
manifest="$dbdir/active"

# Bail out if the db doesn't have this package or the package
# isn't active.
test -d "$dbdir" -a -L "$manifest" || {
    warn "$name is not installed"
    exit 1
}

# Grab the currently installed version from the active symlink.
vers=$(readlink $manifest)

# Remove all files installed by this package
cat "$dbdir/active" |
grep -v '^#' |
xargs -n 1 unlink

# Unlink the active symlink
unlink $manifest

notice "$name $vers"

# Better safe than sorry.
:
