#!/bin/bash
# Vault Initialization Script for Diamonds DevContainer
# Initializes HashiCorp Vault dev server with GitHub authentication and policies

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
VAULT_ADDR="${VAULT_ADDR:-http://vault-dev:8200}"
VAULT_TOKEN="${VAULT_TOKEN:-root}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
UNSEAL_KEYS_FILE="${PROJECT_ROOT}/.devcontainer/data/vault-unseal-keys.json"
VAULT_MODE_CONF="${PROJECT_ROOT}/.devcontainer/data/vault-mode.conf"

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

# Wait for Vault to be ready
wait_for_vault() {
    local max_attempts=30
    local attempt=1

    log_info "Waiting for Vault to be ready..."
    while [ $attempt -le $max_attempts ]; do
        if curl -s "${VAULT_ADDR}/v1/sys/health" > /dev/null 2>&1; then
            log_success "Vault is ready!"
            return 0
        fi

        log_info "Attempt $attempt/$max_attempts: Vault not ready yet..."
        sleep 2
        ((attempt++))
    done

    log_error "Vault failed to start after $max_attempts attempts"
    return 1
}

# Initialize Vault in persistent mode (operator init)
initialize_persistent_vault() {
    log_info "Initializing Vault in persistent mode..."
    
    # Check if Vault is already initialized
    local init_status=$(curl -s "$VAULT_ADDR/v1/sys/health" | jq -r '.initialized' 2>/dev/null || echo "false")
    
    if [[ "$init_status" == "true" ]]; then
        log_success "Vault is already initialized"
        
        # Check if unseal keys file exists
        if [[ ! -f "$UNSEAL_KEYS_FILE" ]]; then
            log_warning "⚠️  Vault is initialized but unseal keys file not found"
            log_warning "⚠️  If Vault was initialized outside this script, you may need to manually create:"
            log_warning "⚠️  $UNSEAL_KEYS_FILE"
        fi
        
        return 0
    fi
    
    log_info "Performing initial Vault operator init..."
    
    # Initialize Vault using HTTP API (returns unseal keys and root token)
    local init_response=$(curl -s -X PUT "$VAULT_ADDR/v1/sys/init" \
        -d '{
            "secret_shares": 5,
            "secret_threshold": 3
        }' 2>/dev/null)
    
    # Check if initialization was successful
    if [[ -z "$init_response" ]] || ! echo "$init_response" | jq -e '.keys' >/dev/null 2>&1; then
        log_error "Failed to initialize Vault"
        log_error "Response: $init_response"
        return 1
    fi
    
    # Save unseal keys to file
    log_info "Saving unseal keys to $UNSEAL_KEYS_FILE..."
    echo "$init_response" | jq '{
        keys: .keys,
        keys_base64: .keys_base64,
        root_token: .root_token,
        created_at: now | strftime("%Y-%m-%d %H:%M:%S UTC")
    }' > "$UNSEAL_KEYS_FILE"
    
    # Secure the file (owner read/write only)
    chmod 600 "$UNSEAL_KEYS_FILE"
    log_success "✅ Unseal keys saved and secured (chmod 600)"
    
    # Extract root token for subsequent operations
    VAULT_TOKEN=$(echo "$init_response" | jq -r '.root_token')
    export VAULT_TOKEN
    
    log_success "✅ Vault initialized successfully!"
    log_info "Root token: $VAULT_TOKEN"
    
    # Unseal Vault using first 3 keys
    log_info "Unsealing Vault..."
    local unseal_keys
    mapfile -t unseal_keys < <(echo "$init_response" | jq -r '.keys_base64[]' | head -n 3)
    
    for i in "${!unseal_keys[@]}"; do
        local key="${unseal_keys[$i]}"
        log_info "Unsealing with key $((i+1))/3..."
        
        local unseal_response=$(curl -s -X PUT -d "{\"key\":\"$key\"}" "$VAULT_ADDR/v1/sys/unseal")
        local sealed=$(echo "$unseal_response" | jq -r '.sealed')
        local progress=$(echo "$unseal_response" | jq -r '.progress')
        local threshold=$(echo "$unseal_response" | jq -r '.t')
        
        log_info "Unseal progress: $progress/$threshold"
        
        if [[ "$sealed" == "false" ]]; then
            log_success "✅ Vault unsealed successfully!"
            break
        fi
    done
    
    return 0
}

# Initialize Vault with GitHub authentication
setup_github_auth() {
    log_info "Setting up GitHub authentication method..."

    # Enable GitHub auth method using HTTP API
    curl -s -X POST \
        -H "X-Vault-Token: $VAULT_TOKEN" \
        -d '{"type": "github"}' \
        "$VAULT_ADDR/v1/sys/auth/github" || {
        log_warning "GitHub auth method already enabled or failed to enable"
    }

    # Configure GitHub auth with organization
    # TODO: This needs to be configured or picked up from git via `gh` client to supply the actual organization
    # It shouldn't be referencing diamondlabs directly but could also look to a variety of .env or config files including the `~/.vault_token` or `.vault_token` file in the project root.
    curl -s -X POST \
        -H "X-Vault-Token: $VAULT_TOKEN" \
        -d '{
            "organization": "diamondlabs",
            "base_url": "https://api.github.com"
        }' \
        "$VAULT_ADDR/v1/auth/github/config" || {
        log_error "Failed to configure GitHub auth"
        return 1
    }

    log_success "GitHub authentication configured"
}

# Create Vault policies
create_policies() {
    log_info "Creating Vault policies..."

    # Developer policy - read/write access to dev secrets
    DEV_POLICY='{
        "policy": "path \"secret/dev/*\" {\n  capabilities = [\"create\", \"read\", \"update\", \"delete\", \"list\"]\n}\n\npath \"secret/test/*\" {\n  capabilities = [\"create\", \"read\", \"update\", \"delete\", \"list\"]\n}"
    }'

    curl -s -X PUT \
        -H "X-Vault-Token: $VAULT_TOKEN" \
        -d "$DEV_POLICY" \
        "$VAULT_ADDR/v1/sys/policies/acl/dev-policy" || {
        log_error "Failed to create dev policy"
        return 1
    }

    # CI policy - read access to all secrets, write access to ci secrets
    CI_POLICY='{
        "policy": "path \"secret/ci/*\" {\n  capabilities = [\"create\", \"read\", \"update\", \"delete\", \"list\"]\n}\n\npath \"secret/dev/*\" {\n  capabilities = [\"read\", \"list\"]\n}\n\npath \"secret/test/*\" {\n  capabilities = [\"read\", \"list\"]\n}"
    }'

    curl -s -X PUT \
        -H "X-Vault-Token: $VAULT_TOKEN" \
        -d "$CI_POLICY" \
        "$VAULT_ADDR/v1/sys/policies/acl/ci-policy" || {
        log_error "Failed to create CI policy"
        return 1
    }

    # Read-only policy for external access
    READ_POLICY='{
        "policy": "path \"secret/dev/*\" {\n  capabilities = [\"read\", \"list\"]\n}\n\npath \"secret/test/*\" {\n  capabilities = [\"read\", \"list\"]\n}\n\npath \"secret/ci/*\" {\n  capabilities = [\"read\", \"list\"]\n}"
    }'

    curl -s -X PUT \
        -H "X-Vault-Token: $VAULT_TOKEN" \
        -d "$READ_POLICY" \
        "$VAULT_ADDR/v1/sys/policies/acl/read-policy" || {
        log_error "Failed to create read policy"
        return 1
    }

    log_success "Vault policies created"
}

# Map GitHub teams to policies
setup_github_team_mappings() {
    log_info "Setting up GitHub team to policy mappings..."

    # Map diamondlabs organization members to dev-policy
    curl -s -X POST \
        -H "X-Vault-Token: $VAULT_TOKEN" \
        -d '{"value": "dev-policy"}' \
        "$VAULT_ADDR/v1/auth/github/map/teams/genius-ventures" || {
        log_warning "Failed to map genius-ventures team (may not exist)"
    }

    # Map CI/CD team to ci-policy (if it exists)
    curl -s -X POST \
        -H "X-Vault-Token: $VAULT_TOKEN" \
        -d '{"value": "ci-policy"}' \
        "$VAULT_ADDR/v1/auth/github/map/teams/ci-cd" || {
        log_warning "Failed to map ci-cd team (may not exist)"
    }

    log_success "GitHub team mappings configured"
}

# Initialize secret paths with default structure
initialize_secret_paths() {
    log_info "Initializing secret paths..."

    # Create dev secrets path with placeholder
    curl -s -X POST \
        -H "X-Vault-Token: $VAULT_TOKEN" \
        -d '{"data": {"value": "This is a placeholder secret. Replace with actual secrets."}}' \
        "$VAULT_ADDR/v1/secret/data/dev/placeholder" || {
        log_warning "Failed to create dev placeholder secret"
    }

    # Create test secrets path with placeholder
    curl -s -X POST \
        -H "X-Vault-Token: $VAULT_TOKEN" \
        -d '{"data": {"value": "This is a placeholder secret. Replace with actual secrets."}}' \
        "$VAULT_ADDR/v1/secret/data/test/placeholder" || {
        log_warning "Failed to create test placeholder secret"
    }

    # Create ci secrets path with placeholder
    curl -s -X POST \
        -H "X-Vault-Token: $VAULT_TOKEN" \
        -d '{"data": {"value": "This is a placeholder secret. Replace with actual secrets."}}' \
        "$VAULT_ADDR/v1/secret/data/ci/placeholder" || {
        log_warning "Failed to create CI placeholder secret"
    }

    log_success "Secret paths initialized"
}

# Main initialization function
main() {
    log_info "Starting Vault initialization..."

    # Set Vault environment variables
    export VAULT_ADDR="$VAULT_ADDR"
    export VAULT_TOKEN="$VAULT_TOKEN"

    # Wait for Vault to be ready
    wait_for_vault
    
    # Check if running in persistent mode (requires operator init)
    local vault_mode="ephemeral"  # Default to ephemeral
    
    if [[ -f "$VAULT_MODE_CONF" ]]; then
        source "$VAULT_MODE_CONF"
        vault_mode="${VAULT_MODE:-ephemeral}"
    fi
    
    log_info "Detected Vault mode: $vault_mode"
    
    # If persistent mode, perform operator init and unseal
    if [[ "$vault_mode" == "persistent" ]]; then
        initialize_persistent_vault || {
            log_error "Failed to initialize persistent Vault"
            return 1
        }
    else
        log_info "Ephemeral mode detected - skipping operator init (dev mode auto-initializes)"
    fi

    # Setup components (policies, auth, etc.)
    setup_github_auth
    create_policies
    setup_github_team_mappings
    initialize_secret_paths

    log_success "Vault initialization completed successfully!"
    log_info "Vault is ready at: $VAULT_ADDR"
    log_info "Root token: $VAULT_TOKEN"
    log_info ""
    log_info "Next steps:"
    log_info "1. Run vault-fetch-secrets.sh to retrieve secrets"
    log_info "2. Use VaultSecretManager.ts for programmatic access"
    log_info "3. Run migrate-secrets-to-vault.sh to import existing secrets"
}

# Run main function
main "$@"
