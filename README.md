# dotfiles

Personal terminal and editor configuration — **tmux** + **Neovim** (AstroNvim).

**Theme:** Tokyo Night Storm across both tmux and Neovim.

---

## Contents

| Tool | Description |
|---|---|
| **tmux** | Catppuccin v2 status layout recolored with Tokyo Night Storm palette |
| **Neovim** | AstroNvim v5 with Tokyo Night Storm, git tools, LSP, and formatters |

### Neovim plugins

| Plugin | Purpose |
|---|---|
| [AstroNvim](https://github.com/AstroNvim/AstroNvim) | Base distribution — LSP, completion, telescope, treesitter |
| [folke/tokyonight.nvim](https://github.com/folke/tokyonight.nvim) | Tokyo Night colorscheme (active: Storm) |
| [catppuccin/nvim](https://github.com/catppuccin/nvim) | Catppuccin colorscheme (available; switch in `colorscheme.lua`) |
| [sindrets/diffview.nvim](https://github.com/sindrets/diffview.nvim) | Diff viewer, file history, merge-conflict resolution |
| [kdheepak/lazygit.nvim](https://github.com/kdheepak/lazygit.nvim) | Lazygit TUI inside Neovim |
| [esmuellert/codediff.nvim](https://github.com/esmuellert/codediff.nvim) | VSCode-style side-by-side / inline diff |
| [MeanderingProgrammer/render-markdown.nvim](https://github.com/MeanderingProgrammer/render-markdown.nvim) | In-editor markdown rendering |
| [stevearc/conform.nvim](https://github.com/stevearc/conform.nvim) | Formatter integration (format-on-save) |
| [airblade/vim-rooter](https://github.com/airblade/vim-rooter) | Auto-set cwd to project root |

---

## Dependencies

Dependencies are split into three tiers:

- **Required** — the setup will not work without these
- **Auto-installed** — installed automatically by Mason on first Neovim launch
- **Recommended** — needed for specific formatters/features; noted per-language

### Required (install before running install.sh)

| Dependency | Minimum version | Purpose |
|---|---|---|
| [Neovim](https://neovim.io) | 0.10+ | Editor |
| [tmux](https://github.com/tmux/tmux) | 3.2+ | Terminal multiplexer |
| [Git](https://git-scm.com) | any | Plugin installation, lazy.nvim bootstrap |
| [lazygit](https://github.com/jesseduffield/lazygit) | any | Git TUI (`<Leader>gg`) |
| A [Nerd Font](https://www.nerdfonts.com) | any | Icons in tmux status and Neovim |

### Must be on PATH (not auto-installed by Mason)

These two formatters are expected on your system `PATH`. Mason cannot install them
in environments with private npm registries (corporate proxies, etc.), so they
are managed separately:

| Dependency | Purpose | Install |
|---|---|---|
| [prettier](https://prettier.io) | JSON, Markdown, YAML, HTML, CSS, JS, TS | `brew install prettier` or `npm install -g prettier` |
| [sql-formatter](https://sql-formatter-org.github.io/sql-formatter/) | SQL | `brew install sql-formatter` or `npm install -g sql-formatter` |

> **npm users:** If `npm install -g` fails with an authentication error (corporate
> registry), use `brew install prettier sql-formatter` instead.

### Auto-installed by Mason (on first Neovim launch)

Mason will download and install these automatically. You do not need to install them
manually — but their **language runtimes** must be present:

| Mason package | Language | Runtime required |
|---|---|---|
| `lua-language-server` | Lua LSP | none (self-contained binary) |
| `stylua` | Lua formatter | none (self-contained binary) |
| `black` | Python formatter | **Python 3.8+** |
| `isort` | Python import sorter | **Python 3.8+** |
| `jq` | JSON/JSONL formatter | none (self-contained binary) |
| `clang-format` | C / C++ formatter | **LLVM/clang** |
| `google-java-format` | Java formatter | **Java JDK 11+** |
| `debugpy` | Python debugger | **Python 3.8+** |
| `tree-sitter-cli` | Treesitter parsers | **Node.js 18+** |

#### Runtime install commands

**Python 3.8+**
```bash
# macOS / Linux
brew install python

# Ubuntu/Debian
sudo apt install python3 python3-pip

# Windows
scoop install python  OR  winget install Python.Python.3
```

**Java JDK 11+** (required for `google-java-format`)
```bash
# macOS / Linux
brew install openjdk

# Ubuntu/Debian
sudo apt install default-jdk

# Windows
scoop install openjdk  OR  winget install Microsoft.OpenJDK.21
```

**LLVM/clang** (required for `clang-format`)
```bash
# macOS (clang is already included with Xcode Command Line Tools)
xcode-select --install

# Linux
brew install llvm  OR  sudo apt install clang-format

# Windows
scoop install llvm  OR  winget install LLVM.LLVM
```

**Node.js 18+** (required for `tree-sitter-cli`; also needed for `npm install -g prettier`)
```bash
# macOS / Linux
brew install node

# Ubuntu/Debian
sudo apt install nodejs npm

# Windows
scoop install nodejs  OR  winget install OpenJS.NodeJS
```

---

## Installation

The installer handles **everything** — it installs all dependencies (via Homebrew
on macOS/Linux, Scoop on Windows) and then links the configs.

### macOS / Linux (one command)

```bash
git clone https://github.com/Brandon-Schur/dotfiles.git ~/dotfiles
bash ~/dotfiles/install.sh
```

`install.sh` will:
1. Install Homebrew (if missing)
2. Install core tools: git, tmux, neovim, lazygit
3. Install formatters: prettier, sql-formatter
4. Install language runtimes: python, node, openjdk, llvm/clang
5. Install the JetBrainsMono Nerd Font
6. Link the tmux + Neovim + lazygit configs
7. Install tmux plugins (TPM)

Flags:
```bash
bash ~/dotfiles/install.sh --no-deps     # link configs only, skip dependency install
bash ~/dotfiles/install.sh --nvim-only   # deps + Neovim config only
bash ~/dotfiles/install.sh --tmux-only   # deps + tmux config only
```

After install, set **JetBrainsMono Nerd Font** as your terminal font.

### Windows (native — PowerShell)

tmux is not available on native Windows; use WSL (below) if you want tmux.
For Neovim only:

```powershell
# 1. Clone the repo (install Git first if needed: https://git-scm.com/download/win)
git clone https://github.com/Brandon-Schur/dotfiles.git $HOME\dotfiles
cd $HOME\dotfiles

# 2. Install ALL dependencies (installs Scoop, git, neovim, lazygit,
#    node, prettier, sql-formatter, python, openjdk, llvm, and the Nerd Font).
#    If you hit an execution-policy error, run the Set-ExecutionPolicy line first.
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
.\scripts\install-deps-windows.ps1

# 3. Open a NEW terminal (so PATH updates apply), then link the Neovim config:
bash scripts\install-nvim.sh
```

Then set **JetBrainsMono Nerd Font** in Windows Terminal settings.

### Windows (WSL — recommended for full tmux + nvim)

```powershell
# In PowerShell as Administrator:
wsl --install
# Reboot if prompted, open Ubuntu, then run the macOS/Linux one-liner above.
```

---

## First launch

### tmux

```bash
tmux                         # start a new session
# Press  Ctrl-a  then  Shift-I  to install TPM plugins (first time only)
# Press  Ctrl-a  then  r        to reload config
```

### Neovim

```bash
nvim                         # lazy.nvim auto-installs all plugins on first open
# Mason installs LSP servers and formatters in the background (~1 min)
# Check formatter status:  :ConformInfo
# Check LSP status:        :LspInfo
# Check Mason packages:    :Mason
```

---

## Key mappings

### tmux (prefix = `Ctrl-a`)

| Key | Action |
|---|---|
| `prefix \|` | Split pane horizontally |
| `prefix -` | Split pane vertically |
| `prefix h/j/k/l` | Resize pane (repeatable) |
| `prefix Ctrl-a` | Cycle through panes |
| `prefix n` | Next window |
| `prefix N` | Previous window |
| `prefix s` | Session picker (sorted, 1-indexed) |
| `prefix e` | Capture scrollback to `~/.tmux.log` |
| `prefix I` | Install TPM plugins |
| `prefix r` | Reload tmux config |

### Neovim (leader = `Space`)

| Key | Action | Defined in |
|---|---|---|
| `Tab` / `Shift-Tab` | Next / previous buffer | `mappings.lua` |
| `Ctrl-Tab` / `Ctrl-Shift-Tab` | Next / previous buffer | `init.lua` |
| `Space ←` / `Space →` | Move to left / right window | `mappings.lua` |
| `Ctrl-C` (visual) | Yank selection to system clipboard | `mappings.lua` |
| `Space lf` | Format buffer or selection | `formatting.lua` |
| `Space lF` | Toggle format-on-save (`:AutoFormatToggle`) | `formatting.lua` |
| `Space gg` | LazyGit (repo) | `lazygit.lua` |
| `Space gG` | LazyGit (current file's repo) | `lazygit.lua` |
| `Space gl` | LazyGit: commits for current file | `lazygit.lua` |
| `Space gd` | Diffview: working tree diff | `diffview.lua` |
| `Space gD` | Diffview: close | `diffview.lua` |
| `Space gh` | Diffview: file history (current file / visual selection) | `diffview.lua` |
| `Space gH` | Diffview: repo history | `diffview.lua` |
| `Space gv` | CodeDiff: changed files explorer | `codediff.lua` |
| `Space gV` | CodeDiff: commit history | `codediff.lua` |

---

## Custom config edits (beyond AstroNvim defaults)

Everything below is an intentional customization on top of stock AstroNvim.
All files live under `nvim/lua/plugins/`.

| File | What it customizes |
|---|---|
| `colorscheme.lua` | Sets active colorscheme to `tokyonight-storm` |
| `tokyonight.lua` | Installs Tokyo Night (style = storm, terminal colors on) |
| `catppuccin.lua` | Installs Catppuccin (macchiato) as an alternative theme |
| `mappings.lua` | Tab/Shift-Tab buffers, `Space`+arrows window nav, visual `Ctrl-C` clipboard yank |
| `clipboard.lua` | Forces OSC 52 clipboard provider (works over SSH/tmux) |
| `formatting.lua` | conform.nvim: per-filetype formatters, format-on-save + toggle, custom JSONL formatter (`jq`) |
| `mason.lua` | Auto-installs formatters/LSP: lua-language-server, stylua, black, isort, jq, clang-format, google-java-format, debugpy, tree-sitter-cli |
| `diffview.lua` | diffview.nvim + `Space g*` keymaps, diff3_mixed merge layout |
| `lazygit.lua` | lazygit.nvim + `Space g*` keymaps, floating window scaling |
| `codediff.lua` | codediff.nvim + `Space gv`/`gV` keymaps |
| `render-markdown.lua` | render-markdown.nvim + treesitter markdown parsers |
| `vim-rooter.lua` | Auto-cd to project root; markers = `.git`, `Cargo.toml`, `.svn`, `.hg` |

Also in `init.lua`: `<C-Tab>`/`<C-S-Tab>` buffer navigation and a vscode-neovim guard.

lazygit config (`lazygit/config.yml`): `editPreset: nvim-remote` — opens files
from lazygit in the parent Neovim instead of a nested editor.

---

## Customization

### Change colorscheme

Edit `nvim/lua/plugins/colorscheme.lua`:

```lua
opts = {
  colorscheme = "tokyonight-storm",  -- change this line
}
```

Available: `tokyonight-storm`, `tokyonight-night`, `tokyonight-moon`, `tokyonight-day`,
`catppuccin-macchiato`, `catppuccin-mocha`, `catppuccin-frappe`, `catppuccin-latte`, `astrodark`.

### Add a formatter

1. Find the Mason package name at `:Mason` or https://mason-registry.dev/
2. Add it to `ensure_installed` in `nvim/lua/plugins/mason.lua`
3. Add the filetype → formatter mapping in `nvim/lua/plugins/formatting.lua`

### tmux clipboard (OSC 52)

The tmux config includes:
```tmux
set -as terminal-features ",alacritty:clipboard"
```
This enables OSC 52 clipboard passthrough specifically for Alacritty. Change
`alacritty` to match your terminal if different (e.g. `xterm-256color`, `kitty`,
`wezterm`). Most modern terminals support OSC 52 by default and may not need this line.

### Project root markers (vim-rooter)

Edit `nvim/lua/plugins/vim-rooter.lua` → `rooter_patterns` to add markers for your
project structure (e.g. `pyproject.toml`, `go.mod`).

---

## Troubleshooting

**Icons look like boxes or question marks**
→ Install a Nerd Font and configure it in your terminal emulator.

**Formatters not working**
→ Run `:ConformInfo` in Neovim — it shows which formatters are found vs missing.
→ Check `prettier` and `sql-formatter` are on PATH: `which prettier`.
→ Check language runtimes are installed (`java -version`, `python3 --version`, `clang-format --version`).

**Mason tools not installing**
→ Check runtimes above are installed.
→ If on a corporate network with a private npm registry, install prettier and
   sql-formatter via `brew install` instead of Mason.

**Plugins not loading in Neovim**
→ Run `:Lazy sync` to force a full sync.
→ Ensure `git` is installed and you have internet access.

**tmux plugins not loading**
→ Press `prefix I` inside tmux, or run manually:
```bash
~/.tmux/plugins/tpm/bin/install_plugins
```

**Clipboard not working from Neovim**
→ Requires Neovim 0.10+ and a terminal that supports OSC 52.
→ If broken, delete `nvim/lua/plugins/clipboard.lua` — Neovim falls back to
   `pbcopy` (macOS), `xclip`/`xsel` (Linux), or the Windows clipboard.
→ On macOS without tmux, clipboard usually works out of the box without this file.

**google-java-format fails**
→ Ensure Java 11+ is installed: `java -version`
→ On macOS: `brew install openjdk && brew link openjdk`

**clang-format not found**
→ macOS: `xcode-select --install`
→ Linux: `sudo apt install clang-format` or `brew install llvm`
→ Windows: `scoop install llvm`
