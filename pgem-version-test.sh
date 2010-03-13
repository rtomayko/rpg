#!/bin/sh
#/ Usage: pgem-version-test -e <ver> <expr>...
#/ Test if <ver> matches the version test given in <expr>.
#/
local ver exp op ver1 ver2 gte lt left right compver
set -e

compare () {
    expr "$1" "$2" "$3" >/dev/null
}

# Shift off the version
ver="$1" ; shift

# Create a single big expression separated by commas.
exp=""
while test $# -gt 0
do
    exp="$1,$exp"
    shift
done
exp=$(
    echo "$exp" |
    sed '
        s/ //g
        s/,$//g
    ')

# Run one pgem-version-test process per expression.
compare "$exp" : '.*,' && {
    echo "$exp"               |
      tr ',' '\n'             |
      while read compver
      do
          pgem version-test "$ver" "$compver"
      done
    exit 0
}

. pgem-sh-setup

op=${exp%%[!><=~]*}
ver2=${exp##*[><=~]}

# handle squiggly guy
test "$op" = "~>" && {
    gte="$ver2"
    lt="${ver2%.*}.999999" # gross
    pgem version-test "$ver" "<$lt,>=$gte"
    exit 0
}

ver1="$ver."
ver2="$ver2."
while test -n "$ver1" -o -n "$ver2"
do
    left=${ver1%%.*}
    right=${ver2%%.*}
    left=${left:-0}
    right=${right:-0}
    ver1=${ver1#*.}
    ver2=${ver2#*.}
    if compare $left $op $right
    then
        compare $left = $right || exit 0
    else
        compare $left = $right
    fi
done

compare 0 $op 0
