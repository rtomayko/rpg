#!/bin/sh

: ${__SHC__:=false}

# Guard against sourcing this file multiple times
test $__pgem_sh_setup_included && return
__pgem_sh_setup_included=true

# pgem configuration
: ${PGEMPATH:=/var/lib/pgem}
: ${PGEMLIB:=$PGEMPATH/lib}
: ${PGEMBIN:=$PGEMPATH/bin}
: ${PGEMMAN:=$PGEMPATH/man}
: ${PGEMCACHE:=$PGEMPATH/cache}
: ${PGEMPACKS:=$PGEMPATH/packs}

# `PGEMDB` is where our local package database is kept. It's a
# filesystem hierarchy. It looks like this:
#
#     $PGEMDB/
#     |-- ronn
#     |   |-- 0.4
#     |   |-- 0.4.1
#     |   `-- active -> 0.4.1
#     |-- sinatra
#     |   |-- 0.9.4
#     |   |-- 0.9.6
#     |   `-- active -> 0.9.6
#     |-- stemmer
#     |   |-- 1.0.1
#     |   `-- active -> 1.0.1
#     |-- syntax
#     |   |-- 1.0.0
#     |   `-- active -> 1.0.0
#     `-- turn
#         |-- 0.7.0
#         `-- active -> 0.10.0
#
# The database is meant to be "stable". That is, you can write programs
# that rely on this structure. Maybe it should be documented first.
: ${PGEMDB:=$PGEMPATH/db}

# `PGEMINDEX` is where the index of available gems is kept. It's a
# directory. The `pgem-update(1)` program manages the files under it.
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
: ${PGEMINDEX:=$PGEMPATH/index}

# Enable the shell's trace facility (`set -x`) in all pgem programs.
: ${PGEMTRACE:=false}

# Show extconf.rb and make output when building extensions.
: ${PGEMSHOWBUILD:=false}

# Default stale time for use with `pgem-update -s`. Values can be stuff
# like `10 days` or `10d`, `30 minutes` or `30m`. A number with no time
# designator is considered in days. This value can also be `never`, in
# which case the database will never be automatically updated in the
# course of running other programs.
: ${PGEMSTALETIME:=1 day}

# export all PGEM variables
export PGEMPATH PGEMLIB PGEMBIN PGEMMAN PGEMCACHE PGEMPACKS PGEMDB PGEMINDEX
export PGEMTRACE PGEMSHOWBUILD PGEMSTALETIME

# Logging and Output
# ------------------

# Write a warning to stderr. The message is prefixed with the
# program's basename.
warn () { echo "$(basename $0):" "$@" 1>&2; }

# Write an informationational message stderr under verbose mode.
log () {
    _t="$1:" ; shift
    printf "%12s %s\n" "$_t" "$*" 1>&2
}

abort () { test "$*" && warn "$@"; exit 1; }


# Misc Utility Functions
# ----------------------

# rubygems gemdir path
pgem_gemdir () {
    test "$GEM_HOME" || {
        GEM_HOME=$(gem environment gemdir)
        export GEM_HOME
    }
    echo "$GEM_HOME"
}

# Retrieve a rbconfig value.
pgem_rbconfig () {
    ruby -rrbconfig -e "puts RbConfig::CONFIG['$1']"
}

# ruby sitelibdir path.
pgem_sitelibdir () {
    test "$RUBYSITE" || {
        RUBYSITE=$(pgem_rbconfig sitelibdir)
        export RUBYSITE
    }
    echo "$RUBYSITE"
}

# full path to ruby binary
pgem_rubybin () {
    command -v ruby
}

# Query rbconfig for the the dynamic library file extension.
pgem_ruby_dlext() {
    test "$RUBYDLEXT" || {
        RUBYDLEXT=$(pgem_rbconfig DLEXT)
        export RUBYDLEXT
    }
    echo "$RUBYDLEXT"
}

# readlink(1) for systems that don't have it
readlink () {
    test -L "$1"
    command readlink "$1" 2>/dev/null || {
        _p=$(ls -l "$1")
        echo ${_p##* -> }
    }
}

# Alias yes/no, 1/0 to true/false respectively so options can be
# set to any of those values.
yes () { true; }
no () { false; }
alias 1=true
alias 0=false

# Constants
# ---------

# Useful BRE patterns for matching various gem stuffs.
GEMNAME_PATTERN='[0-9A-Za-z_.-]\{1,\}'
GEMVERS_PATTERN='[0-9.]\{1,\}'
GEMPRES_PATTERN='[0-9A-Za-z.]\{1,\}'

# Config Files
# ------------

# source system pgemrc file
test -f /etc/pgemrc &&
. /etc/pgemrc

# source user pgemrc file
test -f ~/.pgemrc &&
. ~/.pgemrc

# Turn on the shell's built in tracing facilities
# if PGEMTRACE is enabled.
eval "${PGEMTRACE:-false}" && set -x

# make sure we don't accidentally exit with a non-zero status
:
