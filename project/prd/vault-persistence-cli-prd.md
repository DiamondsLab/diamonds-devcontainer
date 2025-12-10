# Product Requirements Document: HashiCorp Vault Persistence & CLI Installation

**Document Version:** 1.0  
**Date:** October 21, 2025  
**Author:** GitHub Copilot (AI Coding Agent)  
**Status:** Completed
**Project:** Diamonds Development Environment - DevContainer  
**Related PRDs:** Remote Vault Connectivity (follows this PRD)

---

## Executive Summary

This PRD defines requirements for adding **file-based persistence** and **Vault CLI installation** to the existing HashiCorp Vault integration in the Diamonds Development Environment - DevContainer. Currently, Vault runs in ephemeral dev mode where all secrets are lost on container rebuild. This enhancement enables:

1. **Persistent Storage**: Vault data survives container rebuilds via file-based storage in `.devcontainer/data/vault-data/`
2. **Vault CLI Tooling**: Install HashiCorp Vault CLI during container setup for enhanced developer experience
3. **Flexible Configuration**: Users choose between ephemeral dev mode (current) or persistent mode during setup
4. **Backward Compatibility**: Existing workflows continue without modification (dev mode remains available)

**Business Value**: Reduces developer friction by eliminating secret re-entry after rebuilds, provides production-like local development environment, and enables advanced Vault CLI workflows.

---

## Problem Statement

### Current State
- **Ephemeral Vault**: Runs with `-dev` flag using in-memory storage
- **Data Loss**: All secrets lost on `docker-compose down`, container rebuild, or DevContainer rebuild
- **Manual Re-entry**: Developers must re-migrate secrets (DEFENDER_API_KEY, ETHERSCAN_API_KEY, etc.) after each rebuild
- **No CLI Access**: Developers cannot use `vault` commands for debugging, policy management, or advanced operations
- **Limited Workflows**: HTTP API-only approach restricts developer tooling options

### User Pain Points
1. **Rebuild Friction**: "I rebuild my container frequently during development, and losing all secrets is frustrating"
2. **Onboarding Overhead**: "New team members spend time re-entering secrets instead of coding"
3. **Debugging Difficulty**: "I can't use `vault` CLI commands to debug auth/policy issues"
4. **Production Parity Gap**: "Local dev mode doesn't match how Vault works in production (persistent, sealed)"

### Success Metrics
- **Developer Time Saved**: Reduce secret re-entry time from ~5 min/rebuild to 0 min
- **Vault CLI Usage**: 80% of developers use CLI commands within first week
- **Rebuild Frequency**: Zero impact on development workflow (no secret loss)
- **Onboarding Time**: Reduce initial Vault setup from 15 min to 5 min (via template/seed)

---

## Goals & Non-Goals

### Goals
✅ **Persistence**: Implement file-based Vault storage surviving container rebuilds  
✅ **CLI Installation**: Add Vault CLI to DevContainer (Docker build + post-create fallback)  
✅ **User Choice**: Wizard prompts for ephemeral vs persistent mode during setup  
✅ **Seal/Unseal Management**: Optional auto-unseal or manual unsealing on container start  
✅ **Validation**: Extend `validate-vault-setup.sh` to detect and validate persistent Vault  
✅ **Documentation**: Update VAULT_SETUP.md with persistence workflows  
✅ **Template Support**: Provide `.devcontainer/data/vault-data.template/` for team sharing  

### Non-Goals
❌ **Remote Vault Connectivity**: Covered in separate PRD (Remote Vault Connectivity)  
❌ **Production Deployment**: This is dev environment only; production Vault setup out of scope  
❌ **HA/Clustering**: Single-node Vault sufficient for local development  
❌ **HSM Integration**: Auto-unseal via cloud KMS not required for dev environment  
❌ **Legacy Migration**: No existing users (new project, per Q10A)  

---

## User Stories

### US-1: Developer Wants Persistent Vault
**As a** developer rebuilding my DevContainer frequently  
**I want** my Vault secrets to persist across rebuilds  
**So that** I don't waste time re-entering secrets after each rebuild  

**Acceptance Criteria**:
- Vault data stored in `.devcontainer/data/vault-data/` (gitignored)
- Secrets survive `docker-compose down && docker-compose up`
- Secrets survive DevContainer rebuild (`.devcontainer` changes)
- Wizard prompts: "Use persistent Vault storage? (Y/n) [default: Y]"

---

### US-2: Developer Wants Vault CLI Access
**As a** developer debugging authentication issues  
**I want** to use `vault` CLI commands  
**So that** I can inspect policies, tokens, and secrets interactively  

**Acceptance Criteria**:
- `vault --version` works in DevContainer terminal
- `vault login` works with root token or GitHub auth
- `vault kv get secret/dev/DEFENDER_API_KEY` retrieves secrets
- Installation failure shows warning but continues (non-blocking)

---

### US-3: Developer Wants to Switch Between Modes
**As a** developer testing different Vault configurations  
**I want** to switch between ephemeral and persistent modes  
**So that** I can test both dev-mode and production-like workflows  

**Acceptance Criteria**:
- CLI command: `vault-mode switch [ephemeral|persistent]`
- Prompts for confirmation before mode change
- Creates backup of current Vault data before switch
- Updates `docker-compose.dev.yml` and restarts Vault service

---

### US-4: Team Lead Wants Seed Data Template
**As a** team lead onboarding new developers  
**I want** to provide a Vault seed data template  
**So that** new devs start with pre-configured secrets (placeholders)  

**Acceptance Criteria**:
- Template file: `.devcontainer/data/vault-data.template/vault.db.template`
- README with instructions to copy and customize
- Template includes placeholder secrets: `DEFENDER_API_KEY=REPLACE_ME`
- Added to `.gitignore` but template tracked in Git

---

### US-5: Developer Wants Secure Sealed Vault
**As a** security-conscious developer  
**I want** Vault to start sealed and require manual unsealing  
**So that** my secrets are protected if someone accesses my machine  

**Acceptance Criteria**:
- Wizard prompts: "Auto-unseal Vault on container start? (y/N) [default: N]"
- If NO: Vault starts sealed, prompt shows unseal command
- If YES: Post-create script auto-unseals with stored unseal keys
- Unseal keys stored in `.devcontainer/data/vault-unseal-keys.json` (gitignored)

---

## Technical Requirements

### TR-1: File-Based Persistence
**Priority**: P0 (Critical)  
**Description**: Replace in-memory dev mode with file-based Raft storage

**Requirements**:
1. Vault storage backend: `raft` (recommended for single-node)
2. Data directory: `.devcontainer/data/vault-data/`
3. Bind mount in `docker-compose.dev.yml`:
   ```yaml
   volumes:
     - ../data/vault-data:/vault/data
   ```
4. Vault config file: `.devcontainer/config/vault-persistent.hcl`:
   ```hcl
   storage "raft" {
     path = "/vault/data"
   }
   listener "tcp" {
     address = "0.0.0.0:8200"
     tls_disable = 1
   }
   api_addr = "http://vault-dev:8200"
   cluster_addr = "http://vault-dev:8201"
   ui = true
   ```
5. Create `.devcontainer/data/vault-data/.gitkeep` (track directory, ignore contents)
6. Update `.devcontainer/data/.gitignore`:
   ```
   vault-data/*
   !vault-data/.gitkeep
   !vault-data.template/
   vault-unseal-keys.json
   ```

**Acceptance Criteria**:
- Vault data persists after `docker-compose restart vault-dev`
- Vault data persists after `docker-compose down && up`
- Vault data persists after DevContainer rebuild
- Directory created automatically if missing

---

### TR-2: Vault CLI Installation
**Priority**: P0 (Critical)  
**Description**: Install HashiCorp Vault CLI in DevContainer

**Requirements**:
1. **Docker Build Installation** (preferred):
   - Add to `.devcontainer/Dockerfile` after Node.js setup:
     ```dockerfile
     # Install HashiCorp Vault CLI
     RUN wget -qO- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null \
         && echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list \
         && apt-get update && apt-get install -y vault \
         && apt-get clean && rm -rf /var/lib/apt/lists/*
     ```

2. **Post-Create Fallback**:
   - Add to `.devcontainer/scripts/post-create.sh`:
     ```bash
     # Install Vault CLI if not present
     if ! command -v vault &> /dev/null; then
         echo "[INFO] Vault CLI not found. Installing via post-create..."
         sudo bash .devcontainer/scripts/setup/install-vault-cli.sh || {
             echo "[WARNING] Vault CLI installation failed. Continuing..."
         }
     fi
     ```

3. **Installation Script**: `.devcontainer/scripts/setup/install-vault-cli.sh`
   - Check for existing installation
   - Download and verify HashiCorp GPG key
   - Add HashiCorp APT repository
   - Install `vault` package
   - Verify installation: `vault --version`
   - Exit code 0 on success, 1 on failure (non-fatal)

**Acceptance Criteria**:
- `vault --version` returns version number
- Installation succeeds in Docker build (99% of cases)
- Post-create fallback works if Docker build skipped
- Installation failure shows warning but doesn't break setup
- CLI available in all terminal sessions

---

### TR-3: Vault Mode Selection
**Priority**: P1 (High)  
**Description**: Allow users to choose ephemeral vs persistent mode during setup

**Requirements**:
1. **Wizard Prompt** (in `vault-setup-wizard.sh`):
   ```bash
   step_vault_mode_selection() {
       echo ""
       echo "╔════════════════════════════════════════════════════════════╗"
       echo "║          Vault Storage Mode Selection                     ║"
       echo "╠════════════════════════════════════════════════════════════╣"
       echo "║ Choose how Vault should store data:                       ║"
       echo "║                                                            ║"
       echo "║ [P] Persistent - File-based storage (recommended)          ║"
       echo "║     └─ Secrets survive container rebuilds                 ║"
       echo "║     └─ Requires manual unseal on restart                  ║"
       echo "║     └─ Production-like workflow                           ║"
       echo "║                                                            ║"
       echo "║ [E] Ephemeral - In-memory dev mode                        ║"
       echo "║     └─ Secrets lost on restart (current behavior)         ║"
       echo "║     └─ Auto-initialized and unsealed                      ║"
       echo "║     └─ Fast iteration, no unseal needed                   ║"
       echo "╚════════════════════════════════════════════════════════════╝"
       
       read -p "Select mode [P/e]: " mode_choice
       mode_choice=${mode_choice:-P}  # Default to Persistent
       
       case "${mode_choice^^}" in
           P|PERSISTENT)
               VAULT_MODE="persistent"
               echo "[INFO] Selected: Persistent mode"
               ;;
           E|EPHEMERAL)
               VAULT_MODE="ephemeral"
               echo "[INFO] Selected: Ephemeral mode (dev)"
               ;;
           *)
               echo "[ERROR] Invalid choice. Defaulting to Persistent."
               VAULT_MODE="persistent"
               ;;
       esac
   }
   ```

2. **Configuration Update**:
   - Store selection in `.devcontainer/data/vault-mode.conf`
   - Update `docker-compose.dev.yml` based on mode:
     - Persistent: Use config file, mount data volume
     - Ephemeral: Use `-dev` flag, no data mount

3. **Non-Interactive Mode**:
   - Flag: `--vault-mode=[persistent|ephemeral]`
   - Default: `persistent`

**Acceptance Criteria**:
- Wizard shows mode selection prompt
- Selection updates `vault-mode.conf`
- `docker-compose.dev.yml` updated correctly
- Vault service restarts with new configuration
- Mode persists across container restarts

---

### TR-4: Seal/Unseal Management
**Priority**: P1 (High)  
**Description**: Handle Vault sealing/unsealing for persistent mode

**Requirements**:
1. **Auto-Unseal Prompt** (wizard):
   ```bash
   if [[ "$VAULT_MODE" == "persistent" ]]; then
       echo ""
       read -p "Auto-unseal Vault on container start? (y/N): " auto_unseal
       auto_unseal=${auto_unseal:-N}
       
       if [[ "${auto_unseal^^}" == "Y" ]]; then
           AUTO_UNSEAL=true
           echo "[WARNING] Auto-unseal is less secure. Unseal keys stored in plaintext."
       else
           AUTO_UNSEAL=false
           echo "[INFO] Vault will require manual unsealing on each start."
       fi
   fi
   ```

2. **Unseal Key Storage**:
   - File: `.devcontainer/data/vault-unseal-keys.json`
   - Format: 
     ```json
     {
       "keys": ["key1", "key2", "key3"],
       "keys_base64": ["b64key1", "b64key2", "b64key3"],
       "root_token": "hvs.xxxxx"
     }
     ```
   - Permissions: `chmod 600` (owner read/write only)
   - Add to `.gitignore`

3. **Auto-Unseal Script**: `.devcontainer/scripts/vault-auto-unseal.sh`
   ```bash
   #!/usr/bin/env bash
   set -euo pipefail
   
   UNSEAL_KEYS_FILE="${VAULT_UNSEAL_KEYS_FILE:-.devcontainer/data/vault-unseal-keys.json}"
   
   if [[ ! -f "$UNSEAL_KEYS_FILE" ]]; then
       echo "[ERROR] Unseal keys file not found: $UNSEAL_KEYS_FILE"
       exit 1
   fi
   
   # Extract unseal keys (Shamir threshold default: 3 of 5)
   mapfile -t UNSEAL_KEYS < <(jq -r '.keys_base64[]' "$UNSEAL_KEYS_FILE" | head -n 3)
   
   for key in "${UNSEAL_KEYS[@]}"; do
       vault operator unseal "$key"
   done
   
   echo "[SUCCESS] Vault unsealed successfully"
   ```

4. **Post-Start Integration**:
   - Add to `.devcontainer/scripts/post-start.sh`:
     ```bash
     # Auto-unseal Vault if configured
     if [[ -f .devcontainer/data/vault-mode.conf ]]; then
         source .devcontainer/data/vault-mode.conf
         
         if [[ "$VAULT_MODE" == "persistent" ]] && [[ "$AUTO_UNSEAL" == "true" ]]; then
             echo "[INFO] Auto-unsealing Vault..."
             bash .devcontainer/scripts/vault-auto-unseal.sh || {
                 echo "[WARNING] Auto-unseal failed. Use: vault operator unseal"
             }
         elif [[ "$VAULT_MODE" == "persistent" ]]; then
             echo "[INFO] Vault is sealed. Unseal with: vault operator unseal"
             echo "[INFO] Unseal keys: cat .devcontainer/data/vault-unseal-keys.json"
         fi
     fi
     ```

**Acceptance Criteria**:
- Wizard prompts for auto-unseal preference
- Unseal keys saved securely (600 permissions)
- Auto-unseal works on container start (if enabled)
- Manual unseal instructions shown (if auto-unseal disabled)
- Sealed Vault prevents secret access (security test)

---

### TR-5: Data Migration & Backup
**Priority**: P1 (High)  
**Description**: Migrate secrets between ephemeral and persistent modes safely

**Requirements**:
1. **Migration Script**: `.devcontainer/scripts/vault-migrate-mode.sh`
   ```bash
   #!/usr/bin/env bash
   # Usage: vault-migrate-mode.sh [ephemeral-to-persistent | persistent-to-ephemeral]
   
   set -euo pipefail
   
   SOURCE_MODE="$1"
   TARGET_MODE="$2"
   BACKUP_DIR=".devcontainer/data/vault-backups/$(date +%Y%m%d-%H%M%S)"
   
   # Prompt for confirmation
   echo "[WARNING] This will migrate Vault data from $SOURCE_MODE to $TARGET_MODE"
   read -p "Create backup before migration? (Y/n): " create_backup
   create_backup=${create_backup:-Y}
   
   if [[ "${create_backup^^}" == "Y" ]]; then
       mkdir -p "$BACKUP_DIR"
       # Snapshot current Vault data
       vault operator raft snapshot save "$BACKUP_DIR/vault-snapshot.snap" || {
           echo "[WARNING] Snapshot failed (dev mode doesn't support snapshots)"
           # Fallback: export secrets as JSON
           vault kv list -format=json secret/dev > "$BACKUP_DIR/secrets-dev.json"
           vault kv list -format=json secret/test > "$BACKUP_DIR/secrets-test.json"
       }
       echo "[SUCCESS] Backup created: $BACKUP_DIR"
   fi
   
   # Export secrets from source
   # Import to target
   # Update configuration
   # Restart Vault
   ```

2. **Wizard Integration**:
   - If switching modes, offer migration
   - Require explicit confirmation
   - Show backup location

3. **Backup Retention**:
   - Keep last 5 backups
   - Older backups auto-deleted
   - Manual restore instructions in docs

**Acceptance Criteria**:
- Migration creates backup before changes
- All secrets transferred successfully
- Backup restore tested and documented
- Migration failures rollback to backup
- Backup directory added to `.gitignore`

---

### TR-6: Validation & Detection
**Priority**: P1 (High)  
**Description**: Extend validation script to detect and validate persistent Vault

**Requirements**:
1. **Vault Mode Detection** (in `validate-vault-setup.sh`):
   ```bash
   check_vault_mode() {
       echo -n "[INFO] Detecting Vault storage mode... "
       
       # Check if using persistent storage
       if [[ -f .devcontainer/data/vault-mode.conf ]]; then
           source .devcontainer/data/vault-mode.conf
           echo "[$VAULT_MODE mode]"
           
           if [[ "$VAULT_MODE" == "persistent" ]]; then
               # Check if sealed
               seal_status=$(curl -s "$VAULT_ADDR/v1/sys/seal-status" | jq -r '.sealed')
               if [[ "$seal_status" == "true" ]]; then
                   echo "[WARNING] Vault is sealed. Unseal required."
                   CHECKS_WARNING=$((CHECKS_WARNING + 1))
               else
                   echo "[SUCCESS] Vault is unsealed"
                   CHECKS_PASSED=$((CHECKS_PASSED + 1))
               fi
               
               # Check data persistence
               if [[ -d .devcontainer/data/vault-data/raft ]]; then
                   echo "[SUCCESS] Persistent storage detected: raft database exists"
                   CHECKS_PASSED=$((CHECKS_PASSED + 1))
               else
                   echo "[ERROR] Persistent mode configured but no data found"
                   CHECKS_FAILED=$((CHECKS_FAILED + 1))
               fi
           fi
       else
           echo "[ephemeral/dev mode]"
           echo "[INFO] Using in-memory dev mode (data not persistent)"
       fi
   }
   ```

2. **Health Checks**:
   - Verify storage backend matches configuration
   - Check data directory permissions
   - Validate unseal key file (if exists)

**Acceptance Criteria**:
- Validation detects persistent vs ephemeral mode
- Reports seal status correctly
- Identifies missing data directories
- Warns if configuration mismatch

---

### TR-7: Template & Seed Data
**Priority**: P2 (Medium)  
**Description**: Provide shareable template for team onboarding

**Requirements**:
1. **Template Directory**: `.devcontainer/data/vault-data.template/`
   ```
   .devcontainer/data/vault-data.template/
   ├── README.md                 # Setup instructions
   ├── vault.db.template         # Pre-initialized Vault database
   └── seed-secrets.json         # Placeholder secrets
   ```

2. **Seed Secrets Format** (`seed-secrets.json`):
   ```json
   {
     "secret/dev/DEFENDER_API_KEY": {
       "value": "REPLACE_WITH_YOUR_DEFENDER_API_KEY"
     },
     "secret/dev/DEFENDER_API_SECRET": {
       "value": "REPLACE_WITH_YOUR_DEFENDER_API_SECRET"
     },
     "secret/dev/ETHERSCAN_API_KEY": {
       "value": "REPLACE_WITH_YOUR_ETHERSCAN_API_KEY"
     },
     "secret/dev/SOCKET_CLI_API_TOKEN": {
       "value": "REPLACE_WITH_YOUR_SOCKET_CLI_API_TOKEN"
     },
     "secret/test/TEST_PRIVATE_KEY": {
       "value": "0x0000000000000000000000000000000000000000000000000000000000000000"
     }
   }
   ```

3. **Setup Script**: `.devcontainer/scripts/vault-init-from-template.sh`
   ```bash
   #!/usr/bin/env bash
   # Initialize Vault from template
   
   TEMPLATE_DIR=".devcontainer/data/vault-data.template"
   TARGET_DIR=".devcontainer/data/vault-data"
   
   if [[ -d "$TARGET_DIR" ]] && [[ -n "$(ls -A "$TARGET_DIR")" ]]; then
       echo "[WARNING] Vault data already exists. Use --force to overwrite."
       exit 1
   fi
   
   echo "[INFO] Initializing Vault from template..."
   cp -r "$TEMPLATE_DIR/"* "$TARGET_DIR/"
   
   # Load seed secrets
   source .env
   export VAULT_ADDR VAULT_TOKEN
   
   while IFS='=' read -r path value; do
       vault kv put "$path" value="$value"
   done < <(jq -r 'to_entries | .[] | "\(.key)=\(.value.value)"' "$TEMPLATE_DIR/seed-secrets.json")
   
   echo "[SUCCESS] Vault initialized from template"
   ```

4. **Wizard Integration**:
   - Step 2: "Initialize from template? (y/N)"
   - If YES: Run `vault-init-from-template.sh`
   - If NO: Proceed with normal setup

5. **Git Tracking**:
   - Track template directory in Git
   - Ignore actual `vault-data/` (developer-specific)
   - Update `.gitignore`:
     ```
     # Vault data (developer-specific)
     .devcontainer/data/vault-data/*
     !.devcontainer/data/vault-data/.gitkeep
     
     # Vault template (team-shared, tracked in Git)
     !.devcontainer/data/vault-data.template/
     ```

**Acceptance Criteria**:
- Template directory tracked in Git
- `seed-secrets.json` has all required placeholders
- Initialization script creates working Vault
- README explains customization process
- Developers can share templates via Git

---

## Architecture & Design

### System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     DevContainer                            │
│  ┌──────────────────────────────────────────────────────┐   │
│  │           Vault CLI (installed)                      │   │
│  │  Commands: vault login, vault kv get, etc.          │   │
│  └──────────────────────────────────────────────────────┘   │
│                           │                                  │
│                           │ VAULT_ADDR=http://vault-dev:8200 │
│                           ▼                                  │
│  ┌──────────────────────────────────────────────────────┐   │
│  │     Docker Compose: vault-dev service                │   │
│  │  ┌────────────────────────────────────────────────┐  │   │
│  │  │ Vault Server (hashicorp/vault:latest)          │  │   │
│  │  │                                                 │  │   │
│  │  │  Mode: persistent OR ephemeral                 │  │   │
│  │  │  Config: /vault/config/vault-persistent.hcl    │  │   │
│  │  │  Storage: raft (/vault/data)                   │  │   │
│  │  │  Listener: tcp://0.0.0.0:8200 (no TLS)         │  │   │
│  │  └────────────────────────────────────────────────┘  │   │
│  │                        │                              │   │
│  │                        ▼                              │   │
│  │  ┌────────────────────────────────────────────────┐  │   │
│  │  │ Volume Mount (persistent mode only)            │  │   │
│  │  │  Host: .devcontainer/data/vault-data/          │  │   │
│  │  │  Container: /vault/data                        │  │   │
│  │  │  Contains: raft/raft.db, snapshots/            │  │   │
│  │  └────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘

Developer Workflows:
1. CLI Access:    vault kv get secret/dev/DEFENDER_API_KEY
2. HTTP API:      curl -H "X-Vault-Token: $TOKEN" $VAULT_ADDR/v1/secret/data/...
3. Scripts:       bash .devcontainer/scripts/vault-fetch-secrets.sh
```

### Configuration Files

1. **Vault Config** (`.devcontainer/config/vault-persistent.hcl`):
   ```hcl
   # Persistent Vault Configuration
   
   storage "raft" {
     path = "/vault/data"
     node_id = "vault-dev-node1"
   }
   
   listener "tcp" {
     address = "0.0.0.0:8200"
     tls_disable = 1
   }
   
   api_addr = "http://vault-dev:8200"
   cluster_addr = "http://vault-dev:8201"
   ui = true
   disable_mlock = true  # Required for Docker
   ```

2. **Docker Compose** (`.devcontainer/docker-compose.dev.yml`):
   ```yaml
   services:
     vault-dev:
       image: hashicorp/vault:latest
       container_name: vault-dev
       environment:
         VAULT_ADDR: 'http://0.0.0.0:8200'
         # Conditional: Remove VAULT_DEV_ROOT_TOKEN_ID for persistent mode
         VAULT_DEV_ROOT_TOKEN_ID: ${VAULT_DEV_ROOT_TOKEN_ID:-root}
       ports:
         - "8200:8200"
       volumes:
         # Always mount config
         - ./config/vault-persistent.hcl:/vault/config/vault.hcl:ro
         # Conditional: Only mount data volume in persistent mode
         - ./data/vault-data:/vault/data
         - vault-logs:/vault/logs
       # Conditional command based on mode:
       # Persistent: vault server -config=/vault/config/vault.hcl
       # Ephemeral:  vault server -dev -dev-root-token-id=root
       command: ${VAULT_COMMAND:-vault server -config=/vault/config/vault.hcl}
       cap_add:
         - IPC_LOCK
       networks:
         - dev-network
   ```

3. **Mode Configuration** (`.devcontainer/data/vault-mode.conf`):
   ```bash
   # Vault Mode Configuration
   # Generated by vault-setup-wizard.sh
   
   VAULT_MODE="persistent"          # persistent | ephemeral
   AUTO_UNSEAL="false"              # true | false
   VAULT_COMMAND="vault server -config=/vault/config/vault.hcl"
   ```

### State Machine: Vault Lifecycle

```
┌─────────────┐
│   Initial   │ (Container start)
└──────┬──────┘
       │
       ▼
┌─────────────────────────────────┐
│ Check vault-mode.conf           │
└──────┬──────────────────────────┘
       │
       ├─── Ephemeral ────────┐
       │                      │
       │                      ▼
       │            ┌──────────────────┐
       │            │ Start Vault -dev │
       │            │ (auto-initialized│
       │            │  auto-unsealed)  │
       │            └──────────────────┘
       │                      │
       │                      ▼
       │            ┌──────────────────┐
       │            │  READY (dev)     │
       │            └──────────────────┘
       │
       └─── Persistent ───────┐
                              │
                              ▼
                    ┌──────────────────┐
                    │ Start Vault      │
                    │ (file backend)   │
                    └────────┬─────────┘
                             │
                             ▼
                    ┌──────────────────┐
                    │ Check if sealed  │
                    └────────┬─────────┘
                             │
                    ┌────────┴────────┐
                    │                 │
              SEALED               UNSEALED
                    │                 │
                    ▼                 ▼
          ┌──────────────────┐  ┌──────────────┐
          │ Auto-unseal?     │  │ READY        │
          └────────┬─────────┘  └──────────────┘
                   │
          ┌────────┴────────┐
          │                 │
         YES               NO
          │                 │
          ▼                 ▼
┌──────────────────┐  ┌─────────────────┐
│ Run auto-unseal  │  │ Show unseal     │
│ script           │  │ instructions    │
└────────┬─────────┘  └─────────────────┘
         │
         ▼
┌──────────────────┐
│ READY (unsealed) │
└──────────────────┘
```

---

## Implementation Plan

### Phase 1: Foundation (Week 1)
**Tasks**:
1. **File Structure Setup**
   - Create `.devcontainer/data/vault-data/` with `.gitkeep`
   - Create `.devcontainer/data/vault-data.template/`
   - Update `.devcontainer/data/.gitignore`
   - Create `vault-persistent.hcl` config

2. **Vault CLI Installation**
   - Add Dockerfile instructions for Vault CLI
   - Create `install-vault-cli.sh` script
   - Update `post-create.sh` with fallback logic
   - Test installation in fresh container

3. **Basic Persistence**
   - Update `docker-compose.dev.yml` with volume mount
   - Test Vault initialization with Raft backend
   - Verify data persistence across container restarts

**Deliverables**:
- ✅ Vault CLI available in DevContainer
- ✅ Persistent storage working (manual configuration)
- ✅ Data survives `docker-compose down && up`

---

### Phase 2: User Choice & Wizard (Week 2)
**Tasks**:
1. **Wizard Mode Selection**
   - Add `step_vault_mode_selection()` to wizard
   - Create `vault-mode.conf` management
   - Update wizard flow diagram

2. **Dynamic Configuration**
   - Create `update-docker-compose.sh` to modify compose file
   - Handle conditional volume mounts
   - Handle conditional command flags

3. **Seal/Unseal Prompts**
   - Add auto-unseal prompt to wizard
   - Create `vault-unseal-keys.json` template
   - Implement secure file permissions (600)

**Deliverables**:
- ✅ Wizard prompts for mode selection
- ✅ Docker Compose updated based on selection
- ✅ Seal/unseal preference captured

---

### Phase 3: Auto-Unseal & Migration (Week 3)
**Tasks**:
1. **Auto-Unseal Implementation**
   - Create `vault-auto-unseal.sh` script
   - Integrate with `post-start.sh`
   - Test auto-unseal on container start

2. **Migration Script**
   - Create `vault-migrate-mode.sh`
   - Implement backup before migration
   - Test ephemeral → persistent migration
   - Test persistent → ephemeral migration

3. **CLI Mode Switcher**
   - Create `vault-mode` CLI command
   - Add to PATH via `.bashrc` update
   - Test mode switching workflow

**Deliverables**:
- ✅ Auto-unseal working (if enabled)
- ✅ Manual unseal instructions shown (if disabled)
- ✅ Migration between modes tested

---

### Phase 4: Validation & Templates (Week 4)
**Tasks**:
1. **Validation Extension**
   - Add `check_vault_mode()` to `validate-vault-setup.sh`
   - Add seal status detection
   - Add persistent storage checks

2. **Template Creation**
   - Create `.devcontainer/data/vault-data.template/`
   - Generate `seed-secrets.json` with placeholders
   - Write template README
   - Create `vault-init-from-template.sh`

3. **Integration Testing**
   - Test full wizard flow (ephemeral mode)
   - Test full wizard flow (persistent mode)
   - Test template initialization
   - Test validation with both modes

**Deliverables**:
- ✅ Validation detects and validates both modes
- ✅ Template setup working
- ✅ All integration tests passing

---

### Phase 5: Documentation & Polish (Week 5)
**Tasks**:
1. **Documentation Updates**
   - Update `VAULT_SETUP.md` with persistence section
   - Add mode switching guide
   - Add seal/unseal workflows
   - Add troubleshooting section

2. **Code Quality**
   - Add unit tests for new scripts
   - Lint all bash scripts (shellcheck)
   - Add JSDoc comments for TypeScript utilities
   - Code review and refactoring

3. **User Experience**
   - Improve wizard UI/prompts
   - Add success/warning/error emojis
   - Add progress indicators
   - Test non-interactive mode

**Deliverables**:
- ✅ `VAULT_SETUP.md` updated
- ✅ All tests passing (unit + integration)
- ✅ Code quality checks pass
- ✅ Wizard UX polished

---

## Testing Strategy

### Unit Tests

**Test File**: `test/unit/vault-persistence.test.ts`

```typescript
import { expect } from 'chai';
import { execSync } from 'child_process';
import * as fs from 'fs';
import * as path from 'path';

describe('Vault Persistence', () => {
  const vaultDataDir = path.join(__dirname, '../../.devcontainer/data/vault-data');
  const vaultModeConf = path.join(__dirname, '../../.devcontainer/data/vault-mode.conf');

  it('should create vault-data directory on initialization', () => {
    expect(fs.existsSync(vaultDataDir)).to.be.true;
  });

  it('should persist secrets across container restarts', async () => {
    // Write secret
    const testSecret = { key: 'test-key', value: 'test-value-12345' };
    await writeVaultSecret('secret/test/persistence', testSecret);

    // Restart Vault container
    execSync('docker-compose restart vault-dev', { cwd: '/workspaces/diamonds_dev_env' });

    // Wait for Vault to be ready
    await waitForVault();

    // Read secret
    const retrievedSecret = await readVaultSecret('secret/test/persistence');
    expect(retrievedSecret.value).to.equal(testSecret.value);
  });

  it('should detect vault mode from config file', () => {
    expect(fs.existsSync(vaultModeConf)).to.be.true;
    const config = fs.readFileSync(vaultModeConf, 'utf-8');
    expect(config).to.match(/VAULT_MODE="(persistent|ephemeral)"/);
  });

  it('should store unseal keys securely (600 permissions)', () => {
    const unsealKeysFile = path.join(__dirname, '../../.devcontainer/data/vault-unseal-keys.json');
    if (fs.existsSync(unsealKeysFile)) {
      const stats = fs.statSync(unsealKeysFile);
      const permissions = (stats.mode & parseInt('777', 8)).toString(8);
      expect(permissions).to.equal('600');
    }
  });
});
```

**Test File**: `test/unit/vault-cli.test.ts`

```typescript
import { expect } from 'chai';
import { execSync } from 'child_process';

describe('Vault CLI Installation', () => {
  it('should have vault CLI installed', () => {
    const version = execSync('vault --version', { encoding: 'utf-8' });
    expect(version).to.match(/Vault v\d+\.\d+\.\d+/);
  });

  it('should authenticate with vault CLI', () => {
    const output = execSync('vault login -method=token token=root', {
      encoding: 'utf-8',
      env: { ...process.env, VAULT_ADDR: 'http://vault-dev:8200' },
    });
    expect(output).to.include('Success!');
  });

  it('should read secrets via vault CLI', () => {
    const output = execSync('vault kv get -format=json secret/dev/DEFENDER_API_KEY', {
      encoding: 'utf-8',
      env: { ...process.env, VAULT_ADDR: 'http://vault-dev:8200', VAULT_TOKEN: 'root' },
    });
    const data = JSON.parse(output);
    expect(data.data.data).to.have.property('value');
  });
});
```

---

### Integration Tests

**Test File**: `test/integration/vault-wizard-persistence.test.ts`

```typescript
import { expect } from 'chai';
import { execSync } from 'child_process';

describe('Vault Setup Wizard - Persistence Mode', () => {
  it('should complete wizard in persistent mode (non-interactive)', () => {
    const output = execSync(
      'bash .devcontainer/scripts/setup/vault-setup-wizard.sh --non-interactive --vault-mode=persistent',
      { encoding: 'utf-8', cwd: '/workspaces/diamonds_dev_env' }
    );

    expect(output).to.include('[SUCCESS]');
    expect(output).to.include('Vault setup verification passed');
  });

  it('should initialize Vault with Raft backend', () => {
    const status = execSync('vault status -format=json', {
      encoding: 'utf-8',
      env: { ...process.env, VAULT_ADDR: 'http://vault-dev:8200', VAULT_TOKEN: 'root' },
    });
    const data = JSON.parse(status);
    expect(data.storage_type).to.equal('raft');
  });

  it('should auto-unseal if configured', async () => {
    // Test auto-unseal workflow
    // 1. Seal Vault
    execSync('vault operator seal', {
      env: { ...process.env, VAULT_ADDR: 'http://vault-dev:8200', VAULT_TOKEN: 'root' },
    });

    // 2. Run auto-unseal script
    const output = execSync('bash .devcontainer/scripts/vault-auto-unseal.sh', {
      encoding: 'utf-8',
      cwd: '/workspaces/diamonds_dev_env',
    });

    expect(output).to.include('[SUCCESS] Vault unsealed successfully');

    // 3. Verify unsealed
    const status = JSON.parse(
      execSync('vault status -format=json', {
        encoding: 'utf-8',
        env: { ...process.env, VAULT_ADDR: 'http://vault-dev:8200' },
      })
    );
    expect(status.sealed).to.be.false;
  });
});
```

---

### Functional Tests

**Test Scenarios**:
1. **Fresh Setup - Persistent Mode**
   - Run wizard selecting persistent mode
   - Verify Vault initializes with Raft storage
   - Write test secret
   - Restart container
   - Verify secret persists

2. **Fresh Setup - Ephemeral Mode**
   - Run wizard selecting ephemeral mode
   - Verify Vault runs in dev mode
   - Write test secret
   - Restart container
   - Verify secret is lost (expected)

3. **Mode Migration - Ephemeral → Persistent**
   - Start with ephemeral mode
   - Write secrets
   - Run `vault-mode switch persistent`
   - Verify secrets migrated
   - Verify new mode active

4. **Template Initialization**
   - Run wizard with "initialize from template"
   - Verify seed secrets loaded
   - Customize secrets
   - Verify customizations persist

5. **Seal/Unseal Workflow**
   - Start Vault in persistent mode
   - Seal Vault manually
   - Restart container
   - Verify auto-unseal (if enabled) or manual unseal prompt

---

## Documentation Plan

### VAULT_SETUP.md Updates

**New Sections**:

1. **Persistence Overview**
   ```markdown
   ## Vault Persistence
   
   ### Overview
   HashiCorp Vault can run in two modes in this DevContainer:
   
   - **Ephemeral Mode** (dev): In-memory storage, data lost on restart
   - **Persistent Mode** (production-like): File-based storage, data survives rebuilds
   
   ### When to Use Each Mode
   - **Ephemeral**: Fast iteration, testing, no sensitive data
   - **Persistent**: Daily development, avoid re-entering secrets, team collaboration
   
   ### Data Location
   - Persistent data: `.devcontainer/data/vault-data/` (gitignored)
   - Unseal keys: `.devcontainer/data/vault-unseal-keys.json` (gitignored)
   - Mode config: `.devcontainer/data/vault-mode.conf`
   ```

2. **Switching Modes**
   ```markdown
   ## Switching Between Modes
   
   ### Using CLI Command
   ```bash
   # Switch to persistent mode
   vault-mode switch persistent
   
   # Switch to ephemeral mode
   vault-mode switch ephemeral
   ```
   
   ### Manual Migration
   1. Export secrets: `bash .devcontainer/scripts/vault-export-secrets.sh`
   2. Stop Vault: `docker-compose stop vault-dev`
   3. Update `vault-mode.conf`: `VAULT_MODE="persistent"`
   4. Update `docker-compose.dev.yml` (mount volumes)
   5. Start Vault: `docker-compose up -d vault-dev`
   6. Import secrets: `bash .devcontainer/scripts/vault-import-secrets.sh`
   ```

3. **Seal/Unseal Management**
   ```markdown
   ## Sealing and Unsealing
   
   ### What is Sealing?
   When Vault is "sealed", it cannot decrypt secrets. This is a security feature.
   
   ### Auto-Unseal
   If enabled during setup, Vault automatically unseals on container start.
   
   **Security Warning**: Auto-unseal stores unseal keys in plaintext. Use manual unsealing for higher security.
   
   ### Manual Unsealing
   ```bash
   # Check seal status
   vault status
   
   # Unseal (requires 3 of 5 keys by default)
   vault operator unseal <key1>
   vault operator unseal <key2>
   vault operator unseal <key3>
   
   # Get unseal keys
   cat .devcontainer/data/vault-unseal-keys.json | jq -r '.keys_base64[]'
   ```
   ```

4. **Template Setup**
   ```markdown
   ## Using Vault Template for Teams
   
   ### Setup for New Developers
   1. Clone repository
   2. Run wizard: `bash .devcontainer/scripts/setup/vault-setup-wizard.sh`
   3. When prompted, select "Initialize from template"
   4. Customize secrets:
      ```bash
      vault kv put secret/dev/DEFENDER_API_KEY value="YOUR_KEY_HERE"
      vault kv put secret/dev/ETHERSCAN_API_KEY value="YOUR_KEY_HERE"
      ```
   
   ### Creating Templates for Your Team
   1. Initialize Vault with desired secrets (use placeholders)
   2. Copy template:
      ```bash
      cp -r .devcontainer/data/vault-data/ .devcontainer/data/vault-data.template/
      ```
   3. Update `.devcontainer/data/vault-data.template/README.md` with instructions
   4. Commit template to Git (ensure `.gitignore` excludes actual `vault-data/`)
   ```

---

### CLI Reference

**New File**: `.devcontainer/docs/VAULT_CLI.md`

```markdown
# Vault CLI Reference

## Installation
The Vault CLI is automatically installed during DevContainer setup.

## Common Commands

### Authentication
```bash
# Login with root token
vault login token=root

# Login with GitHub (if configured)
vault login -method=github token=$GITHUB_TOKEN
```

### Reading Secrets
```bash
# Get secret (formatted)
vault kv get secret/dev/DEFENDER_API_KEY

# Get secret (JSON)
vault kv get -format=json secret/dev/DEFENDER_API_KEY

# Get secret value only
vault kv get -field=value secret/dev/DEFENDER_API_KEY
```

### Writing Secrets
```bash
# Create/update secret
vault kv put secret/dev/MY_SECRET value="my-secret-value"

# Update with multiple fields
vault kv put secret/dev/MY_SECRET \
  value="secret-value" \
  description="My secret description"
```

### Listing Secrets
```bash
# List secrets under path
vault kv list secret/dev

# Recursive listing (all paths)
vault kv list -format=json secret/
```

### Deleting Secrets
```bash
# Soft delete (can be recovered)
vault kv delete secret/dev/OLD_SECRET

# Permanent delete
vault kv metadata delete secret/dev/OLD_SECRET
```

### Seal/Unseal Operations
```bash
# Check seal status
vault status

# Seal Vault (requires token)
vault operator seal

# Unseal Vault (requires unseal keys)
vault operator unseal <unseal-key-1>
vault operator unseal <unseal-key-2>
vault operator unseal <unseal-key-3>
```

### Backup & Restore
```bash
# Create snapshot (Raft backend only)
vault operator raft snapshot save backup.snap

# Restore from snapshot
vault operator raft snapshot restore backup.snap
```

## Troubleshooting

### "Error: vault CLI not found"
**Solution**: Run installation script
```bash
bash .devcontainer/scripts/setup/install-vault-cli.sh
```

### "Error: vault is sealed"
**Solution**: Unseal Vault
```bash
# Get unseal keys
cat .devcontainer/data/vault-unseal-keys.json | jq -r '.keys_base64[]'

# Unseal (use 3 keys)
vault operator unseal <key>
```

### "Error: permission denied"
**Solution**: Authenticate with valid token
```bash
export VAULT_TOKEN=root
# or
vault login token=root
```
```

---

## Risks & Mitigation

### Risk 1: Data Loss During Migration
**Severity**: High  
**Impact**: Developers lose all secrets during mode migration  
**Mitigation**:
- Always create backup before migration (enforced in script)
- Prompt for confirmation before destructive actions
- Keep last 5 backups automatically
- Test migration in CI before release

---

### Risk 2: Unseal Keys Exposure
**Severity**: High  
**Impact**: Unseal keys stored in plaintext (if auto-unseal enabled)  
**Mitigation**:
- Default to manual unsealing (more secure)
- Warn users about auto-unseal security implications
- Store unseal keys with 600 permissions
- Add to `.gitignore` (prevent accidental commits)
- Document secure alternatives (GPG encryption, password manager)

---

### Risk 3: Vault CLI Installation Failure
**Severity**: Medium  
**Impact**: Developers cannot use `vault` commands  
**Mitigation**:
- Docker build primary installation (99% success)
- Post-create fallback (catches edge cases)
- Non-fatal failure (warn and continue)
- HTTP API fallback in all scripts (no CLI dependency)
- Document manual installation steps

---

### Risk 4: Docker Compose Modification Errors
**Severity**: Medium  
**Impact**: Vault service fails to start after mode switch  
**Mitigation**:
- Validate YAML syntax before writing
- Create backup of `docker-compose.dev.yml` before modification
- Rollback on failure
- Test with yamllint in CI
- Use templating instead of sed/awk manipulation

---

### Risk 5: Storage Backend Compatibility
**Severity**: Low  
**Impact**: Raft storage issues on certain file systems (NFS, CIFS)  
**Mitigation**:
- Document supported file systems (ext4, APFS, NTFS)
- Detect file system and warn if incompatible
- Fallback to ephemeral mode if Raft initialization fails
- Add troubleshooting section in docs

---

## Timeline & Milestones

### Milestone 1: MVP - Basic Persistence (Week 1-2)
**Deadline**: End of Week 2  
**Deliverables**:
- ✅ Vault CLI installed
- ✅ Persistent storage working (Raft backend)
- ✅ Data survives container restarts
- ✅ Basic wizard mode selection

**Success Criteria**:
- Manual testing: Secrets persist across rebuild
- Unit tests pass (vault-persistence.test.ts)
- Validation detects persistent mode

---

### Milestone 2: User Choice & Automation (Week 3)
**Deadline**: End of Week 3  
**Deliverables**:
- ✅ Wizard prompts for mode selection
- ✅ Auto-unseal implementation
- ✅ Migration script (ephemeral ↔ persistent)
- ✅ CLI mode switcher

**Success Criteria**:
- Integration tests pass (wizard-persistence.test.ts)
- Mode switching tested in both directions
- Auto-unseal works on container start

---

### Milestone 3: Templates & Validation (Week 4)
**Deadline**: End of Week 4  
**Deliverables**:
- ✅ Vault data template created
- ✅ Seed secrets file
- ✅ Validation extended (mode detection, seal status)
- ✅ Template initialization tested

**Success Criteria**:
- Template setup completes successfully
- Validation reports correct mode and status
- All integration tests pass

---

### Milestone 4: Documentation & Release (Week 5)
**Deadline**: End of Week 5  
**Deliverables**:
- ✅ VAULT_SETUP.md updated
- ✅ VAULT_CLI.md created
- ✅ All tests passing (unit + integration + functional)
- ✅ Code quality checks pass (lint, format)
- ✅ User acceptance testing

**Success Criteria**:
- Documentation reviewed and approved
- 80%+ test coverage
- Zero critical bugs
- Ready for production use

---

## Acceptance Criteria (Overall)

### Functional Requirements
- ✅ Vault data persists across container rebuilds (persistent mode)
- ✅ Vault CLI available and functional
- ✅ Wizard prompts for mode selection (default: persistent)
- ✅ Auto-unseal optional (default: manual for security)
- ✅ Migration between modes works without data loss
- ✅ Template initialization sets up Vault with seed data
- ✅ Validation detects mode and reports seal status

### Non-Functional Requirements
- ✅ Installation failure non-fatal (warn and continue)
- ✅ Unseal keys stored with 600 permissions
- ✅ Backup created before destructive operations
- ✅ All data files added to `.gitignore` (except templates)
- ✅ 80%+ test coverage (unit + integration)
- ✅ Documentation comprehensive and accurate

### User Experience
- ✅ Wizard provides clear prompts and defaults
- ✅ Success/warning/error messages with emojis
- ✅ Non-interactive mode works for CI/CD
- ✅ CLI mode switcher simple to use
- ✅ Template setup reduces onboarding time

---

## Appendix

### A. File Changes Summary

**New Files**:
- `.devcontainer/config/vault-persistent.hcl`
- `.devcontainer/scripts/setup/install-vault-cli.sh`
- `.devcontainer/scripts/vault-auto-unseal.sh`
- `.devcontainer/scripts/vault-migrate-mode.sh`
- `.devcontainer/scripts/vault-mode` (CLI command)
- `.devcontainer/data/vault-mode.conf`
- `.devcontainer/data/vault-unseal-keys.json` (generated)
- `.devcontainer/data/vault-data.template/README.md`
- `.devcontainer/data/vault-data.template/seed-secrets.json`
- `.devcontainer/docs/VAULT_CLI.md`
- `test/unit/vault-persistence.test.ts`
- `test/unit/vault-cli.test.ts`
- `test/integration/vault-wizard-persistence.test.ts`

**Modified Files**:
- `.devcontainer/Dockerfile` (add Vault CLI installation)
- `.devcontainer/docker-compose.dev.yml` (conditional volumes/commands)
- `.devcontainer/scripts/post-create.sh` (Vault CLI fallback)
- `.devcontainer/scripts/post-start.sh` (auto-unseal integration)
- `.devcontainer/scripts/setup/vault-setup-wizard.sh` (mode selection, seal/unseal prompts)
- `.devcontainer/scripts/validate-vault-setup.sh` (mode detection, seal status)
- `.devcontainer/data/.gitignore` (vault-data, unseal keys)
- `docs/VAULT_SETUP.md` (new sections for persistence, seal/unseal, templates)

---

### B. Dependencies

**External**:
- HashiCorp Vault (latest image): `hashicorp/vault:latest`
- HashiCorp APT repository: `apt.releases.hashicorp.com`

**Internal**:
- Docker Compose: For multi-service orchestration
- Bash 4.0+: For scripts
- jq: JSON parsing in scripts
- curl: HTTP API calls

---

### C. Environment Variables

**New Variables**:
- `VAULT_MODE`: `persistent` | `ephemeral`
- `AUTO_UNSEAL`: `true` | `false`
- `VAULT_COMMAND`: Docker command for Vault service
- `VAULT_UNSEAL_KEYS_FILE`: Path to unseal keys JSON

**Existing (no changes)**:
- `VAULT_ADDR`: `http://vault-dev:8200`
- `VAULT_TOKEN`: Root token (varies by mode)
- `VAULT_DEV_ROOT_TOKEN_ID`: `root` (ephemeral mode only)

---

### D. References

- [Vault Raft Storage Backend](https://developer.hashicorp.com/vault/docs/configuration/storage/raft)
- [Vault Seal/Unseal Concepts](https://developer.hashicorp.com/vault/docs/concepts/seal)
- [Vault CLI Commands](https://developer.hashicorp.com/vault/docs/commands)
- [Docker Compose Volume Mounts](https://docs.docker.com/compose/compose-file/compose-file-v3/#volumes)

---

---

**Approval Signatures**:
- [ ] Product Owner: ______________________  Date: __________
- [ ] Tech Lead: __________________________  Date: __________
- [ ] DevOps: _____________________________  Date: __________
