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


# `shc` is a sh combiner. The `__SHC__` variable is set true when running
# under that environment, which sometimes requires special case logic.
: ${__SHC__:=false}

# Install Paths
# -------------

# This is the psuedo root directory where `rpg` keeps all its stuff. The
# default locations of all other rpg paths use this as a base.
# *HOWEVER*, no rpg utility targets this directory -- every significant
# location must have a separate path variable so that things stay
# flexible in configuration.
: ${RPGPATH:=/var/lib/rpg}

# `RPGLIB` is the shared Ruby `lib` directory where library files are
# installed. You can set this to the current Ruby's site packages with:
#
#     RPGLIB=$(ruby_sitelibdir)
: ${RPGLIB:=$RPGPATH/lib}

# `RPGBIN` is where executable scripts included in packages are installed.
: ${RPGBIN:=$RPGPATH/bin}

# `RPGMAN` is where manpages included with packages are installed. This
# is basically the whole reason `rpg` was written in the first place.
: ${RPGMAN:=$RPGPATH/man}

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
# directory. The `rpg-update(1)` program manages the files under it.
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

# Default stale time for use with `rpg-update -s`. Values can be stuff
# like `10 days` or `10d`, `30 minutes` or `30m`. A number with no time
# designator is considered in days. This value can also be `never`, in
# which case the database will never be automatically updated in the
# course of running other programs.
: ${RPGSTALETIME:=1 day}

# URL to the specs file used to build the package index.
: ${RPGSPECSURL:='http://rubygems.org/specs.4.8.gz'}

# export all RPG variables
export RPGPATH RPGLIB RPGBIN RPGMAN RPGCACHE RPGPACKS RPGDB RPGINDEX
export RPGTRACE RPGSHOWBUILD RPGSTALETIME RPGSPECSURL

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
#     . rpg-sh-setup  # bring in support lib
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
ruby_command () {
    command -v ruby 2>/dev/null ||
    echo "/usr/bin/env ruby"
}

# Retrieve a rbconfig value.
ruby_config () {
    ruby -rrbconfig -e "puts RbConfig::CONFIG['$1']"
}

# Ruby's `site_ruby` directory.
ruby_sitelibdir () {
    test "$RUBYSITEDIR" || {
        RUBYSITEDIR=$(ruby_config sitelibdir)
        export RUBYSITEDIR
    }
    echo "$RUBYSITEDIR"
}

# The file extension for dynamic libraries on this operating system.
# e.g., `so` on Linux, `dylib` on MacOS.
ruby_dlext() {
    test "$RUBYDLEXT" || {
        RUBYDLEXT=$(ruby_config DLEXT)
        export RUBYDLEXT
    }
    echo "$RUBYDLEXT"
}

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

# Alias `yes`, `no`, `1`, `0` to `true` and `false` so options can be
# set to any of those values.
yes () { true; }
no () { false; }
alias 1=true
alias 0=false


# Config Files
# ------------

# Source the system `/etc/rpgrc` file.
test -f /etc/rpgrc &&
. /etc/rpgrc

# Source the user `~/.rpgrc` file.
test -f ~/.rpgrc &&
. ~/.rpgrc

# Turn on the shell's built in tracing facilities
# if RPGTRACE is enabled.
${RPGTRACE:-false} && set -x

${RPGVERBOSE:-false} && {
    notice () { heed "$@"; }
}

# make sure we don't accidentally exit with a non-zero status
:
