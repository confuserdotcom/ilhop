<!-- GSD:project-start source:PROJECT.md -->

## Project

**ilhop**

`ilhop` is a keyboard-driven screen-hop layer for [input-leap](https://github.com/input-leap/input-leap)
on Wayland. One chord moves the pointer and keyboard focus between a Linux box
and a Mac, in both directions, and the window-focus keys hop automatically when
you run out of windows in that direction. It exists because input-leap's own
keyboard screen-switching does not work on Wayland at all.

Today it is ~457 lines of shell and C living loose in `~/.local/bin/il-*` on one
machine. This project turns it into `ilhop`: a named, installable, documented
thing with its bugs killed.

**Core Value:** Pressing the hop key always lands you on the other machine, ready to type, with
no lost keystroke and no wedged input device.

Everything else — packaging, docs, adapters, upstreaming — is negotiable. That
one sentence is not.

### Constraints

- **Verification**: No input-path change ships without the author physically at
  the keyboard — This project already broke its own input once by shipping
  unverified reasoning. Every phase touching key or pointer injection gates on a
  human keypress.
- **Testability**: `ydotool` key events relay to the Mac but do **not** fire
  Hyprland keybinds (verified: 0 fires even with control local), and
  `il-heldmods` excludes ydotool's own device by design — Keybind paths cannot be
  simulated at all. Test by calling scripts directly, by reading Mac modifier
  flags with `modstate`, and by driving real `aerospace workspace` switches. A
  flag read alone is not proof.
- **Tech stack**: POSIX shell plus one small C helper; no runtime beyond
  `ydotool`, `systemd --user`, and ssh — It has to install on a stranger's box
  without dragging a language runtime along.
- **Compositor coupling**: The Ryoku Hyprland fork replaces `hyprctl dispatch`
  with a Lua API (`hl.dsp.*`); plain `hyprctl dispatch movecursor` fails with a
  parse error — Every compositor call is fork-specific today. Isolating them is
  what makes v2's adapters possible, so v1 should not scatter new ones.
- **Log level**: `input-leap-server.service` must run `--debug INFO`, never
  `DEBUG` — At DEBUG it emits ~4487 journal lines/minute of motion events, and
  `il-side-watch` follows that journal.
- **Latency budget**: The hop must stay under ~50ms in both directions — 700ms
  was the original implementation and the author rejected it as laggy. Awaiting
  journald confirmation (~450ms) in the hot path is the specific thing that must
  never come back.
<!-- GSD:project-end -->

<!-- GSD:stack-start source:codebase/STACK.md -->

## Technology Stack

## Languages

- Lua - All Neovim configuration and plugin specification (in `~/.config/nvim/` and `~/.config/nvim-code/`)
- Shell (Fish) - Primary interactive shell, system automation, and personal scripts
- LaTeX - Document preparation and mathematical typesetting (via TeX Live)
- Bash - System scripts and compatibility (in `~/cleanup.sh`, `~/.bashrc`)
- Python - General-purpose scripting and package management (system package)
- JavaScript/TypeScript - Web development and editor integrations (via Node.js ecosystem)
- JSON - Configuration files and package manifests
- TOML - Configuration format for multiple tools
- YAML - Configuration for various services

## Runtime

- Fish 3.x - Primary shell (installed via pacman, configured in `~/.config/fish/`)
- Bash - Secondary shell (for system scripts and SSH compatibility)
- Neovim 0.9+ - Primary editor runtime (Lua VM embedded)
- Python 3.x - System Python (installed via pacman, version 3.11 wrapper in `~/.local/bin/`)
- Node.js - JavaScript runtime (installed via pacman, `npm` configured)
- Bun - JavaScript runtime (installed, state in `~/.bun/`)
- Rust runtime (via Cargo, CARGO_INSTALL_ROOT set to `~/.local/`)
- Go runtime (GOBIN set to `~/.local/bin/`, `go install` targets)
- npm (Node.js package manager) - Configured to global prefix `~/.local/` (see `~/.npmrc`)
- pipx - Python package installer (sandboxed, used for spotdl)
- pip - Python package manager (system via python-pip)
- pacman - Arch Linux package manager (system packages)
- yay - AUR helper (Rust-based, used for community packages)
- Cargo - Rust package manager (installed packages go to `~/.local/bin/`)
- Lockfiles: `lazy-lock.json` (Neovim plugins in `~/.config/nvim/` and `~/.config/nvim-code/`)

## Frameworks

- LazyVim (Neovim IDE starter) - Provides sensible defaults and plugin ecosystem (in `~/.config/nvim/`)
- lazy.nvim - Neovim plugin manager with lazy-loading (bootstrapped in `init.lua`)
- Lua (embedded in Neovim) - Configuration language for all editor extensions
- Hyprland - Wayland window manager (configured in `~/.config/hypr/`, Lua config)
- Ryoku - Desktop environment framework built on Hyprland (installed via pacman as `ryoku-desktop`)
- QuickShell - QML-based shell surface system for widgets and UI (configured in `~/.config/quickshell/`)
- Matugen - Color scheme generator for theming (configured in `~/.config/matugen/`)
- Kitty - GPU-based terminal emulator (configured in `~/.config/kitty/`)
- Starship - Cross-shell prompt (initialized in `config.fish`, installed via pacman)
- Zoxide - Directory jumper with frecency (initialized in `config.fish`)
- VimTeX - Full LaTeX editing suite for Neovim (plugin in `~/.config/nvim/`, uses `latexmk`)
- latexmk - LaTeX build automation (configured in `~/.latexmkrc`, uses LuaLaTeX by default)
- TeX Live - Full LaTeX distribution (installed via pacman as `texlive-meta`)
- Neotest - Test runner framework for Neovim (plugin, supports Go/Python/Ruby)
- neotest-golang - Go test adapter
- neotest-python - Python test adapter
- neotest-rspec - Ruby RSpec adapter
- Mason - LSP and tool manager for Neovim (auto-installs servers via plugin)
- Conform - Code formatter (integrates multiple formatters via plugin)
- Stylua - Lua formatter (configured in `stylua.toml`)
- mise - Runtime version manager for multiple languages (installed via pacman, initialized in `config.fish`)

## Key Dependencies

- nvim-cmp - Completion engine (plugin)
- LuaSnip - Snippet engine with Lua-based snippets (plugin)
- Telescope - Fuzzy finder with multiple sources (plugin)
- Neo-tree - File explorer (plugin)
- Harpoon - Quick file/location jumping (plugin)
- Gitsigns - Git diff signs in gutter (plugin)
- Lualine - Statusline (plugin)
- BufferLine - Buffer tabs UI (plugin)
- Which-key - Keymap help and organization (plugin)
- texlab - LaTeX LSP server (installed via Mason)
- ltex-ls - Grammar and spelling checker (installed via Mason)
- pyright - Python LSP (installed via Mason)
- rust-analyzer - Rust LSP (installed via Mason)
- gopls - Go LSP (installed via Mason)
- clangd - C/C++ LSP (installed via Mason)
- lua-language-server - Lua LSP (installed via Mason)
- typescript-language-server - JavaScript/TypeScript LSP (installed via Mason)
- stylua - Lua formatter (installed via pacman)
- prettier - JavaScript/TypeScript formatter
- black - Python formatter
- shfmt - Shell script formatter
- git - Version control (installed via pacman, configured as bare repo in `~/.dotfiles/`)
- lazygit - Git TUI client (installed via pacman, launched from Neovim)
- github-cli - GitHub command-line tool (installed via pacman)
- fd - Fast file finder (installed via pacman, used by Telescope)
- ripgrep - Fast text search (installed via pacman, used by Telescope and other tools)
- fzf - Fuzzy finder (installed via pacman, initialized in `config.fish`)
- eza - Modern `ls` replacement (installed via pacman)
- bat - Cat clone with syntax highlighting (installed via pacman)
- btop - System monitor (installed via pacman)
- yt-dlp - Video downloader (installed via pacman)
- mpd (Music Player Daemon) - Backend daemon for music playback (installed via pacman)
- ncmpcpp - TUI music client for mpd (installed via pacman)
- spotdl - Spotify to local music downloader (installed via pipx)
- spotify-launcher - Spotify native client (installed via pacman)
- spicetify-cli - Spotify customization tool (installed via pacman)
- mpv - Video player (installed via pacman)
- rsync - File sync tool (installed via pacman, used in shell aliases)
- syncthing - Continuous file synchronization (installed via pacman)
- Tailscale - VPN networking (installed via pacman, used for Mac connectivity)
- Input Leap - Multi-machine input sharing (installed via pacman, managed as systemd service)
- copi - Clipboard sync between machines (binary in `/home/nastralis/copi`, managed as systemd service)
- Obsidian - Notes application (installed via pacman, vault at `~/notes/`)
- Obsidian.nvim - Obsidian integration plugin for Neovim
- Copilot.lua - GitHub Copilot integration (plugin)
- CopilotChat.nvim - Copilot chat interface (plugin)
- GitHub Copilot - AI code completion (integrated via copilot.lua plugin)
- jq - JSON query tool (installed via pacman)
- tree - Directory tree display (installed via pacman)
- lsof - List open files (installed via pacman)
- curl - HTTP client (installed via pacman)
- ffmpeg - Media converter (installed via pacman)
- imagemagick - Image processing (installed via pacman)
- tesseract - OCR engine (installed via pacman)

## Configuration

- Entry point: `~/.config/nvim/init.lua` (loads lazy.nvim and `config.lazy`)
- Plugin specifications: `~/.config/nvim/lua/plugins/*.lua` (24+ plugin spec files)
- Configuration modules: `~/.config/nvim/lua/config/` (options, keymaps, autocmds)
- LaTeX snippets: `~/.config/nvim/lua/snippets/tex/` (200+ Lua-defined snippets)
- Plugin lockfile: `~/.config/nvim/lazy-lock.json`
- Main config: `~/.config/hypr/hyprland.lua` (Lua-based config)
- Settings: `~/.config/hypr/settings.lua`, `~/.config/hypr/keyboard.lua`, `~/.config/hypr/monitors.lua`
- User overrides: `~/.config/hypr/user.lua` (never shipped, survives updates)
- Reload: `hyprctl reload`
- Fish config: `~/.config/fish/config.fish` (main configuration)
- User overrides: `~/.config/fish/user.fish` (custom aliases and functions, never shipped)
- Prompt: `~/.config/starship.toml` (Starship prompt configuration)
- Reload: Open new shell or `source ~/.config/fish/config.fish`
- Latexmk config: `~/.latexmkrc` (LuaLaTeX by default, synctex enabled, 8 parallel processes)
- TeX Live: System-wide installation (installed via `texlive-meta` pacman package)
- PDF output: `.out/` directory (configurable per project via latexmkrc)
- npm global prefix: `~/.local/` (configured in `~/.npmrc`)
- Cargo install root: `~/.local/` (env var `CARGO_INSTALL_ROOT` in `config.fish`)
- Go install bin: `~/.local/bin/` (env var `GOBIN` in `config.fish`)
- Pipx virtual environments: `~/.local/share/pipx/venvs/`

## Environment Variables

- `EDITOR` = `nvim` (default editor)
- `VISUAL` = `nvim` (visual editor)
- `GOBIN` = `~/.local/bin` (Go install target)
- `CARGO_INSTALL_ROOT` = `~/.local` (Rust install target)
- `FZF_DEFAULT_COMMAND` = `fd --hidden --follow --exclude .git` (fzf file search)
- `FZF_CTRL_T_COMMAND` = same as above (Ctrl-T file picker)
- `FZF_ALT_C_COMMAND` = `fd --type d --hidden --follow --exclude .git` (Alt-C directory picker)
- `NVIM_APPNAME` = `nvim` (default) or `nvim-code` (via aliases `nvl`/`nvc`)
- `SSH_CONNECTION` - Used to detect SSH sessions and auto-attach tmux

## Platform Requirements

- Arch Linux (rolling release, kernel 7.2.3+)
- Intel CPU (GPU = Intel Iris Xe via i915 driver)
- Hyprland 0.x (Wayland window manager, not X11)
- Neovim 0.9+ (with Lua 5.1 embedded)
- TeX Live or MacTeX (for LaTeX workflows)
- Git 2.x
- Fish 3.x shell
- `latexmk` - LaTeX build automation (formula-triggered via `<leader>lc`)
- `fd` - File finder (required by fzf and Telescope)
- `ripgrep` - Text search (required by Telescope live grep)
- `detex` - LaTeX text extraction (for word count)
- Inkscape - SVG editor (for figure creation workflow)
- Sioyek - PDF viewer with synctex support (launches via `open` command)
- `spotdl` - Music downloader (already installed via pipx)
- `mpd` - Music daemon (installed via pacman, listens on `~/.config/mpd/socket`)
- macOS 12+ (for remote work via Tailscale SSH)
- Network connectivity to Tailscale VPN (for multi-machine workflows)
- Input Leap server/client for keyboard/mouse sharing
- Copi daemon for clipboard sync

<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->

## Conventions

## Naming Patterns

- Filenames: lowercase with hyphens (e.g., `notify-stop.sh`, `config-reload.sh`, `cleanup.sh`)
- Functions: snake_case for internal functions (e.g., `line()`, `present=()`)
- Variables: UPPERCASE for constants and arrays (e.g., `PKGS=()`, `HOME`)
- Local vars: lowercase with underscores for loop counters and temporaries (e.g., `present`, `orphans`, `root`)
- Aliases: lowercase with hyphens (e.g., `copi-status`, `input-leap-server`, `fishconfig`)
- Functions: lowercase with hyphens and double-dash naming (e.g., `push`, `pull`, `openon`, `mmac`)
- Descriptive long-form flags with `--` (e.g., `--description`, `--progress`)
- Nested variable references use camelCase: `SSH_CONNECTION`, `TMUX`
- Module names: lowercase with underscores, reflect file structure (e.g., `modules.env`, `modules.displays`, `modules.binds`)
- Functions: camelCase in library calls (e.g., `hl.monitor()`, `hl.config()`, `hl.env()`)
- Local helper functions: snake_case (e.g., `optional()`)
- Callback parameters: Follow Hyprland naming (e.g., `mod`, `key`, `output`)
- Module names: camelCase within modules, kebab-case for file exports (e.g., `gsd-ensure-canonical-path.js`)
- Constants: UPPERCASE_WITH_UNDERSCORES (e.g., `MANAGED_SUBDIRS`, `KIMI_TOOL_NAMES`, `ON_CRASH`)
- Functions: camelCase (e.g., `resolveConfigDir()`, `resolveBundledTree()`, `createDirLink()`)
- Local vars: camelCase (e.g., `envDir`, `bundledReal`, `canonicalDir`)
- Maps/Objects: Use for namespace avoidance (e.g., `const KIMI_TOOL_NAMES = new Map()`)
- Boolean predicates: prefix with `is` or use past-tense verb (e.g., `isDirectory()`, `linkPointsAt()`)
- Keys: camelCase in nested objects, descriptive (e.g., `inputOnly`, `provider`, `pluginKind`)
- Collections: plural nouns (e.g., `hosts`, `tags`, `metadata`)
- IDs: kebab-case (e.g., `hancore-kanso`, `plugin-id`)

## Code Style

- Bash: 4-space soft indentation (observed in `cleanup.sh`)
- Fish: 4-space soft indentation (observed in `user.fish`)
- Lua: 2-space soft indentation (configured in `stylua.toml` for Neovim configs)
- JavaScript: 2-space soft indentation (observed in hook files)
- No tabs anywhere
- Bash: Uses `set -uo pipefail` for strict error handling (mandatory in scripts)
- No explicit ESLint/Prettier configs in this home directory (uses defaults where tools exist)
- Lua: Uses `stylua` for Neovim configs (2-space, 120-char line width in `stylua.toml`)
- Bash: ~80 characters (observed in `notify-stop.sh`, `config-reload.sh`)
- Lua: 120 characters (configured in `stylua.toml`)
- JavaScript: ~80-100 characters typical (observed in hook files)

## Import Organization

- Shebang line first: `#!/usr/bin/env bash`
- Comments and metadata before logic
- `source` directives for sourcing other files minimal (each script is standalone)
- Comments and section headers at top
- `set` directives for environment setup
- `alias` definitions grouped by category (e.g., Editor, Navigation, Config, Services)
- Functions defined after aliases
- `require()` statements grouped by layer:
- Path order: `modules.*` → optional hardware (`gpu`, `monitors`) → optional overrides (`user.lua`)
- `const fs = require('fs')` style for Node modules
- `const { func } = require('./module.js')` for destructuring exports
- CommonJS `require()` for backward compatibility
- Comments describe integration points and security considerations

## Error Handling

- `set -uo pipefail` at top of every script (strict mode)
- `[ -n "$var" ]` checks before dereference
- `||` fallback patterns: `cmd || true`, `cmd || echo "message"`
- Exit codes explicit: `exit 0`, `exit 1`, `exit 2`
- Command substitution wrapped: `$(cmd 2>/dev/null)` suppresses errors
- Explicit condition checks: `test (count $argv) -gt 0; or begin ... end`
- Error messages to stderr: `>&2` redirection
- Return codes: `return 2` for usage errors
- `pcall()` wrapping for optional modules: catches load errors without crashing
- Print error messages via `print()` for config errors (observed in `hyprland.lua`)
- Graceful degradation when modules fail: "degrade, but say so"
- `try/catch` blocks around I/O operations (e.g., `fs.realpathSync()`, `fs.mkdirSync()`)
- Error objects returned in structured results (e.g., `{status: 'error', reason: 'message'}`)
- File existence checks via `fs.statSync()` with try-wrap
- `null` returns for "not found" vs exceptions for true failures

## Logging

- `printf` with color codes for section headers: `printf '\n\033[1;36m==== %s ====\033[0m\n'`
- Plain `echo` for status messages
- Command output piped to files or shown to user
- Execution step announcements before each step (e.g., "1/5 REMOVE UNUSED PACKAGES")
- `echo` to stdout for normal messages
- `>&2` redirection for error messages
- Description strings in function definitions (e.g., `--description 'rsync files to the Mac'`)
- `print()` for user-facing errors in config loading
- Comments document state and transitions (e.g., "load order" explaining require sequence)
- No dedicated logging framework
- `console.log()` for test output (e.g., "PASS", "FAIL" in calendar.test.mjs)
- Return structured result objects with `status`, `reason`, action arrays (linked, prunedStale, preserved, skipped)
- Comments document preconditions and security boundaries extensively

## Comments

- Bash: Explain non-obvious conditions, command purpose (observed in `cleanup.sh`)
- Fish: Describe function purpose and usage via `--description`
- Lua: Explain load order, failure modes, user-owned vs generated files
- JavaScript: Document security implications, edge cases, data transformations
- Bash: `# Single-line comments`
- Lua: `-- Single-line` or `-- ──── Section headers with dividers ────`
- JavaScript: `// Single-line` or `/* Multi-line for security/design notes */`
- Lua section dividers: `-- ──────────────────────────────────────────` with readable spacing
- Bash: Comments above functions explain purpose
- Lua: Inline comments explain why (e.g., "optional() because updates never repair user files")
- JavaScript: JSDoc-style blocks for exported functions with `@param`, `@returns` (observed in gsd-ensure-canonical-path.js)

## Function Design

- Minimal parameters (use global state sparingly)
- Return via exit codes or stdout capture
- Error propagation via `|| true` or exit handling
- Example: `line()` function takes single string argument, prints formatted output
- Function receives arguments array `$argv`
- Explicit argument count check: `test (count $argv) -gt 0`
- Returns exit code 2 for usage errors
- Local variables via `set -l varname`
- Example: `push` function validates args then calls `rsync`
- Pure functions where possible (e.g., `optional()` just attempts require and returns silently)
- Callback-style configuration (pass tables to library functions)
- No explicit return of errors; graceful degradation via `pcall`
- Dependency injection pattern for testability: `function(opts = {})` with destructuring
- Pure functions return structured result objects: `{status, reason, ...actionArrays}`
- Immutability: never mutate input parameters
- Example: `ensureCanonicalPath(opts)` returns `{status, canonicalDir, linked, prunedStale, preserved, skipped}`

## Module Design

- Each script is standalone (no shared library imports)
- Comments at top document purpose and preconditions
- `config.fish` is loaded at startup; `user.fish` is user-customized
- Aliases and functions defined in `user.fish` for personal tooling
- No explicit module system (shell-level only)
- Hyprland modules follow pattern: `require("modules.X")` for mandatory, `optional("X")` for conditional
- User-owned files never overwritten by updates (documented in load order comments)
- Settings/preferences written by hub at runtime, loaded before user.lua so user wins
- Modules export via `module.exports = { func1, func2, ... }`
- Hooks structured as CLI entry (if `require.main === module`) with pure core function
- Pure core function dependency-injected: `function(opts = {homeDir, env, platform, ...})`
- Test-friendly: exports both pure function AND CLI wrapper

## Module Patterns

- None (each script self-contained)
- Each command is a separate function with `--description`
- No global state mutation (use local `set -l`)
- Plugin specs in separate files under `lua/plugins/`
- Config modules in `lua/config/`
- Snippet definitions in `lua/snippets/<language>/`
- Shared utilities in `shared.lua` per language
- Core logic in pure function (testable)
- CLI wrapper via `if (require.main === module) { ... }`
- Exports struct: `module.exports = { coreFunc, helperFunc, CONSTANT }`

## Error Codes

- `0`: Success
- `1`: General error
- `2`: Usage/argument error (observed in Fish functions)
- `0`: Success, allow hook
- `1`: Block/error condition
- Exit codes returned via `allow()` or `crash()` helpers from `lib/hook-exit.js`

## Patterns

- Bash: `[ -z "$var" ]` before use, `|| true` for optional commands
- Fish: `test` conditions before dereference
- Lua: `pcall()` for risky requires
- JavaScript: Try-catch for I/O, explicit null checks before dereferencing
- Bash: Exit immediately on strict conditions (`set -uo pipefail`)
- Lua: Return early from `optional()` if module missing
- JavaScript: `if (!condition) return earlyValue`
- Bash: Print section headers, show before/after state (e.g., disk usage)
- JavaScript: Structured result objects track what happened (linked, skipped, preserved)

<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->

## Architecture

## System Overview

```text

```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| Hyprland | Window manager, layout, keybinds, monitors, animations | `~/.config/hypr/hyprland.lua` |
| Quickshell/QS Bar | Desktop shell surfaces (bar, sidebar, launcher, dock) | `~/.config/quickshell/` |
| Neovim (LazyVim) | Primary text editor with Lua config and lazy plugins | `~/.config/nvim/init.lua` |
| Neovim (Code) | Secondary editor instance via NVIM_APPNAME nvim-code | `~/.config/nvim-code/` |
| Fish shell | Primary interactive shell with REPL, completions, aliases | `~/.config/fish/config.fish`, `user.fish` |
| Zsh | Secondary shell, used as login shell | `~/.zshrc` |
| Ryoku system map | Declarative registry of all config paths and reload commands | `~/.local/share/ryoku/rashin/desktop.md` |
| Claude Code hooks | Post-Write/Edit hooks to reload changed subsystems immediately | `~/.claude/hooks/config-reload.sh` |
| Obsidian SUP vault | Personal knowledge base (MPSI course notes) | `~/SUP/.obsidian/`, `.obsidian.vimrc` |
| GSD core system | Project workflow automation, skills, phase planning | `~/.claude/gsd-core/` |

## Pattern Overview

- **Declarative config first** - all system state lives in config files under `~/.config/` and `~/.local/share/ryoku/rashin/`
- **Automated reload loops** - PostToolUse hooks in `~/.claude/hooks/` detect file changes and reload the owning subsystem immediately (`hyprctl reload`, `ryoku reload`)
- **Single source of truth** - Ryoku system map (`desktop.md`) documents every config path, its owner binary, and the reload command
- **Explicit subsystem contracts** - each tool (Hyprland, Quickshell, Neovim, Fish) owns its config subtree and responds to standardized reload commands

## Layers

- Purpose: Detects file changes and triggers subsystem reloads; manages GSD workflows
- Location: `~/.claude/hooks/`, `~/.claude/gsd-core/`
- Contains: Shell scripts (config-reload.sh), Node.js hooks (gsd-*.js), GSD agents and skills
- Depends on: All config layers (watches for file changes)
- Used by: Claude Code IDE, developers working on configs
- Purpose: Owns the configuration state for each subsystem; reloads on demand
- Location: `~/.config/hypr/`, `~/.config/quickshell/`, `~/.config/nvim/`, `~/.config/fish/`, `~/.config/ryoku/`, etc.
- Contains: Lua configs (Hyprland), JSON/QML (Quickshell), Lua (Neovim), Fish shell functions, TOML (Ryoku theme)
- Depends on: System Foundation (references reload commands, reads from rashin/)
- Used by: Each respective application (Hyprland, Shell daemon, Neovim, Fish)
- Purpose: Maintains the declarative registry of system structure; tracks hardware, packages, user divergences
- Location: `~/.local/share/ryoku/rashin/`
- Contains: `desktop.md` (config ownership map), `AGENTS.md` (rules for agents), `packages.md` (installed packages), `system.md` (hardware info), `user.md` (user-specific changes), `memory/` (durable notes), `journal/` (dated notes)
- Depends on: Ryoku system binaries (pacman, hyprctl, etc. for reindexing)
- Used by: All agents and tools (read-first before filesystem exploration)

## Data Flow

### Primary Config Reload Path

- `~/.claude/hooks/config-reload.sh:12-21` — pattern matching and reload dispatch

### Shell Startup Path

- `~/.zshrc` — Zsh initialization
- `~/.config/fish/config.fish` — Fish shell entry point
- `~/.config/fish/user.fish` — User-specific fish functions/aliases

### Desktop Initialization Path

- `~/.config/hypr/hyprland.lua` — Hyprland main config
- `~/.config/hypr/monitors.lua` — Monitor setup
- `~/.config/hypr/user.lua` — User-specific overrides (never edit shipped files)
- `~/.config/quickshell/` — Shell surfaces (bar, launcher, sidebar)

### Knowledge & System State Flow

- `~/.local/share/ryoku/rashin/AGENTS.md` — rules and indexed file locations
- `~/.local/share/ryoku/rashin/desktop.md` — config ownership registry (regenerated)
- `~/.local/share/ryoku/rashin/user.md` — user-specific changes (regenerated)
- `~/.local/share/ryoku/rashin/memory/` — durable notes across sessions
- Hyprland state: in-memory (window layout, workspace, keybind state)
- Shell state: environment variables (`$EDITOR=nvim`, `$PATH`), aliases, functions in-memory
- Config state: files on disk, reloaded on-demand
- Knowledge state: system map on disk (`rashin/`), read by every agent before acting

## Key Abstractions

- Purpose: Single source of truth for "where do I find X and how do I reload it"
- Examples: `~/.local/share/ryoku/rashin/desktop.md`, `AGENTS.md`, `user.md`
- Pattern: Read-only generated files (content between markers is overwritten), prose outside markers is kept. Agents check `user.md` to never revert user changes.
- Purpose: Standardized, immediate feedback from config edits
- Examples: `hyprctl reload` (Hyprland), `ryoku reload` (Quickshell), `open new shell` (Fish)
- Pattern: PostToolUse hook detects config file path and dispatches the appropriate reload command
- Purpose: Each tool owns a subtree under `~/.config/`; user overrides live in `user.lua`, `user.fish`, etc.
- Examples: `~/.config/hypr/user.lua` (Hyprland overrides), `~/.config/fish/user.fish` (Fish overrides), `~/.config/ryoku/user_edits/` (Ryoku divergences)
- Pattern: Main shipped config imports/sources user variants; user files always survive reindex
- Purpose: Obsidian vault for learning (MPSI course notes)
- Examples: `~/SUP/` with `.obsidian.vimrc` for Vim Motions plugin
- Pattern: Markdown files, Obsidian config in `.obsidian/`, auto-synced via Syncthing

## Entry Points

- Location: `~/.zshrc`, `~/.config/fish/config.fish`
- Triggers: Opening a new terminal
- Responsibilities: Set environment (EDITOR, PATH), load aliases, source tex-workflow if available
- Location: `~/.config/hypr/hyprland.lua`
- Triggers: Display manager login or Hyprland startup
- Responsibilities: Initialize window manager, load monitor config, start Quickshell, apply theme
- Location: `~/.config/nvim/init.lua`
- Triggers: Running `nvim` or `v` command
- Responsibilities: Load LazyVim plugins, apply user settings, initialize LSP
- Location: `~/.claude/hooks/config-reload.sh`
- Triggers: PostToolUse Write or Edit event from Claude Code
- Responsibilities: Detect changed config file, dispatch subsystem reload

## Architectural Constraints

- **Declarative over imperative** — configs describe desired state; Hyprland/Quickshell/Neovim own the imperative reload
- **Read-only system map** — `rashin/` content between markers is regenerated; durable notes go to `memory/` or `journal/`
- **User divergences never reverted** — `user.md` lists user changes; agents check it before reverting to defaults
- **Immediate reload feedback** — config edit triggers subsystem reload within seconds (not batch or delayed)
- **No direct shipped-file edits** — Hyprland/Quickshell configs should not be edited directly; use `ryoku` commands for safe changes
- **Single editor instance per config tree** — `nvim` → `~/.config/nvim/`, `nvim-code` (via NVIM_APPNAME) → `~/.config/nvim-code/`

## Anti-Patterns

### Editing Shipped Hyprland/Quickshell Files Directly

```bash

```

### Editing System Map Files Between Generated Markers

### Triggering Reloads Manually After Config Edits

### Searching the Filesystem Without Reading rashin/

## Error Handling

- Shell startup errors: logged to .zsh_history or terminal output; user must fix syntax errors manually
- Hyprland syntax errors: `hyprctl reload` outputs error; Hyprland keeps previous valid state
- Quickshell load failures: shell daemon exits and must be restarted; hook attempts `setsid -f ryoku reload` or nohup fallback
- Missing config files: subsystems use hardcoded defaults (no crash)

## Cross-Cutting Concerns

<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->

## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, `.github/skills/`, or `.codex/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->

## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:

- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->

<!-- GSD:profile-start -->

## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
