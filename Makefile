# Harvest — the targets CI runs, so local and CI cannot disagree.

FLUTTER ?= flutter
APP     := app
SERVER  := server

# The server's test database. Created once with `createdb harvest_test`; the
# suite migrates it and empties it between runs.
TEST_DATABASE_URL ?= postgres://localhost:5432/harvest_test

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) \
	  | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

# --- the gate ---------------------------------------------------------------

.PHONY: ci
ci: doc-check design-check counts-check audio-check picture-check analyze test coverage-gate server-check ## Everything CI runs

.PHONY: gates
gates: doc-check design-check counts-check audio-check picture-check coverage-gate ## The blocking gates alone. These never go yellow.

.PHONY: design-check
design-check: ## Fail if DESIGN.md disagrees with the theme it documents
	@python3 scripts/design-check.py

.PHONY: counts-check
counts-check: ## Fail if README or RELEASE-GATES quote a figure the code does not produce
	@python3 scripts/counts-check.py

.PHONY: audio-check
audio-check: ## Fail if anything the app says is missing a clip, or is not bundled
	@python3 scripts/audio-check.py

.PHONY: picture-check
picture-check: ## Fail if a crop or unit has no picture, or a picture has nothing using it
	@python3 scripts/picture-check.py

.PHONY: device-check
# The half of Phase 2's exit gate a machine can reach.
#
# A widget test proves the app *decides* to schedule an alert. Only a device
# proves the platform *accepted* the schedule, and nothing at all proves a
# notification arrived three days later — that part is a person with a phone,
# and it stays on the gate.
#
#   make device-check D=<device id>     (flutter devices)
device-check: ## Run the on-device tests:  make device-check D=<device>
	@if [ -z "$(D)" ]; then \
	  echo "\033[0;33m!\033[0m no device given. \`flutter devices\`, then: make device-check D=<id>"; \
	  exit 64; \
	fi
	@echo "\033[0;33m!\033[0m Watch the device: it asks for notification permission once per"
	@echo "  install, and the suite waits for the tap. Without authorisation iOS"
	@echo "  registers no pending requests at all, so the tests would be red for"
	@echo "  a reason that has nothing to do with the code."
	cd $(APP) && $(FLUTTER) test integration_test -d $(D)

.PHONY: speech-budget
speech-budget: ## Print how long the app talks for on the shortest path
	@python3 scripts/speech-budget.py $(L)

.PHONY: placeholders
placeholders: ## Write stand-in clips and tiles for anything not yet made (macOS)
	@python3 scripts/make-placeholders.py

# --- code -------------------------------------------------------------------

.PHONY: setup
setup: ## Install dependencies, and run code generation if any is configured
	cd $(APP) && $(FLUTTER) pub get
	@$(MAKE) --no-print-directory gen

.PHONY: gen
# Guarded, because it was not.
#
# `dart run build_runner build` on a project without build_runner fails with
# "Could not find package `build_runner`" — so `make setup`, the first command
# anybody runs after cloning, ended in an error that says nothing about what to
# do. Drift and Riverpod arrive with lot storage and will bring the generator
# with them; until then there is nothing to generate and the target says so.
gen: ## Re-run code generation (Drift tables, Riverpod providers)
	@if grep -q '^  build_runner:' $(APP)/pubspec.yaml; then \
	  cd $(APP) && dart run build_runner build --delete-conflicting-outputs; \
	else \
	  echo "\033[0;33m!\033[0m nothing to generate — build_runner is not a dependency yet"; \
	fi

.PHONY: analyze
analyze: ## Static analysis, plus the domain-purity check
	cd $(APP) && $(FLUTTER) analyze
	@$(MAKE) --no-print-directory domain-purity

.PHONY: domain-purity
domain-purity: ## Fail if the domain touches the platform, the clock or randomness
	@python3 scripts/domain-purity.py

.PHONY: test
test: ## Run the test suite
	cd $(APP) && $(FLUTTER) test

.PHONY: coverage
coverage: ## Run tests with coverage and print the per-file breakdown
	cd $(APP) && $(FLUTTER) test --coverage
	@python3 scripts/coverage-report.py $(APP)/coverage/lcov.info

.PHONY: coverage-gate
# `/domain/`, not `/domain/services/`.
#
# Grid gates its services directory. Harvest has no services yet — phase 2
# brings `ShelfLifeEngine` — and a gate pointing at a directory that does not
# exist fails with "no matching files", which is a gate that cannot *pass*: the
# mirror of one that cannot fail, and the same temptation to delete it.
#
# The whole domain is gated instead. When services arrives it is already
# covered by this, at the 95% the roadmap asks of the engine.
coverage-gate: ## Fail if the pure-Dart domain drops below 95%
	cd $(APP) && $(FLUTTER) test --coverage >/dev/null
	@python3 scripts/coverage-report.py $(APP)/coverage/lcov.info --gate 95 --only /domain/

.PHONY: server-check
server-check: ## Typecheck and test the server
	@if [ ! -d $(SERVER)/node_modules ]; then \
	  echo "\033[0;33m!\033[0m server dependencies are not installed:  cd server && pnpm install"; \
	else \
	  cd $(SERVER) && pnpm run typecheck && TEST_DATABASE_URL=$(TEST_DATABASE_URL) pnpm run test; \
	fi

.PHONY: server-run
server-run: ## Run the server against the development database
	cd $(SERVER) && DATABASE_URL=postgres://localhost:5432/harvest_dev pnpm run dev

.PHONY: run
run: ## Run on the attached device
	cd $(APP) && $(FLUTTER) run

# --- documentation ----------------------------------------------------------

.PHONY: doc-check
doc-check: ## Verify the documentation is present, well-formed and current
	@scripts/doc-check.sh

.PHONY: adr
adr: ## Scaffold the next ADR:  make adr T="the decision"
	@scripts/new-adr.sh "$(T)"

.PHONY: screenshot
screenshot: ## Capture a booted simulator screen:  make screenshot N=03-quantity
	@if [ -z "$(N)" ]; then \
	  echo "\033[0;33m!\033[0m no name given:  make screenshot N=03-quantity"; \
	  ls docs/screenshots | sed 's/\.png$$//' | sed 's/^/    /'; \
	else \
	  scripts/screenshot.sh "$(N)"; \
	fi

.PHONY: journal
journal: ## Add a session entry:  make journal T="what this session was about"
	@scripts/journal.sh "$(T)"

.PHONY: hooks
hooks: ## Install the git hooks
	@git config core.hooksPath .githooks
	@echo "\033[0;32m✓\033[0m hooks installed (core.hooksPath = .githooks)"

.PHONY: phase
phase: ## Print the current phase and its exit gate
	@p=$$(cat PHASE); \
	echo "Phase $$p"; \
	awk -v want="## Phase $$p" '$$0 ~ want {inside=1} /^## Phase/ && $$0 !~ want {inside=0} inside' docs/ROADMAP.md \
	  | grep -A6 '^\*\*Exit gate\*\*' || true

# --- Docker: reproducible Android builds ------------------------------------
# iOS is deliberately absent — Xcode does not run in a container. See Dockerfile.

.PHONY: docker-verify docker-apk docker-shell

docker-verify: ## analyze + the full suite on the pinned toolchain
	docker compose run --rm verify

docker-apk: ## build/grid-debug.apk, without Flutter installed on the host
	@mkdir -p build
	docker compose run --rm apk

docker-shell: ## a toolchain prompt
	docker compose run --rm shell
