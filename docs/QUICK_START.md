# Quick Start: Portable DevContainer

## 🚀 Use This DevContainer in Another Project

### Option 1: Git Submodule (Recommended)

```bash
# Navigate to your project
cd /path/to/your/project

# Add devcontainer as submodule
git submodule add https://github.com/diamondlabs/diamonds-monitor-dev.git .devcontainer

# Or if using SSH
git submodule add git@github.com:diamondlabs/diamonds-monitor-dev.git .devcontainer

# Configure workspace name
cp .devcontainer/.env.example .devcontainer/.env
nano .devcontainer/.env  # Set WORKSPACE_NAME=your_project_name

# Commit the submodule
git add .gitmodules .devcontainer
git commit -m "Add devcontainer as submodule"

# Open in VS Code
code .
```

### Option 2: Direct Copy

```bash
# Copy devcontainer to your project
cp -r /path/to/diamonds-dev-env/.devcontainer /path/to/your/project/

# Configure workspace name
cd /path/to/your/project
echo "WORKSPACE_NAME=your_project_name" > .devcontainer/.env

# Open in VS Code
code .
```

## ⚙️ Configuration

### Required: Set Workspace Name

Edit `.devcontainer/.env`:

```bash
# Use underscores, not hyphens!
WORKSPACE_NAME=your_project_name
```

### Examples

| Your Project | WORKSPACE_NAME |
|-------------|----------------|
| my-awesome-dapp | `my_awesome_dapp` |
| nft-marketplace | `nft_marketplace` |
| defi-protocol | `defi_protocol` |

## 🎯 Opening the Container

1. Open your project in VS Code
2. When prompted: Click **"Reopen in Container"**
3. Or use Command Palette (`Ctrl+Shift+P`):
   - Type: "Dev Containers: Reopen in Container"
   - Press Enter

## 🔧 Updating Submodule

If using as a submodule, update to latest version:

```bash
cd .devcontainer
git pull origin main
cd ..
git add .devcontainer
git commit -m "Update devcontainer to latest version"
```

## 📝 Important Notes

- **Always use underscores** in `WORKSPACE_NAME`, not hyphens
- The `.env` file is project-specific (not committed to submodule)
- Each project gets isolated Docker networks and volumes
- Don't modify files in `.devcontainer/` if using as submodule

## 🐛 Troubleshooting

### Container won't build?

```bash
# Check environment file exists
ls .devcontainer/.env

# Rebuild without cache
docker-compose -f .devcontainer/docker-compose.yml build --no-cache
```

### Wrong workspace path?

```bash
# Verify WORKSPACE_NAME in .env
cat .devcontainer/.env

# Should show: WORKSPACE_NAME=your_project_name
```

### Network issues?

```bash
# List Docker networks
docker network ls

# Remove old network if conflicts
docker network rm old_network_name
```

## 📚 Full Documentation

- [Complete Setup Guide](./README.md)
- [Portability Details](./PORTABILITY.md)
- [Verification Status](./VERIFICATION.md)

---

**That's it! Happy coding! 🎉**
