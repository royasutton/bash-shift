###############################################################################
#==============================================================================
#
# terminal utility functions
#
#------------------------------------------------------------------------------
#
# terminal_enable_color (default=<not-set>)
#
#==============================================================================
###############################################################################

include "print.bash"
include "exception.bash"
include "external_command.bash"

#==============================================================================
# flush terminal standard input buffer
#
# Params:
# none
#==============================================================================
function terminal_flush_stdin()
{
    declare    local chr
    declare -i local cnt=0

    while read -t 0 ; do
       read -s -N 1 chr
       let cnt++
    done

    print_debug_vl 5 "flushed [$cnt] characters"

    return $cnt
}


#==============================================================================
# get terminal size
#
# Params:
# -s   : command scope
# -v_c : variable name for columns value
# -v_l : variable name for lines value
# -dc  : default columns if can not be determined via tput
# -dl  : default lines if can not be determined via tput
# -q   : quiet flag
#==============================================================================
function terminal_get_size()
{
    declare local cmd_scope
    declare local __rvn_cols
    declare local __rvn_lines
    declare local def_cols=80
    declare local def_lines=24
    declare local quiet

    while [ $# -gt 0 ] ; do
        case $1 in
        -s) cmd_scope=$2        ; shift 1   ;;
        -v_c) __rvn_cols=$2     ; shift 1   ;;
        -v_l) __rvn_lines=$2    ; shift 1   ;;
        -dc) def_cols=$2        ; shift 1   ;;
        -dl) def_lines=$2       ; shift 1   ;;
        -q) quiet=true                      ;;
         *) abort_invalid_arg $1            ;;
        esac
        shift 1
    done

    # retreive tput external command
    declare local tput
    ext_cmd_get -nv_p 'tput' ${cmd_scope+-s $cmd_scope}

    declare local changed_cols
    declare local changed_lines

    declare -i local new_cols
    declare -i local new_lines
    
    # get new values: columns and lines
    if [ -n "$tput" ] ; then
        new_cols=$($tput cols)
        new_lines=$($tput lines)
    else
        [ -z "$quiet" ] && print_m_vl 1 "tput not available using defaults"
        
        new_cols=$def_cols
        new_lines=$def_lines
    fi

    # current columns
    if [ -n "$__rvn_cols" ] ; then
        declare -i local cur_cols=${!__rvn_cols}
        
        if [[ $cur_cols -ne $new_cols ]] ; then
            changed_cols=true
            eval "$__rvn_cols=\"${new_cols}\""
        fi
    fi

    # current lines
    if [ -n "$__rvn_lines" ] ; then
        declare -i local cur_lines=${!__rvn_lines}
        
        if [[ $cur_lines -ne $new_lines ]] ; then
            changed_lines=true
            eval "$__rvn_lines=\"${new_lines}\""
        fi
    fi

    [ -z "$quiet" ] && print_m_vl 2 "terminal" \
        "columns=[$new_cols]${changed_cols+(updated)}" \
        "lines=[$new_lines]${changed_lines+(updated)}"

    # return change status
    if [[ -z "$changed_cols" && -z "$changed_lines" ]] ; then
        return 1
    else
        return 0
    fi
}


#==============================================================================
# set ansi terminal text colors and attributes
#
# to enable terminal color control set the variable (global to this function)
# terminal_enable_color
#
# Params:
# -ca <num>                     : color attribute  [0-8]
# -cf <num>                     : foreground color [0-7]
# -cb <num>                     : background color [0-7]
#
# -ct <[num][num][num]>         : [afb] [000-877]
#
# -raa                          : reset all attributes
#
# --attribute  | -can <aname>   : color attribute name
# --foreground | -cfn <cname>   : foreground color name
# --background | -cbn <cname>   : background color name
#
# --codes                       : show codes
#
# -v <variable-name>            : write to variable, not terminal
#
# color number and names:
#   0=black, 1=red, 2=green, 3=yellow, 4=blue, 5=magenta, 6=cyan, 7=white
#
# color attribute number and names:
#   0=reset, 1=bright or bold, 2=dim, 3=underline, 5=blink, 7=reverse, 8=hidden
#
#==============================================================================
function terminal_ansi_ctrl_ca()
{
    # if color printing is not enabled, return imediately
    [ -z "$terminal_enable_color" ] && return

    function numin()
    {
        [[ $1 == [[:digit:]] ]] && 
        (( $2 <= $1 )) && (( $1 <= $3 )) && \
            return 0

        return 1
    }
    function amap()
    {
        case ${1,,} in
        res*)       echo 0 ;;   # reset
        br*|bo*)    echo 1 ;;   # bright or bold
        d*)         echo 2 ;;   # dim
        u*)         echo 3 ;;   # underline
        bl*)        echo 5 ;;   # blink
        rev*)       echo 7 ;;   # reverse
        h*)         echo 8 ;;   # hidden
        *)          echo 0 ;;   # *
        esac

        return
    }
    function cmap()
    {
        case ${1,,} in
        bla*)       echo 0 ;;   # black
        r*)         echo 1 ;;   # red
        g*)         echo 2 ;;   # green
        y*)         echo 3 ;;   # yellow
        blu*)       echo 4 ;;   # blue
        m*)         echo 5 ;;   # magenta
        c*)         echo 6 ;;   # cyan
        w*)         echo 7 ;;   # white
        *)          echo 0 ;;   # *
        esac

        return
    }

    declare local __rv_name
    declare local sc \
                  ca \
                  cf \
                  cb \
                  ct

    while [ $# -gt 0 ] ; do
        case $1 in
        -ca)    ca=$2         ; shift 1 ;; # color attribute  [0-8]
        -cf)    cf=$2         ; shift 1 ;; # foreground color [0-7]
        -cb)    cb=$2         ; shift 1 ;; # background color [0-7]

        -ct)    ct=$2         ; shift 1 ;; # [at:fg:bg] [afb] [000-877]

        -raa) ca=0                      ;; # reset all attributes

        --attribute|-can)
                ca=$(amap $2) ; shift 1 ;; # attribute by name
        --foreground|-cfn)
                cf=$(cmap $2) ; shift 1 ;; # foreground color by name
        --background|-cbn)
                cb=$(cmap $2) ; shift 1 ;; # background color by name

        --codes) sc=true                ;; # show codes on terminal

        -v) __rv_name=$2      ; shift 1 ;; # write to variable, not terminal

         *) abort_invalid_arg $1        ;;
        esac

        shift 1
    done

    # if ct is defined, seperate and assign component values. 
    # note: this over-rides values specified prior is the argument list.
    if [ -n "$ct" ] ; then
        # make sure there are exactly three characters
        [ ${#ct} -ne 3 ] && \
            abort_error "invalid argument passed to -ct [$ct]." \
                        "must be exactly three characters [afb]."

        ca=${ct:0:1} # char 1 = attribute 
        cf=${ct:1:1} # char 2 = foreground
        cb=${ct:2:1} # char 3 = background
    fi

    declare local code="\033["
    declare local pcs
    # NOTE: This does not check for the errors ca={4|6}
    if [ -n "$ca" ] && numin $ca 0 8 ; then
        code+="$ca"
        pcs=true
    fi
    if [ -n "$cf" ] && numin $cf 0 7 ; then
        [ -n "$pcs" ] && code+=";"
        code+="$((30+$cf))"
        pcs=true
    fi
    if [ -n "$cb" ] && numin $cb 0 7 ; then
        [ -n "$pcs" ] && code+=";"
        code+="$((40+$cb))"
    fi
    code+="m"

    # if specified, write code to named variable
    if [ -n "$__rv_name" ] ; then
        declare local __rv_value="$code"
        eval "$__rv_name=\"${__rv_value}\""
    else
        [ -z "$sc" ] && print_m -j -n -e "$code"
        [ -n "$sc" ] && print_m -j -n -E "$code"
    fi

    return
}

#==============================================================================
# send ansi terminal control sequence
#
# Params:
# -bell         : sound bell
#
# -cuu <n>      : move the cursor n cells up
# -cud <n>      : move the cursor n cells down
# -cuf <n>      : move the cursor n cells forward
# -cub <n>      : move the cursor n cells back
# 
# -cnl <n>      : move the cursor to beginning of line, n lines down
# -cpl <n>      : move the cursor to beginning of line, n lines up
# 
# -cha <n>      : move the cursor to column n
# 
# -cup <n> <m>  : move the cursor to row n, column m
# -hvp <n> <m>  : move the cursor to row n, column m
# -hpa <n>      : horizontal (character/column) position absolute
# -vpa <n>      : vertical (line/row) position absolute
# 
# -ed <n>       : erase in display n={0, 1, or 2}
# -ede          : same as '-ed 0' erase from cursor to end of display
# -edb          : same as '-ed 1' erase from cursor to beginning of display
# -eda          : same as '-ed 2' erase from entire display
# 
# -el <n>       : erase in line n={0, 1, or 2}
# -ele          : same as '-el 0' erase from cursor to end of line
# -elb          : same as '-el 1' erase from cursor to beginning of line
# -ela          : same as '-el 2' erase entire line
# 
# -il           : insert n lines
# -dl           : delete n lines
# -ich          : insert n blank characters
# -dch          : delete b characters
#
# -tbm          : set scrolling region [top;bottom]
# 
# -su <n>       : scroll display up n lines
# -sd <n>       : scroll display down n lines
# 
# -rep <n>      : repeat the preceding character n times
#
# -scp          : *saves the cursor position and attributes
# -rcp          : *restores the cursor position and attributes
# 
# -scu <n>      : set style of the cursor n={0,1,2,3, or 4}
# -scubb        : same as '-scu 0' blink block
# -scusb        : same as '-scu 2' steady block
# -scubu        : same as '-scu 3' blink underline
# -scusu        : same as '-scu 4' steady underline
#
# -cus          : shows the cursor
# -cuh          : hides the cursor
#
# -rvs          : set reverse video on screen
# -rvn          : set normal video on screen
#
# -tr           : reset terminal (soft reset)
# -ris          : reset terminal to initial state (hard reset)
#
# -ts           : output text string
#
# -v <name>     : write output to variable, not terminal
#
# --codes       : show codes
#
# * not honoured by many terminal emulators
#==============================================================================
# ** the arguments of terminal_ctrl_ca may be passed to terminal_ctrl
#==============================================================================
function terminal_ansi_ctrl()
{
    declare local __rv_name
    declare local __rv_value
    declare local sc

    declare local ca_codes

    declare local esc="\033"
    declare local csi="${esc}["

    while [ $# -gt 0 ] ; do
        case $1 in
        -bell)  __rv_value+="\07"                           ;;
        
        -cuu)   __rv_value+="${csi}${2}A"       ; shift 1   ;;
        -cud)   __rv_value+="${csi}${2}B"       ; shift 1   ;;
        -cuf)   __rv_value+="${csi}${2}C"       ; shift 1   ;;
        -cub)   __rv_value+="${csi}${2}D"       ; shift 1   ;;

        -cnl)   __rv_value+="${csi}${2}E"       ; shift 1   ;;
        -cpl)   __rv_value+="${csi}${2}F"       ; shift 1   ;;

        -cha)   __rv_value+="${csi}${2}G"       ; shift 1   ;;

        -cup)   __rv_value+="${csi}${2};${3}H"  ; shift 2   ;;
        -hvp)   __rv_value+="${csi}${2};${3}f"  ; shift 2   ;;
        -hpa)   __rv_value+="${csi}${2}\`"      ; shift 1   ;;
        -vpa)   __rv_value+="${csi}${2}d"       ; shift 1   ;;

        -ed)    __rv_value+="${csi}${2}J"       ; shift 1   ;;
        -ede)   __rv_value+="${csi}0J"                      ;;
        -edb)   __rv_value+="${csi}1J"                      ;;
        -eda)   __rv_value+="${csi}2J"                      ;;
        
        -el)    __rv_value+="${csi}${2}K"       ; shift 1   ;;
        -ele)   __rv_value+="${csi}0K"                      ;;
        -elb)   __rv_value+="${csi}1K"                      ;;
        -ela)   __rv_value+="${csi}2K"                      ;;

        -il)    __rv_value+="${csi}${2}L"       ; shift 1   ;;
        -dl)    __rv_value+="${csi}${2}M"       ; shift 1   ;;
        -ich)   __rv_value+="${csi}${2}@"       ; shift 1   ;;
        -dch)   __rv_value+="${csi}${2}P"       ; shift 1   ;;

        -tbm)   __rv_value+="${csi}${2};${3}r"  ; shift 2   ;;

        -su)    __rv_value+="${csi}${2}S"       ; shift 1   ;;
        -sd)    __rv_value+="${csi}${2}T"       ; shift 1   ;;

        -rep)   __rv_value+="${csi}${2}b"       ; shift 1   ;;

        -scp)   __rv_value+="${csi}s"                       ;;
        -rcp)   __rv_value+="${csi}u"                       ;;

        -scu)   __rv_value+="${csi}${2} q"      ; shift 1   ;;
        -scubb) __rv_value+="${csi}0 q"                     ;;
        -scusb) __rv_value+="${csi}2 q"                     ;;
        -scubu) __rv_value+="${csi}3 q"                     ;;
        -scusu) __rv_value+="${csi}4 q"                     ;;
        
        -cus)   __rv_value+="${csi}?25h"                    ;;
        -cuh)   __rv_value+="${csi}?25l"                    ;;

        -rvs)   __rv_value+="${csi}?5h"                     ;;
        -rvn)   __rv_value+="${csi}?5l"                     ;;

        -tr)    __rv_value+="${csi}!p"                      ;;
        -ris)   __rv_value+="${esc}c"                       ;;
        
        -ts)    __rv_value+="$2"                ; shift 1   ;;

        -v)     __rv_name=$2                    ; shift 1   ;;

        --codes) sc=true                                    ;;
 
        # pass to terminal_ansi_ctrl_ca() - 1 variable operations
        -ca|-cf|-cb|-ct|--attribute|-can|--foreground|-cfn|--background|-cbn)
            terminal_ansi_ctrl_ca $1 $2 -v 'ca_codes'
            __rv_value+="$ca_codes"
          
            shift 1
        ;;

        # pass to terminal_ansi_ctrl_ca() - 0 variable operations
        -raa)
            terminal_ansi_ctrl_ca $1 -v 'ca_codes'
            __rv_value+="$ca_codes"
        ;;

         *) abort_invalid_arg $1                            ;;
        esac

        shift 1
    done

    # if specified, write code to named variable
    if [ -n "$__rv_name" ] ; then
        eval "$__rv_name=\"${__rv_value}\""
    else
        [ -z "$sc" ] && print_m -j -n -e "$__rv_value"
        [ -n "$sc" ] && print_m -j -n -E "$__rv_value"
    fi

    return
}


#==============================================================================
# eof
#==============================================================================
