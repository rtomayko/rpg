#!/bin/sh
set -e
. rpg-sh-setup

[ "$*" ] || set -- "--help"; ARGV="$@"
USAGE '${PROGNAME} <package> [<version>]
Fetch a package into the cache, writing the filename to stdout.

No network operations are performed when a package exists in the cache
that satisfies the version spec.'

package="$1"
version="${2:->=0}"

# Find the best (most recent) version of the package matching the
# supplied version spec. Bail out with a failure status if nothing is
# found satisfying the requested version.
bestver=$(rpg-resolve -n 1 "$package" "$version") || {
    warn "$package $version not found."
    exit 1
}

gemfile="${package}-${bestver}.gem"
if test -f "$RPGCACHE/$gemfile"
then notice "$package $version [cached: $bestver]"
else
    # We're going to need to pull the gem off the server.
    mkdir -p "$RPGCACHE"
    cd "$RPGCACHE"

    if test "$bestver" != "$version"
    then heed "$package $version [resolved: $bestver]"
    else heed "$package $version"
    fi

    # Grab the gem with curl(1) and write to a temporary file just
    # in case something goes wrong during transfer.
    curl -s -L "http://rubygems.org/downloads/${gemfile}" > "${gemfile}+"
    mv "${gemfile}+" "$gemfile"
fi

echo "$RPGCACHE/$gemfile"
