#!/usr/bin/env bash
# scripts/install-deps.sh
# Installs all dependencies for tmux + Neovim on macOS and Linux.
# Called automatically by install.sh — you can also run it standalone.
#
# What this installs:
#   Core:       Homebrew (if missing), git, tmux, neovim, lazygit
#   Formatters: prettier, sql-formatter  (via brew — avoids npm registry issues)
#   Runtimes:   python, node, openjdk, llvm/clang
#   Font:       JetBrainsMono Nerd Font

set -e

OS="$(uname -s)"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
info()    { echo "  [•] $*"; }
success() { echo "  [✓] $*"; }
warning() { echo "  [!] $*"; }
step()    { echo; echo "==> $*"; }

command_exists() { command -v "$1" &>/dev/null; }

# ---------------------------------------------------------------------------
# Homebrew (macOS + Linux)
# ---------------------------------------------------------------------------
install_homebrew() {
  if command_exists brew; then
    success "Homebrew already installed ($(brew --version | head -1))"
    return
  fi
  info "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Add brew to PATH for the remainder of this script
  if [ "$OS" = "Linux" ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" 2>/dev/null || \
    eval "$(~/.linuxbrew/bin/brew shellenv)" 2>/dev/null || true
  elif [ "$OS" = "Darwin" ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || \
    eval "$(/usr/local/bin/brew shellenv)" 2>/dev/null || true
  fi
  success "Homebrew installed"
}

# ---------------------------------------------------------------------------
# Core tools
# ---------------------------------------------------------------------------
install_core() {
  step "Installing core tools (git, tmux, neovim, lazygit)..."

  local tools=()
  command_exists git      || tools+=("git")
  command_exists tmux     || tools+=("tmux")
  command_exists nvim     || tools+=("neovim")
  command_exists lazygit  || tools+=("lazygit")

  if [ ${#tools[@]} -eq 0 ]; then
    success "All core tools already installed"
    return
  fi

  info "Installing via brew: ${tools[*]}"
  brew install "${tools[@]}"
  success "Core tools installed"
}

# ---------------------------------------------------------------------------
# Formatters (PATH-required — not Mason-managed)
# ---------------------------------------------------------------------------
install_formatters() {
  step "Installing formatters (prettier, sql-formatter)..."

  local tools=()
  command_exists prettier      || tools+=("prettier")
  command_exists sql-formatter || tools+=("sql-formatter")

  if [ ${#tools[@]} -eq 0 ]; then
    success "prettier and sql-formatter already installed"
    return
  fi

  info "Installing via brew: ${tools[*]}"
  brew install "${tools[@]}"
  success "Formatters installed"
}

# ---------------------------------------------------------------------------
# Language runtimes (needed by Mason-managed formatters)
# ---------------------------------------------------------------------------
install_runtimes() {
  step "Installing language runtimes (python, node, openjdk, llvm)..."

  # Python
  if command_exists python3; then
    success "Python already installed ($(python3 --version))"
  else
    info "Installing Python..."
    brew install python
  fi

  # Node.js
  if command_exists node; then
    success "Node.js already installed ($(node --version))"
  else
    info "Installing Node.js..."
    brew install node
  fi

  # Java (for google-java-format)
  if command_exists java; then
    success "Java already installed ($(java -version 2>&1 | head -1))"
  else
    info "Installing OpenJDK..."
    brew install openjdk
    # Symlink so system Java picks it up
    if [ "$OS" = "Darwin" ]; then
      sudo ln -sfn "$(brew --prefix openjdk)/libexec/openjdk.jdk" \
        /Library/Java/JavaVirtualMachines/openjdk.jdk 2>/dev/null || \
        warning "Could not symlink JDK (may need sudo). Run manually if java -version fails."
    fi
  fi

  # clang-format (part of llvm)
  if command_exists clang-format; then
    success "clang-format already installed"
  else
    info "Installing llvm (provides clang-format)..."
    if [ "$OS" = "Darwin" ]; then
      # macOS: Xcode CLT provides clang; brew llvm for a full/newer version
      xcode-select -p &>/dev/null && success "Xcode CLT already installed (provides clang-format)" || {
        info "Installing Xcode Command Line Tools..."
        xcode-select --install 2>/dev/null || true
        warning "Xcode CLT install opened a GUI dialog — complete it, then re-run this script."
      }
    else
      brew install llvm
    fi
  fi

  success "Language runtimes done"
}

# ---------------------------------------------------------------------------
# Nerd Font — JetBrainsMono
# ---------------------------------------------------------------------------
install_nerd_font() {
  step "Installing JetBrainsMono Nerd Font..."

  if [ "$OS" = "Darwin" ]; then
    if fc-list 2>/dev/null | grep -qi "JetBrainsMono" || \
       ls ~/Library/Fonts/JetBrainsMono* &>/dev/null 2>&1; then
      success "JetBrainsMono Nerd Font already installed"
      return
    fi
    brew install --cask font-jetbrains-mono-nerd-font
    success "Font installed — set 'JetBrainsMono Nerd Font' in your terminal preferences"

  elif [ "$OS" = "Linux" ]; then
    FONT_DIR="${HOME}/.local/share/fonts"
    if fc-list 2>/dev/null | grep -qi "JetBrainsMono"; then
      success "JetBrainsMono Nerd Font already installed"
      return
    fi
    info "Downloading JetBrainsMono Nerd Font..."
    mkdir -p "$FONT_DIR"
    FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz"
    curl -fsSL "$FONT_URL" | tar -xJ -C "$FONT_DIR" --wildcards "*.ttf" 2>/dev/null || \
      curl -fsSL "$FONT_URL" | tar -xJ -C "$FONT_DIR" 2>/dev/null || \
      warning "Font download failed — install manually from https://www.nerdfonts.com"
    fc-cache -fv "$FONT_DIR" &>/dev/null
    success "Font installed — set 'JetBrainsMono Nerd Font' in your terminal preferences"
  fi
}

# ---------------------------------------------------------------------------
# Linux: system packages that brew doesn't provide well
# ---------------------------------------------------------------------------
install_linux_extras() {
  if [ "$OS" != "Linux" ]; then return; fi
  step "Installing Linux system extras..."

  # curl/wget needed for Mason binary downloads
  if ! command_exists curl && ! command_exists wget; then
    if command_exists apt-get; then
      sudo apt-get install -y curl
    elif command_exists dnf; then
      sudo dnf install -y curl
    fi
  fi
  success "Linux extras done"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
echo "=========================================="
echo "  Dependency installer — macOS / Linux"
echo "  OS: $OS"
echo "=========================================="

install_homebrew
install_core
install_formatters
install_runtimes
install_nerd_font
install_linux_extras

echo
echo "=========================================="
echo "  All dependencies installed!"
echo "  Run install.sh to link your configs."
echo "=========================================="
