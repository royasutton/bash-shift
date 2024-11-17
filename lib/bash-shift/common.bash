###############################################################################
#==============================================================================
#
# common helper functions
#
#------------------------------------------------------------------------------
#
# common_print_key_value_kfw (default=20)
#
#==============================================================================
###############################################################################

include "print.bash"
include "print_textbox.bash"
include "exception.bash"
include "variable_expansion.bash"
include "external_command.bash"

#==============================================================================
# print title centered in a text box
#
# Params:
# -t  : title string
#  *  : other arguments passed to print_textbox
#==============================================================================
function common_textbox()
{
    declare local title

    while [ $# -gt 0 ] ; do
        case $1 in
        -t) title="$2"      ; shift 2   ;;
        *) break                        ;;
        esac
    done

    print_textbox -ct "$title" $* -bt -pl -bb

    return
}


#==============================================================================
# print title centered on a text line
#
# Params:
# -t  : title string
#  *  : other arguments passed to print_textbox
#==============================================================================
function common_textline()
{
    declare local title

    while [ $# -gt 0 ] ; do
        case $1 in
        -t) title="$2"      ; shift 2   ;;
        *) break                        ;;
        esac
    done

    print_textbox -bc 0 -lt ":" -ct "$title" -rt ":" -fc "-" $* -pl

    return
}


#==============================================================================
# string modify
#
# Params:
#  -s <string>  : input string
#  -v <name>    : variable name for result string
#  -e           : evaluate variables in input string
#
# -ccl          : convert to all lower case
# -ccu          : convert to all upper case
#
# -stc <list>   : set character list for trim operations (default=[:space:])
# -tlc          : trim leading characters in '-stl' from beginning of string
# -ttc          : trim trailing characters in '-stl' from end of string
#==============================================================================
function common_string_mod()
{
    declare local str
    declare local __rvn
    declare local ev
    declare local stc="[:space:]"

    declare local __rvv

    while [ $# -gt 0 ] ; do
        case $1 in
        -s)     __rvv="$2"  ; shift 1   ;;
        -v)     __rvn=$2    ; shift 1   ;;
        -e)     ev=true                 ;;

        # convert to lower case
        -ccl)
            __rvv="${__rvv,,}"
        ;;

        # convert to upper case
        -ccu)
            __rvv="${__rvv^^}"
        ;;

        -stc)   stc="$2"    ; shift 1   ;;

        # trim leading
        -tlc)
            declare local __idx=0 __cnt=${#__rvv}
            while (( __idx<__cnt )) ; do
                [[ ${__rvv:$__idx:1} != [$stc] ]] && break
                let __idx++
            done
            __rvv="${__rvv:$__idx}"
        ;;

        # trim trailing
        -ttc)
            declare local __idx=${#__rvv} __cnt=${#__rvv}
            while (( __idx>0 )) ; do
                [[ ${__rvv:$((__idx-1)):1} != [$stc] ]] && break
                let __idx--
            done
            __rvv="${__rvv:0:$__idx}"
        ;;

        *) abort_invalid_arg $1         ;;
        esac

        shift 1
    done

    # if the evaluate flag '-e' is not set: avoid evaluating words in '${__rvv}'
    # preceded by '$' by replacing all occurrences of '$' with '\$' before eval
    [ -z "$ev" ] && __rvv=${__rvv//\$/\\$}

    [ -n "$__rvn" ] && eval "${__rvn}=\"${__rvv}\""

    return
}


#==============================================================================
# confirm continuation
#
# Params:
# $1 : message to print prior to continuation prompt
#==============================================================================
function common_confirm()
{
    declare local message="$1"

    declare local cont_conf
    [ -n "$message" ] && print_m -j "$message"
    print_select_char -m "continue [y/n]? :" -j -l yn -v cont_conf -i

    if [ "$cont_conf" == "y" ] ; then
        return 0
    else
        return 1
    fi
}


#==============================================================================
# print keyword and its value(s)
#
# Params:
# -k : set keyword
# -w : set keyword field width
# -s : set separator for multiple values (default=' ')
#  * : other arguments are values for the keyword
#==============================================================================
function common_print_key_value()
{
    declare local key
    declare local kfw=${common_print_key_value_kfw:-20}
    declare local sep=" "

    while [ $# -gt 0 ] ; do
        case $1 in
        -k) key="$2"    ; shift 1   ;;
        -w) kfw=$2      ; shift 1   ;;
        -s) sep="$2"    ; shift 1   ;;
        *) break                    ;;
        esac
        shift 1
    done

    # do keyword in bold
    declare local sf ef
    terminal_ansi_ctrl_ca -v sf --attribute bright
    terminal_ansi_ctrl_ca -v ef --attribute reset

    print_m -j -e "$sf" \
            -j -r $(($kfw - ${#key})) " " \
            -j "${key}:${ef} " \
            -j -s "${sep}" $*

    return
}


#==============================================================================
# dump expansion variables (using common_print_key_value)
#
# Params:
# -s  : expansion variables scope
# -l  : list of variables to dump (default=all)
# -t  : title string
# -w  : set keyword field width
# -nt : do not print title box
#==============================================================================
function common_dump_expand_vars()
{
    declare local scope
    declare local list
    declare local title="$script_base_name expansion/script variables (sv)"
    declare local kfw
    declare local nt

    while [ $# -gt 0 ] ; do
        case $1 in
        -s) scope=$2    ; shift 1   ;;
        -l) list="$2"   ; shift 1   ;;
        -t) title="$2"  ; shift 1   ;;
        -w) kfw=$2      ; shift 1   ;;
        -nt) nt=true                ;;
        *) abort_invalid_arg $1     ;;
        esac
        shift 1
    done

    [ -z "$list" ] && expand_var_get_list ${scope+-s $scope} -v 'list'
    [ -z "$nt" ] && common_textbox -t "${scope+[$scope] }$title"

    declare local item value
    for item in $list ; do
        if [[ "$item" == ":" || "$item" == "<sep>" ]] ; then
            print_m -j
            continue
        fi

        expand_var_get ${scope+-s $scope} -n $item -v 'value' \
            || value="<not set>"

        common_print_key_value -k "$item" ${kfw+-w $kfw} "-n"
        print_m -j "[$value]"
    done

    return
}


#==============================================================================
# dump external commands (using common_print_key_value)
#
# Params:
# -s  : external command scope
# -l  : list of commands to dump (default=all)
# -t  : title string
# -w  : set keyword field width
# -nt : do not print title box
#==============================================================================
function common_dump_ext_cmds()
{
    declare local scope
    declare local list
    declare local title="$script_base_name external commands (ec)"
    declare local kfw
    declare local nt

    while [ $# -gt 0 ] ; do
        case $1 in
        -s) scope=$2    ; shift 1   ;;
        -l) list="$2"   ; shift 1   ;;
        -t) title="$2"  ; shift 1   ;;
        -w) kfw=$2      ; shift 1   ;;
        -nt) nt=true                ;;
        *) abort_invalid_arg $1     ;;
        esac
        shift 1
    done

    [ -z "$list" ] && ext_cmd_get_list ${scope+-s $scope} -v 'list'
    [ -z "$nt" ] && common_textbox -t "${scope+[$scope] }$title"

    # do not through exception for non-existing commands
    declare local ext_cmd_get_error_continue=1

    declare local item value
    for item in $list ; do
        if [[ "$item" == ":" || "$item" == "<sep>" ]] ; then
            print_m -j
            continue
        fi

        ext_cmd_get ${scope+-s $scope} -n $item -v_po 'value' -inoe \
            || value="<not set>"

        common_print_key_value -k "$item" ${kfw+-w $kfw} "-n"
        print_m -j "[$value]"
    done

    return
}


#==============================================================================
# set common expansion variables
#
# Params:
# -s  : expansion variables scope
#==============================================================================
function common_set_expand_vars()
{
    declare local s

    while [ $# -gt 0 ] ; do
        case $1 in
        -s) s=$2        ; shift 1   ;;
        *) abort_invalid_arg $1     ;;
        esac
        shift 1
    done

    expand_var_set ${s:+-s $s} -n 'sysname'        -v "$(uname -s)"
    expand_var_set ${s:+-s $s} -n 'machine'        -v "$(uname -m)"

    expand_var_set ${s:+-s $s} -n 'date'           -v "$(date +%y%m%d)"
    expand_var_set ${s:+-s $s} -n 'time'           -v "$(date +%H%M%S)"
    expand_var_set ${s:+-s $s} -n 'day_name'       -v "$(date +%A)"
    expand_var_set ${s:+-s $s} -n 'day_name_abbr'  -v "$(date +%a)"

    expand_var_set ${s:+-s $s} -n 'conf_dir'       -v "${script_conf_dir}"
    expand_var_set ${s:+-s $s} -n 'dcf_base_name'  -v "${script_base_name}"
    expand_var_set ${s:+-s $s} -n 'dcf_root_name'  -v "${script_root_name}"

    return
}


#==============================================================================
# set common external commands
#
# Params:
# -s  : external command scope
#==============================================================================
function common_set_ext_cmds()
{
    declare local s

    while [ $# -gt 0 ] ; do
        case $1 in
        -s) s=$2        ; shift 1   ;;
        *) abort_invalid_arg $1     ;;
        esac
        shift 1
    done

    # parse_cmd_line requirements
    ext_cmd_setf ${s:+-s $s} -sp -n edit     -l "gvim vim vi"
    ext_cmd_setf ${s:+-s $s} -sp -n ls_l     -l "ls" -o "-lh"

    # parse_conf_file requirements
    ext_cmd_setf ${s:+-s $s} -sp -n md_pm755 -l "mkdir" -o "-pvm 755"
    ext_cmd_setf ${s:+-s $s} -sp -n ls_ld    -l "ls" -o "-ld"
    ext_cmd_setf ${s:+-s $s} -sp -n rm_f     -l "rm" -o "-f"
    ext_cmd_setf ${s:+-s $s} -sp -n cp_a     -l "cp" -o "-a"
    ext_cmd_setf ${s:+-s $s} -sp -n mv_f     -l "mv" -o "-f"

    ext_cmd_setf ${s:+-s $s} -nsp gzip

    # terminal_utility requirements
    ext_cmd_setf ${s:+-s $s} -nsp tput

    return
}


#==============================================================================
# eof
#==============================================================================
