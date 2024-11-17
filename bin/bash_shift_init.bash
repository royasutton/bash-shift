###############################################################################
#==============================================================================
#
# common directory and file name initialization.
#
#==============================================================================
###############################################################################

#
# install prefix and configuration path mode {0: absolute, 1:relative}
#
declare script_home_prefix=${HOME}/local
declare script_path_mode=1

#
# verify minimum bash version
#
if [ $BASH_VERSINFO -lt 4 ] ; then
    echo "bash version is $BASH_VERSION. version 4 or greater required."
    exit 1
fi

#
# script name and location
#
declare script_base_path="${0%/*}"
declare script_base_name="${0##*/}"
declare script_root_name="${script_base_name%.*}"

#
# library and configuration directories
#
declare script_lib_dir
declare script_conf_dir

if [ "${script_path_mode}" == "0" ] ; then
  # absolute directory path
  script_lib_dir="${script_home_prefix}/lib"

  if [ -d "${script_home_prefix}/etc/${script_root_name}" ] ; then
    script_conf_dir="${script_home_prefix}/etc/${script_root_name}"
  else
    script_conf_dir="${script_home_prefix}/etc"
  fi
else
  # directory path relative to script path
  script_lib_dir="$(cd ${script_base_path}/../lib; pwd)"

  if [ -d "${script_base_path}/../etc/${script_root_name}" ] ; then
    script_conf_dir="$(cd ${script_base_path}/../etc/${script_root_name}; pwd)"
  else
    script_conf_dir="$(cd ${script_base_path}/../etc; pwd)"
  fi
fi

#
# default configuration filename
#
declare script_conf_file="${script_conf_dir}/${script_root_name}.conf"

#
# default temporary-file root name
#
declare script_tmp_root="/tmp/${script_root_name}-$$"

#
# load shell script loader
#
source "${script_lib_dir}/shell-script-loader/v0.2.2/loader.bash-4"

if [ "$LOADER_ACTIVE" != true ]; then
    echo "unable to load the shell script loader, aborting..."; exit 1
fi


###############################################################################
# eof
###############################################################################
