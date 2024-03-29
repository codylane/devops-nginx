#!/usr/bin/env bash

CMD="${BASH_SOURCE[0]}"
BIN_DIR="${CMD%/*}"
cd ${BIN_DIR}
BIN_DIR="${PWD}"

MINICONDA_INSTALL_DIR="${HOME}/miniconda3"

export USER_UID=$(id -u $USER)
export USER_GID=$(id -g $USER)

PROJNAME="${PROJNAME:-${BIN_DIR##*/}}"

CONDA_ENV_PYTHON="3.9"
CONDA_ENV_NAME="${PROJNAME}-${CONDA_ENV_PYTHON}"

OS_TYPE="${OS_TYPE:-}"

export PATH="${MINICONDA_INSTALL_DIR}/bin:$PWD/bin:$PWD/:$PATH"

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

  curl -LO ${MINICONDA_URL}
  chmod 755 ${MINICONDA_INSTALLER}

  ./${MINICONDA_INSTALLER} -b- u -p ${MINICONDA_INSTALL_DIR}
}

install_miniconda_osx64()
{
  local MINICONDA_INSTALLER="Miniconda3-latest-MacOSX-x86_64.sh"
  local MINICONDA_URL="https://repo.continuum.io/miniconda/Miniconda3-latest-MacOSX-x86_64.sh"

  curl -LO ${MINICONDA_URL}
  chmod 755 ${MINICONDA_INSTALLER}

  ./${MINICONDA_INSTALLER} -b -u -p ${MINICONDA_INSTALL_DIR}
}

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

activate_ci()
{
  info "$GREEN" "Activating CI..."
  echo

  run_pip_if_recent_requirements_change "${BIN_DIR}/test-requirements.txt"
}

activate_prod()
{
  info "$GREEN" "Activating PROD..."
  echo
}

activate_env()
{
  local ACTIVATE_ENV="${1}"

  case "$ACTIVATE_ENV" in

    prod|production)
      activate_prod
      ;;

    *)
      activate_ci
      ;;

  esac
}


filetime_last_change_in_seconds()
{
  stat -c %Z "${1}"
}

get_file_contents()
{
  cat "${1}" 2>>/dev/null || echo ""
}

get_cache_filename()
{
  local _default_cache="${1}"
  is_conda_env_active && _default_cache="${1}-${CONDA_DEFAULT_ENV}" || _default_cache="${1}"

  local CACHE_FILENAME="${BIN_DIR}/.${_default_cache##*/}.lcts"

  echo "${CACHE_FILENAME}"
}

update_cache_file()
{
  local DEFAULT_CACHE_FILENAME=$(get_cache_filename "${1}")
  local CHECK_FILENAME="${1}"
  local CACHE_FILENAME="${2:-${DEFAULT_CACHE_FILENAME}}"
  local LAST_CHANGE_TIME_SECS=$(filetime_last_change_in_seconds "${CHECK_FILENAME}")

  info "$GREEN" "update_cache_file: DEFAULT_CACHE_FILENAME=${DEFAULT_CACHE_FILENAME} CACHE_FILENAME=$CACHE_FILENAME"

  echo "${LAST_CHANGE_TIME_SECS}" > "${CACHE_FILENAME}"

  echo $LAST_CHANGE_TIME_SECS
}

cache_file_last_change_in_seconds()
{
  [ -z "${1}" ] && err "Please pass a filename path as the first argument"

  local CHECK_FILENAME="${1}"
  local CACHE_FILENAME=$(get_cache_filename "${1}")

  # get last change time
  local LAST_CHANGE_TIME_SECS=$(filetime_last_change_in_seconds "${CHECK_FILENAME}")

  # if cache file does not exist, display seconds since list last change and return
  if [ ! -f "${CACHE_FILENAME}" ]; then
    echo $LAST_CHANGE_TIME_SECS
    return
  fi

  # cache file exists, get cache file last change time stamp (LCTS)
  local CACHE_FILE_LCTS=$(get_file_contents "${CACHE_FILENAME}")

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

is_conda_env_active()
{
  # If not NULL, environment is active, rc=0, otherwise rc=1
  [ -n ${CONDA_DEFAULT_ENV} ]

}

run_pip_if_recent_requirements_change()
{
  local REQUIREMENTS_FILE="${1}"
  local CACHE_FILE=

  info "${GREEN}" "The active conda environment is: '${CONDA_DEFAULT_ENV}'"
  CACHE_FILE=$(get_cache_filename "${REQUIREMENTS_FILE}")

  info "${GREEN}" "cache state file: ${CACHE_FILE}"

  [ -f "${REQUIREMENTS_FILE}" ] || err "The requirements file: ${REQUIREMENTS_FILE} does not exist"
  info "${GREEN}" "REQUIREMENTS_FILE=$REQUIREMENTS_FILE"

  local CACHE_FILE_LCTS=$(cache_file_last_change_in_seconds "${REQUIREMENTS_FILE}")
  info "${GREEN}" "CACHE_FILE_LCTS=$CACHE_FILE_LCTS"

  if [ ${CACHE_FILE_LCTS} -ne 0 ]; then
    info "${GREEN}" "Refreshing requirements deps"
    update_cache_file "${REQUIREMENTS_FILE}" "${CACHE_FILE}" >>/dev/null

    pip install -r "${REQUIREMENTS_FILE}"
    [ -f setup.py ] && pip install -e . || true
  fi
}

init_osx()
{
  info "$YELLOWBOLD" "WARNING: there is no handler for osx yet"

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

init_linux()
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

create_conda_env()
{
  local NAME="${1}"
  local PYTHON="${2}"

  [ -z "${1}" ] && err "Please pass NAME as first argument to create_conda_env"
  [ -z "${2}" ] && err "Please pass PYTHON as second argument to create_conda_env"

  conda create -y -n "${NAME}" python="${PYTHON}"

  # activate conda environment
  conda activate ${NAME}

  # remove last change time stamps
  rm -f .*.lcts

  run_pip_if_recent_requirements_change "${BIN_DIR}/requirements.txt"

  conda deactivate
}

remove_conda_envs()
{
  command -v conda >>/dev/null

  MINICONDA_INSTALL_DIR="${HOME}/miniconda3"

  conda deactivate

  find "${MINICONDA_INSTALL_DIR}/envs" -name "${PROJNAME}*" -type d | sort | while read env_name
  do
    rm -rf "${env_name}"
  done
}


## main ##

[ -z "${CONDA_ENV_NAME}" ] && err "Please set CONDA_ENV_NAME"
[ -z "${PROJNAME}" ] && err "please set PROJNAME"

info "$GREEN" "BIN_DIR=${BIN_DIR}"

info "$GREEN" "CONDA_ENV_NAME=$CONDA_ENV_NAME"
info "$GREEN" "CONDA_ENV_PYTHON=$CONDA_ENV_PYTHON"

get_os_type || err "The OS type $OS_TYPE is not supported for local development"

eval "init_${OS_TYPE}"
[ -f ${MINICONDA_INSTALL_DIR}/etc/profile.d/conda.sh ] && . ${MINICONDA_INSTALL_DIR}/etc/profile.d/conda.sh
[ -f /usr/local/miniconda3/etc/profile.d/conda.sh ] && . /usr/local/miniconda3/etc/profile.d/conda.sh
[ -f /etc/profile.d/miniconda.sh ] && . /etc/profile.d/miniconda.sh
[ -f /usr/local/Caskroom/miniconda/base/etc/profile.d/conda.sh ] && . /usr/local/Caskroom/miniconda/base/etc/profile.d/conda.sh

[ $(find . -maxdepth 1 -name '*.lcts' -type f -print | wc -l) -eq 0 ] && remove_conda_envs || true

has_conda_env "${CONDA_ENV_NAME}" || create_conda_env "${CONDA_ENV_NAME}" "${CONDA_ENV_PYTHON}"

conda activate ${CONDA_ENV_NAME}

run_pip_if_recent_requirements_change "${BIN_DIR}/requirements.txt"

activate_env "${1:-ci}"

export PATH="${CONDA_PREFIX}/bin:${PATH}"
