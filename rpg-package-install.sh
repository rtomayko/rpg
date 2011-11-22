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

# Usage: `installfile <source> <dest>`
#
# Attempt to hard link `<dest>` to `<source>` but fall back to `cp(1)` if
# you're crossing file systems or `ln` fails otherwise.
installfile () {
    if ln -f "$1" "$2" 2>/dev/null
    then notice "$2 [ln]"
    else notice "$2 [cp]"
         cp "$1" "$2"
    fi
}

# Usage: `installdir <source> <dest>`
#
# Recursive file hierarchy copy routine. Attempts to hardlink files
# and falls back to normal copies.
installdir () {
    mkdir -p "$2"
    for file in "$1"/*
    do
        if test -f "$file"
        then # link dest to source
             installfile "$file" "$2/$(basename $file)"
             echo "$2/$(basename $file)"

        elif test -d "$file"
        then # recurse into directories
             installdir "$file" "$2/$(basename $file)"

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
package="$1" version="$2"; shift 2
test "$version" = '=' && { version="$1"; shift; }
packagedir="$RPGDB/$package"

test -d "$packagedir/$version" || {
    warn "package not registered: $package $version"
    exit 1
}

heed "$package $version"

# Fetch the gem into the cache and unpack into the packs area if
# its not already there.
if ! $force && test -d "$RPGPACKS/$package-$version"
then notice "$package $version sources exist. bypassing fetch / unpack."
else rm -rf "$RPGPACKS/$package-$version"
     gemfile=$(rpg-fetch "$package" "$version")
     notice "unpacking $gemfile into $RPGPACKS"
     mkdir -p "$RPGPACKS"
     rpg-unpack -p "$RPGPACKS" "$gemfile" >/dev/null
     rpg-shit-list "$package" "$version" "$RPGPACKS/$package-$version"
fi

# If the package already has an active/installed version, check if it's
# the same as the one we're installing and bail if so. Otherwise unlink
# the active version and install over it for now.
test -e "$packagedir/active" && {
    activevers=$(readlink $packagedir/active)
    if test "$activevers" = "$version"
    then
        if $force
        then notice "$package $version is current; reinstalling due to -f"
             unlink "$packagedir/active"
        else notice "$package $version is current; skipping package install"
             exit 0
        fi
    else notice "$package $activevers is installed but $version requested"
         rpg-uninstall "$package"
    fi
}

# Path to the unpacked package directory.
pack="$RPGPACKS/$package-$version"

# Symlink the `installing` file to the version directory. This will let us
# detect in progress or failed installations.
ln -sf "$version" "$packagedir/installing"

# Anything written to standard output within the main install block is
# written to the install manifest. The manifest should include full paths to
# all files installed
manifest="$packagedir/$version/manifest"
{
    echo "# $package $version ($(date))"

    # Extension Libraries
    # -------------------

    # Build extension libraries if they exist. Bail out if the build fails.
    exts="$(rpg-build "$pack")" || {
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
            prefix=$(sed -n 's/^target_prefix *= *//p' "$(dirname $dl)/Makefile")
            test "$prefix" = "/ext" && prefix=""
            dest="${RPGLIB}/${RUBYARCH}${prefix}/$(basename $dl)"
            mkdir -p "${RPGLIB}/${RUBYARCH}${prefix}"
            installfile "$dl" "$dest"
            echo "$dest"
        done
    }

    # Ruby Library Files
    # ------------------

    # Recursively install all library files into `RPGLIB`.
    #
    # A big majority of packages have a single lib directory but some use an
    # alternative libdir (ruby-debug) and it's also possible to have multiple
    # lib directories. Use the `require_paths` gemspec value to determine lib
    # sub-directories, ignoring certain incorrect values (`test`, `ext`, `spec`,
    # etc.).

    libdirs=$(cat "$packagedir/$version/require_paths" 2>&1)
    : ${libdirs:=lib}

    for libdir in $libdirs
    do
        test "$libdir" = "ext"  && continue
        test "$libdir" = "test" && continue
        test "$libdir" = "spec" && continue

        if test -d "$pack/$libdir"
        then mkdir -p "$RPGLIB"
             installdir "$pack/$libdir" "$RPGLIB"
        else notice "warning: $package libdir '$libdir' does not exist"
        fi
    done

    # Ruby Executables
    # ----------------

    bindir=$(cat "$packagedir/$version/bindir" 2>&1)
    : ${bindir:=bin}

    # Write executable scripts into `RPGBIN` and rewrite shebang lines.
    test -d "$pack/$bindir" && {
        mkdir -p "$RPGBIN"
        for file in "$pack/$bindir"/*
        do  dest="$RPGBIN/$(basename $file)"
            notice "$dest [!]"
            sed "s@^#!.*ruby.*@#!$(ruby_command)@" <"$file" >"$dest"
            chmod 0755 "$dest"
            echo "$dest"
        done
    }

    # Manpages
    # --------

    # Install any manpages included with the package into `RPGMAN`. Make
    # sure files are being installed under the prescribed hierarchy.
    test -d "$pack/man" && {
        for file in "$pack/man"/*
        do
            if  test -f "$file" &&
                expr "$file" : '.*\.[0-9][0-9A-Za-z]*$' >/dev/null
            then
                section=${file##*\.}
                dest="$RPGMAN/man$section/$(basename $file)"
                mkdir -p "$RPGMAN/man$section"
                installfile "$file" "$dest"
                echo "$dest"
            fi
        done
    }

} > "$manifest"

# Mark this package as active
unlink "$packagedir/installing"
ln -sf "$version" "$packagedir/active"
