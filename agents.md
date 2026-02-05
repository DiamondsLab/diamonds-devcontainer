# AGENTS.md

## Project Overview

This repository contains a **reusable DevContainer infrastructure** for Ethereum Diamond Proxy smart contract development. It's not a smart contract project itself, but rather the containerized development environment that can be deployed to multiple projects.

**What this repository is:**
- Infrastructure-as-code for development environments
- Template system for portable DevContainer configuration
- Multi-service Docker Compose setup
- Security-hardened container with comprehensive tooling
- Designed for both local development and CI/CD pipelines

**Key Technologies:**
- Docker & Docker Compose (multi-service architecture)
- Python 3 (initialization and templating scripts)
- Node.js 22 with Yarn 4.x (via Corepack)
- Go 1.24.7 (for OSV-Scanner and other tools)
- Bash scripting (lifecycle hooks and automation)

**Deployment Modes:**
1. **Git Submodule** - Added to projects as `.devcontainer/` submodule
2. **Direct Copy** - Configuration files copied into project
3. **CI/CD Integration** - Used in GitHub Actions for testing

**Architecture:**
- Template-based configuration with variable substitution
- Initialization script processes templates before container starts
- Multi-service Docker Compose with optional profiles
- Lifecycle hooks (post-create, post-start, post-attach)
- Volume-based caching for performance

## Repository Structure

```
.devcontainer/
├── devcontainer.template.json    # Template with __PLACEHOLDER__ variables
├── devcontainer.json             # Generated from template (git-ignored)
├── Dockerfile                    # Container build instructions
├── docker-compose.yml            # Production multi-service setup
├── docker-compose.dev.yml        # Development multi-service setup
├── .env.example                  # Environment variable template
├── .env                          # Local configuration (git-ignored)
├── scripts/
│   ├── init-devcontainer.py      # Template processor (runs on host)
│   ├── post-create.sh            # After container creation
│   ├── post-start.sh             # After container starts
│   ├── setup-security.sh         # Security tool configuration
│   ├── github-actions-setup.sh   # CI/CD parity validation
│   └── vault-*.sh                # Vault secret management
├── config/
│   ├── settings.json             # VS Code workspace settings
│   ├── slither.config.json       # Slither analyzer config
│   └── .semgrep.yml              # Semgrep security rules
└── docs/
    ├── QUICK_START.md            # Usage documentation
    └── PORTABILITY.md            # Template system guide

Key Files:
├── README.md                     # User-facing documentation
└── AGENTS.md                     # This file (agent documentation)
```

## Setup Commands

### Cloning and Initial Setup

```bash
# Clone the repository
git clone https://github.com/<org>/diamonds-devcontainer.git
cd diamonds-devcontainer

# Create local .env from template
cp .devcontainer/.env.example .devcontainer/.env

# Edit configuration
nano .devcontainer/.env
# Set WORKSPACE_NAME=diamonds_devcontainer (or your preferred name)
```

### Testing the DevContainer Locally

```bash
# Open in VS Code
code .

# Use Command Palette (Ctrl+Shift+P):
# "Dev Containers: Reopen in Container"

# Container will:
# 1. Run init-devcontainer.py (generates devcontainer.json)
# 2. Build Docker image from Dockerfile
# 3. Start services from docker-compose.dev.yml
# 4. Execute post-create.sh (install dependencies)
# 5. Execute post-start.sh (start services)
# 6. Execute setup-security.sh (configure security tools)
```

### Manual Template Processing

```bash
# Process template manually (for testing)
cd .devcontainer
python3 scripts/init-devcontainer.py

# Verify generated devcontainer.json
cat devcontainer.json | jq .
```

## Development Workflow

### Template System

The DevContainer uses a template-based configuration system:

**Template Variables:**
- `__WORKSPACE_NAME__` - Replaced with project-specific identifier
- `__DIAMOND_NAME__` - Replaced with diamond contract name
- `__VAULT_PORT__` - Replaced with Vault server port

**Processing Flow:**
1. User creates `.env` file with project-specific values
2. `init-devcontainer.py` runs on **host machine** before container starts
3. Script reads `.env` and loads values
4. Script processes `devcontainer.template.json` → `devcontainer.json`
5. Generated `devcontainer.json` is used to start container
6. Environment variables are available in container via `containerEnv`

**Example Template Processing:**

```python
# In init-devcontainer.py
workspace_name = env_vars.get('WORKSPACE_NAME', 'diamonds_project')
output = template.replace('__WORKSPACE_NAME__', workspace_name)
```

### Modifying the Dockerfile

When adding new tools or changing the container image:

```bash
# Edit Dockerfile
nano .devcontainer/Dockerfile

# Add new tool installation (example: adding a new Python package)
# Find the "Install Python security tools" section and add:
RUN pipx install your-new-tool

# Rebuild container to test
# In VS Code: Command Palette → "Dev Containers: Rebuild Container"

# Or rebuild manually:
docker-compose -f .devcontainer/docker-compose.dev.yml build --no-cache
```

**Dockerfile Structure:**
1. Base image: `node:22-slim` (minimal attack surface)
2. System dependencies and tools installation
3. Create workspace directory
4. Switch to `node` user (non-root)
5. Install Python tools via `pipx` (isolated environments)
6. Install Node.js global packages
7. Configure git-secrets patterns
8. Set up cache directories
9. Health checks and default command

### Modifying Docker Compose Services

```bash
# Edit service configuration
nano .devcontainer/docker-compose.yml

# Add new service (example: adding MongoDB)
# Add to services section:
mongo-db:
  image: mongo:latest
  ports:
    - "${MONGO_PORT:-27017}:27017"
  volumes:
    - mongo-data:/data/db
  networks:
    - ${WORKSPACE_NAME}-network
  profiles:
    - database

# Add to volumes section:
volumes:
  mongo-data:

# Test with profile
docker-compose -f .devcontainer/docker-compose.yml --profile database up -d
```

### Adding Lifecycle Scripts

**Script Execution Order:**
1. `initializeCommand` - Runs on HOST before container starts
2. `postCreateCommand` - Runs ONCE after container is created
3. `postStartCommand` - Runs every time container starts
4. `postAttachCommand` - Runs when attaching to container

```bash
# Add new post-create task
nano .devcontainer/scripts/post-create.sh

# Example: Add dependency installation
echo "Installing project dependencies..."
yarn install --frozen-lockfile

# Make script executable
chmod +x .devcontainer/scripts/post-create.sh

# Test by rebuilding container
```

### Working with Environment Variables

**Three levels of environment variables:**

1. **Build-time** (Dockerfile ARG):
   ```dockerfile
   ARG WORKSPACE_NAME
   RUN mkdir -p /workspaces/${WORKSPACE_NAME}
   ```

2. **Container-time** (devcontainer.json containerEnv):
   ```json
   "containerEnv": {
     "WORKSPACE_NAME": "__WORKSPACE_NAME__"
   }
   ```

3. **Runtime** (.env file loaded by compose):
   ```bash
   WORKSPACE_NAME=my_project
   VAULT_PORT=8201
   ```

### Testing Changes

```bash
# 1. Clean rebuild (tests Dockerfile changes)
docker-compose -f .devcontainer/docker-compose.dev.yml down -v
docker-compose -f .devcontainer/docker-compose.dev.yml build --no-cache
docker-compose -f .devcontainer/docker-compose.dev.yml up -d

# 2. Test template processing
python3 .devcontainer/scripts/init-devcontainer.py
cat .devcontainer/devcontainer.json | jq .workspaceFolder

# 3. Test in VS Code
# Command Palette → "Dev Containers: Rebuild Container"

# 4. Verify all services start
docker-compose -f .devcontainer/docker-compose.dev.yml ps

# 5. Check logs for errors
docker-compose -f .devcontainer/docker-compose.dev.yml logs -f devcontainer
```

## Testing the DevContainer

### Local Testing Workflow

**1. Test Template Processing:**
```bash
# Clear generated files
rm -f .devcontainer/devcontainer.json

# Set test workspace name
echo "WORKSPACE_NAME=test_workspace_123" > .devcontainer/.env

# Run initialization
python3 .devcontainer/scripts/init-devcontainer.py

# Verify correct substitution
grep "test_workspace_123" .devcontainer/devcontainer.json
```

**2. Test Container Build:**
```bash
# Build without cache (full test)
cd .devcontainer
docker-compose -f docker-compose.dev.yml build --no-cache

# Check for build errors
echo $?  # Should be 0

# Inspect image size
docker images | grep devcontainer
```

**3. Test Container Startup:**
```bash
# Start container
docker-compose -f .devcontainer/docker-compose.dev.yml up -d

# Check all services are running
docker-compose -f .devcontainer/docker-compose.dev.yml ps

# Verify devcontainer is healthy
docker ps --filter "name=devcontainer" --format "{{.Status}}"

# Check logs for errors
docker-compose -f .devcontainer/docker-compose.dev.yml logs devcontainer | grep -i error
```

**4. Test Tool Installation:**
```bash
# Execute commands in container to verify tools
docker-compose -f .devcontainer/docker-compose.dev.yml exec devcontainer bash -c "
  node --version &&
  yarn --version &&
  python3 --version &&
  go version &&
  slither --version &&
  semgrep --version &&
  snyk --version &&
  git secrets --version
"

# Should output versions for all tools
```

**5. Test Lifecycle Scripts:**
```bash
# Rebuild to trigger post-create
docker-compose -f .devcontainer/docker-compose.dev.yml down -v
docker-compose -f .devcontainer/docker-compose.dev.yml up -d

# Check post-create.sh executed
docker-compose -f .devcontainer/docker-compose.dev.yml logs devcontainer | grep "post-create"

# Check post-start.sh executed
docker-compose -f .devcontainer/docker-compose.dev.yml logs devcontainer | grep "post-start"
```

### Testing as Git Submodule

Simulate how projects will use this DevContainer:

```bash
# Create test project
mkdir -p /tmp/test-project
cd /tmp/test-project
git init

# Add DevContainer as submodule
git submodule add /path/to/diamonds-devcontainer .devcontainer

# Configure
cp .devcontainer/.env.example .devcontainer/.env
echo "WORKSPACE_NAME=test_project" > .devcontainer/.env

# Test opening in VS Code
code .
# Then: Dev Containers: Reopen in Container

# Verify workspace folder
# Inside container:
echo $WORKSPACE_FOLDER  # Should be /workspaces/test_project
echo $WORKSPACE_NAME    # Should be test_project
```

### Testing Different Configurations

**Test with minimal services:**
```bash
# Use only devcontainer service
docker-compose -f .devcontainer/docker-compose.dev.yml up devcontainer
```

**Test with database profile:**
```bash
# Start with PostgreSQL
docker-compose -f .devcontainer/docker-compose.yml --profile database up -d

# Verify Postgres is accessible
docker-compose -f .devcontainer/docker-compose.yml exec postgres-db psql -U postgres -c "SELECT version();"
```

**Test with IPFS profile:**
```bash
# Start with IPFS
docker-compose -f .devcontainer/docker-compose.yml --profile ipfs up -d

# Test IPFS API
curl http://localhost:5001/api/v0/version
```

### CI/CD Testing

**Validate GitHub Actions Parity:**
```bash
# Inside container, run parity check
bash .devcontainer/scripts/github-actions-setup.sh

# Should verify:
# - Node.js version matches CI
# - Yarn version matches CI
# - Python version matches CI
# - Security tool versions match CI
```

**Simulate CI Environment:**
```bash
# Set CI mode
export CI_MODE=true
export CI=true

# Run setup like CI would
yarn install --frozen-lockfile
yarn build
yarn test
yarn security-check

# All should pass
```

### Security Testing

**Test git-secrets:**
```bash
# Inside container
cd /workspaces/${WORKSPACE_NAME}

# Create test file with secret pattern
echo "PRIVATE_KEY=0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" > test-secrets.txt

# Try to commit (should fail)
git add test-secrets.txt
git commit -m "test"
# Should be blocked by git-secrets pre-commit hook

# Clean up
rm test-secrets.txt
```

**Test security scanners:**
```bash
# Test Slither (requires Solidity contracts)
slither --version

# Test Semgrep
semgrep --version
semgrep --config auto .

# Test Snyk (requires authentication)
snyk test || echo "Snyk auth required"
```

### Performance Testing

**Measure build time:**
```bash
time docker-compose -f .devcontainer/docker-compose.dev.yml build --no-cache
# Record build duration
```

**Test volume performance:**
```bash
# Inside container
time yarn install  # First run (no cache)
# vs
time yarn install  # Second run (with cache)
```

**Memory and CPU usage:**
```bash
# Monitor during operation
docker stats --no-stream

# Check container memory limit
docker inspect devcontainer | grep -i memory
```

### Breaking Change Testing

Before major updates:

```bash
# 1. Tag current working version
git tag -a v1.0.0 -m "Working version before changes"

# 2. Make changes to Dockerfile/scripts

# 3. Test with old projects
# Clone an existing project that uses this DevContainer
# Point submodule to local dev version
# Try to build and run

# 4. Document any breaking changes in changelog
```

## Code Style and Conventions

### Bash Scripts

**Script Header:**
```bash
#!/usr/bin/env bash
set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Script Name: descriptive-name.sh
# Purpose: Brief description
# Usage: ./script-name.sh [args]
```

**Error Handling:**
```bash
# Always check command success
if ! command_that_might_fail; then
    echo "Error: Command failed" >&2
    exit 1
fi

# Use trap for cleanup
cleanup() {
    rm -f /tmp/tempfile
}
trap cleanup EXIT
```

**Logging:**
```bash
# Use consistent logging
log_info() { echo "[INFO] $*"; }
log_error() { echo "[ERROR] $*" >&2; }
log_success() { echo "[SUCCESS] $*"; }
```

### Python Scripts

**Follow PEP 8:**
```python
#!/usr/bin/env python3
"""
Module docstring explaining purpose.

Detailed description if needed.
"""

import os
import sys
from pathlib import Path
from typing import Dict, Optional

class ClassName:
    """Class docstring."""
    
    def method_name(self, param: str) -> bool:
        """Method docstring."""
        pass
```

**Type Hints:**
```python
# Always use type hints
def process_template(
    template_path: Path,
    output_path: Path,
    variables: Dict[str, str]
) -> None:
    """Process template with variable substitution."""
    pass
```

### Dockerfile Conventions

**Layer Optimization:**
```dockerfile
# Combine related commands to minimize layers
RUN apt-get update && apt-get install -y \
    package1 \
    package2 \
    package3 \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# Not this (creates unnecessary layers):
# RUN apt-get update
# RUN apt-get install -y package1
# RUN apt-get install -y package2
```

**Comments:**
```dockerfile
# Use comments to explain why, not what
# Use Node.js slim for smaller attack surface (not "Install Node.js")
FROM node:22-slim

# Install build tools required by native npm modules
RUN apt-get update && apt-get install -y build-essential
```

**Security:**
```dockerfile
# Always switch to non-root user
USER node

# Never run as root in production
# Always specify USER directive
```

### Docker Compose Conventions

**Service Naming:**
```yaml
# Use descriptive, kebab-case names
services:
  devcontainer:        # Main development container
  hardhat-node:        # Local blockchain node
  postgres-db:         # PostgreSQL database
```

**Volume Naming:**
```yaml
volumes:
  # Named volumes for persistence
  yarn-cache:
  node-modules:
  
  # Descriptive names
  hardhat-artifacts:
  typechain-types:
```

**Environment Variables:**
```yaml
# Always use ${VAR:-default} syntax
environment:
  - WORKSPACE_NAME=${WORKSPACE_NAME:-diamonds_project}
  - NODE_ENV=${NODE_ENV:-development}
```

### Template Conventions

**Placeholder Format:**
```json
// Use double underscores for template variables
{
  "name": "__WORKSPACE_NAME__",
  "workspaceFolder": "/workspaces/__WORKSPACE_NAME__"
}

// NOT: ${WORKSPACE_NAME} (that's for environment variables)
// NOT: {{WORKSPACE_NAME}} (that's for other template systems)
```

**Variable Naming:**
- Use `UPPER_SNAKE_CASE` for environment variables
- Use `__UPPER_SNAKE_CASE__` for template placeholders
- Use `kebab-case` for filenames and service names
- Use `snake_case` for workspace/project names (Docker compatibility)

### Git Conventions

**Commit Messages:**
```
feat: add MongoDB service to docker-compose
fix: correct vault port substitution in template
docs: update usage instructions for submodule setup
refactor: simplify post-create script
test: add integration tests for template processing
chore: update Node.js to v22
security: update Slither to latest version
```

**Branch Naming:**
```
feature/add-mongodb-service
fix/vault-port-templating
docs/improve-readme
refactor/simplify-scripts
```

### File Organization

**Script Organization:**
```
scripts/
├── init-devcontainer.py      # Main initialization (host-side)
├── post-create.sh             # Container lifecycle hooks
├── post-start.sh
├── setup-security.sh          # Feature-specific setup
├── github-actions-setup.sh    # CI/CD integration
├── setup/                     # Grouped setup scripts
│   ├── vault-setup-wizard.sh
│   └── migrate-secrets-to-vault.sh
└── vault-*.sh                 # Feature-prefixed scripts
```

**Configuration Organization:**
```
config/
├── settings.json              # VS Code settings
├── slither.config.json        # Tool-specific configs
└── .semgrep.yml
```

### Documentation Standards

**README.md:**
- User-facing, getting started guide
- Quick start examples
- Link to detailed docs

**AGENTS.md:**
- Developer/agent facing
- Technical implementation details
- Maintenance and testing procedures

**Inline Documentation:**
```bash
# Good: Explains why
# Use dev mode for faster startup without authentication
VAULT_COMMAND="server -dev"

# Bad: States the obvious
# Set vault command
VAULT_COMMAND="server -dev"
```

## Adding New Features to the DevContainer

### Adding a New Development Tool

**Example: Adding hadolint (Dockerfile linter)**

1. **Add to Dockerfile:**
```dockerfile
# In Dockerfile, after other tool installations
RUN curl -L https://github.com/hadolint/hadolint/releases/download/v2.12.0/hadolint-Linux-x86_64 \
  -o /usr/local/bin/hadolint \
  && chmod +x /usr/local/bin/hadolint
```

2. **Add configuration file:**
```yaml
# Create config/hadolint.yaml
---
ignored:
  - DL3008  # Pin versions in apt-get install
  - DL3009  # Delete apt cache
```

3. **Add to post-create script:**
```bash
# In scripts/post-create.sh
log_info "Configuring hadolint..."
cp /workspaces/${WORKSPACE_NAME}/.devcontainer/config/hadolint.yaml ~/.hadolint.yaml
```

4. **Add VS Code extension:**
```json
// In devcontainer.template.json
"customizations": {
  "vscode": {
    "extensions": [
      "exiasr.hadolint"
    ]
  }
}
```

5. **Test:**
```bash
docker-compose -f .devcontainer/docker-compose.dev.yml build --no-cache
docker-compose -f .devcontainer/docker-compose.dev.yml run devcontainer hadolint --version
```

### Adding a New Service

**Example: Adding Elasticsearch**

1. **Add service to docker-compose.yml:**
```yaml
elasticsearch:
  image: docker.elastic.co/elasticsearch/elasticsearch:8.11.0
  environment:
    - discovery.type=single-node
    - xpack.security.enabled=false
    - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
  ports:
    - "${ELASTICSEARCH_PORT:-9200}:9200"
  volumes:
    - elasticsearch-data:/usr/share/elasticsearch/data
  networks:
    - ${WORKSPACE_NAME}-network
  profiles:
    - search
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:9200/_cluster/health"]
    interval: 30s
    timeout: 10s
    retries: 5
```

2. **Add volume:**
```yaml
volumes:
  elasticsearch-data:
```

3. **Add to .env.example:**
```bash
# Elasticsearch
ELASTICSEARCH_PORT=9200
```

4. **Document in README.md:**
```markdown
### Search Services

Start with Elasticsearch:
```bash
docker-compose --profile search up -d
```
```

5. **Test:**
```bash
docker-compose -f .devcontainer/docker-compose.yml --profile search up -d
curl http://localhost:9200/_cluster/health
```

### Adding VS Code Configuration

**Add new VS Code settings:**

```json
// In devcontainer.template.json customizations.vscode.settings
"editor.rulers": [80, 120],
"editor.wordWrap": "on",
"files.watcherExclude": {
  "**/node_modules/**": true,
  "**/.yarn/**": true
}
```

### Adding Environment Variables

1. **Add to .env.example:**
```bash
# New feature configuration
NEW_FEATURE_ENABLED=true
NEW_FEATURE_PORT=9999
```

2. **Add to devcontainer.template.json:**
```json
"containerEnv": {
  "NEW_FEATURE_ENABLED": "__NEW_FEATURE_ENABLED__",
  "NEW_FEATURE_PORT": "__NEW_FEATURE_PORT__"
}
```

3. **Update init-devcontainer.py:**
```python
# In generate_devcontainer function
new_feature_enabled = env_vars.get('NEW_FEATURE_ENABLED', 'false')
new_feature_port = env_vars.get('NEW_FEATURE_PORT', '9999')

output = output.replace('__NEW_FEATURE_ENABLED__', new_feature_enabled)
output = output.replace('__NEW_FEATURE_PORT__', new_feature_port)
```

4. **Test template processing:**
```bash
python3 .devcontainer/scripts/init-devcontainer.py
grep "NEW_FEATURE" .devcontainer/devcontainer.json
```

## Build Optimization

### Docker Build Caching

**Layer ordering for maximum cache reuse:**

```dockerfile
# 1. System packages (changes rarely)
RUN apt-get update && apt-get install -y ...

# 2. Global tools (changes occasionally)
RUN npm install -g snyk

# 3. Project setup (changes per project)
COPY package.json ./
RUN yarn install

# 4. Source code (changes frequently)
COPY . .
```

**Multi-stage builds (if needed):**

```dockerfile
# Build stage
FROM node:22 AS builder
WORKDIR /build
COPY package.json ./
RUN yarn install
COPY . .
RUN yarn build

# Runtime stage  
FROM node:22-slim
COPY --from=builder /build/dist ./dist
```

### Volume Caching Strategy

**Named volumes for persistence:**

```yaml
volumes:
  # Cache that persists across rebuilds
  yarn-cache:
    driver: local
  
  # Bind mount for active development
  - ..:/workspaces/${WORKSPACE_NAME}:cached
  
  # Delegated for large writes (artifacts)
  - hardhat-artifacts:/workspaces/${WORKSPACE_NAME}/artifacts:delegated
```

### BuildKit Features

```dockerfile
# syntax=docker/dockerfile:1.4

# Use BuildKit cache mounts
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt/lists \
    apt-get update && apt-get install -y build-essential

# Cache npm installs
RUN --mount=type=cache,target=/home/node/.npm \
    npm install -g snyk
```

**Enable BuildKit:**
```bash
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1
docker-compose build
```

## CI/CD Integration

### GitHub Actions Configuration

The DevContainer should work identically in GitHub Actions:

**Example .github/workflows/ci.yml:**

```yaml
name: CI

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    container:
      image: devcontainer:latest
      env:
        WORKSPACE_NAME: ci_test
        CI_MODE: "true"
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup DevContainer Environment
        run: bash .devcontainer/scripts/github-actions-setup.sh
      
      - name: Install Dependencies
        run: yarn install --frozen-lockfile
      
      - name: Lint
        run: yarn lint
      
      - name: Test
        run: yarn test
      
      - name: Security Check
        run: yarn security-check
```

### Ensuring Parity

**Verification script (github-actions-setup.sh):**

```bash
#!/usr/bin/env bash

# Verify Node.js version
NODE_VERSION=$(node --version)
echo "Node.js: $NODE_VERSION"

# Verify Yarn version
YARN_VERSION=$(yarn --version)
echo "Yarn: $YARN_VERSION"

# Verify Python version
PYTHON_VERSION=$(python3 --version)
echo "Python: $PYTHON_VERSION"

# Verify security tools
slither --version || echo "Warning: Slither not found"
semgrep --version || echo "Warning: Semgrep not found"
snyk --version || echo "Warning: Snyk not found"

# Set up CI-specific configurations
if [ "$CI_MODE" = "true" ]; then
  echo "CI_MODE=true" >> $GITHUB_ENV
  yarn config set enableImmutableInstalls true
fi
```

### Publishing the DevContainer Image

**Build and tag:**
```bash
# Build for specific version
docker build -t myorg/diamonds-devcontainer:v1.0.0 \
  --build-arg WORKSPACE_NAME=diamonds_project \
  -f .devcontainer/Dockerfile \
  .devcontainer

# Tag as latest
docker tag myorg/diamonds-devcontainer:v1.0.0 myorg/diamonds-devcontainer:latest

# Push to registry
docker push myorg/diamonds-devcontainer:v1.0.0
docker push myorg/diamonds-devcontainer:latest
```

**Use pre-built image:**
```json
// In devcontainer.json
{
  "image": "myorg/diamonds-devcontainer:latest",
  // Remove "build" section
}
```

## Security Considerations

### Container Security

**1. Use minimal base images:**
```dockerfile
# Good: Slim variant
FROM node:22-slim

# Avoid: Full variant (larger attack surface)
# FROM node:22
```

**2. Run as non-root user:**
```dockerfile
# Switch to non-root early
USER node
WORKDIR /home/node

# Never run application as root
```

**3. Apply security updates:**
```dockerfile
# Update packages during build
RUN apt-get update && apt-get upgrade -y
```

**4. Scan for vulnerabilities:**
```bash
# Scan Docker image
docker scan devcontainer:latest

# Use Trivy
trivy image devcontainer:latest
```

### Secret Management

**Never commit:**
- `.env` files with real secrets
- API tokens or keys
- Private keys or mnemonics

**Do commit:**
- `.env.example` with placeholder values
- Documentation about required secrets
- Instructions for obtaining secrets

**Use Vault for sensitive data:**
```bash
# Vault integration already configured
# Secrets are fetched at runtime, not baked into image
```

### Git-Secrets Configuration

**Pre-configured patterns:**
```bash
# Ethereum private keys
0x[a-fA-F0-9]{64}

# API keys
INFURA_API_KEY|ALCHEMY_API_KEY|ETHERSCAN_API_KEY

# Generic secrets
PRIVATE_KEY\s*=\s*["']*0x[a-fA-F0-9]{64}["']*
SECRET_KEY\s*=\s*["']*[a-zA-Z0-9]{32,}["']*
```

**Adding custom patterns:**
```bash
# In Dockerfile or post-create.sh
git config --global secrets.patterns "YOUR_CUSTOM_PATTERN"
```

## Dependency Management

### Updating Node.js Version

1. **Update Dockerfile:**
```dockerfile
FROM node:23-slim  # Changed from node:22-slim
ARG NODE_VERSION=23  # Update version arg
```

2. **Update documentation:**
```markdown
# In README.md
- Node.js 23 with Yarn 4.x
```

3. **Test compatibility:**
```bash
docker-compose build --no-cache
docker-compose run devcontainer node --version
```

4. **Update CI:**
```yaml
# In .github/workflows/ci.yml
container:
  image: node:23
```

### Updating Security Tools

**Updating Slither:**
```dockerfile
# In Dockerfile
RUN pipx install slither-analyzer==0.10.0  # Pin specific version

# Or update to latest
RUN pipx install --force slither-analyzer
```

**Verify version:**
```bash
docker-compose run devcontainer slither --version
```

### Managing Python Dependencies

**Using pipx for isolation:**
```dockerfile
# Each tool in isolated environment
RUN pipx install slither-analyzer
RUN pipx install semgrep
RUN pipx install bandit
```

**Benefits:**
- No dependency conflicts
- Easy updates
- Clean uninstalls

### Node.js Global Packages

```dockerfile
# Install specific versions
RUN npm install -g snyk@1.1200.0

# Update to latest
RUN npm install -g snyk@latest

# List installed
RUN npm list -g --depth=0
```

## Troubleshooting

### Common DevContainer Issues

**Issue: Template processing fails**
```bash
# Solution: Check .env file format
cat .devcontainer/.env
# Ensure no spaces around '='
# Correct: WORKSPACE_NAME=my_project
# Wrong: WORKSPACE_NAME = my_project

# Re-run initialization
python3 .devcontainer/scripts/init-devcontainer.py
```

**Issue: Container won't start**
```bash
# Check Docker daemon
docker info

# Check disk space
df -h

# Clean up Docker resources
docker system prune -a
docker volume prune

# Rebuild from scratch
docker-compose -f .devcontainer/docker-compose.dev.yml down -v
docker-compose -f .devcontainer/docker-compose.dev.yml build --no-cache
```

**Issue: Volume mount permission errors**
```bash
# Check ownership
ls -la /workspaces/${WORKSPACE_NAME}

# Fix permissions (inside container)
sudo chown -R node:node /workspaces/${WORKSPACE_NAME}

# Or rebuild with correct USER directive
```

**Issue: Network name conflicts**
```bash
# List Docker networks
docker network ls

# Remove conflicting network
docker network rm ${WORKSPACE_NAME}-network

# Use underscores, not hyphens in WORKSPACE_NAME
WORKSPACE_NAME=my_project  # Good
WORKSPACE_NAME=my-project  # May cause issues
```

**Issue: Service won't start (e.g., hardhat-node)**
```bash
# Check logs
docker-compose -f .devcontainer/docker-compose.yml logs hardhat-node

# Check if port is in use
lsof -i :8545

# Change port in .env
echo "HARDHAT_PORT=8547" >> .devcontainer/.env

# Restart services
docker-compose -f .devcontainer/docker-compose.yml restart
```

**Issue: Scripts don't execute**
```bash
# Make scripts executable
chmod +x .devcontainer/scripts/*.sh

# Check script syntax
bash -n .devcontainer/scripts/post-create.sh

# Test script manually
docker-compose -f .devcontainer/docker-compose.dev.yml exec devcontainer \
  bash /workspaces/${WORKSPACE_NAME}/.devcontainer/scripts/post-create.sh
```

**Issue: Tool not found in container**
```bash
# Verify tool installation
docker-compose -f .devcontainer/docker-compose.dev.yml exec devcontainer which slither

# Check PATH
docker-compose -f .devcontainer/docker-compose.dev.yml exec devcontainer echo $PATH

# Reinstall tool (rebuild required)
# Edit Dockerfile, then:
docker-compose -f .devcontainer/docker-compose.dev.yml build --no-cache
```

**Issue: Slow build times**
```bash
# Enable BuildKit
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

# Use cache mounts (see Build Optimization section)

# Build specific service only
docker-compose -f .devcontainer/docker-compose.dev.yml build devcontainer
```

### Debugging the Container

**Access running container:**
```bash
# Execute bash shell
docker-compose -f .devcontainer/docker-compose.dev.yml exec devcontainer bash

# Or use specific user
docker-compose -f .devcontainer/docker-compose.dev.yml exec -u node devcontainer bash
```

**Inspect container configuration:**
```bash
# View container details
docker inspect devcontainer

# View environment variables
docker inspect devcontainer | jq '.[0].Config.Env'

# View mounts
docker inspect devcontainer | jq '.[0].Mounts'
```

**Check container logs:**
```bash
# All logs
docker-compose -f .devcontainer/docker-compose.dev.yml logs

# Follow logs
docker-compose -f .devcontainer/docker-compose.dev.yml logs -f devcontainer

# Last 100 lines
docker-compose -f .devcontainer/docker-compose.dev.yml logs --tail=100 devcontainer
```

**Test without VS Code:**
```bash
# Start container manually
docker-compose -f .devcontainer/docker-compose.dev.yml up -d

# Attach to container
docker attach devcontainer

# Or exec commands
docker-compose -f .devcontainer/docker-compose.dev.yml exec devcontainer node --version
```

## Pull Request Guidelines

### Before Submitting PR

**1. Test all changes:**
```bash
# Test template processing
python3 .devcontainer/scripts/init-devcontainer.py

# Test container build
docker-compose -f .devcontainer/docker-compose.dev.yml build

# Test container startup
docker-compose -f .devcontainer/docker-compose.dev.yml up -d

# Test lifecycle scripts
docker-compose -f .devcontainer/docker-compose.dev.yml logs devcontainer | grep -E "post-create|post-start"

# Test as submodule
mkdir /tmp/test-pr && cd /tmp/test-pr
git init
git submodule add /path/to/your/fork .devcontainer
code .  # Test in VS Code
```

**2. Validate configurations:**
```bash
# Validate JSON files
jq empty .devcontainer/devcontainer.template.json
jq empty .devcontainer/config/*.json

# Validate YAML files
yamllint .devcontainer/docker-compose.yml

# Validate shell scripts
shellcheck .devcontainer/scripts/*.sh
```

**3. Update documentation:**
```bash
# If adding new feature:
# - Update README.md
# - Update AGENTS.md (this file)
# - Update .env.example
# - Add usage examples

# If changing configuration:
# - Document in PORTABILITY.md
# - Update template if needed
```

### PR Title Format

Use conventional commits:
```
feat(dockerfile): add MongoDB client tools
fix(template): correct VAULT_PORT substitution
docs(readme): update submodule usage instructions
chore(deps): update Node.js to v22.1.0
refactor(scripts): simplify post-create workflow
test(ci): add integration tests for template system
security(docker): update base image for CVE fixes
```

### Required Checks

Before merging:
- ✅ Container builds successfully
- ✅ Template processing works
- ✅ All scripts execute without errors
- ✅ Works as git submodule
- ✅ Works with direct copy
- ✅ CI/CD parity maintained
- ✅ Documentation updated
- ✅ No hardcoded project names
- ✅ Backwards compatible (or breaking changes documented)

### Review Checklist

**For Dockerfile changes:**
- [ ] Using slim base images
- [ ] Running as non-root user (USER node)
- [ ] Minimizing layers
- [ ] Cleaning up after installations
- [ ] Security updates applied
- [ ] Build args properly used

**For script changes:**
- [ ] Error handling implemented (set -e)
- [ ] Logging is clear and helpful
- [ ] Scripts are executable (chmod +x)
- [ ] Works in both local and CI environments
- [ ] Environment variables validated

**For template changes:**
- [ ] Placeholder format consistent (__VAR__)
- [ ] init-devcontainer.py updated
- [ ] .env.example updated
- [ ] Documentation updated
- [ ] Tested with different values

**For service additions:**
- [ ] Profile-based (optional services use profiles)
- [ ] Health checks implemented
- [ ] Documentation added
- [ ] Environment variables in .env.example
- [ ] Tested startup and shutdown

## Usage Examples

### For End Users

**Using as Git Submodule:**
```bash
# In their project
cd /path/to/my-diamond-project
git submodule add https://github.com/org/diamonds-devcontainer .devcontainer

# Configure
cp .devcontainer/.env.example .devcontainer/.env
nano .devcontainer/.env  # Set WORKSPACE_NAME=my_diamond_project

# Open in VS Code
code .
# Dev Containers: Reopen in Container
```

**Direct Copy Method:**
```bash
# Copy files
cp -r /path/to/diamonds-devcontainer/.devcontainer /path/to/my-project/

# Configure
cd /path/to/my-project
echo "WORKSPACE_NAME=my_project" > .devcontainer/.env

# Use
code .
```

### For DevContainer Developers

**Local Development:**
```bash
# Clone this repository
git clone https://github.com/org/diamonds-devcontainer
cd diamonds-devcontainer

# Setup
cp .devcontainer/.env.example .devcontainer/.env
echo "WORKSPACE_NAME=diamonds_devcontainer" > .devcontainer/.env

# Test in VS Code
code .
# Dev Containers: Reopen in Container

# Make changes to Dockerfile, scripts, etc.

# Test changes
docker-compose -f .devcontainer/docker-compose.dev.yml down -v
docker-compose -f .devcontainer/docker-compose.dev.yml build --no-cache
docker-compose -f .devcontainer/docker-compose.dev.yml up -d
```

**Testing in Isolation:**
```bash
# Create test project
mkdir /tmp/test-project
cd /tmp/test-project

# Add as submodule (pointing to local dev version)
git init
git submodule add /path/to/diamonds-devcontainer .devcontainer

# Configure
echo "WORKSPACE_NAME=test_project" > .devcontainer/.env

# Test
code .
```

## Additional Notes

### Environment Variable Reference

**Core Variables (.env file):**
```bash
# Project Identity (REQUIRED)
WORKSPACE_NAME=my_project           # Project identifier (use underscores)
DIAMOND_NAME=MyDiamond             # Diamond contract name

# Vault Configuration
VAULT_COMMAND=server -dev          # Vault startup command
VAULT_PORT=8201                    # Vault server port

# Port Mappings
HARDHAT_PORT=8545                  # Hardhat node port
ADDITIONAL_BLOCKCHAIN_PORT=8556    # Secondary blockchain port
FRONTEND_PORT=3001                 # Frontend dev server port
API_PORT=5001                      # API server port
DOC_PORT=8081                      # Documentation server port
```

**Template Placeholders (devcontainer.template.json):**
```
__WORKSPACE_NAME__    → Replaced with WORKSPACE_NAME from .env
__DIAMOND_NAME__      → Replaced with DIAMOND_NAME from .env
__VAULT_PORT__        → Replaced with VAULT_PORT from .env
```

**Container Environment (available inside container):**
```bash
WORKSPACE_NAME        # From .env
WORKSPACE_FOLDER      # /workspaces/${WORKSPACE_NAME}
DIAMOND_NAME          # From .env
NODE_ENV              # development
HARDHAT_NETWORK       # hardhat
CI_MODE               # false (or true in CI)
```

### Lifecycle Hook Execution Order

1. **initializeCommand** (host machine)
   - Runs: `python3 .devcontainer/scripts/init-devcontainer.py`
   - Purpose: Generate devcontainer.json from template
   - Environment: Host machine (before container exists)

2. **Container Build**
   - Dockerfile executed
   - Image created
   - Base tools installed

3. **postCreateCommand** (inside container, once)
   - Runs: `bash .devcontainer/scripts/post-create.sh`
   - Purpose: Project setup (yarn install, compile, etc.)
   - Runs: Only once after container is created

4. **postStartCommand** (inside container, every start)
   - Runs: `bash .devcontainer/scripts/post-start.sh`
   - Purpose: Start services (if needed)
   - Runs: Every time container starts

5. **postAttachCommand** (inside container, every attach)
   - Runs: `bash .devcontainer/scripts/setup-security.sh`
   - Purpose: Configure security tools
   - Runs: Every time VS Code attaches

### Best Practices

**Template Variables:**
- Always provide defaults: `${localEnv:VAR:default_value}`
- Use descriptive names: `WORKSPACE_NAME` not `WS`
- Document in .env.example

**Scripts:**
- Make idempotent (can run multiple times safely)
- Log progress with echo statements
- Exit on error: `set -euo pipefail`
- Clean up on failure: use `trap`

**Docker Configuration:**
- Use named volumes for persistence
- Use profiles for optional services
- Implement health checks
- Document port mappings

**Security:**
- Never commit .env files
- Always run as non-root user
- Apply security updates
- Scan images regularly

### Maintenance Schedule

**Weekly:**
- Check for security updates to base images
- Test with latest VS Code version
- Review open issues

**Monthly:**
- Update Node.js to latest LTS patch
- Update Python tools (slither, semgrep)
- Update npm global packages
- Review and update documentation

**Quarterly:**
- Consider Node.js LTS version updates
- Evaluate new development tools
- Review and optimize build times
- Update examples and templates

**Annually:**
- Major version upgrades (Node.js, Python)
- Architecture review
- Deprecated feature removal
- Comprehensive security audit

### Support and Resources

- **DevContainer Spec:** https://containers.dev/
- **Docker Documentation:** https://docs.docker.com/
- **Docker Compose:** https://docs.docker.com/compose/
- **VS Code DevContainers:** https://code.visualstudio.com/docs/devcontainers/containers

---

**Note for AI Agents:** This is infrastructure-as-code for a reusable DevContainer. When making changes, always test both local usage and as a git submodule in a separate project. Ensure CI/CD parity is maintained. Document all breaking changes. The template system is critical - test template processing thoroughly after any changes to init-devcontainer.py or devcontainer.template.json.