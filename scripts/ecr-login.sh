#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/lib/common.sh"

ROOT_DIR=$(common_repo_root)
ENV_FILE=${1:-${EC2_ENV_FILE:-${ROOT_DIR}/.env.ec2}}
common_source_env_file "${ENV_FILE}"
ENV_FILE="${COMMON_ENV_FILE}"

AWS_REGION=${AWS_REGION:-}
ECR_REGISTRY=${ECR_REGISTRY:-}

if [ -z "${AWS_REGION}" ]; then
  echo "AWS_REGION is required." >&2
  exit 1
fi
if [ -z "${ECR_REGISTRY}" ]; then
  echo "ECR_REGISTRY is required." >&2
  exit 1
fi

aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${ECR_REGISTRY}"
