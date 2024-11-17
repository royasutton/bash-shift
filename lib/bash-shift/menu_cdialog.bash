###############################################################################
#==============================================================================
#
# menu functions in bash (compatible with cdialog's '-menu')
#
#------------------------------------------------------------------------------
#
# menu_default_id (default=menu_0)
# menu_render_show_tags (default=<not-set>)
# menu_render_center (default=<not-set>)
#
#==============================================================================
###############################################################################

include "print.bash"
include "exception.bash"
include "print_textbox.bash"
include "terminal_utility.bash"
include "external_command.bash"
include "hash_table.bash"

#==============================================================================
# dump menu
#
# Params:
# -m  : menu-id
# -ml : menu-id list
#==============================================================================
function menu_dump()
{
    declare local menu=${menu_default_id:-menu_0}
    declare local list

    while [ $# -gt 0 ] ; do
        case $1 in
        -m) menu=$2    ; shift 1    ;;
        -ml) list="$2" ; shift 1    ;;
        *)  abort_invalid_arg $1    ;;
        esac
        shift 1
    done

    if [ -n "$list" ] ; then
        for m in $list ; do
            menu_dump -m $m
        done
    else
        abort_if_not_defined "$menu" "-m:menu-id"
        print_debug_vl 5 "[$menu]"
        hash_dump $menu "menu-id [$menu] definition"
    fi

    return
}


#==============================================================================
# destroy menu
#
# Params:
# -m  : menu-id
# -ml : menu-id list
#==============================================================================
function menu_destroy()
{
    declare local menu=${menu_default_id:-menu_0}
    declare local list

    while [ $# -gt 0 ] ; do
        case $1 in
        -m) menu=$2    ; shift 1    ;;
        -ml) list="$2" ; shift 1    ;;
        *)  abort_invalid_arg $1    ;;
        esac
        shift 1
    done

    if [ -n "$list" ] ; then
        for m in $list ; do
            menu_destroy -m $m
        done
    else
        abort_if_not_defined "$menu" "-m:menu-id"
        print_debug_vl 5 "[$menu]"
        hash_unset_all $menu
    fi

    return
}


#==============================================================================
# check if keyword is a 'reserved word' ie: a menu construct
#
# Params:
# -w : word
#==============================================================================
function menu_is_word_reserved()
{
    declare local word

    while [ $# -gt 0 ] ; do
        case $1 in
        -w) word=$2    ; shift 1    ;;
         *) abort_invalid_arg $1    ;;
        esac
        shift 1
    done

    if [[  $word == _menu_layout_*_ || $word == _menu_eval_*_ ]] ; then
        return 0
    else
        return 1
    fi
}


#==============================================================================
# check if word is a menu layout property name
#
# Params:
# -p : property
#==============================================================================
function menu_is_property()
{
    declare local prop

    while [ $# -gt 0 ] ; do
        case $1 in
        -p) prop=$2    ; shift 1    ;;
         *) abort_invalid_arg $1    ;;
        esac
        shift 1
    done

    if [[  $prop == height \
        || $prop == width \
        || $prop == mheight \
        || $prop == ok_label \
        || $prop == cancel_label \
        || $prop == title \
        || $prop == title_tree \
        || $prop == prompt \
        || $prop == default \
        || $prop == default_text \
        || $prop == timeout \
       ]]
    then
        return 0
    else
        return 1
    fi
}


#==============================================================================
# set menu layout property
#
# Params:
# -m : menu-id
# -p : property
# -v : value
#==============================================================================
function menu_set_layout()
{
    declare local menu=${menu_default_id:-menu_0}
    declare local prop
    declare local value

    while [ $# -gt 0 ] ; do
        case $1 in
        -m) menu=$2     ; shift 1    ;;
        -p) prop=${2,,} ; shift 1    ;;
        -v) value="$2"  ; shift 1    ;;
         *) abort_invalid_arg $1     ;;
        esac
        shift 1
    done

    abort_if_not_defined "$menu" "-m:menu-id"
    abort_if_not_defined "$prop" "-p:property"

    menu_is_property -p $prop || \
        abort_error "invalid menu layout property [$prop] in menu-id [$menu]"

    print_debug_vl 5 "[$menu]:[$prop]=[$value]"

    hash_set $menu _menu_layout_${prop}_ "$value"

    return
}


#==============================================================================
# get menu layout property
#
# Params:
#  -m : menu-id
#  -p : property
#  -v : variable name to store property value
# -pv : property and variable name to store property value (at once)
#==============================================================================
function menu_get_layout()
{
    declare local menu=${menu_default_id:-menu_0}
    declare local prop
    declare local __rv_name

    while [ $# -gt 0 ] ; do
        case $1 in
        -m) menu=$2         ; shift 1   ;;
        -p) prop=${2,,}     ; shift 1   ;;
        -v) __rv_name=$2    ; shift 1   ;;
       -pv) prop=${2,,}
            __rv_name=$2    ; shift 1   ;;
         *) abort_invalid_arg $1        ;;
        esac
        shift 1
    done

    abort_if_not_defined "$menu" "-m:menu-id"
    abort_if_not_defined "$prop" "-p:property"

    menu_is_property -p $prop || \
        abort_error "invalid menu layout property [$prop] in menu-id [$menu]"

    if hash_is_set $menu _menu_layout_${prop}_ ; then
        declare local __rv_value

        hash_get_into $menu _menu_layout_${prop}_ '__rv_value'

        print_debug_vl 5 "[$menu]:[$prop]=[$__rv_value]"

        [ -n "$__rv_name" ] && eval "$__rv_name=\"${__rv_value}\""

        return 0
    else
        print_debug_vl 5 "[$menu]:[$prop]=(not defined)"

        return 1
    fi
}


#==============================================================================
# set menu entry
#
# Params:
# -m : menu-id
# -i : entry tag-id
# -t : entry text
# -c : entry eval code
#==============================================================================
function menu_set_entry()
{
    declare local menu=${menu_default_id:-menu_0}
    declare local tag
    declare local text
    declare local code

    while [ $# -gt 0 ] ; do
        case $1 in
        -m) menu=$2     ; shift 1   ;;
        -i) tag=$2      ; shift 1   ;;
        -t) text="$2"   ; shift 1   ;;
        -c) code="$2"   ; shift 1   ;;
         *) abort_invalid_arg $1    ;;
        esac
        shift 1
    done

    abort_if_not_defined "$menu" "-m:menu-id"
    abort_if_not_defined "$tag"  "-i:entry-tag-id"

    print_debug_vl 5 "[$menu]:[$tag]=[$text]"

    hash_set $menu $tag "$text"

    [ -n "$code" ] && menu_set_eval -m $menu -i $tag -c "$code"

    return
}


#==============================================================================
# get menu entry
#
# Params:
# -m : menu-id
# -i : entry tag-id
# -v : variable name to store menu entry text
#==============================================================================
function menu_get_entry()
{
    declare local menu=${menu_default_id:-menu_0}
    declare local tag
    declare local __rv_name

    while [ $# -gt 0 ] ; do
        case $1 in
        -m) menu=$2         ; shift 1   ;;
        -i) tag=$2          ; shift 1   ;;
        -v) __rv_name=$2    ; shift 1   ;;
         *) abort_invalid_arg $1        ;;
        esac
        shift 1
    done

    abort_if_not_defined "$menu" "-m:menu-id"
    abort_if_not_defined "$tag"  "-i:entry-tag-id"

    if hash_is_set $menu $tag ; then
        declare local __rv_value

        hash_get_into $menu $tag '__rv_value'

        print_debug_vl 5 "[$menu]:[$tag]=[$__rv_value]"

        [ -n "$__rv_name" ] && eval "$__rv_name=\"${__rv_value}\""

        return 0
    else
        print_debug_vl 5 "[$menu]:[$tag]=(not defined)"

        return 1
    fi
}


#==============================================================================
# set menu entry eval code
#
# Params:
# -m : menu-id
# -i : entry tag-id
# -c : entry eval code
#==============================================================================
function menu_set_eval()
{
    declare local menu=${menu_default_id:-menu_0}
    declare local tag
    declare local code

    while [ $# -gt 0 ] ; do
        case $1 in
        -m) menu=$2     ; shift 1   ;;
        -i) tag=$2      ; shift 1   ;;
        -c) code="$2"   ; shift 1   ;;
         *) abort_invalid_arg $1    ;;
        esac
        shift 1
    done

    abort_if_not_defined "$menu" "-m:menu-id"
    abort_if_not_defined "$tag"  "-i:entry-tag-id"

    # verify the entry tag-id exists
    if hash_is_set $menu $tag || [ "$tag" == "cancel" ] ; then
        print_debug_vl 5 "[$menu]:[$tag]=[$code]"

        hash_set $menu _menu_eval_${tag}_ "$code"
    else
        abort_error "attempt to assign code to menu tag that does not exists," \
                    "menu[$menu]:tag[$tag]=code[$code]."
    fi

    return 0
}


#==============================================================================
# get menu entry eval code
#
# Params:
# -m : menu-id
# -i : entry tag-id
# -v : variable name to store eval code
#==============================================================================
function menu_get_eval()
{
    declare local menu=${menu_default_id:-menu_0}
    declare local tag
    declare local __rv_name

    while [ $# -gt 0 ] ; do
        case $1 in
        -m) menu=$2         ; shift 1   ;;
        -i) tag=$2          ; shift 1   ;;
        -v) __rv_name=$2    ; shift 1   ;;
         *) abort_invalid_arg $1        ;;
        esac
        shift 1
    done

    abort_if_not_defined "$menu" "-m:menu-id"
    abort_if_not_defined "$tag"  "-i:entry-tag-id"

    if hash_is_set $menu _menu_eval_${tag}_ ; then
        declare local __rv_value

        hash_get_into $menu _menu_eval_${tag}_ '__rv_value'

        print_debug_vl 5 "[$menu]:[$tag]=[$__rv_value]"

        [ -n "$__rv_name" ] && eval "$__rv_name=\"${__rv_value}\""

        return 0
    else
        print_debug_vl 5 "[$menu]:[$tag]=(not defined)"

        return 1
    fi
}


#==============================================================================
# get list of menu entry tag-id's
#
# Params:
# -m : menu-id
# -v : variable name to store tag-id list
#==============================================================================
function menu_get_entry_list()
{
    declare local menu=${menu_default_id:-menu_0}
    declare local __rv_name

    while [ $# -gt 0 ] ; do
        case $1 in
        -m) menu=$2         ; shift 1   ;;
        -v) __rv_name=$2    ; shift 1   ;;
         *) abort_invalid_arg $1        ;;
        esac
        shift 1
    done

    abort_if_not_defined "$menu" "-m:menu-id"

    declare local __rv_value

    function foreach_function()
    {
        declare local key=$1

        # skip menu construct keywords
        menu_is_word_reserved -w $key && return

        [ -n "$__rv_value" ] && __rv_value+=" $key"
        [ -z "$__rv_value" ] && __rv_value="$key"

        return
    }

    hash_foreach $menu foreach_function

    print_debug_vl 5 "[$menu]:list=[$__rv_value]"

    [ -n "$__rv_name" ] && eval "$__rv_name=\"${__rv_value}\""

    return
}


#==============================================================================
# render menu to terminal
#
# to show menu tags set the variable (global to this function)
# menu_render_show_tags
#
# to center the menu entries, set the variable (global to this function)
# menu_render_center
#
# Params:
# --backtitle       : < t >         : set the back-title
# --title           : < t >         : set the menu title
# --ok-label        : < t >         : set text for the ok button
# --cancel-label    : < t >         : set text for the cancel button
# --no-cancel       :               : ignored
# --no-ok           :               : ignored
# --default-item    : < n >         : set the default item
# --timeout         : < n >         : specify timeout for selection
# --menu            : < t, n, n,n > : specify menu
# *                 : < t, t >      :
#==============================================================================
function menu_render()
{
    declare local backtitle \
                  cancel_label \
                  default_item \
                  menu_text \
                  height \
                  width \
                  mheight \
                  ok_label \
                  timeout \
                  title

    declare -i local tcnt=0
    declare -a local tag_a
    declare -a local itm_a

    # parse menu definition string
    while [ $# -gt 0 ]; do
        case $1 in
        --no-cancel|--no-ok)
        ;;
        --clear)
            clear
        ;;
        --backtitle)
            backtitle="$2"
            shift 1
        ;;
        --cancel-label)
            cancel_label="$2"
            shift 1
        ;;
        --default-item)
            default_item=$2
            shift 1
        ;;
        --menu)
            menu_text="$2"
            height=$3
            width=$4
            mheight=$5
            shift 4
        ;;
        --ok-label)
            ok_label="$2"
            shift 1
        ;;
        --timeout)
            timeout=$2
            shift 1
        ;;
        --title)
            title="$2"
            shift 1
        ;;
        *)
            tag_a[$tcnt]=$1
            itm_a[$tcnt]="$2"
            let tcnt++
            shift 1
        ;;
        esac
        shift 1
    done

    # if width=0 assume and set to 80
    [ $width -eq 0 ] && width=80

    # determine char possitions in menu keynum index
    # assumes max number of menu items to be less than 999
    declare -i local    keypos=1
    [ $tcnt -gt  9 ] && keypos=2
    [ $tcnt -gt 99 ] && keypos=3

    declare -i local idx=0  # counting index
    declare -i local mtw=0  # max tag width
    declare -i local miw=0  # max item width
    declare -i local mco=0  # menu centering offset

    # offsets for menu-centering and tag-printing
    if [[ -n "$menu_render_show_tags" || -n "$menu_render_center" ]] ; then
        # determine: (1) max menu tag and (2) menu item width
        for (( idx=0; idx < tcnt; idx++ )) ; do
            declare local tw=${#tag_a[$idx]}
            declare local iw=${#itm_a[$idx]}
            [ $tw -gt $mtw ] && mtw=$tw
            [ $iw -gt $miw ] && miw=$iw
        done

        # determine menu offset for menu centering
        let mco=(width-keypos-miw-7)
        [ -n "$menu_render_show_tags" ] && let mco=mco-mtw-3
        let mco=mco/2
    fi

    # output back title if defined
    if [ -n "$backtitle" ]; then
        # this is a workabout to remain compatible with cdialog
        # passing multiple feilds joined together as backtitle
        # check for first ':' seperating feilds
        declare local ct st

        if [[ $backtitle == *:* ]] ; then
            ct=${backtitle%:*}
            st=${backtitle#*:}
        else
            ct=${backtitle}
        fi

        print_textbox -tw "$width" -bw "$width" \
                      -lt "$st" -ct "$ct" -bt -pl -bb
        print_m -j
    fi

    # output menu title if defined
    if [ -n "$title" ]; then
        print_textbox -tw "$width" -bw "$width" \
                      -bc 0 -fc "-" -lt ":" -rt ":" \
                      -ct " $title " -pl
        print_m -j
    fi

    declare -a local keymap
    declare -i local keynum=1

    # output each menu tag and item lines
    for (( idx=0; idx < tcnt; idx++ )) ; do
        declare local tag=${tag_a[$idx]}
        declare local itm=${itm_a[$idx]}

        # center offset
        [ -n "$menu_render_center" ] && print_m -j -n -r $mco ' '

        declare local fmt_keynum
        printf -v fmt_keynum "%0${keypos}d" $keynum

        # tag-id number
        if [ x"$tag" == x"$default_item" ] ; then
            declare local tbld trst
            terminal_set_color -v tbld --attribute reverse
            terminal_set_color -v trst --attribute reset

            print_m -j -n -e "[$tbld $fmt_keynum $trst] :"
        else
            print_m -j -n "  $fmt_keynum  " :
        fi

        # tag-id text
        if [ -n "$menu_render_show_tags" ] ; then
            declare -i local tagw=${#tag}
            declare -i local spad
            let spad=mtw-tagw+1

            print_m -j -n -r $spad " "  # align each tag
            print_m -j -n "$tag" :      # output tag
        fi

        # menu line item text
        print_m -j " $itm"

        keymap[ $keynum ]="$tag"
        let keynum++
    done

    # line after last menu line item
    print_m -j
    print_textbox -tw "$width" -bw "$width" -bc 0 \
                  -fc "-" -lt ":" -rt ":" -ct " + " -pl

    # draw ok button (if default exists and cancel labels is defined)
    if [[ -n "$ok_label" && -n "$default_item" ]] || [ -n "$cancel_label" ]
    then
        declare local label

        [[ -n "$ok_label" && -n "$default_item" ]] \
            && label+=" <enter>:[$ok_label] "

        [ -n "$cancel_label" ] \
            && label+=" <x>:[$cancel_label] "

        print_textbox -tw "$width" -bw "$width" -bc 0 \
                      -ct "$label" -pl
    fi

    # a magic number that could be exported for user configuration
    declare local menu_prompt_margin=5

    # menu prompt text
    if [ -n "$menu_text" ] ; then
        print_m -j
        print_textbox -tw "$width" -bw "$(($width - $menu_prompt_margin * 2))" \
                      -bc 0 -ljml "$menu_text"
    fi

    print_m -j -n -r "$menu_prompt_margin" ' ' "digit choice: "

    declare local choice
    if [ -z "$timeout" ] ; then
        terminal_flush_stdin
        read -n $keypos choice
    else
        terminal_flush_stdin
        read -n $keypos -t $timeout choice
    fi

    # strip all leading zeros from choice string
    declare -i local choice_chrs=${#choice}
    for (( idx=0; idx < $choice_chrs; idx++ )) ; do
        [[ ${choice:$idx:1} != "0" ]] && break
    done
    choice=${choice:$idx:$choice_chrs}

    [[ -z "$choice"       && $choice_chrs -eq 0 ]] && return 255
    [[ -n "$cancel_label" && "$choice" == "x"   ]] && return 1

    # return result via tmp file using standard error stream
    echo ${keymap[ $choice ]} 1>&2

    return 0
}


#==============================================================================
# select from menu
#
# Params:
# -m : menu-id
# -s : environment scope
# -v : variable name for selection
#==============================================================================
function menu_get_selection()
{
    declare local menu=${menu_default_id:-menu_0}
    declare local scope
    declare local __rv_name

    while [ $# -gt 0 ] ; do
        case $1 in
        -m) menu=$2         ; shift 1   ;;
        -s) scope=$2        ; shift 1   ;;
        -v) __rv_name=$2    ; shift 1   ;;
         *) abort_invalid_arg $1        ;;
        esac
        shift 1
    done

    abort_if_not_defined "$menu" "-m:menu-id"

    declare local title
    declare local title_tree
    declare local prompt
    declare local default
    declare local default_text
    declare local timeout

    declare local height
    declare local width
    declare local mheight

    declare local ok_label
    declare local cancel_label

    # retreive menu definition
    menu_get_layout -m $menu -pv title
    menu_get_layout -m $menu -pv title_tree
    menu_get_layout -m $menu -pv prompt
    menu_get_layout -m $menu -pv default
    menu_get_layout -m $menu -pv default_text
    menu_get_layout -m $menu -pv timeout

    menu_get_layout -m $menu -pv height
    menu_get_layout -m $menu -pv width
    menu_get_layout -m $menu -pv mheight

    menu_get_layout -m $menu -pv ok_label
    menu_get_layout -m $menu -pv cancel_label

    # if menu sizes are not specified, set to zero for auto-size
    [ -z "$height"  ] &&  height=0
    [ -z "$width"   ] &&   width=0
    [ -z "$mheight" ] && mheight=0

    # set default text if not specified
    [ -z "$default_text" ] && default_text="[highlighted]"

    # setup the "back-title". if menu defines title tree, append
    declare local backtitle="[${script_base_name}-${script_version}]"
    [ -n "$title_tree" ] && backtitle+=": $title_tree"

    # lookup menu command
    declare local menu_cmd
    ext_cmd_get -n 'menu' -v_p 'menu_cmd' ${scope+-s $scope}

    # assemble menu
    declare local menu_string="$menu_cmd"

    menu_string+=" --clear --backtitle \"$backtitle\" --title \"$title\""

    [ -n "$default"      ] && menu_string+=" --default-item \"$default\""
    [ -z "$ok_label"     ] && menu_string+=" --ok-label \"OK\""
    [ -n "$ok_label"     ] && menu_string+=" --ok-label \"$ok_label\""
    [ -z "$cancel_label" ] && menu_string+=" --no-cancel"
    [ -n "$cancel_label" ] && menu_string+=" --cancel-label \"$cancel_label\""

    if [[ "$timeout" -gt 0 ]] ; then
        if [ -z "$default" ] ; then
            menu_string+=" --timeout $timeout
                --menu \"$prompt Selection timeout after
                  $timeout idle seconds.\""
        else
            menu_string+=" --timeout $timeout
                --menu \"$prompt Default=${default_text}
                  after $timeout seconds.\""
        fi
    else
        if [ -z "$default" ] ; then
            menu_string+=" --menu \"$prompt\""
        else
            menu_string+=" --menu \"$prompt Default=${default_text}.\""
        fi
    fi

    menu_string+=" $height $width $mheight"

    # menu entry ('tag-id' and 'line items')
    declare local menu_tags
    menu_get_entry_list -m $menu -v 'menu_tags'
    for tag in $menu_tags ; do
        declare local item
        menu_get_entry -m $menu -i $tag -v 'item'
        menu_string+=" $tag \"$item\""
    done

    # pass menu to menu command (using tmp file to pass result)
    declare local temp_file="${script_tmp_root}-1"
    declare local menu_ret_val
    declare local __rv_value

    print_debug_vl 5 "$menu_string $temp_file"
    eval $menu_string 2> $temp_file

    menu_ret_val=$?
    __rv_value=$(cat $temp_file)

    # lookup rm -f command
    declare local rm_f rm_fo
    ext_cmd_get -nv_p 'rm_f' -v_o 'rm_fo' ${scope+-s $scope}

    # remove temp file
    eval "$rm_f $rm_fo $temp_file"

    case $menu_ret_val in
    1)
        print_m -j " ($cancel_label selected)"
        __rv_value="cancel"
    ;;
    255)
        print_m -j -n " (default selected)"
        __rv_value="${default}"
    ;;
    esac

    declare local exit_val
    # 'cancel' does not map to a menu entry tag, so skip validity check
    if [ x"$__rv_value" == x"cancel" ] ; then
        exit_val=0      # return: selection valid
    else
        # check validity of '__rv_value'
        if hash_is_set ${menu} ${__rv_value} ; then
            print_m -j " (menu tag id[$__rv_value])"
            exit_val=0  # return: selection valid
        else
            print_m -j " (invalid menu tag id)"
            exit_val=1  # return: selection invalid
        fi
    fi

    [ -n "$__rv_name" ] && eval "$__rv_name=\"${__rv_value}\""

    return $exit_val
}


#==============================================================================
# start a menu handler
#
# Params:
# -m  : menu name
# -p  : parent menu name
# -s  : environment scope
# -dc : default terminal columns (default=80)
# -dl : default terminal lines (default=24)
#==============================================================================
function menu_start_handler()
{
    declare local menu=${menu_default_id:-menu_0}
    declare local pmenu
    declare local dt_cols=80
    declare local dt_lines=24

    while [ $# -gt 0 ] ; do
        case $1 in
        -m) menu=$2         ; shift 1   ;;
        -p) pmenu=$2        ; shift 1   ;;
        -dc) dt_cols=$2     ; shift 1   ;;
        -dl) dt_lines=$2    ; shift 1   ;;
         *) abort_invalid_arg $1        ;;
        esac
        shift 1
    done

    print_m_vl 3 "menu handler enter [$menu]"

    # verify that menu exists
    declare local menu_tags
    menu_get_entry_list -m $menu -v 'menu_tags'
    [ -z "$menu_tags" ] && abort_error "menu [$menu] has no entries."

    declare local orig_title_tree
    # if parent menu specified, then pre-pend to menu title_tree
    if [ -n "$pmenu" ] ; then
        declare local prnt_title_tree

        menu_get_layout -m $pmenu -p 'title_tree' -v 'prnt_title_tree'
        menu_get_layout -m $menu  -p 'title_tree' -v 'orig_title_tree'

        menu_set_layout -m $menu -p 'title_tree' \
                        -v "$prnt_title_tree/$orig_title_tree"
    fi

    # continuous repeat loop
    # use 'break' in menu eval code to exit menu-handler loop
    while [ 1 ]
    do
        declare -i local menu_columns
        declare -i local menu_lines

        if terminal_get_size ${scope+-s $scope} -dc $dt_cols -dl $dt_lines \
                            -v_c 'menu_columns' -v_l 'menu_lines'
        then
            menu_set_layout -m $menu -p 'width'  -v "$menu_columns"
            menu_set_layout -m $menu -p 'height' -v "$menu_lines"
        fi

        print_m_vl 1 "loading menu [$menu]"

        declare local menu_ret_tag
        if menu_get_selection -m $menu -v 'menu_ret_tag' ${scope+-s $scope}
        then
            declare local eval_code
            if menu_get_eval -m $menu -i "$menu_ret_tag" -v 'eval_code' ; then
                # run code assigned to the selected menu item
                eval "$eval_code"

                # here we could catch any returned errors
            else
                print_textbox -pn -hvc "#" \
                    -ct "no code assigned to menu tag [$menu]:[$menu_ret_tag]" \
                    -bt -pl -bb
                sleep 1
            fi
        fi
    done

    # if parent menu specified, restore original title_tree value
    [ -n "$pmenu" ] && \
        menu_set_layout -m $menu -p 'title_tree' -v "$orig_title_tree"

    print_m_vl 3 "menu handler exit [$menu]"

    return
}


#==============================================================================
# eof
#==============================================================================

