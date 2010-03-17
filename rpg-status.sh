#!/bin/sh
# The `rpg-status` program compares installed packages to packages available
# in the remote repository. It's useful for determining the versions of
# packages and how they relate to same named packages available in the
# repository.
#
# This is somewhere between a plumbing and porcelain command. It's useful
# for building other programs and provides options for generating easily
# parseable output. However, it's also useful to humans and the default
# output is optimize for human consumption.
set -e
. rpg-sh-setup

ARGV="$@"
USAGE '${PROGNAME} [-u] [-p] [<glob>...]
Show status of installed packages vs available packages.

Options
  -a               Include all packages, not just installed, packages
  -u               Sync the available package index before running
  -p               Generate more parseable output

Passing one or more <glob>s filters the list to matching packages.'

sync=false
parsey=false
joiner=
while getopts apu opt
do
    case $opt in
    a)   joiner="-a2";;
    u)   sync=true;;
    p)   parsey=true;;
    ?)   helpthem;
         exit 2;;
    esac
done
shift $(( $OPTIND - 1 ))

# Sync the package index. Force the sync right now if we were given
# the `-u` arg; otherwise, maybe update it based on the configured stale
# time.
if $sync
then  rpg-sync
else  rpg-sync -s
fi

# Parsey Mode
# -----------

# The `-p` argument causes the output to be varied slightly. These variables
# control how output lines are formatted and what symbols they use. In
# parsey mode, simple alpha characters are used since those are a bit easier
# to `grep` / `sed` without escaping.
if $parsey
then  st_outdate="o"
      st_up2date="u"
      st_missing="x"
      st_format="%s %s %s %s\n"
else
      st_up2date=" "
      st_outdate="*"
      st_missing="X"
      st_format="%1s %-35s %-12s %-12s\n"
fi

# Package Selection / Glob Filter
# -------------------------------

# Default to matching all installed packages -- or all available packages
# when `-a` was given -- if no `<glob>`s were given.
[ "$*" ] || set -- '*'

# Build glob BREs for filtering the remote package list. The local package
# list is filtered by `rpg-package-list` so we don't need to worry about that
# side.
#
# If there's only one glob and it's `*`, don't do any `grep` nonsense,
# just throw a `cat` in there.
if   [ "$*" = '*' ]
then remotefilter="cat"
else remotefilter="grep"
     for glob in "$@"
     do  glob=$(
           echo "$glob"              |
           sed -e 's@\*@[^ ]*@g'     \
               -e 's/\?/[^ ]/g'      \
         )
         remotefilter="$remotefilter -e '$glob '"
     done
fi

notice "remote filter: $remotefilter"

# Main Pipeline
# -------------

# Kick off a pipeline by listing installed packages. The output from
# `rpg-package-list` looks something like this:
#
#
#     RedCloth                       4.2.3
#     abstract                       1.0.0
#     actionmailer                   2.3.5
#     actionpack                     2.3.5
#     activerecord                   2.3.5
#     activeresource                 2.3.5
#     activesupport                  2.3.5
#     ansi                           1.1.0
#     builder                        2.1.2
#     classifier                     1.3.1
#     coffee-script                  0.3.2
#     ...
#
# So we have the `<package> <version>` pairs separated by whitespace,
# basically.
rpg-package-list -x "$@"                           |

# Okay ...
#
# This is going to blow your mind.
#
# Use `join(1)` to perform a relational join between the installed
# package list and the recent release list from the index. The recent
# release list looks nearly identical, format-wise, to the installed
# list.
#
# There's a few things needed for this to work properly. First, both
# files need to be sorted (as with `sort -b`) on the join field. Here,
# the join field is the `<package>` -- we don't need to specify it
# explicitly on the command line because it's the first field in both
# files.
#
# The stream text that comes out of `join(1)` looks like:
#
#     <package> <installed-version> <available-version>
#
# Without any other options, `join(1)` performs an "inner join",
# excluding unpaired lines from output entirely. Which is great because
# that's exactly what we need to determine which packages are out of
# date.
#
# This is a really insanely fast operation because it need only take a
# single pass over each file. It simply walks through each file line by
# line and, because both files are sorted, knows immediately whether the
# lines intersect or are unpairable.
#
# Additional, we selectively enable some of `join(1)`'s other options (`-a`
# and `-e`) for achieving "outer joins" and "full joins" when querying
# against all remote packages.
join -a 1 $joiner                                \
     -o 1.1,1.2,2.2,2.1                          \
     -e '-'                                      \
     - "$RPGINDEX/release-recent"                |

# Grep out remote packages based on our globs. See the *Glob Filter* section
# above for more information.
/bin/sh -c "exec $remotefilter"                  |

# Grep out lines that don't match a package. Also, the regular expression
# is amazing.
grep -v '. - - .'                                |

# All that's left is to read the output from `join` and apply some light
# formatting.
while read package curvers recvers pdup
do
    test "$package" = '-' &&
    package="$pdup"

    if   test "$recvers" = '-'
    then sig="$st_missing"

    elif test "$curvers" = "-"
    then sig="$st_missing"
         curvers="-"

    elif test "$curvers" = "$recvers"
    then sig="$st_up2date"

    else sig="$st_outdate"
    fi

    printf "$st_format" "$sig" "$package" "$curvers" "$recvers"
done
