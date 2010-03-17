#!/bin/sh
# The `rpg-version-test` program tests a version string against one or more
# matching expressions. When all expressions match the version, the program
# exits successfully. When any expression fails to match, the program exits
# non-zero.
set -e
. rpg-sh-setup

[ "$*" ] || set -- '--help'; ARGV="$@"
USAGE '${PROGNAME} [-q] <version> <expression>...
Test package version against dependency expression.

Test that <version> matches the version tests given in <expression>. If
<version> is -, read multiple versions from stdin. <expression> may
include commas to separate multiple tests.

<expression> is comprised of a comparison operator: =, >, <, >=,
<=, or ~>, followed by a version number. When no operator is specified,
= is assumed.

Exits zero when all tests compare truthfully; non-zero when any tests fail.'

# Don't write matching version to stdout with -q
quiet=false
test "$1" = '-q' && {
    quiet=true
    shift
}

# Like `expr(1)` but ignore stdout.
compare () { expr "$1" "$2" "$3" >/dev/null; }

#/ Usage: rpg_version_eval <ver1> <op> <ver2>
#/ Compare <ver1> with <ver2> using operator <op>.
#/ Return zero if <ver1> matches <ver2>, non-zero otherwise.
version_compare () {
    v1="$1."; op="$2"; v2="$3."
    while test -n "$v1" -o -n "$v2"
    do
        # Take left-most item from `v1` and `v2`.
        left=${v1%%.*}; right=${v2%%.*}

        # Remove left-most item from `v1` and `v2`.
        v1=${v1#*.}; v2=${v2#*.}

        # Use `0` if we've eaten through either side.
        left=${left:-0}; right=${right:-0}

        # Check if `v1` satisfies operator w/ `v2`.
        if compare $left $op $right
        then compare $left = $right || return 0
        else compare $left = $right || return 1
        fi
    done
    compare 0 $op 0
}

# Shift off the version
vers="$1"; shift

# Read versions from stdin if - was given.
test "$vers" = '-' &&
vers="$(cat -)"

# Combine the rest of the arguments into one big list of expression with
# each version test separated by commas.
exps=""
while test $# -gt 0
do exps="$1,$exp"
   shift
done

# Get rid of the commas and condense each version spec so we get
# something like: `0.3.4 =0.5.7 >=0.9 10.2`
exps=$(echo "$exps" | sed -e 's/ //g' -e 's/,$//' -e 's/,/ /g')
allmatch=true

for ver in $vers
do satisfied=true
   for exp in $exps
   do
      # Extract the operator part or default to '='.
      operator=${exp%%[!><=~]*}
      operator=${operator:-=}

      # Extract the version part.
      ver2=${exp##*[><=~]}

      case "$operator" in

      # Fast path equality.
      =)   test "$ver" = "$ver2" || {
              satisfied=false
              break
           };;

      # Handle the squiggly guy.
      ~\>) lt="${ver2%.*}.999999" # gross
           version_compare "$ver" "<" "$lt" &&
           version_compare "$ver" ">=" "$ver2" || {
              satisfied=false
              break
           };;

      # Normal comparison.
      *)   version_compare "$ver" "$operator" "$ver2" || {
              satisfied=false
              break
           };;
      esac
   done

   if $satisfied
   then $quiet || echo "$ver"
   else allmatch=false
   fi
done

$allmatch
