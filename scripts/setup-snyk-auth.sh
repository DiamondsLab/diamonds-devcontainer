#!/bin/bash
# Snyk Authentication Helper for DevContainers
# This script helps set up Snyk authentication in a devcontainer environment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Print header
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}  Snyk Authentication Setup for DevContainers${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check if snyk is installed
if ! command -v snyk &> /dev/null; then
    echo -e "${RED}✗ Snyk CLI is not installed${NC}"
    echo -e "${YELLOW}Installing Snyk CLI...${NC}"
    npm install -g snyk
    echo -e "${GREEN}✓ Snyk CLI installed${NC}"
fi

# Check current authentication status
echo -e "${BLUE}Checking current authentication status...${NC}"
if [ -n "${SNYK_TOKEN:-}" ]; then
    echo -e "${GREEN}✓ SNYK_TOKEN environment variable is set${NC}"
    # Try to get username with experimental flag
    if USER=$(snyk whoami --experimental 2>/dev/null); then
        echo -e "${GREEN}✓ Authenticated as: ${USER}${NC}"
        echo ""
        echo -e "${GREEN}You're all set! You can now use Snyk commands.${NC}"
        exit 0
    elif snyk config get >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Authenticated (token verified)${NC}"
        echo ""
        echo -e "${GREEN}You're all set! You can now use Snyk commands.${NC}"
        exit 0
    fi
elif snyk config get >/dev/null 2>&1; then
    # Try to get username
    if USER=$(snyk whoami --experimental 2>/dev/null); then
        echo -e "${GREEN}✓ Authenticated as: ${USER}${NC}"
    else
        echo -e "${GREEN}✓ Authenticated${NC}"
    fi
    echo ""
    echo -e "${GREEN}You're all set! You can now use Snyk commands.${NC}"
    exit 0
else
    echo -e "${YELLOW}✗ Not authenticated${NC}"
fi

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  OAuth flow doesn't work in devcontainers!${NC}"
echo -e "${YELLOW}  Use token-based authentication instead.${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Provide instructions
echo -e "${BLUE}Step 1: Get Your Snyk Token${NC}"
echo "   Visit: ${CYAN}https://app.snyk.io/account${NC}"
echo "   Navigate to: General → Auth Token"
echo "   Click 'Show' or 'Generate' to get your token"
echo ""

# Ask if user has token
read -p "$(echo -e ${GREEN}'Do you have your Snyk token? (y/n): '${NC})" -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${YELLOW}Please get your token from https://app.snyk.io/account first${NC}"
    echo -e "${BLUE}Then run this script again: ${CYAN}.devcontainer/scripts/setup-snyk-auth.sh${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}Step 2: Enter Your Token${NC}"
read -sp "$(echo -e ${GREEN}'Paste your Snyk token: '${NC})" TOKEN
echo ""

if [ -z "$TOKEN" ]; then
    echo -e "${RED}✗ No token provided${NC}"
    exit 1
fi

# Authenticate with the token
echo ""
echo -e "${BLUE}Authenticating...${NC}"
if snyk auth "$TOKEN" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Authentication successful!${NC}"
else
    echo -e "${RED}✗ Authentication failed${NC}"
    echo -e "${YELLOW}Please verify your token and try again${NC}"
    exit 1
fi

# Ask if user wants to save to .env
echo ""
read -p "$(echo -e ${GREEN}'Save token to .env for persistence? (y/n): '${NC})" -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Check if .env exists
    if [ -f ".env" ]; then
        # Check if SNYK_TOKEN already exists in .env
        if grep -q "^SNYK_TOKEN=" .env; then
            # Update existing entry
            sed -i.bak "s|^SNYK_TOKEN=.*|SNYK_TOKEN=$TOKEN|" .env
            rm -f .env.bak
            echo -e "${GREEN}✓ Updated SNYK_TOKEN in .env${NC}"
        else
            # Add new entry
            echo "" >> .env
            echo "# Snyk Security Token" >> .env
            echo "SNYK_TOKEN=$TOKEN" >> .env
            echo -e "${GREEN}✓ Added SNYK_TOKEN to .env${NC}"
        fi
        
        # Export for current session
        export SNYK_TOKEN="$TOKEN"
        echo -e "${GREEN}✓ Exported SNYK_TOKEN for current session${NC}"
    else
        echo -e "${YELLOW}! .env file not found${NC}"
        read -p "$(echo -e ${GREEN}'Create .env file? (y/n): '${NC})" -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "# Snyk Security Token" > .env
            echo "SNYK_TOKEN=$TOKEN" >> .env
            echo -e "${GREEN}✓ Created .env and added SNYK_TOKEN${NC}"
            export SNYK_TOKEN="$TOKEN"
            echo -e "${GREEN}✓ Exported SNYK_TOKEN for current session${NC}"
        fi
    fi
fi

# Verify authentication
echo ""
echo -e "${BLUE}Verifying authentication...${NC}"
if USER=$(snyk whoami --experimental 2>/dev/null); then
    echo -e "${GREEN}✓ Successfully authenticated as: ${USER}${NC}"
elif snyk config get >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Successfully authenticated (token verified)${NC}"
else
    echo -e "${YELLOW}! Could not verify authentication${NC}"
fi

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Setup Complete!${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}You can now use Snyk commands:${NC}"
echo "  • ${CYAN}snyk test${NC}           - Test for vulnerabilities"
echo "  • ${CYAN}snyk monitor${NC}        - Monitor project continuously"
echo "  • ${CYAN}yarn snyk:test${NC}      - Run configured Snyk test"
echo "  • ${CYAN}snyk whoami${NC}         - Check authentication status"
echo ""
echo -e "${BLUE}Documentation:${NC}"
echo "  ${CYAN}.devcontainer/docs/SNYK_AUTHENTICATION.md${NC}"
echo ""
