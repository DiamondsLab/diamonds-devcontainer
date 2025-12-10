# syntax=docker/dockerfile:1.6

###
### Medusa build process
###
FROM golang:1.25 AS medusa

WORKDIR /src
RUN git clone https://github.com/crytic/medusa.git
RUN cd medusa && \
    export LATEST_TAG="$(git describe --tags | sed 's/-[0-9]\+-g\w\+$//')" && \
    git checkout "$LATEST_TAG" && \
    go build -trimpath -o=/usr/local/bin/medusa -ldflags="-s -w" && \
    chmod 755 /usr/local/bin/medusa


###
### Echidna "build process"
###
FROM ghcr.io/crytic/echidna/echidna:latest AS echidna
RUN chmod 755 /usr/local/bin/echidna


###
### Diamonds DevContainer - Main Stage
###
# Diamonds DevContainer Dockerfile
# Optimized for security, performance, and Diamond Proxy development
# Security approach: Node.js slim image (minimal attack surface), automatic security updates, pipx for Python tools
# Note: Any remaining vulnerabilities are in the Node.js runtime itself, maintained by the Node.js project

# Use Node.js LTS slim image for better security (fewer packages = fewer vulnerabilities)
FROM node:22-slim

# Build arguments
ARG NODE_VERSION=22
ARG PYTHON_VERSION=3.11
ARG GO_VERSION=1.24.7
ARG WORKSPACE_NAME

# Note: DIAMOND_NAME is NOT a build arg because it's only used at runtime
# It's available via containerEnv and .env file when the container runs

# Environment variables for better Docker behavior
ENV DEBIAN_FRONTEND=noninteractive \
  PYTHONUNBUFFERED=1 \
  PIP_DISABLE_PIP_VERSION_CHECK=1 \
  NODE_ENV=development \
  YARN_CACHE_FOLDER=/home/node/.yarn/cache \
  PATH="/home/node/.local/bin:/home/node/.npm-global/bin:/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/node/go/bin" \
  WORKSPACE_FOLDER=/workspaces/${WORKSPACE_NAME} \
  QEMU_LD_PREFIX=/usr/x86_64-linux-gnu

# Install system dependencies in a single layer for better caching
# First update package lists and apply security updates
RUN apt-get update && apt-get upgrade -y && apt-get install -y --no-install-recommends \
  # Basic system utilities (needed for slim image)
  ca-certificates \
  curl \
  wget \
  gnupg \
  # Build tools
  build-essential \
  cmake \
  pkg-config \
  # Development tools
  git \
  bash-completion \
  jq \
  lsb-release \
  software-properties-common \
  # Python development
  python3-pip \
  python3-dev \
  python3-setuptools \
  python3-wheel \
  pipx \
  # Security tools dependencies
  libssl-dev \
  libffi-dev \
  libxml2-dev \
  libxslt-dev \
  libyaml-dev \
  # Git and version control
  git-lfs \
  # Compression tools
  unzip \
  xz-utils \
  # Text processing
  grep \
  sed \
  gawk \
  # Network tools
  netcat-openbsd \
  dnsutils \
  openssh-client \
  # Process monitoring
  htop \
  procps \
  # File system tools
  tree \
  findutils \
  # Additional useful tools
  vim \
  less \
  man \
  # Clean up
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* \
  && apt-get autoremove -y

# Create workspace directory as root before switching to node user
RUN mkdir -p /workspaces/${WORKSPACE_NAME} && chown -R node:node /workspaces/${WORKSPACE_NAME}

# Enable Corepack to manage Yarn version specified in package.json (must run as root)
RUN corepack enable

# Install Go
RUN curl -fsSL https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz -o /tmp/go.tar.gz \
  && tar -C /usr/local -xzf /tmp/go.tar.gz \
  && rm /tmp/go.tar.gz

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
  && apt-get update \
  && apt-get install -y gh \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# Install HashiCorp Vault CLI for secret management
RUN set -ex \
  && apt-get remove -y vault 2>/dev/null || true \
  && rm -f /usr/bin/vault 2>/dev/null || true \
  && VAULT_VERSION=$(curl -s https://api.github.com/repos/hashicorp/vault/releases/latest | jq -r '.tag_name' | sed 's/^v//') \
  && wget -qO /tmp/vault.zip https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip \
  && unzip /tmp/vault.zip -d /usr/local/bin \
  && chmod +x /usr/local/bin/vault \
  && chown root:root /usr/local/bin/vault \
  && /usr/local/bin/vault --version \
  && rm /tmp/vault.zip

# Install Docker CLI and Docker Compose for Docker-in-Docker support
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
  && apt-get update \
  && apt-get install -y docker-ce-cli docker-compose-plugin \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# Install git-secrets globally (must run as root)
RUN git clone https://github.com/awslabs/git-secrets.git /tmp/git-secrets \
  && cd /tmp/git-secrets \
  && make install \
  && cd / \
  && rm -rf /tmp/git-secrets

# Add cross-architecture support for ARM64/M1 Macs (improve compatibility with amd64 solc)
RUN if [ ! "$(uname -m)" = "x86_64" ]; then \
    export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get install -y --no-install-recommends libc6-amd64-cross \
    && rm -rf /var/lib/apt/lists/*; fi

# Copy Medusa and Echidna binaries from build stages (must run as root)
COPY --chown=root:root --from=medusa /usr/local/bin/medusa /usr/local/bin/medusa
COPY --chown=root:root --from=echidna /usr/local/bin/echidna /usr/local/bin/echidna

# Configure Medusa bash completion (must run as root)
RUN medusa completion bash > /etc/bash_completion.d/medusa

# Switch to non-root user (already created by base Node.js image)
USER node
WORKDIR /home/node

# Create .yarn directory structure with correct permissions before volume mount
RUN mkdir -p /home/node/.yarn/cache && \
    mkdir -p /home/node/.yarn/berry && \
    mkdir -p /home/node/.yarn/install-state

# Install Python security tools using pipx
RUN pipx install slither-analyzer \
  && pipx install semgrep \
  && pipx install trufflehog \
  && pipx ensurepath \
  && export PATH="$PATH:/home/node/.local/bin"

# Install additional security tools using pipx
RUN pipx install bandit \
  && pipx install safety \
  && pipx install pip-audit

# Install Trail of Bits Python security tools using pipx
RUN pipx install pyevmasm \
  && pipx install crytic-compile

# Install Vyper compiler in virtual environment
RUN python3 -m venv ${HOME}/.vyper && \
    ${HOME}/.vyper/bin/pip3 install --no-cache-dir vyper && \
    echo '\nexport PATH=${PATH}:${HOME}/.vyper/bin' >> /home/node/.bashrc

# OSV-Scanner will be installed via post-create scripts after Go is available

# Install Foundry (optional advanced testing - non-fatal on network issues)
RUN curl -L https://foundry.paradigm.xyz | bash \
  && /home/node/.foundry/bin/foundryup \
  && chmod +x /home/node/.foundry/bin/* || true

# Set up global npm packages (security tools)
# Note: @openzeppelin/cli removed as it's deprecated; use @openzeppelin/hardhat-upgrades in project dependencies instead
RUN npm config set prefix /home/node/.npm-global \
  && export PATH="/home/node/.npm-global/bin:$PATH" \
  && npm install -g semver \
  && npm install -g \
  snyk \
  @socketsecurity/cli \
  ganache \
  hardhat-shorthand

# Workspace directory already created above, just set workdir
WORKDIR /workspaces/${WORKSPACE_NAME}

# Copy package files for dependency installation optimization
COPY --chown=node:node package.json ./

# Configure Yarn for better performance (using project-specified version via Corepack)
RUN yarn config set cacheFolder /home/node/.yarn/cache && \
    yarn config set globalFolder /tmp/yarn-global

# Pre-install dependencies (will be overridden by post-create script)
# Note: No yarn.lock file in repo, so installation will resolve latest compatible versions
RUN yarn install --prefer-offline || true

# Copy security configuration files if they exist (configuration can also be done via post-create scripts)
# .semgrep.yml, slither.config.json, .gitsecretsignore will be available via workspace mount

# Configure git-secrets with blockchain-specific patterns
RUN git config --global secrets.patterns "0x[a-fA-F0-9]{64}" \
  && git config --global secrets.patterns "mnemonic.*[a-z]{3,}\s+[a-z]{3,}" \
  && git config --global secrets.patterns "INFURA_API_KEY|ALCHEMY_API_KEY|ETHERSCAN_API_KEY" \
  && git config --global secrets.patterns "PRIVATE_KEY\s*=\s*[\"']*0x[a-fA-F0-9]{64}[\"']*" \
  && git config --global secrets.patterns "SECRET_KEY\s*=\s*[\"']*[a-zA-Z0-9]{32,}[\"']*" \
  && git config --global secrets.allowed "0x0000000000000000000000000000000000000000"

# Create cache directories for performance
RUN mkdir -p \
  /workspaces/${WORKSPACE_NAME}/node_modules \
  /workspaces/${WORKSPACE_NAME}/artifacts \
  /workspaces/${WORKSPACE_NAME}/cache \
  /workspaces/${WORKSPACE_NAME}/diamond-abi \
  /workspaces/${WORKSPACE_NAME}/diamond-typechain-types \
  /workspaces/${WORKSPACE_NAME}/typechain-types \
  /workspaces/${WORKSPACE_NAME}/reports \
  /workspaces/${WORKSPACE_NAME}/logs

# Set proper permissions
RUN chown -R node:node /workspaces/${WORKSPACE_NAME}  

# Set aliases for convenience (can be overridden in shell)
RUN echo "alias ll='ls -alFh'" >> /home/node/.bashrc && \
  echo "alias la='ls -A'" >> /home/node/.bashrc && \
  echo "alias l='ls -CF'" >> /home/node/.bashrc

# Enable bash completion including git-completion
RUN echo "" >> /home/node/.bashrc && \
  echo "# Enable bash completion" >> /home/node/.bashrc && \
  echo "if [ -f /etc/bash_completion ]; then" >> /home/node/.bashrc && \
  echo "  . /etc/bash_completion" >> /home/node/.bashrc && \
  echo "fi" >> /home/node/.bashrc

# Set custom PS1 prompt to show only current directory name
RUN echo "" >> /home/node/.bashrc && \
  echo "# Custom prompt - show only current directory name" >> /home/node/.bashrc && \
  echo 'export PS1="\[\033[01;32m\]\W\[\033[00m\] $ "' >> /home/node/.bashrc

# Add health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD node --version && yarn --version && python3 --version && go version

# Security note: Post-create scripts will perform additional security validation and tool setup

# Expose ports for development
EXPOSE 8545 8546 3000 5000 8080

# Default command
CMD ["sleep", "infinity"]