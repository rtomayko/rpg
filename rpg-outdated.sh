#!/bin/sh
set -e
. rpg-sh-setup

ARGV="$@"
USAGE '${PROGNAME} [-u] [<glob>...]
List locally installed packages that can be updated.

Options
  -u               Sync the available package index before running.'

# `rpg-list` implements `-u` so just pass everything right on over.
rpg-list -l "$@"    |
grep '^\*'          |
sed 's/..//'
