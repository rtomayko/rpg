#!/bin/sh
#/ Usage: pgem-list
#/ List installed packages
set -e

. pgem-sh-setup

for f in $PGEMDB/*/active
do
    name=$(basename $(dirname $f))
    vers=$(readlink $f)
    echo "$name $vers"
done | sort
