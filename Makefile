# Convenience wrapper around docker compose. Run `make help` for a summary.

.DEFAULT_GOAL := help

help: ## List available targets
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | awk -F ':.*## ' '{printf "  %-12s %s\n", $$1, $$2}'

setup: ## One-time: create .env from the template
	@test -f .env || (cp .env.example .env && echo "Created .env — edit it to add your HF_TOKEN.")

build: setup ## Build the image (uses cached layers)
	docker compose build

up: setup ## Start the UI at http://localhost:8675
	docker compose up -d
	@echo "UI: http://localhost:$${UI_PORT:-8675}"

down: ## Stop the container
	docker compose down

logs: ## Follow container logs
	docker compose logs -f

shell: ## Open a shell inside the running container
	docker compose exec ai-toolkit bash

upgrade: setup ## Re-clone ai-toolkit at AI_TOOLKIT_REF and restart (deps re-resolve too)
	CACHEBUST=$$(date +%s) docker compose build
	docker compose up -d

version: ## Show the exact ai-toolkit commit baked into the image
	docker compose run --rm --no-deps --entrypoint cat ai-toolkit /app/ai-toolkit-commit.txt

gpu-check: ## Verify the container sees the GPU and torch has CUDA
	docker compose run --rm --entrypoint "" ai-toolkit \
		python -c "import torch; print('torch', torch.__version__, '| cuda available:', torch.cuda.is_available(), '|', torch.cuda.get_device_name(0) if torch.cuda.is_available() else '-')"

.PHONY: help setup build up down logs shell upgrade version gpu-check
