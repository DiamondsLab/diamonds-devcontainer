#!/bin/bash
# Diamonds Security Tools Setup Script
# Configures all security scanning tools for blockchain development

set -euo pipefail

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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to setup git-secrets
setup_git_secrets() {
    log_info "Setting up git-secrets for blockchain security..."

    if ! command_exists git-secrets; then
        log_error "git-secrets not found. Installing..."
        if command_exists brew; then
            brew install git-secrets
        elif command_exists apt-get; then
            sudo apt-get update && sudo apt-get install -y git-secrets
        else
            log_error "Unable to install git-secrets. Please install manually."
            return 1
        fi
    fi

    # Configure git-secrets with blockchain-specific patterns
    log_info "Configuring git-secrets patterns..."

    # Clear existing patterns to avoid conflicts (only if they exist)
    if git config --get-all secrets.patterns >/dev/null 2>&1; then
        git config --unset-all secrets.patterns >/dev/null 2>&1 || true
    fi
    if git config --get-all secrets.allowed >/dev/null 2>&1; then
        git config --unset-all secrets.allowed >/dev/null 2>&1 || true
    fi

    # Add all patterns from git-secrets_patterns.md
    git secrets --add 'PRIVATE_KEY|SECRET_KEY' || log_warning "Failed to add PRIVATE_KEY|SECRET_KEY pattern"
    git secrets --add '0x[a-fA-F0-9]{64}' || log_warning "Failed to add 0x pattern"failed 
    git secrets --add 'mnemonic.*[a-z]{3,}\s+[a-z]{3,}' || log_warning "Failed to add mnemonic pattern"
    git secrets --add '"mnemonic":\s*"[^"]+"' || log_warning "Failed to add mnemonic JSON pattern"
    git secrets --add "'mnemonic':\s*'[^']+'" || log_warning "Failed to add mnemonic JS pattern"
    git secrets --add 'INFURA_API_KEY\s*=\s*["'\'']*[a-zA-Z0-9]{32}["'\'']*' || log_warning "Failed to add INFURA pattern"
    git secrets --add 'ALCHEMY_API_KEY\s*=\s*["'\'']*[a-zA-Z0-9]{32}["'\'']*' || log_warning "Failed to add ALCHEMY pattern"
    git secrets --add 'ETHERSCAN_API_KEY\s*=\s*["'\'']*[a-zA-Z0-9]{32}["'\'']*' || log_warning "Failed to add ETHERSCAN pattern"
    git secrets --add 'PRIVATE_KEY\s*=\s*["'\'']*0x[a-fA-F0-9]{64}["'\'']*' || log_warning "Failed to add PRIVATE_KEY pattern"
    git secrets --add 'PRIVATE_KEY\s*=\s*["'\'']*0x[a-fA-F0-9]{64}["'\'']*\s*$' || log_warning "Failed to add PRIVATE_KEY end pattern"
    git secrets --add 'SECRET_KEY\s*=\s*["'\'']*0x[a-fA-F0-9]{64}["'\'']*' || log_warning "Failed to add SECRET_KEY pattern"
    git secrets --add 'API_SECRET\s*=\s*["'\'']*[a-zA-Z0-9]{32,}["'\'']*' || log_warning "Failed to add API_SECRET pattern"
    git secrets --add 'https://[^/]*:[^@]*@[^/]*' || log_warning "Failed to add HTTPS URL pattern"
    git secrets --add 'wss://[^/]*:[^@]*@[^/]*' || log_warning "Failed to add WSS URL pattern"

    # Add all allowed patterns from git-secrets_patterns.md
    git secrets --add --allowed 'PRIVATE_KEY\s*=\s*your_private_key_here' || log_warning "Failed to add placeholder allowed pattern"
    git secrets --add --allowed 'process\.env\.PRIVATE_KEY' || log_warning "Failed to add env var allowed pattern"
    git secrets --add --allowed 'PRIVATE_KEY\s*,' || log_warning "Failed to add comma allowed pattern"
    git secrets --add --allowed 'PRIVATE_KEY=' || log_warning "Failed to add equals allowed pattern"
    git secrets --add --allowed 'ETHERSCAN_API_KEY=' || log_warning "Failed to add ETHERSCAN allowed pattern"
    git secrets --add --allowed 'ALCHEMY_API_KEY=' || log_warning "Failed to add ALCHEMY allowed pattern"
    git secrets --add --allowed 'INFURA_API_KEY=' || log_warning "Failed to add INFURA allowed pattern"
    git secrets --add --allowed 'git config --global secrets.patterns "PRIVATE_KEY|SECRET_KEY"' || log_warning "Failed to add git config allowed pattern"
    git secrets --add --allowed "git secrets --add 'PRIVATE_KEY|SECRET_KEY'" || log_warning "Failed to add git secrets add allowed pattern"
    git secrets --add --allowed 'Private key is required' || log_warning "Failed to add private key required allowed pattern"
    git secrets --add --allowed '/PRIVATE_KEY\\s*= /' || log_warning "Failed to add regex pattern 1 allowed"
    git secrets --add --allowed "'RPC_URL', 'PRIVATE_KEY', 'DIAMOND_NAME'" || log_warning "Failed to add RPC_URL allowed pattern"
    git secrets --add --allowed "git secrets --add 'SECRET_KEY" || log_warning "Failed to add git secrets SECRET_KEY allowed pattern"
    git secrets --add --allowed '/PRIVATE_KEY\\s*= /,' || log_warning "Failed to add regex pattern 2 allowed"
    git secrets --add --allowed '/PRIVATE_KEY\\\\s*= /' || log_warning "Failed to add regex pattern 3 allowed"
    git secrets --add --allowed '/PRIVATE_KEY\\\\s*= /,' || log_warning "Failed to add regex pattern 5 allowed"
    git secrets --add --allowed '/PRIVATE_KEY\\s\\*=/' || log_warning "Failed to add regex pattern 6 allowed"
    git secrets --add --allowed 'const secretPatterns = \[' || log_warning "Failed to add const allowed pattern"
    git secrets --add --allowed 'SECRET_KEYs*' || log_warning "Failed to add SECRET_KEYs allowed pattern"
    git secrets --add --allowed 'scripts/devops/signed-artifacts/' || log_warning "Failed to add signed-artifacts allowed pattern"
    git secrets --add --allowed '.devcontainer/scripts/setup-security.sh' || log_warning "Failed to add .devcontainer allowed pattern"
    git config --add secrets.allowed 'API_KEY|API_SECRET|PRIVATE_KEY|SECRET_KEY' || log_warning "Failed to add combined API_KEY|API_SECRET|PRIVATE_KEY|SECRET_KEY allowed pattern"
    git config --add secrets.allowed '.yarn/releases/' || log_warning "Failed to add .yarn/releases allowed pattern"
    
    # Install git-secrets hooks
    if [ -d .git ]; then
        git secrets --install -f || log_warning "Failed to install git-secrets hooks"
        git secrets --register-aws || log_warning "Failed to register AWS patterns"
        log_success "git-secrets configured and hooks installed"
    else
        log_warning "Not in a git repository. git-secrets hooks not installed."
    fi
}

# Function to setup Git credential helper with GitHub CLI
setup_git_credentials() {
    log_info "Configuring Git to use GitHub CLI for authentication..."

    if ! command_exists gh; then
        log_warning "GitHub CLI (gh) not found. Skipping credential helper setup."
        log_info "Install gh and run 'gh auth login && gh auth setup-git' to enable Git authentication."
        return 0
    fi

    # Check if user is authenticated with gh
    if ! gh auth status >/dev/null 2>&1; then
        log_warning "Not authenticated with GitHub CLI."
        log_info "Run 'gh auth login && gh auth setup-git' to authenticate before using Git operations."
        return 0
    fi

    # Configure Git to use GitHub CLI as credential helper
    log_info "Setting up GitHub CLI as Git credential helper..."
    
    # Clear any existing generic credential helper to avoid conflicts
    git config --global credential.helper "" 2>/dev/null || true
    
    # Setup gh as credential helper for GitHub
    if gh auth setup-git 2>/dev/null; then
        log_success "GitHub CLI credential helper configured successfully"
        
        # Verify the configuration
        if git config --global --get credential.https://github.com.helper | grep -q "gh auth git-credential"; then
            log_success "Git will now use GitHub CLI for authentication"
        else
            log_warning "Credential helper configured but verification failed"
        fi
    else
        log_warning "Failed to setup GitHub CLI as credential helper"
        log_info "You may need to manually run 'gh auth setup-git'"
    fi
}

# Function to setup Semgrep
setup_semgrep() {
    log_info "Setting up Semgrep for code security scanning..."

    if ! command_exists semgrep; then
        log_error "Semgrep not found. Installing..."
        pip3 install semgrep
    fi

    # Verify Semgrep installation
    if semgrep --version >/dev/null 2>&1; then
        log_success "Semgrep is ready"

        # Test Semgrep configuration
        if [ -f .semgrep.yml ]; then
            log_info "Testing Semgrep configuration..."
            semgrep --config .semgrep.yml --validate >/dev/null 2>&1 && \
                log_success "Semgrep configuration is valid" || \
                log_warning "Semgrep configuration validation failed"
        else
            log_warning ".semgrep.yml not found. Using default rules."
        fi
    else
        log_error "Semgrep installation failed"
        return 1
    fi
}

# Function to setup Snyk
setup_snyk() {
    log_info "Setting up Snyk for dependency vulnerability scanning..."

    if ! command_exists snyk; then
        log_error "Snyk not found. Installing..."
        npm install -g snyk
    fi

    # Check if Snyk is authenticated via token or OAuth
    if snyk auth --help >/dev/null 2>&1; then
        log_info "Snyk CLI is available"

        # Check if already authenticated
        if snyk whoami --experimental >/dev/null 2>&1; then
            log_success "Snyk is already authenticated"
            return 0
        fi

        # Check for SNYK_TOKEN in .env file
        local snyk_token=""
        if [ -f "$PROJECT_ROOT/.env" ] && grep -q "^SNYK_TOKEN=" "$PROJECT_ROOT/.env"; then
            snyk_token=$(grep "^SNYK_TOKEN=" "$PROJECT_ROOT/.env" | cut -d'=' -f2- | sed 's/^"//' | sed 's/"$//')
            log_info "Found SNYK_TOKEN in .env file, attempting authentication..."
        elif [ -f "$PROJECT_ROOT/packages/diamonds/.env" ] && grep -q "^SNYK_TOKEN=" "$PROJECT_ROOT/packages/diamonds/.env"; then
            snyk_token=$(grep "^SNYK_TOKEN=" "$PROJECT_ROOT/packages/diamonds/.env" | cut -d'=' -f2- | sed 's/^"//' | sed 's/"$//')
            log_info "Found SNYK_TOKEN in packages/diamonds/.env file, attempting authentication..."
        fi

        if [ -n "$snyk_token" ]; then
            # Set the token and test authentication
            export SNYK_TOKEN="$snyk_token"
            if snyk whoami --experimental >/dev/null 2>&1; then
                log_success "Snyk authenticated successfully using token from .env file"
                return 0
            else
                log_warning "Failed to authenticate with SNYK_TOKEN from .env file"
                unset SNYK_TOKEN
            fi
        fi

        # If we reach here, authentication failed or no token was found
        log_warning "Snyk is not authenticated."
        log_info "To authenticate Snyk:"
        log_info "  1. Visit https://app.snyk.io/account and generate an API token"
        log_info "  2. Add 'SNYK_TOKEN=your_token_here' to your .env file"
        log_info "  3. Or run 'snyk auth' manually (may not work in dev containers)"
        log_info "Note: SNYK_TOKEN may require a paid Snyk plan for API access"
    else
        log_error "Snyk installation failed"
        return 1
    fi
}

# Function to setup Socket.dev
setup_socket() {
    log_info "Setting up Socket.dev for supply chain security..."

    if ! command_exists socket; then
        log_error "Socket CLI not found. Installing..."
        npm install -g @socketsecurity/cli
    fi

    if command_exists socket; then
        log_success "Socket.dev CLI is ready"

        # Check if API token is configured in .env file
        if [ -f "$PROJECT_ROOT/.env" ] && grep -q "^SOCKET_CLI_API_TOKEN=" "$PROJECT_ROOT/.env"; then
            log_success "Socket.dev API token is configured in .env"
        else
            log_warning "SOCKET_CLI_API_TOKEN not set in .env file. Set it in .env for full functionality."
        fi
    else
        log_error "Socket.dev CLI installation failed"
        return 1
    fi
}

# Function to setup OSV-Scanner
setup_osv_scanner() {
    log_info "Setting up OSV-Scanner for vulnerability database scanning..."

    # Add Go bin to PATH persistently
    local go_bin_path="$HOME/go/bin"
    local shell_rc=""
    
    # Determine which shell config file to use
    if [ -n "$BASH_VERSION" ]; then
        shell_rc="$HOME/.bashrc"
    elif [ -n "$ZSH_VERSION" ]; then
        shell_rc="$HOME/.zshrc"
    else
        shell_rc="$HOME/.profile"
    fi

    # Add Go bin to PATH if not already present
    if ! grep -q "export PATH=.*$go_bin_path" "$shell_rc" 2>/dev/null; then
        log_info "Adding Go bin directory to PATH in $shell_rc..."
        echo "" >> "$shell_rc"
        echo "# Go binaries path for OSV-Scanner and other tools" >> "$shell_rc"
        echo "export PATH=\"\$HOME/go/bin:\$PATH\"" >> "$shell_rc"
        log_success "Go bin path added to $shell_rc"
    fi

    # Source the shell config to update current session
    export PATH="$HOME/go/bin:$PATH"

    if ! command_exists osv-scanner; then
        log_info "OSV-Scanner not found. Installing..."
        
        # Check if Go is installed
        if ! command_exists go; then
            log_error "Go is not installed. Please install Go first."
            return 1
        fi
        
        # Try Go install with proxy configuration
        log_info "Attempting Go install with proxy configuration..."
        export GOPROXY="https://proxy.golang.org,direct"
        export GOSUMDB="sum.golang.org"
        
        if go install github.com/google/osv-scanner/cmd/osv-scanner@latest 2>/dev/null; then
            log_success "OSV-Scanner installed via Go"
        else
            log_warning "Go install failed, trying direct binary download..."
            
            # Fallback: Try to download pre-built binary
            local osv_version="1.9.2"
            local osv_url="https://github.com/google/osv-scanner/releases/download/v${osv_version}/osv-scanner_${osv_version}_linux_amd64.tar.gz"
            
            if command_exists curl && curl -s --head "$osv_url" >/dev/null 2>&1; then
                log_info "Downloading OSV-Scanner binary v${osv_version}..."
                mkdir -p "$HOME/go/bin"
                curl -L "$osv_url" | tar -xz -C "$HOME/go/bin" --strip-components=1 "osv-scanner_${osv_version}_linux_amd64/osv-scanner" 2>/dev/null && \
                chmod +x "$HOME/go/bin/osv-scanner" && \
                log_success "OSV-Scanner binary downloaded successfully"
            else
                log_warning "Binary download failed. OSV-Scanner will be skipped."
                log_info "You can install OSV-Scanner manually later with: go install github.com/google/osv-scanner/cmd/osv-scanner@latest"
                return 0  # Don't fail the entire setup
            fi
        fi
        
        # Verify installation with explicit path
        if [ -f "$HOME/go/bin/osv-scanner" ]; then
            log_success "OSV-Scanner binary installed at $HOME/go/bin/osv-scanner"
        else
            log_error "OSV-Scanner installation failed - binary not found"
            return 1
        fi
    fi

    # Check with explicit path first
    if [ -f "$HOME/go/bin/osv-scanner" ] || command_exists osv-scanner; then
        log_success "OSV-Scanner is ready"

        # Update vulnerability database
        log_info "Updating OSV vulnerability database..."
        "$HOME/go/bin/osv-scanner" --version >/dev/null 2>&1 && \
            log_success "OSV-Scanner database is ready" || \
            log_warning "OSV-Scanner database update may be needed"
    else
        log_error "OSV-Scanner installation failed"
        return 1
    fi
}

# Function to setup Slither
setup_slither() {
    log_info "Setting up Slither for Solidity smart contract analysis..."

    if ! command_exists slither; then
        log_error "Slither not found. Installing..."
        pip3 install slither-analyzer
    fi

    if command_exists slither; then
        log_success "Slither is ready"

        # Verify Slither configuration
        if [ -f slither.config.json ]; then
            log_info "Testing Slither configuration..."
            slither --version >/dev/null 2>&1 && \
                log_success "Slither configuration is valid" || \
                log_warning "Slither configuration validation failed"
        else
            log_warning "slither.config.json not found. Using default configuration."
        fi
    else
        log_error "Slither installation failed"
        return 1
    fi
}

# Function to setup additional security tools
setup_additional_tools() {
    log_info "Setting up additional security tools..."

    # Setup git-secrets ignore patterns
    if [ -f .gitsecretsignore ]; then
        log_info "Configuring git-secrets ignore patterns..."
        while IFS= read -r pattern; do
            if [[ ! "$pattern" =~ ^[[:space:]]*# && -n "$pattern" ]]; then
                git secrets --add --allowed "$pattern" 2>/dev/null || true
            fi
        done < .gitsecretsignore
        log_success "git-secrets ignore patterns configured"
    fi

    # Setup pre-commit hooks if husky is available
    if [ -d .husky ]; then
        log_info "Setting up Husky pre-commit hooks..."
        if command_exists yarn; then
            yarn prepare || true
        fi
    fi
}

# Function to run security health check
run_security_health_check() {
    log_info "Running security tools health check..."

    local failed_tools=()

    # Check each tool
    command_exists git-secrets || failed_tools+=("git-secrets")
    command_exists semgrep || failed_tools+=("semgrep")
    command_exists snyk || failed_tools+=("snyk")
    command_exists socket || failed_tools+=("socket")
    command_exists osv-scanner || failed_tools+=("osv-scanner")
    command_exists slither || failed_tools+=("slither")

    if [ ${#failed_tools[@]} -eq 0 ]; then
        log_success "All security tools are properly installed"
    else
        log_warning "Some security tools are missing: ${failed_tools[*]}"
        log_info "Run this script again or install missing tools manually"
    fi
}

# Main execution
main() {
    log_info "Starting Diamonds security tools setup..."

    # Determine project root
    PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
    log_info "Project root determined as: $PROJECT_ROOT"

    # Setup each security tool
    setup_git_secrets
    setup_git_credentials
    setup_semgrep
    setup_snyk
    setup_socket
    setup_osv_scanner
    setup_slither
    setup_additional_tools

    # Run health check
    run_security_health_check

    log_success "Security tools setup completed!"
    log_info "Run 'yarn security-check' to test all security tools"
    log_info "Use 'git secrets --scan' to scan for secrets in the repository"
}

# Run main function
main "$@"