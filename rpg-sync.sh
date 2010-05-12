#!/bin/sh
# The `rpg-sync` program is responsible for building the remote package
# index and keeping it up to date. The package index is a set of simple text
# files kept under the `RPGINDEX` directory. They include basic information
# on all gems available at [rubygems.org](http://rubygems.org) and are
# optimized for use with utilities like `grep(1)`, `sed(1)`, and `join(1)`.
#
# `rpg-sync` has two modes of operation:
#
#   1. Someone runs `rpg-sync` directly to bring the package index in sync
#      with the remote repository. If the command completes successfully,
#      the index is guaranteed to be up to date with the repository.
#
#   2. Some other rpg program (like `rpg-upgrade` or `rpg-list`) executes
#      `rpg-sync -s` before performing an operation on the index. In this
#      mode, `rpg-sync` attempts to determine if the index is overly stale
#      (based on the `RPGSTALETIME` option) and may or may not perform an
#      sync.
#
# Philosophy on Automatic Index Sync
# ----------------------------------
#
# Generally speaking, rpg's philosophy is that the user should control
# when the package index is synchronized. The primary reason for this is that
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
# configuration and can be customized to get any behavior along the spectrum.
# By default, the package index is automatically synchronized when it's more
# than two weeks old:
#
#     # auto sync the package index when it's more than 14 days old
#     RPGSTALETIME=14d
#
# Setting the stale time to `0`, causes the index to be synchronized before
# performing any operation that involves remote packages. This is closest to
# the `gem` commands behavior:
#
#     # keep the package index in sync
#     RPGSTALETIME=0
#
# Finally, automatic sync can be disabled completely with:
#
#     # never auto sync the package index
#     PGSTALETIME=never
#
# See the stale time code below for more information on acceptable values.

set -e
. rpg-sh-setup

ARGV="$@"
USAGE '${PROGNAME} [-v] [-m <mins>|-d <days>|-s]
Create or sync the remote package index. Maybe.

Options
  -d <days>             Do nothing if db is less than <days> days old
  -m <mins>             Do nothing if db is less than <mins> minutes old
  -s                    Do nothing if db is less than $RPGSTALETIME old
  -F                    Strict failures when package index cannot be updated
  -v                    Write newly available packages to stdout after updating

The -s option is used by various rpg commands when a sync may be
necessary. Its default stale time can be configured by setting the
RPGSTALETIME option in ~/.rpgrc or /etc/rpgrc.'

verbose=false
staletime=
strict=false
while getopts svFm:d: opt
do
    case $opt in
    v)   verbose=true;;
    m)   staletime="$OPTARG min";;
    d)   staletime="$OPTARG day";;
    F)   strict=true;;
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
# don't sync the index due to staleness in the course of running
# other programs.
if test "$staletime"
then
    case "$staletime" in
    never|none) notice "index is in never auto sync mode"
                exit 0;;
    [0-9]*m*)   fargs="-mmin -${staletime%%[!0-9]*}";;
    [0-9]*)     fargs="-mtime -${staletime%%[!0-9]*}";;
    *)          fargs=""
                warn "bad RPGSTALETIME value: '$staletime'. ignoring.";;
    esac

    if test -z "$(find "$release" -maxdepth 0 $fargs 2>/dev/null)"
    then notice "release index is missing or stale [> $staletime old]"
         if test -f "$release"
         then heed "package index is stale [> $staletime old]. retrieving now."
         else heed "package index not found. retrieving now."
         fi
    else notice "release index is fresh [< $staletime old]"
         exit 0
    fi
else
    heed "retrieving package index: $RPGSPECSURL"
fi

# First thing we do, we create the `RPGINDEX` directory if it doesn't exist.
test -d "$RPGINDEX" || {
    notice "creating index directory: $RPGINDEX"
    mkdir -p "$RPGINDEX"
}

notice "building release file: $release"

# Fetching and Formatting The Spec Index
# --------------------------------------

{

# Fetch the latest specs file from rubygems.org.
curl -sL "$RPGSPECSURL"                     |

# Decompress.
gzip -dc -                                  |

# Now turn this mess of Marshal data into something we can deal with using
# `rpg-parse-index`. See that file for more info on the `specs.gz` file
# format and the output from `rpg-parse-index`.
rpg-parse-index                             |

# We only want packages with a "ruby" platform. This may be too aggressive a
# filter but seems to work fine in 99.9% of cases.
grep ' ruby$'                               |

# We don't need the platform, yet. Grab only the `<name>` and `<version>`
# fields. After `cut`, our stream text looks like this:
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
# One line per package and package version. Output is sorted on package name
# and then reverse by version.
#
# Write that out to our staged release file so we can pass over it a bit.
cut -d ' ' -f 1,2

} > "$release+" 2>/dev/null

# There's a chance that `curl` or `gzip` or something else in the above
# pipeline will have failed. `set -e` won't catch that since it's not the
# last command in the pipeline. Detect it by checking the contents of the
# file and bail if there's nothing there. Exit with failure when the strict
# option (-F) was given and also when the index doesn't already exist.
if test -z "$(head -1 "$release+" 2>/dev/null)"
then
    if   $strict || ! test -f "$release"
    then heed "could not retrieve package index. failing."
         exit 1
    else heed "could not retrieve package index. using existing."
         exit 0
    fi
fi

# The Release Diff
# ----------------

# We wrote the new index to a separate file, so we can take a quick diff
# now. We can show the diff directly, which is awesome, but this could also
# be used to roll back an update (`patch -R`) if something goes wrong.
#
# We also don't care that much if this doesn't work due to, e.g.
# `diff(1)` not being available.
notice "building release diff: $release-diff"

(diff -u "$release" "$release+" 2>&1 && true) > "$release-diff+"

# Write a list of new packages to stdout if the verbose flag was given.
if $verbose
then echo "# New packages:"
     grep '^+' < "$release-diff+"   |
     grep -v '^++'                  |
     cut -c2-
fi

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
do mv "$file+" "$file"
done
notice "index rebuild complete"

# Write some stats on the number of packages available, both total and
# newly available since the last sync.
packs="$(grep -c . <"$release-recent" || true)"
new="$(grep -e '^+[^+]' "$release-diff" | { grep -c . || true; })"
message="complete. $packs packages available."
test "$new" -gt 0 && message="$message +$new since last sync."
heed "$message"

# Careful now.
:
