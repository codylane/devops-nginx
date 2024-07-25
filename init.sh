#!/usr/bin/env bash

CMD="${BASH_SOURCE[0]}"
BIN_DIR="${CMD%/*}"
cd ${BIN_DIR}
BIN_DIR="${PWD}"

PROJNAME="${PROJNAME:-${BIN_DIR##*/}}"

export MY_UID="$(id -u)"
export MY_GID="$(id -g)"

MINICONDA_INSTALL_DIR="${HOME}/miniconda3"

export USER_UID="$(id -u $USER)"
export USER_GID="$(id -g $USER)"

OS_TYPE="${OS_TYPE:-}"

export PATH="$PWD/bin:$PATH"

BLACK="\033[0;30m"
BLACKBOLD="\033[1;30m"
RED="\033[0;31m"
REDBOLD="\033[1;31m"
GREEN="\033[0;32m"
GREENBOLD="\033[1;32m"
YELLOW="\033[0;33m"
YELLOWBOLD="\033[1;33m"
BLUE="\033[0;34m"
BLUEBOLD="\033[1;34m"
PURPLE="\033[0;35m"
PURPLEBOLD="\033[1;35m"
CYAN="\033[0;36m"
CYANBOLD="\033[1;36m"
WHITE="\033[0;37m"
WHITEBOLD="\033[1;37m"

INIT_CONDA_ENVS=.conda.envs
INIT_ENV=.init.env


err()
{
  echo "ERR: $* exiting" >&2
  exit 1
}


info()
{
  local MSG_COLOR="${1:-$WHITE}"
  shift

  echo -en "${MSG_COLOR}${@}\033[0m"
  echo
}


get_os_type()
{
  case "$(uname -s)" in

    Darwin)
      OS_TYPE="osx"
      OS_ARCH="$(uname -m)"
      return 0
    ;;

    Linux)
      OS_TYPE="linux"
      OS_ARCH="$(uname -m)"
      return 0
    ;;

    *)
      return 1
    ;;

  esac
}


has_conda_env()
{
  conda list -n "${1}" 2>&1 >>/dev/null 2>&1
}


install_miniconda_linux64()
{
  local MINICONDA_INSTALLER="Miniconda3-latest-Linux-x86_64.sh"
  local MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh"

  init_conda
}


install_miniconda_osx64()
{
  local MINICONDA_INSTALLER="Miniconda3-latest-MacOSX-x86_64.sh"
  local MINICONDA_URL="https://repo.continuum.io/miniconda/Miniconda3-latest-MacOSX-x86_64.sh"

  init_conda
}


init_conda()
{
  curl -LO ${MINICONDA_URL}
  chmod 755 ${MINICONDA_INSTALLER}

  ./${MINICONDA_INSTALLER} -b -u -p ${MINICONDA_INSTALL_DIR}

  export PATH="${PATH}:${MINICONDA_INSTALL_DIR}/bin"

  conda init ${SHELL##*/}

  [ -f "${HOME}/.profile" ]      && . "${HOME}/.profile"      || true
  [ -f "${HOME}/.bash_profile" ] && . "${HOME}/.bash_profile" || true
  [ -f "${HOME}/.bashrc" ]       && . "${HOME}/.bashrc"       || true
}


activate-ci()
{

  info "$GREEN" "Activating CI..."
  echo

  run-pip-if-recent-requirements-change "${BIN_DIR}/test-requirements.txt"

}

activate-prod()
{

  info "$GREEN" "Activating PROD..."
  echo

}

activate-env()
{
  local ACTIVATE_ENV="${1}"

  case "$ACTIVATE_ENV" in

    prod|production)
      activate-prod
      ;;

    *)
      activate-ci
      ;;

  esac
}


filetime-last-change-in-seconds()
{
  stat -c %Z "${1}"
}


get-file-contents()
{
  cat "${1}" 2>>/dev/null || echo ""
}

get-cache-filename()
{

  local _default_cache="${1}"
  _default_cache="${1}-${CONDA_DEFAULT_ENV}"

  local cache_filename="${BIN_DIR}/.${_default_cache##*/}.lcts"

  echo "${cache_filename}"

}

update-cache-file()
{
  [ -z "${1}" ] && err "Please pass a filename path as the first argument"

  local DEFAULT_CACHE_FILENAME=$(get-cache-filename "${1}")
  local CHECK_FILENAME="${1}"
  local CACHE_FILENAME="${2:-${DEFAULT_CACHE_FILENAME}}"
  local LAST_CHANGE_TIME_SECS=$(filetime-last-change-in-seconds "${CHECK_FILENAME}")

  info "$GREEN" "update-cache-file: DEFAULT_CACHE_FILENAME=${DEFAULT_CACHE_FILENAME} CACHE_FILENAME=$CACHE_FILENAME"

  echo "${LAST_CHANGE_TIME_SECS}" > "${CACHE_FILENAME}"

  echo $LAST_CHANGE_TIME_SECS
}


cache-file-last-change-in-seconds()
{
  [ -z "${1}" ] && err "Please pass a filename path as the first argument"

  local CHECK_FILENAME="${1}"
  local CACHE_FILENAME=$(get-cache-filename "${1}")

  # get last change time
  local LAST_CHANGE_TIME_SECS=$(filetime-last-change-in-seconds "${CHECK_FILENAME}")

  # if cache file does not exist, display seconds since list last change and return
  if [ ! -f "${CACHE_FILENAME}" ]; then
    echo $LAST_CHANGE_TIME_SECS
    return
  fi

  # cache file exists, get cache file last change time stamp (LCTS)
  local CACHE_FILE_LCTS=$(get-file-contents "${CACHE_FILENAME}")

  local DELTA_LCTS=$((LAST_CHANGE_TIME_SECS - CACHE_FILE_LCTS))
  [ $DELTA_LCTS -lt 0 ] && DELTA_LCTS=$((DELTA_LCTS * -1))

  echo $DELTA_LCTS
}


debug_console()
{
  echo "#############|  Entering DEBUG mode  |####################";
  CMD=
  set -x
  while [ "${CMD}" != "exit" ]; do
      read -p "> " CMD
      case "${CMD}" in

          vars)
            (set -o posix ; set)
            ;;

          exit|quit)
            ;;

          *)
            eval "${CMD}"
            ;;
      esac
  done
  set +x
  echo "#############|  End of DEBUG mode |####################";
}


run-pip-if-recent-requirements-change()
{
  local REQUIREMENTS_FILE="${1}"
  local CACHE_FILE=

  [ -z "${REQUIREMENTS_FILE}" ] && err "Please pass a filename path to the requirements.txt file as the first arguemnt"

  info "${GREEN}" "The active conda environment is: '${CONDA_DEFAULT_ENV}'"
  CACHE_FILE=$(get-cache-filename "${REQUIREMENTS_FILE}")

  info "${GREEN}" "cache state file: ${CACHE_FILE}"

  [ -f "${REQUIREMENTS_FILE}" ] || err "The requirements file: ${REQUIREMENTS_FILE} does not exist"
  info "${GREEN}" "REQUIREMENTS_FILE=$REQUIREMENTS_FILE"

  local CACHE_FILE_LCTS=$(cache-file-last-change-in-seconds "${REQUIREMENTS_FILE}")
  info "${GREEN}" "CACHE_FILE_LCTS=$CACHE_FILE_LCTS"

  if [ ${CACHE_FILE_LCTS} -ne 0 ]; then
    info "${GREEN}" "Refreshing requirements deps"
    update-cache-file "${REQUIREMENTS_FILE}" "${CACHE_FILE}" >>/dev/null

    pip install -r "${REQUIREMENTS_FILE}"
    [ -f setup.py ] && pip install -e . || true
  fi
}


init-osx()
{
  case "${OS_ARCH}" in

    x86_64)
      command -v conda >>/dev/null || install_miniconda_osx64
      ;;

    *)
      info "$REDBOLD" "WARNING: OS arch ${OS_ARCH} is not currently supported"
      return 1
      ;;

  esac
}


init-linux()
{
  info "$GREEN" "Initializing linux deps"

  case "${OS_ARCH}" in

    x86_64)
      command -v conda >>/dev/null || install_miniconda_linux64
      ;;

    *)
      info "$REDBOLD" "WARNING: OS arch ${OS_ARCH} is not currently supported"
      return 1
      ;;

  esac
}


coverage_report()
{
  local test_module="${1:-tests/}"

  [ "$#" -gt 1 ] && shift

  coverage run -m pytest -vvrs ${@} ${test_module} || true
  coverage report --show-missing
}


bandit_report()
{
  bandit --ini tox.ini -r "$@"
}


create-conda-env()
{
    local NAME="${1}"
    local PYTHON="${2}"

    [ -z "${1}" ] && err "Please pass NAME as first argument to create-conda-env"
    [ -z "${2}" ] && err "Please pass PYTHON as second argument to create-conda-env"

    conda create -y -n "${NAME}" python="${PYTHON}"

    # activate conda environment
    conda activate ${NAME}

    # remove last change time stamps
    rm -f .*.lcts

    run-pip-if-recent-requirements-change "${BIN_DIR}/requirements.txt"

    conda deactivate
}


activate-conda-env-and-install-requirements()
{
  for conda_env in "${CONDA_ENV_PYTHON[@]}"
  do
    local conda_env_name="${PROJNAME}-${conda_env}"

    # cache the conda env name
    echo "${conda_env_name}" >> "${INIT_CONDA_ENVS}"

    # remove duplicates from cache env
    sort "${INIT_CONDA_ENVS}" | uniq > "${INIT_CONDA_ENVS}.new"
    mv -f "${INIT_CONDA_ENVS}.new" "${INIT_CONDA_ENVS}"

    info "$GREEN" "CONDA_ENV_NAME=${conda_env_name}"
    info "$GREEN" "CONDA_ENV_PYTHON=${conda_env}"

    has_conda_env "${conda_env_name}" || create-conda-env "${conda_env_name}" "${conda_env}"
    conda activate ${conda_env_name}
    activate-env "${conda_env:-ci}"
    run-pip-if-recent-requirements-change "${BIN_DIR}/requirements.txt"

    local bin_dir="${CONDA_PREFIX}/bin"

    [ -d "${bin_dir}" ] || err "The directory: '${bin_dir}' does not exist"

    export PATH="${bin_dir}:${PATH}"
  done
}


run_ansible()
{
  local target="${1}"
  [ "$#" -ge 1 ] && shift || true

  command -v ansible || return 1

  ansible-playbook -u deploy -i "${target}", -vv "$@" orchestrate.yml

}


_update_conda()
{

  for conda_env in "${CONDA_ENV_PYTHON[@]}"
  do
    local conda_env_name="${PROJNAME}-${conda_env}"

    conda update -y --all -n "${conda_env_name}"
  done
}


main()
{
  case "${1}" in

    update-conda)
      shift

      _update_conda
      ;;

  esac

  info "$GREEN" "BIN_DIR=${BIN_DIR}"
}


## main ##
main

[ -f "${INIT_ENV}" ] && . "${INIT_ENV}" || err "Please create a '${INIT_ENV}' file"
[ -z "${PROJNAME}" ] && err "please set PROJNAME"
[ -f ${MINICONDA_INSTALL_DIR}/etc/profile.d/conda.sh ] && . ${MINICONDA_INSTALL_DIR}/etc/profile.d/conda.sh
[ -f /usr/local/miniconda3/etc/profile.d/conda.sh ] && . /usr/local/miniconda3/etc/profile.d/conda.sh
[ -f /etc/profile.d/miniconda.sh ] && . /etc/profile.d/miniconda.sh
[ -f /usr/local/Caskroom/miniconda/base/etc/profile.d/conda.sh ] && . /usr/local/Caskroom/miniconda/base/etc/profile.d/conda.sh

get_os_type || err "The OS type $OS_TYPE is not supported for local development"

eval "init-${OS_TYPE}"

activate-conda-env-and-install-requirements
