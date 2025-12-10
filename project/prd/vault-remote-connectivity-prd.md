# Product Requirements Document: HashiCorp Vault Remote Connectivity

**Document Version:** 1.0  
**Date:** October 21, 2025  
**Author:** GitHub Copilot (AI Coding Agent)  
**Status:** Draft - Awaiting Approval  
**Project:** Hardhat-Diamonds Development Environment  
**Prerequisites:** Vault Persistence & CLI Installation PRD (must be implemented first)

---

## Executive Summary

This PRD defines requirements for **remote Vault connectivity** in the Hardhat-Diamonds DevContainer environment. Building on the local persistent Vault foundation, this enhancement enables developers to:

1. **Connect to Remote Vault**: Use cloud-hosted or self-hosted Vault instances (HCP Vault, AWS, GCP, on-premise)
2. **Flexible Configuration**: Switch between local and remote Vault via CLI commands or wizard
3. **Unified Workflows**: Use same scripts/tools regardless of Vault location
4. **Automatic Detection**: Detect existing Vault setup and configure appropriately
5. **Failover Support**: Fallback from remote to local if remote unavailable

**Business Value**: Enables centralized secret management for distributed teams, supports production-like workflows, and reduces secret sprawl across developer machines.

---

## Problem Statement

### Current State (After Persistence PRD)
- **Local Vault Only**: All secrets stored on individual developer machines
- **No Centralization**: Teams cannot share Vault configuration
- **Manual Sync**: Developers manually sync secrets across team members
- **Production Gap**: Local dev Vault differs significantly from production (cloud-hosted)
- **Network Dependency**: Cannot access secrets when working from different machines

### User Pain Points
1. **Team Collaboration**: "I can't easily share Vault policies/secrets with my team"
2. **Multi-Machine Development**: "I work from laptop and desktop - secrets out of sync"
3. **Production Parity**: "Local Vault setup doesn't match our HCP Vault production instance"
4. **Secret Sprawl**: "Everyone has their own copy of secrets - hard to rotate"
5. **Onboarding Friction**: "New devs need manual secret sharing - insecure and time-consuming"

### Success Metrics
- **Remote Vault Adoption**: 60%+ of teams use remote Vault within 3 months
- **Onboarding Time**: Reduce from 15 min (manual) to 2 min (remote auto-sync)
- **Secret Consistency**: 100% of team members use same secret versions
- **Failover Success**: 95%+ failover success rate (remote → local)

---

## Goals & Non-Goals

### Goals
✅ **Remote Connectivity**: Connect DevContainer to remote Vault instances (HCP, AWS, GCP, self-hosted)  
✅ **Wizard Integration**: Prompt for local vs remote during setup (equal priority)  
✅ **CLI Switcher**: Command to switch between local and remote Vault  
✅ **Authentication**: Support GitHub auth (consistent with local), token auth, AppRole  
✅ **Automatic Detection**: Detect existing remote Vault and configure automatically  
✅ **Bidirectional Migration**: Migrate secrets from local → remote and remote → local  
✅ **Failover Logic**: Fallback to local Vault if remote unreachable  
✅ **Validation**: Extend validation to test remote connectivity and auth  
✅ **Documentation**: Create VAULT_REMOTE.md with setup guides for HCP Vault  

### Non-Goals
❌ **Vault Deployment**: Not deploying remote Vault (users bring their own)  
❌ **Multi-Vault Sync**: Not syncing secrets across multiple Vaults  
❌ **Vault Enterprise Features**: Not implementing Enterprise-only features (namespaces, replication)  
❌ **Custom Auth Methods**: Only GitHub, token, AppRole (no LDAP, OIDC, Kubernetes)  
❌ **Vault Agent**: Not implementing Vault Agent for sidecar pattern  

---

## User Stories

### US-1: Developer Connects to HCP Vault
**As a** developer using HashiCorp Cloud Platform (HCP)  
**I want** to connect my DevContainer to HCP Vault  
**So that** I use the same secrets as my production environment  

**Acceptance Criteria**:
- Wizard prompts: "Use remote Vault? (y/N)"
- If YES, prompts for: Vault address (e.g., `https://my-vault.vault.11eb1a1c-23c4-42c9-abcd-1234567890ab.aws.hashicorp.cloud:8200`)
- Prompts for authentication method: GitHub, Token, AppRole
- Validates connectivity before proceeding
- Stores configuration in `.devcontainer/data/vault-remote.conf`

---

### US-2: Team Lead Sets Up Remote Vault Template
**As a** team lead managing a development team  
**I want** to provide a remote Vault configuration template  
**So that** new developers automatically connect to team Vault  

**Acceptance Criteria**:
- Template file: `.devcontainer/data/vault-remote.conf.template`
- Contains: `VAULT_ADDR`, `VAULT_AUTH_METHOD`, `VAULT_NAMESPACE` (if applicable)
- Wizard detects template and uses it (non-interactive setup)
- Developer only needs to provide their GitHub token or credentials

---

### US-3: Developer Switches Between Local and Remote
**As a** developer testing offline workflows  
**I want** to switch between local and remote Vault easily  
**So that** I can work offline without breaking my setup  

**Acceptance Criteria**:
- CLI command: `vault-mode switch local` or `vault-mode switch remote`
- Prompts for confirmation before switch
- Migrates secrets if requested
- Updates environment variables (`VAULT_ADDR`, `VAULT_TOKEN`)
- Restarts Vault service (if switching to local)

---

### US-4: Developer Experiences Remote Vault Outage
**As a** developer with unreliable network  
**I want** automatic failover to local Vault if remote is unavailable  
**So that** I can continue development during outages  

**Acceptance Criteria**:
- Scripts detect remote Vault unavailability (timeout, connection refused)
- Automatically switch to local Vault (with warning message)
- Offer to sync secrets from remote (if available) to local
- Resume normal operations with local Vault

---

### US-5: Developer Migrates Local Secrets to Remote
**As a** developer transitioning from local to remote Vault  
**I want** to migrate my existing local secrets to remote  
**So that** I don't lose my work and can share with team  

**Acceptance Criteria**:
- Migration script: `vault-migrate --from local --to remote`
- Prompts for confirmation and shows secret count
- Creates backup before migration
- Validates remote auth before uploading secrets
- Reports success/failure for each secret path

---

## Technical Requirements

### TR-1: Remote Vault Configuration
**Priority**: P0 (Critical)  
**Description**: Store and manage remote Vault connection details

**Requirements**:
1. **Configuration File**: `.devcontainer/data/vault-remote.conf`
   ```bash
   # Remote Vault Configuration
   VAULT_TYPE="remote"                    # local | remote
   VAULT_ADDR="https://vault.example.com:8200"
   VAULT_NAMESPACE=""                     # HCP Vault namespace (if applicable)
   VAULT_AUTH_METHOD="github"             # github | token | approle
   VAULT_SKIP_VERIFY="false"              # Skip TLS verification (dev only)
   
   # GitHub Auth (if VAULT_AUTH_METHOD=github)
   VAULT_GITHUB_TOKEN=""                  # Leave empty, prompt at runtime
   
   # Token Auth (if VAULT_AUTH_METHOD=token)
   VAULT_TOKEN=""                         # Leave empty, prompt at runtime
   
   # AppRole Auth (if VAULT_AUTH_METHOD=approle)
   VAULT_ROLE_ID=""                       # Stored in config
   VAULT_SECRET_ID=""                     # Leave empty, prompt at runtime
   ```

2. **Template Support**: `.devcontainer/data/vault-remote.conf.template`
   - Committed to Git (team-shared)
   - Actual config (`.vault-remote.conf`) gitignored
   - Wizard copies template and prompts for missing values

3. **Validation**:
   - URL validation (must be `https://` or `http://localhost`)
   - Reachability test before saving
   - Auth method compatibility check

**Acceptance Criteria**:
- Configuration file supports all common remote Vault setups
- Template mechanism works for team onboarding
- Invalid configurations rejected with clear error messages

---

### TR-2: Wizard Remote Vault Prompts
**Priority**: P0 (Critical)  
**Description**: Extend wizard to support remote Vault selection

**Requirements**:
1. **Vault Type Prompt** (new step in wizard):
   ```bash
   step_vault_type_selection() {
       echo ""
       echo "╔════════════════════════════════════════════════════════════╗"
       echo "║          Vault Type Selection                              ║"
       echo "╠════════════════════════════════════════════════════════════╣"
       echo "║ Choose Vault deployment type:                              ║"
       echo "║                                                            ║"
       echo "║ [L] Local Persistent Vault (recommended for solo devs)    ║"
       echo "║     └─ Vault runs in DevContainer                         ║"
       echo "║     └─ Data stored locally                                ║"
       echo "║                                                            ║"
       echo "║ [R] Remote Vault (recommended for teams)                  ║"
       echo "║     └─ Connect to HCP Vault, AWS, GCP, or self-hosted    ║"
       echo "║     └─ Shared secrets across team                         ║"
       echo "╚════════════════════════════════════════════════════════════╝"
       
       # Detect template
       if [[ -f .devcontainer/data/vault-remote.conf.template ]]; then
           echo "[INFO] Remote Vault template detected. Recommend selecting [R]."
       fi
       
       read -p "Select type [L/r]: " vault_type
       vault_type=${vault_type:-L}  # Default to Local
       
       case "${vault_type^^}" in
           L|LOCAL)
               VAULT_TYPE="local"
               # Continue to mode selection (persistent/ephemeral)
               ;;
           R|REMOTE)
               VAULT_TYPE="remote"
               step_remote_vault_config
               ;;
           *)
               echo "[ERROR] Invalid choice. Defaulting to Local."
               VAULT_TYPE="local"
               ;;
       esac
   }
   ```

2. **Remote Configuration Prompts**:
   ```bash
   step_remote_vault_config() {
       echo ""
       echo "╔════════════════════════════════════════════════════════════╗"
       echo "║          Remote Vault Configuration                        ║"
       echo "╚════════════════════════════════════════════════════════════╝"
       
       # Check for template
       if [[ -f .devcontainer/data/vault-remote.conf.template ]]; then
           read -p "Use template configuration? (Y/n): " use_template
           use_template=${use_template:-Y}
           
           if [[ "${use_template^^}" == "Y" ]]; then
               cp .devcontainer/data/vault-remote.conf.template \
                  .devcontainer/data/vault-remote.conf
               echo "[SUCCESS] Template configuration loaded"
               
               # Prompt only for credentials
               step_remote_vault_auth
               return
           fi
       fi
       
       # Manual configuration
       read -p "Vault Address (e.g., https://vault.example.com:8200): " vault_addr
       read -p "Vault Namespace (leave empty if not HCP): " vault_namespace
       
       echo ""
       echo "Select authentication method:"
       echo "  [1] GitHub (uses your GitHub personal token)"
       echo "  [2] Token (Vault token auth)"
       echo "  [3] AppRole (role_id + secret_id)"
       read -p "Method [1/2/3]: " auth_method
       
       case "$auth_method" in
           1) VAULT_AUTH_METHOD="github" ;;
           2) VAULT_AUTH_METHOD="token" ;;
           3) VAULT_AUTH_METHOD="approle" ;;
           *) echo "[ERROR] Invalid. Defaulting to GitHub."; VAULT_AUTH_METHOD="github" ;;
       esac
       
       # Save configuration
       cat > .devcontainer/data/vault-remote.conf <<EOF
   VAULT_TYPE="remote"
   VAULT_ADDR="$vault_addr"
   VAULT_NAMESPACE="$vault_namespace"
   VAULT_AUTH_METHOD="$VAULT_AUTH_METHOD"
   VAULT_SKIP_VERIFY="false"
   EOF
       
       # Validate connectivity
       if ! curl -sf "$vault_addr/v1/sys/health" > /dev/null; then
           echo "[ERROR] Cannot reach Vault at $vault_addr"
           read -p "Continue anyway? (y/N): " continue_anyway
           [[ "${continue_anyway^^}" != "Y" ]] && exit 1
       fi
       
       step_remote_vault_auth
   }
   ```

3. **Authentication Prompts**:
   ```bash
   step_remote_vault_auth() {
       echo ""
       echo "╔════════════════════════════════════════════════════════════╗"
       echo "║          Remote Vault Authentication                       ║"
       echo "╚════════════════════════════════════════════════════════════╝"
       
       source .devcontainer/data/vault-remote.conf
       
       case "$VAULT_AUTH_METHOD" in
           github)
               echo "GitHub authentication requires a personal access token."
               echo "Create token at: https://github.com/settings/tokens"
               echo "Required scopes: read:user, read:org"
               read -sp "GitHub Token: " github_token
               echo ""
               
               # Test authentication
               export VAULT_ADDR VAULT_NAMESPACE
               vault_token=$(curl -sf -X POST \
                   -d "{\"token\":\"$github_token\"}" \
                   "$VAULT_ADDR/v1/auth/github/login" | jq -r '.auth.client_token')
               
               if [[ -z "$vault_token" ]] || [[ "$vault_token" == "null" ]]; then
                   echo "[ERROR] GitHub authentication failed"
                   exit 1
               fi
               
               # Store token securely (encrypted or prompt each time)
               read -p "Store GitHub token? (less secure but convenient) (y/N): " store_token
               if [[ "${store_token^^}" == "Y" ]]; then
                   echo "VAULT_GITHUB_TOKEN=\"$github_token\"" >> .devcontainer/data/vault-remote.conf
                   echo "[WARNING] Token stored in plaintext. Use with caution."
               fi
               
               export VAULT_TOKEN="$vault_token"
               ;;
               
           token)
               echo "Vault Token authentication requires a valid Vault token."
               read -sp "Vault Token: " vault_token
               echo ""
               
               # Validate token
               export VAULT_ADDR VAULT_NAMESPACE VAULT_TOKEN="$vault_token"
               if ! vault token lookup > /dev/null 2>&1; then
                   echo "[ERROR] Token authentication failed"
                   exit 1
               fi
               
               read -p "Store Vault token? (y/N): " store_token
               if [[ "${store_token^^}" == "Y" ]]; then
                   echo "VAULT_TOKEN=\"$vault_token\"" >> .devcontainer/data/vault-remote.conf
               fi
               ;;
               
           approle)
               echo "AppRole authentication requires role_id and secret_id."
               read -p "Role ID: " role_id
               read -sp "Secret ID: " secret_id
               echo ""
               
               # Authenticate
               export VAULT_ADDR VAULT_NAMESPACE
               vault_token=$(curl -sf -X POST \
                   -d "{\"role_id\":\"$role_id\",\"secret_id\":\"$secret_id\"}" \
                   "$VAULT_ADDR/v1/auth/approle/login" | jq -r '.auth.client_token')
               
               if [[ -z "$vault_token" ]] || [[ "$vault_token" == "null" ]]; then
                   echo "[ERROR] AppRole authentication failed"
                   exit 1
               fi
               
               # Store role_id (secret_id should never be stored)
               echo "VAULT_ROLE_ID=\"$role_id\"" >> .devcontainer/data/vault-remote.conf
               export VAULT_TOKEN="$vault_token"
               ;;
       esac
       
       echo "[SUCCESS] ✅ Remote Vault authentication successful"
       
       # Update .env file
       update_env_file
   }
   ```

**Acceptance Criteria**:
- Wizard prompts for local vs remote (equal priority)
- Remote configuration supports HCP Vault, self-hosted
- Authentication works for GitHub, Token, AppRole
- Invalid credentials rejected with clear error messages
- Template detection and auto-configuration working

---

### TR-3: CLI Mode Switcher (Extended)
**Priority**: P0 (Critical)  
**Description**: Extend `vault-mode` CLI to support local ↔ remote switching

**Requirements**:
1. **Extended Syntax**:
   ```bash
   # Switch to local persistent
   vault-mode switch local
   
   # Switch to local ephemeral (dev mode)
   vault-mode switch local --ephemeral
   
   # Switch to remote
   vault-mode switch remote
   
   # Switch to remote with specific address
   vault-mode switch remote --addr https://vault.example.com:8200
   ```

2. **Migration Prompt**:
   ```bash
   # When switching modes, prompt for migration
   echo "[INFO] Current mode: remote"
   echo "[INFO] Target mode: local"
   echo ""
   read -p "Migrate secrets from remote to local? (y/N): " migrate_secrets
   
   if [[ "${migrate_secrets^^}" == "Y" ]]; then
       bash .devcontainer/scripts/vault-migrate.sh --from remote --to local
   fi
   ```

3. **Failover Detection**:
   ```bash
   # Auto-switch if remote unavailable
   if [[ "$VAULT_TYPE" == "remote" ]]; then
       if ! curl -sf --max-time 5 "$VAULT_ADDR/v1/sys/health" > /dev/null; then
           echo "[WARNING] Remote Vault unreachable. Switching to local Vault."
           vault-mode switch local --auto-failover
       fi
   fi
   ```

**Acceptance Criteria**:
- CLI supports switching between local (persistent/ephemeral) and remote
- Migration offered when switching
- Failover works automatically with warning message
- Configuration updated correctly after switch

---

### TR-4: Secret Migration (Bidirectional)
**Priority**: P1 (High)  
**Description**: Migrate secrets between local and remote Vault

**Requirements**:
1. **Migration Script**: `.devcontainer/scripts/vault-migrate.sh`
   ```bash
   #!/usr/bin/env bash
   # Usage: vault-migrate.sh --from [local|remote] --to [local|remote]
   
   set -euo pipefail
   
   SOURCE="$2"
   TARGET="$4"
   BACKUP_DIR=".devcontainer/data/vault-backups/$(date +%Y%m%d-%H%M%S)"
   
   echo "[INFO] Migrating secrets: $SOURCE → $TARGET"
   
   # Prompt for confirmation
   read -p "This will copy all secrets from $SOURCE to $TARGET. Continue? (y/N): " confirm
   [[ "${confirm^^}" != "Y" ]] && exit 0
   
   # Create backup
   mkdir -p "$BACKUP_DIR"
   echo "[INFO] Creating backup..."
   
   # Export secrets from source
   if [[ "$SOURCE" == "local" ]]; then
       export VAULT_ADDR="http://vault-dev:8200"
       export VAULT_TOKEN="root"  # Or read from local config
   else
       source .devcontainer/data/vault-remote.conf
       export VAULT_ADDR VAULT_TOKEN VAULT_NAMESPACE
   fi
   
   # List all secret paths
   mapfile -t secret_paths < <(vault kv list -format=json secret/ | jq -r '.[]')
   
   echo "[INFO] Found ${#secret_paths[@]} secret paths"
   
   # Export each secret
   for path in "${secret_paths[@]}"; do
       vault kv get -format=json "secret/$path" > "$BACKUP_DIR/$path.json"
   done
   
   echo "[SUCCESS] Backup created: $BACKUP_DIR"
   
   # Import to target
   if [[ "$TARGET" == "local" ]]; then
       export VAULT_ADDR="http://vault-dev:8200"
       export VAULT_TOKEN="root"
   else
       source .devcontainer/data/vault-remote.conf
       export VAULT_ADDR VAULT_TOKEN VAULT_NAMESPACE
   fi
   
   # Import each secret
   for json_file in "$BACKUP_DIR"/*.json; do
       path=$(basename "$json_file" .json)
       
       # Extract key-value pairs
       while IFS='=' read -r key value; do
           vault kv put "secret/$path" "$key=$value"
       done < <(jq -r '.data.data | to_entries | .[] | "\(.key)=\(.value)"' "$json_file")
       
       echo "[SUCCESS] Migrated: secret/$path"
   done
   
   echo "[SUCCESS] ✅ Migration complete: $SOURCE → $TARGET"
   ```

2. **Conflict Resolution**:
   - If secret exists in target, prompt: Overwrite, Skip, Merge
   - Default: Skip (non-destructive)

3. **Rollback**:
   - Keep backup automatically
   - Provide rollback command: `vault-migrate.sh --rollback <backup-dir>`

**Acceptance Criteria**:
- Migration works: local → remote
- Migration works: remote → local
- Backup created before migration
- Conflict resolution prompts working
- Rollback tested and functional

---

### TR-5: Automatic Detection
**Priority**: P1 (High)  
**Description**: Detect existing Vault setup and configure automatically

**Requirements**:
1. **Detection Logic** (in wizard):
   ```bash
   step_detect_vault_setup() {
       echo "[INFO] Detecting existing Vault setup..."
       
       # Check for remote config
       if [[ -f .devcontainer/data/vault-remote.conf ]]; then
           source .devcontainer/data/vault-remote.conf
           echo "[SUCCESS] Remote Vault configuration detected"
           echo "  Address: $VAULT_ADDR"
           echo "  Auth Method: $VAULT_AUTH_METHOD"
           
           read -p "Use existing remote configuration? (Y/n): " use_existing
           use_existing=${use_existing:-Y}
           
           if [[ "${use_existing^^}" == "Y" ]]; then
               VAULT_TYPE="remote"
               return
           fi
       fi
       
       # Check for local persistent Vault
       if [[ -d .devcontainer/data/vault-data/raft ]]; then
           echo "[SUCCESS] Local persistent Vault data detected"
           
           read -p "Use existing local Vault? (Y/n): " use_existing
           use_existing=${use_existing:-Y}
           
           if [[ "${use_existing^^}" == "Y" ]]; then
               VAULT_TYPE="local"
               VAULT_MODE="persistent"
               return
           fi
       fi
       
       # Check for remote Vault template (team setup)
       if [[ -f .devcontainer/data/vault-remote.conf.template ]]; then
           echo "[INFO] Remote Vault template detected (team configuration)"
           
           read -p "Initialize from team template? (Y/n): " use_template
           use_template=${use_template:-Y}
           
           if [[ "${use_template^^}" == "Y" ]]; then
               VAULT_TYPE="remote"
               step_remote_vault_config  # Will auto-load template
               return
           fi
       fi
       
       echo "[INFO] No existing Vault setup detected. Starting fresh setup..."
   }
   ```

2. **Environment Variable Detection**:
   - Check for `VAULT_ADDR` in environment
   - If set and not localhost, assume remote Vault
   - Prompt to use or override

**Acceptance Criteria**:
- Wizard detects existing remote config
- Wizard detects existing local persistent data
- Wizard detects team template
- Detection results shown to user with clear prompts

---

### TR-6: Validation Extensions
**Priority**: P1 (High)  
**Description**: Extend validation to support remote Vault

**Requirements**:
1. **Remote Vault Checks** (in `validate-vault-setup.sh`):
   ```bash
   check_remote_vault() {
       if [[ "$VAULT_TYPE" != "remote" ]]; then
           return
       fi
       
       echo -n "[INFO] Validating remote Vault connectivity... "
       
       # Test reachability
       if ! curl -sf --max-time 10 "$VAULT_ADDR/v1/sys/health" > /dev/null; then
           echo "[ERROR] Remote Vault unreachable: $VAULT_ADDR"
           CHECKS_FAILED=$((CHECKS_FAILED + 1))
           
           # Offer failover
           read -p "Switch to local Vault? (y/N): " switch_local
           if [[ "${switch_local^^}" == "Y" ]]; then
               vault-mode switch local --auto-failover
           fi
           return
       fi
       
       echo "[SUCCESS]"
       CHECKS_PASSED=$((CHECKS_PASSED + 1))
       
       # Test authentication
       echo -n "[INFO] Validating remote Vault authentication... "
       if ! vault token lookup > /dev/null 2>&1; then
           echo "[ERROR] Authentication failed"
           CHECKS_FAILED=$((CHECKS_FAILED + 1))
           return
       fi
       
       echo "[SUCCESS]"
       CHECKS_PASSED=$((CHECKS_PASSED + 1))
       
       # Test secret read access
       echo -n "[INFO] Validating secret read access... "
       if ! vault kv list secret/ > /dev/null 2>&1; then
           echo "[WARNING] Cannot list secrets (permission issue?)"
           CHECKS_WARNING=$((CHECKS_WARNING + 1))
       else
           echo "[SUCCESS]"
           CHECKS_PASSED=$((CHECKS_PASSED + 1))
       fi
   }
   ```

2. **Failover Testing**:
   ```bash
   check_failover_capability() {
       if [[ "$VAULT_TYPE" != "remote" ]]; then
           return
       fi
       
       echo -n "[INFO] Testing failover to local Vault... "
       
       # Check if local Vault data exists
       if [[ -d .devcontainer/data/vault-data/raft ]]; then
           echo "[SUCCESS] Local Vault available for failover"
           CHECKS_PASSED=$((CHECKS_PASSED + 1))
       else
           echo "[WARNING] No local Vault data. Failover not possible."
           CHECKS_WARNING=$((CHECKS_WARNING + 1))
       fi
   }
   ```

**Acceptance Criteria**:
- Validation detects remote vs local Vault
- Remote connectivity tested
- Authentication validated
- Failover capability checked
- Clear error messages with actionable suggestions

---

### TR-7: Failover Automation
**Priority**: P2 (Medium)  
**Description**: Automatically failover to local Vault if remote unavailable

**Requirements**:
1. **Failover Script**: `.devcontainer/scripts/vault-failover.sh`
   ```bash
   #!/usr/bin/env bash
   # Automatic failover from remote to local Vault
   
   set -euo pipefail
   
   REMOTE_VAULT_ADDR="$VAULT_ADDR"
   LOCAL_VAULT_ADDR="http://vault-dev:8200"
   
   # Test remote connectivity
   if curl -sf --max-time 5 "$REMOTE_VAULT_ADDR/v1/sys/health" > /dev/null; then
       echo "[SUCCESS] Remote Vault is reachable"
       exit 0
   fi
   
   echo "[WARNING] Remote Vault unreachable: $REMOTE_VAULT_ADDR"
   echo "[INFO] Initiating failover to local Vault..."
   
   # Check if local Vault available
   if ! curl -sf --max-time 5 "$LOCAL_VAULT_ADDR/v1/sys/health" > /dev/null; then
       echo "[ERROR] Local Vault also unreachable. Starting local Vault..."
       docker-compose up -d vault-dev
       sleep 5
   fi
   
   # Switch to local
   export VAULT_ADDR="$LOCAL_VAULT_ADDR"
   export VAULT_TOKEN="root"
   
   # Update current session
   echo "export VAULT_ADDR=\"$LOCAL_VAULT_ADDR\"" > /tmp/vault-failover.env
   echo "export VAULT_TOKEN=\"root\"" >> /tmp/vault-failover.env
   
   echo "[SUCCESS] ✅ Failover complete. Using local Vault."
   echo "[INFO] To restore remote, run: vault-mode switch remote"
   ```

2. **Integration with Scripts**:
   - Add failover check to all Vault-dependent scripts
   - Wrapper function: `ensure_vault_connection()`
   - Transparent failover (scripts continue working)

3. **Notification**:
   - Log failover events to `.devcontainer/logs/vault-failover.log`
   - Show banner in terminal: "⚠️  Using LOCAL Vault (failover mode)"

**Acceptance Criteria**:
- Failover triggered when remote unavailable
- Local Vault starts automatically if not running
- Scripts continue working after failover
- User notified of failover state
- Easy restoration to remote when available

---

## Architecture & Design

### System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Developer Machine                       │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              DevContainer                            │   │
│  │  ┌────────────────────────────────────────────────┐  │   │
│  │  │  Vault CLI + Scripts                           │  │   │
│  │  │  ┌──────────────────────────────────────────┐  │  │   │
│  │  │  │ vault-mode CLI                           │  │  │   │
│  │  │  │  - switch local/remote                   │  │  │   │
│  │  │  │  - auto-failover detection               │  │  │   │
│  │  │  └──────────────────────────────────────────┘  │  │   │
│  │  └────────────────────────────────────────────────┘  │   │
│  │                        │                              │   │
│  │           ┌────────────┴────────────┐                 │   │
│  │           │                         │                 │   │
│  │           ▼                         ▼                 │   │
│  │  ┌──────────────────┐    ┌──────────────────────┐    │   │
│  │  │  Local Vault     │    │  Remote Vault        │    │   │
│  │  │  (Docker)        │    │  Connectivity        │    │   │
│  │  │                  │    │                      │    │   │
│  │  │  Persistent:     │    │  VAULT_ADDR:         │    │   │
│  │  │  /vault/data     │    │  https://...         │    │   │
│  │  │                  │    │                      │    │   │
│  │  │  Failover target │    │  Auth: GitHub/Token  │    │   │
│  │  └──────────────────┘    └──────────┬───────────┘    │   │
│  └──────────────────────────────────────│────────────────┘   │
└─────────────────────────────────────────│────────────────────┘
                                          │
                                          │ HTTPS
                                          ▼
                 ┌────────────────────────────────────────┐
                 │       Remote Vault Instance            │
                 │  ┌──────────────────────────────────┐  │
                 │  │  HCP Vault / AWS / GCP / OnPrem │  │
                 │  │                                  │  │
                 │  │  - Centralized secrets           │  │
                 │  │  - Team-shared policies          │  │
                 │  │  - Production parity             │  │
                 │  └──────────────────────────────────┘  │
                 └────────────────────────────────────────┘
```

### Decision Flow: Local vs Remote

```
┌───────────────┐
│  Wizard Start │
└───────┬───────┘
        │
        ▼
┌───────────────────────────┐
│ Detect Existing Setup     │
└───────┬───────────────────┘
        │
        ├─── vault-remote.conf exists ────┐
        │                                  │
        │                                  ▼
        │                        ┌──────────────────┐
        │                        │ Use Remote?      │
        │                        │  [Y/n]           │
        │                        └────────┬─────────┘
        │                                 │
        │                        ┌────────┴────────┐
        │                        │                 │
        │                       YES               NO
        │                        │                 │
        │                        ▼                 ▼
        │              ┌──────────────────┐   Continue
        │              │ Use Remote Vault │
        │              └──────────────────┘
        │
        ├─── vault-data/raft exists ──────┐
        │                                  │
        │                                  ▼
        │                        ┌──────────────────┐
        │                        │ Use Local?       │
        │                        │  [Y/n]           │
        │                        └────────┬─────────┘
        │                                 │
        │                        ┌────────┴────────┐
        │                        │                 │
        │                       YES               NO
        │                        │                 │
        │                        ▼                 ▼
        │              ┌──────────────────┐   Continue
        │              │ Use Local Vault  │
        │              └──────────────────┘
        │
        └─── No existing setup ───────────┐
                                          │
                                          ▼
                              ┌────────────────────┐
                              │ Vault Type Prompt  │
                              │  [L] Local         │
                              │  [R] Remote        │
                              └────────┬───────────┘
                                       │
                              ┌────────┴────────┐
                              │                 │
                            LOCAL            REMOTE
                              │                 │
                              ▼                 ▼
                    ┌──────────────────┐  ┌───────────────┐
                    │ Mode Selection   │  │ Remote Config │
                    │  [P] Persistent  │  │  - Address    │
                    │  [E] Ephemeral   │  │  - Auth       │
                    └──────────────────┘  └───────────────┘
```

---

## Implementation Plan

### Phase 1: Remote Configuration (Week 1)
**Tasks**:
1. **Configuration Files**
   - Create `vault-remote.conf` structure
   - Create `vault-remote.conf.template`
   - Update `.gitignore` (ignore conf, track template)

2. **Wizard Prompts**
   - Add `step_vault_type_selection()`
   - Add `step_remote_vault_config()`
   - Add `step_remote_vault_auth()`

3. **Basic Connectivity**
   - Test connection to HCP Vault
   - Implement GitHub auth
   - Implement Token auth

**Deliverables**:
- ✅ Remote Vault configuration working
- ✅ GitHub/Token authentication functional
- ✅ Wizard prompts for remote setup

---

### Phase 2: CLI Switcher & Migration (Week 2)
**Tasks**:
1. **Extend CLI Switcher**
   - Add remote mode to `vault-mode switch`
   - Implement configuration updates
   - Test switching: local → remote → local

2. **Migration Script**
   - Create `vault-migrate.sh`
   - Implement local → remote migration
   - Implement remote → local migration
   - Add conflict resolution

3. **Backup/Rollback**
   - Automatic backup before migration
   - Rollback command implementation

**Deliverables**:
- ✅ CLI switcher supports remote
- ✅ Bidirectional migration working
- ✅ Backup/rollback tested

---

### Phase 3: Detection & Failover (Week 3)
**Tasks**:
1. **Automatic Detection**
   - Implement `step_detect_vault_setup()`
   - Detect remote config
   - Detect local data
   - Detect team templates

2. **Failover Logic**
   - Create `vault-failover.sh`
   - Integrate with scripts
   - Test remote outage scenarios
   - Test auto-recovery

3. **Wrapper Functions**
   - Create `ensure_vault_connection()`
   - Add to all Vault-dependent scripts
   - Transparent failover

**Deliverables**:
- ✅ Detection working for all scenarios
- ✅ Failover automated and tested
- ✅ Scripts resilient to remote outages

---

### Phase 4: Validation & Polish (Week 4)
**Tasks**:
1. **Validation Extensions**
   - Add `check_remote_vault()`
   - Add `check_failover_capability()`
   - Test all validation scenarios

2. **AppRole Authentication**
   - Implement AppRole in wizard
   - Test role_id + secret_id auth
   - Document AppRole setup

3. **Integration Testing**
   - Test full wizard (remote HCP Vault)
   - Test mode switching
   - Test failover scenarios
   - Test migration workflows

**Deliverables**:
- ✅ Validation covers remote Vault
- ✅ AppRole authentication working
- ✅ All integration tests passing

---

### Phase 5: Documentation & Release (Week 5)
**Tasks**:
1. **VAULT_REMOTE.md**
   - HCP Vault setup guide
   - Self-hosted Vault guide
   - Authentication methods
   - Troubleshooting

2. **VAULT_SETUP.md Updates**
   - Add remote sections
   - Update decision tree
   - Add migration guides

3. **HCP Vault Guide**
   - Step-by-step HCP setup
   - Screenshots/examples
   - Best practices

**Deliverables**:
- ✅ `VAULT_REMOTE.md` complete
- ✅ `VAULT_SETUP.md` updated
- ✅ HCP guide published
- ✅ Ready for production use

---

## Testing Strategy

### Unit Tests

**Test File**: `test/unit/vault-remote.test.ts`

```typescript
import { expect } from 'chai';
import * as fs from 'fs';
import * as path from 'path';

describe('Remote Vault Configuration', () => {
  const remoteConfPath = path.join(__dirname, '../../.devcontainer/data/vault-remote.conf');

  it('should parse remote vault configuration', () => {
    if (fs.existsSync(remoteConfPath)) {
      const config = fs.readFileSync(remoteConfPath, 'utf-8');
      expect(config).to.match(/VAULT_TYPE="remote"/);
      expect(config).to.match(/VAULT_ADDR="https?:\/\/.+"/);
      expect(config).to.match(/VAULT_AUTH_METHOD="(github|token|approle)"/);
    }
  });

  it('should validate VAULT_ADDR format', () => {
    const validAddrs = [
      'https://vault.example.com:8200',
      'http://localhost:8200',
      'https://my-vault.vault.abc123.aws.hashicorp.cloud:8200',
    ];

    validAddrs.forEach((addr) => {
      expect(addr).to.match(/^https?:\/\/.+:\d+$/);
    });
  });

  it('should detect remote Vault type from config', () => {
    // Mock config
    process.env.VAULT_TYPE = 'remote';
    process.env.VAULT_ADDR = 'https://vault.example.com:8200';

    expect(process.env.VAULT_TYPE).to.equal('remote');
    expect(process.env.VAULT_ADDR).to.include('https://');
  });
});
```

---

### Integration Tests

**Test File**: `test/integration/vault-remote-wizard.test.ts`

```typescript
import { expect } from 'chai';
import { execSync } from 'child_process';

describe('Vault Setup Wizard - Remote Mode', () => {
  // NOTE: Requires actual remote Vault for full testing
  // Use HCP Vault dev instance or mock server

  it('should detect remote vault template', () => {
    const output = execSync(
      'bash .devcontainer/scripts/setup/vault-setup-wizard.sh --detect-only',
      { encoding: 'utf-8', cwd: '/workspaces/diamonds_dev_env' }
    );

    if (fs.existsSync('.devcontainer/data/vault-remote.conf.template')) {
      expect(output).to.include('Remote Vault template detected');
    }
  });

  it('should authenticate with GitHub to remote Vault', async function () {
    this.timeout(30000); // Remote auth may be slow

    const githubToken = process.env.GITHUB_TOKEN;
    if (!githubToken) {
      this.skip();
    }

    const output = execSync(
      `echo "${githubToken}" | vault login -method=github -`,
      {
        encoding: 'utf-8',
        env: {
          ...process.env,
          VAULT_ADDR: process.env.REMOTE_VAULT_ADDR || 'https://vault.example.com:8200',
        },
      }
    );

    expect(output).to.include('Success!');
  });
});
```

---

### Functional Tests

**Test Scenarios**:
1. **Remote Vault Setup (HCP)**
   - Run wizard selecting remote
   - Provide HCP Vault address
   - Authenticate with GitHub token
   - Verify connectivity
   - Read/write test secret

2. **Mode Switching (Local → Remote)**
   - Start with local persistent Vault
   - Switch to remote: `vault-mode switch remote`
   - Migrate secrets when prompted
   - Verify secrets in remote Vault

3. **Failover (Remote → Local)**
   - Configure remote Vault
   - Simulate remote outage (disconnect network)
   - Verify automatic failover to local
   - Verify scripts continue working

4. **Template Onboarding**
   - New developer clones repo with template
   - Run wizard
   - Wizard detects template
   - Developer provides only credentials
   - Verify connected to team Vault

5. **Bidirectional Migration**
   - Local Vault with secrets
   - Migrate to remote
   - Verify secrets copied
   - Migrate back to local
   - Verify round-trip successful

---

## Documentation Plan

### VAULT_REMOTE.md (New File)

```markdown
# Remote Vault Connectivity

## Overview
This guide explains how to connect your DevContainer to a remote Vault instance.

## Supported Remote Vault Providers
- **HashiCorp Cloud Platform (HCP) Vault**: Recommended for teams
- **Self-Hosted Vault**: AWS, GCP, Azure, on-premise
- **Vault Enterprise**: With namespace support

## Quick Start: HCP Vault

### 1. Create HCP Vault Cluster
1. Visit https://portal.cloud.hashicorp.com
2. Create new Vault cluster
3. Note your cluster URL (e.g., `https://my-vault.vault.11eb1a1c-23c4-42c9-abcd-1234567890ab.aws.hashicorp.cloud:8200`)

### 2. Enable GitHub Authentication
```bash
# In HCP Vault UI:
# - Go to Access → Auth Methods
# - Enable GitHub auth
# - Configure your GitHub organization
```

### 3. Run DevContainer Wizard
```bash
bash .devcontainer/scripts/setup/vault-setup-wizard.sh
```

Select:
- Vault Type: **[R] Remote**
- Vault Address: `<your-hcp-vault-url>`
- Auth Method: **[1] GitHub**
- GitHub Token: `<your-github-token>`

### 4. Verify Connection
```bash
vault status
vault kv list secret/
```

## Authentication Methods

### GitHub Authentication (Recommended)
**Best for**: Teams using GitHub

**Setup**:
1. Create GitHub personal access token: https://github.com/settings/tokens
2. Required scopes: `read:user`, `read:org`
3. Authenticate:
   ```bash
   vault login -method=github token=<your-token>
   ```

**Pros**: Single sign-on, team management via GitHub orgs  
**Cons**: Requires internet for auth

---

### Token Authentication
**Best for**: Temporary access, testing

**Setup**:
1. Generate token in Vault UI or CLI
2. Authenticate:
   ```bash
   vault login token=<your-token>
   ```

**Pros**: Simple, works offline (if token cached)  
**Cons**: Manual token management, no SSO

---

### AppRole Authentication
**Best for**: CI/CD, automated systems

**Setup**:
1. Create AppRole in Vault:
   ```bash
   vault write auth/approle/role/devcontainer \
       secret_id_ttl=24h \
       token_ttl=1h \
       token_max_ttl=4h \
       policies="dev-policy"
   ```

2. Get credentials:
   ```bash
   vault read auth/approle/role/devcontainer/role-id
   vault write -f auth/approle/role/devcontainer/secret-id
   ```

3. Authenticate:
   ```bash
   vault write auth/approle/login \
       role_id=<role-id> \
       secret_id=<secret-id>
   ```

**Pros**: No human user required, credential rotation  
**Cons**: More complex setup

## Switching Between Local and Remote

### Switch to Remote
```bash
vault-mode switch remote
```

### Switch to Local
```bash
vault-mode switch local
```

### Migrate Secrets
```bash
# Local → Remote
vault-migrate --from local --to remote

# Remote → Local
vault-migrate --from remote --to local
```

## Failover to Local Vault

If remote Vault is unreachable, automatic failover occurs:

```
[WARNING] Remote Vault unreachable: https://vault.example.com:8200
[INFO] Initiating failover to local Vault...
[SUCCESS] ✅ Failover complete. Using local Vault.
```

To restore remote:
```bash
vault-mode switch remote
```

## Troubleshooting

### "Error: remote Vault unreachable"
**Causes**:
- Network connectivity issue
- Vault cluster stopped/deleted
- Firewall blocking port 8200

**Solutions**:
1. Check Vault cluster status in HCP UI
2. Verify network connectivity: `curl https://your-vault-url:8200/v1/sys/health`
3. Check firewall rules
4. Use local failover: `vault-mode switch local`

### "Error: GitHub authentication failed"
**Causes**:
- Invalid GitHub token
- GitHub auth not enabled in Vault
- Wrong GitHub organization configured

**Solutions**:
1. Verify token: https://github.com/settings/tokens
2. Check token scopes: `read:user`, `read:org`
3. Verify GitHub auth enabled: `vault auth list`
4. Check organization config: `vault read auth/github/config`

### "Error: permission denied"
**Causes**:
- Token expired
- Insufficient policy permissions

**Solutions**:
1. Re-authenticate: `vault login -method=github`
2. Check token TTL: `vault token lookup`
3. Verify policies: `vault token lookup -format=json | jq -r '.data.policies'`

## Best Practices

### Security
- ✅ Use HTTPS for remote Vault (never HTTP in production)
- ✅ Rotate tokens regularly (max TTL: 24h recommended)
- ✅ Use least-privilege policies (dev vs prod namespaces)
- ✅ Never commit `vault-remote.conf` to Git (use template)
- ✅ Enable audit logging in remote Vault

### Team Collaboration
- ✅ Provide `vault-remote.conf.template` for team
- ✅ Use GitHub auth for SSO
- ✅ Document team-specific policies in README
- ✅ Use namespaces for dev/test/staging isolation (Enterprise)

### Performance
- ✅ Use local Vault for offline development
- ✅ Cache tokens to reduce auth calls
- ✅ Use failover for network reliability
- ✅ Minimize secrets read frequency

## HCP Vault Setup (Detailed)

### Step 1: Create HCP Account
1. Visit https://portal.cloud.hashicorp.com
2. Sign up with GitHub (recommended) or email
3. Create organization

### Step 2: Create Vault Cluster
1. Click "Create Vault cluster"
2. Choose tier: **Development** (free) or **Starter/Plus**
3. Select region (closest to your team)
4. Wait for cluster creation (~5 min)

### Step 3: Generate Admin Token
1. Go to cluster overview
2. Click "Generate admin token"
3. Copy token (you'll need it for initial setup)

### Step 4: Enable GitHub Auth
1. Access Vault UI (click "Access Vault" button)
2. Login with admin token
3. Go to **Access → Auth Methods**
4. Click **Enable new method → GitHub**
5. Configure:
   - **Organization**: Your GitHub org name
   - **Base URL**: `https://github.com` (default)
6. Click **Enable Method**

### Step 5: Create Policies
```bash
# Admin policy (full access)
vault policy write admin-policy - <<EOF
path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOF

# Dev policy (secrets read/write, no admin)
vault policy write dev-policy - <<EOF
path "secret/dev/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "secret/test/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
EOF
```

### Step 6: Map GitHub Teams to Policies
```bash
# Admins team → admin-policy
vault write auth/github/map/teams/admins value=admin-policy

# Developers team → dev-policy
vault write auth/github/map/teams/developers value=dev-policy
```

### Step 7: Test Connection
```bash
export VAULT_ADDR="<your-hcp-vault-url>"
vault login -method=github token=<your-github-token>
vault kv put secret/dev/test value="Hello from HCP Vault"
vault kv get secret/dev/test
```

## See Also
- [VAULT_SETUP.md](./VAULT_SETUP.md) - Local Vault setup
- [HashiCorp Cloud Platform Docs](https://developer.hashicorp.com/hcp/docs/vault)
- [Vault Authentication Methods](https://developer.hashicorp.com/vault/docs/auth)
```

---

### VAULT_SETUP.md Updates

**New Section**:

```markdown
## Remote Vault

For connecting to remote Vault instances (HCP Vault, self-hosted), see:
- **[VAULT_REMOTE.md](./.devcontainer/docs/VAULT_REMOTE.md)**: Complete remote setup guide
- **[HCP Vault Guide](./.devcontainer/docs/VAULT_REMOTE.md#hcp-vault-setup-detailed)**: Step-by-step HCP setup

### Quick Remote Setup
```bash
# Run wizard and select Remote
bash .devcontainer/scripts/setup/vault-setup-wizard.sh

# Or use template (team setup)
cp .devcontainer/data/vault-remote.conf.template \
   .devcontainer/data/vault-remote.conf
# Edit vault-remote.conf with your credentials
```

### Switching Modes
```bash
# Switch to remote
vault-mode switch remote

# Switch to local
vault-mode switch local
```
```

---

## Risks & Mitigation

### Risk 1: Network Dependency
**Severity**: High  
**Impact**: Remote Vault unavailable = no secret access  
**Mitigation**:
- Automatic failover to local Vault
- Local Vault maintains secret cache
- Offline mode detection and switching
- Clear notifications to user

---

### Risk 2: Credential Exposure
**Severity**: High  
**Impact**: GitHub tokens or Vault tokens in plaintext config  
**Mitigation**:
- Add `vault-remote.conf` to `.gitignore` (enforced)
- Prompt for credentials at runtime (default)
- Warn when storing credentials in config
- Document credential rotation policies

---

### Risk 3: HCP Vault Costs
**Severity**: Medium  
**Impact**: Unexpected cloud costs for teams  
**Mitigation**:
- Document HCP pricing clearly
- Recommend Development tier (free)
- Provide self-hosted alternative
- Cost estimation in docs

---

### Risk 4: Authentication Complexity
**Severity**: Medium  
**Impact**: Users confused by multiple auth methods  
**Mitigation**:
- Default to GitHub (simplest for teams)
- Clear wizard prompts
- Step-by-step HCP guide
- Troubleshooting section in docs

---

### Risk 5: Migration Data Loss
**Severity**: Medium  
**Impact**: Secrets lost during local ↔ remote migration  
**Mitigation**:
- Automatic backup before migration (enforced)
- Dry-run mode to preview migration
- Conflict resolution prompts
- Rollback capability tested

---

## Timeline & Milestones

### Milestone 1: Remote Configuration (Week 1)
**Deadline**: End of Week 6 (after Persistence PRD Week 5)  
**Deliverables**:
- ✅ `vault-remote.conf` structure
- ✅ Wizard prompts for remote
- ✅ GitHub + Token authentication

---

### Milestone 2: CLI & Migration (Week 2)
**Deadline**: End of Week 7  
**Deliverables**:
- ✅ CLI switcher supports remote
- ✅ Bidirectional migration working
- ✅ Backup/rollback tested

---

### Milestone 3: Detection & Failover (Week 3)
**Deadline**: End of Week 8  
**Deliverables**:
- ✅ Automatic detection implemented
- ✅ Failover automated
- ✅ Scripts resilient to outages

---

### Milestone 4: Validation & AppRole (Week 4)
**Deadline**: End of Week 9  
**Deliverables**:
- ✅ Validation covers remote
- ✅ AppRole authentication working
- ✅ Integration tests passing

---

### Milestone 5: Documentation & Release (Week 5)
**Deadline**: End of Week 10  
**Deliverables**:
- ✅ `VAULT_REMOTE.md` complete
- ✅ HCP guide published
- ✅ Ready for production use

---

## Acceptance Criteria (Overall)

### Functional Requirements
- ✅ Connect to HCP Vault successfully
- ✅ Authenticate with GitHub, Token, AppRole
- ✅ Switch between local and remote via CLI
- ✅ Migrate secrets bidirectionally (local ↔ remote)
- ✅ Automatic failover from remote to local
- ✅ Template detection and auto-configuration

### Non-Functional Requirements
- ✅ Failover completes within 10 seconds
- ✅ Migration creates backup (100% of cases)
- ✅ Remote config gitignored (no credential leaks)
- ✅ 80%+ test coverage (unit + integration)
- ✅ Clear error messages for all auth failures

### User Experience
- ✅ Wizard provides equal local/remote priority
- ✅ Template onboarding reduces setup time to <5 min
- ✅ Failover transparent to user workflows
- ✅ Documentation comprehensive (HCP guide)

---

## Appendix

### A. File Changes Summary

**New Files**:
- `.devcontainer/data/vault-remote.conf` (gitignored)
- `.devcontainer/data/vault-remote.conf.template`
- `.devcontainer/scripts/vault-migrate.sh`
- `.devcontainer/scripts/vault-failover.sh`
- `.devcontainer/docs/VAULT_REMOTE.md`
- `test/unit/vault-remote.test.ts`
- `test/integration/vault-remote-wizard.test.ts`

**Modified Files**:
- `.devcontainer/scripts/setup/vault-setup-wizard.sh` (add remote prompts)
- `.devcontainer/scripts/vault-mode` (extend with remote support)
- `.devcontainer/scripts/validate-vault-setup.sh` (add remote checks)
- `.devcontainer/data/.gitignore` (add vault-remote.conf)
- `docs/VAULT_SETUP.md` (add remote section)

---

### B. Dependencies

**External**:
- HashiCorp Cloud Platform (optional): For HCP Vault
- GitHub API: For GitHub authentication
- TLS/HTTPS: For secure remote connectivity

**Internal**:
- Vault CLI: For remote Vault operations
- curl: For connectivity tests
- jq: For JSON parsing

---

### C. Environment Variables

**New Variables**:
- `VAULT_TYPE`: `local` | `remote`
- `VAULT_NAMESPACE`: HCP Vault namespace (Enterprise)
- `VAULT_AUTH_METHOD`: `github` | `token` | `approle`
- `VAULT_GITHUB_TOKEN`: GitHub personal access token (runtime)
- `VAULT_ROLE_ID`: AppRole role_id (stored)
- `VAULT_SECRET_ID`: AppRole secret_id (runtime, never stored)
- `VAULT_SKIP_VERIFY`: `true` | `false` (TLS verification)

**Modified**:
- `VAULT_ADDR`: Now supports remote URLs (e.g., `https://vault.example.com:8200`)
- `VAULT_TOKEN`: Now sourced from remote auth (GitHub, AppRole)

---

### D. References

- [HashiCorp Cloud Platform](https://portal.cloud.hashicorp.com)
- [HCP Vault Documentation](https://developer.hashicorp.com/hcp/docs/vault)
- [Vault GitHub Auth](https://developer.hashicorp.com/vault/docs/auth/github)
- [Vault AppRole Auth](https://developer.hashicorp.com/vault/docs/auth/approle)
- [Vault Namespaces](https://developer.hashicorp.com/vault/docs/enterprise/namespaces)

---

**Prerequisites Check**:
- ✅ Vault Persistence & CLI Installation PRD must be completed first
- ✅ Local persistent Vault must be working
- ✅ Vault CLI must be installed
- ✅ `vault-mode` CLI must support persistent/ephemeral switching

---

**Next Steps**:
1. Complete **Vault Persistence & CLI Installation PRD** implementation (Weeks 1-5)
2. Review and approve this PRD
3. Begin implementation (Phase 1: Remote Configuration - Week 6)
4. Deploy incrementally to avoid disrupting active development

---

**Approval Signatures**:
- [ ] Product Owner: ______________________  Date: __________
- [ ] Tech Lead: __________________________  Date: __________
- [ ] DevOps: _____________________________  Date: __________
