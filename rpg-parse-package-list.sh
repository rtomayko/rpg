#!/bin/sh
# Parses a package list given in argv or piped in standard input (or both)
# and writes a formatted package list to standard output. This is used by
# most commands that accept multiple package arguments to get consistent
# behavior.
#
# A variety of argument styles are supported:
#
#     $ rpg-parse-package-list rdiscount -v '>=1.8.7' sinatra/1.0
#     rdiscount >= 1.8.7
#     sinatra = 1.0
#
# The output format is:
#
#     <package> <verspec> <version>
#
# When a `~>` version specifier is given, it's converted into two specifiers
# in output:
#
#     $ rpg-parse-package-list rails '~> 2.2.4'
#     rails >= 2.2.4
#     rails < 2.3
#
set -e
. rpg-sh-setup

ARGV="$@"
USAGE '${PROGNAME} [<package>]
Parse a package list and output in standard format.'

# These variables are used to keep the current package and version.
package=
verspec=
vers=

# Parse argv
parse_packages () {
    # Run over arguments adding packages as needed.
    for arg in $(cat)
    do
        case "$arg" in
           -v|--version) :;;
                     -*) warn "invalid argument: '$arg'";
                         exit 2;;
              [\>\<=~]*) verspec="$arg";;
                  *.gem) write_package; package="$arg";;
                    *.*) vers="$arg";;
       [0-9]|[0-9][0-9]|[0-9][0-9][0-9]) vers="$arg";;
          [A-Za-z0-9_]*) write_package; package="$arg";;
                      *) warn "invalid argument: '$arg'";
                         exit 2;;
        esac
    done
    write_package
}

# Write a `<package> <version>` pair to standard output and reset the
# `package`, `verspec`, and `vers` variables.
write_package () {
    test "$package" || return 0

    # Use `>=0` if no version was given
    test "$vers" || {
        verspec='>='
        vers='0'
    }

    # Replace `~> 0.3` with `>= 0.3 < 0.4`.
    if test "$verspec" = '~>'
    then echo "$package >= $vers"
         echo "$package <= ${vers%.*}.99999999"
    else
         echo "$package ${verspec:-=} ${vers:-0}"
    fi

    # Reset variables and start over.
    package=
    verspec=
    vers=
}


# Massage input to make option parsing a bit easier. Substitutions are:
#
#   * `-v1.2.3` turns into `-v 1.2.3`
#   * `--version=123` turns into `--version 123`
#   * `>=0.3.1` turns into `>= 0.3.1`
#   * `rails/2.3.4` turns into `rails -v 2.3.4`
#
preformat () {
    sed -e "s/[= ]\{1,\}/$ENEWLINE/g"                      |
    sed -e "s/^-\([a-z]\)\([^ ]\)/-\1$ENEWLINE\2/g"        \
        -e "s@^\([a-z][a-z]*\)/\([0-9.]\)@\1$ENEWLINE\2@g" \
        -e "s/\([><=~]\)\([0-9]\)/\1$ENEWLINE\2/g"
}


# Read package list from stdin if - given
test "$1" = - && {
    shift
    notice "parsing package list items on stdin"
    preformat |
    parse_packages
}

# Now format arguments
notice "parsing package list items in $# arguments"
echo "$@" | preformat | parse_packages
