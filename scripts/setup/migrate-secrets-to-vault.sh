#!/bin/bash
# migrate-secrets-to-vault.sh
# Script to migrate secrets from .env file to HashiCorp Vault
# This script safely moves sensitive configuration to Vault while maintaining backups
#
# IMPORTANT: This script operates on PROJECT_ROOT/.env ONLY
# - .devcontainer/.env is for Docker Compose configuration only (not modified)
# - Project secrets should be in PROJECT_ROOT/.env
#
# Environment Variables:
#   KEEP_ENV_UNCHANGED=true   - Copy secrets to Vault without removing from .env
#   VAULT_MODE=ephemeral      - Automatically sets KEEP_ENV_UNCHANGED=true
#   VAULT_MODE=persistent     - Removes secrets from .env (unless KEEP_ENV_UNCHANGED=true)
#
# Usage:
#   # Migrate secrets (remove from .env):
#   ./migrate-secrets-to-vault.sh
#
#   # Copy secrets (keep in .env as fallback):
#   KEEP_ENV_UNCHANGED=true ./migrate-secrets-to-vault.sh

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
VAULT_ADDR="${VAULT_ADDR:-http://localhost:8200}"
VAULT_TOKEN="${VAULT_TOKEN:-}"

# Secret pattern configuration
SECRET_PATTERNS_FILE="${PROJECT_ROOT}/.devcontainer/data/secret-patterns/secret-patterns.json"

# Arrays to hold loaded patterns
VAR_NAME_PATTERNS=()
VAR_VALUE_PATTERNS=()
EXCLUDE_VARIABLES=()

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

# Function to load secret patterns from configuration file
load_secret_patterns() {
    log_info "Loading secret patterns from: ${SECRET_PATTERNS_FILE}"

    if [[ ! -f "$SECRET_PATTERNS_FILE" ]]; then
        log_error "Secret patterns file not found: ${SECRET_PATTERNS_FILE}"
        log_error "Please ensure the secret patterns configuration file exists"
        exit 1
    fi

    # Check if jq is available
    if ! command_exists jq; then
        log_error "jq is required but not installed. Please install jq to use external secret patterns."
        exit 1
    fi

    # Load variable name patterns
    mapfile -t VAR_NAME_PATTERNS < <(jq -r '.variable_name_patterns[]' "$SECRET_PATTERNS_FILE" 2>/dev/null || echo "")
    if [[ ${#VAR_NAME_PATTERNS[@]} -eq 0 ]]; then
        log_warning "No variable name patterns loaded from configuration file"
    else
        log_info "Loaded ${#VAR_NAME_PATTERNS[@]} variable name patterns"
    fi

    # Load variable value patterns
    mapfile -t VAR_VALUE_PATTERNS < <(jq -r '.variable_value_patterns[]' "$SECRET_PATTERNS_FILE" 2>/dev/null || echo "")
    if [[ ${#VAR_VALUE_PATTERNS[@]} -eq 0 ]]; then
        log_warning "No variable value patterns loaded from configuration file"
    else
        log_info "Loaded ${#VAR_VALUE_PATTERNS[@]} variable value patterns"
    fi

    # Load exclude variables
    mapfile -t EXCLUDE_VARIABLES < <(jq -r '.exclude_variables[]' "$SECRET_PATTERNS_FILE" 2>/dev/null || echo "")
    if [[ ${#EXCLUDE_VARIABLES[@]} -eq 0 ]]; then
        log_warning "No exclude variables loaded from configuration file"
    else
        log_info "Loaded ${#EXCLUDE_VARIABLES[@]} exclude variables"
    fi

    log_success "Secret patterns loaded successfully"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check Vault connectivity
check_vault_connection() {
    log_info "Checking Vault connectivity..."

    if [[ -z "${VAULT_TOKEN}" ]]; then
        log_error "VAULT_TOKEN is not set. Please authenticate with Vault first."
        log_info "Run: .devcontainer/scripts/setup/vault-setup-wizard.sh --non-interactive"
        exit 1
    fi

    export VAULT_TOKEN

    # Check Vault health using HTTP API
    if ! curl -s -H "X-Vault-Token: $VAULT_TOKEN" "$VAULT_ADDR/v1/sys/health" >/dev/null 2>&1; then
        log_error "Cannot connect to Vault at ${VAULT_ADDR}"
        log_error "Make sure Vault is running and accessible"
        exit 1
    fi

    log_success "Vault connection established"
}

# Function to identify secret variables
is_secret_variable() {
    local var_name="$1"
    local var_value="$2"

    # Check exclude variables first
    for exclude_pattern in "${EXCLUDE_VARIABLES[@]}"; do
        if [[ "$var_name" =~ $exclude_pattern ]]; then
            return 1 # Not a secret
        fi
    done

    # Check variable name patterns
    for name_pattern in "${VAR_NAME_PATTERNS[@]}"; do
        if [[ "$var_name" =~ $name_pattern ]]; then
            return 0 # Is a secret
        fi
    done

    # Check variable value patterns
    for value_pattern in "${VAR_VALUE_PATTERNS[@]}"; do
        if [[ "$var_value" =~ $value_pattern ]]; then
            return 0 # Is a secret
        fi
    done

    return 1 # Not a secret
}

# Function to backup .env file
create_backup() {
    local env_file="$1"
    local backup_file="${env_file}.vault-migrated.$(date +%Y%m%d_%H%M%S)"

    log_info "Creating backup of .env file: ${backup_file}"
    cp "$env_file" "$backup_file"

    # Add backup file to .gitignore if not already present
    local gitignore_file="$(dirname "$env_file")/.gitignore"
    if [[ -f "$gitignore_file" ]] && ! grep -q "^${backup_file}$" "$gitignore_file"; then
        echo "${backup_file}" >> "$gitignore_file"
        log_info "Added backup file to .gitignore"
    fi

    echo "$backup_file"
}

# Function to migrate secrets to Vault
migrate_secrets() {
    local env_file="$1"
    local vault_path="${2:-secret/dev}"
    local keep_unchanged="${3:-false}"

    log_info "Starting secret migration from ${env_file} to Vault path: ${vault_path}"
    if [[ "$keep_unchanged" == "true" ]]; then
        log_info "Mode: COPY (will not modify .env file)"
    else
        log_info "Mode: MIGRATE (will remove secrets from .env file)"
    fi

    local secrets_found=0
    local secrets_migrated=0
    local non_secret_vars=()

    # Read .env file and process each line
    while IFS='=' read -r key value || [[ -n "$key" ]]; do
        # Skip comments and empty lines
        [[ "$key" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$key" ]] && continue

        # Remove leading/trailing whitespace
        key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        if is_secret_variable "$key" "$value"; then
            log_info "Migrating secret: ${key}"

            # Store in Vault using HTTP API
            if ! curl -s -X POST \
                -H "X-Vault-Token: $VAULT_TOKEN" \
                -d "{\"data\": {\"value\": \"$value\"}}" \
                "$VAULT_ADDR/v1/secret/data/${vault_path}/${key}" >/dev/null 2>&1; then
                log_error "Failed to migrate: ${key}"
                exit 1
            fi

            log_success "Successfully migrated: ${key}"
            ((secrets_found++))
            ((secrets_migrated++))
        else
            # Keep non-secret variables
            non_secret_vars+=("$key=$value")
        fi
    done < "$env_file"

    log_info "Found ${secrets_found} secrets, migrated ${secrets_migrated} secrets"

    # Only update .env file if requested and there were secrets to migrate
    if [[ "$keep_unchanged" == "true" ]]; then
        log_info "KEEP_ENV_UNCHANGED=true - .env file will not be modified"
        log_info "Secrets copied to Vault: $secrets_migrated"
        log_info ".env file remains unchanged as fallback for secret retrieval"
    elif [[ $secrets_found -gt 0 ]]; then
        log_info "Creating new .env file with non-secret variables..."
        # Create new .env file with only non-secret variables
        {
            echo "# .env file - Non-secret configuration only"
            echo "# Secrets have been migrated to Vault (${vault_path})"
            echo "# To retrieve secrets, run: .devcontainer/scripts/vault-fetch-secrets.sh"
            echo ""
            printf '%s\n' "${non_secret_vars[@]}"
        } > "${env_file}.new"

        log_info "Contents of .env.new:"
        cat "${env_file}.new"

        log_info "Updating .env file..."
        # Use cat and rm instead of cp to avoid device busy issues
        if cat "${env_file}.new" > "$env_file"; then
            log_info "File update successful, removing temp file..."
            rm "${env_file}.new"
            log_success "Updated .env file to contain only non-secret configuration"
        else
            log_error "Failed to update .env file - permission denied or device busy"
            log_info "You can manually update the .env file by replacing its contents with:"
            log_info "${env_file}.new"
            exit 1
        fi
    else
        log_info "No secrets found to migrate - .env file unchanged"
    fi
}

# Function to validate migration
validate_migration() {
    local env_file="$1"
    local vault_path="${2:-secret/dev}"

    log_info "Validating migration..."

    local secrets_remaining=0

    # Check if any secrets remain in .env file
    while IFS='=' read -r key value || [[ -n "$key" ]]; do
        [[ "$key" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$key" ]] && continue

        key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        if is_secret_variable "$key" "$value"; then
            log_error "Secret still found in .env file: ${key}"
            ((secrets_remaining++))
        fi
    done < "$env_file"

    if [[ $secrets_remaining -gt 0 ]]; then
        log_error "Migration validation failed: ${secrets_remaining} secrets still remain in .env file"
        exit 1
    fi

    # Verify secrets are accessible in Vault
    local vault_secrets
    vault_secrets=$(curl -s \
        -H "X-Vault-Token: $VAULT_TOKEN" \
        "$VAULT_ADDR/v1/secret/metadata/${vault_path}?list=true" | \
        jq -r '.data.keys[]' 2>/dev/null || echo "")

    if [[ -z "$vault_secrets" ]]; then
        log_warning "No secrets found in Vault path: ${vault_path}"
        log_warning "This might be expected if no secrets were migrated"
    else
        log_success "Secrets successfully stored in Vault:"
        echo "$vault_secrets" | while read -r secret; do
            [[ -n "$secret" ]] && log_info "  - ${secret}"
        done
    fi

    log_success "Migration validation completed successfully"
}

# Main function
main() {
    local env_file="${PROJECT_ROOT}/.env"
    local vault_path="secret/dev"
    local keep_env_unchanged="${KEEP_ENV_UNCHANGED:-false}"

    log_info "Secret Migration to Vault"
    log_info "=================================="
    log_info "Operating on: ${env_file}"
    log_info "Note: .devcontainer/.env is NOT modified (Docker Compose only)"
    echo

    # Check environment variable for keeping .env unchanged
    if [[ "${VAULT_MODE:-ephemeral}" == "ephemeral" ]]; then
        keep_env_unchanged="true"
        log_info "Running in EPHEMERAL mode - .env file will remain unchanged"
    fi

    if [[ "$keep_env_unchanged" == "true" ]]; then
        log_info "KEEP_ENV_UNCHANGED=true - .env file will not be modified"
        log_info "Secrets will be copied to Vault but remain in .env as fallback"
    fi
    echo

    # Load secret patterns from configuration file
    load_secret_patterns

    # Check if .env file exists
    if [[ ! -f "$env_file" ]]; then
        log_error ".env file not found: ${env_file}"
        exit 1
    fi

    # Check Vault connection
    check_vault_connection

    # Create backup
    local backup_file
    backup_file=$(create_backup "$env_file")

    # Migrate secrets
    migrate_secrets "$env_file" "$vault_path" "$keep_env_unchanged"

    if [[ "$keep_env_unchanged" != "true" ]]; then
        log_info "Migration completed, starting validation..."
        # Validate migration only if .env was modified
        validate_migration "$env_file" "$vault_path"
    else
        log_info "Secrets copied to Vault, .env file unchanged (fallback mode)"
    fi

    log_success "Secret migration completed successfully!"
    log_info "Backup created: ${backup_file}"
    log_info "To restore from backup: cp '${backup_file}' '${env_file}'"
    log_info "To retrieve secrets: .devcontainer/scripts/vault-fetch-secrets.sh"
    
    if [[ "$keep_env_unchanged" == "true" ]]; then
        log_info "\nNote: .env file was not modified - secrets remain as fallback"
    fi
}

# Run main function
main "$@"