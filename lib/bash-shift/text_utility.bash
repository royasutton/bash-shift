###############################################################################
#==============================================================================
#
# text utility functions
#
#==============================================================================
###############################################################################

include "print.bash"
include "exception.bash"

#==============================================================================
# text string statistics
#
# Params:
# -text <string>           : specify text for statistics
# -v_lcnt <vname>          : variable name for line count
# -v_cmax <vname>          : variable name for max line size
# -v_cmin <vname>          : variable name for min line size
# -v_pat_cnt <pat> <vname> : search pattern and variable name for match count
#==============================================================================
function text_string_stats()
{
    declare local text
    declare local mpat
    declare local nocase

    declare local __rvn_lcnt
    declare local __rvn_cmax
    declare local __rvn_cmin
    declare local __rvn_pcnt

    while [ $# -gt 0 ] ; do
        case $1 in
        -text)          text="$2"       ; shift 1 ;;
        -v_lcnt)        __rvn_lcnt=$2   ; shift 1 ;;
        -v_cmax)        __rvn_cmax=$2   ; shift 1 ;;
        -v_cmin)        __rvn_cmin=$2   ; shift 1 ;;
        -v_pat_cnt)     mpat="$2"       ;
                        __rvn_pcnt=$3   ; shift 2 ;;
        -i)             nocase=true               ;;
        *) abort_invalid_arg $1                   ;;
        esac

        shift 1
    done

    [ -n "$mpat" ] && \
        abort_if_not_defined "$__rvn_pcnt" "-v_pat_cnt:<pat>,<vname>"

    declare -i local __rvv_lcnt=0
    declare -i local __rvv_cmax=0
    declare -i local __rvv_cmin     # set to length of first line below

    declare -i local __rvv_pcnt=0
    declare -i local mpat_len=${#mpat}

    declare -i local idx
    declare -i local cnt=${#text}
    declare    local line

    # include 'cnt' (string size + 1) for eos processing
    for (( idx=0; idx <= cnt; idx++ )) ; do
        # count lines & min and max line size
        declare local ch

        if [ $idx -eq $cnt ] ; then
            # include end of string as last line iff size>0
            [ $idx -gt 0 ] && ch=$'\n'
        else
            ch=${text:$idx:1}
        fi

        case $ch in
        $'\n')
            declare -i local lsize=${#line}

            # set cmin to the first line size if uninitialized
            [ -z "$__rvv_cmin" ] && __rvv_cmin=$lsize

            (( lsize < ${__rvv_cmin} )) && let __rvv_cmin=lsize
            (( lsize > ${__rvv_cmax} )) && let __rvv_cmax=lsize

            let __rvv_lcnt++

            line=""
        ;;
        *)
            line+=$ch
        ;;
        esac

        # count occurances of pattern
        [ -n "$mpat" ] && (( (idx + mpat_len) <= cnt )) && \
            [[ $mpat == ${text:$idx:$mpat_len} ]] && let __rvv_pcnt++
    done

    # return specified values
    [ -n "$__rvn_cmin" ] && eval "$__rvn_cmin=\"${__rvv_cmin}\""
    [ -n "$__rvn_cmax" ] && eval "$__rvn_cmax=\"${__rvv_cmax}\""
    [ -n "$__rvn_lcnt" ] && eval "$__rvn_lcnt=\"${__rvv_lcnt}\""
    [ -n "$__rvn_pcnt" ] && eval "$__rvn_pcnt=\"${__rvv_pcnt}\""

    return
}


#==============================================================================
# eof
#==============================================================================
