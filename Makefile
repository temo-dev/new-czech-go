SHELL := /bin/zsh

RTK := rtk
GO_DIR := backend
CMS_DIR := cms
FLUTTER_DIR := flutter_app
FLUTTER := /Users/daniel.dev/tools/flutter/bin/flutter
DART := /Users/daniel.dev/tools/flutter/bin/dart
IOS_DEVICE ?= iPhone 17 Pro Max
EC2_ENV_FILE ?= .env.ec2
SMOKE_BASE_URL ?= http://localhost:8080
SMOKE_ATTEMPT_ARGS ?=
SMOKE_AUDIO_FILE ?=

.PHONY: help install install-cms install-flutter \
	backend-run backend-build backend-test backend-fmt \
	cms-dev cms-build cms-lint \
	flutter-analyze flutter-test flutter-run-ios flutter-build-ipa flutter-devices flutter-format \
	dev-backend dev-cms dev-ios dev-check dev-stop-backend dev-stop-cms dev-stop \
	compose-build compose-up compose-down compose-logs compose-config compose-proxy-config \
	compose-proxy-up compose-proxy-down compose-proxy-logs compose-ec2-config \
	compose-ec2-pull compose-ec2-up compose-ec2-down compose-ec2-logs release-images ecr-login check-ec2-env \
	check-ec2-host check-aws-audio-pipeline package-ec2-deploy smoke-attempt-flow \
	smoke-course-flow smoke-exam-flow smoke-all \
	seed-modelovy-test-2 graph-status verify clean

help:
	@echo "Available targets:"
	@echo "  make install          - Install CMS and Flutter dependencies"
	@echo "  make backend-run      - Run the Go API on :8080"
	@echo "  make backend-build    - Build the Go backend"
	@echo "  make backend-test     - Run Go tests"
	@echo "  make cms-dev          - Start Next.js CMS in dev mode"
	@echo "  make cms-build        - Build the CMS"
	@echo "  make cms-lint         - Lint the CMS"
	@echo "  make flutter-analyze  - Run Flutter static analysis"
	@echo "  make flutter-test     - Run Flutter tests"
	@echo "  make flutter-run-ios  - Run the learner app on iOS (set IOS_DEVICE if needed)"
	@echo "  make flutter-build-ipa - Build release IPA pointed at EC2 (https://apicz.hadoo.eu)"
	@echo "  make flutter-devices  - List Flutter devices"
	@echo "  make dev-backend      - Start the Go API for local development"
	@echo "  make dev-cms          - Start the CMS dev server"
	@echo "  make dev-ios          - Start the Flutter learner app on iOS"
	@echo "  make dev-check        - Check backend and CMS local URLs"
	@echo "  make dev-stop-backend - Stop the local backend process on :8080"
	@echo "  make dev-stop-cms     - Stop the local CMS process on :3000"
	@echo "  make dev-stop         - Stop backend and CMS local dev servers"
	@echo "  make compose-build    - Build backend and CMS Docker images"
	@echo "  make compose-up       - Start backend, CMS, and Postgres via docker compose"
	@echo "  make compose-down     - Stop the docker compose stack"
	@echo "  make compose-logs     - Tail docker compose logs"
	@echo "  make compose-config   - Render the resolved docker compose config"
	@echo "  make compose-proxy-config - Render the EC2 nginx-proxy bootstrap stack"
	@echo "  make compose-proxy-up - Start nginx-proxy and acme-companion on EC2"
	@echo "  make compose-proxy-down - Stop the EC2 proxy stack"
	@echo "  make compose-proxy-logs - Tail logs for the EC2 proxy stack"
	@echo "  make compose-ec2-config - Render the EC2 nginx-proxy compose config"
	@echo "  make compose-ec2-pull - Pull EC2 deployment images using EC2_ENV_FILE"
	@echo "  make compose-ec2-up   - Deploy or refresh the EC2 nginx-proxy app stack"
	@echo "  make compose-ec2-down - Stop the EC2 nginx-proxy app stack"
	@echo "  make compose-ec2-logs - Tail logs for the EC2 nginx-proxy app stack"
	@echo "  make release-images   - Build and push versioned backend and CMS images"
	@echo "  make ecr-login        - Log Docker into ECR using EC2_ENV_FILE"
	@echo "  make check-ec2-env    - Validate the EC2 env file and print deploy warnings"
	@echo "  make check-ec2-host   - Validate Docker/AWS/proxy readiness on the EC2 host"
	@echo "  make check-aws-audio-pipeline - Check AWS identity plus S3/Transcribe access from the EC2 env"
	@echo "  make package-ec2-deploy - Create a tar.gz deploy bundle for EC2 without git"
	@echo "  make smoke-attempt-flow - Run the API-level learner smoke test against SMOKE_BASE_URL"
	@echo "                            Add --require-real-transcript in SMOKE_ATTEMPT_ARGS to fail when the backend still returns synthetic transcript data"
	@echo "  make smoke-course-flow  - Smoke test course browsing: login → courses → modules → skills → exercises"
	@echo "  make smoke-exam-flow    - Smoke test mock exam session: create → submit all sections → complete → verify score"
	@echo "  make smoke-all          - Run all three smoke tests in sequence"
	@echo "  make graph-status     - Show whether the local code-review graph database exists"
	@echo "  make verify           - Run backend build, CMS lint/build, Flutter analyze/test"

install: install-cms install-flutter

install-cms:
	cd $(CMS_DIR) && $(RTK) npm install

install-flutter:
	cd $(FLUTTER_DIR) && $(RTK) $(FLUTTER) pub get

backend-run:
	cd $(GO_DIR) && $(RTK) go run ./cmd/api

backend-build:
	cd $(GO_DIR) && $(RTK) go build ./...

backend-test:
	cd $(GO_DIR) && $(RTK) go test ./...

backend-fmt:
	cd $(GO_DIR) && $(RTK) gofmt -w $$(find . -name '*.go' -type f)

cms-dev:
	cd $(CMS_DIR) && $(RTK) npm run dev

cms-build:
	cd $(CMS_DIR) && $(RTK) npm run build

cms-lint:
	cd $(CMS_DIR) && $(RTK) npm run lint

flutter-analyze:
	cd $(FLUTTER_DIR) && $(RTK) $(FLUTTER) analyze

flutter-test:
	cd $(FLUTTER_DIR) && $(RTK) $(FLUTTER) test

flutter-run-ios:
	cd $(FLUTTER_DIR) && $(RTK) $(FLUTTER) run -d "$(IOS_DEVICE)" \
		--dart-define=API_BASE_URL=$(API_BASE_URL) \
		--dart-define=SIMLI_API_KEY=$(SIMLI_API_KEY) \
		--dart-define=SIMLI_FACE_ID=$(SIMLI_FACE_ID)

flutter-build-ipa:
	cd $(FLUTTER_DIR) && $(RTK) $(FLUTTER) build ipa \
		--dart-define=API_BASE_URL=https://apicz.hadoo.eu \
		--dart-define=SIMLI_API_KEY=$(SIMLI_API_KEY) \
		--dart-define=SIMLI_FACE_ID=$(SIMLI_FACE_ID) \
		--release

flutter-devices:
	cd $(FLUTTER_DIR) && $(RTK) $(FLUTTER) devices

flutter-format:
	cd $(FLUTTER_DIR) && $(RTK) $(DART) format lib test

dev-backend: backend-run

dev-cms: cms-dev

dev-ios: flutter-run-ios

dev-check:
	$(RTK) curl -s http://localhost:8080/healthz
	$(RTK) curl -I http://localhost:3000

dev-stop-backend:
	@pids=`$(RTK) lsof -ti tcp:8080`; \
	if [ -n "$$pids" ]; then \
		echo "Stopping backend on :8080 ($$pids)"; \
		$(RTK) kill $$pids; \
	else \
		echo "No backend process found on :8080"; \
	fi

dev-stop-cms:
	@pids=`$(RTK) lsof -ti tcp:3000`; \
	if [ -n "$$pids" ]; then \
		echo "Stopping CMS on :3000 ($$pids)"; \
		$(RTK) kill $$pids; \
	else \
		echo "No CMS process found on :3000"; \
	fi

dev-stop: dev-stop-cms dev-stop-backend

compose-build:
	$(RTK) docker compose build

compose-up:
	$(RTK) docker compose up --build -d

compose-down:
	$(RTK) docker compose down

compose-logs:
	$(RTK) docker compose logs -f --tail=100

compose-config:
	$(RTK) docker compose config

compose-proxy-config:
	$(RTK) docker compose --env-file $(EC2_ENV_FILE) -f docker-compose.proxy.yml config

compose-proxy-up:
	$(RTK) docker compose --env-file $(EC2_ENV_FILE) -f docker-compose.proxy.yml up -d

compose-proxy-down:
	$(RTK) docker compose --env-file $(EC2_ENV_FILE) -f docker-compose.proxy.yml down

compose-proxy-logs:
	$(RTK) docker compose --env-file $(EC2_ENV_FILE) -f docker-compose.proxy.yml logs -f --tail=100

compose-ec2-config:
	$(RTK) docker compose --env-file $(EC2_ENV_FILE) -f docker-compose.ec2.yml config

compose-ec2-pull:
	$(RTK) docker compose --env-file $(EC2_ENV_FILE) -f docker-compose.ec2.yml pull

compose-ec2-up:
	$(RTK) sh scripts/deploy-ec2.sh $(EC2_ENV_FILE)

compose-ec2-down:
	$(RTK) docker compose --env-file $(EC2_ENV_FILE) -f docker-compose.ec2.yml down

compose-ec2-logs:
	$(RTK) docker compose --env-file $(EC2_ENV_FILE) -f docker-compose.ec2.yml logs -f --tail=100

release-images:
	ENV_FILE=$(EC2_ENV_FILE) $(RTK) sh scripts/build-push-images.sh

ecr-login:
	$(RTK) sh scripts/ecr-login.sh $(EC2_ENV_FILE)

check-ec2-env:
	$(RTK) sh scripts/check-ec2-env.sh $(EC2_ENV_FILE)

check-ec2-host:
	$(RTK) sh scripts/check-ec2-host.sh $(EC2_ENV_FILE)

check-aws-audio-pipeline:
	$(RTK) sh scripts/check-aws-audio-pipeline.sh $(EC2_ENV_FILE)

package-ec2-deploy:
	$(RTK) sh scripts/package-ec2-deploy.sh $(EC2_ENV_FILE)

smoke-attempt-flow:
	$(RTK) python3 scripts/smoke_test_attempt_flow.py --base-url $(SMOKE_BASE_URL) $(SMOKE_ATTEMPT_ARGS)

smoke-course-flow:
	$(RTK) python3 scripts/smoke_course_flow.py --base-url $(SMOKE_BASE_URL)

smoke-exam-flow:
	$(RTK) python3 scripts/smoke_exam_flow.py --base-url $(SMOKE_BASE_URL) $(if $(SMOKE_AUDIO_FILE),--audio-file $(SMOKE_AUDIO_FILE),)

smoke-all: smoke-attempt-flow smoke-course-flow smoke-exam-flow

seed-modelovy-test-2:
	$(RTK) python3 scripts/seed-modelovy-test-2.py

graph-status:
	@if [ -f .code-review-graph/graph.db ]; then \
		echo "code-review-graph database present at .code-review-graph/graph.db"; \
	else \
		echo "code-review-graph database not found"; \
	fi

verify: backend-build cms-lint cms-build flutter-analyze flutter-test

clean:
	cd $(CMS_DIR) && $(RTK) rm -rf .next
	cd $(FLUTTER_DIR) && $(RTK) $(FLUTTER) clean
