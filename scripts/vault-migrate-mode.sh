#!/usr/bin/env bash
# Vault Mode Migration Script
# Migrates secrets between ephemeral and persistent Vault modes

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BACKUP_BASE="${PROJECT_ROOT}/.devcontainer/data/vault-backups"
BACKUP_DIR="${BACKUP_BASE}/$(date +%Y%m%d-%H%M%S)"

# Default values
SOURCE_MODE=""
TARGET_MODE=""
ROLLBACK_DIR=""

# Usage information
usage() {
    cat << EOF
Usage: $0 --from <mode> --to <mode>
       $0 --rollback <backup-dir>

Migrate Vault secrets between ephemeral and persistent modes.

Options:
  --from <mode>        Source mode: ephemeral or persistent
  --to <mode>          Target mode: ephemeral or persistent
  --rollback <dir>     Restore secrets from backup directory
  --help               Show this help message

Examples:
  # Migrate from ephemeral to persistent
  $0 --from ephemeral --to persistent

  # Migrate from persistent to ephemeral
  $0 --from persistent --to ephemeral

  # Rollback from a backup
  $0 --rollback $BACKUP_BASE/20241022-120000

Notes:
  - Backups are created automatically before migration
  - Only the last 5 backups are retained
  - Vault will be restarted during migration
  - Requires VAULT_ADDR and VAULT_TOKEN environment variables

EOF
    exit 0
}

# Parse arguments
if [[ $# -eq 0 ]]; then
    usage
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        --from)
            SOURCE_MODE="$2"
            shift 2
            ;;
        --to)
            TARGET_MODE="$2"
            shift 2
            ;;
        --rollback)
            ROLLBACK_DIR="$2"
            shift 2
            ;;
        --help|-h)
            usage
            ;;
        *)
            log_error "Unknown option: $1"
            echo ""
            usage
            ;;
    esac
done

# Validate arguments
if [[ -n "$ROLLBACK_DIR" ]]; then
    # Rollback mode - no other arguments needed
    if [[ ! -d "$ROLLBACK_DIR" ]]; then
        log_error "Backup directory not found: $ROLLBACK_DIR"
        exit 1
    fi
else
    # Migration mode - validate source and target
    if [[ -z "$SOURCE_MODE" ]] || [[ -z "$TARGET_MODE" ]]; then
        log_error "Both --from and --to are required for migration"
        echo ""
        usage
    fi
    
    if [[ "$SOURCE_MODE" != "ephemeral" ]] && [[ "$SOURCE_MODE" != "persistent" ]]; then
        log_error "Invalid source mode: $SOURCE_MODE (must be 'ephemeral' or 'persistent')"
        exit 1
    fi
    
    if [[ "$TARGET_MODE" != "ephemeral" ]] && [[ "$TARGET_MODE" != "persistent" ]]; then
        log_error "Invalid target mode: $TARGET_MODE (must be 'ephemeral' or 'persistent')"
        exit 1
    fi
    
    if [[ "$SOURCE_MODE" == "$TARGET_MODE" ]]; then
        log_error "Source and target modes cannot be the same"
        exit 1
    fi
fi

echo "═══════════════════════════════════════════════════════════"
if [[ -n "$ROLLBACK_DIR" ]]; then
    log_info "Vault Migration: Rollback Mode"
    log_info "Backup Directory: $ROLLBACK_DIR"
else
    log_info "Vault Migration: $SOURCE_MODE → $TARGET_MODE"
fi
echo "═══════════════════════════════════════════════════════════"
echo ""

# Backup creation function (Task 7.2)
create_backup() {
    log_info "Creating backup before migration..."
    mkdir -p "$BACKUP_DIR"
    
    # Check if Vault is accessible
    if ! curl -s -f "$VAULT_ADDR/v1/sys/health" > /dev/null 2>&1; then
        log_warning "Vault is not accessible at $VAULT_ADDR"
        log_warning "Backup will be empty - ensure Vault is running"
        return 0
    fi
    
    # Export all secrets as JSON
    local secret_paths=("secret/dev" "secret/test" "secret/ci" "secret/prod")
    local backup_count=0
    
    for path in "${secret_paths[@]}"; do
        log_info "Backing up $path..."
        
        # List secrets in path
        local secrets
        secrets=$(curl -s -H "X-Vault-Token: ${VAULT_TOKEN}" \
            "$VAULT_ADDR/v1/$path/metadata?list=true" 2>/dev/null | jq -r '.data.keys[]?' 2>/dev/null || echo "")
        
        if [[ -z "$secrets" ]]; then
            log_info "No secrets found in $path (path may not exist)"
            continue
        fi
        
        # Export each secret
        while IFS= read -r secret; do
            [[ -z "$secret" ]] && continue
            
            log_info "Backing up $path/$secret..."
            local output_file="$BACKUP_DIR/${path//\//_}_${secret}.json"
            
            if curl -s -H "X-Vault-Token: ${VAULT_TOKEN}" \
                "$VAULT_ADDR/v1/$path/data/$secret" | jq '.' > "$output_file" 2>/dev/null; then
                backup_count=$((backup_count + 1))
            else
                log_warning "Failed to backup $path/$secret"
            fi
        done <<< "$secrets"
    done
    
    # Save backup metadata
    cat > "$BACKUP_DIR/metadata.json" <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "source_mode": "${SOURCE_MODE:-unknown}",
  "target_mode": "${TARGET_MODE:-unknown}",
  "vault_addr": "$VAULT_ADDR",
  "secret_count": $backup_count
}
EOF
    
    log_success "Backup created: $BACKUP_DIR ($backup_count secrets)"
}

# Import secrets from backup (helper for migration and rollback)
import_secrets_from_backup() {
    local backup_dir="$1"
    
    if [[ ! -d "$backup_dir" ]]; then
        log_error "Backup directory not found: $backup_dir"
        return 1
    fi
    
    log_info "Importing secrets from backup: $backup_dir"
    
    local import_count=0
    local failed_count=0
    
    # Import all JSON files in backup directory
    for backup_file in "$backup_dir"/*.json; do
        [[ ! -f "$backup_file" ]] && continue
        [[ "$(basename "$backup_file")" == "metadata.json" ]] && continue
        
        # Parse filename to get path and secret name
        local filename=$(basename "$backup_file" .json)
        local path_part=$(echo "$filename" | cut -d_ -f1-2 | sed 's/_/\//g')
        local secret_name=$(echo "$filename" | cut -d_ -f3-)
        
        log_info "Restoring $path_part/$secret_name..."
        
        # Extract secret data from backup
        local secret_data
        secret_data=$(jq -c '.data.data' "$backup_file" 2>/dev/null)
        
        if [[ -z "$secret_data" ]] || [[ "$secret_data" == "null" ]]; then
            log_warning "No data found in $backup_file"
            failed_count=$((failed_count + 1))
            continue
        fi
        
        # Write secret to Vault
        if curl -s -X POST -H "X-Vault-Token: ${VAULT_TOKEN}" \
            -H "Content-Type: application/json" \
            -d "{\"data\": $secret_data}" \
            "$VAULT_ADDR/v1/$path_part/data/$secret_name" > /dev/null 2>&1; then
            import_count=$((import_count + 1))
        else
            log_warning "Failed to restore $path_part/$secret_name"
            failed_count=$((failed_count + 1))
        fi
    done
    
    log_success "Import complete: $import_count secrets restored, $failed_count failed"
}

# Update Docker Compose environment (Task 7.3 helper)
update_docker_compose_env() {
    local target_mode="$1"
    local mode_conf="${PROJECT_ROOT}/.devcontainer/data/vault-mode.conf"
    
    log_info "Updating Docker Compose configuration for $target_mode mode..."
    
    # Determine vault command based on mode
    local vault_command
    if [[ "$target_mode" == "persistent" ]]; then
        vault_command="server -config=/vault/config/vault-persistent.hcl"
    else
        vault_command="server -dev -dev-root-token-id=root -dev-listen-address=0.0.0.0:8200"
    fi
    
    # Update vault-mode.conf (this is the only file that should be modified)
    mkdir -p "$(dirname "$mode_conf")"
    cat > "$mode_conf" <<EOF
VAULT_MODE="$target_mode"
AUTO_UNSEAL="false"
VAULT_COMMAND="$vault_command"
EOF
    
    log_success "Configuration updated for $target_mode mode"
    log_info "Note: .devcontainer/.env is for Docker Compose only and is not modified"
    log_info "Project secrets are managed in $PROJECT_ROOT/.env"
}

# Ephemeral to Persistent migration (Task 7.3)
migrate_ephemeral_to_persistent() {
    log_info "Migrating from ephemeral to persistent mode..."
    
    # Source: ephemeral Vault (http://localhost:8200, token: root)
    export VAULT_ADDR="${VAULT_ADDR:-http://localhost:8200}"
    export VAULT_TOKEN="${VAULT_TOKEN:-root}"
    
    # Create backup
    create_backup
    
    # Check if Docker is available
    local compose_file="${PROJECT_ROOT}/.devcontainer/docker-compose.dev.yml"
    if ! docker ps > /dev/null 2>&1; then
        log_warning "Docker not accessible - configuration updated but Vault not restarted"
        log_info "Please restart Vault manually from the host machine"
        update_docker_compose_env "persistent"
        return 0
    fi
    
    # Stop current Vault
    log_info "Stopping Vault service..."
    docker compose -f "$compose_file" stop vault-dev 2>/dev/null || true
    
    # Update configuration to persistent
    update_docker_compose_env "persistent"
    
    # Start Vault in persistent mode
    log_info "Starting Vault in persistent mode..."
    docker compose -f "$compose_file" up -d vault-dev 2>/dev/null || true
    sleep 8
    
    # Check if Vault needs initialization
    local health_response
    health_response=$(curl -s "$VAULT_ADDR/v1/sys/health" 2>/dev/null || echo '{}')
    
    if echo "$health_response" | jq -e '.initialized == false' > /dev/null 2>&1; then
        log_info "Initializing persistent Vault..."
        
        # Run vault-init.sh if available
        local init_script="${SCRIPT_DIR}/vault-init.sh"
        if [[ -f "$init_script" ]]; then
            bash "$init_script" || log_warning "Initialization script failed"
        else
            log_warning "vault-init.sh not found - manual initialization required"
        fi
        
        sleep 3
    fi
    
    # Check if Vault is sealed
    if echo "$health_response" | jq -e '.sealed == true' > /dev/null 2>&1; then
        log_info "Unsealing Vault..."
        
        # Run auto-unseal script if available
        local unseal_script="${SCRIPT_DIR}/vault-auto-unseal.sh"
        if [[ -f "$unseal_script" ]]; then
            bash "$unseal_script" || log_warning "Auto-unseal failed"
        else
            log_warning "vault-auto-unseal.sh not found - manual unseal required"
        fi
        
        sleep 3
    fi
    
    # Get root token for persistent Vault
    local keys_file="${PROJECT_ROOT}/.devcontainer/data/vault-unseal-keys.json"
    if [[ -f "$keys_file" ]]; then
        export VAULT_TOKEN=$(jq -r '.root_token' "$keys_file" 2>/dev/null || echo "root")
    fi
    
    # Import secrets from backup
    import_secrets_from_backup "$BACKUP_DIR"
    
    log_success "Migration complete: ephemeral → persistent"
    log_info "Vault is running in persistent mode with raft storage"
}

# Persistent to Ephemeral migration (Task 7.4)
migrate_persistent_to_ephemeral() {
    log_info "Migrating from persistent to ephemeral mode..."
    
    # Source: persistent Vault - need to get token from keys file
    export VAULT_ADDR="${VAULT_ADDR:-http://localhost:8200}"
    
    local keys_file="${PROJECT_ROOT}/.devcontainer/data/vault-unseal-keys.json"
    if [[ -f "$keys_file" ]]; then
        export VAULT_TOKEN=$(jq -r '.root_token' "$keys_file" 2>/dev/null || echo "root")
    else
        export VAULT_TOKEN="${VAULT_TOKEN:-root}"
    fi
    
    # Create backup
    create_backup
    
    # Check if Docker is available
    local compose_file="${PROJECT_ROOT}/.devcontainer/docker-compose.dev.yml"
    if ! docker ps > /dev/null 2>&1; then
        log_warning "Docker not accessible - configuration updated but Vault not restarted"
        log_info "Please restart Vault manually from the host machine"
        update_docker_compose_env "ephemeral"
        return 0
    fi
    
    # Stop current Vault
    log_info "Stopping Vault service..."
    docker compose -f "$compose_file" stop vault-dev 2>/dev/null || true
    
    # Update configuration to ephemeral
    update_docker_compose_env "ephemeral"
    
    # Start Vault in ephemeral mode
    log_info "Starting Vault in ephemeral mode..."
    docker compose -f "$compose_file" up -d vault-dev 2>/dev/null || true
    sleep 8
    
    # Ephemeral mode is pre-initialized with root token
    export VAULT_TOKEN="root"
    
    # Import secrets from backup
    import_secrets_from_backup "$BACKUP_DIR"
    
    log_success "Migration complete: persistent → ephemeral"
    log_info "Vault is running in ephemeral/dev mode (root token: root)"
}

# Cleanup old backups - keep last 5 (Task 7.6)
cleanup_old_backups() {
    log_info "Cleaning up old backups (keeping last 5)..."
    
    local backup_count
    backup_count=$(find "$BACKUP_BASE" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
    
    if [[ $backup_count -gt 5 ]]; then
        # Delete oldest backups
        find "$BACKUP_BASE" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null \
            | xargs -0 ls -dt \
            | tail -n +6 \
            | xargs rm -rf
        
        log_success "Old backups removed (kept last 5)"
    else
        log_info "Only $backup_count backup(s) exist - no cleanup needed"
    fi
}

# Rollback from backup (Task 7.7)
rollback_from_backup() {
    local backup_dir="$1"
    
    log_info "Rolling back from backup: $backup_dir"
    
    # Read backup metadata
    if [[ -f "$backup_dir/metadata.json" ]]; then
        local metadata
        metadata=$(cat "$backup_dir/metadata.json")
        log_info "Backup timestamp: $(echo "$metadata" | jq -r '.timestamp')"
        log_info "Secret count: $(echo "$metadata" | jq -r '.secret_count')"
    fi
    
    # Set Vault credentials
    export VAULT_ADDR="${VAULT_ADDR:-http://localhost:8200}"
    
    # Try to get token from keys file for persistent mode
    local keys_file="${PROJECT_ROOT}/.devcontainer/data/vault-unseal-keys.json"
    if [[ -f "$keys_file" ]]; then
        export VAULT_TOKEN=$(jq -r '.root_token' "$keys_file" 2>/dev/null || echo "root")
    else
        export VAULT_TOKEN="${VAULT_TOKEN:-root}"
    fi
    
    # Import secrets from backup
    import_secrets_from_backup "$backup_dir"
    
    log_success "Rollback complete"
}

# Confirmation prompt (Task 7.5)
confirm_migration() {
    echo ""
    log_warning "This will migrate Vault data from $SOURCE_MODE to $TARGET_MODE"
    log_warning "A backup will be created before migration"
    echo ""
    
    read -p "Continue with migration? (y/N): " confirm
    confirm=${confirm:-N}
    
    if [[ "${confirm^^}" != "Y" ]]; then
        log_info "Migration cancelled by user"
        exit 0
    fi
}

# Main script execution
if [[ -n "$ROLLBACK_DIR" ]]; then
    # Rollback mode
    rollback_from_backup "$ROLLBACK_DIR"
    cleanup_old_backups
else
    # Migration mode
    confirm_migration
    
    if [[ "$SOURCE_MODE" == "ephemeral" ]] && [[ "$TARGET_MODE" == "persistent" ]]; then
        migrate_ephemeral_to_persistent
    elif [[ "$SOURCE_MODE" == "persistent" ]] && [[ "$TARGET_MODE" == "ephemeral" ]]; then
        migrate_persistent_to_ephemeral
    else
        log_error "Invalid migration path: $SOURCE_MODE → $TARGET_MODE"
        exit 1
    fi
    
    cleanup_old_backups
fi

echo ""
log_success "✅ Operation completed successfully!"
echo ""

exit 0
