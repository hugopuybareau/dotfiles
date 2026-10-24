# Dotfiles

Here are my dotfiles, I will be adding to it and explaining along the way.

A journey begins.

## Setup/

### One-shot (fresh Mac)

Paste this in Terminal — it installs Homebrew + git, clones the repo (HTTPS), and runs `make setup`:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
  && eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)" \
  && brew install git \
  && git clone https://github.com/maxmaxou2/dotfiles.git ~/dotfiles \
  && cd ~/dotfiles \
  && make setup
```

### Breakdown (idempotent, re-running is safe)

From inside the cloned repo (`~/dotfiles`):

```
make setup
```

This runs `make xcode-clt`, `make brew`, `make stow`, and `make stay-alert` (see [Makefile](Makefile) for all targets).

### HomeBrew
```
ln -s ~/dotfiles/.Brewfile ~/.Brewfile
brew bundle --global
```

### Symlinks
```
stow conda hammerspoon karabiner nvim pdb rich ssh tmux zsh clang-format opencode
```

### stay-alert (notifications for Claude Code & opencode)
```
git clone git@github.com:maxmaxou2/stay-alert.git ~/src/stay-alert
make -C ~/src/stay-alert setup
```

`make setup` in stay-alert does `bun link` (puts `stay-alert` on PATH) and `stay-alert init` (installs Claude Code hooks, opencode plugin, and compiles the Swift focus helper).

### context-mode (token-saving routing for Claude Code & opencode)
```
make context-mode      # npm install -g context-mode
make verify-symlinks   # sanity-check ~/.claude/* and opencode.json symlinks
```

- Claude Code: enabled via `enabledPlugins["context-mode@context-mode"]` in `claude/.claude/settings.json` + `SessionStart` hook `context-mode-cache-heal.mjs`.
- opencode: registered via `plugin: ["context-mode"]` in `opencode/.config/opencode/opencode.json`. Plugin is loaded in-process — no MCP entry needed.
- Marketplace `mksglu/context-mode` is declared under `extraKnownMarketplaces` in claude settings; install/update of the Claude plugin itself: `/plugin marketplace add mksglu/context-mode && /plugin install context-mode@context-mode`.

### agentmemory (persistent cross-session memory for Claude Code & opencode)
```
make agentmemory       # npm install -g @agentmemory/agentmemory, launchd autostart, claude plugin
make verify-symlinks
```

Persistent memory that auto-captures sessions/tools and recalls context into future sessions. A local REST server runs on `http://localhost:3111` (viewer: `http://localhost:3113`).

- **Server**: `make agentmemory` installs the `@agentmemory/agentmemory` npm package and loads `agentmemory/ai.agentmemory.plist` into `~/Library/LaunchAgents` so the server autostarts at login (`KeepAlive`).
- **Provider keys**: on a fresh machine `agentmemory init` seeds `~/.agentmemory/.env`. Fill in the LLM + embeddings keys there — this file holds secrets and is **not** committed. Verify with `agentmemory status` (Provider/Embeddings should be ✓).
- **Claude Code**: marketplace `rohitg00/agentmemory` is declared under `extraKnownMarketplaces` and enabled via `enabledPlugins["agentmemory@agentmemory"]` in `claude/.claude/settings.json`. The plugin registers 12 hooks, 8 skills, and auto-wires the `@agentmemory/mcp` server via its own `.mcp.json` — **no manual `mcpServers` entry needed**. `make agentmemory` runs `claude plugin marketplace add rohitg00/agentmemory && claude plugin install agentmemory@agentmemory`; if the CLI step fails, run `/plugin install agentmemory` inside Claude Code.
- **opencode**: wired declaratively in `opencode/.config/opencode/opencode.json` — manual `mcp.agentmemory` entry (opencode does NOT auto-wire MCP) plus `plugin: ["./plugins/agentmemory-capture.ts"]`. The plugin (`plugins/agentmemory-capture.ts`, 22 auto-capture hooks) and `/recall`+`/remember` commands (`commands/`) are stowed by the `opencode` package via `make stow`.
- Verify: `curl http://localhost:3111/agentmemory/health` and `agentmemory status`.
- **MCP shim**: set `AGENTMEMORY_URL=http://localhost:3111` and `AGENTMEMORY_FORCE_PROXY=1` in `~/.agentmemory/.env` so the MCP server (Claude Code `memory_*` tools, opencode `/recall`) **always proxies to the daemon** instead of silently falling back to a throwaway standalone db when the daemon was briefly down at shim start.
- **LLM compression** (optional, richer summaries) is routed through a LiteLLM proxy → Vertex/Gemini — see next section.

### LiteLLM → Vertex AI (Gemini) for agentmemory compression
```
make litellm
```

agentmemory's `AGENTMEMORY_AUTO_COMPRESS` runs an LLM on observations for richer memories. agentmemory has **no native Vertex support** (its Gemini path only hits AI Studio), so a local **LiteLLM** proxy bridges it: agentmemory speaks OpenAI → LiteLLM → Vertex AI (Gemini 2.5 Flash) using a GCP **service account**, billed to the `jayn-dev` project / `europe-west4`.

```
agentmemory ──OpenAI API──▶ LiteLLM (localhost:4000) ──SA auth──▶ Vertex AI / Gemini 2.5 Flash
```

- **Install/run**: `make litellm` installs the proxy via `uv` (with `google-cloud-aiplatform` + `google-auth`) and loads `litellm/ai.litellm.plist` into `~/Library/LaunchAgents` (autostart, `KeepAlive`).
- **Config**: committed template `litellm/config.yaml.example` → copy to `~/.config/litellm/config.yaml`. The real config holds the `master_key` and is **gitignored** (so is `*-sa.json`).
- **Secrets (manual on a fresh machine, never committed):**
  1. Place the Vertex service-account JSON at `~/.config/litellm/vertex-sa.json` (`chmod 600`).
  2. Set `master_key` + `vertex_credentials` path in `~/.config/litellm/config.yaml`.
  3. Point agentmemory at it in `~/.agentmemory/.env`:
     ```
     OPENAI_API_KEY=<the litellm master_key>
     OPENAI_BASE_URL=http://localhost:4000
     OPENAI_MODEL=gemini-flash
     EMBEDDING_PROVIDER=openai          # route embeddings through litellm too
     OPENAI_EMBEDDING_MODEL=vertex-embed
     OPENAI_EMBEDDING_DIMENSIONS=768
     AGENTMEMORY_AUTO_COMPRESS=true
     MAX_TOKENS=1024
     ```
  4. Restart: `launchctl kickstart -k gui/$(id -u)/ai.agentmemory`.
- **Why these choices**: `reasoning_effort: disable` (Gemini 2.5 thinking wastes output tokens on compression); both LLM (`gemini-2.5-flash`) and embeddings (`gemini-embedding-2`, top MTEB, 768-dim) run on Vertex credits.
- **Embedding-2 quirk**: it's **global-endpoint only** (`vertex_location: global`) — 404s on a regional location like `europe-west4`.
- **Switching embedding provider/dims after data exists** crashes the worker (`persisted vector index has wrong dimension`). Recovery: add `AGENTMEMORY_DROP_STALE_INDEX=true` to `~/.agentmemory/.env`, restart, then remove the line (rebuilds from live observations).
- **Verify**: `curl http://localhost:4000/health/liveliness` → 200; live test:
  `KEY=$(grep master_key ~/.config/litellm/config.yaml | sed -E 's/.*: *//'); curl -s localhost:4000/v1/chat/completions -H "Authorization: Bearer $KEY" -H 'Content-Type: application/json' -d '{"model":"gemini-flash","messages":[{"role":"user","content":"ping"}],"max_tokens":50}'`

### Backups (restic → Hetzner Storage Box)
```
make backup              # restic, launcher, ~/.config/restic skeleton, hourly launchd job
restic-backup init       # once per machine, creates the encrypted repository
caffeinate -i restic-backup   # first full upload, keeps the Mac awake
```

`backup/restic-backup.sh` backs up `$HOME` every hour and, once a week, prunes old
snapshots and downloads 5% of the repository to verify it. Snapshots are kept hourly
for 2 days, daily for 2 weeks, weekly for 2 months and monthly for a year, counted
from the latest snapshot so a Mac that sits closed for weeks keeps its history.
What is skipped is in `backup/excludes.txt`: `~/Library`, toolchains, package caches,
`node_modules`/`.venv`, anything tagged `CACHEDIR.TAG`, and logs.

- **Nothing secret is committed.** `~/.config/restic/` (mode 700) holds `env`
  (repository, fixed host name, healthchecks URLs; template in `backup/env.example`),
  `password` (generated by `make backup`) and `excludes.local` (personal paths). The
  storage box login is a `Host storagebox-backup` block in `~/.ssh/config` with its own
  key, `~/.ssh/id_ed25519_storagebox`.
- **The repository password is the one thing that must outlive the Mac.** Keep a copy
  in a password manager; without it the backup cannot be decrypted.
- **Full Disk Access** goes to `~/.local/bin/restic-backup-launcher`, a small C
  program that launchd starts instead of the script. macOS charges a launchd job's
  file reads to the job's own binary, so the grant lives on the launcher and survives
  restic upgrades. Without it the job cannot read Desktop, Documents or Downloads.
- **Alerts** come from healthchecks.io by email: no successful backup for 3 days, or
  no successful maintenance for 9. A failed run is only logged there, since a laptop
  is often offline. restic's exit code 3 (some files unreadable, typically a lost
  Full Disk Access grant) counts as a failure.
- Logs: `~/.local/state/restic-backup/` (`backup.log`, `maintain.log`, `history.log`).

Restore:
```
restic-backup snapshots
restic-backup restore latest --target /tmp/restore --include "$HOME/src/some-repo"
restic-backup mount /tmp/restic        # browse every snapshot (needs macFUSE)
```

Adding a Mac (each machine gets its own Storage Box sub-account, repository and password):

1. Storage Box owner, Hetzner Console: create a sub-account with its own folder, SSH
   support and external reachability on, not read-only.
2. New Mac: FileVault on, then `make backup` from a clone of this repo (not `make setup`).
   The clone must stay where it is: the launchd job runs the script from it.
3. Grant Full Disk Access to `~/.local/bin/restic-backup-launcher`; save
   `~/.config/restic/password` in a password manager.
4. `ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519_storagebox`, and add to `~/.ssh/config`:
   ```
   Host storagebox-backup
     HostName uXXXXXX-subN.your-storagebox.de
     User uXXXXXX-subN
     Port 23
     IdentityFile ~/.ssh/id_ed25519_storagebox
     IdentitiesOnly yes
     ServerAliveInterval 60
     ServerAliveCountMax 240
   ```
5. Install the key: `cat ~/.ssh/id_ed25519_storagebox.pub | ssh storagebox-backup install-ssh-key`
   (asks for the sub-account password). Only accept the host key if its fingerprint is
   one Hetzner publishes; for ED25519 that is `SHA256:XqONwb1S0zuj5A1CDxpOSuD2hnAArV1A3wKY7Z3sdgM`.
6. Fill `~/.config/restic/env`: `RESTIC_HOST` and two healthchecks.io checks (backup:
   period 1 day, grace 2 days; maintenance: period 7 days, grace 2 days).
7. `restic-backup init`, then preview what would be uploaded and add personal paths to
   skip to `~/.config/restic/excludes.local`:
   ```
   restic-backup backup "$HOME" --dry-run -vv --one-file-system --exclude-caches \
     --exclude-file backup/excludes.txt --exclude-file ~/.config/restic/excludes.local
   ```
8. `caffeinate -i restic-backup` for the first full upload (mains power, lid open), and
   only then `make backup` again to schedule the hourly job, so the first hourly run
   does not start a second full upload alongside it.

### Additional steps

- Karabiner :
    - Open Karabiner-Elements from your Applications folder.
    - Grant necessary permissions in System Preferences > Security & Privacy (Input Monitoring and Accessibility). 

- Postgres related :
```
createuser --superuser $USER -U postgres
createdb $USER -U $USER
```


## Todo List/

- Add scripts calling general commands for setup

## Neovim Configuration

My Neovim setup is designed for a modern development experience with a focus on productivity and ergonomics. Here's a breakdown of the key plugins and their purposes:

### Core Plugins

- **LazyVim** - Plugin manager and configuration framework
- **Catppuccin** - A soothing pastel theme for Neovim
- **Telescope** - Fuzzy finder for files, buffers, and more
  - With `telescope-fzf-native` for better performance
- **Treesitter** - Advanced syntax highlighting and code navigation
  - With `nvim-treesitter-context` for showing code context
  - With `playground` for debugging syntax highlighting
  - With `nvim-treesitter-textobjects` for smart text objects

### LSP and Completion

- **Mason** - Package manager for LSP servers
- **mason-lspconfig** - Auto enabling of mason lsp servers
- **blink-cmp** - Completion engine with blink effect
- **nvim-lspconfig** - Native LSP configuration
- **conform** - Formatter plugin, lightweight yet powerful

### Navigation and Editing

- **Harpoon2** - Quick file navigation between frequently used files
- **Leap** - Quick motion plugin for faster navigation
- **nvim-surround** - Easy text surrounding operations
- **nvim-autopairs** - Automatic bracket pairing
- **nvim-ufo** - Modern folding experience
- **vim-tmux-navigator** - Seamless navigation between Vim and tmux splits

### Development Tools

- **vim-test** - Testing support
- **avante.nvim** - AI-powered coding assistant

### Quality of Life

- **bigfile** - Better handling of large files
- **yeet** - Quick file operations
- **persistence** - Session management
- **vim-be-good** - Neovim training game
- **cellular-automaton** - Fun animations

### Special Features

- **Azerty Layout Support** - Custom configuration for AZERTY keyboard layout
- **Custom Keymaps** - Personalized key mappings for improved workflow

This configuration is continuously evolving as I discover new tools and better ways to work with Neovim. Feel free to explore and adapt any parts that you find useful!

## Hammerspoon Configuration/

My Hammerspoon setup includes several productivity-enhancing features:

### Key Logger
- Displays active key presses in real-time
- Toggle with `ctrl + cmd + k`
- Useful for presentations and debugging keyboard inputs
- Cycles through predefined positions before disabling

### Application Quick Launch
- Fast application switching using keyboard shortcuts
- Mapped to `ctrl + cmd + [number]`
- Common applications mapped to numbers (7,8,9, etc.)
- Provides instant access to frequently used applications
- Application window maximization (fake fullscreen) using ctrl + cmd + F

### Multi-Display Management
- Intelligent window management for multiple displays
- Automatically saves window positions when disconnecting external monitors
- Restores window layouts when reconnecting displays
- Screen swapping functionality with `ctrl + cmd + m`
- Maintains application workspace consistency across different display configurations

This setup ensures a smooth workflow when transitioning between single and multi-monitor setups while providing quick access to applications and keyboard input visualization when needed.

## Keymap Cheatsheet

### Neovim Keymaps

#### General
- `<Space>` - Leader key
- `<leader>e` - Open file explorer (Ex)
- `<C-s>` - Save file (works in normal, insert, and visual modes)

#### Window Management
- `<C-Up/Down/Left/Right>` - Resize windows
- `<C-w>q` or `<C-w><C-q>` - Close split and navigate left (Tmux aware)
- `<leader>gd` - Open definition in vertical split
- `<leader>gg` - Open references in vertical split
- `<leader>gr` - Open LSP references in vertical split

#### Clipboard Operations
- `<leader>y` - Copy to system clipboard
- `<leader>Y` - Copy line to system clipboard (from cursor to end)
- `<leader>yy` - Copy whole line to system clipboard
- `<leader>p` - Paste from system clipboard
- `<leader>P` - Paste before from system clipboard
- `<leader>yp` - Copy full file path to clipboard
- `<leader>yn` - Copy filename to clipboard
- `<leader>yd` - Copy parent directory path to clipboard

#### Navigation
- `<C-d>` - Scroll down (centered)
- `<C-u>` - Scroll up (centered)
- `<C-j>` - Go down a pane (Tmux aware)
- `<C-k>` - Go up a pane (Tmux aware)
- `<C-h>` - Go left a pane (Tmux aware)
- `<C-l>` - Go right a pane (Tmux aware)

#### Indentation
- `<S-Tab>` - Unindent (normal and insert mode)
- `<Tab>` - Indent (visual mode)
- `<S-Tab>` - Unindent (visual mode)

#### Development
- `<leader>bp` - Insert Python breakpoint
- `<leader>bd` - Insert Dagster debugger breakpoint
- `<leader>T` - Launch nearest test, test file or test class
- `<leader>S` - Launch nearest test, test file or test class while updating snapshots

#### Telescope (Fuzzy Finder)
- `<C-p>` - Find files (git files if in repo, all files otherwise)
- `<leader>ps` - Grep with input prompt
- `<leader>pf` - Live grep
- `<leader>w` - Fuzzy find in current buffer
- `gr` - Find LSP references
- `gd` - Go to LSP definition
- `<leader>gr` - Go to LSP references in a new v-split
- `<leader>gd` - Go to LSP definition in a new v-split

#### Diffview
- `<leader>dv` - Opens up telescope git branches listing and show diffview for the selected, quit diffview if already opened
- `<leader>df` - Toggles file tree display

### Hammerspoon Keymaps

#### Window Management
- `ctrl + cmd + F` - Make focused window fullscreen (custom fullscreen)

#### Application Management
- `ctrl + cmd + k` - Toggle key logger display
- `ctrl + cmd + m` - Screen swapping functionality

Note: Additional Hammerspoon keybindings for application quick launch (ctrl + cmd + [number]) are configured but not explicitly listed in the configuration files.

This cheatsheet will be continuously updated as new keymaps are added to my configuration.
