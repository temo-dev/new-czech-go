#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/lib/common.sh"

ROOT_DIR=$(common_repo_root)
ENV_FILE=${1:-${EC2_ENV_FILE:-${ROOT_DIR}/.env.ec2}}

if [ -f "${ENV_FILE}" ]; then
  common_source_env_file "${ENV_FILE}"
  ENV_FILE="${COMMON_ENV_FILE}"
fi

missing=0

require_cmd() {
  if command -v "$1" >/dev/null 2>&1; then
    :
  else
    echo "ERROR: required command '$1' was not found."
    missing=1
  fi
}

require_cmd docker
require_cmd aws
require_cmd curl

ARCH=$(uname -m 2>/dev/null || echo unknown)
if [ "${ARCH}" = "aarch64" ] || [ "${ARCH}" = "arm64" ]; then
  :
else
  echo "WARN: host architecture is '${ARCH}', not arm64/aarch64."
fi

if command -v docker >/dev/null 2>&1; then
  if docker info >/dev/null 2>&1; then
    :
  else
    echo "ERROR: Docker is installed but the daemon is not reachable for the current user."
    missing=1
  fi

  if docker compose version >/dev/null 2>&1; then
    :
  else
    echo "ERROR: Docker Compose plugin is missing."
    missing=1
  fi

  if [ -n "${PROXY_NETWORK:-}" ]; then
    if docker network inspect "${PROXY_NETWORK}" >/dev/null 2>&1; then
      :
    else
      echo "WARN: proxy network '${PROXY_NETWORK}' does not exist yet."
    fi
  fi
fi

if command -v aws >/dev/null 2>&1; then
  if aws sts get-caller-identity >/dev/null 2>&1; then
    :
  else
    echo "WARN: AWS CLI is installed but credentials or instance role are not ready yet."
  fi
fi

if command -v ss >/dev/null 2>&1; then
  if ss -ltn '( sport = :80 or sport = :443 )' 2>/dev/null | grep -q LISTEN; then
    :
  else
    echo "WARN: nothing is listening on ports 80/443 yet; proxy stack may still be down."
  fi
fi

if [ "${missing}" -ne 0 ]; then
  exit 1
fi

echo "OK: host checks passed."
