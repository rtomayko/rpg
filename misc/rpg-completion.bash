# rpg bash completion

# Turn on extended globbing
shopt -s extglob

_rpg() {
    local cur prev stuff word comm i

    COMPREPLY=()
    cur=${COMP_WORDS[COMP_CWORD]}
    prev=${COMP_WORDS[COMP_CWORD-1]}
    if test "$COMP_CWORD" -gt 2
    then prev2=${COMP_WORDS[COMP_CWORD-2]}
    else prev2=
    fi

    # Run over args and set comm to either "rpg" or the sub-command name.
    i=0
    comm=rpg
    while [ $i -lt $COMP_CWORD ]
    do
        case "${COMP_WORDS[$i]}" in
            rpg)    comm=rpg;;
            -c)     i=$(( i + 1 ));;
            [a-z]*) test "$comm" = rpg && comm="${COMP_WORDS[$i]}"
                    break;;
        esac
        i=$(( i + 1 ))
    done

    case "$comm" in

    # The main rpg command
    rpg)
        if test "$prev" = '-c'
        then : # complete filename
        else
            case "$cur" in
                -*) COMPREPLY=( $(compgen -W "-c -v -q -x --help" -- "$cur") );;
                 *) _rpg_complete commands "$cur";;
            esac
        fi
        ;;

    # The install and prepare commands
    install|prepare)
        case "$cur" in
        # an option argument
        -*)
            case "$prev" in
            -f|-s|install|prepare)
                COMPREPLY=( $(compgen -W "-f -s --help" -- "$cur") );;
            *)  COMPREPLY=( $(compgen -W "-v" -- "$cur") );;
            esac
            ;;

        # a package name
        [A-Za-z]*)
            case "$prev" in
            -s) ;; # session names
            -v) # package versions
                _rpg_complete versions "$prev2" "$cur";;
             *) _rpg_complete available "$cur";;
            esac
            ;;

        # a package version
        [0-9]*)
            case "$prev" in
            -s) ;;
            -v) _rpg_complete versions "$prev2" "$cur";;
             *) _rpg_complete versions "$prev"  "$cur";;
            esac
            ;;

        # no argument or something really crazy
        *)
            case "$prev" in
            -s) ;; # session name
            -v) _rpg_complete versions "$prev2" "$cur";;
            *)  _rpg_complete available "$cur";;
            esac;;

        esac
        ;;

    # The status command
    status)
        _rpg_complete available "$cur";;

    package-install)
        _rpg_complete available "$cur";;

    resolve)
        _rpg_complete available "$cur";;

    uninstall|list|upgrade|dependencies|manifest)
        _rpg_complete installed "$cur";;

    esac
}

_rpg_complete () {
    local cur stuff
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    stuff="$(rpg complete "$@")"
    COMPREPLY=( $(compgen -W "$stuff" -- "$cur") )
}

complete -F _rpg rpg
