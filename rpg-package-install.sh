#!/bin/sh
# The `rpg-package-install` program perform the actual installation of files
# into the system installation locations. The `<package>` and `<version>`
# supplied must already be registered in the package database as by invoking
# the `rpg-package-register` program.
#
# If the package is already installed and at the version specified,
# `rpg-package-install` exits immediately with a success exit status. The
# `-f` argument can be used to force the install operations to be performed
# on an already installed program.
set -e
. rpg-sh-setup

[ "$*" ] || set -- '--help'; ARGV="$@"
USAGE '${PROGNAME} [-f] <package> <version> ...
Install a registered package from the database.

This is a low level command. For an install front-end, see rpg-install(1).'

force=false
test "$1" = '-f' && {
    force=true
    shift
}

[ "$1$2" ] || {
    warn "invalid arguments: '$*'";
    exit 2
}

# Utility Functions
# -----------------

# Usage: rpg_ln <source> <dest>
# Attempt to hard link <dest> to <source> but fall back to cp(1) if
# you're crossing file systems or the ln fails otherwise.
rpg_ln () {
    if ln -f "$1" "$2" 2>/dev/null
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

# Package Database Prep
# ---------------------

# Establish our directories in the package database. These should
# have already been created by `rpg-package-register`. If not, bail
# out now since something isn't right.
package="$1";shift
version="$1";shift
test "$version" = '=' && version="$1";shift
packagedir="$RPGDB/$package"

test -d "$packagedir/$version" || {
    warn "package not registered: $package/$version"
    exit 1
}

notice "$package $version"

# Fetch the gem into the cache and unpack into the packs area if
# its not already there.
if test -d "$RPGPACKS/$package-$version"
then notice "sources already exist. bypassing fetch and unpack."
else gemfile=$(rpg-fetch "$package" "$version")
     notice "unpacking $gemfile into $RPGPACKS"
     mkdir -p "$RPGPACKS"
     (cd "$RPGPACKS" && gem unpack "$gemfile" >/dev/null)
fi

# If the package already has an active/installed version, check if its
# the same as the one we're installing and bail if so. Otherwise unlink
# the active version and install over it for now.
#
# TODO handle uninstalling previous package version or fail or something.
test -e "$packagedir/active" && {
    activevers=$(readlink $packagedir/active)
    if test "$activevers" = "$version"
    then
        if $force
        then notice "$package $version is current. reinstalling due to -f"
             unlink "$packagedir/active"
        else notice "$package $version is current. not reinstalling."
             exit 0
        fi
    else notice "$package $activevers is installed but $version requested"
         unlink "$packagedir/active"
    fi
}

# This is our file manifest. We record everything installed in here
# so we know how to uninstall the package. Create/truncate it in case
# it already exists.
#
# TODO if the manifest already exists that means the package was
# previously installed or may currently be installed. Do something with
# that information.
manifest="$packagedir/$version/manifest"
echo "# $(date)" > "$manifest"

# Symlink the `installing` file to the version directory. This will let us
# detect in progress or failed installations.
ln -sf "$version" "$packagedir/installing"

# Go into the unpackaged package dir to make installing a bit easier.
cd "$RPGPACKS/$package-$version"


# Extension Libraries
# -------------------

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
        prefix=$(
            grep '^target_prefix.=' "$(dirname $dl)/Makefile" |
            sed 's/^target_prefix *= *//'
        )
        dest="${RPGLIB}${prefix}/$(basename $dl)"
        mkdir -p "${RPGLIB}${prefix}"
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
    do  if test -f "$file" && expr "$file" : '.*\.[0-9][0-9A-Za-z]*$' >/dev/null
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
unlink "$packagedir/installing"
ln -sf "$version" "$packagedir/active"
