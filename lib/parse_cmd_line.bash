###############################################################################
#==============================================================================
#
# command line parsing functions
#
#==============================================================================
###############################################################################

# be sure to 'source basenames.bash' prior to using these functions
include "print.bash"
include "print_textbox.bash"
include "exception.bash"

#==============================================================================
# print help message
#
# Params:
#    -ahs : append pre-formatted text to help summary
#    -alh : append library help text to help summary
#
#    -ahu : append text to help usage
#    -alu : append text to help usage
#
#     -cd : display configuration directory
#     -cf : display default configuration file full path name
# -CF|-cn : display default configuration file name w/o path
#
#     -tw : terminal width
#     -bw : box width
#
#==============================================================================
function parse_cmd_line_print_textbox_help()
{
    declare local hs
    declare local hu

    declare local cd
    declare local cf
    declare local cn

    declare local tw
    declare local bw
    
    # summary of arguments handled by parse_cmd_line.bash
    declare local ss="
 -c|--conf <file>     : specify absolute path to configuration script
 -C|--CONF <file>     : specify script in script-configuration directory

 -e|--edit            : edit configuration file
 -l|--list            : list script-configuration directory
 -s|--status          : dump expansion variable status

 -t|--trial_run       : do make perform any changes, trial only
 -b|--debug_conf      : debug configuration script

 -h|--help            : display this help message
 -v|--verbosity <int> : set run verbosity level (0-5)
                        0=quiet, 1=normal, 2=chatty, 3=verbose, 5=debug
"
    # usage of arguments handled by parse_cmd_line.bash
    declare local su=""

    while [ $# -gt 0 ] ; do
        case $1 in
       -ahs) hs+="$2"    ; shift 1  ;;
       -alh) hs+="$ss"              ;;
       
       -ahu) hu+="$2"    ; shift 1  ;;
       -alu) hu+="$su"              ;;

        -cd) cd=true                ;;
        -cf) cf=true                ;;
    -CF|-cn) cn=true                ;;

        -tw) tw=$2      ; shift 1   ;;
        -bw) bw=$2      ; shift 1   ;;

        *) abort_invalid_arg $1     ;;
        esac

        shift 1
    done

    abort_if_not_defined "$hs" "-hs:help-summary"

    print_textbox ${tw+-tw $tw} ${bw+-bw $bw} \
        -bc 2 -bt \
        -lt "(help)" -ct "${script_base_name}" -rt "(help)" -pl -clr \
        -hr -bc 1 \
        -lt "synopsis: ${script_base_name} < arguments >" -pl -clr \
        -hc '-' -hr -hc '=' \
        -lt " summary:" -pl -clr \
        -ifs '' -ljfml "$hs" \
        -hr 

    [ -n "$hu" ] && print_textbox ${tw+-tw $tw} ${bw+-bw $bw} \
        -lt " usage:" -pl -clr -bl -ljml "$hu" -hr
    
    [ -n "$cd" ] && print_textbox ${tw+-tw $tw} ${bw+-bw $bw} \
        -ct "configuration directory:" -pl \
        -ct "${script_conf_dir}" -pl \
        -bc 0 -lt "+-----" -ct "---+---" -rt "-----+" -pl

    [ -n "$cf" ] && print_textbox ${tw+-tw $tw} ${bw+-bw $bw} \
        -ct "default configuration file:" -pl -clr \
        -ct "${script_conf_file}" -pl \
        -bc 0 -lt "+-----" -ct "---+---" -rt "-----+" -pl

    [ -n "$cn" ] && print_textbox ${tw+-tw $tw} ${bw+-bw $bw} \
        -ct "default configuration name=[${script_conf_file##*/}]" -pl \
        -bc 0 -lt "+-----" -ct "---+---" -rt "-----+" -pl

    print_textbox ${tw+-tw $tw} ${bw+-bw $bw} \
        -lt "(summary)" \
        -ct "[${script_base_path}/${script_base_name}]" \
        -rt "version ${script_version}" -pl \
        -bb

    return
}


#==============================================================================
# parse command line
#
# Params:
#  1 : custom handler function name (null for none)
#  2 : minimum verbosity level for parse command line message
# $* : command line options
#==============================================================================

function parse_cmd_line()
{
    declare local handler_function=$1
    declare local verb_level=$2
    shift 2
    
    print_m_vl $verb_level "parsing command line"

    while [ $# -gt 0 ] ; do
    
        # call handler for custom options
        if [ -n "$handler_function" ] ; then
            $handler_function $*
            
            declare local ret_val=$?
            if [ $ret_val -gt 0 ] ; then
                shift $ret_val
                continue
            fi
        fi
        
        # standard options
        case $1 in
        -c|--conf)
            script_conf_file="$2"
            shift 1
        ;;
        -C|--CONF)
            script_conf_file="${script_conf_dir}/${2}"
            shift 1
        ;;
        #
        -e|--edit)
            edit_conf_flag=true
        ;;
        -l|--list)
            list_conf_flag=true
        ;;
        -s|--status)
            status_flag=true
        ;;
        #
        -t|--trial_run)
            print_m "setting trial-run mode flag [trial_run_flag=true]"
            trial_run_flag=true
        ;;
        -b|--debug_conf)
            debug_conf_flag=true
        ;;
        #
        -h|--help)
            print_help_flag=true
        ;;
        -v|--verbosity)
            verbosity_level=$2
            shift 1
        ;;
        *)
            print_m "invalid command line argument [$1]"
            print_m -J "use '$script_base_name -h' for help."
            exit 1
        ;;
        esac

        shift 1
    done

    return
}


#==============================================================================
# parsed command line flags handler
#
# Params:
# -hf : help function name (default=parse_cmd_line_print_help_handler)
#
# -cs : external command scope (default=<not-set>)
# -vs : variable expansion scope (default=<not-set>)
#
# -cr : configuration file must be specified
#==============================================================================

function parse_cmd_line_handle_flags()
{
    declare local hf="parse_cmd_line_print_help_handler"
    declare local cs
    declare local vs
    declare local cr

    while [ $# -gt 0 ] ; do
        case $1 in
        -hf) hf=$2      ; shift 1   ;;
        -cs) cs=$2      ; shift 1   ;;
        -vs) vs=$2      ; shift 1   ;;
        -cr) cr=true                ;;
        *) abort_invalid_arg $1     ;;
        esac
        shift 1
    done

    declare -i local fc=0
    
    # list the configuration directory
    if [ -n "$list_conf_flag" ] ; then
        declare local ls_l
        ext_cmd_get ${cs+-s $cs} -nv_po ls_l
        
        common_textbox -t "[ begin: configuration files ]"
        print_m -j $ls_l ${script_conf_dir}
        eval $ls_l ${script_conf_dir}
        common_textline -t "[ end: configuration files ]"
        
        let fc++
    fi

    # output 'status' expand_vars and ext_cmds
    if [ -n "$status_flag" ] ; then
        common_dump_expand_vars ${vs+-s $vs}
        print_m -j
        
        common_dump_ext_cmds ${cs+-s $cs}
        print_m -j
        
        let fc++
    fi

    # display help
    if [ -n "$print_help_flag" ] ; then
        $hf
        
        let fc++
    fi

    # configuration specified
    if [[ -n "$cr" && -z "$script_conf_file" && $fc -eq 0 ]] ; then
        common_textbox -t "please specify a configuration file." -hc "-" -bc 2
        
        print_m -j "use '$script_base_name -h' for help."
        
        exit 1
    fi

    # edit configuration file
    if [ -n "$edit_conf_flag" ] ; then
        declare local edit
        ext_cmd_get ${cs+-s $cs} -nv_p 'edit'
        
        print_m -j $edit \"$script_conf_file\"
        eval "$edit \"$script_conf_file\""
        
        let fc++
    fi

    # return number of flags processed
    return $fc
}


#==============================================================================
# eof
#==============================================================================

