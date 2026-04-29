#!/usr/bin/env bash
# setup-env-ec2.sh — Interactive .env.ec2 generator
# Usage: bash scripts/setup-env-ec2.sh
set -euo pipefail

ENV_FILE=".env.ec2"
EXAMPLE_FILE=".env.ec2.example"

# ── colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'
BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${CYAN}▸ $*${NC}"; }
success() { echo -e "${GREEN}✓ $*${NC}"; }
warn()    { echo -e "${YELLOW}⚠ $*${NC}"; }
header()  { echo -e "\n${BOLD}$*${NC}"; }

# ── helpers ───────────────────────────────────────────────────────────────────
# read existing value from env file (if present)
existing() {
  local key="$1"
  if [ -f "$ENV_FILE" ]; then
    local val
    val=$(grep "^${key}=" "$ENV_FILE" 2>/dev/null | cut -d= -f2- | tr -d '"' || true)
    echo "$val"
  fi
}

# prompt user; use existing value as default if available
ask() {
  local key="$1" prompt="$2" default="${3:-}"
  local cur
  cur=$(existing "$key")
  [ -n "$cur" ] && default="$cur"

  if [ -n "$default" ]; then
    read -r -p "$(echo -e "${BOLD}${prompt}${NC} [${default}]: ")" val
    val="${val:-$default}"
  else
    read -r -p "$(echo -e "${BOLD}${prompt}${NC}: ")" val
    while [ -z "$val" ]; do
      warn "Required — cannot be empty"
      read -r -p "$(echo -e "${BOLD}${prompt}${NC}: ")" val
    done
  fi
  echo "$val"
}

# ask for a secret — mask input; auto-generate if empty
ask_secret() {
  local key="$1" prompt="$2"
  local cur gen
  cur=$(existing "$key")
  gen=$(openssl rand -hex 32 2>/dev/null || python3 -c "import secrets; print(secrets.token_hex(32))")

  if [ -n "$cur" ]; then
    read -r -s -p "$(echo -e "${BOLD}${prompt}${NC} [keep existing, Enter to keep]: ")" val
    echo
    val="${val:-$cur}"
  else
    read -r -s -p "$(echo -e "${BOLD}${prompt}${NC} [Enter = auto-generate]: ")" val
    echo
    val="${val:-$gen}"
  fi
  echo "$val"
}

# generate bcrypt hash interactively
ask_admin_password() {
  local cur
  cur=$(existing "ADMIN_PASSWORD")

  if [ -n "$cur" ] && [[ "$cur" == \$2* ]]; then
    read -r -s -p "$(echo -e "${BOLD}Admin password${NC} [bcrypt hash exists — Enter to keep, or type new password]: ")" val
    echo
    if [ -z "$val" ]; then
      echo "$cur"
      return
    fi
  else
    read -r -s -p "$(echo -e "${BOLD}Admin password${NC} (min 12 chars): ")" val
    echo
    while [ ${#val} -lt 12 ]; do
      warn "Password too short (min 12 chars)"
      read -r -s -p "$(echo -e "${BOLD}Admin password${NC}: ")" val
      echo
    done
  fi

  # Try to hash with available tool
  if command -v python3 >/dev/null && python3 -c "import bcrypt" 2>/dev/null; then
    hash=$(python3 -c "import bcrypt, sys; print(bcrypt.hashpw(sys.argv[1].encode(), bcrypt.gensalt(12)).decode())" "$val")
    info "Bcrypt hash generated (cost=12)"
  elif command -v htpasswd >/dev/null; then
    hash=$(htpasswd -bnBC 12 "" "$val" | tr -d ':\n')
    info "Bcrypt hash generated via htpasswd"
  else
    warn "python3-bcrypt and htpasswd not found — storing plaintext (install bcrypt for production)"
    hash="$val"
  fi
  echo "$hash"
}

# ── start ─────────────────────────────────────────────────────────────────────
echo -e "${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   Czech-Go System — EC2 env setup        ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════╝${NC}"

if [ -f "$ENV_FILE" ]; then
  warn "Existing ${ENV_FILE} found — existing values shown as defaults."
fi

# ── Section 1: AWS / ECR ──────────────────────────────────────────────────────
header "1/7 AWS / ECR"

AWS_REGION=$(ask "AWS_REGION" "AWS region" "eu-central-1")
AWS_ACCOUNT_ID=$(ask "AWS_ACCOUNT_ID" "AWS account ID (12 digits)")
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
IMAGE_PLATFORM=$(ask "IMAGE_PLATFORM" "Docker image platform" "linux/arm64")
IMAGE_TAG=$(ask "IMAGE_TAG" "Release image tag (e.g. 20260429-001)" "$(date +%Y%m%d)-001")

# ── Section 2: Domains ────────────────────────────────────────────────────────
header "2/7 Domains & TLS"

BACKEND_HOST=$(ask "BACKEND_HOST" "Backend public domain (e.g. apicz.hadoo.eu)")
CMS_HOST=$(ask "CMS_HOST" "CMS public domain (e.g. cms.hadoo.eu)")
LE_EMAIL=$(ask "LE_EMAIL" "Let's Encrypt email")
TZ=$(ask "TZ" "Timezone" "Europe/Prague")

# ── Section 3: Database ───────────────────────────────────────────────────────
header "3/7 Database (PostgreSQL / RDS)"
info "Format: postgres://user:pass@host:5432/dbname?sslmode=require"

DATABASE_URL=$(ask "DATABASE_URL" "DATABASE_URL")

# ── Section 4: Admin credentials ─────────────────────────────────────────────
header "4/7 Admin credentials"

ADMIN_EMAIL=$(ask "ADMIN_EMAIL" "Admin email" "admin@example.com")
ADMIN_PASSWORD=$(ask_admin_password)

# ── Section 5: Secrets (auto-generated) ───────────────────────────────────────
header "5/7 Secrets"

AUDIO_SIGN_SECRET=$(ask_secret "AUDIO_SIGN_SECRET" "AUDIO_SIGN_SECRET (random hex)")
success "AUDIO_SIGN_SECRET ready"

CMS_BASIC_AUTH_PASSWORD=$(ask_secret "CMS_BASIC_AUTH_PASSWORD" "CMS basic-auth password (protects /)")
CMS_BASIC_AUTH_USER=$(ask "CMS_BASIC_AUTH_USER" "CMS basic-auth username" "cmsadmin")

# ── Section 6: AI providers ───────────────────────────────────────────────────
header "6/7 AI providers"

ANTHROPIC_API_KEY=$(ask "ANTHROPIC_API_KEY" "Anthropic API key (sk-ant-...)")
LLM_MODEL=$(ask "LLM_MODEL" "Claude model ID (leave blank = default)" "")

# ── Section 7: AWS services ───────────────────────────────────────────────────
header "7/7 AWS services (S3 / Polly / Transcribe)"
info "Leave blank to keep dev/local mode — can update later"

TTS_PROVIDER=$(ask "TTS_PROVIDER" "TTS provider [dev|amazon_polly]" "amazon_polly")
POLLY_VOICE_ID=$(ask "POLLY_VOICE_ID" "Polly primary voice" "Jitka")
POLLY_VOICE_ID_2=$(ask "POLLY_VOICE_ID_2" "Polly secondary voice (dialog exercises)" "Tomas")
POLLY_SAMPLE_RATE=$(ask "POLLY_SAMPLE_RATE" "Polly sample rate Hz" "22050")

TRANSCRIBER_PROVIDER=$(ask "TRANSCRIBER_PROVIDER" "Transcriber [dev|amazon_transcribe]" "amazon_transcribe")
REQUIRE_REAL_TRANSCRIPT=$(ask "REQUIRE_REAL_TRANSCRIPT" "Require real transcript [true|false]" "true")

ATTEMPT_UPLOAD_PROVIDER=$(ask "ATTEMPT_UPLOAD_PROVIDER" "Upload provider [local|s3]" "s3")
ATTEMPT_AUDIO_S3_BUCKET=$(ask "ATTEMPT_AUDIO_S3_BUCKET" "S3 bucket for attempt audio" "")
ATTEMPT_AUDIO_S3_PREFIX=$(ask "ATTEMPT_AUDIO_S3_PREFIX" "S3 prefix" "attempt-audio")
ATTEMPT_UPLOAD_URL_TTL=$(ask "ATTEMPT_UPLOAD_URL_TTL" "Upload URL TTL" "5m")

TRANSCRIBE_OUTPUT_BUCKET=$(ask "TRANSCRIBE_OUTPUT_BUCKET" "S3 bucket for Transcribe output" "$ATTEMPT_AUDIO_S3_BUCKET")
TRANSCRIBE_OUTPUT_PREFIX=$(ask "TRANSCRIBE_OUTPUT_PREFIX" "Transcribe output prefix" "transcribe-output")
TRANSCRIBE_LANGUAGE_CODE=$(ask "TRANSCRIBE_LANGUAGE_CODE" "Transcribe language code" "cs-CZ")
TRANSCRIBE_POLL_INTERVAL=$(ask "TRANSCRIBE_POLL_INTERVAL" "Transcribe poll interval" "5s")
TRANSCRIBE_TIMEOUT=$(ask "TRANSCRIBE_TIMEOUT" "Transcribe timeout" "3m")

# ── Write file ────────────────────────────────────────────────────────────────
# Backup existing if present
[ -f "$ENV_FILE" ] && cp "$ENV_FILE" "${ENV_FILE}.bak.$(date +%Y%m%d%H%M%S)"

cat > "$ENV_FILE" << EOF
COMPOSE_PROJECT_NAME=czech-go-system

# ── Environment ───────────────────────────────────────────────────────────────
ENV=production
TZ=${TZ}

# ── AWS / ECR ─────────────────────────────────────────────────────────────────
AWS_REGION=${AWS_REGION}
AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID}
ECR_REGISTRY=${ECR_REGISTRY}

# ── Docker images ─────────────────────────────────────────────────────────────
BACKEND_IMAGE_REPO=${ECR_REGISTRY}/czech-go-system-backend
CMS_IMAGE_REPO=${ECR_REGISTRY}/czech-go-system-cms
IMAGE_TAG=${IMAGE_TAG}
IMAGE_PLATFORM=${IMAGE_PLATFORM}

# ── Proxy / TLS ───────────────────────────────────────────────────────────────
PROXY_NETWORK=proxy
BACKEND_HOST=${BACKEND_HOST}
CMS_HOST=${CMS_HOST}
LE_EMAIL=${LE_EMAIL}

# ── Database ──────────────────────────────────────────────────────────────────
DATABASE_URL=${DATABASE_URL}

# ── Admin credentials ─────────────────────────────────────────────────────────
ADMIN_EMAIL=${ADMIN_EMAIL}
ADMIN_PASSWORD=${ADMIN_PASSWORD}

# ── Secrets ───────────────────────────────────────────────────────────────────
AUDIO_SIGN_SECRET=${AUDIO_SIGN_SECRET}
CMS_BASIC_AUTH_USER=${CMS_BASIC_AUTH_USER}
CMS_BASIC_AUTH_PASSWORD=${CMS_BASIC_AUTH_PASSWORD}

# ── CMS runtime ───────────────────────────────────────────────────────────────
API_BASE_URL=http://backend:8080
CORS_ALLOWED_ORIGINS=https://${CMS_HOST}

# ── LLM (Claude) ──────────────────────────────────────────────────────────────
LLM_PROVIDER=claude
ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
LLM_MODEL=${LLM_MODEL}

# ── TTS (Polly) ───────────────────────────────────────────────────────────────
TTS_PROVIDER=${TTS_PROVIDER}
POLLY_VOICE_ID=${POLLY_VOICE_ID}
POLLY_VOICE_ID_2=${POLLY_VOICE_ID_2}
POLLY_SAMPLE_RATE=${POLLY_SAMPLE_RATE}

# ── Transcription ─────────────────────────────────────────────────────────────
TRANSCRIBER_PROVIDER=${TRANSCRIBER_PROVIDER}
REQUIRE_REAL_TRANSCRIPT=${REQUIRE_REAL_TRANSCRIPT}
TRANSCRIBE_LANGUAGE_CODE=${TRANSCRIBE_LANGUAGE_CODE}
TRANSCRIBE_POLL_INTERVAL=${TRANSCRIBE_POLL_INTERVAL}
TRANSCRIBE_TIMEOUT=${TRANSCRIBE_TIMEOUT}

# ── S3 audio upload ───────────────────────────────────────────────────────────
ATTEMPT_UPLOAD_PROVIDER=${ATTEMPT_UPLOAD_PROVIDER}
ATTEMPT_AUDIO_S3_BUCKET=${ATTEMPT_AUDIO_S3_BUCKET}
ATTEMPT_AUDIO_S3_PREFIX=${ATTEMPT_AUDIO_S3_PREFIX}
ATTEMPT_UPLOAD_URL_TTL=${ATTEMPT_UPLOAD_URL_TTL}
TRANSCRIBE_OUTPUT_BUCKET=${TRANSCRIBE_OUTPUT_BUCKET}
TRANSCRIBE_OUTPUT_PREFIX=${TRANSCRIBE_OUTPUT_PREFIX}
EOF

chmod 600 "$ENV_FILE"
success "Written ${ENV_FILE} (permissions: 600)"

# ── Validate ──────────────────────────────────────────────────────────────────
echo
header "Validation"
ERRORS=0

check() {
  local val="$1" label="$2"
  if [ -z "$val" ] || [ "$val" = "change-me" ] || [[ "$val" == *"example.com"* && "$label" != *"email"* ]]; then
    warn "MISSING/PLACEHOLDER: ${label}"
    ERRORS=$((ERRORS+1))
  else
    success "${label}"
  fi
}

check "$AWS_ACCOUNT_ID"          "AWS_ACCOUNT_ID"
check "$BACKEND_HOST"            "BACKEND_HOST"
check "$CMS_HOST"                "CMS_HOST"
check "$DATABASE_URL"            "DATABASE_URL"
check "$ADMIN_PASSWORD"          "ADMIN_PASSWORD"
check "$ANTHROPIC_API_KEY"       "ANTHROPIC_API_KEY"
check "$AUDIO_SIGN_SECRET"       "AUDIO_SIGN_SECRET"

if [ "$ATTEMPT_UPLOAD_PROVIDER" = "s3" ] && [ -z "$ATTEMPT_AUDIO_S3_BUCKET" ]; then
  warn "ATTEMPT_AUDIO_S3_BUCKET empty but ATTEMPT_UPLOAD_PROVIDER=s3"
  ERRORS=$((ERRORS+1))
fi

echo
if [ "$ERRORS" -eq 0 ]; then
  success "All checks passed. Run: make check-ec2-env && make release-images && make compose-ec2-up"
else
  warn "${ERRORS} issue(s) found. Edit ${ENV_FILE} then re-run: make check-ec2-env"
  exit 1
fi
