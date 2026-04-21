SHELL := /bin/zsh

RTK := rtk
GO_DIR := backend
CMS_DIR := cms
FLUTTER_DIR := flutter_app
FLUTTER := /Users/daniel.dev/tools/flutter/bin/flutter
DART := /Users/daniel.dev/tools/flutter/bin/dart
IOS_DEVICE ?= iPhone 17 Pro Max

.PHONY: help install install-cms install-flutter \
	backend-run backend-build backend-test backend-fmt \
	cms-dev cms-build cms-lint \
	flutter-analyze flutter-test flutter-run-ios flutter-devices flutter-format \
	dev-backend dev-cms dev-ios dev-check dev-stop-backend dev-stop-cms dev-stop \
	graph-status verify clean

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
	@echo "  make flutter-devices  - List Flutter devices"
	@echo "  make dev-backend      - Start the Go API for local development"
	@echo "  make dev-cms          - Start the CMS dev server"
	@echo "  make dev-ios          - Start the Flutter learner app on iOS"
	@echo "  make dev-check        - Check backend and CMS local URLs"
	@echo "  make dev-stop-backend - Stop the local backend process on :8080"
	@echo "  make dev-stop-cms     - Stop the local CMS process on :3000"
	@echo "  make dev-stop         - Stop backend and CMS local dev servers"
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
	cd $(FLUTTER_DIR) && $(RTK) $(FLUTTER) run -d "$(IOS_DEVICE)"

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
