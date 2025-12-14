# HashiCorp Vault Setup Guide for Diamonds Project DevContainer

This guide provides comprehensive instructions for setting up and using HashiCorp Vault for secure secret management in the Diamonds Project development environment.

## Table of Contents

1. [Overview](#overview)
2. [Vault Persistence Modes](#vault-persistence-modes)
3. [Prerequisites](#prerequisites)
4. [Quick Start](#quick-start)
5. [Vault Architecture](#vault-architecture)
6. [Environment Configuration](#environment-configuration)
7. [Mode Switching](#mode-switching)
8. [Seal/Unseal Management](#sealunseal-management)
9. [Team Templates](#team-templates)
10. [Secret Management](#secret-management)
11. [DevContainer Integration](#devcontainer-integration)
12. [Backup and Restore](#backup-and-restore)
13. [Troubleshooting](#troubleshooting)
14. [Security Considerations](#security-considerations)

## Overview

The Diamonds Project project uses HashiCorp Vault for secure secret management in development and CI/CD environments. Vault provides:

- **Secure Storage**: Encrypted storage of sensitive data (API keys, private keys, tokens)
- **Access Control**: Role-based access control with GitHub authentication
- **Audit Logging**: Complete audit trail of secret access
- **Dynamic Secrets**: On-demand secret generation and rotation
- **Multi-Environment Support**: Separate secret paths for dev/staging/production

### Key Benefits

- **Enhanced Security**: Secrets never stored in code or plain text files
- **Compliance**: Audit trails and access controls for regulatory compliance
- **Developer Experience**: Seamless integration with existing development workflows
- **CI/CD Integration**: Automated secret injection in deployment pipelines

## Vault Persistence Modes

Vault supports two storage modes in the DevContainer environment:

### Ephemeral Mode (Development)

**Use Case**: Quick prototyping, CI/CD, temporary testing

**Characteristics**:
- Runs in development mode (`vault server -dev`)
- Secrets stored in memory only
- All data lost on container restart
- Auto-unsealed and always available
- Root token: `root` (for convenience)
- Fastest startup time

**Pros**:
- Zero configuration required
- Always available, no unsealing needed
- Fast and lightweight
- Perfect for CI/CD pipelines

**Cons**:
- Data does not persist across restarts
- Not suitable for long-term development
- Secrets must be re-entered after restart

### Persistent Mode (Production-like)

**Use Case**: Long-term development, team collaboration, realistic testing

**Characteristics**:
- Uses Raft storage backend
- Secrets persist across container restarts
- Data stored in `.devcontainer/data/vault-data/`
- Requires unsealing after restart (manual or automatic)
- Production-like behavior
- Team-shareable via templates

**Pros**:
- Data persists indefinitely
- Realistic production environment
- Team template support
- Can be backed up and restored

**Cons**:
- Requires unsealing after restart
- Slightly slower startup
- More disk space required

### Mode Comparison Table

| Feature | Ephemeral Mode | Persistent Mode |
|---------|---------------|----------------|
| **Storage** | In-memory | Raft (disk-based) |
| **Persistence** | ❌ Lost on restart | ✅ Persists across restarts |
| **Seal Status** | Always unsealed | Sealed on restart |
| **Startup Time** | ~2 seconds | ~5 seconds |
| **Disk Usage** | Negligible | ~10-50 MB |
| **Use Case** | CI/CD, quick tests | Development, team work |
| **Root Token** | `root` (fixed) | Generated on init |
| **Team Templates** | ❌ Not applicable | ✅ Supported |
| **Backup/Restore** | ❌ Not applicable | ✅ Supported |

### Storage Backend: Raft

Persistent mode uses the Raft consensus algorithm for storage:

```
.devcontainer/data/vault-data/
├── raft/
│   ├── raft.db          # Main database file
│   ├── snapshots/       # Snapshot backups
│   └── wal/             # Write-ahead log
├── unseal-keys.json     # Unseal keys (5 keys, threshold 3)
└── .vault-token         # Root token
```

**Raft Benefits**:
- High Availability (HA) support (multi-node)
- Built-in snapshots for backup
- Cloud-agnostic (no external dependencies)
- Production-ready and battle-tested

### Choosing a Mode

**Use Ephemeral Mode if you**:
- Are running in CI/CD pipelines
- Need quick throwaway environments
- Don't mind re-entering secrets after restart
- Want zero configuration

**Use Persistent Mode if you**:
- Are doing active development over multiple days
- Want secrets to survive container restarts
- Need to share configuration via team templates
- Want production-like behavior for testing

## Prerequisites

### System Requirements

- Docker and Docker Compose
- GitHub account with repository access
- Node.js 18+ (for development tooling)
- Bash shell environment

### Vault Access

- GitHub Personal Access Token with `repo` scope
- Access to Diamonds Project GitHub organization
- VPN access (if required for corporate networks)

## Quick Start

### 1. Environment Setup

```bash
# Clone the repository
git clone https://github.com/diamondslab/diamonds-base.git
cd diamonds-base

# Set up GitHub token for Vault authentication
export GITHUB_TOKEN=your_github_token_here

# Start the development environment
docker-compose up -d

# Open in VS Code DevContainer
code .
```

### 2. Verify Vault Integration

```bash
# Run environment validation
./.devcontainer/scripts/test-env.sh

# Check Vault status
./.devcontainer/scripts/validate-vault-setup.sh

# Fetch secrets manually
./.devcontainer/scripts/vault-fetch-secrets.sh
```

### 3. Development Workflow

Once set up, Vault integration works transparently:

- Secrets are automatically loaded on container startup
- Environment variables are available in your development session
- Secrets refresh every 5 minutes to pick up updates

## Vault Architecture

### Service Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   DevContainer  │────│     Vault       │────│   GitHub Auth   │
│                 │    │   (vault-dev)   │    │                 │
│ • post-create.sh│    │ • KV Secrets    │    │ • Token Auth    │
│ • post-start.sh │    │ • GitHub Auth   │    │ • User Mapping  │
│ • test-env.sh   │    │ • Policies      │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │   Secret Store  │
                    │                 │
                    │ • private keys  │
                    │ • API tokens    │
                    │ • RPC URLs      │
                    │ • credentials   │
                    └─────────────────┘
```

### Secret Path Structure

```
secret/dev/
├── PRIVATE_KEY              # Main deployment private key
├── TEST_PRIVATE_KEY         # Test network private key
├── RPC_URL                  # Mainnet RPC URL
├── INFURA_API_KEY           # Infura API key
├── ALCHEMY_API_KEY          # Alchemy API key
├── ETHERSCAN_API_KEY        # Etherscan API key
├── GITHUB_TOKEN             # GitHub API token
├── SNYK_TOKEN               # Snyk security token
└── SOCKET_CLI_API_TOKEN     # Socket CLI token
```

### Authentication Flow

1. **GitHub Token**: Developer provides GitHub Personal Access Token
2. **Vault Login**: Token exchanged for Vault authentication
3. **Policy Application**: User-specific policies applied
4. **Secret Access**: Encrypted secrets retrieved via KV engine
5. **Environment Injection**: Secrets exported as environment variables

## Environment Configuration

### Required Environment Variables

```bash
# Vault Configuration
VAULT_ADDR=http://vault-dev:8200          # Vault server address
GITHUB_TOKEN=ghp_...                      # GitHub Personal Access Token

# Optional Configuration
FALLBACK_TO_ENV=true                      # Enable .env fallback
ENV_FILE=../../.env                       # Path to fallback .env file
```

### Docker Compose Configuration

The `docker-compose.yml` includes:

```yaml
services:
  vault-dev:
    image: hashicorp/vault:latest
    environment:
      - VAULT_DEV_ROOT_TOKEN_ID=dev-token
      - VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200
    ports:
      - "8200:8200"
    volumes:
      - vault-data:/vault/data
    cap_add:
      - IPC_LOCK
```

### DevContainer Configuration

The `.devcontainer/devcontainer.json` includes:

```json
{
  "postCreateCommand": "./.devcontainer/scripts/post-create.sh",
  "postStartCommand": "./.devcontainer/scripts/post-start.sh",
  "remoteEnv": {
    "VAULT_ADDR": "http://vault-dev:8200"
  }
}
```

## Mode Switching

You can switch between ephemeral and persistent modes using the `vault-mode` CLI utility.

### Using vault-mode CLI

```bash
# Check current mode
vault-mode status

# Switch to persistent mode
vault-mode switch persistent

# Switch to ephemeral mode
vault-mode switch ephemeral
```

### What Happens During Mode Switch

The mode switching process includes automatic secret migration to preserve your data:

1. **Backup Creation**: Current secrets are backed up to `.devcontainer/data/vault-data-backups/`
2. **Mode Configuration**: `vault-mode.conf` is updated with the new mode
3. **Container Restart**: Vault container restarts with the new configuration
4. **Secret Migration**: Secrets are restored from backup to the new storage backend
5. **Verification**: Migration script verifies all secrets were transferred successfully

**Important Notes**:
- Migration preserves all secrets and their values
- Up to 5 backups are retained automatically
- You can switch modes multiple times without data loss
- Migration requires Vault to be unsealed (in persistent mode)

### Migration Example

```bash
# Start in persistent mode with some secrets
vault-mode status
# Output: Current mode: persistent

vault kv put secret/dev/API_KEY value="my-api-key"
vault kv put secret/dev/DATABASE_URL value="postgresql://..."

# Switch to ephemeral mode
vault-mode switch ephemeral
# Prompts:
#   1. Migrate secrets to ephemeral mode (recommended)
#   2. Switch without migration (data will be lost)
# Select option: 1

# Verify secrets migrated
vault kv get secret/dev/API_KEY
# Output: value=my-api-key

# Switch back to persistent
vault-mode switch persistent
# Secrets migrate back automatically
```

### Migration Script

If you prefer manual migration, use the migration script directly:

```bash
# Migrate from ephemeral to persistent
bash .devcontainer/scripts/vault-migrate-mode.sh ephemeral persistent

# Migrate from persistent to ephemeral
bash .devcontainer/scripts/vault-migrate-mode.sh persistent ephemeral
```

### Troubleshooting Mode Switching

**Issue**: Migration fails with "Vault is sealed"

**Solution**: Unseal Vault before attempting migration
```bash
bash .devcontainer/scripts/vault-auto-unseal.sh
# Or manually: vault operator unseal <key1> <key2> <key3>
```

**Issue**: Secrets missing after switch

**Solution**: Check backup directory and restore manually
```bash
# List backups
ls -la .devcontainer/data/vault-data-backups/

# Restore from backup
bash .devcontainer/scripts/vault-migrate-mode.sh restore backup-20241022-120000
```

## Seal/Unseal Management

In persistent mode, Vault starts in a "sealed" state for security. You must unseal it before accessing secrets.

### Understanding Seal Status

**Sealed Vault**:
- Cannot serve read/write requests
- All data is encrypted and inaccessible
- Encryption keys are not in memory
- Restart always seals Vault

**Unsealed Vault**:
- Can serve requests normally
- Encryption keys loaded in memory
- Secrets are accessible
- Remains unsealed until explicitly sealed or restarted

### Seal Status State Machine

```
┌─────────────────┐
│   Container     │
│   Restart       │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│     SEALED      │◄────────┐
│                 │         │
│ • Data locked   │         │
│ • No requests   │         │
│ • Keys needed   │         │
└────────┬────────┘         │
         │                  │
         │ Unseal Keys      │ vault operator seal
         │ (3 of 5)         │
         ▼                  │
┌─────────────────┐         │
│    UNSEALED     │─────────┘
│                 │
│ • Data accessible│
│ • Serves requests│
│ • Keys in memory │
└─────────────────┘
```

### Manual Unseal Procedure

When Vault is sealed, you need 3 out of 5 unseal keys to unlock it:

```bash
# Check seal status
vault status
# Output: Sealed: true

# Get unseal keys from file
cat .devcontainer/data/vault-data/unseal-keys.json

# Unseal with 3 keys (one at a time)
vault operator unseal <unseal-key-1>
# Progress: 1/3

vault operator unseal <unseal-key-2>
# Progress: 2/3

vault operator unseal <unseal-key-3>
# Vault is now unsealed!

# Verify
vault status
# Output: Sealed: false
```

### Auto-Unseal Configuration

For convenience, you can enable auto-unseal to automatically unlock Vault on container start.

#### Enabling Auto-Unseal

**Option 1: During Wizard Setup**
```bash
bash .devcontainer/scripts/setup/vault-setup-wizard.sh
# When prompted:
# "Enable auto-unseal? (y/N)" → Select 'y'
```

**Option 2: Manual Configuration**
```bash
# Edit vault-mode.conf
vim .devcontainer/data/vault-mode.conf

# Set AUTO_UNSEAL=true
AUTO_UNSEAL=true

# Restart container for changes to take effect
docker-compose restart vault-dev
```

#### How Auto-Unseal Works

On container start, the `post-start.sh` script:
1. Checks if `AUTO_UNSEAL=true` in configuration
2. Verifies Vault is sealed
3. Reads unseal keys from `unseal-keys.json`
4. Automatically unseals using first 3 keys
5. Logs unseal progress

**Security Warning**: Auto-unseal stores unseal keys in plaintext on disk (with 600 permissions). This is convenient for development but should **never** be used in production environments.

### Unsealing After Restart

```bash
# Container restarted, Vault is sealed
vault status
# Sealed: true

# If AUTO_UNSEAL=true, it happens automatically
# Check logs:
docker-compose logs vault-dev | grep -i unseal

# If AUTO_UNSEAL=false, unseal manually
bash .devcontainer/scripts/vault-auto-unseal.sh
# Or use vault operator unseal (3 times)
```

### Sealing Vault Manually

You can manually seal Vault for security:

```bash
# Seal Vault (requires authentication)
vault operator seal

# Vault is now sealed
vault status
# Sealed: true

# All requests will fail until unsealed
vault kv get secret/dev/API_KEY
# Error: Vault is sealed
```

**Use Cases for Manual Sealing**:
- Before system maintenance
- When leaving workstation unattended
- Before creating backups
- For security audits

### Key Storage and Security

**Unseal Keys Location**: `.devcontainer/data/vault-data/unseal-keys.json`

**File Permissions**: `600` (owner read/write only)

**Important Security Notes**:
- ⚠️ **Never commit unseal keys to Git** (directory is gitignored)
- Store keys in a secure password manager for production
- Consider using Vault Auto-Unseal with cloud KMS in production
- In persistent mode, share keys securely with team members
- Rotate keys periodically using `vault operator rekey`

### Rekeying Vault

To change unseal keys (security rotation):

```bash
# Initialize rekey operation
vault operator rekey -init

# Provide current keys when prompted
vault operator rekey <old-key-1>
vault operator rekey <old-key-2>
vault operator rekey <old-key-3>

# New keys are generated
# Save new keys to unseal-keys.json
```

## Team Templates

Team templates allow you to share pre-configured Vault setups with placeholder secrets for easy onboarding.

### What is a Team Template?

A team template is a pre-configured vault-data directory with:
- Placeholder secrets (safe values to commit to Git)
- Seed secrets file (JSON with common development secrets)
- Documentation (README explaining customization)

**Benefits**:
- New team members can initialize Vault in minutes
- Consistent secret structure across the team
- Easy to share via Git (no real secrets committed)
- Reduces onboarding friction

### Template Structure

```
.devcontainer/data/vault-data.template/
├── README.md             # Setup and customization instructions
└── seed-secrets.json     # Placeholder secrets
```

### Using a Team Template

If a template exists, the wizard will prompt you to use it:

```bash
# Run setup wizard
bash .devcontainer/scripts/setup/vault-setup-wizard.sh

# Wizard detects template
# "Vault team template detected!"
# "Initialize from template? (Y/n)" → Select 'Y'

# Template is initialized automatically
# All placeholder secrets are loaded

# Customize secrets for your environment
vault kv put secret/dev/DEFENDER_API_KEY value="YOUR_ACTUAL_KEY"
vault kv put secret/dev/ETHERSCAN_API_KEY value="YOUR_ACTUAL_KEY"
```

### Manual Template Initialization

You can also initialize from a template manually:

```bash
# Initialize Vault from template
bash .devcontainer/scripts/vault-init-from-template.sh

# Script will:
# 1. Validate template exists
# 2. Check Vault connectivity
# 3. Load all seed secrets
# 4. Provide instructions for customization
```

### Creating a Team Template

To create a template for your team:

1. **Set up Vault with desired configuration**:
   ```bash
   bash .devcontainer/scripts/setup/vault-setup-wizard.sh
   # Select persistent mode
   ```

2. **Add placeholder secrets**:
   ```bash
   vault kv put secret/dev/DEFENDER_API_KEY value="REPLACE_WITH_YOUR_KEY"
   vault kv put secret/dev/ETHERSCAN_API_KEY value="REPLACE_WITH_YOUR_KEY"
   vault kv put secret/test/TEST_PRIVATE_KEY value="0x0000000000000000000000000000000000000000000000000000000000000000"
   # Add all required secrets with safe placeholder values
   ```

3. **Export secrets to seed file**:
   ```bash
   # Create seed-secrets.json manually or use helper script
   cat > .devcontainer/data/vault-data.template/seed-secrets.json <<EOF
   {
     "secret/dev/DEFENDER_API_KEY": {
       "value": "REPLACE_WITH_YOUR_KEY",
       "description": "OpenZeppelin Defender API key",
       "obtain_from": "https://defender.openzeppelin.com/v2/#/manage/api-keys"
     },
     "secret/dev/ETHERSCAN_API_KEY": {
       "value": "REPLACE_WITH_YOUR_KEY",
       "description": "Etherscan API key for contract verification",
       "obtain_from": "https://etherscan.io/myapikey"
     }
   }
   EOF
   ```

4. **Create documentation**:
   ```bash
   # Add README.md with instructions
   # (A template README exists in vault-data.template/)
   ```

5. **Commit template to Git**:
   ```bash
   git add .devcontainer/data/vault-data.template/
   git commit -m "feat: add Vault team template"
   git push
   ```

### Template Best Practices

1. **Use Safe Placeholder Values**: Never include real secrets
2. **Document Each Secret**: Add descriptions and source URLs
3. **Include Metadata**: Note required scopes, permissions, etc.
4. **Keep It Updated**: Refresh template when adding new services
5. **Version Control**: Commit templates to Git (they're safe!)
6. **Test Templates**: Initialize on a clean environment to verify

### Example seed-secrets.json

```json
{
  "_comment": "Team template for Diamonds project. Replace all REPLACE_WITH values with actual keys.",
  
  "secret/dev/DEFENDER_API_KEY": {
    "value": "REPLACE_WITH_YOUR_DEFENDER_API_KEY",
    "description": "OpenZeppelin Defender API key for deployment management",
    "obtain_from": "https://defender.openzeppelin.com/v2/#/manage/api-keys",
    "required_scopes": ["manage:deployments", "manage:contracts"]
  },
  
  "secret/dev/ETHERSCAN_API_KEY": {
    "value": "REPLACE_WITH_YOUR_ETHERSCAN_API_KEY",
    "description": "Etherscan API key for contract verification",
    "obtain_from": "https://etherscan.io/myapikey"
  },
  
  "secret/test/TEST_PRIVATE_KEY": {
    "value": "0x0000000000000000000000000000000000000000000000000000000000000000",
    "description": "Test private key for local development (DO NOT use for real funds)",
    "security_note": "This is a well-known test key. Never use for mainnet!"
  }
}
```

## Secret Management

### Adding New Secrets

1. **Authenticate with Vault**:
   ```bash
   vault login -method=github token=$GITHUB_TOKEN
   ```

2. **Add a secret**:
   ```bash
   vault kv put secret/dev/NEW_SECRET_KEY value="your-secret-value"
   ```

3. **Verify the secret**:
   ```bash
   vault kv get secret/dev/NEW_SECRET_KEY
   ```

### Updating Secrets

```bash
# Update existing secret
vault kv put secret/dev/EXISTING_KEY value="new-value"

# Secrets automatically refresh in DevContainer (every 5 minutes)
# Or force refresh immediately
./.devcontainer/scripts/vault-fetch-secrets.sh --quiet
```

### Secret Rotation

For enhanced security, rotate secrets regularly:

```bash
# Generate new API key from provider
# Update in Vault
vault kv put secret/dev/API_KEY value="new-key"

# Update any external references
# Verify applications still work
./.devcontainer/scripts/test-env.sh
```

## DevContainer Integration

### Lifecycle Hooks

#### post-create.sh
- Runs once when DevContainer is created
- Installs dependencies and sets up development environment
- Calls vault-fetch-secrets.sh to load initial secrets

#### post-start.sh
- Runs every time DevContainer starts
- Performs health checks (including Vault connectivity)
- Refreshes secrets if needed (every 5 minutes)

#### test-env.sh
- Validates environment configuration
- Tests Vault connectivity and authentication
- Verifies secret accessibility

### Automatic Fallback

When Vault is unavailable, the system gracefully falls back to `.env` file:

1. **Vault Unavailable**: Connection check fails
2. **Fallback Triggered**: Scripts load from `.env` file
3. **Warning Displayed**: User notified of fallback mode
4. **Continued Operation**: Development workflow uninterrupted

### Error Handling

The integration includes comprehensive error handling:

- **Network Issues**: Automatic retry with exponential backoff
- **Authentication Failures**: Clear error messages with resolution steps
- **Missing Secrets**: Graceful degradation with available secrets
- **Permission Issues**: Detailed logging for troubleshooting

## Backup and Restore

Vault data backup is crucial for persistent mode to prevent data loss.

### Automatic Backups During Migration

When switching modes, Vault automatically creates backups:

```bash
# Backups are stored here
ls -la .devcontainer/data/vault-data-backups/

# Example backup structure
vault-data-backups/
├── backup-20241022-120000/    # Timestamp: YYYYMMDD-HHMMSS
│   ├── raft/
│   ├── unseal-keys.json
│   └── .vault-token
├── backup-20241021-153000/
└── backup-20241020-094500/
```

**Retention Policy**: The 5 most recent backups are kept automatically. Older backups are deleted to save disk space.

### Manual Backup Procedure

Create a manual backup of your Vault data:

```bash
# Create timestamped backup
BACKUP_DIR=".devcontainer/data/vault-data-backup-$(date +%Y%m%d-%H%M%S)"
cp -r .devcontainer/data/vault-data "$BACKUP_DIR"

echo "Backup created: $BACKUP_DIR"

# Verify backup
ls -la "$BACKUP_DIR"
```

**Recommended Backup Schedule**:
- Before major configuration changes
- Before switching Vault modes
- Before DevContainer rebuilds
- Weekly for active development

### Restoring from Backup

To restore Vault data from a backup:

```bash
# Stop Vault
docker-compose stop vault-dev

# Backup current data (just in case)
cp -r .devcontainer/data/vault-data .devcontainer/data/vault-data-before-restore

# Restore from backup
BACKUP_TO_RESTORE=".devcontainer/data/vault-data-backups/backup-20241022-120000"
rm -rf .devcontainer/data/vault-data
cp -r "$BACKUP_TO_RESTORE" .devcontainer/data/vault-data

# Restart Vault
docker-compose start vault-dev

# Unseal if in persistent mode
bash .devcontainer/scripts/vault-auto-unseal.sh

# Verify secrets
vault kv list secret/dev
```

### Backing Up Specific Secrets

Export specific secrets to a file for safekeeping:

```bash
# Export single secret
vault kv get -format=json secret/dev/API_KEY > api-key-backup.json

# Export all secrets in a path
vault kv list -format=json secret/dev | jq -r '.[]' | while read key; do
  vault kv get -format=json "secret/dev/$key" > "backup-dev-${key}.json"
done

# Create encrypted archive
tar -czf vault-secrets-backup.tar.gz backup-*.json
# Optional: encrypt with gpg
gpg --symmetric --cipher-algo AES256 vault-secrets-backup.tar.gz
rm vault-secrets-backup.tar.gz
```

### Restoring Specific Secrets

Restore secrets from JSON backup:

```bash
# Restore single secret
cat api-key-backup.json | jq -r '.data.data | to_entries[] | "vault kv put secret/dev/API_KEY \(.key)=\"\(.value)\""' | bash

# Restore from backup files
for backup in backup-dev-*.json; do
  path=$(echo $backup | sed 's/backup-dev-//; s/.json//');
  cat "$backup" | jq -r '.data.data | to_entries[] | "vault kv put secret/dev/'"$path"' \(.key)=\"\(.value)\""' | bash
done
```

### Disaster Recovery

If Vault data becomes corrupted:

1. **Check available backups**:
   ```bash
   ls -lat .devcontainer/data/vault-data-backups/
   ```

2. **Stop Vault**:
   ```bash
   docker-compose stop vault-dev
   ```

3. **Move corrupted data**:
   ```bash
   mv .devcontainer/data/vault-data .devcontainer/data/vault-data-corrupted
   ```

4. **Restore latest backup**:
   ```bash
   cp -r .devcontainer/data/vault-data-backups/backup-LATEST .devcontainer/data/vault-data
   ```

5. **Restart and verify**:
   ```bash
   docker-compose start vault-dev
   bash .devcontainer/scripts/vault-auto-unseal.sh
   vault kv list secret/dev
   ```

### Backup Best Practices

1. **Regular Backups**: Create manual backups before risky operations
2. **Version Control**: Commit template secrets (not real secrets!) to Git
3. **Encrypted Storage**: Use GPG or similar for backup encryption
4. **Off-Site Backups**: Store critical backups outside the DevContainer
5. **Test Restores**: Periodically verify backups can be restored
6. **Document Secrets**: Keep a list of which secrets exist (not values)

### What to Backup

**Must Backup**:
- ✅ `.devcontainer/data/vault-data/` (entire directory)
- ✅ `unseal-keys.json` (critical for unsealing)
- ✅ `.vault-token` (root token)

**Optional**:
- Configuration files (`vault-mode.conf`)
- Template files (already in Git)
- Backup archives (historical backups)

**Never Backup to Git**:
- ❌ Real Vault data directory
- ❌ Actual unseal keys
- ❌ Real secret values
- ❌ Root tokens

## Troubleshooting

### Common Issues

#### Vault Sealed After Restart

**Symptoms**: 
- `Error: Vault is sealed` when accessing secrets
- Container restarts successfully but secrets inaccessible
- `vault status` shows `Sealed: true`

**Cause**: This is expected behavior in persistent mode. Vault seals automatically on restart for security.

**Solutions**:

**Option 1: Auto-Unseal (Recommended for Development)**
```bash
# Enable auto-unseal in configuration
echo 'AUTO_UNSEAL=true' >> .devcontainer/data/vault-mode.conf

# Restart container
docker-compose restart vault-dev

# Vault will auto-unseal on startup
```

**Option 2: Manual Unseal**
```bash
# Use auto-unseal script
bash .devcontainer/scripts/vault-auto-unseal.sh

# Or unseal manually with 3 keys
vault operator unseal $(jq -r '.unseal_keys_b64[0]' .devcontainer/data/vault-data/unseal-keys.json)
vault operator unseal $(jq -r '.unseal_keys_b64[1]' .devcontainer/data/vault-data/unseal-keys.json)
vault operator unseal $(jq -r '.unseal_keys_b64[2]' .devcontainer/data/vault-data/unseal-keys.json)

# Verify unsealed
vault status
```

#### Vault CLI Not Found in PATH

**Symptoms**: `vault: command not found`

**Cause**: Vault CLI not installed or not in PATH

**Solutions**:
```bash
# Check if vault is installed
which vault
dpkg -l | grep vault

# Reinstall using installation script
bash .devcontainer/scripts/install-vault-cli.sh

# Verify installation
vault version

# If installed but not in PATH, add to profile
echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

#### Vault Not Accessible

**Symptoms**: `Vault is not available` warnings

**Solutions**:
```bash
# Check if Vault container is running
docker-compose ps vault-dev

# Restart Vault service
docker-compose restart vault-dev

# Check Vault logs
docker-compose logs vault-dev

# Verify network connectivity
curl http://vault-dev:8200/v1/sys/health
```

#### Raft Database Corruption

**Symptoms**:
- Vault fails to start
- Logs show "raft: failed to open backend"
- Container repeatedly restarting

**Cause**: Raft database corruption due to unclean shutdown, disk issues, or bugs

**Solutions**:

**Option 1: Restore from Backup**
```bash
# Stop Vault
docker-compose stop vault-dev

# Move corrupted data
mv .devcontainer/data/vault-data .devcontainer/data/vault-data-corrupted

# Restore from latest backup
cp -r .devcontainer/data/vault-data-backups/backup-LATEST .devcontainer/data/vault-data

# Restart Vault
docker-compose start vault-dev
bash .devcontainer/scripts/vault-auto-unseal.sh
```

**Option 2: Fresh Start (Data Loss)**
```bash
# WARNING: This will delete all secrets!
docker-compose stop vault-dev
rm -rf .devcontainer/data/vault-data
docker-compose start vault-dev

# Re-run setup wizard
bash .devcontainer/scripts/setup/vault-setup-wizard.sh
```

**Option 3: Raft Recovery**
```bash
# Try Raft recovery (advanced)
vault operator raft snapshot restore backup.snap
```

#### Migration Failures

**Symptoms**:
- "Migration failed" error during mode switch
- Some secrets missing after migration
- Migration script hangs or times out

**Solutions**:

**Check Vault Status**:
```bash
# Ensure Vault is unsealed
vault status

# If sealed, unseal first
bash .devcontainer/scripts/vault-auto-unseal.sh
```

**Retry Migration with Logging**:
```bash
# Enable debug logging
export DEBUG=1

# Run migration manually
bash .devcontainer/scripts/vault-migrate-mode.sh ephemeral persistent

# Check logs in logs/migration.log
```

**Restore from Backup**:
```bash
# If migration corrupted data, restore
ls -la .devcontainer/data/vault-data-backups/

# Restore pre-migration backup
BACKUP=".devcontainer/data/vault-data-backups/backup-BEFORE-MIGRATION"
docker-compose stop vault-dev
rm -rf .devcontainer/data/vault-data
cp -r "$BACKUP" .devcontainer/data/vault-data
docker-compose start vault-dev
```

#### unseal-keys.json File Permissions

**Symptoms**:
- Warning: "Insecure unseal keys file permissions"
- Auto-unseal fails with permission denied

**Cause**: Incorrect file permissions on unseal-keys.json (should be 600)

**Solution**:
```bash
# Fix permissions
chmod 600 .devcontainer/data/vault-data/unseal-keys.json

# Verify
ls -la .devcontainer/data/vault-data/unseal-keys.json
# Should show: -rw------- (600)
```

#### Authentication Failed

**Symptoms**: `Vault authentication failed` errors

**Solutions**:
```bash
# Verify GitHub token
echo $GITHUB_TOKEN | head -c 10  # Should start with ghp_

# Check token permissions (needs repo scope)
curl -H "Authorization: token $GITHUB_TOKEN" \
     https://api.github.com/user

# Try manual authentication
vault login -method=github token=$GITHUB_TOKEN
```

#### Secrets Not Loading

**Symptoms**: Environment variables not set

**Solutions**:
```bash
# Check Vault status
vault status

# Verify secret exists
vault kv list secret/dev

# Check authentication
vault token lookup

# Force secret refresh
./.devcontainer/scripts/vault-fetch-secrets.sh
```

### Debug Mode

Enable verbose logging for troubleshooting:

```bash
# Run with debug output
export DEBUG=true
./.devcontainer/scripts/validate-vault-setup.sh

# Check detailed logs
tail -f logs/vault-debug.log
```

### Recovery Procedures

#### Complete Vault Reset

```bash
# Stop all services
docker-compose down

# Remove Vault data
docker volume rm <PROJECT_NAME>_vault-data

# Restart environment
docker-compose up -d

# Reinitialize Vault
./scripts/setup/init-vault.sh
```

#### Emergency .env Fallback

If Vault is completely unavailable:

```bash
# Disable Vault integration
export FALLBACK_TO_ENV=true

# Ensure .env file exists with required secrets
ls -la .env

# Run setup without Vault
./.devcontainer/scripts/post-create.sh --no-vault
```

## Security Considerations

### Access Control

- **GitHub Authentication**: Only authorized repository members can access secrets
- **Path-Based Policies**: Users only see secrets they need
- **Token Expiration**: GitHub tokens expire, requiring re-authentication
- **Audit Logging**: All secret access is logged and auditable

### Best Practices

#### Developer Guidelines

1. **Never Commit Secrets**: Use Vault for all sensitive data
2. **Rotate Regularly**: Change secrets every 30-90 days
3. **Principle of Least Privilege**: Only access required secrets
4. **Monitor Access**: Review audit logs regularly

#### Operational Security

1. **Network Security**: Use VPN for corporate environments
2. **Token Management**: Store GitHub tokens securely
3. **Backup Strategy**: Regular Vault data backups
4. **Incident Response**: Defined procedures for security incidents

### Compliance

The Vault integration supports:

- **SOC 2**: Audit trails and access controls
- **GDPR**: Data encryption and access logging
- **Industry Standards**: Secure secret management practices

## Advanced Configuration

### Custom Vault Policies

Create organization-specific policies:

```hcl
# policy.hcl
path "secret/dev/*" {
  capabilities = ["read", "list"]
}

path "secret/dev/PRIVATE_KEY" {
  capabilities = ["deny"]
}
```

### Multi-Environment Setup

Configure different Vault instances for each environment:

```bash
# Development
export VAULT_ADDR=http://vault-dev:8200

# Staging
export VAULT_ADDR=https://vault-staging.company.com

# Production
export VAULT_ADDR=https://vault.company.com
```

### CI/CD Integration

Integrate with GitHub Actions:

```yaml
# .github/workflows/deploy.yml
- name: Authenticate to Vault
  run: |
    vault login -method=github token=${{ secrets.GITHUB_TOKEN }}

- name: Fetch Secrets
  run: |
    ./scripts/vault-fetch-secrets.sh --quiet
```

## Support

### Getting Help

1. **Documentation**: Check this guide and related docs
2. **Team Chat**: Ask in #devops or #security channels
3. **Issue Tracking**: Create GitHub issue with `vault` label
4. **Security Issues**: Contact security team directly

### Resources

- [HashiCorp Vault Documentation](https://www.vaultproject.io/docs)
- [Diamonds Project Security Guidelines](../../SECURITY.md)
- [DevContainer Troubleshooting](VAULT_TROUBLESHOOTING.md)
- [CI/CD Pipeline Documentation](../../docs/CI-PIPELINE.md)

---

**Last Updated**: October 2025
**Version**: 1.0
**Maintainer**: Diamonds DevOps Team</content>