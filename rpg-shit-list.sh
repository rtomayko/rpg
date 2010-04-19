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

memcached)
    fixable "memcached.rb reads VERSION file from package root"
    cd "$path"
    sedi "s/VERSION = File.read.*/VERSION = '$version'/" lib/memcached.rb
    ;;

capistrano)
    fixable "capistrano/version.rb reads VERSION file from package root"
    cd "$path"
    sedi "s/CURRENT = /CURRENT = '$version' #/" lib/capistrano/version.rb
    sedi "s/  require 'rubygems'//" lib/capistrano/ssh.rb
    sedi "s/  gem 'net-ssh', \">= 2.0.10\"//" lib/capistrano/ssh.rb
    ;;

mongrel)
    fixable "mongrel_rails is missing a shebang"
    cd "$path"
    echo "#!$(ruby_command)" >bin/mongrel_rails+
    cat <bin/mongrel_rails >>bin/mongrel_rails+
    mv bin/mongrel_rails+ bin/mongrel_rails
    chmod +x bin/mongrel_rails
    ;;

SystemTimer)
  fixable "system_timer.rb and system_timer_stub.rb requires rubygems"
  cd "$path"
  sedi "s/require 'rubygems'//" lib/system_timer.rb
  sedi "s/require 'rubygems'//" lib/system_timer_stub.rb
  ;;

esac

# Make sure we exit with success.
:
