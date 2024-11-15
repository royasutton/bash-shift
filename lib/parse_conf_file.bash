###############################################################################
#==============================================================================
#
# configuration file parsing functions
#
#==============================================================================
###############################################################################

include "common.bash"
include "file_utility.bash"
include "exit_stat.bash"

#==============================================================================
# dump parser (environment) variables (using common_print_key_value)
#
# Params:
# -l  : list of variables to dump
# -t  : title string
# -w  : set keyword feild width
# -nt : do not print title box
#==============================================================================
function parse_conf_file_dump_env_vars()
{
    declare local list
    declare local title="$script_base_name parser/environment variables (ev)"
    declare local kfw
    declare local nt

    while [ $# -gt 0 ] ; do
        case $1 in
        -l) list="$2"   ; shift 1   ;;
        -t) title="$2"  ; shift 1   ;;
        -w) kfw=$2      ; shift 1   ;;
        -nt) nt=true                ;;
        *) abort_invalid_arg $1     ;;
        esac
        shift 1
    done

    [ -z "$nt" ] && common_textbox -t "$title"

    declare local item value
    for item in $list ; do
        if [[ "$item" == ":" || "$item" == "<sep>" ]] ; then
            print_m -j
            continue
        fi
        
        value=${!item:=<not set>}
        
        common_print_key_value -k "$item" ${kfw+-w $kfw} "-n"
        print_m -j "[$value]"
    done

    return
}


#==============================================================================
# expand for loop
#
# Params:
# 1 : return variable name
# 2 : input feild seperator
# 3 : variable expansion scope
# 4 : block level
#------------------------------------------------------------------------------
# 5 : for loop iterator variable
# 6 : 'in' keyword
# * : for loop enumerated list
#==============================================================================
function parse_conf_file_expand_for_loop()
{
    declare local __rv_name=$1
    declare local cf_ifs="$2"
    declare local v_scope=$3
    declare local inc_lev=$4
    
    declare local li_var=$5
    declare local in_kw=$6
    shift 6

    # remaining form enumerated list
    declare local loop_variable_list="$*"
    
    # make sure the keyword 'in' exists as expected
    [ "${in_kw,,}" != "in" ] && \
        abort_error "invalid for-loop construct [for $li_var $in_kw $*]"

    # increment loop expansion level
    let inc_lev++

    print_m_vl 3 "block level $inc_lev;" \
                 "for [$li_var] in [$loop_variable_list]"

    declare -i local cb_line=0

    declare local block_code
    declare local got_do_keyword
    declare local break_loop_in
    declare local skip_loop_in
    
    # parse loop
    declare local tag tag_line prior_IFS=$IFS
    while IFS="$cf_ifs" read tag tag_line
    do
        IFS=$prior_IFS
        let cb_line++

        # remove leading and trailing spaces
        # make tag all lower-case using -ccl
        common_string_mod -s "$tag" -tlc -ttc -v 'tag' -ccl

        # skip comments and blank lines
        [[ "${tag:0:1}" == "#" || -z "${tag}" ]] && continue

        # expand variables in the $tag_line
        declare local exp_tag_line
        expand_var_str -i "$tag_line" -v 'exp_tag_line' -rut "" \
            ${v_scope:+-s $v_scope}

        # create array to allow index access to arguments
        declare -a local exp_tag_line_array=( $exp_tag_line )

        # enforce existence of 'do' keyword
        [[ cb_line -gt 1  &&  -z $got_do_keyword ]] &&
            abort_error "invalid for-loop construct near tag [$tag]" \
                        "'do' must exists on the line follow 'for'" \
                        "block level=[$inc_lev]" \
                        "code-block line=[$cb_line]"

        case ${tag} in
        do)
            # 'do' must exists on line one and only line one
            [ $cb_line != 1 ] && \
            abort_error "invalid for-loop construct near tag [$tag]" \
                        "'do' must exists once and only once" \
                        "block level=[$inc_lev]" \
                        "code-block line=[$cb_line]"
            got_do_keyword=true
        ;;
        done)
            break
        ;;
        skip)
            [ ${#exp_tag_line_array[@]} == 0 ] && \
                abort_error "skip missing arguments" \
                            "block level=[$inc_lev]" \
                            "code-block line=[$cb_line]"
  
            skip_loop_in="$exp_tag_line"
            
            # verify that each skip condition exists in $loop_variable_list
            for skip_loop_in_iter in $skip_loop_in
            do
                declare local skip_condition_exist=""
                for loop_variable_iter in $loop_variable_list
                do
                    if [ "$loop_variable_iter" == "$skip_loop_in_iter" ] ; then
                        skip_condition_exist=true
                        break
                    fi
                done
                
                [ -z "$skip_condition_exist" ] && 
                abort_error "invalid skip condition [${skip_loop_in_iter}]" \
                            "block level=[$inc_lev]" \
                            "code-block line=[$cb_line]"
            done

            block_code+="# skip encountered"
            block_code+=", skip for in [$li_var]=[$skip_loop_in]"
            block_code+=", block level=[$inc_lev]\n"
            
            print_m_vl 3 "block level $inc_lev;" \
                         "skip-for in [$li_var]=[$skip_loop_in]"
        ;;
        break)
            [ -n "$break_loop_in" ] && \
            abort_error "multiple breaks in loop-code block" \
                        "block level=[$inc_lev]" \
                        "code-block line=[$cb_line]"

            # syntax: break (in word)
            # set break word
            if [ ${#exp_tag_line_array[@]} == 0 ] ; then
                # set to first work in $loop_variable_list
                declare -a loop_variable_array=( $loop_variable_list )
                
                break_loop_in=${loop_variable_array[0]}
            else
                # parse from break arguments
                [[ "${exp_tag_line_array[0],,}" != "in" || \
                   ${#exp_tag_line_array[@]} != 2 ]] && \
                abort_error "invalid break construct [$tag $tag_line]" \
                            "block level=[$inc_lev]" \
                            "code-block line=[$cb_line]"

                break_loop_in=${exp_tag_line_array[1]}
                
                # verify that break condition exists in $loop_variable_list
                declare local break_condition_exist
                for loop_variable_iter in $loop_variable_list
                do
                    if [ "$loop_variable_iter" == "$break_loop_in" ] ; then
                        break_condition_exist=true
                        break
                    fi
                done
                
                [ -z "$break_condition_exist" ] && 
                abort_error "invalid break condition [${break_loop_in}]" \
                            "block level=[$inc_lev]" \
                            "code-block line=[$cb_line]"
            fi
                        
            block_code+="# break encountered"
            block_code+=", break for in [$li_var]=[$break_loop_in]"
            block_code+=", block level=[$inc_lev]\n"
            
            print_m_vl 3 "block level $inc_lev;" \
                         "break-for in [$li_var]=[$break_loop_in]"
        ;;
        for)
            # expanded / unroll loop code
            parse_conf_file_expand_for_loop \
                $__rv_name "$cf_ifs" "$v_scope" \
                $inc_lev $exp_tag_line

            # append expanded nested loop code to local-level code block
            # if a 'break' has not been set
            [ -z "$break_loop_in" ] && \
                block_code+=${!__rv_name}
        ;;
        *) 
            # if 'break' has not been set
            [ -z "$break_loop_in" ] && \
                block_code+="$tag $tag_line\n"
        ;;
        esac
    done

    # expanded / unroll the local loop code
    declare local expanded_code
    for loop_variable_iter in $loop_variable_list
    do
        # check to 'loop_variable_iter' in 'skip_loop_in'
        for skip_loop_in_iter in $skip_loop_in ; do
            [ "$loop_variable_iter" == "$skip_loop_in_iter" ] && continue 2
        done

        # add comment
        expanded_code+="# block level=$inc_lev"
        expanded_code+=", iterator $li_var=[$loop_variable_iter]\n"
                            
        # update loop variable
        expanded_code+="set $li_var $loop_variable_iter\n"
        
        # expand loop code
        expanded_code+="$block_code"
        
        [ "$loop_variable_iter" == "$break_loop_in" ] && break
    done
    # clear loop variable
    expanded_code+="unset $li_var\n"

    print_debug_vl 7 -e "$__rv_name=\"\n$expanded_code\""
  
    # avoid evaluating words in the loop code.
    # variable expansion to occure during code exection not during loop-expansion.
    # preceeded by '$' by replacing all occurances of '$' with '\$' before eval
    expanded_code=${expanded_code//\$/\\$}
    
    eval "$__rv_name=\"$expanded_code\""

    print_m_vl 3 "block level $inc_lev;" \
                 "for [$li_var] expanded"
    
    return
}


#==============================================================================
# parse configuration file line
#
# Params:
#  1 : custom-tag handler funtion
#  2 : environment variable name list
#  3 : tag-name black-list
#  4 : input feild seperator
#  5 : configuration file include level
#  6 : command exit status scope (for accumulated totals)
#  7 : configuration file debug mode
#------------------------------------------------------------------------------
#  8 : external command scope
#  9 : variable expansion scope
# 10 : exit statistics scope (for current include level)
# 11 : line tag
# 12 : unexpanded line arguments string
# $* : expanded line arguments
#==============================================================================
function parse_conf_file_line()
{
    declare local tag_handler=$1        # handler funtion
    declare local ev_tag_list="$2"      # variable list
    declare local tag_blacklist="$3"    # tag blacklist
    declare local cf_ifs="$4"           # input feild seperator
    declare local inc_lev=$5            # included file level
    declare local x_scope=$6            # exit-stats scope (accumulated)
    declare local debug_conf=$7         # config file debug mode

    declare local c_scope=$8            # external command scope
    declare local v_scope=$9            # variable expansion scope
    declare local e_scope=${10}         # exit-stats scope (current inc. level)
    declare local tag=${11}             # line tag command
    declare local tag_line="${12}"      # unexpanded line arguments string
    shift 12                            # $* expanded line arguments

    #-------------------------------------------------------------------------#
    # helper function: validate variable name (in $ev_tag_list)
    function parse_conf_file_env_vars_validate()
    {
        for item in $1 ; do
            [[ "$item" == ":" || "$item" == "<sep>" ]] && continue
            [[ "$item" == "$2" ]] && return
        done
        abort_error "invalid environment variable [$2]"
    }
    
    #-------------------------------------------------------------------------#
    # (1) call custom tags handler function (if defined)
    #     handler function to return 1 if the tag was handled
    if [ -n "$tag_handler" ] ; then
        $tag_handler "$c_scope" "$v_scope" $e_scope \
                     $tag "$tag_line" $* || return
    fi

    #-------------------------------------------------------------------------#
    # (2) environment variables handler (short-set form)
    for item in $ev_tag_list ; do
        [[ "$item" == ":" || "$item" == "<sep>" ]] && continue
        if [[ "$tag" == "$item" ]] ; then
            # tag is custom environment variables, set its value
            print_m_vl 3 "(ev_set) ${tag}=[$*]"
            eval "$tag=\"$*\""
            return
        fi
    done

    #-------------------------------------------------------------------------#
    # (3) standard tag handler
    case ${tag} in

    # environment variables (long-form)
    ev_clr) parse_conf_file_env_vars_validate "$ev_tag_list" $1
            declare local __rv_name=$1 ; shift 1
            declare local __rv_value=""
            print_m_vl 3 "$tag ${__rv_name}=[${__rv_value}]"
            eval "$__rv_name=\"$__rv_value\"" ;;
    ev_set) parse_conf_file_env_vars_validate "$ev_tag_list" $1
            declare local __rv_name=$1 ; shift 1
            declare local __rv_value="$*"
            print_m_vl 3 "$tag ${__rv_name}=[${__rv_value}]"
            eval "$__rv_name=\"$__rv_value\"" ;;
    ev_add) parse_conf_file_env_vars_validate "$ev_tag_list" $1
            declare local __rv_name=$1 ; shift 1
            declare local __rv_value="${!__rv_name}"
            [ -n "$__rv_value" ] && __rv_value+=" $*"
            [ -z "$__rv_value" ] && __rv_value="$*"
            print_m_vl 3 "$tag ${__rv_name}=[${__rv_value}]"
            eval "$__rv_name=\"$__rv_value\"" ;;
    ev_app) parse_conf_file_env_vars_validate "$ev_tag_list" $1
            declare local __rv_name=$1 ; shift 1
            declare local __rv_value="${!__rv_name}$*"
            print_m_vl 3 "$tag ${__rv_name}=[${__rv_value}]"
            eval "$__rv_name=\"$__rv_value\"" ;;
    ev_prp) parse_conf_file_env_vars_validate "$ev_tag_list" $1
            declare local __rv_name=$1 ; shift 1
            declare local __rv_value="$*${!__rv_name}"
            print_m_vl 3 "$tag ${__rv_name}=[${__rv_value}]"
            eval "$__rv_name=\"$__rv_value\"" ;;
    #
    ev_dump) 
        if check_vl 1 ; then
            [ -z "$1" ] && parse_conf_file_dump_env_vars -l "$ev_tag_list"
            [ -n "$1" ] && parse_conf_file_dump_env_vars -l "$*" -nt
        fi
    ;;
    #-------------------------------------------------------------------------#
    file_check)
        print_m_vl 1 "$tag( $* )"
        if ! ${tag} $* ; then
            print_m -J "returned error, context break..." \
            ${trial_run:+(trial, continuing)}
            [ -z "$trial_run" ] && break
        else
            print_m_vl 1 -J "returned ok"
        fi
    ;;
    file_check_owner | file_check_mode)
        print_m_vl 1 "$tag( $* )"
        if ! ${tag} ${c_scope:+-s $c_scope} $* ; then
            print_m -J "returned error, context break..." \
            ${trial_run:+(trial, continuing)}
            [ -z "$trial_run" ] && break
        else
            print_m_vl 1 -J "returned ok"
        fi
    ;;
    file_backup)
        print_m_vl 1 "$tag( $* ) ${trial_run:+(trial)}"
        if [ -z "$trial_run" ] ; then
            if ! ${tag} ${c_scope:+-s $c_scope} $* ; then
                print_m -J "returned error, context break..." \
                ${trial_run:+(trial, continuing)}
                [ -z "$trial_run" ] && break
            else
                print_m_vl 1 -J "returned ok"
            fi
        fi
    ;;
    ls)
        if check_vl 1 ; then
            declare local ls_l
            ext_cmd_get -nv_po ls_l ${c_scope:+-s $c_scope}
            common_textline -t "[ begin: $tag ]"
            print_m -j $ls_l $*
            eval "$ls_l \"$*\""
            common_textline -t "[ end: $tag ]"
        fi
    ;;
    mkdir)
        declare local md_pm755
        ext_cmd_get -nv_po md_pm755 ${c_scope:+-s $c_scope}
        print_m_vl 1 "$md_pm755 $* ${trial_run:+(trial)}"
        [ -z "$trial_run" ] && eval "$md_pm755 \"$*\""
    ;;
    gzip)
        declare local gzip
        ext_cmd_get -nv_p gzip ${c_scope:+-s $c_scope}
        print_m_vl 1 "$gzip $* ${trial_run:+(trial)}"
        [ -z "$trial_run" ] && eval "$gzip \"$*\""
    ;;
    #-------------------------------------------------------------------------#
    for)
        declare local expanded_loop_code

        print_m_vl 2 "expanding for-loop to temporary file"

        # expanded / unroll loop code
        parse_conf_file_expand_for_loop \
            'expanded_loop_code' "$cf_ifs" "$v_scope" \
            0 $*

        # append expanded_loop_code to loop_file
        declare local loop_file=${script_tmp_root}-${inc_lev}
        echo -e $expanded_loop_code > $loop_file
        
        print_debug_vl 7 -e "expanded to[$loop_file]=\"\n$expanded_loop_code\""

        # process expanded loop
        parse_conf_file -f "$loop_file" -l $inc_lev -ifs "$cf_ifs" \
                        ${tag_handler:+-th $tag_handler} \
                        ${ev_tag_list:+-vl "$ev_tag_list"} \
                        ${tag_blacklist:+-tb "$tag_blacklist"} \
                        ${debug_conf:+-db} \
                        ${c_scope:+-cs $c_scope} \
                        ${v_scope:+-vs $v_scope} \
                        ${x_scope:+-es $x_scope}
        
        # delete tmp file
        print_m_vl 2 "removing expanded for-loop temporary file"
        declare local rm_f
        ext_cmd_get -nv_po rm_f ${c_scope:+-s $c_scope}
        eval "$rm_f \"$loop_file\""
    ;;
    #
    include)
        parse_conf_file -f "$*" -l $inc_lev -ifs "$cf_ifs" \
                        ${tag_handler:+-th $tag_handler} \
                        ${ev_tag_list:+-vl "$ev_tag_list"} \
                        ${tag_blacklist:+-tb "$tag_blacklist"} \
                        ${debug_conf:+-db} \
                        ${c_scope:+-cs $c_scope} \
                        ${v_scope:+-vs $v_scope} \
                        ${x_scope:+-es $x_scope}
    ;;
    #-------------------------------------------------------------------------#
    sv_set | set)
        declare local name=$1 ; shift 1
        declare local value="$*"

        abort_if_not_defined "$name"  "variable-name"
        abort_if_not_defined "$value" "variable-value"

        print_m_vl 2 "$tag ${name}=[${value}]"
        expand_var_set -n $name -v "$value" ${v_scope:+-s $v_scope}
    ;;
    sv_unset | unset)
        abort_if_not_defined "$1" "variable-name"

        while [ $# -gt 0 ] ; do
            print_m_vl 2 "$tag $1"
            expand_var_unset -n $1 ${v_scope:+-s $v_scope}
            shift 1
        done
    ;;
    #
    sv_dump)
        check_vl 1 && common_dump_expand_vars ${1+-l "$*" -nt} \
                                              ${v_scope:+-s $v_scope}
    ;;
    #-------------------------------------------------------------------------#
    aa_set)
        declare local name=$1 ; shift 1
        abort_if_not_defined "$name" "array-name"
        while [ $# -gt 0 ] ; do
            declare local key=${1%=*} value=${1#*=} ; shift 1
            print_m_vl 2 "$tag $name[$key]=[$value]"
            [[ "$key" == "$value" || -z $key ]] && \
                abort_not_defined "key=value"
            expand_var_set -n __aa_${name}_${key} -v "$value" \
                ${v_scope:+-s $v_scope}
        done
    ;;
    aa_sets)
        declare local name=$1 ; shift 1
        abort_if_not_defined "$name" "array-name"
        declare local key=$1 ; shift 1
        declare local value=$*
        print_m_vl 2 "$tag $name[$key]=[$value]"
        [[ -z $key ]] && abort_not_defined "key string"
        expand_var_set -n __aa_${name}_${key} -v "$value" \
            ${v_scope:+-s $v_scope}
    ;;
    aa_get | aa_get_ife)
        [ $# -ne 3 ] && abort_not_defined "array_name key value-variable-name"
        declare local __aa_n_k_value
        if ! expand_var_get -n __aa_${1}_${2} -v __aa_n_k_value \
           ${v_scope:+-s $v_scope}
        then
            [[ "$tag" == "aa_get" ]] && abort_error "$tag $1[$2] (not defined)"
        fi
        print_m_vl 2 "$tag $1[$2]=[$__aa_n_k_value]-->[!{$3}]"
        expand_var_set -n $3 -v "$__aa_n_k_value" \
            ${v_scope:+-s $v_scope}
    ;;
    aa_unset)
        declare local name=$1 ; shift 1
        abort_if_not_defined "$name" "array-name"
        declare local key_list="$*"
        if [ -z "$key_list" ] ; then
            declare local list
            expand_var_get_list -v list ${v_scope:+-s $v_scope}
            for item in $list ; do
                [[ "$item" == __aa_${name}_* ]] && key_list+=" ${item#__aa_${name}_}"
            done
        fi
        for key in $key_list ; do
            if expand_var_get -n __aa_${name}_${key} ${v_scope:+-s $v_scope}
            then
                print_m_vl 2 "$tag $name[$key]"
                expand_var_unset -n __aa_${name}_${key} ${v_scope:+-s $v_scope}
            else
                print_m_vl 1 "$tag $name[$key] (not defined)"
            fi
        done
    ;;
    #-------------------------------------------------------------------------#
    ec_dump)    check_vl 1 && common_dump_ext_cmds ${1+-l "$*" -nt} \
                                                   ${c_scope:+-s $c_scope}
    ;;
    #
    trial_run)  trial_run=true
                check_vl 1 && common_textbox \
                    -t "trial-run set in script [trial_run=true]" -hvc "#" 
    ;;
    #-------------------------------------------------------------------------#
    textbox3)   check_vl 1 && common_textbox -t " $* " -bc 2 -hc '~' -fc '-' ;;
    textbox2)   check_vl 1 && common_textbox -t "$*" -bc 2 ;;
    textbox)    check_vl 1 && common_textbox -t "$*" ;;
    textline)   check_vl 1 && common_textline -t "$*" ;;
    text)       check_vl 1 && print_m $* ;;
    echo)       check_vl 1 && print_m -j $* ;;
    #-------------------------------------------------------------------------#
    break)      check_vl 1 && \
                    common_textbox -t "${tag}() encountered; context break..."
                break ;;
    exit)       common_textbox -t "${tag}() encountered; exiting..." -hvc "#"
                exit 1 ;;
    #-------------------------------------------------------------------------#
    *) abort_error "invalid tag [$tag] encountered" ;;
    esac

    return
}


#==============================================================================
# parse configuration file
#
# Params:
#   -f : configuration file name
#   -l : configuration file include level (default=0)
#
# -ifs : configuration file tag/arguments input feild seperator
#
#  -th : custom tag handler funtion
#  -vl : environment variable list
#  -tb : tag black-list
#
#  -cs : external command scope
#  -vs : variable expansion scope
#  -es : command exit status scope (for accumulated totals)
#
#  -db : set script debug mode flag
#  -tr : set trial run mode flag (sets 'trial_run' global variable)
#==============================================================================
function parse_conf_file()
{
    declare local file_name
    declare local inc_lev=0
    
    declare local cf_ifs=$' \t\n'

    declare local tag_handler
    declare local ev_tag_list
    declare local tag_blacklist

    declare local c_scope
    declare local v_scope
    declare local x_scope
    
    declare local debug_conf
  # declare -g local trial_run
    
    while [ $# -gt 0 ] ; do
        case $1 in
        -f) file_name="$2"      ; shift 1   ;;
        -l) inc_lev=$2          ; shift 1   ;;

        -ifs) cf_ifs="$2"       ; shift 1   ;;

        -th) tag_handler=$2     ; shift 1   ;;
        -vl) ev_tag_list="$2"   ; shift 1   ;;
        -tb) tag_blacklist="$2" ; shift 1   ;;

        -cs) c_scope=$2         ; shift 1   ;;
        -vs) v_scope=$2         ; shift 1   ;;
        -es) x_scope=$2         ; shift 1   ;;

        -db) debug_conf=true                ;;
        -tr) trial_run=true                 ;;

        *) abort_invalid_arg $1             ;;
        esac
        shift 1
    done

    print_m_vl 1 "script begin: [$file_name]" \
                 ${debug_conf:+ (debug)} ${trial_run:+(trial)}

    # check configuration file
    file_check -d "$script_base_name configuration file" \
               -f "$file_name" -p 'efr' || abort_error

    # increment include file block level
    let inc_lev++

    # prepare exit status scope for this include level
    # (1) create scope name and
    # (2) copy titles from 'accumulator' (iff they will be printed later)
    declare local e_scope=${FUNCNAME}${inc_lev}
    check_vl 2 && exit_status_merge ${x_scope:+-ss $x_scope} -ds $e_scope -ct

    # used when 'debug_conf' is set
    declare local cmd_num=0 fmt_cmd_num fmt_inc_lev

    # process file line-by-line
    declare local tag tag_line prior_IFS=$IFS
    while IFS="$cf_ifs" read tag tag_line
    do
        IFS=$prior_IFS
         
        # remove leading and trailing spaces
        # make tag all lower-case using -ccl
        common_string_mod -s "$tag" -tlc -ttc -v 'tag' -ccl
        common_string_mod -s "$tag_line" -tlc -ttc -v 'tag_line'

        # skip comments and blank lines
        [[ "${tag:0:1}" == "#" || -z "${tag}" ]] && continue
        
        #---------------------------------------------------------------------#
        # enforce tag blacklist
        for item in $tag_blacklist ; do
            [[ "$tag" == "$item" ]] && \
                abort_error "invalid tag [$tag] (blacklisted)" \
                            "in [$file_name]"
        done
        #---------------------------------------------------------------------#
        # debuging
        print_debug_vl 5 "[$tag]=[$tag_line]"
        
        if [ -n "$debug_conf" ] ; then
            # script debuging is set
            let cmd_num++
            printf -v fmt_cmd_num "%3d" $cmd_num
            printf -v fmt_inc_lev "%2d" $inc_lev
            
            print_m -j " (${fmt_inc_lev}) ${fmt_cmd_num} :" \
                       "$tag(${tag_line:+ $tag_line })"

            # in debug mode, honor the following tags:
            #
            # (1) custom environment variables short form
            # (2) custom environment variables long form
            # (3) expansion variable set and unset (short and long keyword)
            # (4) 'for' and 'include' operations
            #
            declare local honor_tag_list="
                $ev_tag_list
                ev_clr ev_set ev_add ev_app ev_prp
                set unset sv_set sv_unset
                aa_set aa_sets aa_get aa_get_ife aa_unset
                for include"
            
            declare local honor_tag=""
            for item in $honor_tag_list ; do
                [[ "$item" == ":" || "$item" == "<sep>" ]] && continue
                if [[ "$tag" == "$item" ]] ; then
                    honor_tag=true
                    break
                fi
            done

            [ -z "$honor_tag" ] && continue
        fi
        #---------------------------------------------------------------------#
        
        # expand variables in the $tag_line
        declare local exp_tag_line
        expand_var_str -i "$tag_line" -v 'exp_tag_line' ${v_scope:+-s $v_scope}

        # process line for 'tag' and expanded 'tag_line'
        parse_conf_file_line "$tag_handler" "$ev_tag_list" "$tag_blacklist" \
                             "$cf_ifs" $inc_lev "$x_scope" "$debug_conf" \
                             "$c_scope" "$v_scope" "$e_scope" \
                             $tag "$tag_line" $exp_tag_line
        
    done < "$file_name"

    # output exit stats for this include level
    check_vl 2 && exit_status_summary -s $e_scope \
                    -t "wget exit-code summary ($e_scope)" -sb -nz
                            
    # add stats for this include-level to 'accumulator' scope totals
    exit_status_merge ${x_scope:+-ds $x_scope} -ss $e_scope -av
    
    exit_status_destroy -s $e_scope

    print_m_vl 1 "script end: [$file_name]" \
                 ${debug_conf:+ (debug)} ${trial_run:+(trial)}

    return
}


#==============================================================================
# eof
#==============================================================================

