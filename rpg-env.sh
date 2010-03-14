#!/bin/sh
set -e
. rpg-sh-setup

ARGV="$@"
USAGE '${PROGNAME} [name=value ...] [<command> [<arguments> ...]]
Execute command under rpg environment.

The RPGLIB dir is placed on RUBYLIB and exported, and RPGBIN is add to
added PATH before executing command.

If no <command> is specified, ${PROGNAME} writes the name and values
of variables in the environment to stdout with one <name>=<value> per line.'

# Setup RUBYLIB and PATH.
RUBYLIB="$RPGLIB:$RUBYLIB"
PATH="$RPGBIN:$PATH"
export RUBYLIB PATH

# Leave the rest of the work to env(1).
exec /usr/bin/env "$@"
