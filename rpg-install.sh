#!/bin/sh
set -e
. pgem-sh-setup

[ "$*" ] || set -- '--help'; ARGV="$@"
USAGE '${PROGNAME} <package> [<version>...]
Install package into pgem environment.'

name="$1"
vers="${2:->=0}"

[ "$name" ] || helpthem

# Usage: pgem_ln <source> <dest>
# Attempt to hard link <dest> to <source> but fall back to cp(1) if
# you're crossing file systems or the ln fails otherwise.
pgem_ln () {
    if ln -f "$1" "$2"
    then notice "$2 [ln]"
    else notice "$2 [cp]"
         cp "$1" "$2"
    fi
}

# Recursive file hierarchy copy routine. Attempts to hardlink files
# and falls back to normal copies.
pgem_install_dir () {
    local src="$1" dest="$2" manifest="$3"
    mkdir -p "$dest"
    for file in "$1"/*
    do
        if test -f "$file"
        then # link dest to source
             pgem_ln "$file" "$dest/$(basename $file)"
             echo "$dest/$(basename $file)" >> "$manifest"

        elif test -d "$file"
        then # recurse into directories
             pgem_install_dir "$file" "$dest/$(basename $file)" "$manifest"

        else warn "unknown file type: $file"
             return 1
        fi
    done
    return 0
}

notice "$name $vers installation commencing ..."

# Fetch the gem into the cache.
gemfile=$(pgem-fetch $name $vers)
gemname=$(basename $gemfile .gem)
gemvers=${gemname##*-}

# Install all dependencies
pgem-deps "$gemfile" |
xargs -n 2 pgem install

# Unpack the gem into the packages area if its not already there
test -d "$PGEMPACKS/$gemname" || {
    notice "unpacking $gemfile into $PGEMPACKS"
    mkdir -p "$PGEMPACKS"
    cd "$PGEMPACKS"
    gem unpack "$gemfile" >/dev/null
}

# Get the manifest file going.
dbdir="$PGEMDB/$name"
manifest="$dbdir/$gemvers"

# Check if the package already has an installed version
test -e "$dbdir/active" && {
    curvers=$(readlink $dbdir/active)
    if pgem-version-test -q "$curvers" "$vers"
    then notice "$name $curvers is installed and current"
         exit 0
    else notice "$name $curvers is installed but $gemvers requested"
         unlink "$dbdir/active"
    fi
}

mkdir -p "$dbdir"
echo "# $(date)" > "$manifest"
ln -sf "$gemvers" "$dbdir/installing"

# Go into the unpackaged package dir to make installing a bit easier.
cd "$PGEMPACKS/$gemname"

# Extension Library Files
# -----------------------

# Build extension libraries if they exist. Bail out if the build fails.
exts="$(pgem-build "$(pwd)")" || {
    warn "extension failed to build"
    exit 1
}

# Install any extensions to `PGEMLIB`. This is kind of tricky. We should
# be running `make` in the extension directory but I haven't had time to
# make it work right so just pull the prefix out of the `Makefile` and
# install the shared libs manually.
test -n "$exts" && {
    mkdir -p "$PGEMLIB"
    echo "$exts" |
    while read dl
    do
        # make install sitearchdir=/lib
        prefix=$(
            grep '^target_prefix.=' "$(dirname $dl)/Makefile" |
            sed 's/^target_prefix *= *//'
        )
        dest="${PGEMLIB}${prefix}/$(basename $dl)"
        pgem_ln "$dl" "$dest"
        echo "$dest" >> "$manifest"
    done
}

# Ruby Library Files
# ------------------

# Recursively install all library files into `PGEMLIB`.
test -d lib && {
    mkdir -p "$PGEMLIB"
    pgem_install_dir lib "$PGEMLIB" "$manifest"
}

# Ruby Executables
# ----------------

# Write executable scripts into `PGEMBIN` and rewrite shebang lines.
test -d bin && {
    mkdir -p "$PGEMBIN"
    for file in bin/*
    do  dest="$PGEMBIN/$(basename $file)"
        notice "$dest [!]"
        sed "s@^#!.*ruby.*@#!$(ruby_command)@" \
            < "$file" \
            > "$dest"
        chmod 0755 "$dest"
        echo "$dest" >> "$manifest"
    done
}

# Manpages
# --------

# Install any manpages included with the package into `PGEMMAN`. Make
# sure files are being installed under the prescribed hierarchy.
test -d man && {
    for file in man/*
    do
        if test -f "$file" && expr "$file" : '.*\.[0-9]' >/dev/null
        then
            section=${file##*\.}
            dest="$PGEMMAN/man$section/$(basename $file)"
            mkdir -p "$PGEMMAN/man$section"
            pgem_ln "$file" "$dest"
            echo "$dest" >> "$manifest"
        fi
    done
}


# Mark this package as active
unlink "$dbdir/installing"
ln -sf "$gemvers" "$dbdir/active"
