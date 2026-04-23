#!/bin/sh

common_script_dir() {
  CDPATH= cd -- "$(dirname -- "$0")" && pwd
}

common_repo_root() {
  CDPATH= cd -- "$(common_script_dir)/.." && pwd
}

common_canonical_path() {
  input_path=$1
  dir_path=$(CDPATH= cd -- "$(dirname -- "${input_path}")" && pwd)
  printf '%s/%s\n' "${dir_path}" "$(basename -- "${input_path}")"
}

common_require_env_file() {
  env_file=$1
  if [ ! -f "${env_file}" ]; then
    echo "Env file not found: ${env_file}" >&2
    exit 1
  fi
  common_canonical_path "${env_file}"
}

common_source_env_file() {
  env_file=$(common_require_env_file "$1")
  set -a
  # shellcheck disable=SC1090
  . "${env_file}"
  set +a
  COMMON_ENV_FILE="${env_file}"
}
