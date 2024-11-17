###############################################################################
#==============================================================================
#
# exceptions warning, errors, stack dump, functions
#
#------------------------------------------------------------------------------
#
# exception_call_stack_basename (default=<not-set>)
#
#==============================================================================
###############################################################################

include "print.bash"

#==============================================================================
# dump call stack
#
# Params:
# 1 : start level for stack dump
#==============================================================================
function dump_call_stack()
{
    declare    local start=${1-1}

    print_m "*** [call-stack] ***"

    declare -i local idx=${start}
    declare -i local cnt=${#FUNCNAME[@]}

    while (( idx<cnt )) ; do
        print_m -J -n "[" -j $(( $cnt - $idx - 1 )) -j "]--> "

        if [ $idx -eq $start ] ; then
            print_m -j -n "in function"
        else
            print_m -j -n "called from"
        fi

        declare local srcf=${BASH_SOURCE[$idx]}
        declare local name=${FUNCNAME[$idx]}
        declare local line=${BASH_LINENO[ $(($idx-1)) ]}

        # basename: remote leading path if set
        if [ -n "$exception_call_stack_basename" ] ; then
            srcf=${srcf##*/}
            print_m -j " [${name}()] at line [${line}] in [${srcf}]"
        else
            print_m -j " [${name}()] at line [${line}]"
            print_m -J -r 6 ' ' "file [${srcf}]"
        fi

        let idx++
    done

    return
}


#==============================================================================
# output multi-line error message and exit
#
# Params:
# * : error message line list
#==============================================================================
function abort_error()
{
    print_m "*** [error] ***"

    while [ $# -gt 0 ] ; do
        [ -n "$1" ] && print_m -J $1

        shift 1
    done

    dump_call_stack 2
    print_m "aborting..."

    exit 1
}


#==============================================================================
# report message with appended list of error words
#
# Params:
# --abort-message-base : base error message
# --abort-stack-start  : specify stack start possition
#  * : error words
#==============================================================================
function abort_message_list()
{
    declare local message="unspecified exception"
    declare local stack=2
    declare local list

    print_m "*** [error] ***"

    declare -i local cnt=0

    while [ $# -gt 0 ] ; do
        case $1 in
        --abort-message-base)   message="$2"    ; shift 1   ;;
        --abort-stack-start)    stack=$2        ; shift 1   ;;
         *) list+=" [$1]"                       ; let cnt++ ;;
        esac
        shift 1
    done

    [ $cnt -ge 2 ] && message+="s"

    print_m -J $message $list
    dump_call_stack $stack
    print_m "aborting..."

    exit 1
}


#==============================================================================
# invalid argument
#
# Params:
# 1 : argument name list
#==============================================================================
function abort_invalid_arg()
{
    abort_message_list \
        --abort-message-base "invalid argument" \
        --abort-stack-start 3 $*
}


#==============================================================================
# undefined required variable
#
# Params:
# 1 : variable name list
#==============================================================================
function abort_not_defined()
{
    abort_message_list \
        --abort-message-base "undefined required variable" \
        --abort-stack-start 3 $*
}


#==============================================================================
# check for undefined required variable
#
# Params:
# 1 : variable (quoted function call to capture null string)
# 2 : variable name (list)
#==============================================================================
function abort_if_not_defined()
{
    [ -n "$1" ] && return

    shift 1
    abort_message_list \
        --abort-message-base "undefined required variable" \
        --abort-stack-start 3 $*
}


#==============================================================================
# eof
#==============================================================================

