#!/bin/bash
#===============================================================================
# Bootstrap: Create GitHub repo and push the setup script
# Run this AFTER downloading and extracting ubuntu-cloud-architect-setup.zip
#===============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_step() { echo -e "${GREEN}[✓]${NC} $1"; }
log_info() { echo -e "${YELLOW}[i]${NC} $1"; }

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Bootstrap: Push to GitHub${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Install git if missing
if ! command -v git &> /dev/null; then
    log_step "Installing git..."
    sudo apt update && sudo apt install -y git
fi

# Install GitHub CLI if missing
if ! command -v gh &> /dev/null; then
    log_step "Installing GitHub CLI..."
    sudo mkdir -p -m 755 /etc/apt/keyrings
    wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
    sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
        sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt update
    sudo apt install -y gh
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    log_info "Please authenticate with GitHub..."
    gh auth login
fi

# Configure git identity if not set
if [ -z "$(git config --global user.name)" ]; then
    log_info "Setting up git identity..."
    echo -n "Enter your name for git commits: "
    read GIT_NAME
    echo -n "Enter your email for git commits: "
    read GIT_EMAIL
    git config --global user.name "$GIT_NAME"
    git config --global user.email "$GIT_EMAIL"
fi

# Initialize repo
cd "$(dirname "$0")"
log_step "Initializing git repository..."
git init

# Create GitHub repo and push
REPO_NAME="ubuntu-cloud-architect-setup"
log_step "Creating GitHub repository: $REPO_NAME..."

gh repo create "$REPO_NAME" --public --description "Ubuntu 24.04 LTS Cloud Architect Workstation Setup Script" --source=. --remote=origin --push

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Done! Repository created and pushed.${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
gh repo view --web
