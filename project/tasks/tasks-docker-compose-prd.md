## Relevant Files

- `.devcontainer/docker-compose.dev.yml` - Main docker-compose configuration with Vault integration replacing current build setup
- `.devcontainer/devcontainer.json` - DevContainer configuration updated to use docker-compose
- `.devcontainer/scripts/vault-init.sh` - Vault server initialization script
- `.devcontainer/scripts/vault-fetch-secrets.sh` - Script to retrieve secrets from Vault
- `.devcontainer/scripts/validate-vault-setup.sh` - Vault configuration validation script
- `scripts/setup/VaultSecretManager.ts` - TypeScript client for Vault operations
- `scripts/setup/migrate-secrets-to-vault.sh` - Script to migrate secrets from .env to Vault
- `scripts/setup/vault-setup-wizard.sh` - Interactive setup wizard for Vault configuration
- `.env.example` - Updated example environment file with Vault-only structure
- `docs/devs/VAULT_SETUP.md` - Comprehensive Vault setup documentation
- `docs/devs/VAULT_TROUBLESHOOTING.md` - Troubleshooting guide for Vault issues

### Notes

- Unit tests should be placed alongside the code files they are testing
- Use `npx jest [optional/path/to/test/file]` to run tests
- Vault-related scripts should have executable permissions (chmod +x)
- Environment variables should follow the priority: Vault > .env > defaults

## Tasks

- [x] 1.0 Docker-Compose Configuration Migration
  - [x] 1.1 Create `.devcontainer/docker-compose.dev.yml` with services (devcontainer, vault-dev, hardhat-node)
  - [x] 1.2 Configure WORKSPACE_NAME variable substitution from .env file in docker-compose
  - [x] 1.3 Define named volumes for caching (yarn-cache, node-modules, hardhat artifacts, etc.)
  - [x] 1.4 Set up networks for inter-service communication
  - [x] 1.5 Update `.devcontainer/devcontainer.json` to reference docker-compose instead of build
  - [x] 1.6 Update workspaceFolder to use `${localEnv:WORKSPACE_NAME:diamonds_project}`
  - [x] 1.7 Ensure environment variables propagate correctly from .env through docker-compose to container
- [x] 2.0 HashiCorp Vault Integration Setup
  - [x] 2.1 Add vault-dev service to docker-compose using hashicorp/vault:latest image
  - [x] 2.2 Configure Vault dev server with in-memory storage and exposed port 8200
  - [x] 2.3 Create `.devcontainer/scripts/vault-init.sh` for Vault initialization and GitHub auth setup
  - [x] 2.4 Create `.devcontainer/scripts/vault-fetch-secrets.sh` for secret retrieval and environment export
  - [x] 2.5 Implement `.devcontainer/scripts/setup/VaultSecretManager.ts` with connect, getSecret, setSecret, listSecrets methods
- [x] 2.6 Configure Vault secret paths structure (secret/dev/*, secret/test/*, secret/ci/*)
- [x] 2.7 Set up Vault policies for read/write access to secret paths
- [x] 3.0 Secret Management Implementation
  - [x] 3.1 Create `.devcontainer/scripts/setup/migrate-secrets-to-vault.sh` to move secrets from .env to Vault
  - [x] 3.2 Update `.devcontainer/.env.example` to contain only non-secret configuration with Vault instructions
  - [x] 3.3 Update `.gitignore` to exclude Vault tokens, secret files, and backup files
  - [x] 3.4 Implement secret backup mechanism (.env.vault-migrated) during migration
  - [x] 3.5 Remove secrets from .env file after successful Vault migration
  - [x] 3.6 Add validation to ensure no secrets remain in repository after migration
- [x] 4.0 DevContainer Lifecycle Integration
  - [x] 4.1 Update `.devcontainer/scripts/post-create.sh` to call vault-fetch-secrets.sh
  - [x] 4.2 Update `.devcontainer/scripts/post-start.sh` to include Vault health checks
  - [x] 4.3 Update `.devcontainer/scripts/test-env.sh` to validate Vault connectivity and secret access
  - [x] 4.4 Create `.devcontainer/scripts/validate-vault-setup.sh` for comprehensive Vault validation
  - [x] 4.5 Implement secret refresh mechanism in post-start.sh for updated secrets
  - [x] 4.6 Add error handling for Vault unavailability with fallback to .env
- [x] 5.0 Developer Experience and Validation
  - [ ] 5.1 Create `.devcontainer/scripts/setup/vault-setup-wizard.sh` for interactive Vault configuration
  - [x] 5.2 Create `.devcontainer/docs/devs/VAULT_SETUP.md` with step-by-step setup instructions
  - [x] 5.3 Create `.devcontainer/docs/devs/VAULT_TROUBLESHOOTING.md` with common issues and solutions
  - [ ] 5.4 Implement auto-detection of Vault configuration status on container start
  - [x] 5.5 Add environment variable priority system (Vault > .env > defaults)
  - [x] 5.6 Implement critical vs non-critical secret handling with appropriate error levels
  - [x] 5.7 Add comprehensive error messages with actionable guidance
  - [x] 5.8 Implement secret format validation (private keys, API keys, etc.)
  - [x] 5.9 Add warnings for expiring tokens and placeholder values