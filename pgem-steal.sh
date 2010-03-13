#!/bin/sh
set -e
usage="Usage: pgem-steal [-n]
Take everything currently installed in Rubygems and install in pgems.

With the -n option, show what would be installed but don't.
"
expr "$*" : ".*--help" >/dev/null && {
    echo "$usage"
    exit 2
}

. pgem-sh-setup

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
