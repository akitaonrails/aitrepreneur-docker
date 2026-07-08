# Convenience wrapper around docker compose. Run `make help` for a summary.
# APP targets: ai-toolkit (default profile), krea2, ideogram, ltx.

.DEFAULT_GOAL := help
COMPOSE = docker compose --profile krea2 --profile ideogram --profile ltx

help: ## List available targets
	@grep -E '^[a-z%-]+:.*##' $(MAKEFILE_LIST) | awk -F ':.*## ' '{printf "  %-18s %s\n", $$1, $$2}'

setup: ## One-time: create .env from the template
	@test -f .env || (cp .env.example .env && echo "Created .env — edit it to add your HF_TOKEN.")

build: setup ## Build every image (cached layers reused)
	$(COMPOSE) build

up: setup ## Start ai-toolkit (training UI) at :8675
	docker compose up -d ai-toolkit

krea2 ideogram ltx: setup ## Start one ComfyUI app (krea2 :8188, ideogram :8189, ltx :8190)
	docker compose --profile $@ up -d $@
	@echo "$@ starting — model downloads happen on first start, follow with: make logs-$@"

down: ## Stop everything
	$(COMPOSE) down

stop-%: ## Stop one service (e.g. make stop-krea2)
	$(COMPOSE) stop $*

logs-%: ## Follow logs of one service (e.g. make logs-krea2)
	$(COMPOSE) logs -f $*

shell-%: ## Shell into a running service (e.g. make shell-ltx)
	$(COMPOSE) exec $* bash

upgrade: setup ## Rebuild all images from fresh upstream clones and restart running ones
	CACHEBUST=$$(date +%s) $(COMPOSE) build
	$(COMPOSE) up -d --no-deps $$(docker compose ps --services 2>/dev/null)

upgrade-%: setup ## Rebuild one app from a fresh clone (e.g. make upgrade-krea2)
	CACHEBUST=$$(date +%s) $(COMPOSE) build $*

version: ## Show upstream commits baked into the images
	@for s in ai-toolkit:/app/ai-toolkit-commit.txt comfyui-krea2:/opt/app/comfyui-commit.txt comfyui-ideogram:/opt/app/comfyui-commit.txt comfyui-ltx:/opt/app/comfyui-commit.txt; do \
	  img="$${s%%:*}:local"; f="$${s#*:}"; \
	  docker image inspect "$$img" >/dev/null 2>&1 && \
	    echo "$$img  $$(docker run --rm --entrypoint cat $$img $$f)" || true; \
	done

gpu-check: ## Verify a container sees the GPU and torch has CUDA
	docker compose run --rm --entrypoint "" ai-toolkit \
		python -c "import torch; print('torch', torch.__version__, '| cuda available:', torch.cuda.is_available(), '|', torch.cuda.get_device_name(0) if torch.cuda.is_available() else '-')"

.PHONY: help setup build up krea2 ideogram ltx down upgrade version gpu-check
