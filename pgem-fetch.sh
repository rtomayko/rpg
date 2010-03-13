#!/bin/sh
set -e
usage="Usage: pgem-fetch <package> [<version>]
Fetch <package> to the cache and write the package files name and version.

No network operations are performed when a package exists in the cache
that satisfies the version spec."
[ -z "$*" -o "$1" = "--help" ] && echo "$usage" && exit 2

. pgem-sh-setup

package="$1"
version="${2:->=0}"

# Find the best (most recent) version of the package matching the
# supplied version spec. Bail out with a failure status if nothing is
# found satisfying the requested version.
bestver=$(pgem-resolve -n 1 "$package" "$version") || {
    warn "$package $version not found."
    exit 1
}

gemfile="${package}-${bestver}.gem"
if test -f "$PGEMCACHE/$gemfile"
then log fetch "$package $version [cached: $bestver]"
else
    # We're going to need to pull the gem off the server.
    mkdir -p "$PGEMCACHE"
    cd "$PGEMCACHE"
    log fetch "$package $version [fetching: $bestver]"

    # Grab the gem with curl(1) and write to a temporary file just
    # in case something goes wrong during transfer.
    curl -# -L "http://rubygems.org/downloads/${gemfile}" > "${gemfile}+"
    mv "${gemfile}+" "$gemfile"
fi

echo "$PGEMCACHE/$gemfile"
