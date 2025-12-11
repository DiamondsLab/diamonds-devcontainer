# Diamonds DevContainer

A comprehensive, reproducible development environment for the Diamonds Ethereum smart contract project using ERC-2535 Diamond Proxy Standard.

## 🚀 Quick Start

### Prerequisites

- **Docker**: Version 20.10+ with Docker Compose
- **VS Code**: Version 1.70+ with Dev Containers extension
- **Git**: Version 2.30+

### First-Time Setup

1. **Clone the repository**:

   ```bash
   git clone https://github.com/<git-org-name>/<git-repo-name>.git
   cd <git-repo-name>
   ```

2. **Open in VS Code**:

   ```bash
   code .
   ```

3. **Reopen in DevContainer**:
   - When prompted, click "Reopen in Container"
   - Or use Command Palette: `Dev Containers: Reopen in Container`

4. **Initial setup** (runs automatically):
   - Dependencies installation
   - TypeScript/Solidity compilation
   - Security tools configuration
   - TypeChain types generation

## 📋 What's Included

### Core Technologies

- **Node.js 20** with Yarn 4.x
- **TypeScript** with strict configuration
- **Solidity ^0.8.19** with Hardhat
- **ERC-2535 Diamond Proxy** architecture

### Development Tools

- **Hardhat** - Ethereum development framework
- **TypeChain** - Type-safe contract interactions
- **Diamond Proxy Tools** - ERC-2535 utilities
- **Multi-chain Testing** - Cross-network fork testing

### Security Tools

- **Semgrep** - Code security scanning
- **Slither** - Solidity smart contract analysis
- **Snyk** - Dependency vulnerability scanning
- **Socket.dev** - Supply chain security
- **OSV-Scanner** - Known vulnerability database
- **git-secrets** - Secret detection and prevention

### VS Code Extensions

- Solidity support (JuanBlanco.solidity, NomicFoundation.hardhat-solidity)
- TypeScript/JavaScript (ms-vscode.vscode-typescript-next)
- ESLint/Prettier integration
- Git/GitHub integration
- Docker support
- Security tools

## 🛠️ Available Commands

### Development Workflow

```bash
# Install dependencies
yarn install

# Compile contracts and generate types
yarn compile

# Run test suite
yarn test

# Run security scans
yarn security-check

# Start local blockchain
npx hardhat node

# Deploy to local network
npx hardhat run scripts/deploy/local.ts
```

### Security & Quality

```bash
# Run all security tools
yarn security-check

# Individual security scans
yarn audit              # Dependency audit
yarn semgrep:scan       # Code security
yarn slither:scan       # Contract analysis
yarn snyk:test          # Vulnerability scan

# Code quality
yarn lint               # ESLint
yarn format             # Prettier
```

### Diamond Proxy Development

```bash
# Generate diamond ABI and types
npx hardhat diamond:generate-abi-typechain --diamond-name <DIAMOND_NAME>

# Deploy diamond
npx hardhat run scripts/deploy/diamond.ts

# Add facet to diamond
npx hardhat run scripts/facets/addFacet.ts

# Upgrade diamond
npx hardhat run scripts/upgrade/diamond.ts
```

### Multi-Chain Testing

```bash
# Test on multiple networks
yarn test:multichain --chains hardhat,sepolia,polygon

# Fork mainnet for testing
npx hardhat node --fork https://mainnet.infura.io/v3/YOUR_KEY

# Test specific network
npx hardhat test --network sepolia
```

## 🔧 Configuration

### Environment Variables

Copy `.devcontainer/.env.example` to `.env` and configure:

```bash
# Network RPC URLs
MAINNET_RPC_URL=https://mainnet.infura.io/v3/YOUR_KEY
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_KEY

# API Keys
INFURA_PROJECT_ID=your_infura_project_id
ETHERSCAN_API_KEY=your_etherscan_key
SNYK_TOKEN=your_snyk_token

# Development settings
NODE_ENV=development
HARDHAT_NETWORK=hardhat
```

### VS Code Settings

The DevContainer includes optimized settings for:

- Solidity development with proper compiler version
- TypeScript with strict type checking
- ESLint/Prettier integration
- Git integration with security hooks
- File associations for blockchain files

## 🐳 Docker Services

### Multi-Service Setup

Use Docker Compose for additional services:

```bash
# Start with local Hardhat node
docker-compose up devcontainer hardhat-node

# Start with full stack (database, IPFS, etc.)
docker-compose --profile database --profile ipfs up

# Start with Ganache instead of Hardhat
docker-compose --profile ganache up
```

### Available Services

- **devcontainer**: Main development environment
- **hardhat-node**: Local Hardhat blockchain network
- **ganache-node**: Alternative local blockchain (profile: ganache)
- **ipfs-node**: IPFS decentralized storage (profile: ipfs)
- **postgres-db**: PostgreSQL database (profile: database)
- **redis-cache**: Redis caching (profile: cache)
- **graph-node**: The Graph indexing (profile: graph)

## 🔒 Security Features

### Git-Secrets Integration

Automatically prevents committing sensitive data:

```bash
# Scan repository for secrets
git secrets --scan

# Add custom patterns
git secrets --add 'PRIVATE_KEY\s*=\s*["'\'']*0x[a-fA-F0-9]{64}["'\'']*'
```

### Security Scanning Pipeline

```bash
# Run complete security audit
yarn security-check

# Results include:
# - Dependency vulnerabilities (Snyk)
# - Code security issues (Semgrep)
# - Contract vulnerabilities (Slither)
# - Supply chain risks (Socket.dev)
# - Known vulnerabilities (OSV-Scanner)
```

### Authentication Setup

#### Snyk Authentication (Token-Based)

OAuth flow doesn't work in devcontainers. Use token-based authentication:

```bash
# Option 1: Direct authentication with token
# Get your token from: https://app.snyk.io/account
snyk auth <your-token>

# Option 2: Environment variable (recommended for persistence)
export SNYK_TOKEN=<your-token>

# Add to .env file for automatic loading
echo "SNYK_TOKEN=your_snyk_token" >> .env

# Verify authentication
snyk whoami
```

#### Socket.dev Setup

```bash
export SOCKET_CLI_API_TOKEN=your_token
```

## 🚢 GitHub Actions Parity

The DevContainer environment exactly matches GitHub Actions CI/CD:

```bash
# Validate environment parity
.devcontainer/scripts/github-actions-setup.sh

# Run CI simulation
yarn install --frozen-lockfile
yarn build
yarn test
yarn security-check
```

### CI/CD Environment Features

- Identical Node.js/Yarn versions
- Same security tool versions
- Matching cache directories
- Production-like settings
- Frozen lockfile installations

## 🔍 Troubleshooting

### Common Issues

#### Container Won't Start

```bash
# Check Docker resources
docker system info

# Clean up and rebuild
docker system prune -a
docker volume prune
```

#### Dependencies Installation Fails

```bash
# Clear caches
rm -rf node_modules .yarn/cache
yarn cache clean

# Reinstall
yarn install --frozen-lockfile
```

#### Compilation Errors

```bash
# Clean and recompile
yarn clean
yarn compile

# Check Solidity version
npx hardhat --version
```

#### Security Tools Not Working

```bash
# Re-run security setup
.devcontainer/scripts/setup-security.sh

# Check tool versions
semgrep --version
slither --version
```

#### Port Conflicts

```bash
# Check port usage
lsof -i :8545

# Change ports in docker-compose.yml or configure in .env
ports:
  - "8547:8545"  # Map host 8547 to container 8545
```

#### Git-Secrets Issues

```bash
# Reinstall git hooks
git secrets --install

# Clear secrets cache
rm -rf .git/git-secrets
```

### Performance Issues

#### Slow Container Startup

- Increase Docker memory allocation (4GB+ recommended)
- Use volume mounts for better I/O performance
- Enable Docker BuildKit: `export DOCKER_BUILDKIT=1`

#### Slow Compilation

```bash
# Enable Hardhat cache
export HARDHAT_CACHE_DIR=./cache

# Use parallel compilation
npx hardhat compile --parallel
```

### Network Issues

#### RPC Connection Problems

```bash
# Test network connectivity
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  http://localhost:${HARDHAT_PORT:-8545}
```

#### Infura/Alchemy Issues

- Check API key validity
- Verify network endpoints
- Check rate limits

## 🏗️ Diamond Proxy Development

### Architecture Overview

Diamonds uses ERC-2535 Diamond Proxy Standard for upgradeable contracts:

```
Diamond (Proxy)
├── Facet A (Access Control)
├── Facet B (Treasury)
├── Facet C (Governance)
└── Facet D (Member Management)
```

### Development Workflow

1. **Create Facet**:

   ```solidity
   contract DiamondAccessControlFacet {
       // Facet logic here
   }
   ```

2. **Add to Diamond**:

   ```typescript
   await diamondCut.facetCuts([
     {
       facetAddress: accessControlFacet.address,
       action: FacetCutAction.Add,
       functionSelectors: getSelectors(accessControlFacet),
     },
   ]);
   ```

3. **Generate Types**:
   ```bash
   npx hardhat diamond:generate-abi-typechain --diamond-name <DIAMOND_NAME>
   ```

### Best Practices

- Use `LibDiamond` for standard diamond operations
- Implement proper storage patterns
- Test facet isolation thoroughly
- Validate upgrade compatibility
- Monitor gas usage for diamond cuts

## 🔗 Multi-Chain Development

### Supported Networks

- **Ethereum Mainnet**
- **Sepolia Testnet**
- **Polygon Mainnet/Mumbai**
- **Arbitrum One/Sepolia**
- **Base Mainnet/Sepolia**

### Fork Testing

```bash
# Fork mainnet for testing
npx hardhat node --fork https://mainnet.infura.io/v3/YOUR_KEY

# Run tests against fork
npx hardhat test --network hardhat
```

### Deployment Scripts

```bash
# Deploy to testnet
npx hardhat run scripts/deploy/ --network sepolia

# Verify contracts
npx hardhat verify --network sepolia CONTRACT_ADDRESS
```

## 📊 Monitoring & Health Checks

### Container Health

```bash
# Check container status
docker ps

# View logs
docker-compose logs devcontainer

# Health check
curl http://localhost:8545 \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

### Performance Monitoring

```bash
# Monitor resource usage
docker stats

# Check disk usage
docker system df

# Clean up
docker system prune
```

## 🤝 Contributing

### Development Standards

1. **Security First**: All changes must pass security scans
2. **Test Coverage**: Maintain 90%+ test coverage
3. **Code Quality**: Follow ESLint/Prettier rules
4. **Documentation**: Update docs for API changes

### Pull Request Process

1. Create feature branch
2. Run full test suite: `yarn test`
3. Run security checks: `yarn security-check`
4. Update documentation
5. Create PR with detailed description

## 📚 Additional Resources

### Documentation

- [Hardhat Documentation](https://hardhat.org/docs)
- [ERC-2535 Diamond Standard](https://eips.ethereum.org/EIPS/eip-2535)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts)
- [Solidity Documentation](https://docs.soliditylang.org)

### Security Resources

- [Consensys Smart Contract Best Practices](https://consensys.github.io/smart-contract-best-practices/)
- [Slither Documentation](https://github.com/crytic/slither)
- [Semgrep Rules](https://semgrep.dev/docs/writing-rules/overview/)

### Tools

- [Hardhat Network Helpers](https://hardhat.org/hardhat-network-helpers/docs/overview)
- [TypeChain Documentation](https://typechain.org/)
- [Diamond Tools](https://github.com/mudgen/diamond-2-hardhat)

## 🆘 Support

### Getting Help

1. **Check this README** for common issues
2. **Review VS Code output** for error messages
3. **Check container logs**: `docker-compose logs`
4. **Validate environment**: `.devcontainer/scripts/github-actions-setup.sh`

### Reporting Issues

- **Bug Reports**: Create GitHub issue with full error logs
- **Security Issues**: Report via SECURITY.md process
- **Performance Issues**: Include `docker stats` output

## 📄 License

This DevContainer configuration is part of the Diamonds project. See project LICENSE for details.

---

## 🔧 Portable DevContainer Configuration

This DevContainer setup is designed to be portable and reusable across multiple projects. It can be used as a submodule in different repositories.

### Configuration

The devcontainer uses environment variables to make it portable. The main configuration is controlled by the `WORKSPACE_NAME` variable.

#### Setup

1. **Copy the `.env.example` file to `.env`:**
   ```bash
   cp .devcontainer/.env.example .devcontainer/.env
   ```

2. **Edit `.env` and set your workspace name:**
   ```bash
   WORKSPACE_NAME=your-project-name
   ```

   **Important:** Use underscores (`_`) instead of hyphens (`-`) in the workspace name for compatibility with Docker Compose network naming.

#### Environment Variables

- `WORKSPACE_NAME`: The name of your workspace/project. This will be used for:
  - Docker workspace paths (`/workspaces/${WORKSPACE_NAME}`)
  - Docker network naming (`${WORKSPACE_NAME}-network`)
  - Volume mount paths

#### Default Values

If `WORKSPACE_NAME` is not set in the `.env` file, the devcontainer will use the default value: `diamonds-dev-env`

### Using as a Submodule

To use this devcontainer in another project:

1. **Add as a submodule:**
   ```bash
   git submodule add <repository-url> .devcontainer
   ```

2. **Copy the `.env.example` to `.env`:**
   ```bash
   cp .devcontainer/.env.example .devcontainer/.env
   ```

3. **Configure your workspace name:**
   ```bash
   echo "WORKSPACE_NAME=my_new_project" > .devcontainer/.env
   ```

4. **Open in VS Code:**
   - Press `F1` or `Ctrl+Shift+P`
   - Select "Dev Containers: Reopen in Container"

### File Structure

The following files use the `WORKSPACE_NAME` variable:

- **Dockerfile**: Creates workspace directories based on `WORKSPACE_NAME`
- **docker-compose.yml**: Configures volumes, networks, and paths using `WORKSPACE_NAME`
- **devcontainer.json**: Sets workspace folder and mount points using `WORKSPACE_NAME`

### Naming Conventions

#### Workspace Name Format

- **Recommended:** Use underscores (`_`) instead of hyphens (`-`)
  - ✅ Good: `diamonds_dev_env`, `my_project_name`
  - ❌ Avoid: `diamonds-dev-env`, `my-project-name`

This is because Docker Compose has restrictions on network names and will automatically convert hyphens to underscores, which can cause confusion.

#### Examples

| Project Name | WORKSPACE_NAME | Docker Network |
|-------------|----------------|----------------|
| diamonds-dev-env | `diamonds_dev_env` | `diamonds_dev_env-network` |
| diamonds-project | `diamonds_project` | `diamonds_project-network` |
| my-new-project | `my_new_project` | `my_new_project-network` |

## Environment Variables

### Understanding Environment Variable Sources

The DevContainer uses environment variables from three sources:

1. **Host Environment Variables** (build-time) - Set on your host machine, used during container build
2. **Container Environment Variables** (runtime) - Set in `devcontainer.json`, available in running container  
3. **.env File Variables** (application-level) - Used by Hardhat and scripts, loaded at runtime

**See [ENV_VARS.md](./ENV_VARS.md) for detailed documentation.**

### Required Variables

- **WORKSPACE_NAME**: Name of the workspace directory (default: `diamonds_project`)
- **DIAMOND_NAME**: Name of the diamond contract to work with (default: `ExampleDiamond`)

### Setting Environment Variables

#### Option 1: Use Helper Script (Recommended)
```bash
# On your HOST machine (before opening DevContainer)
source .devcontainer/set-host-env.sh
# Then rebuild the container
```

#### Option 2: Manual Export
```bash
# On your HOST machine
export WORKSPACE_NAME=diamonds_dev_env
export DIAMOND_NAME=ExampleDiamond
# Then rebuild the container
```

#### Option 3: Edit .env File
The `.env` file values are used as fallback by scripts:
```bash
WORKSPACE_NAME=diamonds_dev_env
DIAMOND_NAME=ExampleDiamond
```

**Note**: The `.env` file is NOT read during container build, only at runtime.

### Troubleshooting Portable Setup

#### Container fails to build

1. Check that `.env` file exists in `.devcontainer/`
2. Verify `WORKSPACE_NAME` is set and doesn't contain special characters
3. Try rebuilding without cache:
   ```bash
   docker-compose -f .devcontainer/docker-compose.yml build --no-cache
   ```

#### Volume mount issues

1. Ensure the `WORKSPACE_NAME` in `.env` matches your project structure
2. Check Docker has permission to access your workspace folder
3. Verify all required directories exist or will be created by the container

#### Network naming conflicts

If you see network naming errors, ensure `WORKSPACE_NAME` uses underscores instead of hyphens.

### Advanced Configuration

#### Multiple Projects

You can use this devcontainer for multiple projects by:

1. Using different `WORKSPACE_NAME` values for each project
2. Ensuring each project has its own `.env` file in the `.devcontainer` directory
3. Each project will have isolated Docker networks and volumes

#### Contributing to Portable DevContainer

When contributing to this devcontainer setup:

1. Never hardcode project-specific paths
2. Use `${WORKSPACE_NAME}` or `${localEnv:WORKSPACE_NAME:default-value}` for all paths
3. Update this README with any new configuration options
4. Test with different `WORKSPACE_NAME` values to ensure portability

---

**Happy coding! 🚀**

_Built with ❤️ for secure, scalable DeFi development_
