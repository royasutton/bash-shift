###############################################################################
#==============================================================================
#
# command exit-code statistics functions
#
#------------------------------------------------------------------------------
#
# exit_status_default_scope (default=exit_status_scope)
# exit_status_max_code_chars (default=3)
#
#==============================================================================
###############################################################################

include "common.bash"
include "hash_table.bash"

#==============================================================================
# return scope index for given exit-code value
#
# Params:
# 1 : exit-code
# 2 : variable name for index
#==============================================================================
function exit_status_code_idx()
{
    declare local code

    # strip leading '0' in the exit-code
    common_string_mod -s $1 -v code -stc 0 -tlc
    
    # add the appropriate number of '0' based on
    # configuration 'exit_status_max_code_chars'
    printf -v $2 "%0${exit_status_max_code_chars:-3}d" $code
    
    return
}


#==============================================================================
# dump exit-code statistics scope
#
# Params:
# -s  : scope
# -sl : scope list
#==============================================================================
function exit_status_dump()
{
    declare local scope=${exit_status_default_scope:-exit_status_scope}
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
            exit_status_dump -s $s
        done
    else
        abort_if_not_defined "$scope" "-s:scope"

        print_debug_vl 5 "[$scope]"
        hash_dump $scope "exit status scope [$scope]"
    fi

    return
}


#==============================================================================
# destroy exit-code statistics scope
#
# Params:
# -s  : scope
# -sl : scope list
#==============================================================================
function exit_status_destroy()
{
    declare local scope=${exit_status_default_scope:-exit_status_scope}
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
            exit_status_destroy -s $s
        done
    else
        abort_if_not_defined "$scope" "-s:scope"

        print_debug_vl 5 "[$scope]"
        hash_unset_all $scope
    fi

    return
}


#==============================================================================
# set (or unset) text description for an exit-code
#
# Params:
# -s : scope
# -e : exit-code
# -t : text description
# -u : unset text description
#==============================================================================
function exit_status_text()
{
    declare local scope=${exit_status_default_scope:-exit_status_scope}
    declare local code
    declare local text
    declare local unset_text

    while [ $# -gt 0 ] ; do
        case $1 in
        -s) scope=$2        ; shift 1   ;;
        -e) code=$2         ; shift 1   ;;
        -t) text="$2"       ; shift 1   ;;
        -u) unset_text=true             ;;
         *) abort_invalid_arg $1        ;;
        esac
        shift 1
    done

    abort_if_not_defined "$scope" "-s:scope"
    abort_if_not_defined "$code"  "-e:exit-code"

    declare local code_idx
    exit_status_code_idx $code code_idx

    if [ -z "$unset_text" ] ; then
        abort_if_not_defined "$text" "-t:exit-code-text-description"

        print_debug_vl 5 "[$scope]:set[$code_idx]=[$text]"
        hash_set $scope text_${code_idx} "$text"
    else
        print_debug_vl 5 "[$scope]:unset[$code_idx]"
        hash_unset $scope text_${code_idx}
    fi

    return
}


#==============================================================================
# increment exit-code by count
#
# Params:
# -s : scope
# -e : exit-code
# -c : increment count (default=1)
#==============================================================================
function exit_status_incr()
{
    declare local scope=${exit_status_default_scope:-exit_status_scope}
    declare local code
    declare local count=1

    while [ $# -gt 0 ] ; do
        case $1 in
        -s) scope=$2    ; shift 1   ;;
        -e) code=$2     ; shift 1   ;;
        -c) count=$2    ; shift 1   ;;
         *) abort_invalid_arg $1    ;;
        esac
        shift 1
    done

    abort_if_not_defined "$scope" "-s:scope"
    abort_if_not_defined "$code"  "-e:exit-code"

    declare local code_idx
    exit_status_code_idx $code code_idx

    if hash_is_set $scope $code_idx ; then
        declare local __rv_value
        hash_get_into $scope $code_idx '__rv_value'
        let __rv_value+=$count

        print_debug_vl 5 "[$scope]:inc($count)[$code_idx]=[$__rv_value]"
        hash_set $scope $code_idx $__rv_value
    else
        print_debug_vl 5 "[$scope]:new[$code_idx]=[$count]"
        hash_set $scope $code_idx $count
    fi

    return
}


#==============================================================================
# set exit-code count(s)
#
# Params:
#  -s : scope
# -el : exit-code list (default=*)
#  -c : set exit-code count (default=0)
#  -u : unset exit-code entry
#==============================================================================
function exit_status_set()
{
    declare local scope=${exit_status_default_scope:-exit_status_scope}
    declare local list
    declare local count=0
    declare local unset_code

    while [ $# -gt 0 ] ; do
        case $1 in
        -s) scope=$2        ; shift 1   ;;
        -el) list="$2"      ; shift 1   ;;
        -c) count=$2        ; shift 1   ;;
        -u) unset_code=true             ;;
         *) abort_invalid_arg $1        ;;
        esac
        shift 1
    done

    abort_if_not_defined "$scope" "-s:scope"

    declare local idx_list
    
    # code list
    if [ -n "$list" ] ; then
        declare local code_idx
        for code in $list; do
            exit_status_code_idx $code code_idx
            idx_list+=" $code_idx"
        done
    else
        exit_status_get_list -s $scope -v 'idx_list'
    fi

    # (un)set each item in the list
    for code in $idx_list; do
        if [ -n "$unset_code" ] ; then
            print_debug_vl 5 "[$scope]:unset[$code]"
            hash_unset $scope $code
        else
            print_debug_vl 5 "[$scope]:set[$code]=[$count]"
            hash_set $scope $code $count
        fi
    done

    return
}


#==============================================================================
# get exit-code count total
#
# Params:
# -s : scope
# -e : exit-code
# -v : variable name to store total
#==============================================================================
function exit_status_get()
{
    declare local scope=${exit_status_default_scope:-exit_status_scope}
    declare local code
    declare local __rv_name

    while [ $# -gt 0 ] ; do
        case $1 in
        -s) scope=$2        ; shift 1   ;;
        -e) code=$2         ; shift 1   ;;
        -v) __rv_name=$2    ; shift 1   ;;
         *) abort_invalid_arg $1        ;;
        esac
        shift 1
    done

    abort_if_not_defined "$scope" "-s:scope"
    abort_if_not_defined "$code"  "-e:exit-code"

    declare local code_idx
    exit_status_code_idx $code code_idx
    
    declare local __rv_value=0
    
    hash_is_set $scope $code_idx &&
        hash_get_into $scope $code_idx '__rv_value'
    
    print_debug_vl 5 "[$scope]:[$code_idx]=[$__rv_value]"

    [ -n "$__rv_name" ] && eval "$__rv_name=\"${__rv_value}\""

    return
}


#==============================================================================
# get a list of exit-codes
#
# Params:
# -s : scope
# -t : list only codes with text description
# -v : variable name to list
#==============================================================================
function exit_status_get_list()
{
    declare local scope=${exit_status_default_scope:-exit_status_scope}
    declare local text
    declare local __rv_name

    while [ $# -gt 0 ] ; do
        case $1 in
        -s) scope=$2        ; shift 1   ;;
        -t) text=true                   ;;
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
        declare local text=$3

        if [ -z "$text" ] ; then
            # add only non-text entries
            [[ $key == text_* ]] && return
        else
            # add only text entries
            [[ $key != text_* ]] && return
            
            # get index: remove 'text_' from front of key
            key=${key#text_}
        fi
       
        [ -n "$__rv_value" ] && __rv_value+=" $key"
        [ -z "$__rv_value" ] && __rv_value="$key"

        return
    }

    hash_foreach $scope foreach_function $text

    print_debug_vl 5 "[$scope]:list=[$__rv_value]"

    [ -n "$__rv_name" ] && eval "$__rv_name=\"${__rv_value}\""

    return
}


#==============================================================================
# merge two exit-code scopes
#
# Params:
# -ss : source scope
# -ds : destination scope
#
# -ca : copy all
# -ct : copy text descriptions
# -cv : copy exit code values
# -av : add the exit code values
#==============================================================================
function exit_status_merge()
{
    declare local sscope=${exit_status_default_scope:-exit_status_scope}
    declare local dscope=${exit_status_default_scope:-exit_status_scope}
    declare local ca
    declare local ct
    declare local cv
    declare local av

    while [ $# -gt 0 ] ; do
        case $1 in
        -ss) sscope=$2  ; shift 1   ;;
        -ds) dscope=$2  ; shift 1   ;;
        -ca) ca=true                ;;
        -ct) ct=true                ;;
        -cv) cv=true                ;;
        -av) av=true                ;;
         *) abort_invalid_arg $1    ;;
        esac
        shift 1
    done

    [ "$sscope" == "$dscope" ] && \
        abort_not_defined "-ss:source-scope" "-ds:destination-scope"

    print_debug_vl 5 "scope-copy" \
                  -j "${ca+(all)}${ct+(text)}${cv+(values)}${av+(add)}" \
                  -j ":[$sscope]==>[$dscope]"

    # copy all
    [ -n "$ca" ] && hash_copy $sscope $dscope

    function foreach_function()
    {
        declare local key=$1
        declare local value="$2"
        declare local dscope=$3

        if [[ $key == text_* ]] ; then
            # copy text
            [ -n "$ct" ] && hash_set $dscope $key "$value"
        else
            # copy exit-code counts
            [ -n "$cv" ] && hash_set $dscope $key "$value"
            
            # add exit-code counts
            [ -n "$av" ] && exit_status_incr -s $dscope -e $key -c "$value"
        fi

        return
    }

    hash_foreach $sscope foreach_function $dscope

    return
}


#==============================================================================
# print exit-code summay
#
# Params:
#  -s : scope
#  -t : table title (default=$scope)
# -el : exit-code list (default=*)
#
# -tw : set terminal width
# -bw : set text-box width
#
# -tl : list all-and-only codes with text description
# -sb : use small text-box in output
# -nt : do not output exit-code text descriptions
# -nz : do not produce any output if there are zero total entries
#==============================================================================
function exit_status_summary()
{
    declare local scope=${exit_status_default_scope:-exit_status_scope}
    declare local title
    declare local list
    declare local tl
    declare local tw
    declare local bw
    declare local sb
    declare local nt
    declare local nz

    while [ $# -gt 0 ] ; do
        case $1 in
        -s) scope=$2        ; shift 1   ;;
        -t) title="$2"      ; shift 1   ;;
        -el) list="$2"      ; shift 1   ;;

        -tw) tw=$2          ; shift 1   ;;
        -bw) bw=$2          ; shift 1   ;;

        -tl) tl=true                    ;;
        -sb) sb=true                    ;;
        -nt) nt=true                    ;;
        -nz) nz=true                    ;;

         *) abort_invalid_arg $1        ;;
        esac
        shift 1
    done

    abort_if_not_defined "$scope" "-s:scope"

    # set title if not set
    [ -z "$title" ] && title="$scope"
    
    declare local idx_list
    # generate exit-code list
    if [ -n "$list" ] ; then
        for code in $list; do
            declare local code_idx

            exit_status_code_idx $code code_idx
            idx_list+=" $code_idx"
        done
    else
        exit_status_get_list -s $scope -v 'idx_list' ${tl+-t}
    fi

    declare local total=0
    # interate over list to obtain total entry count total
    for code in $idx_list; do
        declare local __rv_value=0

        # retreive only if an entry exists
        hash_is_set $scope $code && hash_get_into $scope $code '__rv_value'
        let total+=$__rv_value
    done

    # if configured, no output if there are zero entries
    [ -n "$nz" ] && [ $total -eq 0 ] && return
    
    # title and headings
    if [ -z "$sb" ] ; then
        print_textbox ${tw+-tw $tw} ${bw+-bw $bw} -bc 2 \
                      -lt "begin" -ct "$title" -rt "begin" -bt -pl -hr \
                      -ct "description" ${nt:+-clr} \
                      -lt " exit-code" \
                      -rt "count " -bc 1 -pl
    else
        print_textbox ${tw+-tw $tw} ${bw+-bw $bw} -bc 1 -fc "-" -vc "+" \
                      -ct " $title " -pl -fc " " -vc "|" \
                      -ct "description" ${nt:+-clr} \
                      -lt " exit-code" \
                      -rt "count " -bc 1 -pl
    fi

    # print each item
    for code in $idx_list; do
        declare local __rv_value=0
        declare local __rv_text=""

        # retreive only if an entry exists
        hash_is_set $scope $code && hash_get_into $scope $code '__rv_value'
        
        [ -z "$nt" ] && hash_is_set $scope text_${code} &&
            hash_get_into $scope text_${code} '__rv_text'

        if [ -z "$sb" ] ; then
            print_textbox ${tw+-tw $tw} ${bw+-bw $bw} \
                          -lt " [$code] " \
                          ${__rv_text:+-ct " $__rv_text "} \
                          -rt " [$__rv_value] " \
                          -fc "." -pl
        else
            print_textbox ${tw+-tw $tw} ${bw+-bw $bw} \
                          -lt " [$code] " \
                          ${__rv_text:+-ct " $__rv_text "} \
                          -rt " [$__rv_value] " \
                          -fc "." -vc "|" -pl
        fi
    done

    # total
    if [ -z "$sb" ] ; then
        print_textbox ${tw+-tw $tw} ${bw+-bw $bw} \
                      -bc 2 -lt "end" -ct "$total entries" -rt "end" \
                      -cc '~' -hc '~' -hr -bc 1 -cc '+' -hc '=' -pl -bb
    else
        print_textbox ${tw+-tw $tw} ${bw+-bw $bw} -bc 1 -fc "-" -vc "+" \
                      -ct " $total entries " -pl
    fi

    return
}


#==============================================================================
# eof
#==============================================================================

