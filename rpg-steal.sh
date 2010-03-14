#!/bin/sh
set -e
. pgem-sh-setup

ARGV="$@"
USAGE '${PROGNAME} [-n]
Take everything currently installed in Rubygems and install in pgems.

With the -n option, show what would be installed but do not.'

if test "$1" = '-n'
then  tampon="echo"
      shift
else  tampon="pgem-install"
fi

gem list --local                                                     |
sed "s|^\(${GEMNAME_PATTERN}\) *(\([$GEMVERS_PATTERN\).*|GEM \1 \2|" |
grep '^GEM '                                                         |
sed 's/^GEM //'                                                      |
xargs -n 2 "$tampon"
