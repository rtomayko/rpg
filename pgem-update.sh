#!/bin/sh
set -e
. pgem-sh-setup

usage="Usage: pgem-update [-v] [-m <mins>|-d <days>|-s]
Create or update the remote package index. Maybe.

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

# The Release Index
# -----------------
#
# The `release` file includes all versions of all packages. One line per
# `<package> <version>` pair.

# Here's where the file is kept. There's also `release-recent` and
# `release-diff` files, which we'll see in a second.
release="$PGEMINDEX/release"

# Maybe bail out if a stale time was given. `PGEMSTALETIME` values can be
# stuff like `10 days` or `10d`, `30 minutes` or `30m`. A number with no
# time designator is considered in days. When the value is `never`,
# don't update the index due to staleness in the course of running
# other programs.
if test "$staletime"
then
    case "$staletime" in
    never|none) log update "index is in never auto update mode"
                exit 0;;
    [0-9]*m*)   fargs="-mmin -${staletime%%[!0-9]*}";;
    [0-9]*)     fargs="-mtime -${staletime%%[!0-9]*}";;
    *)          fargs=""
                warn "bad PGSTALETIME value: '$staletime'. ignoring.";;
    esac

    if test -z "$(find "$release" -maxdepth 0 $fargs 2>/dev/null)"
    then log update "release index is missing or stale [> $staletime old]"
    else log update "release index is fresh [< $staletime old]"
         exit 0
    fi
else
    log update "index rebuild forced"
fi

# First thing we do, we create the `PGEMINDEX` directory if it doesn't exist.
test -d "$PGEMINDEX" || {
    log update "creating index directory: $PGEMINDEX"
    mkdir -p "$PGEMINDEX"
}

log update "building release file [$release+]"

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
gem list --no-installed --remote --all                      |

# Now turn it into something that's easy to use with stream tools like
# `grep(1)`, `sed(1)`, `cut(1)`, `join(1)`, etc.
sed -e "s/^\($GEMNAME_PATTERN\) (\(.*\))$/GEM \1 \2/"       \
    -e 's/,//g'                                             |

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
# This is slow but it'll have to do for now. We should be able to do the same
# fairly easily with `sed(1)` or `awk(1)` but I'm not familiar with any
# approaches.
while read leader name versions
do
    if test "$leader" = "GEM"
    then
        for ver in $versions
        do echo "$name $ver"
        done
    else
        warn "malformed input from \`gem list': $leader $name $versions"
    fi
done > "$release+"

# The Release Diff
# ----------------

# We wrote the new index to separate file, so we can take a quick diff
# now. We can show the diff directly, which is awesome, but this could also
# be used to roll back and update (`patch -R`) if something goes wrong.
#
# We also don't care that much if this doesn't work due to, e.g.
# `diff(1)` not being availble.
log update "building release diff [$release-diff+]"

(diff -u "$release" "$release+" 2>&1 && true) \
> "$release-diff+"

# Write a list of new packages to stdout if the verbose flag was given.
$verbose && {
    echo "# New packages:"
    grep '^+' < "$release-diff+"   |
    grep -v '^++'                  |
    cut -c2-
}

# The Recent Release Index
# ------------------------

# The recent release index contains only the most recent versions of
# release packages but otherwise identical to the `release` file.
log update "building recent release index [$release-recent+]"

# Start out by flipping the `<package> <vers>` fields around so that
# `<version>` is the leader. This lets us use `uniq(1)`'s ignore option.
sed 's@^\([! ]*\) \(.*\)@\2 \1@' < "$release+" |

# Okay we can feed this directly to uniq(1) because the big index is
# reverse sorted by version (most recent first). Only the first line
# for each package is output, which is great because that's the most
# recent version
uniq -f 1                                      |

# Flip `<package>` and `<version>` back the way they came.
#
# Seem crazy to do all this? Doesn't matter. It's fast as shit. 95% of the time
# is spent pulling the index file off the network.
sed 's@^\([! ]*\) \(.*\)@\2 \1@'               \
> "$release-recent+"


# Commit
# ------

# Move the new index files into place.
log update "committing new release index files..."
for file in "$release-diff" "$release-recent" "$release"
do  mv "$file+" "$file"
done
log update "index rebuild complete"

# Careful now.
:
