#!/bin/sh
set -e
PROGNAME="$(basename $0)"
usage="Usage: ${PROGNAME} [-vx] [-c <path>] <command> [<args>...]
Manage gem packages, quickly.

The most commonly used rpg commands are:
  config           Write rpg configuration to stdout
  install          Install a package from file or remote repository
  status           Show status of local packages vs. respository
  steal            Transplant packages from Rubygems into rpg environment
  outdated         List packages with a newer version
  uninstall        Uninstall packages from local system
  update           Update the package index
  upgrade          Upgrade installed packages to latest version

Options
  -c <path>        Read rcfile at <path> instead of standard rpgrc locations
  -v               Enable verbose logging to stderr
  -q               Disable verbose logging to stderr (when enabled in config)
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

# Argument parsing.
while getopts qvxc: opt
do
    case $opt in
    c)   export RPGRCFILE="$OPTARG";;
    v)   export RPGVERBOSE=true;;
    x)   export RPGTRACE=true;;
    q)   export RPGVERBOSE=false;;
    ?)   echo "$usage"
         exit 2;;
    esac
done
shift $(( $OPTIND - 1 ))

# This is replaced by the generated config.sh file at build time.
: __RPGCONFIG__

# Bring in the rpg sh library.
. "$bindir"/rpg-sh-setup

# Shift off the first argument to determine the real command:
command="$1"
shift

# Exec the command or exit with failure if the command doesn't exist.
exec "$libexecdir/rpg-${command}" "$@"
