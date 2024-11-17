###############################################################################
#==============================================================================
#
# external command management functions
#
#------------------------------------------------------------------------------
#
# ext_cmd_default_scope (default=ext_cmd_scope)
# ext_cmd_get_error_continue (default=<not-set>)
#
#==============================================================================
###############################################################################

include "print.bash"
include "exception.bash"
include "hash_table.bash"
include "file_utility.bash"

#==============================================================================
# dump command environment scope
#
# Params:
# -s  : environment scope
# -sl : environment scope list
#==============================================================================
function ext_cmd_dump()
{
    declare local scope=${ext_cmd_default_scope:-ext_cmd_scope}
    declare local list

    while [ $# -gt 0 ] ; do
        case $1 in
        -s) scope=$2    ; shift 1   ;;
        -sl) list="$2"  ; shift 1   ;;
         *) abort_invalid_arg $1    ;;
        esac
        shift 1
    done

    if [ -n "$list" ] ; then
        for s in $list ; do
            ext_cmd_dump -s $s
        done
    else
        abort_if_not_defined "$scope" "-s:scope"
        print_debug_vl 5 "[$scope]"
        hash_dump $scope "external command scope [$scope]"
    fi

    return
}


#==============================================================================
# destroy command environment scope
#
# Params:
# -s  : environment scope
# -sl : environment scope list
#==============================================================================
function ext_cmd_destroy()
{
    declare local scope=${ext_cmd_default_scope:-ext_cmd_scope}
    declare local list

    while [ $# -gt 0 ] ; do
        case $1 in
        -s) scope=$2    ; shift 1   ;;
        -sl) list="$2"  ; shift 1   ;;
         *) abort_invalid_arg $1    ;;
        esac
        shift 1
    done

    if [ -n "$list" ] ; then
        for s in $list ; do
            ext_cmd_destroy -s $s
        done
    else
        abort_if_not_defined "$scope" "-s:scope"
        print_debug_vl 5 "[$scope]"
        hash_unset_all $scope
    fi

    return
}


#==============================================================================
# set command
#
# Params:
# -s : environment scope
# -n : command name
# -p : command path
# -o : command options
#==============================================================================
function ext_cmd_set()
{
    declare local scope=${ext_cmd_default_scope:-ext_cmd_scope}
    declare local  name
    declare local  path
    declare local  opts

    while [ $# -gt 0 ] ; do
        case $1 in
        -s) scope=$2    ; shift 1   ;;
        -n) name=$2     ; shift 1   ;;
        -p) path="$2"   ; shift 1   ;;
        -o) opts="$2"   ; shift 1   ;;
         *) abort_invalid_arg $1    ;;
        esac
        shift 1
    done

    abort_if_not_defined "$scope" "-s:scope"
    abort_if_not_defined "$name"  "-n:name"

    if [ -n "$path" ] ; then
        print_debug_vl 5 "[$scope]:[$name]:path=[$path]"
        hash_set $scope ${name} "$path"
    fi

    if [ -n "$opts" ] ; then
        print_debug_vl 5 "[$scope]:[$name]:opts=[$opts]"
        hash_set $scope ${name}_opts "$opts"
    fi

    return
}


#==============================================================================
# get command
#
# Params:
# -s      : environment scope
# -n      : command name
#
# -v_p    : variable name to store retrieved path
# -v_o    : variable name to store retrieved options
# -v_po   : variable name to store retrieved path and options
#
# -nv_p   : command name == variable name; retrieve and store path
# -nv_po  : command name == variable name; retrieve and store path and options
#
# -nv_pl  : list - use '-nv_p' for each in list
# -nv_pol : list - use '-nv_po' for each in list
#
# -inoe   : ignore no options error
#==============================================================================
function ext_cmd_get()
{
    declare local scope=${ext_cmd_default_scope:-ext_cmd_scope}
    declare local name
    declare local __rv1_name
    declare local __rv2_name
    declare local append
    declare local ignore
    declare local list

    while [ $# -gt 0 ] ; do
        case $1 in
        -s)      scope=$2 ;                                 shift 1   ;;

        -n)      name=$2 ;                                  shift 1   ;;

        -v_p)               __rv1_name=$2 ;                 shift 1   ;;
        -v_o)               __rv2_name=$2 ;                 shift 1   ;;
        -v_po)              __rv1_name=$2 ; append=true ;   shift 1   ;;

        -nv_p)   name=$2 ;  __rv1_name=$2 ;                 shift 1   ;;
        -nv_po)  name=$2 ;  __rv1_name=$2 ; append=true ;   shift 1   ;;

        -nv_pl)  list="$2" ;                                shift 1   ;;
        -nv_pol) list="$2" ;                append=true ;   shift 1   ;;

        -inoe)                              ignore=true               ;;

         *) abort_invalid_arg $1                                      ;;
        esac
        shift 1
    done

    # use recursion to process list
    if [ -n "$list" ] ; then
        for c in $list ; do
            if [ -n "$append" ] ; then
                ext_cmd_get -s ${scope} -nv_po ${c} ${ignore+-inoe}
            else
                ext_cmd_get -s ${scope} -nv_p  ${c} ${ignore+-inoe}
            fi
        done

        return 0
    fi

    abort_if_not_defined "$scope" "-s:scope"
    abort_if_not_defined "$name"  "-n:name"

    declare local __rv1_value not_found1

    if [ -n "$__rv1_name" ] ; then
        if hash_is_set $scope $name ; then
            hash_get_into $scope $name '__rv1_value'

            print_debug_vl 5 "[$scope]:[$name]:path[$__rv1_name]=[$__rv1_value]"
            eval "$__rv1_name=\"${__rv1_value}\""
        else
            print_debug_vl 5 "[$scope]:[$name]:path[$__rv1_name]=(not defined)"

            [ -z "$ext_cmd_get_error_continue" ] && \
                abort_error "path for command [$name] not set in scope [$scope]." \
                        "set the global variable 'ext_cmd_get_error_continue=1'" \
                        "to surpress and ignore this error condition."
            not_found1=true
        fi
    fi

    declare local __rv2_value not_found2

    if [[ -n "$__rv2_name" || -n "$append" ]] ; then
        if hash_is_set $scope ${name}_opts ; then
            hash_get_into $scope ${name}_opts '__rv2_value'

            if [ -n "$__rv2_name" ] ; then
                print_debug_vl 5 "[$scope]:[$name]:opts[$__rv2_name]=[$__rv2_value]"
                eval "$__rv2_name=\"${__rv2_value}\""
            fi
        else
            print_debug_vl 5 "[$scope]:[$name]:opts[$__rv2_name]=(not defined)"

            if [ -z "$ignore" ] ; then
                [ -z "$ext_cmd_get_error_continue" ] && \
                    abort_error \
                        "opts for command [$name] not set in scope [$scope]." \
                        "set the global variable 'ext_cmd_get_error_continue=1'" \
                        "or use the function flag '-inoe'" \
                        "to surpress and ignore this error condition."
                not_found2=true
            fi
        fi
    fi

    # return fail if either were not found
    [[ -n "$not_found1" || -n "$not_found2" ]] && return 1

    # append option to path requested
    if [ -n "$append" ] ; then
        declare local path_opts="${__rv1_value}${__rv2_value+ $__rv2_value}"

        print_debug_vl 5 "[$scope]:[$name]+opts[$__rv1_name]=[$path_opts]"
        eval "$__rv1_name=\"${path_opts}\""
    fi

    return 0
}


#==============================================================================
# get a list of command entries in the scope
#
# Params:
# -s : environment scope
# -v : variable name to store list
#==============================================================================
function ext_cmd_get_list()
{
    declare local scope=${ext_cmd_default_scope:-ext_cmd_scope}
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

    #==========================================================================
    #
    #==========================================================================
    function foreach_function()
    {
        declare local key=$1

        # skip command option entries
        [[ $key == *_opts ]] && return

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
# set first found command from list
#
# Params:
# -s   : command environment scope
# -n   : command name
# -l   : list of command paths
# -o   : command options
# -p   : permission flags
# -sp  : search path for each named file in list
# -nsp : set command name, add name to list, and set search path
#==============================================================================
function ext_cmd_setf()
{
    declare local scope
    declare local name
    declare local list
    declare local opts
    declare local perm='efrx'
    declare local search

    while [ $# -gt 0 ] ; do
        case $1 in
        -s) scope=$2                                ; shift 1   ;;
        -n) name=$2                                 ; shift 1   ;;
        -l) list="$2"                               ; shift 1   ;;
        -o) opts="$2"                               ; shift 1   ;;
        -p) perm=$2                                 ; shift 1   ;;
       -sp) search=1                                            ;;
      -nsp) name=$2     ; list+="$2"    ; search=1  ; shift 1   ;;
         *) abort_invalid_arg $1                                ;;
        esac
        shift 1
    done

    abort_if_not_defined "$name"  "-n:name"
    abort_if_not_defined "$list"  "-l:list"

    declare local path_found

    # check if suitable command can be found in $list
    for file in $list ; do
        declare local filet=$( type -t $file )
        declare local filep

        [ -z "$search" ] && filep="$file"
        [ -n "$search" ] && filep="$( type -P $file )"

        print_debug_vl 5 "checking file=[$file], type=[$filet], path=[$filep]"

        case $filet in
        function|builtin)
            path_found="${file}"
            break
        ;;
        file)
            if file_check -f "$filep" -p "$perm" -q ; then
                path_found="${filep}"
                break
            fi
        ;;
        *)
        ;;
        esac
    done

    [ -z "$path_found" ] && \
        abort_error "unable to find command for [$name] with permissions [$perm]" \
                    "checked each of: [$list]${search+, searching path}."

    print_debug_vl 5 "using [$name]:path=[$path_found] of [$list]"

    [ -z "$opts" ] && \
        ext_cmd_set ${scope+-s $scope} -n $name -p "$path_found"
    [ -n "$opts" ] && \
        ext_cmd_set ${scope+-s $scope} -n $name -p "$path_found" -o "$opts"

    return
}


#==============================================================================
# eof
#==============================================================================
