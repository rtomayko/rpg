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
: ${PGEMPACKS:=$PGEMPATH/packages}
: ${PGEMDB:=$PGEMPATH/db}

# Enable the shell's trace facility (`set -x`) in all pgem programs.
: ${PGEMTRACE:=false}
: ${PGEMSHOWBUILD:=false}

# export all PGEM variables
export PGEMPATH PGEMLIB PGEMCACHE PGEMPACKAGES PGEMBIN PGEMMAN
export PGEMTRACE

# Write a warning to stderr. The message is prefixed with the
# program's basename.
warn () { echo "$(basename $0):" "$@" 1>&2; }

# Write an informationational message stderr under verbose mode.
log () {
    _t="$1:" ; shift
    printf "%12s %s\n" "$_t" "$*" 1>&2
}

abort () { test "$*" && warn "$@"; exit 1; }

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
