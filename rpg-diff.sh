#!/bin/sh
set -e
. rpg-sh-setup

[ "$*" ] || set -- --help; ARGV="$@"
USAGE '${PROGNAME} <package>
       ${PROGNAME} <package> <version>
       ${PROGNAME} <package> <ver1> <ver2>
Show diff between package versions. With no <version>, show diff between
most recent available version and installed version. With one <version>, show diff
between currently installed version and <version>. With <ver1> and <ver2>, show
diff between <ver1> and <ver2>.'

package="$1"
ver1="$2"
ver2="$3"

dir1=$(rpg-unpack -nP "$package" "$ver1")
dir2=$(rpg-unpack -nP "$package" "$ver2")

diff -ruN "$dir1" "$dir2"
