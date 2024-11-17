###############################################################################
#==============================================================================
#
# variable expansion and substitution functions
#
#------------------------------------------------------------------------------
#
# expand_var_default_scope (default=expand_var_scope)
# expand_var_get_error_continue (default=<not-set>)
# expand_var_get_error_text (default=<not-set>)
#
#==============================================================================
###############################################################################

include "print.bash"
include "exception.bash"
include "hash_table.bash"

#==============================================================================
# dump expansion variable scope
#
# Params:
# -s  : environment scope
# -sl : environment scope list
#==============================================================================
function expand_var_dump()
{
    declare local scope=${expand_var_default_scope:-expand_var_scope}
    declare local list

    while [ $# -gt 0 ] ; do
        case $1 in
        -s) scope=$2    ; shift 1   ;;
        -sl) list="$2" ; shift 1    ;;
         *) abort_invalid_arg $1    ;;
        esac
        shift 1
    done

    if [ -n "$list" ] ; then
        for s in $list ; do
            expand_var_dump -s $s
        done
    else
        abort_if_not_defined "$scope" "-s:scope"
        print_debug_vl 5 "[$scope]"
        hash_dump $scope "expansion variable scope [$scope]"
    fi

    return
}


#==============================================================================
# destroy expansion variable scope
#
# Params:
# -s  : environment scope
# -sl : environment scope list
#==============================================================================
function expand_var_destroy()
{
    declare local scope=${expand_var_default_scope:-expand_var_scope}
    declare local list

    while [ $# -gt 0 ] ; do
        case $1 in
        -s) scope=$2    ; shift 1   ;;
        -sl) list="$2" ; shift 1    ;;
         *) abort_invalid_arg $1    ;;
        esac
        shift 1
    done

    if [ -n "$list" ] ; then
        for s in $list ; do
            expand_var_destroy -s $s
        done
    else
        abort_if_not_defined "$scope" "-s:scope"
        print_debug_vl 5 "[$scope]"
        hash_unset_all $scope
    fi

    return
}


#==============================================================================
# unset expansion variable
#
# Params:
# -s : environment scope
# -n : variable name
#==============================================================================
function expand_var_unset()
{
    declare local scope=${expand_var_default_scope:-expand_var_scope}
    declare local var

    while [ $# -gt 0 ] ; do
        case $1 in
        -s) scope=$2    ; shift 1   ;;
        -n) var=$2      ; shift 1   ;;
         *) abort_invalid_arg $1    ;;
        esac
        shift 1
    done

    abort_if_not_defined "$scope" "-s:scope"
    abort_if_not_defined "$var"   "-n:variable-name"

    print_debug_vl 5 "[$scope]:[$var]"

    hash_unset $scope $var

    return
}


#==============================================================================
# set expansion variable
#
# Params:
# -s : environment scope
# -n : variable name
# -v : variable value
#==============================================================================
function expand_var_set()
{
    declare local scope=${expand_var_default_scope:-expand_var_scope}
    declare local var
    declare local value

    while [ $# -gt 0 ] ; do
        case $1 in
        -s) scope=$2    ; shift 1   ;;
        -n) var=$2      ; shift 1   ;;
        -v) value="$2"  ; shift 1   ;;
         *) abort_invalid_arg $1    ;;
        esac
        shift 1
    done

    abort_if_not_defined "$scope" "-s:scope"
    abort_if_not_defined "$var"   "-n:variable-name"

    print_debug_vl 5 "[$scope]:[$var]=[$value]"

    hash_set $scope $var "$value"

    return
}


#==============================================================================
# get expansion variable
#
# Params:
# -s : environment scope
# -n : var name
# -v : variable name to store var value
#==============================================================================
function expand_var_get()
{
    declare local scope=${expand_var_default_scope:-expand_var_scope}
    declare local var
    declare local __rv_name

    while [ $# -gt 0 ] ; do
        case $1 in
        -s) scope=$2        ; shift 1   ;;
        -n) var=$2          ; shift 1   ;;
        -v) __rv_name=$2    ; shift 1   ;;
         *) abort_invalid_arg $1        ;;
        esac
        shift 1
    done

    abort_if_not_defined "$scope" "-s:scope"
    abort_if_not_defined "$var"   "-n:variable-name"

    if hash_is_set $scope $var ; then
        declare local __rv_value

        hash_get_into $scope $var '__rv_value'

        print_debug_vl 5 "[$scope]:[$var]=[$__rv_value]"

        [ -n "$__rv_name" ] && eval "$__rv_name=\"${__rv_value}\""

        return 0
    else
        print_debug_vl 5 "[$scope]:[$var]=(not defined)"

        return 1
    fi
}


#==============================================================================
# get list of variables in expansion environment scope
#
# Params:
# -s : environment scope
# -v : variable name to store variable list
#==============================================================================
function expand_var_get_list()
{
    declare local scope=${expand_var_default_scope:-expand_var_scope}
    declare local __rv_name

    while [ $# -gt 0 ] ; do
        case $1 in
        -s) scope=$2        ; shift 1   ;;
        -v) __rv_name=$2    ; shift 1   ;;
         *) abort_invalid_arg $1        ;;
        esac
        shift 1
    done

    abort_if_not_defined "$scope" "-s:scope"

    declare local __rv_value

    function foreach_function()
    {
        declare local key=$1

        [ -n "$__rv_value" ] && __rv_value+=" $key"
        [ -z "$__rv_value" ] && __rv_value="$key"

        return
    }

    hash_foreach $scope foreach_function

    print_debug_vl 5 "[$scope]:list=[$__rv_value]"

    [ -n "$__rv_name" ] && eval "$__rv_name=\"${__rv_value}\""

    return
}


#==============================================================================
# expand and substitute variables in argument string
#
# Params:
#   -s : environment scope
#   -i : input string
#   -v : variable name to store expanded result string
#   -e : variable name escape character (ie: \~, !, @, ...)
#
# -ruv : re-insert variable names in result string when undefined
# -rut : replace undefined variables with text in result string
#==============================================================================
function expand_var_str()
{
    declare local scope
    declare local in_string
    declare local __rv_name
    declare local es_ch='!'

    declare local ruv
    declare local rut rut_text

    while [ $# -gt 0 ] ; do
        case $1 in
        -s) scope=$2        ; shift 1   ;;
        -i) in_string="$2"  ; shift 1   ;;
        -v) __rv_name=$2    ; shift 1   ;;
        -e) es_ch=$2        ; shift 1   ;;

        -ruv) ruv=true                  ;;
        -rut) rut=true
              rut_text="$2" ; shift 1   ;;
         *) abort_invalid_arg $1        ;;
        esac
        shift 1
    done

    # make sure escape character is exactly one character
    [ ${#es_ch} -ne 1 ] && abort_invalid_arg "-e:ecape-character='$es_ch'"

    # parse and return variable name from in_string
    function get_var_name() {
        declare local in_string="$1"
        declare local __rv_name=$2

        declare -i local cnt=${#in_string}
        declare -i local idx
        declare -i local open_brace_cnt=0
        declare    local __rv_value

        # step through chars in_string, skipping the escape character
        for (( idx=1; idx < cnt; idx++ )) ; do
            declare local chr=${in_string:$idx:1}

            case $chr in
            # [[:alnum:]] = alphanumeric character 0-9 or A-Z or a-z
            [[:alnum:]] | '_')
                __rv_value+=$chr
            ;;
            # explicit begin for variable name
            '{')
                let open_brace_cnt++
            ;;
            # explicit end for variable name
            '}')
                # make sure open_brace_cnt==1
                [ $open_brace_cnt -ne 1 ] && abort_error \
                "malformed explicit end of variable name:" "[$in_string]" \
                "$open_brace_cnt open braces. explicit end at character [$(($idx+1))]."

                # advance past close brace
                let idx++

                break
            ;;
            # implicit end for variable name
            *)
                # since implicit end, make sure open_brace_cnt==0
                [ $open_brace_cnt -ne 0 ] && abort_error \
                "malformed implicit end of variable name:" "[$in_string]" \
                "$open_brace_cnt open braces. implicit end at character [$(($idx+1))]."

                break
            ;;
            esac
        done

        eval "$__rv_name=\"${__rv_value}\""
        return $idx
    }

    # begin function expand_var_str
    declare -i local cnt=${#in_string}
    declare -i local idx=0
    declare    local __rv_value

    # step through chars in in_string
    while (( idx < cnt )) ; do
        declare local chr=${in_string:$idx:1}

        case $chr in
        # escape character: begin variable substitution
        $es_ch)
            # get variable name at current possition
            declare local var \
                          var_value
            get_var_name "${in_string:$idx}" 'var'

            # store returned character count
            declare local var_chr_cnt=$?

            if expand_var_get -n $var -v 'var_value' ${scope+-s $scope} ; then
                # variable valid, append to string
                __rv_value+="${var_value}"
            else
                # variable not found

                # replace with variable name
                [[ -n "$ruv" ]] && \
                    __rv_value+="${es_ch}{${var}}"

                # replace with text
                [[ -z "$ruv" && -n "$rut" ]] && \
                    __rv_value+="${rut_text}"

                # global abort control
                [[ -z "$ruv" && -z "$rut" && \
                   -z "$expand_var_get_error_continue" ]] && \
                    abort_error \
                    "variable [$var] at character [$(($idx+1))] in string:" \
                    "[$in_string]" " undefined${scope+ in scope [$scope]}."

                # global text replacement
                [[ -z "$ruv" && -z "$rut" && \
                   -n "$expand_var_get_error_text" ]] && \
                    __rv_value+="${expand_var_get_error_text}"
            fi

            # advance index by returned character count
            let idx+=$var_chr_cnt
        ;;
        # appended any other character to __rv_value un-modified.
        *)
            __rv_value+=$chr
            let idx++
        ;;
        esac
    done

    # variable expansion

    # using eval will expand all variable names in __rv_value
    # that are visible within the scope of this statement. ie
    # all local variables in this function and other global
    # variables defined in the script.

    [ -n "$__rv_name" ] && eval "$__rv_name=\"${__rv_value}\""

    print_debug_vl 5 "[$in_string]==>[${!__rv_name}]"

    return
}


#==============================================================================
# eof
#==============================================================================

