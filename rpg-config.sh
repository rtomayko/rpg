#!/bin/sh
set -e
. rpg-sh-setup

ARGV="$@"
USAGE '${PROGNAME}
Write rpg configuration values to standard output.'

cat <<CONFIG
# rpg installs package contents in these locations:
RPGBIN='$RPGBIN'
RPGLIB='$RPGLIB'
RPGMAN='$RPGMAN'

# rpg keeps its package database, index, and gem cache in these locations:
RPGPATH='$RPGPATH'
RPGDB='$RPGDB'
RPGINDEX='$RPGINDEX'
RPGPACKS='$RPGPACKS'
RPGCACHE='$RPGCACHE'

# rpg sources these configuration files before executing commands:
RPGSYSCONF='$RPGSYSCONF'
RPGUSERCONF='$RPGUSERCONF'

# rpg uses these options to control various aspects of its behavior:
RPGTRACE='$RPGTRACE'
RPGSHOWBUILD='$RPGSHOWBUILD'
RPGSTALETIME='$RPGSTALETIME'
RPGSPECSURL='$RPGSPECSURL'
CONFIG
