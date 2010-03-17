#!/bin/sh
# RPG shell utility library.
#
# This file is sourced by all `rpg-*` utilities. It handles environment
# setup and provides utility functions.
#
# A typical rpg program should look like this:
#
#     #!/bin/sh
#     # Launch a rocket missile or something like that.
#     set -e
#     . rpg-sh-setup
#
#     ARGV="$@"
#     USAGE '${PROGNAME} [-f] <missle>
#     Launch a rocket missile.'
#
#     # missile launching code
#
# That will handle `--help` usage messages and load the RPG environment.

# Guard against sourcing this file multiple times
test $__rpg_sh_setup_included && return
__rpg_sh_setup_included=true

# This is replaced with the `config.sh` file that's generated when the
# `./configure` script is run. It includes a bunch of environment variables
# for program paths and defaults for the `RPGPATH`, `RPGBIN`, `RPGLIB`, etc.
# options.
: __RPGCONFIG__


# rpg's default installation and database locations are based on the
# currently active ruby environment. We use Ruby's `rbconfig` module to
# load the `bin`, `lib`, `man`, and `var` directories then set and export
# the `__RPGENV__` variable so that we only do this once per rpg
# process hierarchy.
#
# Any of the variables exported below may be used in `rpgrc` config files to
# determine the best locations for various RPG paths.
if test -z "$__RPGENV__"
then
PATH="${libexecdir}:$PATH"
RUBY="$(command -v ruby 2>/dev/null || echo "${RUBY:-ruby}")"
__RPGENV__="$RUBY"

rubyenv () {
$RUBY <<RUBY
require 'rbconfig'
conf = RbConfig::CONFIG
puts "
RUBYPREFIX='#{conf['prefix']}'
RUBYDLEXT='#{conf['DLEXT']}'
RUBYSITEDIR='#{conf['sitelibdir']}'
RUBYVENDORDIR='#{conf['vendorlibdir']}'
RUBYMANDIR='#{conf['mandir']}'
RUBYBINDIR='#{conf['bindir']}'
RUBYSTATEDIR='#{conf['localstatedir']}'
RUBYVERSION='#{conf['ruby_version']}'
RUBYLIBDIR='#{File.dirname(conf['rubylibdir'])}'
"
RUBY
}
eval "$(rubyenv)"

export __RPGENV__ RUBY
export RUBYPREFIX RUBYDLEXT RUBYSITEDIR RUBYVENDORDIR RUBYMANDIR RUBYBINDIR
export RUBYSTATEDIR RUBYLIBDIR RUBYVERSION

    # With `configure --development`, set all paths to be inside a work dir.
    if $develmode; then
        : ${RPGPATH:="./work"}
        : ${RPGLIB:="$RPGPATH/lib"}
        : ${RPGMAN:="$RPGPATH/man"}
        : ${RPGBIN:="$RPGPATH/bin"}
    fi
fi

# Install Paths
# -------------

# This is the psuedo root directory where `rpg` keeps all its stuff. The
# default locations of all other rpg paths use this as a base.
# *HOWEVER*, no rpg utility targets this directory -- every significant
# location must have a separate path variable so that things stay
# flexible in configuration.
: ${RPGPATH:=${RUBYLIBDIR:-/var/lib}/rpg}

# `RPGLIB` is the shared Ruby `lib` directory where library files are
# installed. You can set this to the current Ruby's site packages with:
#
#     RPGLIB=$(ruby_sitelibdir)
: ${RPGLIB:="${RUBYVENDORDIR:-${RPGSITEDIR:-$RPGPATH/lib}}"}

# `RPGBIN` is where executable scripts included in packages are installed.
: ${RPGBIN:="${RUBYBINDIR:-$RPGPATH/bin}"}

# `RPGMAN` is where manpages included with packages are installed. This
# is basically the whole reason `rpg` was written in the first place.
: ${RPGMAN:="${RUBYMANDIR:-$RPGPATH/man}"}


# RPG Paths
# ---------

# `RPGCACHE` is where `rpg-fetch(1)` looks for and stores gem files.
# Set this to your Rubygems `cache` directory to share the gem cache.
: ${RPGCACHE:=$RPGPATH/cache}

# `RPGPACKS` is where `rpg-install(1)` unpacks gems before installing. The
# package directories are not used after package installation is complete.
: ${RPGPACKS:=$RPGPATH/packs}

# `RPGDB` is where the local package database is kept. It's a
# filesystem hierarchy. It looks like this:
#
#     $ rpg-env sh -c 'cd $RPGDB && tree'
#     RPGDB
#     |-- bcrypt-ruby
#     |   |-- 2.1.2
#     |   |   |-- authors
#     |   |   |-- bindir
#     |   |   |-- date
#     |   |   |-- dependencies
#     |   |   |-- description
#     |   |   |-- email
#     |   |   |-- executables
#     |   |   |-- extensions
#     |   |   |-- files
#     |   |   |-- gemspec
#     |   |   |-- homepage
#     |   |   |-- manifest
#     |   |   |-- name
#     |   |   |-- platform
#     |   |   |-- require_paths
#     |   |   |-- summary
#     |   |   |-- test_files
#     |   |   `-- version
#     |   `-- active -> 2.1.2
#     |-- do_sqlite3
#     |   |-- 0.10.1.1
#     |   |   |-- authors
#     |   |   |-- bindir
#     |   |   |-- date
#     |   |   |-- dependencies
#     |   |   |-- description
#     |   |   |-- email
#     |   |   |-- executables
#     |   |   |-- extensions
#     |   |   |-- files
#     |   |   |-- gemspec
#     |   |   |-- homepage
#     |   |   |-- manifest
#     |   |   |-- name
#     |   |   |-- platform
#     |   |   |-- require_paths
#     |   |   |-- summary
#     |   |   |-- test_files
#     |   |   `-- version
#     |   `-- active -> 0.10.1.1
#     `-- sinatra
#         |-- 0.9.6
#         |   |-- authors
#         |   |-- bindir
#         |   |-- date
#         |   |-- dependencies
#         |   |-- description
#         |   |-- email
#         |   |-- executables
#         |   |-- extensions
#         |   |-- files
#         |   |-- gemspec
#         |   |-- homepage
#         |   |-- manifest
#         |   |-- name
#         |   |-- platform
#         |   |-- require_paths
#         |   |-- summary
#         |   |-- test_files
#         |   `-- version
#         |-- 1.0.b
#         |   |-- authors
#         |   |-- bindir
#         |   |-- date
#         |   |-- dependencies
#         |   |-- description
#         |   |-- email
#         |   |-- executables
#         |   |-- extensions
#         |   |-- files
#         |   |-- gemspec
#         |   |-- homepage
#         |   |-- manifest
#         |   |-- name
#         |   |-- platform
#         |   |-- require_paths
#         |   |-- summary
#         |   |-- test_files
#         |   `-- version
#         `-- active -> 0.9.6
#
# The database is meant to be "stable". That is, you can write programs
# that rely on this structure. Maybe it should be documented first.
: ${RPGDB:=$RPGPATH/db}

# `RPGINDEX` is where the index of available gems is kept. It's a
# directory. The `rpg-sync(1)` program manages the files under it.
#
#   * `release`:
#     All available packages and all versions of all packages. Each line is a
#     `<package> <version>` pair, separated by whitespace. The file is sorted
#     alphabetically by package  name, reverse by version number, such that the
#     first line for a package is the most recent version.
#
#   * `release-recent`:
#     The most recent versions of all packages. The format is otherwise
#     identical to the `release` file. This mostly exists so that
#     `join(1)` can be used on it. Otherwise, we'd just build it from
#     `release` when we needed it.
#
#   * `prerelease`:
#     **NOT YET IMPLEMENTED.**
#     This is the same as `release` but includes only prelease packages.
#
#   * `prerelease-recent`:
#     **NOT YET IMPLEMENTED.**
#     This is the same as `release-recent` but includes only prelease
#     packages.
#
: ${RPGINDEX:=$RPGPATH/index}

# Enable verbose logging to stderr.
: ${RPGVERBOSE:=false}

# Enable the shell's trace facility (`set -x`) in all rpg programs.
: ${RPGTRACE:=false}

# Show extconf.rb and make output when building extensions.
: ${RPGSHOWBUILD:=false}

# Default stale time for use with `rpg-sync -s`. Values can be stuff
# like `10 days` or `10d`, `30 minutes` or `30m`. A number with no time
# designator is considered in days. This value can also be `never`, in
# which case the database will never be automatically sync'd in the
# course of running other programs.
: ${RPGSTALETIME:=1 day}

# URL to the specs file used to build the package index.
: ${RPGSPECSURL:='http://rubygems.org/specs.4.8.gz'}

# The system configuration file. Sourced near the end of this script. This
# is one of the variables that the configure script overrides.
: ${RPGSYSCONF:=/etc/rpgrc}

# The user configuration file. Sourced immediately after the system
# configuration file.
: ${RPGUSERCONF:=~/.rpgrc}

# export all RPG variables
export RPGPATH RPGLIB RPGBIN RPGMAN RPGCACHE RPGPACKS RPGDB RPGINDEX
export RPGTRACE RPGSHOWBUILD RPGSTALETIME RPGSPECSURL
export RPGSYSCONF RPGUSERCONF

# Constants
# ---------

# Useful BRE patterns for matching various gem stuffs.
GEMNAME_BRE='[0-9A-Za-z_.-]\{1,\}'
GEMVERS_BRE='[0-9][0-9.]*'
GEMPRES_BRE='[0-9A-Za-z][0-9A-Za-z.]*'

# This seems to be the most portable way of getting a variable with
# embedded newline. `$'\n'` is POSIX but doesn't work in my version of
# `dash(1)`. This works in `bash` and `dash` at least.
#
# The `ENEWLINE` is just an escaped version, useful for `sed` patterns.
NEWLINE='
'
ENEWLINE="\\$NEWLINE"

# Usage Messages, Logging, and Stuff Like That
# --------------------------------------------

# The program name used in usage messages, log output, and other places
# probably. You can set this before sourcing rpg-sh-setup to override
# the default `$(basename $0)` value but it's probably what you want.
: ${PROGNAME:=$(basename $0)}

# The progam's usage message. See the documentation for the `USAGE`
# function for information on setting this and how it plays with the
# other usage related functions.
: ${__USAGE__:='${PROGNAME} <args>'}

# This is the main usage setting thingy. Scripts should start as
# follows to take advantage of it:
#
#     set -e           # always
#     . rpg-sh-setup   # bring in support lib
#
#     ARGV="$@"
#     USAGE '${PROGNAME} <options> ...
#     A short, preferably < 50 char description of the script.
#
#     Options:
#       -b               Booooyaaahhh.'
#
# That will automatically trigger option parsing for a `--help`
# argument and whatnot.
#
# Note that the string passed in is single-quote escape. The string will
# evaluated at help time so you can do wild/expensive interpolations if
# that's your thing.
#
# One more quick usage tip. Some scripts want to show usage when `$@` is
# empty and others don't. These `USAGE` routines default to *not*
# showing the usage message when no arguments were passed. If you want
# to show usage when no arguments are passed, put this immediately
# before setting the `ARGV` variable:
#
#     [ "$*" ] || set -- --help
#     ARGV="$@"
#     USAGE ...
#
# That'll cause empty arg invocations to show the help message.
USAGE () {
    __USAGE__="${1:-$(cat)}"
    case "$ARGV" in
    *--h|*--he|*--hel|*--help|*-h|*-\?)
        helpthem 0
        exit 0;;  # just in case
    esac
}

# Show usage message defined in USAGE environment variable. The usage message
# is first evaluated as a string so interpolations can be performed if
# necessary.
helpthem () {
    : ${REAL_USAGE:=$(eval "echo \"$__USAGE__\"")}
    echo "Usage: $REAL_USAGE"
    exit ${1:-2}
}


# Write a warning to stderr. The message is prefixed with the
# program's basename.
warn () { echo "$PROGNAME:" "$@" 1>&2; }

# Write an informationational message to stderr prefixed with the name
# of the current script. Don't use this, use `notice`.
heed () {
    printf "%20s %s\n" "${PROGNAME#rpg-}:" "$*" |
    sed 's/^\([^ ]\)/                     \1/'  1>&2
}

# We rewite the `notice` function to `head` if `RPGVERBOSE` is enabled
# after sourcing config files.
notice () { true; }

# Ruby Related Utility Functions
# ------------------------------

# The command that should be executed to run `ruby`. This is used to
# rewrite shebang lines.
#
# TODO this is only used in rpg-build and should be updated to use something
# else.
ruby_command () {
    command -v ruby 2>/dev/null ||
    echo "/usr/bin/env ruby"
}

# Retrieve a rbconfig value.
rbconfig () {
    $RUBY -rrbconfig -e "puts RbConfig::CONFIG['$1']"
}

# The file extension for dynamic libraries on this operating system.
# e.g., `so` on Linux, `dylib` on MacOS.
ruby_dlext() { echo "$RUBYDLEXT"; }

# Misc Utility Functions
# ----------------------

# `readlink(1)` for systems that don't have it.
readlink () {
    test -L "$1"
    command readlink "$1" 2>/dev/null || {
        _p=$(ls -l "$1")
        echo ${_p##* -> }
    }
}

# Count lines in a file. This is here because I mess it up so often.
lc () {
    wc -l "$@" | cut -c 1-8 | sed 's/^ *//'
}

# Alias `yes`, `no`, `1`, `0` to `true` and `false` so options can be
# set to any of those values.
yes () { true; }
no () { false; }
alias 1=true
alias 0=false


# Config Files
# ------------

# Source the system `/etc/rpgrc` file.
test -f "$RPGSYSCONF" && . "$RPGSYSCONF"

# Source the user `~/.rpgrc` file.
test -f "$RPGUSERCONF" && . "$RPGUSERCONF"

# Turn on the shell's built in tracing facilities
# if RPGTRACE is enabled.
${RPGTRACE:-false} && set -x

${RPGVERBOSE:-false} && {
    notice () { heed "$@"; }
}

# make sure we don't accidentally exit with a non-zero status
:
