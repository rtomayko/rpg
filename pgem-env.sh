#!/bin/sh
#/ Usage: pgem-env [name=value ...] [<command> [<arguments> ...]]
#/ Executes <command> after modifying the environment with pgem values.
#/ The pgem shared lib path is placed on RUBYLIB and the pgem bin path
#/ is added to PATH.
#/
#/ If no <command> is specified, pgem-env writes the name and values
#/ of variables in the environment stdout with one <name>=<value> per line.

. pgem-sh-setup

# Setup RUBYLIB and PATH.
RUBYLIB="$PGEMLIB:$RUBYLIB"
PATH="$PGEMBIN:$PATH"
export RUBYLIB PATH

# Leave the rest of the work to env(1).
exec /usr/bin/env "$@"
