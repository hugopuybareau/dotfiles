.PHONY: help setup xcode-clt brew stow stay-alert context-mode agentmemory litellm backup verify-symlinks

STAY_ALERT_REPO ?= git@github.com:maxmaxou2/stay-alert.git
STAY_ALERT_DIR  ?= $(HOME)/src/stay-alert
STOW_PACKAGES   ?= claude ghostty hammerspoon karabiner micro ssh tmux tmuxp zsh

# /opt/homebrew on Apple Silicon, /usr/local on Intel.
BREW_PREFIX     ?= $(shell brew --prefix 2>/dev/null || echo /opt/homebrew)
# launchd jobs inherit almost nothing, so the plists carry an explicit PATH.
LAUNCHD_PATH    ?= $(HOME)/.local/bin:$(BREW_PREFIX)/bin:/usr/local/bin:/usr/bin:/bin
# Full Disk Access is granted to this exact binary (see backup/launcher.c).
RESTIC_LAUNCHER ?= $(HOME)/.local/bin/restic-backup-launcher

help:
	@echo "Targets:"
	@echo "  setup            Run xcode-clt, brew, stow, stay-alert, context-mode"
	@echo "  xcode-clt        Install Xcode Command Line Tools (provides swiftc) if missing"
	@echo "  brew             Symlink .Brewfile and run brew bundle --global"
	@echo "  stow             Symlink dotfile packages via GNU stow (--restow for idempotency), hermes per-file"
	@echo "  stay-alert       Clone (if missing) and install stay-alert (bun link + init)"
	@echo "  context-mode     Install context-mode globally via npm (opencode plugin + claude hook)"
	@echo "  agentmemory      Install agentmemory (npm), launchd autostart server, claude plugin"
	@echo "  litellm          Install litellm proxy (uv), launchd autostart, Vertex/Gemini for agentmemory compression"
	@echo "  backup           Install restic and schedule the hourly backup of HOME (needs ~/.config/restic/env)"
	@echo "  verify-symlinks  Check that critical claude/opencode configs are symlinked into HOME"

setup: xcode-clt brew stow stay-alert context-mode agentmemory litellm verify-symlinks

xcode-clt:
	@xcode-select -p >/dev/null 2>&1 || xcode-select --install

brew:
	@test -L $(HOME)/.Brewfile || ln -s $(CURDIR)/.Brewfile $(HOME)/.Brewfile
	-brew bundle --global

stow:
	stow --restow $(STOW_PACKAGES)
# per-file links: Hermes finds skills via rglob, which skips symlinked dirs
	stow --restow --no-folding hermes

stay-alert:
	@test -d $(STAY_ALERT_DIR) || git clone $(STAY_ALERT_REPO) $(STAY_ALERT_DIR)
	$(MAKE) -C $(STAY_ALERT_DIR) setup

context-mode:
	@command -v npm >/dev/null 2>&1 || { echo "npm not found — install node first (brew install node)"; exit 1; }
	npm install -g context-mode
	@command -v context-mode >/dev/null 2>&1 && echo "context-mode installed" || echo "context-mode install verify failed"
	@mkdir -p $(HOME)/.config/opencode
	@test -L $(HOME)/.config/opencode/AGENTS.md || ln -sf ../../dotfiles/opencode/.config/opencode/AGENTS.md $(HOME)/.config/opencode/AGENTS.md
	@echo "AGENTS.md symlinked: $$(readlink $(HOME)/.config/opencode/AGENTS.md)"

agentmemory:
	@command -v npm >/dev/null 2>&1 || { echo "npm not found — install node first (brew install node)"; exit 1; }
	npm install -g @agentmemory/agentmemory
	@command -v agentmemory >/dev/null 2>&1 && echo "agentmemory installed" || echo "agentmemory install verify failed"
	@mkdir -p $(HOME)/.agentmemory
	@test -f $(HOME)/.agentmemory/.env || agentmemory init || true
	@echo "NOTE: fill provider keys in ~/.agentmemory/.env (LLM + embeddings) — not committed (secrets)."
	@mkdir -p $(HOME)/Library/LaunchAgents
	@cp $(CURDIR)/agentmemory/ai.agentmemory.plist $(HOME)/Library/LaunchAgents/ai.agentmemory.plist
	@launchctl bootout gui/$$(id -u)/ai.agentmemory 2>/dev/null || true
	@launchctl bootstrap gui/$$(id -u) $(HOME)/Library/LaunchAgents/ai.agentmemory.plist 2>/dev/null || launchctl load $(HOME)/Library/LaunchAgents/ai.agentmemory.plist
	@sleep 1; curl -fsS http://localhost:3111/agentmemory/health >/dev/null 2>&1 && echo "server healthy: http://localhost:3111" || echo "server not responding yet (check ~/.agentmemory/daemon.log)"
	@claude plugin marketplace add rohitg00/agentmemory 2>/dev/null || true
	@claude plugin install agentmemory@agentmemory 2>/dev/null || echo "claude plugin install: run '/plugin install agentmemory' in Claude Code if CLI failed"
	@echo "Claude Code: hooks+skills+MCP via plugin. opencode: plugin+MCP+commands via 'make stow' (opencode package)."

litellm:
	@command -v uv >/dev/null 2>&1 || brew install uv
	uv tool install "litellm[proxy]" --with google-cloud-aiplatform --with google-auth --force
	@mkdir -p $(HOME)/.config/litellm
	@if [ ! -f $(HOME)/.config/litellm/config.yaml ]; then \
		cp $(CURDIR)/litellm/config.yaml.example $(HOME)/.config/litellm/config.yaml; \
		chmod 600 $(HOME)/.config/litellm/config.yaml; \
		echo "ACTION REQUIRED: edit ~/.config/litellm/config.yaml — set master_key + vertex_credentials path,"; \
		echo "                 place the Vertex service-account JSON at ~/.config/litellm/vertex-sa.json (chmod 600),"; \
		echo "                 then set agentmemory ~/.agentmemory/.env: OPENAI_API_KEY=<that master_key>,"; \
		echo "                 OPENAI_BASE_URL=http://localhost:4000, OPENAI_MODEL=gemini-flash,"; \
		echo "                 EMBEDDING_PROVIDER=local, AGENTMEMORY_AUTO_COMPRESS=true, MAX_TOKENS=1024."; \
	else echo "~/.config/litellm/config.yaml exists — leaving as-is"; fi
	@mkdir -p $(HOME)/Library/LaunchAgents
	@cp $(CURDIR)/litellm/ai.litellm.plist $(HOME)/Library/LaunchAgents/ai.litellm.plist
	@launchctl bootout gui/$$(id -u)/ai.litellm 2>/dev/null || true
	@launchctl bootstrap gui/$$(id -u) $(HOME)/Library/LaunchAgents/ai.litellm.plist 2>/dev/null || launchctl load $(HOME)/Library/LaunchAgents/ai.litellm.plist
	@sleep 12; curl -fsS http://localhost:4000/health/liveliness >/dev/null 2>&1 && echo "litellm healthy: http://localhost:4000" || echo "litellm not responding yet (check ~/.config/litellm/litellm.log)"

# Recompiling changes the launcher's code signature, which silently voids its
# Full Disk Access grant, so it is rebuilt only when launcher.c changes.
$(RESTIC_LAUNCHER): backup/launcher.c
	@mkdir -p $(@D)
	cc -O2 -Wall -o $@ $<
	@echo "ACTION REQUIRED: System Settings > Privacy & Security > Full Disk Access > +,"
	@echo "                 then Cmd-Shift-G and paste $@"

# Not part of `setup`: it needs this machine's repository, credentials and
# healthchecks URLs in ~/.config/restic/env, which never live in this repo.
backup: $(RESTIC_LAUNCHER)
	@command -v restic >/dev/null 2>&1 || brew install restic
	@mkdir -p $(HOME)/.config/restic $(HOME)/.local/state/restic-backup $(HOME)/Library/LaunchAgents
	@chmod 700 $(HOME)/.config/restic
	@ln -sf $(CURDIR)/backup/restic-backup.sh $(HOME)/.local/bin/restic-backup
	@touch $(HOME)/.config/restic/excludes.local
	@if [ ! -f $(HOME)/.config/restic/password ]; then \
		(umask 077; openssl rand -base64 32 > $(HOME)/.config/restic/password); \
		echo "ACTION REQUIRED: save ~/.config/restic/password in your password manager."; \
		echo "                 Without it nobody, you included, can decrypt the backup."; \
	fi
	@if [ ! -f $(HOME)/.config/restic/env ]; then \
		(umask 077; cp $(CURDIR)/backup/env.example $(HOME)/.config/restic/env); \
	fi
	@if grep -q REPLACE_ $(HOME)/.config/restic/env; then \
		echo "ACTION REQUIRED: fill in the REPLACE_ values in ~/.config/restic/env, then re-run 'make backup'"; \
		exit 1; \
	fi
	@sed -e "/<!--/,/-->/d" -e "s|@HOME@|$(HOME)|g" -e "s|@PATH@|$(LAUNCHD_PATH)|g" \
		-e "s|@LAUNCHER@|$(RESTIC_LAUNCHER)|g" -e "s|@SCRIPT@|$(CURDIR)/backup/restic-backup.sh|g" \
		$(CURDIR)/backup/local.restic-backup.plist.in > $(HOME)/Library/LaunchAgents/local.restic-backup.plist
	@launchctl bootout gui/$$(id -u)/local.restic-backup 2>/dev/null || true
	@for i in 1 2 3 4 5 6 7 8 9 10; do \
		launchctl print gui/$$(id -u)/local.restic-backup >/dev/null 2>&1 || break; \
		sleep 1; \
	done
	@launchctl bootstrap gui/$$(id -u) $(HOME)/Library/LaunchAgents/local.restic-backup.plist 2>/dev/null || launchctl load $(HOME)/Library/LaunchAgents/local.restic-backup.plist
	@echo "Hourly backup scheduled. First time on this Mac: 'restic-backup init', then 'caffeinate -i restic-backup'."

verify-symlinks:
	@echo "Verifying critical symlinks..."
	@for f in $(HOME)/.claude $(HOME)/.config/opencode $(HOME)/.config/opencode/AGENTS.md $(HOME)/.Brewfile $(HOME)/.hermes/config.yaml; do \
		if [ -L "$$f" ]; then echo "  ok  $$f -> $$(readlink $$f)"; \
		elif [ -e "$$f" ]; then echo "  WARN $$f exists but is NOT a symlink (run 'make stow' after removing real file)"; \
		else echo "  MISS $$f missing"; fi; \
	done
