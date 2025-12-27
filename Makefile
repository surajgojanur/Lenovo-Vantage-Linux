.PHONY: install uninstall dry-run lint format check

PREFIX ?= /usr
BINDIR ?= $(PREFIX)/bin
ICONDIR ?= $(PREFIX)/share/icons/hicolor/scalable/apps
DESKTOPDIR ?= $(PREFIX)/share/applications

DRY_RUN ?= 0

define _run
	@if [ "$(DRY_RUN)" = "1" ]; then \
		echo "[DRY-RUN] $1"; \
	else \
		$1; \
	fi
endef

require-root:
	@if [ "$(DRY_RUN)" != "1" ] && [ "`id -u`" -ne 0 ]; then \
		echo "error: install/uninstall requires root (run with sudo)"; exit 1; \
	fi

install: require-root
	@echo "Installing Lenovo Vantage (DRY_RUN=$(DRY_RUN))"
	$(call _run,chmod +x ./install.sh)
	$(call _run,./install.sh $(if $(filter 1,$(DRY_RUN)),--dry-run,))
	$(call _run,install -D -m 0644 ./icon.png "$(ICONDIR)/vantage.png")
	$(call _run,install -D -m 0644 ./vantage.desktop "$(DESKTOPDIR)/vantage.desktop")
	$(call _run,install -D -m 0755 ./vantage.sh "$(BINDIR)/vantage")
	@echo "Install complete."

dry-run:
	@$(MAKE) install DRY_RUN=1

uninstall: require-root
	@echo "Uninstalling Lenovo Vantage (DRY_RUN=$(DRY_RUN))"
	$(call _run,rm -f "$(ICONDIR)/vantage.png")
	$(call _run,rm -f "$(DESKTOPDIR)/vantage.desktop")
	$(call _run,rm -f "$(BINDIR)/vantage")
	@echo "Uninstall complete."

lint:
	@echo "Running ShellCheck"
	@set -e; \
	targets="install.sh vantage.sh"; \
	if compgen -G "scripts/*.sh" > /dev/null; then \
		targets="$$targets scripts/*.sh"; \
	fi; \
	shellcheck $$targets

format:
	@echo "Checking formatting with shfmt"
	shfmt -i 4 -ci -bn -d install.sh vantage.sh scripts

check: lint format
