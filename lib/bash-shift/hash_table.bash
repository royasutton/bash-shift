###############################################################################
#==============================================================================
#
# hash table functions (inspired by: http://tldp.org/LDP/abs/html)
#
#------------------------------------------------------------------------------
#
# hash_var_prefix (default=__hash__)
#
#==============================================================================
###############################################################################

include "print.bash"
include "print_textbox.bash"

#==============================================================================
# Emulates: hash[key]=value
#
# Params:
# 1 - hash
# 2 - key
# 3 - value
#==============================================================================
function hash_set()
{
    eval "${hash_var_prefix:-__hash__}${1}_${2}=\"${3}\""

    return
}


#==============================================================================
# Emulates: value=hash[key]
#
# Params:
# 1 - hash
# 2 - key
# 3 - value (name of global variable to set)
#==============================================================================
function hash_get_into()
{
    eval "$3=\"\$${hash_var_prefix:-__hash__}${1}_${2}\""

    return
}


#==============================================================================
# Emulates: echo hash[key]
#
# Params:
# 1 - hash
# 2 - key
# 3 - echo params (like -n, for example)
#==============================================================================
function hash_echo()
{
    eval "echo $3 \"\$${hash_var_prefix:-__hash__}${1}_${2}\""

    return
}


#==============================================================================
# Emulates: unset hash[key]
#
# Params:
# 1 - hash
# 2 - key
#==============================================================================
function hash_unset()
{
    eval "unset ${hash_var_prefix:-__hash__}${1}_${2}"

    return
}


#==============================================================================
# Emulates: isset(hash[key]) or hash[key]==NULL
#
# Params:
# 1 - hash
# 2 - key
# Returns:
# 0 - there is such key
# 1 - there is no such key
#==============================================================================
function hash_is_set()
{
    eval "if [[ \"\${${hash_var_prefix:-__hash__}${1}_${2}-a}\" = \"a\" &&
        \"\${${hash_var_prefix:-__hash__}${1}_${2}-b}\" = \"b\" ]]
        then return 1; else return 0; fi"
}


#==============================================================================
# Emulates:
#   foreach($hash as $key => $value) { fun($key,$value, $*:arguments); }
#
# Params:
# 1  - hash
# 2  - function name
# $* - additional arguments are passed to function after key and "value"
#==============================================================================
function hash_foreach()
{
    declare local hash=$1
    declare local func=$2
    shift 2

    declare local keyname oldIFS="$IFS"
    IFS=' '
    for i in $(eval "echo \${!${hash_var_prefix:-__hash__}${hash}_*}"); do
        keyname=$(eval "echo \${i##${hash_var_prefix:-__hash__}${hash}_}")
        eval "$func $keyname \"\$$i\" $*"
    done
    IFS="$oldIFS"

    return
}


#==============================================================================
# number of elements in hash table
#
# Params:
# 1 - hash table name
# 2 - value (name of global variable to set)
#==============================================================================
function hash_size_into()
{
    declare local hash=$1

    declare -i local __rv_value=0

    function foreach_function() { let __rv_value++; }

    hash_foreach $hash foreach_function

    [ -n "$2" ] && eval "$2=${__rv_value}"

    return
}


#==============================================================================
# copy all elements of source hash table to destination hash table
#
# Params:
# 1 - source hash table name
# 2 - destination hash table name
#==============================================================================
function hash_copy()
{
    declare local src_hash=$1
    declare local dst_hash=$2

    function foreach_function()
    {
        declare local key=$1
        declare local value="$2"
        declare local hash=$3

        print_m_vl 6 "copying to [$hash]:key=[$key] value=[$value]"
        hash_set $hash $key "$value"
    }

    hash_foreach $src_hash foreach_function $dst_hash

    return
}


#==============================================================================
# unset all elements in hash table
#
# Params:
# 1 - hash table name
#==============================================================================
function hash_unset_all()
{
    declare local hash=$1

    function foreach_function()
    {
        declare local key=$1
        declare local value="$2"
        declare local hash=$3

        print_m_vl 6 -J "hash_unset [$hash]:key=[$key]"
        hash_unset $hash $key
    }

    hash_foreach $hash foreach_function $hash

    return
}


#==============================================================================
# dump hash table
#
# Params:
# 1 - hash table name
# 2 - table title
#==============================================================================
function hash_dump()
{
    declare local hash=$1
    declare local title=${2-hash table [$hash]}

    function foreach_function()
    {
        declare local key=$1
        declare local value="$2"

        let size++

        declare local num
        printf -v num "% 3d" $size

        print_textbox -lt "$num: $key = \"$value\"" -pl
    }

    declare -i local size=0

    print_textbox -bc 2 -lt "begin" -ct "$title" -rt "begin" \
                  -bt -pl -hr

    hash_foreach $hash foreach_function

    print_textbox -bc 2 -lt "end" -ct "$size entries" -rt "end" \
                  -cc '~' -hc '~' -hr -bc 1 \
                  -cc '+' -hc '=' -pl -bb


    return
}


#==============================================================================
# eof
#==============================================================================

