#!/usr/bin/env bash
# Vault Mode CLI Utility
# Easy-to-use command-line tool for managing Vault modes

set -eo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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
MODE_CONF="${PROJECT_ROOT}/.devcontainer/data/vault-mode.conf"
DEVCONTAINER_ENV="${PROJECT_ROOT}/.devcontainer/.env"  # For Docker Compose only - DO NOT MODIFY
PROJECT_ENV="${PROJECT_ROOT}/.env"  # Project secrets and configuration
COMPOSE_FILE="${PROJECT_ROOT}/.devcontainer/docker-compose.dev.yml"
MIGRATE_SCRIPT="${SCRIPT_DIR}/vault-migrate-mode.sh"

# Usage information
usage() {
    cat << EOF
${CYAN}Vault Mode CLI Utility${NC}

Usage: vault-mode <command> [options]

Commands:
  ${GREEN}status${NC}              Show current Vault mode and status
  ${GREEN}switch${NC} <mode>       Switch to a different Vault mode
  ${GREEN}help${NC}                Show this help message

Modes:
  ${YELLOW}persistent${NC}          Vault with raft storage (data persists)
  ${YELLOW}ephemeral${NC}           Dev mode Vault (data is temporary)

Examples:
  # Check current mode and status
  vault-mode status

  # Switch to persistent mode
  vault-mode switch persistent

  # Switch to ephemeral mode
  vault-mode switch ephemeral

  # Show help
  vault-mode help

More Information:
  - Configuration: $MODE_CONF
  - Migration script: $MIGRATE_SCRIPT
  - DevContainer env (Docker only): $DEVCONTAINER_ENV
  - Project env (secrets): $PROJECT_ENV

Note:
  - .devcontainer/.env is for Docker Compose configuration only
  - $PROJECT_ROOT/.env is for project secrets and should be used with Vault

EOF
}

# Get current mode from vault-mode.conf (Task 8.2 helper)
get_current_mode() {
    if [[ -f "$MODE_CONF" ]]; then
        source "$MODE_CONF"
        echo "${VAULT_MODE:-ephemeral}"
    else
        echo "ephemeral"
    fi
}

# Status command (Task 8.1)
cmd_status() {
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo -e "${CYAN}Vault Mode Status${NC}"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    
    # Get current mode
    local current_mode
    current_mode=$(get_current_mode)
    
    echo -e "${BLUE}Mode:${NC} ${YELLOW}$current_mode${NC}"
    
    # Show configuration file location
    if [[ -f "$MODE_CONF" ]]; then
        echo -e "${BLUE}Config:${NC} $MODE_CONF"
        
        # Show vault command
        source "$MODE_CONF"
        if [[ -n "$VAULT_COMMAND" ]]; then
            echo -e "${BLUE}Command:${NC} $VAULT_COMMAND"
        fi
        
        # Show auto-unseal status
        if [[ -n "$AUTO_UNSEAL" ]]; then
            echo -e "${BLUE}Auto-unseal:${NC} $AUTO_UNSEAL"
        fi
    else
        echo -e "${BLUE}Config:${NC} Not found (using defaults)"
    fi
    
    echo ""
    
    # Check Vault service status
    if command -v docker &> /dev/null && docker ps &> /dev/null; then
        echo -e "${BLUE}Service Status:${NC}"
        
        if docker compose -f "$COMPOSE_FILE" ps vault-dev 2>/dev/null | grep -q "Up"; then
            echo -e "  ${GREEN}✓${NC} Vault is running"
            
            # Check if Vault is accessible
            local vault_addr="${VAULT_ADDR:-http://localhost:8200}"
            if curl -s -f "$vault_addr/v1/sys/health" > /dev/null 2>&1; then
                local health
                health=$(curl -s "$vault_addr/v1/sys/health" 2>/dev/null || echo '{}')
                
                local initialized=$(echo "$health" | jq -r '.initialized // false')
                local sealed=$(echo "$health" | jq -r '.sealed // false')
                
                if [[ "$initialized" == "true" ]]; then
                    echo -e "  ${GREEN}✓${NC} Vault is initialized"
                else
                    echo -e "  ${YELLOW}!${NC} Vault is not initialized"
                fi
                
                if [[ "$sealed" == "false" ]]; then
                    echo -e "  ${GREEN}✓${NC} Vault is unsealed"
                elif [[ "$sealed" == "true" ]]; then
                    echo -e "  ${YELLOW}!${NC} Vault is sealed"
                fi
            else
                echo -e "  ${YELLOW}!${NC} Vault is not accessible"
            fi
        else
            echo -e "  ${RED}✗${NC} Vault is not running"
        fi
    else
        echo -e "${YELLOW}Note:${NC} Docker not accessible - cannot check service status"
    fi
    
    # Show persistent storage info for persistent mode
    if [[ "$current_mode" == "persistent" ]]; then
        echo ""
        echo -e "${BLUE}Persistent Storage:${NC}"
        
        local raft_dir="${PROJECT_ROOT}/.devcontainer/data/vault-data/raft"
        if [[ -d "$raft_dir" ]]; then
            local size=$(du -sh "$raft_dir" 2>/dev/null | cut -f1 || echo "unknown")
            echo -e "  ${GREEN}✓${NC} Raft database exists"
            echo -e "  ${BLUE}Size:${NC} $size"
            echo -e "  ${BLUE}Location:${NC} $raft_dir"
        else
            echo -e "  ${YELLOW}!${NC} No raft database found"
        fi
        
        local keys_file="${PROJECT_ROOT}/.devcontainer/data/vault-unseal-keys.json"
        if [[ -f "$keys_file" ]]; then
            echo -e "  ${GREEN}✓${NC} Unseal keys file exists"
        else
            echo -e "  ${YELLOW}!${NC} No unseal keys file"
        fi
    fi
    
    echo ""
}

# Update vault-mode.conf (Task 8.4)
update_vault_mode_conf() {
    local target_mode="$1"
    
    log_info "Updating vault-mode.conf..."
    
    # Determine vault command based on mode
    local vault_command
    if [[ "$target_mode" == "persistent" ]]; then
        vault_command="server -config=/vault/config/vault-persistent.hcl"
    else
        vault_command="server -dev -dev-root-token-id=root -dev-listen-address=0.0.0.0:8200"
    fi
    
    # Create configuration directory if needed
    mkdir -p "$(dirname "$MODE_CONF")"
    
    # Write configuration
    cat > "$MODE_CONF" <<EOF
VAULT_MODE="$target_mode"
AUTO_UNSEAL="false"
VAULT_COMMAND="$vault_command"
EOF
    
    log_success "vault-mode.conf updated"
}

# Update Docker Compose environment (Task 8.5)
update_docker_compose_env() {
    local target_mode="$1"
    
    log_info "Updating Docker Compose environment..."
    
    # Determine vault command based on mode
    local vault_command
    if [[ "$target_mode" == "persistent" ]]; then
        vault_command="server -config=/vault/config/vault-persistent.hcl"
    else
        vault_command="server -dev -dev-root-token-id=root -dev-listen-address=0.0.0.0:8200"
    fi
    
    # Update vault-mode.conf (this is the authoritative source for Vault mode)
    mkdir -p "$(dirname "$MODE_CONF")"
    cat > "$MODE_CONF" <<EOF
VAULT_MODE="$target_mode"
AUTO_UNSEAL="false"
VAULT_COMMAND="$vault_command"
EOF
    
    log_success "Docker Compose environment updated in vault-mode.conf"
    log_info "Note: .devcontainer/.env is for Docker Compose only and is not modified"
    log_info "Project secrets are managed in $PROJECT_ENV"
}

# Restart Vault service (Task 8.5)
restart_vault_service() {
    log_info "Restarting Vault service..."
    
    # Check if Docker is available
    if ! command -v docker &> /dev/null || ! docker ps &> /dev/null; then
        log_warning "Docker not accessible - please restart Vault manually"
        log_info "On host: docker compose -f .devcontainer/docker-compose.dev.yml restart vault-dev"
        return 1
    fi
    
    # Restart Vault
    if docker compose -f "$COMPOSE_FILE" restart vault-dev > /dev/null 2>&1; then
        log_success "Vault service restarted"
        
        log_info "Waiting for Vault to be ready..."
        sleep 8
        
        # Check if Vault is accessible
        local vault_addr="${VAULT_ADDR:-http://localhost:8200}"
        if curl -s -f "$vault_addr/v1/sys/health" > /dev/null 2>&1; then
            log_success "Vault is accessible"
            return 0
        else
            log_warning "Vault may still be starting..."
            return 0
        fi
    else
        log_error "Failed to restart Vault service"
        return 1
    fi
}

# Switch command (Task 8.2, 8.3, 8.4, 8.5)
cmd_switch() {
    local target_mode="$1"
    
    # Validate target mode
    if [[ "$target_mode" != "persistent" ]] && [[ "$target_mode" != "ephemeral" ]]; then
        log_error "Invalid mode: $target_mode"
        echo ""
        echo "Valid modes: persistent, ephemeral"
        exit 1
    fi
    
    # Get current mode
    local current_mode
    current_mode=$(get_current_mode)
    
    # Check if already in target mode
    if [[ "$current_mode" == "$target_mode" ]]; then
        log_warning "Already in $target_mode mode"
        exit 0
    fi
    
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo -e "${CYAN}Vault Mode Switch${NC}"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    log_info "Current mode: ${YELLOW}$current_mode${NC}"
    log_info "Target mode:  ${YELLOW}$target_mode${NC}"
    echo ""
    
    # Migration prompt (Task 8.3)
    if [[ -f "$MIGRATE_SCRIPT" ]] && [[ -x "$MIGRATE_SCRIPT" ]]; then
        echo -e "${YELLOW}Migration Options:${NC}"
        echo "  1. Migrate secrets (recommended - preserves data)"
        echo "  2. Switch without migration (data will be lost)"
        echo "  3. Cancel"
        echo ""
        
        read -p "Choose option (1/2/3): " migration_choice
        migration_choice=${migration_choice:-3}
        
        case $migration_choice in
            1)
                log_info "Starting migration with vault-migrate-mode.sh..."
                
                if "$MIGRATE_SCRIPT" --from "$current_mode" --to "$target_mode"; then
                    log_success "Migration completed successfully"
                    log_success "Mode switched: $current_mode → $target_mode"
                    echo ""
                    cmd_status
                    exit 0
                else
                    log_error "Migration failed"
                    exit 1
                fi
                ;;
            2)
                log_warning "Switching without migration - data will NOT be preserved"
                echo ""
                read -p "Are you sure? Type 'yes' to confirm: " confirm
                
                if [[ "$confirm" != "yes" ]]; then
                    log_info "Switch cancelled"
                    exit 0
                fi
                ;;
            3)
                log_info "Switch cancelled"
                exit 0
                ;;
            *)
                log_error "Invalid choice"
                exit 1
                ;;
        esac
    else
        log_warning "Migration script not available - switching without migration"
        log_warning "Secrets will NOT be migrated"
        echo ""
        read -p "Continue? (y/N): " confirm
        confirm=${confirm:-N}
        
        if [[ "${confirm^^}" != "Y" ]]; then
            log_info "Switch cancelled"
            exit 0
        fi
    fi
    
    # Perform switch
    log_info "Switching to $target_mode mode..."
    
    # Update configuration
    update_vault_mode_conf "$target_mode"
    update_docker_compose_env "$target_mode"
    
    # Restart Vault
    restart_vault_service || true
    
    log_success "Mode switched: $current_mode → $target_mode"
    echo ""
    
    # Show new status
    cmd_status
}

# Main command dispatcher
if [[ $# -eq 0 ]]; then
    usage
    exit 0
fi

case "$1" in
    status)
        cmd_status
        ;;
    switch)
        if [[ $# -lt 2 ]]; then
            log_error "Missing mode argument"
            echo ""
            echo "Usage: vault-mode switch <mode>"
            echo "Modes: persistent, ephemeral"
            exit 1
        fi
        cmd_switch "$2"
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        log_error "Unknown command: $1"
        echo ""
        usage
        exit 1
        ;;
esac

exit 0
