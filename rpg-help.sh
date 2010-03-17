#!/bin/sh
set -e
. rpg-sh-setup

ARGV="$@"
USAGE '${PROGNAME} [<command>]
Show help and usage for <command>'

case "$1" in
    help) helpthem;;
     rpg) exec rpg --help;;
  [a-z]*) exec rpg "$1" --help;;
       *) exec rpg --help;;
esac
