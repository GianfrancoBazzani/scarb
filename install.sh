#!/bin/sh
# shellcheck shell=dash
# shellcheck disable=SC2039

# This is just a little script that can be downloaded from the internet to install Scarb.
# It just does platform detection, downloads the release archive, extracts it and tries to make
# the `scarb` binary available in $PATH in least invasive way possible.
#
# It runs on Unix shells like {a,ba,da,k,z}sh. It uses the common `local` extension.
# Note: Most shells limit `local` to 1 var per line, contra bash.
#
# Most of this code is based on/copy-pasted from rustup and protostar installers.

set -u

SCARB_REPO="https://github.com/software-mansion/scarb"
XDG_DATA_HOME="${XDG_DATA_HOME:-"${HOME}/.local/share"}"
INSTALL_ROOT="${XDG_DATA_HOME}/scarb-install"
LOCAL_BIN="${HOME}/.local/bin"
LOCAL_BIN_ESCAPED="\$HOME/.local/bin"

usage() {
  cat <<EOF
The installer for Scarb

Usage: install.sh [OPTIONS]

Options:
  -p, --no-modify-path   Skip PATH variable modification
  -h, --help             Print help
  -v, --version          Specify Scarb version to install

For more information, check out https://docs.swmansion.com/scarb/download.
EOF
}

main() {
  need_cmd chmod
  need_cmd curl
  need_cmd grep
  need_cmd mkdir
  need_cmd mktemp
  need_cmd rm
  need_cmd sed
  need_cmd tar
  need_cmd uname

  # Transform long options to short ones.
  for arg in "$@"; do
    shift
    case "$arg" in
      '--help')           set -- "$@" '-h'   ;;
      '--no-modify-path') set -- "$@" '-p'   ;;
      '--version')        set -- "$@" '-v'   ;;
      *)                  set -- "$@" "$arg" ;;
    esac
  done

  local _requested_ref="latest"
  local _requested_version="latest"
  local _do_modify_path=1
  while getopts ":hpv:" opt; do
    case $opt in
    p)
      _do_modify_path=0
      ;;
    h)
      usage
      exit 0
      ;;
    v)
      _requested_ref="tag/v${OPTARG}"
      _requested_version="$OPTARG"
      ;;
    \?)
      err "invalid option -$OPTARG"
      ;;
    :)
      err "option -$OPTARG requires an argument"
      ;;
    esac
  done

  resolve_version "$_requested_version" "$_requested_ref" || return 1
  local _resolved_version=$RETVAL
  assert_nz "$_resolved_version" "resolved_version"

  get_architecture || return 1
  local _arch="$RETVAL"
  assert_nz "$_arch" "arch"

  local _tempdir
  if ! _tempdir="$(ensure mktemp -d)"; then
    # Because the previous command ran in a subshell, we must manually propagate exit status.
    exit 1
  fi

  ensure mkdir -p "$_tempdir"

  create_install_dir "$_requested_version"
  local _installdir=$RETVAL
  assert_nz "$_installdir" "installdir"

  download "$_resolved_version" "$_arch" "$_installdir" "$_tempdir"

  say "installed scarb to ${_installdir}"

  create_symlink "$_installdir"
  local _retval=$?

  echo
  if echo ":$PATH:" | grep -q ":${LOCAL_BIN}:"; then
    echo "Scarb has been successfully installed and should be already available in your PATH."
    echo "Run 'scarb --version' to verify your installation. Happy coding!"
  else
    if [ $_do_modify_path -eq 1 ]; then
      add_local_bin_to_path
      _retval=$?
    else
      echo "Skipping PATH modification, please manually add '${LOCAL_BIN_ESCAPED}' to your PATH."
    fi

    echo "Then, run 'scarb --version' to verify your installation. Happy coding!"
  fi

  ignore rm -rf "$_tempdir"
  return "$_retval"
}

# This function has been copied verbatim from rustup install script.
check_proc() {
    # Check for /proc by looking for the /proc/self/exe link
    # This is only run on Linux
    if ! test -L /proc/self/exe ; then
        err "fatal: Unable to find /proc/self/exe.  Is /proc mounted?  Installation cannot proceed without /proc."
    fi
}

# This function has been copied verbatim from rustup install script.
get_bitness() {
    need_cmd head
    # Architecture detection without dependencies beyond coreutils.
    # ELF files start out "\x7fELF", and the following byte is
    #   0x01 for 32-bit and
    #   0x02 for 64-bit.
    # The printf builtin on some shells like dash only supports octal
    # escape sequences, so we use those.
    local _current_exe_head
    _current_exe_head=$(head -c 5 /proc/self/exe )
    if [ "$_current_exe_head" = "$(printf '\177ELF\001')" ]; then
        echo 32
    elif [ "$_current_exe_head" = "$(printf '\177ELF\002')" ]; then
        echo 64
    else
        err "unknown platform bitness"
    fi
}

say() {
  printf 'scarb-install: %s\n' "$1"
}

err() {
  say "$1" >&2
  exit 1
}

need_cmd() {
  if ! check_cmd "$1"; then
    err "need '$1' (command not found)"
  fi
}

check_cmd() {
  command -v "$1" >/dev/null 2>&1
}

assert_nz() {
  if [ -z "$1" ]; then err "assert_nz $2"; fi
}

# Run a command that should never fail.
# If the command fails execution will immediately terminate with an error showing the failing command.
ensure() {
  if ! "$@"; then err "command failed: $*"; fi
}

# This is just for indicating that commands' results are being intentionally ignored.
# Usually, because it's being executed as part of error handling.
ignore() {
  "$@"
}

# This function has been copied verbatim from rustup install script.
get_architecture() {
  local _ostype _cputype _bitness _arch _clibtype
  _ostype="$(uname -s)"
  _cputype="$(uname -m)"
  _clibtype="gnu"

  if [ "$_ostype" = Linux ]; then
    if [ "$(uname -o)" = Android ]; then
      _ostype=Android
    fi
    if ldd --_requested_version 2>&1 | grep -q 'musl'; then
      _clibtype="musl"
    fi
  fi

  if [ "$_ostype" = Darwin ] && [ "$_cputype" = i386 ]; then
    # Darwin `uname -m` lies
    if sysctl hw.optional.x86_64 | grep -q ': 1'; then
      _cputype=x86_64
    fi
  fi

  if [ "$_ostype" = SunOS ]; then
    # Both Solaris and illumos presently announce as "SunOS" in "uname -s"
    # so use "uname -o" to disambiguate.  We use the full path to the
    # system uname in case the user has coreutils uname first in PATH,
    # which has historically sometimes printed the wrong value here.
    if [ "$(/usr/bin/uname -o)" = illumos ]; then
      _ostype=illumos
    fi

    # illumos systems have multi-arch userlands, and "uname -m" reports the
    # machine hardware name; e.g., "i86pc" on both 32- and 64-bit x86
    # systems.  Check for the native (widest) instruction set on the
    # running kernel:
    if [ "$_cputype" = i86pc ]; then
      _cputype="$(isainfo -n)"
    fi
  fi

  case "$_ostype" in
  Android)
    _ostype=linux-android
    ;;

  Linux)
    check_proc
    _ostype=unknown-linux-$_clibtype
    _bitness=$(get_bitness)
    ;;

  FreeBSD)
    _ostype=unknown-freebsd
    ;;

  NetBSD)
    _ostype=unknown-netbsd
    ;;

  DragonFly)
    _ostype=unknown-dragonfly
    ;;

  Darwin)
    _ostype=apple-darwin
    ;;

  illumos)
    _ostype=unknown-illumos
    ;;

  MINGW* | MSYS* | CYGWIN* | Windows_NT)
    _ostype=pc-windows-gnu
    ;;

  *)
    err "unrecognized OS type: $_ostype"
    ;;
  esac

  case "$_cputype" in
  i386 | i486 | i686 | i786 | x86)
    _cputype=i686
    ;;

  xscale | arm)
    _cputype=arm
    if [ "$_ostype" = "linux-android" ]; then
      _ostype=linux-androideabi
    fi
    ;;

  armv6l)
    _cputype=arm
    if [ "$_ostype" = "linux-android" ]; then
      _ostype=linux-androideabi
    else
      _ostype="${_ostype}eabihf"
    fi
    ;;

  armv7l | armv8l)
    _cputype=armv7
    if [ "$_ostype" = "linux-android" ]; then
      _ostype=linux-androideabi
    else
      _ostype="${_ostype}eabihf"
    fi
    ;;

  aarch64 | arm64)
    _cputype=aarch64
    ;;

  x86_64 | x86-64 | x64 | amd64)
    _cputype=x86_64
    ;;

  mips)
    _cputype=$(get_endianness mips '' el)
    ;;

  mips64)
    if [ "$_bitness" -eq 64 ]; then
      # only n64 ABI is supported for now
      _ostype="${_ostype}abi64"
      _cputype=$(get_endianness mips64 '' el)
    fi
    ;;

  ppc)
    _cputype=powerpc
    ;;

  ppc64)
    _cputype=powerpc64
    ;;

  ppc64le)
    _cputype=powerpc64le
    ;;

  s390x)
    _cputype=s390x
    ;;
  riscv64)
    _cputype=riscv64gc
    ;;
  loongarch64)
    _cputype=loongarch64
    ;;
  *)
    err "unknown CPU type: $_cputype"
    ;;
  esac

  # Detect 64-bit linux with 32-bit userland
  if [ "${_ostype}" = unknown-linux-gnu ] && [ "${_bitness}" -eq 32 ]; then
    case $_cputype in
    x86_64)
      if [ -n "${RUSTUP_CPUTYPE:-}" ]; then
        _cputype="$RUSTUP_CPUTYPE"
      else {
        # 32-bit executable for amd64 = x32
        if is_host_amd64_elf; then
          err "x86_64 linux with x86 userland unsupported"
        else
          _cputype=i686
        fi
      }; fi
      ;;
    mips64)
      _cputype=$(get_endianness mips '' el)
      ;;
    powerpc64)
      _cputype=powerpc
      ;;
    aarch64)
      _cputype=armv7
      if [ "$_ostype" = "linux-android" ]; then
        _ostype=linux-androideabi
      else
        _ostype="${_ostype}eabihf"
      fi
      ;;
    riscv64gc)
      err "riscv64 with 32-bit userland unsupported"
      ;;
    esac
  fi

  # Detect armv7 but without the CPU features Rust needs in that build,
  # and fall back to arm.
  # See https://github.com/rust-lang/rustup.rs/issues/587.
  if [ "$_ostype" = "unknown-linux-gnueabihf" ] && [ "$_cputype" = armv7 ]; then
    if ensure grep '^Features' /proc/cpuinfo | grep -q -v neon; then
      # At least one processor does not have NEON.
      _cputype=arm
    fi
  fi

  _arch="${_cputype}-${_ostype}"

  RETVAL="$_arch"
}

resolve_version() {
  local _requested_version=$1
  local _requested_ref=$2

  local _response

  say "retrieving $_requested_version version from ${SCARB_REPO}..."
  _response=$(ensure curl -Ls -H 'Accept: application/json' "${SCARB_REPO}/releases/${_requested_ref}")
  if [ "{\"error\":\"Not Found\"}" = "$_response" ]; then
    err "version $_requested_version not found"
  fi

  RETVAL=$(echo "$_response" | sed -e 's/.*"tag_name":"\([^"]*\)".*/\1/')
}

create_install_dir() {
  local _requested_version=$1

  local _installdir="${INSTALL_ROOT}/${_requested_version}"

  if [ -d "$_installdir" ]; then
    ensure rm -rf "$_installdir"
    say "removed existing scarb installation at ${_installdir}"
  fi

  ensure mkdir -p "$_installdir"

  RETVAL=$_installdir
}

download() {
  local _resolved_version=$1
  local _arch=$2
  local _installdir=$3
  local _tempdir=$4

  local _tarball="scarb-${_resolved_version}-${_arch}.tar.gz"
  local _url="${SCARB_REPO}/releases/download/${_resolved_version}/${_tarball}"
  local _dl="$_tempdir/scarb.tar.gz"

  say "downloading ${_tarball}..."

  ensure curl -fLS -o "$_dl" "$_url"
  ensure tar -xz -C "$_installdir" --strip-components=1 -f "$_dl"
}

create_symlink() {
  local _installdir=$1

  local _scarb="${_installdir}/bin/scarb"
  local _symlink="${LOCAL_BIN}/scarb"

  ensure mkdir -p "$LOCAL_BIN"
  ensure ln -fs "$_scarb" "$_symlink"
  ensure chmod u+x "$_symlink"

  say "created symlink ${_symlink} -> ${_scarb}"
}

add_local_bin_to_path() {
  local _profile
  local _pref_shell
  case ${SHELL:-""} in
  */zsh)
    _profile=$HOME/.zshrc
    _pref_shell=zsh
    ;;
  */ash)
    _profile=$HOME/.profile
    _pref_shell=ash
    ;;
  */bash)
    _profile=$HOME/.bashrc
    _pref_shell=bash
    ;;
  */fish)
    _profile=$HOME/.config/fish/config.fish
    _pref_shell=fish
    ;;
  *)
    err "could not detect shell, manually add '${LOCAL_BIN_ESCAPED}' to your PATH."
    ;;
  esac

  echo >>"$_profile" && echo "export PATH=\"\$PATH:${LOCAL_BIN_ESCAPED}\"" >>"$_profile"
  echo \
    "Detected your preferred shell is ${_pref_shell} and added '${LOCAL_BIN_ESCAPED}' to PATH." \
    "Run 'source ${_profile}' or start a new terminal session to use Scarb."
}

main "$@" || exit 1
