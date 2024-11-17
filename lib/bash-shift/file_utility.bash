###############################################################################
#==============================================================================
#
# file utility functions
#
#==============================================================================
###############################################################################

include "print.bash"
include "exception.bash"
include "external_command.bash"

#==============================================================================
# check file owner and / or group
#
# Params:
#  -d: check description
#  -f: file name
#  -u: check if file is owned by this user
#  -g: check if file is in this group
#  -s: external command scope
#  -v: return value variable name
# -ro: report both: user and group flag
# -ru: report user flag
# -rg: report group flag
# -re: report errors
#  -q: quiet flag
#==============================================================================
function file_check_owner()
{
    declare local desc
    declare local file
    declare local check_user
    declare local check_group
    declare local scope
    declare local __rv_name

    declare local report_owner
    declare local report_user
    declare local report_group
    declare local report_error
    declare local report=0

    declare local quiet

    while [ $# -gt 0 ] ; do
        case $1 in
        -d) desc="$2"       ; shift 1  ;;
        -f) file="$2"       ; shift 1  ;;
        -u) check_user=$2   ; shift 1  ;;
        -g) check_group=$2  ; shift 1  ;;
        -s) scope=$2        ; shift 1  ;;
        -v) __rv_name=$2    ; shift 1  ;;

       -ro) report_owner=1  ; report=1 ;;
       -ru) report_user=1   ; report=1 ;;
       -rg) report_group=1  ; report=1 ;;
       -re) report_error=1             ;;

        -q) quiet=1                    ;;
        *)  abort_invalid_arg $1       ;;
        esac
        shift 1
    done

    abort_if_not_defined "$file" "-f:file"

    # get the owner and group using 'ls -ld'. since it is portable
    # across most operating systems. could also use getfacl
    declare local ls_ld ls_ldo
    ext_cmd_get -nv_p 'ls_ld' -v_o 'ls_ldo' ${scope+-s $scope}

    # list file
    declare -a local lsld
    lsld=( $($ls_ld $ls_ldo $file) )

    # feild possitions owner=3 group=4
    declare local file_owner=${lsld[2]}
    declare local file_group=${lsld[3]}

    declare    local rpt_msg \
                     err_msg
    declare -i local err_cnt=0

    # compare owner
    if [ -n "$check_user" ]  && [[ $file_owner != $check_user ]] ; then
        err_msg+=", owned by ${file_owner} (not ${check_user})"
        let err_cnt++
    fi

    # compare group
    if [ -n "$check_group" ]  && [[ $file_group != $check_group ]] ; then
        err_msg+=", group is ${file_group} (not ${check_group})"
        let err_cnt++
    fi

    # report owner, user, group
    [ -n "$report_owner" ] && rpt_msg+=", ${file_owner}:${file_group}"
    [ -n "$report_user"  ] && rpt_msg+=", ${file_owner}"
    [ -n "$report_group" ] && rpt_msg+=", ${file_group}"

    [ -n "$report_error" ] && [ -n "$err_msg" ] && rpt_msg+="$err_msg"

    # if __rv_name specified, write report to string
    if [ -n "$__rv_name" ] ; then
        declare local __rv_value

        # skip the ', ' at the begining of the message
        [ -n "$rpt_msg" ] && __rv_value=${rpt_msg:2}
        eval "$__rv_name=\"${__rv_value}\""
    fi

    [ -z "$quiet" ] && [[ $err_cnt -ne 0 || $report -ne 0 ]] && \
        print_m $desc [$file]$rpt_msg

    return $err_cnt
}


#==============================================================================
# check file mode: access permissions
#
# Params:
#  -d: check description
#  -f: file name
#  -p: 10 character permission flags string
#      (d)(rwx)(:::)(:::) = 'check that permission is true'
#      (-)(---)(:::)(:::) = 'check that permission is false'
#      (:)(:::)(:::)(:::) = 'permission check skipped'
#  -s: external command scope
#  -v: return value variable name
# -rp: report current file permissions
# -re: report errors in permissions check
# -rc: report how to correct reported errors
#  -q: quiet flag
#==============================================================================
function file_check_mode()
{
    declare local desc
    declare local file
    declare local perm
    declare local scope
    declare local __rv_name

    declare local report_perms
    declare local report_error
    declare local report_fix

    declare local quiet

    while [ $# -gt 0 ] ; do
        case $1 in
        -d) desc="$2"       ; shift 1  ;;
        -f) file="$2"       ; shift 1  ;;
        -p) perm=${2,,}     ; shift 1  ;; # convert to lower case
        -s) scope=$2        ; shift 1  ;;
        -v) __rv_name=$2    ; shift 1  ;;

        -rp) report_perms=1            ;;
        -re) report_error=1            ;;
        -rc) report_fix=1              ;;

        -q) quiet=1                    ;;
        *)  abort_invalid_arg $1       ;;
        esac
        shift 1
    done

    abort_if_not_defined "$file" "-f:file"

    # get the status of the permission for the file using 'ls -ld'.  since it
    # is portable across most operating systems. could also use getfacl
    declare local ls_ld ls_ldo
    ext_cmd_get -nv_p 'ls_ld' -v_o 'ls_ldo' ${scope+-s $scope}

    # list file
    declare -a local lsld
    lsld=( $($ls_ld $ls_ldo $file) )

    # the first word will the the file mode status.
    declare local stat=${lsld[0]}

    # cygwin appends an 11th character '+' to identify the
    # existance of extended attributes. check for this case.
    [[ ${#stat} -eq 11 ]] && [[ ${stat:10:1} == '+' ]] && \
        stat=${stat:0:10}

    # verify that $stat has exactly 10 characters
    [[ ${#stat} -ne 10 ]] && \
        abort_error "error obtaining 10 character file permission status" \
                    "for file [$file] stat=[$stat]"

    # verify that the perm also has exactly 10 or 0 characters
    [[ ${#perm} -ne 10 && ${#perm} -ne 0 ]] && \
        abort_error "invalid 10 character file permission mode check" \
                    "for file [$file] check perm=[$perm]"

    declare local err_msg \
                  err_msg_s \
                  last_mclass_s
    declare -i local err_cnt=0

    # compare stat and perm character by character
    declare -i local idx
    declare -i local cnt=${#perm}

    for (( idx=0; idx < cnt; idx++ )) ; do
        declare local sch=${stat:$idx:1}
        declare local pch=${perm:$idx:1}

        # skip permissions that are not to be checked ':',
        # and those that are of unknown status '~'
        [ $pch == ':' ] || [ $sch == '~' ] && continue

        # compare permission check with actual file status
        if [ $pch != $sch ] ; then
            # the expected is different from the actual
            declare local affirm="is" affirm_s="-"
            [ $sch == '-' ] && affirm="not" ; [ $sch == '-' ] && affirm_s="+"

            declare local mclass mclass_s
            ((idx >= 1)) && mclass="owner" ; ((idx >= 1)) && mclass_s="u"
            ((idx >= 4)) && mclass="group" ; ((idx >= 4)) && mclass_s="g"
            ((idx >= 7)) && mclass="other" ; ((idx >= 7)) && mclass_s="o"

            declare local mname mname_s
            case $((idx % 3)) in
            0)  if (( $idx==0 )) ; then
                    mname="directory";  mname_s="d"
                else
                    mname="executable"; mname_s="x"
                fi                                  ;;
            1)      mname="readable";   mname_s="r" ;;
            2)      mname="writeable";  mname_s="w" ;;
            esac

            # validate the permission check character
            [ $pch != '-' ] && [ $pch != $mname_s ] && \
                abort_error "checking file [$file] for permissions [$perm];" \
							"invalid character [$pch] at possition [$(($idx+1))];" \
							"valid check for this possition is one of [${mname_s}|-|:]."

            # append error to 'long' err_msg
            err_msg+=", $affirm $mclass $mname"

            # append error to 'short' err_msg (correction how-to)
            if [ "${mname_s}" != "d" ] ; then
                if [ "${mclass_s}" == "${last_mclass_s}" ] ; then
                    err_msg_s+="${affirm_s}${mname_s}"
                else
                    # new class, ouput class short code
                    if [ -z "${err_msg_s}" ] ; then
                        err_msg_s+="${mclass_s}${affirm_s}${mname_s}"
                    else
                        err_msg_s+=",${mclass_s}${affirm_s}${mname_s}"
                    fi
                fi
                last_mclass_s=$mclass_s
            fi

            # increment error count
            let err_cnt++
        fi
    done

    declare local rpt_msg
    [ -n "$report_perms" ] && rpt_msg+=", ${stat}"
    [ -n "$report_error" ] && [ -n "$err_msg"   ] && \
        rpt_msg+="$err_msg" # already has leading comma
    [ -n "$report_fix"   ] && [ -n "$err_msg_s" ] && \
        rpt_msg+=", fix by [chmod $err_msg_s $file]"

    # if __rv_name specified, write report to string
    if [ -n "$__rv_name" ] ; then
        declare local __rv_value

        # skip the ', ' at the begining of the message
        [ -n "$rpt_msg" ] && __rv_value=${rpt_msg:2}
        eval "$__rv_name=\"${__rv_value}\""
    fi

    [ -z "$quiet" ] && [ -n "$rpt_msg" ] && print_m $desc [$file]$rpt_msg

    return $err_cnt
}


#==============================================================================
# check file: exists, type, and access permissions
#
# Params:
# -d: check description message
# -f: file name
# -v: return value variable name
# -p: permission flags string
#     (ehfdxrw) = 'check that permission is true'
#     (EHFDXRW) = 'check that permission is false'
#          (:.) = these characters are ignored and can be used for formating
# -q: quiet flag
#==============================================================================
function file_check()
{
    declare local desc
    declare local file
    declare local perm='e'
    declare local __rv_name
    declare local quiet

    while [ $# -gt 0 ] ; do
        case $1 in
        -d) desc="$2"       ; shift 1  ;;
        -f) file="$2"       ; shift 1  ;;
        -v) __rv_name=$2    ; shift 1  ;;
        -p) perm=$2         ; shift 1  ;;
        -q) quiet=1                    ;;
        *)  abort_invalid_arg $1       ;;
        esac
        shift 1
    done

    abort_if_not_defined "$file" "-f:file"
    abort_if_not_defined "$perm" "-p:perm"

    declare    local err_msg
    declare -i local err_cnt=0
    declare -i local last_ems=0

    declare -i local idx
    declare -i local cnt=${#perm}

    for (( idx=0; idx < cnt; idx++ )) ; do
        declare local cch=${perm:$idx:1}

        case $cch in
        e) [[   -e "$file" ]] || err_msg+=", does not exists"           ;;
        E) [[ ! -e "$file" ]] || err_msg+=", exists"                    ;;
        h) [[   -h "$file" ]] || err_msg+=", is not a synbolic link"    ;;
        H) [[ ! -h "$file" ]] || err_msg+=", is a synbolic link"        ;;
        f) [[   -f "$file" ]] || err_msg+=", is not a regular file"     ;;
        F) [[ ! -f "$file" ]] || err_msg+=", is a regular file"         ;;
        d) [[   -d "$file" ]] || err_msg+=", is not a directory"        ;;
        D) [[ ! -d "$file" ]] || err_msg+=", is a directory"            ;;
        x) [[   -x "$file" ]] || err_msg+=", is not executable"         ;;
        X) [[ ! -x "$file" ]] || err_msg+=", is executable"             ;;
        r) [[   -r "$file" ]] || err_msg+=", is not readable"           ;;
        R) [[ ! -r "$file" ]] || err_msg+=", is readable"               ;;
        w) [[   -w "$file" ]] || err_msg+=", is not writeable"          ;;
        W) [[ ! -w "$file" ]] || err_msg+=", is writeable"              ;;
  ':'|',')                                                              ;;
        *) abort_error "invalid check [$cch] for${desc+ $desc} [$file]" ;;
        esac

        # check to see if the 'err_msg' string size has changed.
        # if so, record the new error and update string size.
        if [ ${#err_msg} -ne $last_ems ] ; then
            last_ems=${#err_msg}
            let err_cnt++
        fi
    done

    # if __rv_name specified, write report to string
    if [ -n "$__rv_name" ] ; then
        declare local __rv_value

        # skip the ', ' at the begining of the error message
        [ -n "$err_msg" ] && __rv_value=${err_msg:2}
        eval "$__rv_name=\"${__rv_value}\""
    fi

    [ -z "$quiet" ] && [ $err_cnt -ne 0 ] && print_m $desc [$file]$err_msg

    return $err_cnt
}


#==============================================================================
# assign first file from list of files that satisfy permissions checks
#
# Params:
# -d: check description message
# -l: file list
# -p: file permissions list
# -v: variable name for result
# -q: quiet flag
#==============================================================================
function file_check_assign()
{
    declare local desc
    declare local file_list
    declare local file_perm
    declare local __rv_name
    declare local quiet

    while [ $# -gt 0 ] ; do
        case $1 in
        -d) desc="$2"       ; shift 1  ;;
        -l) file_list="$2"  ; shift 1  ;;
        -p) file_perm=$2    ; shift 1  ;;
        -v) __rv_name=$2    ; shift 1  ;;
        -q) quiet=1                    ;;
        *)  abort_invalid_arg $1       ;;
        esac
        shift 1
    done

    abort_if_not_defined "$file_list" "-l:file-list"

    for file in $file_list ; do
        print_debug_vl 5 "checking [$file]"

        if file_check -f "$file" ${file_perm+-p $file_perm} \
                                 ${desc+-d "$desc"} ${quiet+-q}
        then
            print_debug_vl 5 "using [$file] of [$file_list]"

            [ -n "$__rv_name" ] && eval "$__rv_name=\"$file\""

            return 0
        fi
    done

    print_debug_vl 5 "none of [$file_list] satisfy perm=[$file_perm]"

    return 1
}


#==============================================================================
# backup files
#
# Params:
# -f: file to backup
# -p: path for backup files (if differs from '-f:file')
# -s: external command scope
# -x: backup suffix (default=~)
# -c: number of backups to retain (default=1, 0=no backups)
# -r: remove file after backup
# -q: do not report actions
#==============================================================================
function file_backup()
{
    declare local file
    declare local path
    declare local scope
    declare local suffix="~"
    declare local num=1
    declare local remove
    declare local quiet

    while [ $# -gt 0 ] ; do
        case $1 in
        -f) file="$2"       ; shift 1  ;;
        -p) path="$2"       ; shift 1  ;;
        -s) scope=$2        ; shift 1  ;;
        -x) suffix=$2       ; shift 1  ;;
        -c) num=$2          ; shift 1  ;;
        -r) remove=1                   ;;
        -q) quiet=1                    ;;
        *)  abort_invalid_arg $1       ;;
        esac
        shift 1
    done

    abort_if_not_defined "$file"   "-f:file"
    abort_if_not_defined "$suffix" "-x:suffix"
    abort_if_not_defined "$num"    "-c:number"

    declare -i local retval

    # verify not a directory, is a regular file that exists and is readable
    file_check -d "file to backup" -f "$file" -p 'eDfr' ${quiet+-q} || return 1

    if [ $num -ne 0 ] ; then
        # num !=0; doing backup

        declare local file_path="${file%/*}"
        declare local file_base="${file##*/}"

        # if there is no '/' in $file, the path and base
        # will be the same and therefore file has no specified path
        [ "${file_path}" == "${file_base}" ] && file_path="."

        if [ -n "$path" ] ; then
            # make sure the specified path exists, or create it
            if ! file_check -d "backup directory" -f "$path" -p 'e' ${quiet+-q}
            then
                # lookup mkdir with parrents and mode 755
                declare local md_pm755 md_pm755o
                ext_cmd_get -n 'md_pm755' \
                            -v_p 'md_pm755' -v_o 'md_pm755o' ${scope+-s $scope}

                declare cmd_str="$md_pm755 $md_pm755o \"$path\""
                [ -z "$quiet" ] && print_m "creating directory [$path]"
                [ -z "$quiet" ] && print_m $cmd_str
                eval $cmd_str
            else
                # make sure that path is a directory and is writable
                file_check -d "backup directory" -f "$path" -p 'dw' ${quiet+-q} || \
                    return 1

                [ -z "$quiet" ] && print_m "backup directory [$path] exists"
            fi
        else
            # path is not set, set to be same as file_path
            path="$file_path"
        fi

        declare    local backup
        declare    local oldest="${path}/${file_base}${suffix}"
        declare -i local cnt=0

        # find next available backup name and oldest existing backup
        while [ -z "$backup" ] && (( $cnt < $num )) ; do
            # do not append cnt to first backup
            declare local check="${path}/${file_base}${suffix}"

            # append cnt to each after first
            [ $cnt -ge 1 ] && check="${path}/${file_base}${suffix}${cnt}"

            # keep track of the oldest file in case it needs to be recycle
            [ "$oldest" -nt "$check" ] && oldest="$check"

            # if name is not in use, choose it
            [ ! -e "$check" ] && backup="$check"
            let cnt++
        done

        # all backup names are in use. reuse the oldest
        if [ -z "$backup" ] ; then
            [ -z "$quiet" ] && \
                print_m "$num backups exists. recycling oldest=[$oldest]..."

            backup="$oldest"
        fi

        #
        # perform the actual backup
        #
        if [ -z "$remove" ] ; then
            # not removing original. copy the file to backup
            declare local cp_a cp_ao
            ext_cmd_get -n 'cp_a'  -v_p 'cp_a' -v_o 'cp_ao' ${scope+-s $scope}

            declare local cmd_str="$cp_a $cp_ao \"$file\" \"$backup\""
            [ -z "$quiet" ] && print_m "copying [$file] to [$backup] as backup"
            [ -z "$quiet" ] && print_m $cmd_str

            eval $cmd_str
            retval=$?
        else
            # removing original. move the file to backup
            declare local mv_f mv_fo
            ext_cmd_get -n 'mv_f' -v_p 'mv_f' -v_o 'mv_fo' ${scope+-s $scope}

            declare local cmd_str="$mv_f $mv_fo \"$file\" \"$backup\""
            [ -z "$quiet" ] && print_m "moving [$file] to [$backup] as backup"
            [ -z "$quiet" ] && print_m $cmd_str

            eval $cmd_str
            retval=$?
        fi
    else
        # num==0; no backup

        # remove file if requested
        if [ -n "$remove" ] ; then
            declare local rm_f rm_fo
            ext_cmd_get -n 'rm_f' -v_p 'rm_f' -v_o 'rm_fo' ${scope+-s $scope}

            declare local cmd_str="$rm_f $rm_fo \"$file\""
            [ -z "$quiet" ] && print_m "removing file [$file] without backup"
            [ -z "$quiet" ] && print_m $cmd_str

            eval $cmd_str
            retval=$?
        fi
    fi

    return $retval
}


#==============================================================================
# eof
#==============================================================================

