#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/lib/common.sh"

ROOT_DIR=$(common_repo_root)
ENV_FILE=${ENV_FILE:-}

if [ -n "${ENV_FILE}" ]; then
  common_source_env_file "${ENV_FILE}"
  ENV_FILE="${COMMON_ENV_FILE}"
fi

IMAGE_TAG=${1:-${IMAGE_TAG:-}}
BACKEND_IMAGE_REPO=${BACKEND_IMAGE_REPO:-}
CMS_IMAGE_REPO=${CMS_IMAGE_REPO:-}
IMAGE_PLATFORM=${IMAGE_PLATFORM:-linux/arm64}

if [ -z "${IMAGE_TAG}" ]; then
  echo "IMAGE_TAG is required (arg 1 or env)." >&2
  exit 1
fi
if [ -z "${BACKEND_IMAGE_REPO}" ]; then
  echo "BACKEND_IMAGE_REPO is required." >&2
  exit 1
fi
if [ -z "${CMS_IMAGE_REPO}" ]; then
  echo "CMS_IMAGE_REPO is required." >&2
  exit 1
fi

BACKEND_IMAGE="${BACKEND_IMAGE_REPO}:${IMAGE_TAG}"
CMS_IMAGE="${CMS_IMAGE_REPO}:${IMAGE_TAG}"
USE_DOCKER_BUILDX=${USE_DOCKER_BUILDX:-0}

if [ "${USE_DOCKER_BUILDX}" = "1" ]; then
  echo "Building and pushing ${BACKEND_IMAGE} with docker buildx for ${IMAGE_PLATFORM}"
  docker buildx build \
    --platform "${IMAGE_PLATFORM}" \
    -f "${ROOT_DIR}/backend/Dockerfile" \
    -t "${BACKEND_IMAGE}" \
    --push \
    "${ROOT_DIR}/backend"

  echo "Building and pushing ${CMS_IMAGE} with docker buildx for ${IMAGE_PLATFORM}"
  docker buildx build \
    --platform "${IMAGE_PLATFORM}" \
    -f "${ROOT_DIR}/cms/Dockerfile" \
    -t "${CMS_IMAGE}" \
    --push \
    "${ROOT_DIR}/cms"
else
  echo "Building ${BACKEND_IMAGE} for ${IMAGE_PLATFORM}"
  docker build \
    --platform "${IMAGE_PLATFORM}" \
    -f "${ROOT_DIR}/backend/Dockerfile" \
    -t "${BACKEND_IMAGE}" \
    "${ROOT_DIR}/backend"

  echo "Building ${CMS_IMAGE} for ${IMAGE_PLATFORM}"
  docker build \
    --platform "${IMAGE_PLATFORM}" \
    -f "${ROOT_DIR}/cms/Dockerfile" \
    -t "${CMS_IMAGE}" \
    "${ROOT_DIR}/cms"

  echo "Pushing ${BACKEND_IMAGE}"
  docker push "${BACKEND_IMAGE}"

  echo "Pushing ${CMS_IMAGE}"
  docker push "${CMS_IMAGE}"
fi

echo "Done."
