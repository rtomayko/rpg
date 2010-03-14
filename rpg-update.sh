#!/bin/sh
# The `rpg-update` program is responsible for building the remote package
# index and keeping it up to date. The package index is a set of simple text
# files kept under the `RPGINDEX` directory. They include basic information
# on all gems available at [rubygems.org](http://rubygems.org) and are
# optimized for use with utilities like `grep(1)`, `sed(1)`, and `join(1)`.
#
# `rpg-update` has two modes of operation:
#
#   1. Someone runs `rpg-update` directly to bring the package index in sync
#      with the remote repository. If the command completes successfully,
#      the index is guaranteed to be up to date with the repository.
#
#   2. Some other rpg program (like `rpg-upgrade` or `rpg-status`) executes
#      `rpg-update -s` before performing an operation on the index. In this
#      mode, `rpg-update` attempts to determine if the index is overly stale
#      (based on the `RPGSTALETIME` option) and may or may not perform an
#      update.
#
# Philosophy on Automatic Index Updates
# -------------------------------------
#
# Generally speaking, rpg's philosophy is that the user should control
# when the package index is updated. The primary reason for this is that
# rpg should be *fast* *fast* *fast* -- *fast* like a rocket missile -- unless
# specifically told not to be. Network operations destroy any chance at
# predictable performance.
#
# Rubygems's `gem` command has nearly the opposite philosophy. It tries
# hard to make sure it's working with current data consistent with
# the package repository when performing operations involving remote packages
# (like `gem list --remote`, `gem outdated`, or `gem install`). This has
# obvious benefits: running `gem install foo` is guaranteed to install the
# most recent version of `foo` at the time the command is run. Similarly,
# `gem outdated` is guaranteed to show the most recent package versions
# available. This is convenient behavior because it removes the
# responsibility of managing the package index from the user. The downside
# is wildly unpredictable performance in most commands.
#
# rpg attempts to strike a balance between these two extremes in its default
# configuration and can be customize to get any behavior along the spectrum.
# By default, the package index is automatically updated when it's more than
# one day old:
#
#     # auto update the package index when it's more than 1 day old
#     RPGSTALETIME=1d
#
# Setting the stale time to `0`, causes the index to be updated before
# performing any operation that involves remote packages. This is closest to
# the `gem` commands behavior:
#
#     # keep the package index in sync
#     RPGSTALETIME=0
#
# Finally, automatic updates can be disabled completely with:
#
#     # never auto update the package index
#     PGSTALETIME=never
#
# See the stale time code below for more information on acceptable values.

set -e
. rpg-sh-setup

ARGV="$@"
USAGE '${PROGNAME} [-v] [-m <mins>|-d <days>|-s]
Create or update the remote package index. Maybe.

Options
  -d <days>             Do nothing if db is less than <days> days old
  -m <mins>             Do nothing if db is less than <mins> minutes old
  -s                    Do nothing if db is less than $RPGSTALETIME old
  -v                    Write newly available packages to stdout after updating

The -s option is used by various rpg commands when an update may be
neccassary. Its default stale time can be configured by setting the
RPGSTALETIME option in ~/.rpgrc or /etc/rpgrc.'

verbose=false
staletime=
while getopts m:d:vs opt
do
    case $opt in
    v)   verbose=true;;
    m)   staletime="$OPTARG min";;
    d)   staletime="$OPTARG day";;
    s)   staletime="$RPGSTALETIME";;
    ?)   helpthem;;
    esac
done
shift $(($OPTIND - 1))

# Bail out if we have more args.
[ "$*" ] &&
{ warn "invalid argument: $*"; exit 2; }

# The Release Index
# -----------------
#
# The `release` file includes all versions of all packages. One line per
# `<package> <version>` pair.

# Here's where the file is kept. There's also `release-recent` and
# `release-diff` files, which we'll see in a second.
release="$RPGINDEX/release"

# Maybe bail out if a stale time was given. `RPGSTALETIME` values can be
# stuff like `10 days` or `10d`, `30 minutes` or `30m`. A number with no
# time designator is considered in days. When the value is `never`,
# don't update the index due to staleness in the course of running
# other programs.
if test "$staletime"
then
    case "$staletime" in
    never|none) notice "index is in never auto update mode"
                exit 0;;
    [0-9]*m*)   fargs="-mmin -${staletime%%[!0-9]*}";;
    [0-9]*)     fargs="-mtime -${staletime%%[!0-9]*}";;
    *)          fargs=""
                warn "bad PGSTALETIME value: '$staletime'. ignoring.";;
    esac

    if test -z "$(find "$release" -maxdepth 0 $fargs 2>/dev/null)"
    then notice "release index is missing or stale [> $staletime old]"
    else notice "release index is fresh [< $staletime old]"
         exit 0
    fi
else
    notice "index rebuild forced"
fi

# First thing we do, we create the `RPGINDEX` directory if it doesn't exist.
test -d "$RPGINDEX" || {
    notice "creating index directory: $RPGINDEX"
    mkdir -p "$RPGINDEX"
}

notice "building release file [$release+]"

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
gem list --no-installed --remote --all                       |

# Now turn it into something that's easy to use with stream tools like
# `grep(1)`, `sed(1)`, `cut(1)`, `join(1)`, etc.
sed -e "s/^\($GEMNAME_PATTERN\) (\(.*\))$/GEM \1 \2/"        \
    -e 's/,//g'                                              |

# Make sure the file is sorted on package names in `sort -b` order. This is
# important for `join(1)` and `uniq(1)`.
sort -b -k 1,1 -k2,2rn                                       |

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
notice "building release diff [$release-diff+]"

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
notice "building recent release index [$release-recent+]"

# Since the big release index comes down from the server with versions
# in reverse order (most recent first), we can push it through `sort(1)`
# using the `<package>` field as the key (only) and have it uniq the list
# down for us. `sort -u` uses the first line with a distinct `<package>`
# name and discards adjacent matches, leaving us with a sorted list of
# the most recent versions.
sort -u -b -k 1,1 < "$release+" > "$release-recent+"

# Commit
# ------

# Move the new index files into place.
notice "committing new release index files..."
for file in "$release-diff" "$release-recent" "$release"
do  mv "$file+" "$file"
done
notice "index rebuild complete"

# Careful now.
: