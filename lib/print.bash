###############################################################################
#==============================================================================
#
# console message printing functions
#
#------------------------------------------------------------------------------
#
# print_verb_level_var_name (default=$verb_level)
#
#==============================================================================
###############################################################################

# be sure to 'source basenames.bash' prior to using these functions
include "exception.bash"

#==============================================================================
# print message
#
# Params (first argument):
# -j : join - don't prepend script name
# -J : jump - character in scriptname
#  * : name - prepend script name to output
# Params:
# -n : do not output new-line at end of text line
# -e : enable echo escape interpretation
# -E : disable echo escape interpretation
# -j : joint the subsequent word
# -r : repeat count for next word
# -s : set the word seperator string
#  * : text to be printed
#==============================================================================
function print_m()
{
    declare    local nl
    declare    local es
    declare -i local rn=1
    declare    local ws=' '
    declare    local ns="${ws}"

    # first argument processing
    case $1 in
    -j)                                                             ;;
    -J) print_m -j -n -r ${#script_base_name} ' ' -j ' ' ; shift 1  ;;
     *) echo -n ${script_base_name}:                                ;;
    esac
    

    while [ $# -gt 0 ] ; do
        case $1 in
        -n) nl=true           ;; # do not output new-line at end
        -e) es=true           ;; # enable echo escape interpretation
        -E) es=''             ;; # disable echo escape interpretation
        -j) ns=''             ;; # joint the subsequent word
        -r) rn=$2   ; shift 1 ;; # repeat count for next word
        -s) ws="$2" ; shift 1 ;; # set the word seperator string
         *)
            while ((rn > 0))
            do
                if [ -z "$es" ] ; then
                    echo -n -E "${ns}${1}"
                else
                    echo -n -e "${ns}${1}"
                fi

                ns=''
                let rn--
            done
            ns="${ws}"
            rn=1
        ;;
        esac

        shift 1
    done

    [ -z "$nl" ] && echo

    return
}


#==============================================================================
# print debug message
#
# Params:
# * : debug message passed to print_m
#==============================================================================
function print_debug()
{
    declare local fname=${FUNCNAME[1]}

    print_m -j "${script_base_name}.${fname}():" $*

    return
}


#==============================================================================
# check for minimum verbosity level
#
# Params:
# 1 : minimum verbosity level to return true
#==============================================================================
function check_vl()
{
    [[ ${print_verb_level_var_name:-$verb_level} -ge $1 ]] && return 0

    return 1
}


#==============================================================================
# print message for verbosity level
#
# Params:
# 1 : minimum verbosity level to output message
# * : remaining arguments passed to print_m
#==============================================================================
function print_m_vl()
{
    declare local level=$1
    shift 1

    check_vl $level && print_m $*

    return
}


#==============================================================================
# print debug message for verbosity level
#
# Params:
# 1 : minimum verbosity level to output message
# * : remaining arguments printed as debug message
#==============================================================================
function print_debug_vl()
{
    declare local level=$1
    shift 1

    declare local fname=${FUNCNAME[1]}

    check_vl $level && print_m -j "${script_base_name}.${fname}():" $*

    return
}


#==============================================================================
# print message and wait for enter key to be pressed to continue
#
# Params:
# * : arguments passed to print_m
#==============================================================================
function print_pause()
{
    if [ $# -eq 0 ] ; then
        print_m -n "press [enter] to continue :"
    else
        print_m $*
    fi

    declare local choice
    read choice

    return
}


#==============================================================================
# print message and wait for a key in a list-of-keys to be pressed.
#
# Params:
# -m : message to be printed
# -l : list of valid characters
# -i : ignore case (result is converted to lower case).
# -j : joint: passed directly to print_m
# -v: return value variable name
#==============================================================================
function print_select_char()
{
    declare local message
    declare local ch_list
    declare local icase
    declare local join
    declare local __rv_name

    # parse function arguments
    while [ $# -gt 0 ] ; do
        case $1 in
        -m) message="$2"    ; shift 1   ;;
        -l) ch_list=$2      ; shift 1   ;;
        -i) icase=true                  ;;
        -j) join="-j"                   ;;
        -v) __rv_name=$2    ; shift 1   ;;
        *) abort_invalid_arg $1         ;;
        esac

        shift 1
    done

    # if ch_list is empty, return
    [ -z "$ch_list" ] && return

    # if ignoring case
    [ -n "$icase" ] && ch_list=${ch_list,,}

    declare local got_ch
    while [ -z "$got_ch" ]
    do
        declare local choice

        print_m $join -n "$message"
        read -n 1 choice

        # if ignoring case
        [ -n "$icase" ] && choice=${choice,,}

        # check to see if choice is in $ch_list
        declare -i local idx cnt=${#ch_list}
        for (( idx=0; idx < cnt; idx++ )) ; do
            if [ "$choice" == ${ch_list:$idx:1} ] ; then
                got_ch=$choice
                break
            fi
        done

        print_m -j
    done

    declare local __rv_value=$got_ch

    [ -n "$__rv_name" ] && eval "$__rv_name=\"${__rv_value}\""
    
    return
}


#==============================================================================
# eof
#==============================================================================

