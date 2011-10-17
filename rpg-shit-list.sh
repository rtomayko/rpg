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

json|json_pure)
  fixable "json includes ext/ in require_paths"
  echo "lib" > "$RPGDB/$package/$version/require_paths"
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
    # The mongrel_rails executable acts more like a library. Rails and other
    # commands require it to be on the load path. It also doesn't have a shebang
    # so is executed with /bin/sh by default. We move it over to the lib
    # directory -- sub'ing some LOAD_PATH modifications on the way -- and then
    # write simple executable wrapper.
    test -f "$path/lib/mongrel_rails" || {
        fixable "mongrel_rails is more library than executable"
        cd "$path"
        sed 's/\($LOAD_PATH.unshift\)/# \1/' <bin/mongrel_rails >lib/mongrel_rails
        printf "#!$(ruby_command)\nload 'mongrel_rails'" >bin/mongrel_rails
        chmod +x bin/mongrel_rails
    }
    ;;

RedCloth)
    fixable "RedCloth.rb clobbers original redcloth.rb"
    cd "$path"
    rm -rf "lib/case_sensitive_require"
    rm -rf "lib/tasks"
    ;;

sass)
    fixable "sass reads VERSION, VERSION_NAME, REVISION files from package root"
    cd "$path"
    revision=$(cat REVISION 2>/dev/null || true)
    vername=$(cat VERSION_NAME 2>/dev/null || true)
    sedi "
        s/File.read(scope('VERSION'))/'$version'/g
        s/File.read(scope('REVISION'))/'$revision'/g
        s/File.read(scope('VERSION_NAME'))/'$vername'/g
    " lib/sass/version.rb
    ;;

SystemTimer)
    fixable "system_timer.rb and system_timer_stub.rb requires rubygems"
    cd "$path"
    sedi "s/require 'rubygems'//" lib/system_timer.rb
    sedi "s/require 'rubygems'//" lib/system_timer_stub.rb
    ;;

thin)
    fixable "thin assumes thin_parser extension is in package root"
    cd "$path"
    sedi 's@require "#{Thin::ROOT}/thin_parser"@require "thin_parser"@' lib/thin.rb
    ;;

taps)
    cd "$path"
    test -f VERSION.yml && {
        fixable "taps VERSION.yml"
        yaml=$(sed 's|$|\\|' < VERSION.yml)
        sedi "s/@@version_yml ||= /@@version_yml ||= YAML.load('$yaml') #/" \
        lib/taps/config.rb
    }

    fixable "taps relative bin paths"
    sedi "s|bin_path = |bin_path = '$RPGBIN/schema' #|" lib/taps/utils.rb
    ;;

esac

# Make sure we exit with success.
:
