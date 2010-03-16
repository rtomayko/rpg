#!/bin/sh
# Modify package to work around issues
set -e
. rpg-sh-setup

ARGV="$@"
USAGE '${PROGNAME} <package> <version> <path>
Patch package to work with rpg.'

package="$1"
version="$2"
path="$3"

# Usage: `sedi <expr> <file>`
#
# Run `sed` on `<file>` in-place.
sedi () {
    sed "$1" < "$2" > "$2+"
    mv "$2+" "$2"
}

# Note that this package is on the shit-list.
fixable () {
    heed "incompatible package detected: $package/$version (fixing)"
    test -n "$*" && notice "$*"
}

# Master list of shit list packages with hacks.
case "$package" in
haml)
    fixable "haml reads VERSION, VERSION_NAME, REVISION files from package root"
    cd "$path"
    revision=$(cat REVISION 2>/dev/null || true)
    vername=$(cat VERSION_NAME 2>/dev/null || true)
    sedi "
        s/File.read(scope('VERSION'))/'$version'/g
        s/File.read(scope('REVISION'))/'$revision'/g
        s/File.read(scope('VERSION_NAME'))/'$vername'/g
    " lib/haml/version.rb
    ;;

memcache-client)
    fixable "memcache.rb reads VERSION.yml file from package root"
    cd "$path"
    sedi "
        s/VERSION = begin/VERSION = '$version';0.times do/
        s/\"#{config[:major].*//
    " lib/memcache.rb
    ;;

memcached)
    fixable "memcached.rb reads VERSION file from package root"
    cd "$path"
    sedi "s/VERSION = File.read.*/VERSION = '$version'/" lib/memcached.rb
    ;;

esac

# Make sure we exit with success.
:
