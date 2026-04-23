#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/lib/common.sh"

ROOT_DIR=$(common_repo_root)
ENV_FILE=${1:-${EC2_ENV_FILE:-${ROOT_DIR}/.env.ec2}}
DIST_DIR="${ROOT_DIR}/dist"
BUNDLE_DIR="${DIST_DIR}/ec2-deploy"
ARCHIVE_PATH="${DIST_DIR}/czech-go-system-ec2-deploy.tar.gz"
ENV_FILE=$(common_require_env_file "${ENV_FILE}")

rm -rf "${BUNDLE_DIR}"
mkdir -p "${BUNDLE_DIR}/scripts/lib"

cp "${ROOT_DIR}/docker-compose.proxy.yml" "${BUNDLE_DIR}/docker-compose.proxy.yml"
cp "${ROOT_DIR}/docker-compose.ec2.yml" "${BUNDLE_DIR}/docker-compose.ec2.yml"
cp "${ENV_FILE}" "${BUNDLE_DIR}/.env.ec2"
cp "${ROOT_DIR}/.env.ec2.example" "${BUNDLE_DIR}/.env.ec2.example"
cp "${ROOT_DIR}/scripts/check-ec2-host.sh" "${BUNDLE_DIR}/scripts/check-ec2-host.sh"
cp "${ROOT_DIR}/scripts/check-ec2-env.sh" "${BUNDLE_DIR}/scripts/check-ec2-env.sh"
cp "${ROOT_DIR}/scripts/check-aws-audio-pipeline.sh" "${BUNDLE_DIR}/scripts/check-aws-audio-pipeline.sh"
cp "${ROOT_DIR}/scripts/ecr-login.sh" "${BUNDLE_DIR}/scripts/ecr-login.sh"
cp "${ROOT_DIR}/scripts/deploy-ec2.sh" "${BUNDLE_DIR}/scripts/deploy-ec2.sh"
cp "${ROOT_DIR}/scripts/smoke_test_attempt_flow.py" "${BUNDLE_DIR}/scripts/smoke_test_attempt_flow.py"
cp "${ROOT_DIR}/scripts/lib/common.sh" "${BUNDLE_DIR}/scripts/lib/common.sh"

# Strip macOS AppleDouble sidecars if they were created while assembling the bundle.
find "${BUNDLE_DIR}" -name '._*' -delete

cat > "${BUNDLE_DIR}/README.md" <<'EOF'
# EC2 Docker Deploy Bundle

This bundle is meant to be copied to the EC2 host without cloning the repo.

Files:
- `docker-compose.proxy.yml`
- `docker-compose.ec2.yml`
- `.env.ec2`
- `scripts/check-ec2-host.sh`
- `scripts/check-ec2-env.sh`
- `scripts/check-aws-audio-pipeline.sh`
- `scripts/ecr-login.sh`
- `scripts/deploy-ec2.sh`
- `scripts/smoke_test_attempt_flow.py`

Recommended order on the EC2 host:

```bash
sh scripts/check-ec2-host.sh .env.ec2
docker compose --env-file .env.ec2 -f docker-compose.proxy.yml up -d
sh scripts/check-ec2-env.sh .env.ec2
sh scripts/check-aws-audio-pipeline.sh .env.ec2
sh scripts/ecr-login.sh .env.ec2
sh scripts/deploy-ec2.sh .env.ec2
python3 scripts/smoke_test_attempt_flow.py --base-url https://apicz.hadoo.eu
docker compose --env-file .env.ec2 -f docker-compose.ec2.yml ps
docker compose --env-file .env.ec2 -f docker-compose.ec2.yml logs --tail=100
```

Public health checks:

```bash
curl -I https://apicz.hadoo.eu/healthz
curl -I https://cmscz.hadoo.eu/api/healthz
```

Rollback:
- edit `.env.ec2`
- change `IMAGE_TAG` back to the previous release
- rerun `sh scripts/deploy-ec2.sh .env.ec2`
EOF

COPYFILE_DISABLE=1 tar -C "${DIST_DIR}" -czf "${ARCHIVE_PATH}" "ec2-deploy"

echo "Created ${ARCHIVE_PATH}"
