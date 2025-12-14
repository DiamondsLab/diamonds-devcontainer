#!/bin/bash
# Diamonds Post-Start Script
# Runs every time the DevContainer starts

set -eu  # Exit on error, but allow unset variables with ${VAR:-} syntax
# Note: Not using pipefail to allow graceful handling of command failures

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check environment health
check_environment_health() {
    log_info "Checking environment health..."

    local issues_found=0

    # Check if we're in the right directory
    if [ ! -f "package.json" ]; then
        log_error "Not in project root directory"
        issues_found=$((issues_found + 1))
    fi

    # Check Node.js version
    if command -v node >/dev/null 2>&1; then
        local node_version
        node_version=$(node --version | sed 's/v//')
        local min_version="22.0.0"
        if printf '%s\n%s\n' "$min_version" "$node_version" | sort -V -C 2>/dev/null; then
            log_info "Node.js version: $node_version"
        else
            log_warning "Node.js version $node_version may be outdated (minimum: $min_version)"
        fi
    else
        log_error "Node.js not found"
        issues_found=$((issues_found + 1))
    fi

    # Check if dependencies are installed
    if [ ! -d "node_modules" ]; then
        log_warning "node_modules not found. Run 'yarn install'"
        issues_found=$((issues_found + 1))
    fi

    # Check if contracts are compiled
    if [ ! -d "artifacts" ]; then
        log_warning "Contracts not compiled. Run 'yarn compile'"
    fi

    if [ "$issues_found" -eq 0 ]; then
        log_success "Environment health check passed"
    else
        log_warning "Found $issues_found environment issues"
    fi
}

# Function to check for dependency updates
check_dependency_updates() {
    log_info "Checking for dependency updates..."

    if [ -f "yarn.lock" ]; then
        # Check if yarn install is needed
        if yarn check --silent >/dev/null 2>&1; then
            log_success "Dependencies are up to date"
        else
            log_info "Dependencies may need installation. Run 'yarn install' if needed."
        fi
    fi
}
tion to check security tools
check_security_tools() {
    log_info "Checking security tools status..."

    local tools_checked=0
    local tools_available=0

    # Check git-secrets
    tools_checked=$((tools_checked + 1))
    if command -v git-secrets >/dev/null 2>&1; then
        tools_available=$((tools_available + 1))
        log_info "✓ git-secrets available"
    fi

    # Check semgrep
    tools_checked=$((tools_checked + 1))
    if command -v semgrep >/dev/null 2>&1; then
        tools_available=$((tools_available + 1))
        log_info "✓ semgrep available"
    fi

    # Check snyk
    tools_checked=$((tools_checked + 1))
    if command -v snyk >/dev/null 2>&1; then
        tools_available=$((tools_available + 1))
        log_info "✓ snyk available"
    fi

    # Check socket
    tools_checked=$((tools_checked + 1))
    if command -v socket >/dev/null 2>&1; then
        tools_available=$((tools_available + 1))
        log_info "✓ socket available"
    fi

    # Check osv-scanner
    tools_checked=$((tools_checked + 1))
    if command -v osv-scanner >/dev/null 2>&1; then
        tools_available=$((tools_available + 1))
        log_info "✓ osv-scanner available"
    fi

    # Check slither
    tools_checked=$((tools_checked + 1))
    if command -v slither >/dev/null 2>&1; then
        tools_available=$((tools_available + 1))
        log_info "✓ slither available"
    fi

    log_info "Security tools: $tools_available/$tools_checked available"

    if [ "$tools_available" -lt "$tools_checked" ]; then
        log_warning "Some security tools are missing. They will be installed during post-attach."
    fi
}

# Function to check git status
check_git_status() {
    log_info "Checking git repository status..."

    if [ ! -d ".git" ]; then
        log_warning "Not in a git repository"
        return 0
    fi

    # Check if there are uncommitted changes
    if [ -n "$(git status --porcelain 2>/dev/null || true)" ]; then
        log_warning "Uncommitted changes detected"
    else
        log_success "Working directory is clean"
    fi

    # Check current branch
    local current_branch
    current_branch=$(git branch --show-current 2>/dev/null || echo "unknown")
    log_info "Current branch: $current_branch"

    # Check if branch is behind remote (with timeout to avoid hanging)
    # Use timeout command if available, otherwise skip this check
    if command -v timeout >/dev/null 2>&1; then
        if timeout 5s git fetch --quiet 2>/dev/null || true; then
            local behind_count
            behind_count=$(git rev-list HEAD...origin/"$current_branch" --count 2>/dev/null || echo "0")
            if [ "$behind_count" -gt 0 ] 2>/dev/null; then
                log_warning "Branch is $behind_count commits behind remote"
            fi
        else
            log_info "Skipped remote check (timeout or no network)"
        fi
    else
        log_info "Skipped remote check (timeout command not available)"
    fi
}

# Function to setup development server if needed
setup_development_server() {
    log_info "Checking development server setup..."

    # Check if Hardhat network should be running
    if [ "${START_HARDHAT_NETWORK:-false}" == "true" ]; then
        log_info "Starting Hardhat network in background..."

        # Get port from environment or use default
        local hardhat_port="${HARDHAT_PORT:-8555}"

        # Check if port is already in use
        if command -v lsof >/dev/null 2>&1; then
            if lsof -Pi :${hardhat_port} -sTCP:LISTEN -t >/dev/null 2>&1; then
                log_info "Hardhat network already running on port ${hardhat_port}"
                return 0
            fi
        else
            # Fallback: try to connect to the port
            if timeout 1s bash -c "cat < /dev/null > /dev/tcp/localhost/${hardhat_port}" 2>/dev/null; then
                log_info "Hardhat network already running on port ${hardhat_port}"
                return 0
            fi
        fi

        # Start Hardhat network
        if [ ! -d "logs" ]; then
            mkdir -p logs
        fi
        
        if nohup npx hardhat node > logs/hardhat-network.log 2>&1 & then
            log_success "Hardhat network started in background"
        else
            log_warning "Failed to start Hardhat network"
        fi
    fi
}

# Function to display welcome message
display_welcome_message() {
    echo
    log_success "Diamonds DevContainer is ready!"
    echo
    log_info "Available commands:"
    echo "  yarn test              - Run test suite"
    echo "  yarn compile           - Compile contracts"
    echo "  yarn security-check    - Run security scans"
    echo "  npx hardhat node       - Start local blockchain"
    echo "  npx hardhat test       - Run contract tests"
    echo "  yarn lint              - Run linting"
    echo "  yarn build             - Build project"
    echo
    log_info "Security tools:"
    echo "  git secrets --scan     - Scan for secrets"
    echo "  semgrep --config .semgrep.yml --scan ."
    echo "  slither .              - Analyze contracts"
    echo "  snyk test              - Check dependencies"
    echo
    log_info "Happy coding! 🚀"
}

# Function to auto-detect Vault configuration status
auto_detect_vault_status() {
    log_info "Auto-detecting Vault configuration status..."
    log_info "WORKSPACE_NAME: ${WORKSPACE_NAME:-not_set}"
    log_info "VAULT_ADDR: ${VAULT_ADDR:-not_set}"

    local vault_configured=true
    local recommendations=()

    # Check if Vault CLI is available
    log_info "Checking Vault CLI availability..."
    if ! command -v vault >/dev/null 2>&1; then
        vault_configured=false
        recommendations+=("Install Vault CLI: https://www.vaultproject.io/downloads")
        log_warning "Vault CLI not found"
    else
        log_info "Vault CLI is available"
    fi

    # Check VAULT_ADDR
    log_info "Checking VAULT_ADDR environment variable..."
    if [[ -z "${VAULT_ADDR:-}" ]]; then
        vault_configured=false
        recommendations+=("Set VAULT_ADDR environment variable (usually http://vault-dev:8200)")
        log_warning "VAULT_ADDR environment variable not set"
    else
        log_info "VAULT_ADDR is set to: $VAULT_ADDR"
    fi

    # Check if Vault server is accessible
    log_info "Checking Vault server accessibility..."
    if [[ -n "${VAULT_ADDR:-}" ]]; then
        log_info "Attempting to connect to Vault at: $VAULT_ADDR"
        if ! curl -s --max-time 3 "$VAULT_ADDR/v1/sys/health" >/dev/null 2>&1; then
            vault_configured=false
            recommendations+=("Start Vault server (may take a moment to initialize)")
            log_warning "Vault server not accessible at $VAULT_ADDR"
            log_info "curl command failed - checking if vault service is running..."
            # Check if vault process is running
            if pgrep -f "vault server" >/dev/null 2>&1; then
                log_info "Vault process is running but not responding to HTTP requests"
            else
                log_warning "No vault server process found running"
            fi
        else
            log_info "Vault server is accessible at $VAULT_ADDR"
        fi
    fi

    # Handle Vault configuration and mode detection
    log_info "Checking Vault configuration and mode detection..."
    if [[ -n "${VAULT_ADDR:-}" ]] && curl -s --max-time 3 "$VAULT_ADDR/v1/sys/health" >/dev/null 2>&1; then
        local vault_mode_conf="/workspaces/$WORKSPACE_NAME/.devcontainer/data/vault-mode.conf"
        log_info "Checking vault mode configuration file: $vault_mode_conf"

        if [[ -f "$vault_mode_conf" ]]; then
            log_info "Vault mode configuration file found, sourcing it..."
            # Source the configuration
            source "$vault_mode_conf"
            log_info "VAULT_MODE from config: ${VAULT_MODE:-ephemeral}"
            log_info "AUTO_UNSEAL from config: ${AUTO_UNSEAL:-false}"

            if [[ "${VAULT_MODE:-ephemeral}" == "persistent" ]]; then
                log_info "Detected Vault persistent mode configuration"

                # Check if raft directory is initialized
                local raft_db_path="/workspaces/$WORKSPACE_NAME/.devcontainer/data/vault-data/raft/raft.db"
                log_info "Checking for raft database at: $raft_db_path"

                if [[ ! -f "$raft_db_path" ]]; then
                    log_warning "⚠️  Vault is configured for persistent mode but raft.db not found at $raft_db_path"
                    log_info "Directory listing of vault-data:"
                    ls -la "/workspaces/$WORKSPACE_NAME/.devcontainer/data/vault-data/" 2>/dev/null || log_error "Could not list vault-data directory"
                    vault_configured=false
                    recommendations+=("Run vault-setup-wizard.sh to initialize persistent Vault")

                    echo ""
                    echo "═══════════════════════════════════════════════════════"
                    log_info "🔄 Initialize Persistent Vault:"
                    echo "═══════════════════════════════════════════════════════"
                    echo "  Vault is currently running in ephemeral mode for setup."
                    echo "  To initialize persistent storage:"
                    echo ""
                    echo "  1. Run the setup wizard:"
                    echo "     bash .devcontainer/scripts/setup/vault-setup-wizard.sh"
                    echo ""
                    echo "  2. Choose 'Initialize persistent Vault storage' when prompted"
                    echo "  3. Restart the DevContainer"
                    echo "═══════════════════════════════════════════════════════"
                    echo ""
                else
                    log_info "✅ Raft database found at $raft_db_path"
                    # Check seal status for initialized persistent mode
                    log_info "Checking Vault seal status..."
                    local seal_status=$(curl -s "$VAULT_ADDR/v1/sys/seal-status" | jq -r '.sealed' 2>/dev/null || echo "error")
                    log_info "Vault seal status response: $seal_status"

                    if [[ "$seal_status" == "true" ]]; then
                        log_warning "🔒 Vault is SEALED (persistent mode)"

                      if [[ "${AUTO_UNSEAL:-false}" == "true" ]]; then
                          log_info "Auto-unseal is enabled. Attempting to unseal Vault..."

                          local unseal_script="/workspaces/$WORKSPACE_NAME/.devcontainer/scripts/vault-auto-unseal.sh"
                          if [[ -f "$unseal_script" ]]; then
                              if bash "$unseal_script"; then
                                  log_success "✅ Vault auto-unsealed successfully!"
                              else
                                  log_error "Auto-unseal failed. Manual unsealing required."
                                  vault_configured=false
                                  recommendations+=("Unseal Vault manually - see instructions below")

                                  echo ""
                                  echo "═══════════════════════════════════════════════════════"
                                  log_info "🔒 Manual Unseal Instructions:"
                                  echo "═══════════════════════════════════════════════════════"
                                  echo "  1. Export VAULT_ADDR:"
                                  echo "     export VAULT_ADDR=$VAULT_ADDR"
                                  echo ""
                                  echo "  2. Quick unseal (uses first 3 keys):"
                                  echo "     cat .devcontainer/data/vault-unseal-keys.json | jq -r '.keys_base64[]' | head -n 3 | while read key; do vault operator unseal \$key; done"
                                  echo ""
                                  echo "  3. Or unseal manually (repeat 3 times with different keys):"
                                  echo "     vault operator unseal <key1>"
                                  echo "     vault operator unseal <key2>"
                                  echo "     vault operator unseal <key3>"
                                  echo ""
                                  echo "  4. View keys:"
                                  echo "     cat .devcontainer/data/vault-unseal-keys.json | jq -r '.keys_base64[]'"
                                  echo "═══════════════════════════════════════════════════════"
                                  echo ""
                              fi
                          else
                              log_error "Auto-unseal script not found: $unseal_script"
                              vault_configured=false
                          fi
                      else
                          log_info "Auto-unseal is disabled (manual unsealing required)"
                          vault_configured=false

                          echo ""
                          echo "═══════════════════════════════════════════════════════"
                          log_info "🔒 Vault Manual Unseal Required:"
                          echo "═══════════════════════════════════════════════════════"
                          echo "  Persistent Vault starts sealed for security."
                          echo "  You must unseal it before use."
                          echo ""
                          echo "  Quick unseal command:"
                          echo "    export VAULT_ADDR=$VAULT_ADDR"
                          echo "    cat .devcontainer/data/vault-unseal-keys.json | jq -r '.keys_base64[]' | head -n 3 | while read key; do vault operator unseal \$key; done"
                          echo ""
                          echo "  Or unseal manually (3 times):"
                          echo "    vault operator unseal <key1>"
                          echo "    vault operator unseal <key2>"
                          echo "    vault operator unseal <key3>"
                          echo ""
                          echo "  View unseal keys:"
                          echo "    cat .devcontainer/data/vault-unseal-keys.json | jq -r '.keys_base64[]'"
                          echo ""
                          echo "  To enable auto-unseal:"
                          echo "    Edit .devcontainer/data/vault-mode.conf"
                          echo "    Set: AUTO_UNSEAL=\"true\""
                          echo "═══════════════════════════════════════════════════════"
                          echo ""
                      fi
                    elif [[ "$seal_status" == "false" ]]; then
                        log_success "✅ Vault is unsealed and ready (persistent mode)"
                    elif [[ "$seal_status" == "error" ]]; then
                        log_warning "Could not determine Vault seal status"
                        vault_configured=false
                        recommendations+=("Check Vault server status and connectivity")
                    fi
                fi
            else
                log_info "Vault running in ephemeral mode (auto-initialized and unsealed)"
            fi
        else
            log_info "Vault mode configuration not found (assuming ephemeral mode)"
        fi
    else
        log_info "Vault server not accessible, skipping mode detection"
    fi

    # Check GitHub token
    if [[ -z "${GITHUB_TOKEN:-}" ]] && [[ ! -f ~/.config/gh/hosts.yml ]] && ! gh auth status >/dev/null 2>&1; then
        vault_configured=false
        recommendations+=("Set GITHUB_TOKEN or authenticate with GitHub CLI")
    fi

    # Check Vault authentication
    if command -v vault >/dev/null 2>&1 && [[ -n "${VAULT_ADDR:-}" ]]; then
        if ! vault status >/dev/null 2>&1; then
            vault_configured=false
            recommendations+=("Initialize Vault: /workspaces/$WORKSPACE_NAME/.devcontainer/scripts/vault-init.sh")
        elif ! vault token lookup >/dev/null 2>&1; then
            vault_configured=false
            recommendations+=("Authenticate with Vault: vault login -method=github token=\$GITHUB_TOKEN")
        fi
    fi

    # Check if secrets exist
    if command -v vault >/dev/null 2>&1 && vault status >/dev/null 2>&1 && vault token lookup >/dev/null 2>&1; then
        if ! vault kv list secret/dev >/dev/null 2>&1; then
            recommendations+=("Migrate secrets to Vault: ./.devcontainer/scripts/setup/migrate-secrets-to-vault.sh")
        fi
    fi

    # Report status
    if [[ "$vault_configured" == "true" ]]; then
        log_success "Vault is properly configured and ready to use"

        # Show quick commands
        echo ""
        log_info "Quick Vault commands:"
        echo "  • View secrets: vault kv list secret/dev"
        echo "  • Add secret: vault kv put secret/dev/KEY value=VALUE"
        echo "  • Get secret: vault kv get secret/dev/KEY"
        echo "  • Validate setup: ./.devcontainer/scripts/validate-vault-setup.sh"
    else
        log_warning "Vault configuration needs attention"

        # Show recommendations
        echo ""
        log_info "To complete Vault setup:"
        for rec in "${recommendations[@]}"; do
            echo "  • $rec"
        done

        # Offer to run setup wizard
        echo ""
        if [[ -t 0 ]] && [[ -f "/workspaces/$WORKSPACE_NAME/.devcontainer/scripts/setup/vault-setup-wizard.sh" ]]; then
            echo -e "${YELLOW}Would you like to run the interactive setup wizard? (y/N): ${NC}\c"
            read -r response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                log_info "Starting Vault setup wizard..."
                /workspaces/$WORKSPACE_NAME/.devcontainer/scripts/setup/vault-setup-wizard.sh
            fi
        else
            log_info "Run setup wizard: .devcontainer/scripts/setup/vault-setup-wizard.sh"
        fi
    fi
}

# Function to refresh secrets from Vault if they've been updated
refresh_vault_secrets() {
    log_info "Checking for updated Vault secrets..."

    local vault_script="/workspaces/$WORKSPACE_NAME/.devcontainer/scripts/vault-fetch-secrets.sh"
    local last_refresh_file="/tmp/vault-secrets-last-refresh"

    # Check if vault script exists
    if [[ ! -f "$vault_script" ]]; then
        log_info "Vault script not found, skipping secret refresh"
        return 0
    fi

    # Check if we should refresh (every 5 minutes or if forced)
    local current_time
    current_time=$(date +%s)
    local last_refresh=0

    if [[ -f "$last_refresh_file" ]]; then
        last_refresh=$(cat "$last_refresh_file" 2>/dev/null || echo 0)
    fi

    local time_diff=$((current_time - last_refresh))
    local refresh_interval=300  # 5 minutes

    if [[ $time_diff -lt $refresh_interval ]]; then
        log_info "Secrets were refreshed recently ($((time_diff / 60)) minutes ago), skipping"
        return 0
    fi

    # Check if Vault is accessible and we have secrets
    if command -v vault >/dev/null 2>&1 && [[ -n "${VAULT_ADDR:-}" ]]; then
        if vault status >/dev/null 2>&1 && vault kv list secret/dev >/dev/null 2>&1; then
            log_info "Refreshing secrets from Vault..."
            if "$vault_script" --quiet; then
                echo "$current_time" > "$last_refresh_file"
                log_success "Vault secrets refreshed successfully"
            else
                log_warning "Failed to refresh Vault secrets"
            fi
        else
            log_info "Vault not accessible or no secrets available"
        fi
    else
        log_info "Vault not configured, skipping secret refresh"
    fi
}

# Function to run startup health checks
run_startup_health_checks() {
    log_info "Running startup health checks..."

    # Check Vault configuration status
    auto_detect_vault_status

    # Refresh secrets if needed
    refresh_vault_secrets

    # Quick compilation check
    if [ -d "artifacts" ] && [ -d "diamond-abi" ]; then
        log_success "Contracts appear to be compiled"
    else
        log_info "Contracts may need compilation. Run 'yarn compile'"
    fi

    # Check if TypeScript types are generated
    if [ -d "typechain-types" ] && [ -d "diamond-typechain-types" ]; then
        log_success "TypeChain types are generated"
    else
        log_info "TypeChain types may need generation. Run 'yarn compile'"
    fi
}

# Main execution
main() {
    log_info "Starting Diamonds post-start initialization..."

    # Run all setup functions
    check_environment_health
    check_dependency_updates
    check_security_tools
    check_git_status
    setup_development_server
    run_startup_health_checks

    # Display welcome message
    display_welcome_message
}

# Run main function
main "$@"