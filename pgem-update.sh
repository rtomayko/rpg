#!/bin/sh
set -e
. pgem-sh-setup

usage="Usage: pgem-update [-v] [-m <mins>|-d <days>|-s]
Create or update the remote package database if stale.

Options
  -d <days>             Do nothing if db is less than <days> days old
  -m <mins>             Do nothing if db is less than <mins> minutes old
  -s                    Do nothing if db is less than $PGEMSTALETIME old
  -v                    Write newly available packages to stdout after updating

The -s option is used by various pgem commands when an update may be
neccassary. Its default stale time can be configured by setting the
PGEMSTALETIME option in ~/.pgemrc or /etc/pgemrc."
[ "$1" = '--help' ] && echo "$usage" && exit 2

verbose=false
staletime=
while getopts vsm:d: opt
do
    case $opt in
    v)   verbose=true;;
    m)   staletime="$OPTARG min";;
    d)   staletime="$OPTARG day";;
    s)   staletime="$PGEMSTALETIME";;
    ?)   echo "$usage"
         exit 2;;
    esac
done
shift $(($OPTIND - 1))

# Bail out with usage if we have more args.
[ "$*" ] && warn "invalid argument: $*" && exit 2

index="$PGEMDB/gemdb"
test -d "$PGEMDB" || mkdir -p "$PGEMDB"

# Maybe bail out if a stale time was given. `PGEMSTALETIME` values can be
# stuff like `10 days` or `10d`, `30 minutes` or `30m`. A number with no
# time designator is considered in days. When the value is `never`,
# don't update the database due to staleness in the course of running
# other programs.
test -n "$staletime" && {
    case "$staletime" in
    never|none) log update "database is in never update mode"
                exit 0;;
    [0-9]*m*)   fargs="-mmin -${staletime%%[!0-9]*}";;
    [0-9]*)     fargs="-mtime -${staletime%%[!0-9]*}";;
    *)          fargs=""
                warn "bad PGSTALETIME value: '$staletime'. ignoring.";;
    esac

    if test -z "$(find "$index" -maxdepth 0 $fargs 2>/dev/null)"
    then log update "database is missing or stale [> $staletime old]"
    else log update "database is fresh [< $staletime old]"
         exit 0
    fi
}

# The `gem list --all` output looks like this:
#
#     clown (0.0.8)
#     ClsRuby (1.0.1, 1.0.0)
#     clusterer (0.1.9, 0.1.0)
#     clusterfuck (0.1.0)
#     cmd (0.7.2, 0.7.1, 0.7.0)
#     cmd_line_test (0.1.5, 0.1.4)
#     cmdline (0.0.2, 0.0.1, 0.0.0)
#     Cmdline_Parser (0.1.1, 0.1.0)
#     cmdparse (2.0.2, 2.0.1, 2.0.0, 1.0.5, 1.0.4, 1.0.3)
#     cmdrkeene-foursquare (0.0.4)
#
# It includes all gems and all versions of all gems.
gem list --no-installed --remote --all |

# Now turn it into something that's easy to use with stream tools
# like grep(1), sed(1), cut(1), join(1), etc.
sed '
    s/^\([0-9A-Za-z_.-]\{1,\}\) (\(.*\))$/GEM \1 \2/
    s/,//g
    '                                  |

# It looks like this when we're done with it:
#
#     clown 0.0.8
#     ClsRuby 1.0.1
#     ClsRuby 1.0.0
#     clusterer 0.1.9
#     clusterer 0.1.0
#     clusterfuck 0.1.0
#     cmd 0.7.2
#     cmd 0.7.1
#     cmd 0.7.0
#     cmd_line_test 0.1.5
#     cmd_line_test 0.1.4
#
# One line per package and package version.
#
# This is slow but it'll have to for now. We should be able to do the same
# fairly easily with sed(1) or awk(1) but I'm not familiar with any approaches.
while read leader name versions
do
    for ver in $versions
    do echo "$name $ver"
    done
done > "${index}+"

# We wrote the new index to separate file so we can take a quick diff. We can
# show the diff directly, which is awesome, but this could also be used to roll
# back and update (`patch -R`) if something goes wrong.
(diff -u "${index}" "${index}+" 2>&1 && true) > "$PGEMDB/diff"

# Move the new index into place
mv "${index}+" "${index}"

# Write a list of new packages to stdout if the verbose flag was given.
$verbose && {
    echo "# New packages:"
    grep '^+' < "$PGEMDB/diff" |
    grep -v '^++'              |
    cut -c2-
}

# Careful now.
:
