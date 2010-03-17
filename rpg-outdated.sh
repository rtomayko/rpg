#!/bin/sh
set -e
. rpg-sh-setup

ARGV="$@"
USAGE '${PROGNAME} [-u] [<glob>...]
List locally packages that can be updated.

Options
  -u               Sync the available package index before running.'

# `rpg-list` implements `-u` so just pass everything right on over.
rpg-list "$@"    |
grep '^\*'       |
sed 's/..//'
