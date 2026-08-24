# scripts/install-deps-windows.ps1
# Installs all dependencies for Neovim on Windows (native, no WSL).
# NOTE: tmux is not available on native Windows — use WSL for tmux support.
#
# HOW TO RUN:
#   1. Open PowerShell as your normal user (NOT Administrator)
#   2. If you get an execution policy error, run first:
#         Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
#   3. Then run:
#         .\scripts\install-deps-windows.ps1
#
# What this installs:
#   Package manager: Scoop
#   Core:            git, neovim, lazygit
#   Formatters:      nodejs, prettier, sql-formatter
#   Runtimes:        python, openjdk, llvm
#   Font:            JetBrainsMono Nerd Font

$ErrorActionPreference = "Stop"

function Write-Step   { Write-Host "`n==> $args" -ForegroundColor Cyan }
function Write-Info   { Write-Host "  [•] $args" }
function Write-OK     { Write-Host "  [✓] $args" -ForegroundColor Green }
function Write-Warn   { Write-Host "  [!] $args" -ForegroundColor Yellow }

function Test-Command { param($Name); return [bool](Get-Command $Name -ErrorAction SilentlyContinue) }

# ---------------------------------------------------------------------------
# Scoop
# ---------------------------------------------------------------------------
Write-Step "Installing Scoop (Windows package manager)..."

if (Test-Command "scoop") {
    Write-OK "Scoop already installed"
} else {
    Write-Info "Installing Scoop..."
    Write-Info "This requires PowerShell execution policy: RemoteSigned"
    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Invoke-RestMethod get.scoop.sh | Invoke-Expression
    # Reload PATH
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "User") + ";" + $env:PATH
    Write-OK "Scoop installed"
}

# Add extras and versions buckets (needed for some packages)
Write-Step "Adding Scoop buckets..."
$buckets = scoop bucket list 2>$null
foreach ($bucket in @("extras", "java", "versions")) {
    if ($buckets -notcontains $bucket) {
        Write-Info "Adding bucket: $bucket"
        scoop bucket add $bucket
    } else {
        Write-OK "Bucket already added: $bucket"
    }
}

# ---------------------------------------------------------------------------
# Core tools
# ---------------------------------------------------------------------------
Write-Step "Installing core tools (git, neovim, lazygit)..."

$tools = @(
    @{ name = "git";     cmd = "git"     },
    @{ name = "neovim";  cmd = "nvim"    },
    @{ name = "lazygit"; cmd = "lazygit" }
)
foreach ($t in $tools) {
    if (Test-Command $t.cmd) {
        Write-OK "$($t.name) already installed"
    } else {
        Write-Info "Installing $($t.name)..."
        scoop install $t.name
    }
}

# ---------------------------------------------------------------------------
# Node.js + formatters (prettier, sql-formatter)
# ---------------------------------------------------------------------------
Write-Step "Installing Node.js and formatters..."

if (Test-Command "node") {
    Write-OK "Node.js already installed ($(node --version))"
} else {
    Write-Info "Installing Node.js..."
    scoop install nodejs-lts
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "User") + ";" + $env:PATH
}

foreach ($pkg in @("prettier", "sql-formatter")) {
    if (Test-Command $pkg) {
        Write-OK "$pkg already installed"
    } else {
        Write-Info "Installing $pkg via npm..."
        npm install -g $pkg
    }
}

# ---------------------------------------------------------------------------
# Language runtimes (for Mason-managed formatters)
# ---------------------------------------------------------------------------
Write-Step "Installing language runtimes (python, openjdk, llvm)..."

# Python (for black, isort, debugpy)
if (Test-Command "python") {
    Write-OK "Python already installed ($(python --version 2>&1))"
} else {
    Write-Info "Installing Python..."
    scoop install python
}

# Java (for google-java-format)
if (Test-Command "java") {
    Write-OK "Java already installed ($(java -version 2>&1 | Select-Object -First 1))"
} else {
    Write-Info "Installing OpenJDK 21..."
    scoop install openjdk21
}

# LLVM (for clang-format)
if (Test-Command "clang-format") {
    Write-OK "clang-format already installed"
} else {
    Write-Info "Installing LLVM (provides clang-format)..."
    scoop install llvm
}

# ---------------------------------------------------------------------------
# Nerd Font — JetBrainsMono
# ---------------------------------------------------------------------------
Write-Step "Installing JetBrainsMono Nerd Font..."

$fontName = "JetBrainsMono NF"
$installedFonts = [System.Drawing.Text.InstalledFontCollection]::new().Families.Name
if ($installedFonts -contains $fontName) {
    Write-OK "JetBrainsMono Nerd Font already installed"
} else {
    Write-Info "Downloading JetBrainsMono Nerd Font..."
    $fontUrl = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
    $tmpZip  = "$env:TEMP\JetBrainsMono.zip"
    $tmpDir  = "$env:TEMP\JetBrainsMono"

    Invoke-WebRequest -Uri $fontUrl -OutFile $tmpZip
    Expand-Archive -Path $tmpZip -DestinationPath $tmpDir -Force

    # Install each .ttf for the current user
    $fontsFolder = [System.Environment]::GetFolderPath("Fonts")
    $shell = New-Object -ComObject Shell.Application
    $fonts = $shell.Namespace(0x14)  # Special folder: Fonts
    Get-ChildItem "$tmpDir\*.ttf" | ForEach-Object {
        $fonts.CopyHere($_.FullName)
        Write-Info "Installed: $($_.Name)"
    }
    Remove-Item $tmpZip, $tmpDir -Recurse -Force
    Write-OK "Font installed — set 'JetBrainsMono Nerd Font' in Windows Terminal settings"
    Write-Warn "You may need to restart Windows Terminal for the font to appear."
}

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "  All dependencies installed!" -ForegroundColor Green
Write-Host "  Next: run scripts\install-nvim.sh" -ForegroundColor Green
Write-Host "  (tmux is not available on native Windows — use WSL)" -ForegroundColor Yellow
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "  IMPORTANT: Open a NEW PowerShell/terminal window so PATH updates take effect."
