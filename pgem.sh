#!/bin/sh
set -e
PROGNAME="$(basename $0)"
usage="Usage: ${PROGNAME} [-vx] [-c <path>] <command> [<args>...]
Manage gem packages, quickly.

The most commonly used pgem commands are:
  config           Write pgem configuration to stdout
  install          Install a package from file or remote repository
  status           Show status of local packages vs. respository
  steal            Replicate rubygems packages into pgems environment
  outdated         List packages with a newer version
  uninstall        Uninstall packages from local system
  update           Update the package index
  upgrade          Upgrade installed packages to latest version

Options
  -c <path>        Read rcfile at <path> instead of standard pgemrc locations
  -v               Enable verbose logging to stderr
  -x               Enable shell tracing to stderr (extremely verbose)

See \`${PROGNAME} help <command>' for more information on a specific command."
[ "$*" ] || set -- "--help"
for a in "$@"
do
    case "$a" in
    --h|--he|--hel|--help|-h|-\?) echo "$usage"; exit 0;;
                              -*) continue;;
                               *) break;;
    esac
done


# Install Plumbing
#   pgem-build
#   pgem-deps
#   pgem-env
#   pgem-fetch
#   pgem-list
#   pgem-fsck
#
# Version Resolution and Dependency Solving
#   pgem-resolve
#   pgem-version-test

# Argument parsing.
while getopts c:vx opt
do
    case $opt in
    c)   export PGEMRCFILE="$OPTARG";;
    v)   export PGEMVERBOSE=true;;
    x)   export PGEMTRACE=true;;
    ?)   echo "$usage"
         exit 2;;
    esac
done
shift $(( $OPTIND - 1 ))

# Bring in pgem config
. pgem-sh-setup

# Shift off the first argument to determine the real command:
command="$1"
shift

if $__SHC__
then
    case $command in
    build)         pgem_build "$@";;
    config)        pgem_config "$@";;
    deps)          pgem_deps "$@";;
    env)           pgem_env "$@";;
    fetch)         pgem_fetch "$@";;
    install)       pgem_install "$@";;
    list)          pgem_list "$@";;
    resolve)       pgem_resolve "$@";;
    sh-setup)      true ;;
    uninstall)     pgem_uninstall "$@";;
    update)        pgem_update "$@";;
    version-test)  pgem_version_test "$@";;
    *)             exec pgem-$command "$@";;
    esac
else
    exec "pgem-${command}" "$@"
fi
