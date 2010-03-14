#!/bin/sh
set -e
. rpg-sh-setup

ARGV="$@"
USAGE '${PROGNAME}
Write rpg configuration values to standard output.'

env | grep ^RPG
