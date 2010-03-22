#!/bin/sh
# The `rpg-unpack` program reads the gem file's internal tar-based structure
# and either untars into a new directory or writes the data segment's tar
# stream to stdout.
#
# Gem files are more or less normal tarballs that looks like this:
#
#     $ tar tv < sinatra-0.9.6.gem
#     -rw-r--r-- wheel/wheel  117190 1969-12-31 16:00:00 data.tar.gz
#     -rw-r--r-- wheel/wheel    1225 1969-12-31 16:00:00 metadata.gz
#
# The `metadata.gz` file is a gzip compressed YAML gemspec. The
# `data.tar.gz` holds the unprefixed files.
#
# There's also an older gem format apparently, but I'm hoping to not have to
# deal with it.
set -e
. rpg-sh-setup

USAGE '${PROGNAME} [-p <path>|-P] <package> [<version>]
       ${PROGNAME} -c [-m] <package> [<version>]
Unpack a gem file to disk or as a tar stream on standard output.

Options
  -p <path>        Unpack under <path> instead of the working directory.
  -P               Unpack under RPGPACKS instead of the working directory.
  -c               Write gem data tar stream to stdout. Do not create any files.
  -m               Change the behavior of the -c option. Write gem metadata
                   segment instead of the data segment.

The <package> may be a package name or path to a gem file on disk. When a
package name is given, the <version> may also be specified.'
workdir=.
filter=untar
segment=data.tar.gz
while getopts cmPp: opt
do
    case $opt in
    p)   workdir="$OPTARG";;
    P)   workdir="$RPGCACHE";;
    c)   filter=cat;;
    m)   segment=metadata.gz;;
    ?)   helpthem
         exit 2;;
    esac
done
shift $(( $OPTIND - 1 ))

# Piping the gemspec through tar isn't going to help anyone. Fail fast.
if test $segment = "metadata.gz" -a $filter = "untar"
then warn "illegal argument: -m must be used with -c"
     exit 2
fi

# Check whether a gem file or package name was given.
if expr "$1" : '.*\.gem' >/dev/null
then file="$1"
     test -r "$file" || {
        warn "gem file can not be read: $file"
        exit 1
     }
else file=$(rpg-fetch "$1" "${2:->0}")
fi

# Extract the package name and version from the gem file.
basename=$(basename "$file" .gem)
package=${basename%-*}
version=${basename##*-}

# This takes the gem's `data.tar` stream on stdin and untars it into a
# newly created directory after the gem name. When the `-c` option is not
# given, the gem tar stream is piped through here.
untar () {
    mkdir "$workdir/$package-$version"
    tar -xom -C "$workdir/$package-$version" -f - 2>/dev/null
}

notice "$file -> $workdir/$package-$version"

# Pipe the gem directly into `tar` and extract only the file/segment we're
# interested in (the `-O` option causes the file to be written to stdout
# instead of to disk). Next, pipe that thing through gzip to decompress and
# finally into whatever filter was configured (`cat` with the `-c` option or
# our `untar` function above otherwise).
tar -xOmf - $segment < "$file" 2>/dev/null |
gzip -dc                                   |
$filter

# Write the path to the unpacked package directory on standard output.
if test "$filter" = "untar"
then echo "$workdir/$package-$version"
fi

true
