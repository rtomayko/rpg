#!/bin/sh
set -e
. rpg-sh-setup

[ "$*" ] || set -- '--help'; ARGV="$@"
USAGE '${PROGNAME} <package> [<version>...]
Install package into rpg environment.'

name="$1"
vers="${2:->=0}"

[ "$name" ] || helpthem

# Usage: rpg_ln <source> <dest>
# Attempt to hard link <dest> to <source> but fall back to cp(1) if
# you're crossing file systems or the ln fails otherwise.
rpg_ln () {
    if ln -f "$1" "$2"
    then notice "$2 [ln]"
    else notice "$2 [cp]"
         cp "$1" "$2"
    fi
}

# Recursive file hierarchy copy routine. Attempts to hardlink files
# and falls back to normal copies.
rpg_install_dir () {
    local src="$1" dest="$2" manifest="$3"
    mkdir -p "$dest"
    for file in "$1"/*
    do
        if test -f "$file"
        then # link dest to source
             rpg_ln "$file" "$dest/$(basename $file)"
             echo "$dest/$(basename $file)" >> "$manifest"

        elif test -d "$file"
        then # recurse into directories
             rpg_install_dir "$file" "$dest/$(basename $file)" "$manifest"

        else warn "unknown file type: $file"
             return 1
        fi
    done
    return 0
}

notice "$name $vers installation commencing ..."

# Fetch the gem into the cache.
gemfile=$(rpg-fetch $name $vers)
gemname=$(basename $gemfile .gem)
gemvers=${gemname##*-}

# Install all dependencies
rpg-deps "$gemfile" |
xargs -n 2 rpg install

# Unpack the gem into the packages area if its not already there
test -d "$RPGPACKS/$gemname" || {
    notice "unpacking $gemfile into $RPGPACKS"
    mkdir -p "$RPGPACKS"
    cd "$RPGPACKS"
    gem unpack "$gemfile" >/dev/null
}

# Get the manifest file going.
dbdir="$RPGDB/$name"
manifest="$dbdir/$gemvers"

# Check if the package already has an installed version
test -e "$dbdir/active" && {
    curvers=$(readlink $dbdir/active)
    if rpg-version-test -q "$curvers" "$vers"
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
cd "$RPGPACKS/$gemname"

# Extension Library Files
# -----------------------

# Build extension libraries if they exist. Bail out if the build fails.
exts="$(rpg-build "$(pwd)")" || {
    warn "extension failed to build"
    exit 1
}

# Install any extensions to `RPGLIB`. This is kind of tricky. We should
# be running `make` in the extension directory but I haven't had time to
# make it work right so just pull the prefix out of the `Makefile` and
# install the shared libs manually.
test -n "$exts" && {
    mkdir -p "$RPGLIB"
    echo "$exts" |
    while read dl
    do
        # make install sitearchdir=/lib
        prefix=$(
            grep '^target_prefix.=' "$(dirname $dl)/Makefile" |
            sed 's/^target_prefix *= *//'
        )
        dest="${RPGLIB}${prefix}/$(basename $dl)"
        rpg_ln "$dl" "$dest"
        echo "$dest" >> "$manifest"
    done
}

# Ruby Library Files
# ------------------

# Recursively install all library files into `RPGLIB`.
test -d lib && {
    mkdir -p "$RPGLIB"
    rpg_install_dir lib "$RPGLIB" "$manifest"
}

# Ruby Executables
# ----------------

# Write executable scripts into `RPGBIN` and rewrite shebang lines.
test -d bin && {
    mkdir -p "$RPGBIN"
    for file in bin/*
    do  dest="$RPGBIN/$(basename $file)"
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

# Install any manpages included with the package into `RPGMAN`. Make
# sure files are being installed under the prescribed hierarchy.
test -d man && {
    for file in man/*
    do
        if test -f "$file" && expr "$file" : '.*\.[0-9]' >/dev/null
        then
            section=${file##*\.}
            dest="$RPGMAN/man$section/$(basename $file)"
            mkdir -p "$RPGMAN/man$section"
            rpg_ln "$file" "$dest"
            echo "$dest" >> "$manifest"
        fi
    done
}


# Mark this package as active
unlink "$dbdir/installing"
ln -sf "$gemvers" "$dbdir/active"
