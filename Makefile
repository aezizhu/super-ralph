.PHONY: test lint install uninstall help version-check

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

version-check: ## Verify version consistency across config files
	@V1=$$(jq -r '.plugins[0].version' .claude-plugin/marketplace.json); \
	V2=$$(jq -r '.version' plugins/super-ralph/.claude-plugin/plugin.json); \
	if [ "$$V1" != "$$V2" ]; then \
		echo "\033[31mVersion mismatch: marketplace.json=$$V1 plugin.json=$$V2\033[0m"; \
		exit 1; \
	fi; \
	echo "\033[32mVersions consistent: $$V1\033[0m"

check: lint test version-check ## Run lint, tests, and version check
