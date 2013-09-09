#!/bin/bash

thisdir=$(dirname "${BASH_SOURCE[0]}")
BUILDPACK_DIR=$(cd -P -- "$thisdir/.." && pwd -P)

source "$BUILDPACK_DIR/lib/vars.sh"


#
#  Initialize StrongLoop environment variables.
#
#  Examples:
#    init_strongloop_env
#
function init_strongloop_env() {
  #  Exported StrongLoop env variables - default variable values.
  export STRONGLOOP_OS="Unknown"
  export STRONGLOOP_PLATFORM='Local'
  export STRONGLOOP_HOST="127.0.0.1"
  export STRONGLOOP_PORT="3000"
  export STRONGLOOP_INSTALL_BINDIR=""

  if $(which node > /dev/null 2>&1); then
    export STRONGLOOP_INSTALL_BINDIR=$(dirname $(which node))
  fi

}  #  End of function  init_strongloop_env.


#
#  Prints the specified message - formatted.
#
#  Examples:
#    print_message "Initializing ..."
#
function print_message() {
  echo "$@" | sed "s/^/\t/"

}  #  End of function  print_message.


#
#  Checks if the linux distro is Ubuntu.
#
#  Examples:
#    ubuntu_check
#
function ubuntu_check() {
  local etc_issue="/etc/issue"
  local ubuntu_rel="/usr/bin/lsb_release"
  [ -f "$etc_issue" ] && desc=$(cat "$etc_issue" | sed 's/\\[a-z]//g')
  [ -z "$desc" ] && [ -f "$ubuntu_rel" ] && \
    desc=$($ubuntu_rel -d 2> /dev/null | sed 's/Description\:\s*//g')

  if [[ "$desc" =~ Ubuntu.* ]]; then
    export STRONGLOOP_PLATFORM="Ubuntu"
    return 0
  fi

  return 1

}  #  End of function  ubuntu_check.


#
#  Checks if the linux distro is RHEL.
#
#  Examples:
#    rhel_check
#
function rhel_check() {
  local rhel_release="/etc/redhat-release"
  [ -f "$rhel_release" ] || return 1

  local rhelre='s/\(Red\s*Hat\)[^0-9\.]*\([0-9\.]*\).*/RHEL \2/g'
  local rhelver=$(cat $rhel_release | sed "$rhelre")
  if [[ "$rhelver" =~ RHEL.* ]]; then
    export STRONGLOOP_PLATFORM="RHEL"
    return 0
  fi

  return 1

}  #  End of function  rhel_check.


#
#  Determine linux distro.
#
#  Examples:
#    determine_linux_distro
#
function determine_linux_distro() {
  #  Check if we have uname.
  $(which uname > /dev/null 2>&1) || return 1

  export STRONGLOOP_OS=$(uname -s)
  if [[ "$STRONGLOOP_OS" =~ Linux.* ]]; then
    ubuntu_check || rhel_check || return 1
    return 0
  fi

  return 1

}  #  End of function  determine_linux_distro.


#
#  Check if running on VMWare's CloudFoundry.
#
#  Examples:
#    cloudfoundry_paas_check
#
function cloudfoundry_paas_check() {
  [[ -n "$VCAP_APP_HOST"  &&  -n "$VCAP_APP_PORT" ]] ||  \
    [ "$USER" = "vcap" ] || return 1;

  export STRONGLOOP_PLATFORM="CloudFoundry"
  export STRONGLOOP_HOST=$VCAP_APP_HOST
  export STRONGLOOP_PORT=$VCAP_APP_PORT
  return 0

}  #  End of function  cloudfoundry_paas_check.


#
#  Check if running on Red Hat's OpenShift.
#
#  Examples:
#    openshift_paas_check
#
function openshift_paas_check() {
  [ -n "$OPENSHIFT_INTERNAL_IP" ]   || return 1
  [ -n "$OPENSHIFT_INTERNAL_PORT" ] || return 1;

  export STRONGLOOP_PLATFORM="OpenShift"
  export STRONGLOOP_HOST=$OPENSHIFT_INTERNAL_IP
  export STRONGLOOP_PORT=$OPENSHIFT_INTERNAL_PORT
  return 0

}  #  End of function  openshift_paas_check.


#
#  Check if running on SalesForce's Heroku.
#
#  Examples:
#    heroku_paas_check
#
function heroku_paas_check() {
  #  Bit hacky check that HOME is /app or /app/ since there's nothing in the
  #  env on the build host on Heroku.
  [[ "$HOME" =~ /app ]] || return 1;

  # [[ -z "$PORT"  &&  -z "$BUILDPACK_URL" ]]

  export STRONGLOOP_PLATFORM="Heroku"
  export STRONGLOOP_HOST="0.0.0.0"
  export STRONGLOOP_PORT=$PORT
  return 0

}  #  End of function  heroku_paas_check.


#
#  Print StrongLoop environment variables.
#
#  Examples:
#    print_strongloop_env_vars
#
function print_strongloop_env_vars() {
  local slvars=( STRONGLOOP_OS STRONGLOOP_PLATFORM STRONGLOOP_HOST
                 STRONGLOOP_PORT )

  print_message "  - Environment settings: "
  for v in ${slvars[@]}; do
    print_message "      $v = $(printenv $v)"
  done

  return $?

}  #  End of function  print_strongloop_env_vars.


#
#  Setup application's node deployment env.
#
#  Examples:
#    set_node_deployment_env  ./app
#
function set_node_deployment_env() {
  local app_or_build_dir=$1
  local nenv=$app_or_build_dir/strongloop/NODE_ENV
  if [ -f "$nenv" ]; then
    zenv=$(egrep -v "^\s*#.*" "$nenv" | egrep -v "^\s*$" | tail -1)
  fi

  export NODE_ENV="${zenv:-"$STRONGLOOP_DEFAULT_NODE_ENV"}"
  return $?

}  #  End of function  set_node_deployment_env.


#
#  Auto detect platform we are running on.
#
#  Examples:
#    autodetect_platform
#
function autodetect_platform() {
  init_strongloop_env

  if determine_linux_distro; then
    cloudfoundry_paas_check || openshift_paas_check ||  heroku_paas_check
  fi

  if [ "Local" = "$STRONGLOOP_PLATFORM" ]; then
    print_message "  - Warning: Unsupported PaaS platform - assuming local"
  fi

  print_strongloop_env_vars
  return $?

}  #  End of function  autodetect_platform.


#
#  Returns the StrongLoop Node version to install based on a
#  strongloop/VERSION marker file (if any) in the app.
#  See samples/README.md for details.
#
#  Examples:
#    autodetect_platform
#
function get_strongloop_node_version_to_install() {
  local app_or_build_dir=$1
  local version_file="$app_or_build_dir/strongloop/VERSION"
  if [ -f "$version_file" ]; then
    ver=$(egrep  -v "^\s*#.*" "$version_file" | egrep -v "^\s*$" | tail -1)
  fi

  echo "${ver:-"$STRONGLOOP_DEFAULT_NODE_VERSION"}"
  return $?

}  #  End of function  get_strongloop_node_version_to_install.


#
#  Setup PATH to include strongloop binaries.
#
#  setup_paths_to_strongloop_binaries "1.0.0-0.3.beta" [ ~/strongloop ]
#
function setup_paths_to_strongloop_binaries() {
  print_message "  - Setting version and bin dir env variables ..."
  export STRONGLOOP_VERSION="$1"

  local platform_dir=$BUILDPACK_DIR/platform/$STRONGLOOP_PLATFORM
  [ -f "$platform_dir/vars.sh" ] && source "$platform_dir/vars.sh"

  bindir=$STRONGLOOP_VENDOR_INSTALL_DIR/${STRONGLOOP_INSTALL_BIN_DIR#/}
  [ -n "$2" ] && bindir="$2/$bindir"

  print_message "  - Will use node/npm binaries from $bindir"
  print_message "  - Setting PATH to include $bindir"
  export PATH="$bindir:node_modules/.bin:${PATH}"

  return $?

}  #  End of function  setup_paths_to_strongloop_binaries.


#
#  Install StrongLoop.
#
#  Examples:
#     install_strongloop_node  ~/myapp/ /tmp/cachedir
#
function install_strongloop_node() {
  local build_dir=$1
  local cache_dir=$2

  local ver=$(get_strongloop_node_version_to_install "$@")

  local platform_dir=$BUILDPACK_DIR/platform/$STRONGLOOP_PLATFORM
  [ -f "$platform_dir/vars.sh" ] && source "$platform_dir/vars.sh"

  if [ ! -f "$platform_dir/install.sh" ]; then
    print_message "  - No '$STRONGLOOP_PLATFORM' install script found"
    print_message "  - Skipping install ... assuming manual install"
  else
    local install_dir=$STRONGLOOP_VENDOR_INSTALL_DIR
    local version_marker="$install_dir/version.installed"
    if [ -n "$install_dir" ] && [ -d "$cache_dir/$install_dir" ]; then
      mkdir -p  "$build_dir/$install_dir/"
      print_message "  - Copying from cache $cache_dir/$install_dir ... "
      dest_dir=$(dirname "$build_dir/$install_dir")
      cp -RPp "$cache_dir/$install_dir" "$dest_dir/"

      if [ -d "$cache_dir/.profile.d" ]; then
        mkdir -p "$build_dir/.profile.d/"
        cp "$cache_dir/.profile.d/strongloop.sh" "$build_dir/.profile.d/"
      fi
    fi

    local cached_marker="$cache_dir/$version_marker"
    [ -f "$cached_marker" ] && ver_installed=$(cat "$cached_marker")
    if [ "$ver" != "$ver_installed" ]; then
      if [ ! -x "$platform_dir/install.sh" ]; then
        chmod 0755 "$platform_dir/install.sh"
      fi

      "$platform_dir/install.sh" "$ver" "$@"
      echo "$ver" > "$build_dir/$version_marker"
      echo "$ver" > "$cache_dir/$version_marker"
    fi
  fi

  return 0

}  #  End of function  install_strongloop_node.


#
#  Cache installed packages for an app.
#
#  Examples:
#     cache_installed_packages  ~/myapp/ /tmp/cachedir
#
function cache_installed_packages() {
  local build_dir=$1
  local cache_dir=$2

  [ -z "$cache_dir" ] && return 0

  if [ -n "$build_dir" ] && [ -d "$build_dir/node_modules" ]; then
    rm -rf $cache_dir/node_modules
    cp -rpP $build_dir/node_modules $cache_dir
  fi

}  #  End of function  cache_installed_packages.


#
#  Restore cached packages for an app.
#
#  Examples:
#     restore_cached_packages  ~/myapp/ /tmp/cachedir
#
function restore_cached_packages() {
  local build_dir=$1
  local cache_dir=$2

  [ -z "$cache_dir" ] && return 0

  if [ -d "$build_dir/node_modules" ]; then
    #  App has a node_modules dir, check if there's any packages in it that
    #  got pushed and if so, don't use the cache since it is stale.
    local modcount=$(find $build_dir/node_modules/ -type d | wc -l)
    [ $modcount -gt 1 ] && return 0
  fi

  #  Got here, means we can restore from the cache (if any).
  if [ -d "$cache_dir/node_modules" ]; then
    rm -rf $build_dir/node_modules
    cp -rpP $cache_dir/node_modules $build_dir
  fi

  return 0

}  #  End of function  restore_cached_packages.


#
#  Install App Package Dependencies.
#
#  Examples:
#     install_package_dependencies  ~/myapp /tmp/cachedir  ~/strongloop
#
function install_package_dependencies() {
  local build_dir=$1
  local cache_dir=$2
  local install_dir=$3

  print_message "  - Installing package dependencies ..."
  local version_marker="$STRONGLOOP_VENDOR_INSTALL_DIR/version.installed"
  local ver=$(cat "$build_dir/$version_marker" 2> /dev/null)
  [ -n "$install_dir" ] && ver=$(cat "$install_dir/$version_marker")
  setup_paths_to_strongloop_binaries "$ver" "$install_dir"

  slnode=$STRONGLOOP_VENDOR_INSTALL_DIR/${STRONGLOOP_INSTALL_BIN_DIR#/}/node
  [ -n "$install_dir" ] && slnode="$install_dir/$slnode"
  slnpm=$STRONGLOOP_VENDOR_INSTALL_DIR/${STRONGLOOP_INSTALL_BIN_DIR#/}/npm
  [ -n "$install_dir" ] && slnpm="$install_dir/$slnpm"

  set_node_deployment_env "$build_dir"

  pushd "$build_dir" > /dev/null
  print_message "  - Restoring cached packages ..."
  restore_cached_packages "$@"

  #  TODO: Can't run npm install - since path is set to /usr/bin/node and
  #        that's not what Heroku's Slug or CloudFoundry's DEA uses.
  #        So invoke npm via node.
  print_message "  - Installing packages ..."
  HOME="$build_dir" "$slnode" "$slnpm" install 2>&1 | sed "s/^/\t/"
  [ "${PIPESTATUS[0]}" = "0" ] || print_message "npm install failed"

  print_message "  - Caching installed packages ..."
  cache_installed_packages "$@"
  popd > /dev/null

}  #  End of function  install_package_dependencies.


#
#  Get Node.js application script.
#
function get_nodejs_app_script() {
  local PKGJS="console.log(require('./package.json').main);"

  #  Check in order package.json, app.js, server.js
  [ -f "./package.json" ] && zscript=$(node -e "$PKGJS")
  [ -f "$zscript" ] || zscript="app.js"
  [ -f "$zscript" ] || zscript="server.js"

  echo "$zscript"

}  #  End of function  get_nodejs_app_script.


