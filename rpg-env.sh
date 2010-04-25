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

# Put RPGBIN on PATH if it isn't there already.
if ! expr "$PATH" : ".*$RPGBIN" >/dev/null &&
   ! echo "$PATH" | tr ':' '\n' | grep -q -e "^$RPGBIN$" >/dev/null
then PATH="$RPGBIN:$PATH"
fi

# Put RUBYLIB on PATH if it isn't there already.
if   test -z "$RUBYLIB"
then RUBYLIB="$RPGLIB:$RPGLIB/$RUBYARCH"
elif ! echo "$RUBYLIB" | tr ':' '\n' | grep -e "^$RPGLIB$" >/dev/null
then RUBYLIB="$RPGLIB:$RPGLIB/$RUBYARCH:$RUBYLIB"
fi

export RUBYLIB PATH

# Leave the rest of the work to env(1).
exec /usr/bin/env "$@"
