#!/bin/sh
set -e
. pgem-sh-setup

ARGV="$@"
USAGE '${PROGNAME}
Write pgem configuration values to standard output.'

env | grep ^PGEM
