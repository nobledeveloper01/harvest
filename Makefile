# Harvest — the targets CI runs, so local and CI cannot disagree.

FLUTTER ?= flutter
APP     := app

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) \
	  | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

# --- the gate ---------------------------------------------------------------

.PHONY: ci
ci: doc-check palette-check audio-check picture-check analyze test coverage-gate ## Everything CI runs

.PHONY: gates
gates: doc-check palette-check audio-check picture-check coverage-gate ## The blocking gates alone. These never go yellow.

.PHONY: palette-check
palette-check: ## Fail if DESIGN.md's palette table disagrees with the theme
	@python3 scripts/palette-check.py

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
domain-purity: ## Fail if the domain layer imports Flutter
	@if grep -rl "package:flutter/" $(APP)/lib/domain 2>/dev/null | grep -q .; then \
	  echo "\033[0;31m✗\033[0m the domain layer imports Flutter:"; \
	  grep -rl "package:flutter/" $(APP)/lib/domain; \
	  echo "  The engines must stay pure Dart — testable without a device,"; \
	  echo "  identical on every platform. See ADR-0002."; \
	  exit 1; \
	fi
	@echo "\033[0;32m✓\033[0m domain layer is pure Dart"

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
