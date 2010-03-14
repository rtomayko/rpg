#!/bin/sh
set -e
. rpg-sh-setup

ARGV="$@"
USAGE '${PROGNAME} [-n]
Transplant packages from Rubygems to rpg.

With the -n option, show what would be installed but do not.'

if test "$1" = '-n'
then  tampon="echo"
      shift
else  tampon="rpg-install"
fi

gem list --local                                             |
sed "s|^\(${GEMNAME_BRE}\) *(\([$GEMVERS_BRE\).*|GEM \1 \2|" |
grep '^GEM '                                                 |
sed 's/^GEM //'                                              |
xargs -n 2 "$tampon"
