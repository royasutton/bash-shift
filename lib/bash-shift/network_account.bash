###############################################################################
#==============================================================================
#
# network account functions
#
#==============================================================================
###############################################################################

include "print.bash"
include "exception.bash"
include "external_command.bash"
include "terminal_utility.bash"

#==============================================================================
# check if account matches a pattern in list
#
# Params:
# -a : account to check
# -p : pattern list
# -v : verbose output
#==============================================================================
function net_account_match()
{
    declare local acct
    declare local list
    declare local vl=5

    while [ $# -gt 0 ] ; do
        case $1 in
        -a) acct=$2         ; shift 1  ;;
        -p) list="$2"       ; shift 1  ;;
        -v) vl=0                       ;;
        *)  abort_invalid_arg $1       ;;
        esac
        shift 1
    done

    abort_if_not_defined "$acct" "-a:account"

    declare local u f h d

    if [[ $acct == *@* ]] ; then
        u=${acct%@*}    # username before @
        f=${acct#*@}    # full hostname after @
    else
        u=""            # no @ therefore no username
        f=${acct}       # everything is a the full hostname
    fi

    if [[ $f == *.* ]] ; then
        h=${f%%.*}      # short hostname before the first .
        d=${f#*.}       # domain name after .
    else
        h=${f}          # the short name is the same as the long
        d=""            # no '.' therefore no domain name
    fi

    for ma in $list
    do
        declare local mu mf mh md

        if [[ $ma == *@* ]] ; then
            mu=${ma%@*}
            mf=${ma#*@}
        else
            mu=""
            mf=${ma}
        fi

        if [[ $mf == *.* ]] ; then
            mh=${mf%%.*}
            md=${mf#*.}
        else
            mh=${mf}
            md=""
        fi
                                    
        print_m_vl $vl -J -n "match:" \
            "[${u:-*}=${mu:-*}]&[${h:-*}=${mh:-*}]&[${d:-*}=${md:-*}]"

        # only compare non-zero feilds
        if [[ -z "$u" || -z "$mu" || $u == $mu ]] && \
           [[ -z "$h" || -z "$mh" || $h == $mh ]] && \
           [[ -z "$d" || -z "$md" || $d == $md ]]
        then
            # found match
            print_m_vl $vl -j "? (yes)"
            
            print_m_vl $vl -J "matches [$ma]."

            return 0
        else
            print_m_vl $vl -j "? (no)"
        fi
    done

    print_m_vl $vl -J "no match found."
    
    return 1
}

#==============================================================================
# create list of hosts accounts that can be reached via the network
#
# Params:
# -al  : account list to check
# -sp  : skip pattern
# -du  : default username
# -dd  : default domain
# -v   : name of variable to store list of 'active accounts'
# -s   : command scope for ping command
# -vsp : verbose skip mactch processing
#==============================================================================
function net_account_active()
{
    declare local account_list
    declare local acct_skip_pat
    declare local default_user
    declare local default_domain
    declare local __rv_name1
    declare local scope
    declare local vskip

    while [ $# -gt 0 ] ; do
        case $1 in
        -al) account_list="$2"  ; shift 1   ;;
        -sp) acct_skip_pat="$2" ; shift 1   ;;
        -du) default_user=$2    ; shift 1   ;;
        -dd) default_domain=$2  ; shift 1   ;;
        -v) __rv_name1=$2       ; shift 1   ;;
        -s) scope=$2            ; shift 1   ;;
        -vsp) vskip=true                    ;;
        *)  abort_invalid_arg $1            ;;
        esac
        shift 1
    done

    # setup ansi color control strings
    declare local sf1 sf2 sf3 sfr
    terminal_ansi_ctrl_ca -v sf1 --foreground red
    terminal_ansi_ctrl_ca -v sf2 --foreground green
    terminal_ansi_ctrl_ca -v sf3 --foreground blue
    terminal_ansi_ctrl_ca -v sfr --attribute reset

    # check if default user is specified
    if [ -n "$default_user" ] ; then
        # remove all leading and trailing spaces
        default_user=$(echo $default_user)

        # make sure string contains exactly one word
        declare -a local def_a=( $default_user )
        [ ${#def_a[@]} -ne 1 ] &&  abort_error \
            "invalid default user [$default_user]," "may not contain spaces."
    else
        # set the default user to the current user account
        default_user="$USER"
        print_m_vl 1 "default user not specified," \
                     "using current account [$default_user]"
    fi

    # check if default domain is specified
    if [ -n "$default_domain" ] ; then
        # remove all leading and trailing spaces
        default_domain=$(echo $default_domain)

        # make sure string contains exactly one word
        declare -a local def_a=( $default_domain )
        [ ${#def_a[@]} -ne 1 ] && abort_error \
            "invalid default domain [$default_domain]," "may not contain spaces."
    fi

    # add default user name to any account that does not specify a username
    # if default_domain is set, append to hostnames without domain suffix

    # lookup the ping command
    declare local ping_35 ping_35o
    ext_cmd_get -nv_p 'ping_35' -v_o 'ping_35o' ${scope+-s $scope}

    declare local __rv_value1   # active account list

    # check hosts in account list for reachability
    for acct in $account_list ; do
        print_m_vl 1 -n "checking [$acct]"

        # add default domain if without domain
        [ -n "$default_domain" ] && [[ $acct != *.* ]] && acct+=".${default_domain}"
        
        # add default user if without username
        [[ $acct != *@* ]] && acct="${default_user}@${acct}"

        declare local user=${acct%@*}
        declare local host=${acct#*@}

        print_m_vl 1 -j ", account=[$acct]"

        if net_account_match -a $acct -p "$acct_skip_pat" ${vskip+-v} ; then
            print_m_vl 1 -J -e "account match found in skip patterns," \
                            "${sf3}skipping...${sfr}"
        else
            # check if the host responds to ping
            print_m_vl 1 -J -n "ping $host"
            $ping_35 $ping_35o $host > /dev/null 2>&1
            if [ $? = 0 ]; then
                print_m_vl 1 -j -e ", ${sf2}responded...${sfr}"
                [ -n "$__rv_value1" ] && __rv_value1+=" $acct"
                [ -z "$__rv_value1" ] && __rv_value1+="$acct"
            else
                print_m_vl 1 -j -e ", ${sf1}did not respond...${sfr}"
            fi
        fi
    done

    print_debug_vl 5 available: -s "," $__rv_value1

    [ -n "$__rv_name1" ] && eval "$__rv_name1=\"${__rv_value1}\""

    return
}


#==============================================================================
# eof
#==============================================================================
