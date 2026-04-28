#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/lib/common.sh"

ROOT_DIR=$(common_repo_root)
ENV_FILE=${1:-${EC2_ENV_FILE:-${ROOT_DIR}/.env.ec2}}
COMPOSE_FILE="${ROOT_DIR}/docker-compose.ec2.yml"
ENV_FILE=$(common_require_env_file "${ENV_FILE}")

docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" config >/dev/null

# Extract ECR registry hostname from BACKEND_IMAGE_REPO and authenticate
BACKEND_IMAGE_REPO=$(grep -E '^BACKEND_IMAGE_REPO=' "${ENV_FILE}" | cut -d= -f2-)
ECR_REGISTRY=$(printf '%s' "${BACKEND_IMAGE_REPO}" | cut -d/ -f1)
ECR_REGION=$(printf '%s' "${ECR_REGISTRY}" | grep -oE 'ecr\.[a-z0-9-]+\.amazonaws\.com' | cut -d. -f2)
if [ -n "${ECR_REGISTRY}" ] && [ -n "${ECR_REGION}" ]; then
  aws ecr get-login-password --region "${ECR_REGION}" \
    | docker login --username AWS --password-stdin "${ECR_REGISTRY}"
fi

docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" pull
docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" up -d
docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" ps
