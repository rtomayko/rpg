#!/bin/sh
#/ Usage: pgem <options> command
#/
set -e

# Bring in pgem config
. pgem-sh-setup

# Shift off the first argument to determine the real command:
command="$1"
shift

if $__SHC__
then
    case $command in
    build)         pgem_build "$@";;
    config)        pgem_config "$@";;
    deps)          pgem_deps "$@";;
    env)           pgem_env "$@";;
    fetch)         pgem_fetch "$@";;
    install)       pgem_install "$@";;
    list)          pgem_list "$@";;
    resolve)       pgem_resolve "$@";;
    sh-setup)      true ;;
    uninstall)     pgem_uninstall "$@";;
    update)        pgem_update "$@";;
    version-test)  pgem_version_test "$@";;
    *)             exec pgem-$command "$@";;
    esac
else
    exec "pgem-${command}" "$@"
fi
