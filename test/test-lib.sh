
: ${VERBOSE:=false}

unset CDPATH

cd "$(dirname $0)"
TESTDIR=$(pwd)

test_count=0
successes=0
failures=0

output="$testdir/$(basename "$0" .sh).out"
trap "rm -f $output" 0

succeeds () {
    test_count=$(( test_count + 1 ))
    echo "\$ ${2:-$1}" > "$output"
    eval "( ${2:-$1} )" 1>>"$output" 2>&1
    ec=$?
    if test $ec -eq 0
    then successes=$(( successes + 1 ))
         printf 'ok %d - %s\n' $test_count "$1"
    else failures=$(( failures + 1 ))
         printf 'not ok %d - %s [%d]\n' $test_count "$1" "$ec"
    fi

    $VERBOSE && dcat $output
    return 0
}

fails () {
    if test $# -eq 1
    then succeeds "! $1"
    else succeeds "$1" "! $2"
    fi
}

diag () { echo "$@" | sed 's/^/# /'; }
dcat () { cat "$@"  | sed 's/^/# /'; }
desc () { diag "$@"; }

# setup environment for a fake rpg environment under ./trash
RPGPATH="$TESTDIR/trash"
RPGBIN="$RPGPATH/bin"
RPGLIB="$RPGPATH/lib"
RPGMAN="$RPGPATH/man"
RPGDB="$RPGPATH/db"
RPGINDEX="$RPGPATH/index"
RPGPACKS="$RPGPATH/packs"
RPGCACHE="$RPGPATH/cache"
export RPGPATH RPGBIN RPGLIB RPGMAN RPGDB RPGINDEX RPGPACKS RPGCACHE

RPGSYSCONF=false
RPGUSERCONF=false
RPGTRACE=false
RPGSHOWBUILD=false
RPGSTALETIME='1 day'
RPGSPECSURL="file://$TESTDIR/specs.4.8.gz"
export RPGSYSCONF RPGUSERCONF RPGTRACE RPGSHOWBUILD RPGSTALETIME RPGSPECSURL

# put source directory on PATH so we're running the right rpg commands
PATH="$(dirname $TESTDIR):$PATH"
export PATH

setup () {
    rm -rf "$TESTDIR/trash"
    return 0
}
