#!/bin/sh
#/ Usage: pgem-update
#/ Rebuild the package database.
set -e

. pgem-sh-setup

mkdir -p "$PGEMDB"
index="$PGEMDB/gemdb"

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
(diff -u "${index}" "${index}+" && true) > "$PGEMDB/diff"
cat "$PGEMDB/diff"

# Move the new index into place
mv "${index}+" "${index}"
