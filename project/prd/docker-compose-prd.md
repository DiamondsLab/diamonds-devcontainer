# PRD: DevContainer Docker-Compose and HashiCorp Vault Integration

## Introduction/Overview

The current DevContainer setup has a critical flaw where the `WORKSPACE_NAME` environment variable always defaults to `diamonds_project` despite being defined in the `.env` file. This causes issues with workspace paths, mounts, and configuration throughout the development environment. Additionally, the project currently stores secrets in `.env` files, which poses security risks.

This feature will migrate the DevContainer from a direct Dockerfile build to a docker-compose based setup that properly loads environment variables from `.env` files, and integrate HashiCorp Vault for secure secret management. The solution must ensure `WORKSPACE_NAME` and all environment variables are correctly propagated throughout the DevContainer lifecycle while eliminating hardcoded secrets from the repository.

## Goals

1. **Fix WORKSPACE_NAME Loading**: Ensure `WORKSPACE_NAME` from `.env` is correctly used in all DevContainer contexts (build args, mounts, workspace folder, container environment)
2. **Migrate to Docker-Compose**: Replace the current `build` section in `devcontainer.json` with a docker-compose based configuration
3. **Integrate HashiCorp Vault**: Implement local Vault dev server for secure secret storage and retrieval
4. **Eliminate Hardcoded Secrets**: Remove all secrets from `.env` files and repository, storing them in Vault instead
5. **Maintain Developer Experience**: Ensure setup time remains under 10 minutes for new developers

## User Stories

### As a Developer
- I want `WORKSPACE_NAME` to be read from my `.env` file so that my workspace paths and configuration are personalized
- I want secrets to be securely managed through Vault so that I don't accidentally commit sensitive information
- I want the DevContainer to start successfully with all required secrets so that I can begin development immediately
- I want clear error messages when configuration is missing so that I can quickly resolve setup issues

### As a Team Lead
- I want all developers using Vault for secrets so that we have consistent security practices across the team
- I want the setup process to be straightforward so that new team members can onboard quickly
- I want secrets to never be stored in the repository so that we maintain security compliance

### As a DevOps Engineer
- I want the docker-compose configuration to properly handle environment variables so that the DevContainer works consistently
- I want Vault integration to be reliable so that developers don't experience secret access issues
- I want comprehensive validation scripts so that configuration problems are caught early

## Functional Requirements

### 1. Docker-Compose Configuration

**FR-1.1**: Create `.devcontainer/docker-compose.dev.yml` that replaces the current build configuration
- Must support `WORKSPACE_NAME` from `.env` file via docker-compose variable substitution
- Must include all services: devcontainer, hardhat-node, and vault-dev
- Must define named volumes for caching (yarn-cache, node-modules, etc.)
- Must configure networks for inter-service communication

**FR-1.2**: Update `.devcontainer/devcontainer.json` to reference docker-compose
- Replace `build` section with `dockerComposeFile: ["docker-compose.dev.yml"]`
- Set `service: "devcontainer"` to specify which service is the dev container
- Update `workspaceFolder` to use `${localEnv:WORKSPACE_NAME:diamonds_project}`
- Remove duplicate mount configurations (handled by docker-compose)

**FR-1.3**: Ensure environment variable propagation
- Docker-compose must read `.env` file from project root
- `WORKSPACE_NAME` must be available as docker-compose variable
- Build args must receive `WORKSPACE_NAME` from environment
- Container environment must include all required variables

### 2. HashiCorp Vault Integration

**FR-2.1**: Add Vault dev server to docker-compose
- Use official `hashicorp/vault:latest` image
- Configure in development mode with in-memory storage
- Expose port 8200 for API access
- Mount configuration for GitHub auth setup

**FR-2.2**: Implement Vault initialization script (`.devcontainer/scripts/vault-init.sh`)
- Start Vault in dev mode
- Enable GitHub auth method
- Create secret paths for different environments (dev, test, ci)
- Store initial root token securely
- Set up policies for read/write access

**FR-2.3**: Implement Vault secret fetcher (bash: `.devcontainer/scripts/vault-fetch-secrets.sh`)
- Authenticate to Vault using GitHub token
- Fetch secrets from designated paths
- Export secrets as environment variables
- Handle fallback to `.env` if Vault unavailable
- Log warnings for missing secrets

**FR-2.4**: Implement Vault secret manager (TypeScript: `scripts/setup/VaultSecretManager.ts`)
- Provide OOP interface for Vault operations
- Methods: `connect()`, `getSecret()`, `setSecret()`, `listSecrets()`
- Support batch secret retrieval
- Handle authentication refresh
- Provide detailed error messages

**FR-2.5**: Configure secret storage structure in Vault
```
secret/
├── dev/
│   ├── TEST_PRIVATE_KEY
│   ├── PRIVATE_KEY
│   ├── RPC_URL
│   ├── INFURA_API_KEY
│   ├── ALCHEMY_API_KEY
│   ├── ETHERSCAN_API_KEY
│   ├── GITHUB_TOKEN
│   ├── SNYK_TOKEN
│   └── SOCKET_CLI_API_TOKEN
├── test/
│   └── [same structure]
└── ci/
    └── [same structure]
```

### 3. Secret Migration and Management

**FR-3.1**: Create secret migration script (`scripts/setup/migrate-secrets-to-vault.sh`)
- Read secrets from current `.env` file
- Authenticate to Vault
- Store each secret in appropriate Vault path
- Confirm successful storage
- Create `.env.vault-migrated` backup
- Remove secrets from `.env` (keep non-secret config)

**FR-3.2**: Update `.env.example` to reflect new structure
- Include only non-secret configuration variables
- Add placeholder comments for Vault-managed secrets
- Include instructions for Vault setup

**FR-3.3**: Update `.gitignore` to prevent secret leakage
- Ensure `.env` is ignored
- Ensure `.env.local`, `.env.*.local` are ignored
- Add `.vault-token` to gitignore
- Add backup files to gitignore

### 4. DevContainer Lifecycle Integration

**FR-4.1**: Update `post-create.sh` script
- Call `vault-fetch-secrets.sh` to retrieve secrets
- Set environment variables from Vault
- Validate required secrets are present
- Continue with existing dependency installation

**FR-4.2**: Update `post-start.sh` script
- Check Vault connection health
- Refresh secrets if needed
- Validate secret access
- Continue with existing startup checks

**FR-4.3**: Update `test-env.sh` script
- Add Vault connection test
- Verify secret retrieval works
- Validate all required secrets are accessible
- Display secret source (Vault vs fallback)

**FR-4.4**: Create `validate-vault-setup.sh` script
- Test Vault server connectivity
- Verify GitHub authentication works
- Check secret paths exist
- Validate secret values are not empty
- Report configuration status

### 5. Developer Setup Experience

**FR-5.1**: Create setup wizard (`scripts/setup/vault-setup-wizard.sh`)
- Interactive prompts for Vault configuration
- GitHub token validation
- Automatic secret migration from `.env`
- Vault policy creation
- Test secret retrieval
- Generate setup report

**FR-5.2**: Provide manual setup documentation
- Step-by-step Vault setup instructions
- GitHub auth configuration guide
- Secret migration process
- Troubleshooting common issues

**FR-5.3**: Auto-detection and prompting
- Detect if Vault is configured on container start
- Prompt user to run setup wizard if not configured
- Provide clear next steps for configuration
- Allow skipping for emergency situations

### 6. Environment Variable Priority

**FR-6.1**: Implement priority system: Vault > .env > defaults
- Check Vault first for each secret
- Fall back to `.env` if Vault unavailable
- Use default values for non-critical configuration
- Log the source of each environment variable

**FR-6.2**: Handle critical vs non-critical secrets
- **Critical secrets** (fail if missing): `PRIVATE_KEY`, `TEST_PRIVATE_KEY`
- **Non-critical secrets** (warn if missing): API keys, tokens
- **Configuration** (use defaults): `WORKSPACE_NAME`, `NODE_ENV`, etc.

### 7. Error Handling and Validation

**FR-7.1**: Vault unavailability handling
- Detect Vault connection failure
- Fall back to `.env` secrets with warning
- Log fallback behavior
- Continue with placeholder values for non-critical secrets
- Fail fast for critical secrets

**FR-7.2**: Secret validation
- Validate secret format (e.g., private keys are 66 chars starting with 0x)
- Check for placeholder values still in use
- Warn about expiring tokens
- Validate RPC URLs are accessible

**FR-7.3**: Comprehensive error messages
- Provide actionable error messages
- Include documentation links
- Suggest common solutions
- Log error details for debugging

## Non-Goals (Out of Scope)

1. **Production Vault Setup**: This PRD covers only local development Vault setup, not production/staging Vault infrastructure
2. **Vault High Availability**: HA/clustering is not required for local dev environments
3. **Secret Rotation**: Automatic secret rotation is out of scope (manual rotation is sufficient)
4. **Cloud-Hosted Vault**: HCP Vault or cloud-hosted solutions are not included
5. **Backward Compatibility**: Supporting the old non-Vault setup is explicitly out of scope (Vault required for all new developers)
6. **Multi-User Vault**: Each developer runs their own local Vault instance; shared Vault is out of scope

## Design Considerations

### Docker-Compose Structure

The `.devcontainer/docker-compose.dev.yml` should follow this structure:

```yaml
version: "3.8"

services:
  devcontainer:
    build:
      context: ..
      dockerfile: .devcontainer/Dockerfile
      args:
        NODE_VERSION: 22
        PYTHON_VERSION: 3.11
        WORKSPACE_NAME: ${WORKSPACE_NAME}
    volumes:
      - ..:/workspaces/${WORKSPACE_NAME}:cached
      # ... other volumes
    environment:
      - WORKSPACE_NAME=${WORKSPACE_NAME}
      - VAULT_ADDR=http://vault-dev:8200
      # Other env vars from .env
    depends_on:
      - vault-dev
      - hardhat-node

  vault-dev:
    image: hashicorp/vault:latest
    command: server -dev -dev-root-token-id=root
    ports:
      - "8200:8200"
    environment:
      - VAULT_DEV_ROOT_TOKEN_ID=root
      - VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200

  hardhat-node:
    # Existing hardhat-node configuration
```

### Vault Secret Path Convention

Secrets should be organized by environment:
- `secret/dev/*` - Local development secrets
- `secret/test/*` - Test environment secrets  
- `secret/ci/*` - CI/CD secrets

### File Modifications Summary

**New Files:**
- `.devcontainer/docker-compose.dev.yml` - Main compose configuration
- `.devcontainer/scripts/vault-init.sh` - Vault initialization
- `.devcontainer/scripts/vault-fetch-secrets.sh` - Bash secret fetcher
- `.devcontainer/scripts/validate-vault-setup.sh` - Vault validation
- `scripts/setup/VaultSecretManager.ts` - TypeScript Vault client
- `scripts/setup/migrate-secrets-to-vault.sh` - Secret migration tool
- `scripts/setup/vault-setup-wizard.sh` - Interactive setup
- `docs/devs/VAULT_SETUP.md` - Vault setup guide
- `docs/devs/VAULT_TROUBLESHOOTING.md` - Troubleshooting guide

**Modified Files:**
- `.devcontainer/devcontainer.json` - Replace build with dockerComposeFile
- `.devcontainer/scripts/post-create.sh` - Add Vault integration
- `.devcontainer/scripts/post-start.sh` - Add Vault health check
- `.devcontainer/scripts/test-env.sh` - Add Vault tests
- `.env.example` - Update with Vault-only structure
- `.gitignore` - Add Vault-related files
- `docs/devs/ENV_VARS.md` - Update with Vault instructions
- `README.md` - Add Vault prerequisites

## Technical Considerations

### Docker-Compose Environment Variable Loading

DevContainer + Docker-Compose has specific requirements:
1. The `.env` file must be at the same level as `docker-compose.dev.yml` (`.devcontainer/` directory) OR at project root
2. Docker-compose automatically loads `.env` from the compose file directory
3. Use `env_file:` directive in compose if `.env` is elsewhere
4. VS Code DevContainer extension passes `${localEnv:VAR}` from host environment

**Solution**: Place `.env` at project root, and docker-compose will load it for variable substitution.

### Vault GitHub Authentication

GitHub auth in Vault requires:
1. Enabling the GitHub auth method in Vault
2. Configuring organization/team mappings to Vault policies
3. Using GitHub personal access tokens for authentication
4. Token must have `read:org` scope for organization verification

**Implementation**: Setup wizard will prompt for GitHub token and configure automatically.

### Secret Environment Variable Injection

Secrets must be available to:
1. Container build process (limited use)
2. Container runtime environment
3. Shell sessions inside container
4. Node.js processes via `process.env`
5. Hardhat configuration

**Solution**: `vault-fetch-secrets.sh` exports to `/etc/environment` and sources in shell profiles.

### Performance Considerations

- Vault secret fetching adds ~2-3 seconds to container startup
- Cache secrets in memory during container session
- Only fetch secrets once per container start unless refresh needed
- Use health checks to avoid repeated Vault connection attempts

## Success Metrics

**Priority 1 (Critical):**
1. `WORKSPACE_NAME` correctly loaded from `.env` in all contexts (mounts, workspace folder, environment)
2. Secrets never stored in repository or visible in shell history

**Priority 2 (High):**
3. DevContainer starts successfully with proper configuration on first try

**Priority 3 (Medium):**
4. Setup time for new developers < 10 minutes (including Vault setup)

**Priority 4 (Nice-to-Have):**
5. Zero manual environment variable configuration needed (wizard handles all)

### Acceptance Criteria

The feature is considered complete when:

1. **WORKSPACE_NAME Loading**
   - Creating `.env` with `WORKSPACE_NAME=my_project` results in workspace folder `/workspaces/my_project`
   - All mounts use the correct workspace name
   - No fallback to `diamonds_project` occurs when `.env` is properly configured

2. **Docker-Compose Integration**
   - DevContainer builds and starts using docker-compose
   - All services (devcontainer, vault-dev, hardhat-node) start successfully
   - Environment variables propagate correctly to container

3. **Vault Secret Management**
   - Vault dev server starts automatically with docker-compose
   - Setup wizard successfully migrates secrets from `.env` to Vault
   - `vault-fetch-secrets.sh` retrieves all required secrets
   - Secrets are available to all processes in container

4. **Developer Experience**
   - New developer can run setup wizard and have working environment in <10 minutes
   - Clear error messages guide users when configuration is incorrect
   - Validation script confirms all secrets are properly configured

5. **Security**
   - No secrets remain in `.env` after migration
   - `.env` file only contains non-secret configuration
   - Git ignores all secret-containing files
   - Secrets never appear in shell history or logs

6. **Fallback Behavior**
   - If Vault is unavailable, system falls back to `.env` with warning
   - Critical secrets cause failure if missing from both Vault and `.env`
   - Non-critical secrets use placeholders with warning

7. **Validation**
   - `validate-vault-setup.sh` reports green status when properly configured
   - `test-env.sh` includes Vault connectivity and secret access tests
   - All validation scripts provide actionable error messages

## Open Questions

1. **Vault Token Storage**: Where should the Vault root token be stored for developer access? Options:
   - In `.env` file (not ideal for security)
   - In `~/.vault-token` on host machine
   - Prompt on each container start (poor UX)
   
2. **Secret Synchronization**: If developer updates a secret in `.env` manually, should there be a sync command to update Vault?

3. **Team Secret Sharing**: How should teams share non-sensitive default secrets? Should there be a `secrets-template.json` that teams can use to populate their Vault?

4. **CI/CD Integration**: While out of scope for this PRD, should we design the Vault structure with CI/CD in mind (separate paths for CI secrets)?

5. **Docker Socket Mounting**: Should we mount Docker socket for potential future Docker-in-Docker needs, or keep it isolated?

6. **Vault Persistence**: Should Vault data persist across container rebuilds using a volume, or start fresh each time?

---

**Document Version**: 1.0  
**Last Updated**: 2025-10-18  
**Status**: Ready for Review  
**Target Audience**: Junior to Mid-Level Developers