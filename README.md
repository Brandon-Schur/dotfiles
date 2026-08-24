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

### macOS

```bash
# 1. Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 2. Install required tools
brew install tmux neovim git lazygit

# 3. Install formatters (PATH-required, not Mason-managed)
brew install prettier sql-formatter

# 4. Install language runtimes for Mason-managed tools
brew install python openjdk llvm node

# 5. Install a Nerd Font (example: JetBrainsMono)
brew install --cask font-jetbrains-mono-nerd-font
# Then set the font in your terminal preferences.

# 6. Clone dotfiles
git clone https://github.com/Brandon-Schur/dotfiles.git ~/dotfiles

# 7. Run installer
bash ~/dotfiles/install.sh
```

### Linux (Debian/Ubuntu)

```bash
# 1. Install Homebrew (gives latest tmux/nvim without sudo for most packages)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
# Follow the post-install instructions to add brew to your PATH, then reload shell.

# 2. Install required tools
brew install tmux neovim git lazygit

# 3. Install formatters (PATH-required)
brew install prettier sql-formatter

# 4. Install language runtimes
brew install python node
sudo apt install default-jdk clang-format   # Java + clang via apt

# 5. Install a Nerd Font
# Download from https://www.nerdfonts.com, unzip to ~/.local/share/fonts/, then:
fc-cache -fv
# Set the font in your terminal emulator preferences.

# 6. Clone dotfiles
git clone https://github.com/Brandon-Schur/dotfiles.git ~/dotfiles

# 7. Run installer
bash ~/dotfiles/install.sh
```

> **No Homebrew?** Install tmux via `sudo apt install tmux` and Neovim from
> [official releases](https://github.com/neovim/neovim/releases) (apt version is
> usually too old — 0.10+ required). Then install prettier/sql-formatter via npm.

### Windows (WSL — recommended)

WSL2 gives the best experience; tmux and Neovim work exactly as on Linux:

```powershell
# 1. Install WSL2 with Ubuntu (PowerShell as Administrator)
wsl --install

# 2. Open Ubuntu, then follow the Linux instructions above
```

### Windows (Native — PowerShell)

tmux is not available natively on Windows. Only the Neovim config can be installed.

```powershell
# 1. Install Scoop (package manager)
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
irm get.scoop.sh | iex

# 2. Install required tools
scoop install neovim git lazygit

# 3. Install Node.js + formatters
scoop install nodejs
npm install -g prettier sql-formatter

# 4. Install language runtimes
scoop install python openjdk llvm

# 5. Install a Nerd Font
# Download from https://www.nerdfonts.com, double-click the .ttf file to install,
# then set the font in Windows Terminal settings.

# 6. Clone dotfiles
git clone https://github.com/Brandon-Schur/dotfiles.git $HOME/dotfiles

# 7. Install Neovim config only (tmux not supported on native Windows)
bash $HOME/dotfiles/scripts/install-nvim.sh
```

> On native Windows, Neovim config lives at `%LOCALAPPDATA%\nvim`.
> The install script symlinks there automatically.

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

| Key | Action |
|---|---|
| `Tab` / `Shift-Tab` | Next / previous buffer |
| `Space ←` / `Space →` | Move to left / right window |
| `Ctrl-C` (visual) | Yank to system clipboard |
| `Space lf` | Format buffer or selection |
| `Space lF` | Toggle format-on-save |
| `Space gg` | LazyGit |
| `Space gd` | Diffview: working tree |
| `Space gh` | Diffview: file history |
| `Space gv` | CodeDiff: changed files |
| `Space gV` | CodeDiff: commit history |

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
