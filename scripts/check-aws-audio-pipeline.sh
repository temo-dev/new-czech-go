#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/lib/common.sh"

ROOT_DIR=$(common_repo_root)
ENV_FILE=${1:-${EC2_ENV_FILE:-${ROOT_DIR}/.env.ec2}}
common_source_env_file "${ENV_FILE}"
ENV_FILE="${COMMON_ENV_FILE}"

if ! command -v aws >/dev/null 2>&1; then
  echo "ERROR: aws CLI is required on the current host." >&2
  exit 1
fi

if [ -z "${AWS_REGION:-}" ]; then
  echo "ERROR: AWS_REGION is required." >&2
  exit 1
fi

if [ -z "${ATTEMPT_AUDIO_S3_BUCKET:-}" ]; then
  echo "ERROR: ATTEMPT_AUDIO_S3_BUCKET is required." >&2
  exit 1
fi

echo "Checking AWS caller identity..."
aws sts get-caller-identity --output json >/dev/null

echo "Checking attempt-audio bucket access..."
aws s3api get-bucket-location --bucket "${ATTEMPT_AUDIO_S3_BUCKET}" >/dev/null
aws s3api list-objects-v2 \
  --bucket "${ATTEMPT_AUDIO_S3_BUCKET}" \
  --prefix "${ATTEMPT_AUDIO_S3_PREFIX:-attempt-audio}" \
  --max-keys 1 >/dev/null

if [ -n "${TRANSCRIBE_OUTPUT_BUCKET:-}" ]; then
  echo "Checking transcription-output bucket access..."
  aws s3api get-bucket-location --bucket "${TRANSCRIBE_OUTPUT_BUCKET}" >/dev/null
  aws s3api list-objects-v2 \
    --bucket "${TRANSCRIBE_OUTPUT_BUCKET}" \
    --prefix "${TRANSCRIBE_OUTPUT_PREFIX:-}" \
    --max-keys 1 >/dev/null
fi

echo "Checking Amazon Transcribe API access..."
aws transcribe list-transcription-jobs \
  --region "${AWS_REGION}" \
  --status IN_PROGRESS \
  --max-results 1 >/dev/null

echo "OK: AWS identity, S3 bucket access, and Transcribe API access look reachable from ${ENV_FILE}."
