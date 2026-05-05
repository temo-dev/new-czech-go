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
  common_lint_env_file "${env_file}"
  set -a
  # shellcheck disable=SC1090
  . "${env_file}"
  set +a
  COMMON_ENV_FILE="${env_file}"
}

# common_lint_env_file rejects env-file lines whose values contain unquoted
# whitespace. POSIX `set -a; . file` parses `KEY=foo bar` as `KEY=foo` plus
# a `bar` invocation — on macOS APFS (case-insensitive) this is how
# `EMAIL_FROM_NAME=Czech Go` ended up running the `go` binary instead of
# setting the variable. Catch the foot-gun before sourcing.
common_lint_env_file() {
  env_file=$1
  bad=$(awk '
    # Skip blanks and comments.
    /^[[:space:]]*($|#)/ { next }
    # Only inspect KEY=VALUE assignments.
    /^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=/ {
      sub(/^[[:space:]]*export[[:space:]]+/, "")
      key = $0
      sub(/=.*/, "", key)
      val = $0
      sub(/^[^=]*=/, "", val)
      if (val ~ /^".*"$/) next
      if (val ~ /^'\''.*'\''$/) next
      sub(/[[:space:]]+#.*$/, "", val)
      # Trim trailing whitespace — POSIX shell already tolerates it.
      sub(/[[:space:]]+$/, "", val)
      # Whitespace between non-whitespace runs is the real bug.
      if (val ~ /[^[:space:]][[:space:]]+[^[:space:]]/) {
        printf("  line %d: %s=%s\n", NR, key, val)
      }
    }
  ' "${env_file}")
  if [ -n "${bad}" ]; then
    echo "ERROR: ${env_file} has unquoted values with whitespace:" >&2
    echo "${bad}" >&2
    echo "" >&2
    echo "Wrap the value in double quotes, e.g. EMAIL_FROM_NAME=\"Czech Go\"." >&2
    echo "Otherwise POSIX shell parses 'KEY=foo bar' as 'KEY=foo' + a 'bar'" >&2
    echo "command invocation when the file is sourced." >&2
    exit 1
  fi
}
