#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/lib/common.sh"

ROOT_DIR=$(common_repo_root)
ENV_FILE=${1:-${EC2_ENV_FILE:-${ROOT_DIR}/.env.ec2}}
common_source_env_file "${ENV_FILE}"
ENV_FILE="${COMMON_ENV_FILE}"

required_vars='
PROXY_NETWORK
AWS_REGION
AWS_ACCOUNT_ID
ECR_REGISTRY
LE_EMAIL
BACKEND_HOST
CMS_HOST
BACKEND_IMAGE_REPO
CMS_IMAGE_REPO
IMAGE_TAG
IMAGE_PLATFORM
API_BASE_URL
DATABASE_URL
'

missing=0
for key in ${required_vars}; do
  eval "value=\${${key}:-}"
  if [ -z "${value}" ]; then
    echo "ERROR: ${key} is required."
    missing=1
  fi
done

if [ "${missing}" -ne 0 ]; then
  exit 1
fi

if [ "${BACKEND_HOST}" = "${CMS_HOST}" ]; then
  echo "ERROR: BACKEND_HOST and CMS_HOST should be different for the current nginx-proxy deployment shape."
  exit 1
fi

case "${TRANSCRIBER_PROVIDER:-dev}" in
  ""|dev|amazon_transcribe)
    ;;
  *)
    echo "ERROR: TRANSCRIBER_PROVIDER must be dev or amazon_transcribe."
    exit 1
    ;;
esac

case "${ATTEMPT_UPLOAD_PROVIDER:-local}" in
  ""|local|s3)
    ;;
  *)
    echo "ERROR: ATTEMPT_UPLOAD_PROVIDER must be local or s3."
    exit 1
    ;;
esac

case "${REQUIRE_REAL_TRANSCRIPT:-false}" in
  ""|false|FALSE|0|no|NO)
    REQUIRE_REAL_TRANSCRIPT_NORMALIZED=false
    ;;
  true|TRUE|1|yes|YES)
    REQUIRE_REAL_TRANSCRIPT_NORMALIZED=true
    ;;
  *)
    echo "ERROR: REQUIRE_REAL_TRANSCRIPT must be true or false."
    exit 1
    ;;
esac

if [ "${IMAGE_PLATFORM}" != "linux/arm64" ]; then
  echo "WARN: IMAGE_PLATFORM is ${IMAGE_PLATFORM}; for the current EC2 host you likely want linux/arm64."
fi

if command -v docker >/dev/null 2>&1; then
  if docker network inspect "${PROXY_NETWORK}" >/dev/null 2>&1; then
    :
  else
    echo "WARN: docker network '${PROXY_NETWORK}' was not found on the current Docker host."
  fi
fi

if [ "${TRANSCRIBER_PROVIDER:-dev}" = "dev" ]; then
  echo "WARN: TRANSCRIBER_PROVIDER=dev, so production will still use the dev transcript path."
fi

if [ "${ATTEMPT_UPLOAD_PROVIDER:-local}" = "local" ]; then
  echo "WARN: ATTEMPT_UPLOAD_PROVIDER=local, so audio will still upload through the backend host."
fi

if [ "${ATTEMPT_UPLOAD_PROVIDER:-local}" = "s3" ]; then
  if [ -z "${ATTEMPT_AUDIO_S3_BUCKET:-}" ]; then
    echo "ERROR: ATTEMPT_AUDIO_S3_BUCKET is required when ATTEMPT_UPLOAD_PROVIDER=s3."
    exit 1
  fi
fi

if [ "${TRANSCRIBER_PROVIDER:-dev}" = "amazon_transcribe" ]; then
  if [ -z "${ATTEMPT_AUDIO_S3_BUCKET:-}" ]; then
    echo "ERROR: ATTEMPT_AUDIO_S3_BUCKET is required when TRANSCRIBER_PROVIDER=amazon_transcribe."
    exit 1
  fi
  if [ -z "${TRANSCRIBE_LANGUAGE_CODE:-}" ]; then
    echo "ERROR: TRANSCRIBE_LANGUAGE_CODE is required when TRANSCRIBER_PROVIDER=amazon_transcribe."
    exit 1
  fi
fi

if [ "${REQUIRE_REAL_TRANSCRIPT_NORMALIZED:-false}" = "true" ]; then
  if [ "${TRANSCRIBER_PROVIDER:-dev}" != "amazon_transcribe" ]; then
    echo "ERROR: REQUIRE_REAL_TRANSCRIPT=true requires TRANSCRIBER_PROVIDER=amazon_transcribe."
    exit 1
  fi
  if [ "${ATTEMPT_UPLOAD_PROVIDER:-local}" != "s3" ]; then
    echo "ERROR: REQUIRE_REAL_TRANSCRIPT=true requires ATTEMPT_UPLOAD_PROVIDER=s3 in the current architecture."
    exit 1
  fi
fi

if [ "${CMS_ADMIN_TOKEN:-}" = "dev-admin-token" ]; then
  echo "WARN: CMS_ADMIN_TOKEN is still the default dev-admin-token."
fi

if [ -z "${CMS_BASIC_AUTH_USER:-}" ] || [ -z "${CMS_BASIC_AUTH_PASSWORD:-}" ]; then
  echo "WARN: CMS_BASIC_AUTH_USER or CMS_BASIC_AUTH_PASSWORD is empty, so the CMS web layer is not protected with Basic Auth."
elif [ "${CMS_BASIC_AUTH_PASSWORD:-}" = "change-me" ]; then
  echo "WARN: CMS_BASIC_AUTH_PASSWORD still uses the placeholder value change-me."
fi

if printf '%s' "${DATABASE_URL}" | grep -q 'sslmode=require'; then
  :
else
  echo "WARN: DATABASE_URL does not include sslmode=require."
fi

echo "OK: ${ENV_FILE} passed required-variable checks."
