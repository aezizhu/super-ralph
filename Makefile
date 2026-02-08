.PHONY: test lint install uninstall help

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

test: ## Run all bats tests
	bats tests/

lint: ## Run shellcheck on all bash scripts
	shellcheck -x standalone/lib/*.sh standalone/super_ralph_loop.sh standalone/install.sh plugins/super-ralph/hooks/stop-hook.sh

install: ## Install super-ralph globally
	bash standalone/install.sh

uninstall: ## Uninstall super-ralph
	bash standalone/install.sh uninstall

check: lint test ## Run both lint and tests
