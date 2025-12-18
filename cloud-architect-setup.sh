#!/bin/bash
#===============================================================================
# Ubuntu 24.04 LTS - Cloud Architect Workstation Setup
# Author: Claude + Björn
# Purpose: Transform fresh Ubuntu into an AI-powered cloud engineering beast
#===============================================================================
#
# USAGE:
#   Option A: Run entire script:  ./cloud-architect-setup.sh
#   Option B: Run specific phase: ./cloud-architect-setup.sh --phase 3
#   Option C: Rootless Docker:      ./cloud-architect-setup.sh --rootless-docker
#
# PHASES:
#   1 - Foundation (system update, core deps, Zsh + Oh My Zsh + Starship)
#   2 - Browsers (Brave as default, Edge for O365/Teams)
#   3 - Dev Runtimes (Python, nvm + Node LTS)
#   4 - Containers & K8s (Docker, kubectl, helm, k9s, kubectx)
#   5 - Cloud & AI (Azure CLI, Claude Code, Codex)
#   6 - Apps & Tools (VSCode Insiders, 1Password, Spotify, CLI debug tools)
#
#===============================================================================

set -euo pipefail  # Exit on any error, undefined var, or failed pipe

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_phase() { echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; echo -e "${BLUE}  PHASE $1: $2${NC}"; echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"; }
log_step() { echo -e "${GREEN}[✓]${NC} $1"; }
log_info() { echo -e "${YELLOW}[i]${NC} $1"; }
log_warn() { echo -e "${RED}[!]${NC} $1"; }

# Parse arguments
PHASE_TO_RUN=""
DOCKER_ROOTLESS="false"
while [[ $# -gt 0 ]]; do
    case $1 in
        --phase)
            if [[ -z "${2:-}" ]]; then
                echo "Error: --phase requires a value"; exit 1
            fi
            PHASE_TO_RUN="$2"; shift 2 ;;
        --rootless-docker) DOCKER_ROOTLESS="true"; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

should_run_phase() {
    [[ -z "$PHASE_TO_RUN" ]] || [[ "$PHASE_TO_RUN" == "$1" ]]
}

#===============================================================================
# PHASE 1: FOUNDATION
#===============================================================================
phase_1_foundation() {
    log_phase "1" "Foundation - System Update, Core Dependencies, Zsh + Starship"

    # System update
    log_step "Updating system packages..."
    sudo apt update && sudo apt upgrade -y

    # Core dependencies - everything we'll need for subsequent phases
    log_step "Installing core dependencies..."
    sudo apt install -y \
        build-essential \
        curl \
        wget \
        git \
        ca-certificates \
        gnupg \
        lsb-release \
        software-properties-common \
        apt-transport-https \
        unzip \
        zip \
        fontconfig

    # Install Zsh
    log_step "Installing Zsh..."
    sudo apt install -y zsh

    # Install Oh My Zsh (non-interactive)
    log_step "Installing Oh My Zsh..."
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    else
        log_info "Oh My Zsh already installed, skipping..."
    fi

    # Install Zsh plugins
    log_step "Installing Zsh plugins (autosuggestions, syntax-highlighting)..."
    ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
    
    # zsh-autosuggestions
    if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
        git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
    fi
    
    # zsh-syntax-highlighting
    if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
        git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
    fi

    # Configure .zshrc with plugins (idempotent - only adds if missing)
    log_step "Configuring .zshrc with initial plugins..."
    for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
        if ! grep -q "$plugin" "$HOME/.zshrc"; then
            sed -i "s/plugins=(\(.*\))/plugins=(\1 $plugin)/" "$HOME/.zshrc"
        fi
    done

    # Install Starship prompt
    log_step "Installing Starship prompt..."
    if ! command -v starship &> /dev/null; then
        curl -sS https://starship.rs/install.sh | sh -s -- -y
    else
        log_info "Starship already installed"
    fi

    # Install FiraCode Nerd Font (with checksum verification)
    log_step "Installing FiraCode Nerd Font..."
    FONT_DIR="$HOME/.local/share/fonts"
    if [ ! -f "$FONT_DIR/FiraCodeNerdFont-Regular.ttf" ]; then
        TMP_DIR="$(mktemp -d)"
        mkdir -p "$FONT_DIR"
        curl -fsSL -o "$TMP_DIR/FiraCode.zip" \
            "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip"
        curl -fsSL -o "$TMP_DIR/SHA-256.txt" \
            "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/SHA-256.txt"
        EXPECTED_SHA="$(grep 'FiraCode.zip' "$TMP_DIR/SHA-256.txt" | awk '{print $1}' || true)"
        if [[ -z "$EXPECTED_SHA" ]]; then
            log_warn "Checksum not found for FiraCode.zip"; exit 1
        fi
        echo "${EXPECTED_SHA}  $TMP_DIR/FiraCode.zip" | sha256sum -c -
        unzip -o "$TMP_DIR/FiraCode.zip" -d "$FONT_DIR"
        rm -rf "$TMP_DIR"
        fc-cache -fv
    else
        log_info "FiraCode Nerd Font already installed"
    fi

    # Configure Starship
    log_step "Configuring Starship prompt..."
    mkdir -p "$HOME/.config"
    cat > "$HOME/.config/starship.toml" << 'STARSHIPCONFIG'
# ~/.config/starship.toml
# Clean & functional config for cloud architects

# Minimal prompt character
[character]
success_symbol = "[❯](bold green)"
error_symbol = "[❯](bold red)"

# Directory - truncated, clean
[directory]
truncation_length = 3
truncate_to_repo = true
style = "bold cyan"

# Git - minimal but useful
[git_branch]
symbol = " "
style = "bold purple"

[git_status]
style = "bold yellow"
format = '([$all_status$ahead_behind]($style) )'

# Azure - show only when relevant
[azure]
disabled = false
symbol = "󰠅 "
style = "bold blue"
format = '[$symbol($subscription)]($style) '

# Kubernetes - context aware
[kubernetes]
disabled = false
symbol = "󱃾 "
style = "bold bright-blue"
format = '[$symbol$context( \($namespace\))]($style) '
detect_folders = ["k8s", "kubernetes", "helm", "charts"]

# Terraform - workspace awareness
[terraform]
disabled = false
symbol = "󱁢 "
style = "bold 105"
format = '[$symbol$workspace]($style) '

# Python - when in venv
[python]
symbol = " "
style = "bold yellow"
format = '[${symbol}${pyenv_prefix}(${version} )(\($virtualenv\) )]($style)'

# Node - minimal
[nodejs]
symbol = " "
style = "bold green"
format = '[$symbol($version )]($style)'

# Docker context
[docker_context]
symbol = " "
style = "bold blue"
only_with_files = true

# Time - optional, uncomment if you want it
# [time]
# disabled = false
# format = '[$time]($style) '
# style = "dimmed white"

# Command duration - only show if > 2s
[cmd_duration]
min_time = 2_000
style = "bold yellow"
format = '[took $duration]($style) '

# Clean line break before prompt
[line_break]
disabled = false

# ---- Disabled noisy modules ----
[package]
disabled = true

[aws]
disabled = true  # Enable if you use AWS too

[gcloud]
disabled = true  # Enable if you use GCP too

[helm]
disabled = true  # K8s context is enough

[buf]
disabled = true

[cmake]
disabled = true

[cobol]
disabled = true

[crystal]
disabled = true

[daml]
disabled = true

[dart]
disabled = true

[deno]
disabled = true

[dotnet]
disabled = true

[elixir]
disabled = true

[elm]
disabled = true

[erlang]
disabled = true

[golang]
disabled = true  # Enable if you write Go

[haskell]
disabled = true

[java]
disabled = true

[julia]
disabled = true

[kotlin]
disabled = true

[lua]
disabled = true

[nim]
disabled = true

[nix_shell]
disabled = true

[ocaml]
disabled = true

[perl]
disabled = true

[php]
disabled = true

[pulumi]
disabled = true

[purescript]
disabled = true

[rlang]
disabled = true

[ruby]
disabled = true

[rust]
disabled = true

[scala]
disabled = true

[swift]
disabled = true

[vagrant]
disabled = true

[vlang]
disabled = true

[zig]
disabled = true
STARSHIPCONFIG

    # Add Starship initialization to .zshrc
    if ! grep -q 'starship init' "$HOME/.zshrc"; then
        log_step "Adding Starship init to .zshrc..."
        cat >> "$HOME/.zshrc" << 'EOF'

# Starship prompt
eval "$(starship init zsh)"
EOF
    fi

    # Install Neovim (latest stable via PPA)
    log_step "Installing Neovim..."
    if ! command -v nvim &> /dev/null; then
        sudo add-apt-repository -y ppa:neovim-ppa/stable
        sudo apt update
        sudo apt install -y neovim
    else
        log_info "Neovim already installed"
    fi

    # Install dependencies for Neovim plugins
    log_step "Installing Neovim plugin dependencies..."
    sudo apt install -y ripgrep fd-find xclip wl-clipboard

    # Setup Neovim config directory
    log_step "Setting up Neovim configuration..."
    mkdir -p "$HOME/.config/nvim"

    # Create a minimal but practical Neovim config
    cat > "$HOME/.config/nvim/init.lua" << 'NVIMCONFIG'
-- =============================================================================
-- Neovim Config - Cloud Architect Baseline
-- Minimal, practical config for quick edits and SSH sessions
-- =============================================================================

-- Leader key (space)
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- =============================================================================
-- Core Options
-- =============================================================================
local opt = vim.opt

opt.number = true              -- Line numbers
opt.relativenumber = true      -- Relative line numbers
opt.mouse = 'a'                -- Enable mouse
opt.showmode = false           -- Don't show mode (statusline does it)
opt.clipboard = 'unnamedplus'  -- System clipboard
opt.breakindent = true         -- Wrapped lines keep indent
opt.undofile = true            -- Persistent undo
opt.ignorecase = true          -- Case insensitive search...
opt.smartcase = true           -- ...unless capital used
opt.signcolumn = 'yes'         -- Always show sign column
opt.updatetime = 250           -- Faster completion
opt.timeoutlen = 300           -- Faster which-key popup
opt.splitright = true          -- Vertical split to right
opt.splitbelow = true          -- Horizontal split below
opt.list = true                -- Show whitespace chars
opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }
opt.inccommand = 'split'       -- Live substitution preview
opt.cursorline = true          -- Highlight current line
opt.scrolloff = 10             -- Keep 10 lines above/below cursor
opt.hlsearch = true            -- Highlight search matches
opt.tabstop = 4                -- Tab width
opt.shiftwidth = 4             -- Indent width
opt.expandtab = true           -- Spaces instead of tabs
opt.termguicolors = true       -- True color support

-- =============================================================================
-- Keymaps
-- =============================================================================
local keymap = vim.keymap.set

-- Clear search highlight with Escape
keymap('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Better window navigation
keymap('n', '<C-h>', '<C-w><C-h>', { desc = 'Focus left window' })
keymap('n', '<C-l>', '<C-w><C-l>', { desc = 'Focus right window' })
keymap('n', '<C-j>', '<C-w><C-j>', { desc = 'Focus lower window' })
keymap('n', '<C-k>', '<C-w><C-k>', { desc = 'Focus upper window' })

-- Stay in visual mode when indenting
keymap('v', '<', '<gv')
keymap('v', '>', '>gv')

-- Move lines up/down
keymap('v', 'J', ":m '>+1<CR>gv=gv", { desc = 'Move selection down' })
keymap('v', 'K', ":m '<-2<CR>gv=gv", { desc = 'Move selection up' })

-- Quick save
keymap('n', '<leader>w', '<cmd>w<CR>', { desc = 'Save file' })
keymap('n', '<leader>q', '<cmd>q<CR>', { desc = 'Quit' })

-- File explorer (netrw)
keymap('n', '<leader>e', '<cmd>Ex<CR>', { desc = 'File explorer' })

-- Buffer navigation
keymap('n', '<S-h>', '<cmd>bprevious<CR>', { desc = 'Previous buffer' })
keymap('n', '<S-l>', '<cmd>bnext<CR>', { desc = 'Next buffer' })
keymap('n', '<leader>bd', '<cmd>bdelete<CR>', { desc = 'Delete buffer' })

-- =============================================================================
-- Lazy.nvim Plugin Manager Bootstrap
-- =============================================================================
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
        'git', 'clone', '--filter=blob:none',
        'https://github.com/folke/lazy.nvim.git',
        '--branch=stable', lazypath,
    })
end
vim.opt.rtp:prepend(lazypath)

-- =============================================================================
-- Plugins
-- =============================================================================
require('lazy').setup({
    -- Colorscheme: Tokyo Night (easy on the eyes)
    {
        'folke/tokyonight.nvim',
        lazy = false,
        priority = 1000,
        config = function()
            vim.cmd.colorscheme('tokyonight-night')
        end,
    },

    -- Status line
    {
        'nvim-lualine/lualine.nvim',
        dependencies = { 'nvim-tree/nvim-web-devicons' },
        config = function()
            require('lualine').setup({
                options = { theme = 'tokyonight' }
            })
        end,
    },

    -- Fuzzy finder (telescope)
    {
        'nvim-telescope/telescope.nvim',
        branch = '0.1.x',
        dependencies = { 'nvim-lua/plenary.nvim' },
        config = function()
            local builtin = require('telescope.builtin')
            vim.keymap.set('n', '<leader>ff', builtin.find_files, { desc = 'Find files' })
            vim.keymap.set('n', '<leader>fg', builtin.live_grep, { desc = 'Live grep' })
            vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = 'Find buffers' })
            vim.keymap.set('n', '<leader>fh', builtin.help_tags, { desc = 'Help tags' })
            vim.keymap.set('n', '<leader>fr', builtin.oldfiles, { desc = 'Recent files' })
            vim.keymap.set('n', '<leader>/', builtin.current_buffer_fuzzy_find, { desc = 'Search in buffer' })
        end,
    },

    -- Treesitter (better syntax highlighting)
    {
        'nvim-treesitter/nvim-treesitter',
        build = ':TSUpdate',
        config = function()
            require('nvim-treesitter.configs').setup({
                ensure_installed = { 
                    'bash', 'python', 'javascript', 'typescript', 'json', 'yaml', 
                    'lua', 'vim', 'vimdoc', 'markdown', 'dockerfile', 'hcl', 'go'
                },
                auto_install = true,
                highlight = { enable = true },
                indent = { enable = true },
            })
        end,
    },

    -- Git signs in gutter
    {
        'lewis6991/gitsigns.nvim',
        config = function()
            require('gitsigns').setup({
                signs = {
                    add = { text = '│' },
                    change = { text = '│' },
                    delete = { text = '_' },
                    topdelete = { text = '‾' },
                    changedelete = { text = '~' },
                },
            })
        end,
    },

    -- Which-key (shows available keybindings)
    {
        'folke/which-key.nvim',
        event = 'VeryLazy',
        config = function()
            require('which-key').setup()
        end,
    },

    -- Auto pairs (brackets, quotes)
    {
        'windwp/nvim-autopairs',
        event = 'InsertEnter',
        config = true,
    },

    -- Comment toggling
    {
        'numToStr/Comment.nvim',
        config = true,  -- gcc to comment line, gc in visual mode
    },

    -- Indent guides
    {
        'lukas-reineke/indent-blankline.nvim',
        main = 'ibl',
        config = function()
            require('ibl').setup()
        end,
    },
}, {
    -- Lazy.nvim options
    checker = { enabled = false },  -- Don't auto-check for updates
})

-- =============================================================================
-- Autocommands
-- =============================================================================
local augroup = vim.api.nvim_create_augroup('CloudArchitect', { clear = true })

-- Highlight on yank
vim.api.nvim_create_autocmd('TextYankPost', {
    group = augroup,
    callback = function()
        vim.highlight.on_yank({ timeout = 200 })
    end,
})

-- Remove trailing whitespace on save
vim.api.nvim_create_autocmd('BufWritePre', {
    group = augroup,
    pattern = '*',
    command = [[%s/\s\+$//e]],
})

-- Return to last edit position
vim.api.nvim_create_autocmd('BufReadPost', {
    group = augroup,
    callback = function()
        local mark = vim.api.nvim_buf_get_mark(0, '"')
        local lcount = vim.api.nvim_buf_line_count(0)
        if mark[1] > 0 and mark[1] <= lcount then
            pcall(vim.api.nvim_win_set_cursor, 0, mark)
        end
    end,
})
NVIMCONFIG

    # Add Neovim aliases to .zshrc
    if ! grep -q 'alias vim=' "$HOME/.zshrc"; then
        log_step "Adding Neovim aliases to .zshrc..."
        cat >> "$HOME/.zshrc" << 'EOF'

# Neovim as default editor
export EDITOR='nvim'
export VISUAL='nvim'
alias vim='nvim'
alias vi='nvim'
EOF
    fi

    log_step "Neovim configured! First launch will install plugins automatically."

    # Set Zsh as default shell
    log_step "Setting Zsh as default shell..."
    sudo chsh -s "$(which zsh)" "$USER"

    log_step "Phase 1 complete! (Logout/login to activate Zsh)"
}

#===============================================================================
# PHASE 2: BROWSERS
#===============================================================================
phase_2_browsers() {
    log_phase "2" "Browsers - Brave (default) + Edge (O365/Teams)"

    # Brave Browser
    log_step "Installing Brave browser..."
    if ! command -v brave-browser &> /dev/null; then
        sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
            https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | \
            sudo tee /etc/apt/sources.list.d/brave-browser-release.list
        sudo apt update
        sudo apt install -y brave-browser
    else
        log_info "Brave already installed"
    fi

    # Microsoft Edge (for Teams/O365 web apps)
    log_step "Installing Microsoft Edge..."
    if ! command -v microsoft-edge-stable &> /dev/null; then
        curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | \
            sudo gpg --dearmor -o /usr/share/keyrings/microsoft-edge.gpg --yes
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-edge.gpg] https://packages.microsoft.com/repos/edge stable main" | \
            sudo tee /etc/apt/sources.list.d/microsoft-edge.list
        sudo apt update
        sudo apt install -y microsoft-edge-stable
    else
        log_info "Edge already installed"
    fi

    # Set Brave as default browser
    log_step "Setting Brave as default browser..."
    xdg-settings set default-web-browser brave-browser.desktop 2>/dev/null || \
        log_warn "Could not set default browser (may need GUI session)"

    log_step "Phase 2 complete!"
}

#===============================================================================
# PHASE 3: DEV RUNTIMES
#===============================================================================
phase_3_runtimes() {
    log_phase "3" "Dev Runtimes - Python + pip, nvm + Node LTS"

    # Python (should be installed, but ensure pip and venv)
    log_step "Ensuring Python3, pip, and venv..."
    sudo apt install -y python3 python3-pip python3-venv python3-full

    # Create a global pip config to avoid externally-managed-environment issues
    log_step "Configuring pip for user installs..."
    mkdir -p "$HOME/.config/pip"
    cat > "$HOME/.config/pip/pip.conf" << 'EOF'
[global]
break-system-packages = false
user = true
EOF

    # nvm (Node Version Manager)
    log_step "Installing nvm..."
    if [ ! -d "$HOME/.nvm" ]; then
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    else
        log_info "nvm already installed"
    fi

    # Load nvm for this session
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    # Install Node LTS
    log_step "Installing Node.js LTS..."
    nvm install --lts
    nvm use --lts
    nvm alias default 'lts/*'

    # Update npm to latest
    log_step "Updating npm to latest..."
    npm install -g npm@latest

    # Add nvm to .zshrc if not present
    if ! grep -q 'NVM_DIR' "$HOME/.zshrc"; then
        log_step "Adding nvm to .zshrc..."
        cat >> "$HOME/.zshrc" << 'EOF'

# nvm (Node Version Manager)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
EOF
    fi

    log_step "Phase 3 complete! Node $(node -v), npm $(npm -v)"
}

#===============================================================================
# PHASE 4: CONTAINERS & KUBERNETES
#===============================================================================
phase_4_containers() {
    log_phase "4" "Containers & K8s - Docker, kubectl, helm, k9s, kubectx"

    # Docker Engine (official repo)
    log_step "Installing Docker Engine..."
    if ! command -v docker &> /dev/null; then
        # Add Docker's official GPG key
        sudo install -m 0755 -d /etc/apt/keyrings
        sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        sudo chmod a+r /etc/apt/keyrings/docker.asc

        # Add the repository
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
            $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
            sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

        sudo apt update
        sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    else
        log_info "Docker already installed"
    fi

    if [[ "$DOCKER_ROOTLESS" == "true" ]]; then
        log_step "Configuring rootless Docker..."
        sudo apt install -y docker-ce-rootless-extras uidmap dbus-user-session slirp4netns fuse-overlayfs
        if ! systemctl --user status docker &>/dev/null; then
            if command -v dockerd-rootless-setuptool.sh &> /dev/null; then
                dockerd-rootless-setuptool.sh install
            else
                log_warn "dockerd-rootless-setuptool.sh not found; rootless setup skipped"
            fi
        else
            log_info "Rootless Docker already configured"
        fi
        if ! grep -q 'DOCKER_HOST=unix:///run/user/$UID/docker.sock' "$HOME/.zshrc"; then
            cat >> "$HOME/.zshrc" << 'EOF'

# Rootless Docker
export DOCKER_HOST=unix:///run/user/$UID/docker.sock
EOF
        fi
    else
        # Add user to docker group (no sudo needed for docker commands)
        log_step "Adding $USER to docker group..."
        sudo usermod -aG docker "$USER"
    fi

    # kubectl
    log_step "Installing kubectl..."
    if ! command -v kubectl &> /dev/null; then
        curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | \
            sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg --yes
        echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | \
            sudo tee /etc/apt/sources.list.d/kubernetes.list
        sudo apt update
        sudo apt install -y kubectl
    else
        log_info "kubectl already installed"
    fi

    # Helm
    log_step "Installing Helm..."
    if ! command -v helm &> /dev/null; then
        curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    else
        log_info "Helm already installed"
    fi

    # k9s (Kubernetes TUI, with checksum verification)
    log_step "Installing k9s..."
    if ! command -v k9s &> /dev/null; then
        K9S_VERSION="$(curl -fsSL https://api.github.com/repos/derailed/k9s/releases/latest | grep tag_name | cut -d '"' -f 4 || true)"
        if [[ -z "$K9S_VERSION" ]]; then
            log_warn "Could not determine k9s version"; exit 1
        fi
        TMP_DIR="$(mktemp -d)"
        curl -fsSL -o "$TMP_DIR/k9s.tar.gz" \
            "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_amd64.tar.gz"
        curl -fsSL -o "$TMP_DIR/checksums.txt" \
            "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/checksums.txt"
        EXPECTED_SHA="$(grep 'k9s_Linux_amd64.tar.gz' "$TMP_DIR/checksums.txt" | awk '{print $1}' || true)"
        if [[ -z "$EXPECTED_SHA" ]]; then
            log_warn "Checksum not found for k9s"; exit 1
        fi
        echo "${EXPECTED_SHA}  $TMP_DIR/k9s.tar.gz" | sha256sum -c -
        sudo tar xzf "$TMP_DIR/k9s.tar.gz" -C /usr/local/bin k9s
        rm -rf "$TMP_DIR"
    else
        log_info "k9s already installed"
    fi

    # kubectx + kubens
    log_step "Installing kubectx and kubens..."
    if ! command -v kubectx &> /dev/null; then
        sudo git clone https://github.com/ahmetb/kubectx /opt/kubectx
        sudo ln -sf /opt/kubectx/kubectx /usr/local/bin/kubectx
        sudo ln -sf /opt/kubectx/kubens /usr/local/bin/kubens
    else
        log_info "kubectx already installed"
    fi

    # Update .zshrc with kubectl and docker plugins (idempotent)
    log_step "Adding kubectl and docker plugins to Zsh..."
    for plugin in kubectl docker docker-compose kubectx; do
        if ! grep -q "$plugin" "$HOME/.zshrc"; then
            sed -i "s/plugins=(\(.*\))/plugins=(\1 $plugin)/" "$HOME/.zshrc"
        fi
    done

    if [[ "$DOCKER_ROOTLESS" == "true" ]]; then
        log_step "Phase 4 complete! (Logout/login, then test: docker info)"
    else
        log_step "Phase 4 complete! (Logout/login to use docker without sudo)"
    fi
}

#===============================================================================
# PHASE 5: CLOUD & AI TOOLS
#===============================================================================
phase_5_cloud_ai() {
    log_phase "5" "Cloud & AI - Azure CLI, Claude Code, Codex"

    # Azure CLI
    log_step "Installing Azure CLI..."
    if ! command -v az &> /dev/null; then
        curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
    else
        log_info "Azure CLI already installed"
    fi

    # Ensure nvm/node is available
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    # Claude Code (Anthropic's CLI coding assistant)
    log_step "Installing Claude Code..."
    if ! command -v claude &> /dev/null; then
        npm install -g @anthropic-ai/claude-code
    else
        log_info "Claude Code already installed"
    fi

    # Codex CLI (OpenAI)
    log_step "Installing Codex CLI..."
    if ! command -v codex &> /dev/null; then
        npm install -g @openai/codex
    else
        log_info "Codex already installed"
    fi

    # Add Azure CLI completion to Zsh
    log_step "Adding Azure CLI completion to Zsh..."
    if ! grep -q 'az.completion' "$HOME/.zshrc"; then
        cat >> "$HOME/.zshrc" << 'EOF'

# Azure CLI completion
source /etc/bash_completion.d/azure-cli 2>/dev/null || true
EOF
    fi

    log_step "Phase 5 complete!"
    log_info "Remember to authenticate: 'az login' and 'claude' for API keys"
}

#===============================================================================
# PHASE 6: APPS & CLI TOOLS
#===============================================================================
phase_6_apps_tools() {
    log_phase "6" "Apps & Tools - VSCode Insiders, 1Password, Spotify, CLI Debug Tools"

    # Visual Studio Code Insiders (latest features)
    log_step "Installing Visual Studio Code Insiders..."
    if ! command -v code-insiders &> /dev/null; then
        # Remove any existing vscode sources to avoid signed-by conflicts
        sudo rm -f /etc/apt/sources.list.d/vscode.list
        sudo rm -f /etc/apt/sources.list.d/vscode.sources
        # Use consistent keyring location
        wget -qO- https://packages.microsoft.com/keys/microsoft.asc | \
            sudo gpg --dearmor -o /usr/share/keyrings/microsoft-vscode.gpg --yes
        echo "deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/microsoft-vscode.gpg] https://packages.microsoft.com/repos/code stable main" | \
            sudo tee /etc/apt/sources.list.d/vscode.list
        sudo apt update
        sudo apt install -y code-insiders
    else
        log_info "VSCode Insiders already installed"
    fi

    # 1Password Desktop
    log_step "Installing 1Password..."
    if ! command -v 1password &> /dev/null; then
        curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
            sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg --yes
        echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/amd64 stable main' | \
            sudo tee /etc/apt/sources.list.d/1password.list
        sudo mkdir -p /etc/debsig/policies/AC2D62742012EA22/
        curl -sS https://downloads.1password.com/linux/debian/debsig/1password.pol | \
            sudo tee /etc/debsig/policies/AC2D62742012EA22/1password.pol
        sudo mkdir -p /usr/share/debsig/keyrings/AC2D62742012EA22
        curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
            sudo gpg --dearmor --output /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg --yes
        sudo apt update
        sudo apt install -y 1password
    else
        log_info "1Password already installed"
    fi

    # Spotify
    log_step "Installing Spotify..."
    if ! command -v spotify &> /dev/null; then
        curl -sS https://download.spotify.com/debian/pubkey_C85668DF69375001.gpg | \
            sudo gpg --dearmor --output /usr/share/keyrings/spotify-archive-keyring.gpg --yes
        echo "deb [signed-by=/usr/share/keyrings/spotify-archive-keyring.gpg] https://repository.spotify.com stable non-free" | \
            sudo tee /etc/apt/sources.list.d/spotify.list
        sudo apt update
        sudo apt install -y spotify-client
    else
        log_info "Spotify already installed"
    fi

    # CLI Debug & Troubleshooting Tools
    log_step "Installing CLI debug and troubleshooting tools..."
    sudo apt install -y \
        htop \
        btop \
        ncdu \
        tree \
        jq \
        yq \
        httpie \
        net-tools \
        dnsutils \
        traceroute \
        mtr \
        tcpdump \
        nmap \
        iftop \
        iotop \
        sysstat \
        strace \
        lsof \
        nethogs \
        whois \
        ipcalc \
        fzf \
        ripgrep \
        fd-find \
        bat \
        eza \
        tldr

    # Create useful aliases
    log_step "Adding useful aliases to .zshrc..."
    if ! grep -q '# Cloud Architect aliases' "$HOME/.zshrc"; then
        cat >> "$HOME/.zshrc" << 'EOF'

# Cloud Architect aliases
alias code='code-insiders'
alias ll='eza -la --git'
alias cat='batcat'
alias fd='fdfind'
alias k='kubectl'
alias kns='kubens'
alias kctx='kubectx'
alias dc='docker compose'
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias azs='az account show --query "{name:name, id:id}" -o table'
alias tf='terraform'

# Quick system checks
alias ports='sudo lsof -i -P -n | grep LISTEN'
alias myip='curl -s ifconfig.me && echo'
alias diskspace='ncdu --color dark /'
EOF
    fi

    log_step "Phase 6 complete!"
}

#===============================================================================
# MAIN EXECUTION
#===============================================================================
main() {
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════════════════════════════╗"
    echo "║     Ubuntu 24.04 - Cloud Architect Workstation Setup             ║"
    echo "║     Stability • Enterprise • AI-Powered Development              ║"
    echo "╚═══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    if [[ -n "$PHASE_TO_RUN" ]]; then
        log_info "Running only Phase $PHASE_TO_RUN"
    else
        log_info "Running all phases (1-6)"
    fi

    should_run_phase "1" && phase_1_foundation
    should_run_phase "2" && phase_2_browsers
    should_run_phase "3" && phase_3_runtimes
    should_run_phase "4" && phase_4_containers
    should_run_phase "5" && phase_5_cloud_ai
    should_run_phase "6" && phase_6_apps_tools

    echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  SETUP COMPLETE!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "  1. Log out and back in (activates Zsh + Docker group)"
    echo "  2. Run 'az login' to authenticate Azure CLI"
    echo "  3. Run 'claude' to configure Claude Code API key"
    echo "  4. Run 'codex' to configure Codex API key"
    echo "  5. Open 1Password and sign in"
    echo "  6. Install VSCode Insiders extensions as needed"
    echo ""
    echo -e "${BLUE}Verification commands:${NC}"
    echo "  docker --version && kubectl version --client && az --version"
    echo "  node -v && npm -v && python3 --version"
    echo ""
}

main "$@"
