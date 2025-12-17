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
#
# PHASES:
#   1 - Foundation (system update, core deps, Zsh + Oh My Zsh)
#   2 - Browsers (Brave as default, Edge for O365/Teams)
#   3 - Dev Runtimes (Python, nvm + Node LTS)
#   4 - Containers & K8s (Docker, kubectl, helm, k9s, kubectx)
#   5 - Cloud & AI (Azure CLI, Claude Code, Codex)
#   6 - Apps & Tools (VSCode, 1Password, Spotify, CLI debug tools)
#
#===============================================================================

set -e  # Exit on any error

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
while [[ $# -gt 0 ]]; do
    case $1 in
        --phase) PHASE_TO_RUN="$2"; shift 2 ;;
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
    log_phase "1" "Foundation - System Update, Core Dependencies, Zsh"

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

    # Configure .zshrc with plugins (will be updated in later phases)
    log_step "Configuring .zshrc with initial plugins..."
    sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' "$HOME/.zshrc"

    # Set Zsh as default shell
    log_step "Setting Zsh as default shell..."
    sudo chsh -s $(which zsh) $USER

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
            sudo gpg --dearmor -o /usr/share/keyrings/microsoft-edge.gpg
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

    # Add user to docker group (no sudo needed for docker commands)
    log_step "Adding $USER to docker group..."
    sudo usermod -aG docker $USER

    # kubectl
    log_step "Installing kubectl..."
    if ! command -v kubectl &> /dev/null; then
        curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | \
            sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
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

    # k9s (Kubernetes TUI)
    log_step "Installing k9s..."
    if ! command -v k9s &> /dev/null; then
        K9S_VERSION=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | grep tag_name | cut -d '"' -f 4)
        curl -fsSL "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_amd64.tar.gz" | \
            sudo tar xzf - -C /usr/local/bin k9s
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

    # Update .zshrc with kubectl and docker plugins
    log_step "Adding kubectl and docker plugins to Zsh..."
    sed -i 's/plugins=(git/plugins=(git kubectl docker docker-compose kubectx/' "$HOME/.zshrc"

    log_step "Phase 4 complete! (Logout/login to use docker without sudo)"
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
    log_phase "6" "Apps & Tools - VSCode, 1Password, Spotify, CLI Debug Tools"

    # Visual Studio Code
    log_step "Installing Visual Studio Code..."
    if ! command -v code &> /dev/null; then
        wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
        sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
        echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | \
            sudo tee /etc/apt/sources.list.d/vscode.list
        rm -f packages.microsoft.gpg
        sudo apt update
        sudo apt install -y code
    else
        log_info "VSCode already installed"
    fi

    # 1Password Desktop
    log_step "Installing 1Password..."
    if ! command -v 1password &> /dev/null; then
        curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
            sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
        echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/amd64 stable main' | \
            sudo tee /etc/apt/sources.list.d/1password.list
        sudo mkdir -p /etc/debsig/policies/AC2D62742012EA22/
        curl -sS https://downloads.1password.com/linux/debian/debsig/1password.pol | \
            sudo tee /etc/debsig/policies/AC2D62742012EA22/1password.pol
        sudo mkdir -p /usr/share/debsig/keyrings/AC2D62742012EA22
        curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
            sudo gpg --dearmor --output /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg
        sudo apt update
        sudo apt install -y 1password
    else
        log_info "1Password already installed"
    fi

    # Spotify
    log_step "Installing Spotify..."
    if ! command -v spotify &> /dev/null; then
        curl -sS https://download.spotify.com/debian/pubkey_C85668DF69375001.gpg | \
            sudo gpg --dearmor --output /usr/share/keyrings/spotify-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/spotify-archive-keyring.gpg] http://repository.spotify.com stable non-free" | \
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
        exa \
        tldr

    # Create useful aliases
    log_step "Adding useful aliases to .zshrc..."
    if ! grep -q '# Cloud Architect aliases' "$HOME/.zshrc"; then
        cat >> "$HOME/.zshrc" << 'EOF'

# Cloud Architect aliases
alias ll='exa -la --git'
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
    echo "  6. Install VSCode extensions as needed"
    echo ""
    echo -e "${BLUE}Verification commands:${NC}"
    echo "  docker --version && kubectl version --client && az --version"
    echo "  node -v && npm -v && python3 --version"
    echo ""
}

main "$@"
