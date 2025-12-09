# Snyk Authentication in DevContainers

## The Problem

When running `snyk auth` in a devcontainer, the OAuth callback URL (`http://127.0.0.1:8080`) points to the container's localhost, not your host machine's browser. This causes authentication to fail.

## The Solution: Token-Based Authentication

Use Snyk's token-based authentication instead of OAuth.

### Quick Start

1. **Get Your Token**
   - Visit: https://app.snyk.io/account
   - Navigate to "General" → "Auth Token"
   - Click "Show" and copy your token
   - Or click "Generate" to create a new token

2. **Authenticate**

   Choose one of these methods:

   **Method A: Direct Authentication (Quick)**
   ```bash
   snyk auth <your-token>
   ```

   **Method B: Environment Variable (Recommended for Persistence)**
   ```bash
   # Add to your .env file
   echo "SNYK_TOKEN=your_actual_token_here" >> .env
   
   # Export for current session
   export SNYK_TOKEN=your_actual_token_here
   
   # Verify it's set
   echo $SNYK_TOKEN
   ```

   **Method C: Add to .bashrc (Permanent for User)**
   ```bash
   echo 'export SNYK_TOKEN=your_actual_token_here' >> ~/.bashrc
   source ~/.bashrc
   ```

3. **Verify Authentication**
   ```bash
   # Check who you're authenticated as
   snyk whoami
   
   # Test with a simple scan
   snyk test --help
   ```

### Running Snyk Scans

Once authenticated, you can use all Snyk commands:

```bash
# Test all projects
yarn snyk:test

# Or run directly
snyk test

# Test with severity threshold
snyk test --severity-threshold=high

# Monitor project (save results to Snyk dashboard)
snyk monitor

# Test Docker images
snyk container test <image-name>

# Test infrastructure as code
snyk iac test
```

### Troubleshooting

#### Issue: "Not authenticated" error
```bash
# Check if token is set
echo $SNYK_TOKEN

# If empty, set it
export SNYK_TOKEN=your_actual_token_here

# Verify
snyk whoami
```

#### Issue: Token not persisting across sessions
Add the token to your `.env` file:

```bash
# In your .env file
SNYK_TOKEN=your_actual_token_here
```

Then ensure the devcontainer loads it:
```bash
# Check if .env is being sourced
cat ~/.bashrc | grep -i env
```

#### Issue: "Invalid token" error
- Token may have expired
- Generate a new token at https://app.snyk.io/account
- Re-authenticate with the new token

### Security Best Practices

1. **Never commit tokens to git**
   - `.env` is already in `.gitignore`
   - Use git-secrets to prevent accidental commits

2. **Use service accounts for CI/CD**
   - For GitHub Actions, use repository secrets
   - For local development, use personal tokens

3. **Rotate tokens periodically**
   - Generate new tokens every 90 days
   - Revoke old tokens after rotation

### Integration with Vault (Optional)

If you're using HashiCorp Vault for secret management:

```bash
# Store token in Vault
vault kv put secret/dev/SNYK_TOKEN value=your_actual_token_here

# Fetch from Vault (if configured)
source .devcontainer/scripts/vault-fetch-secrets.sh
```

### Alternative: Manual OAuth (Advanced)

If you absolutely need to use OAuth:

1. Run `snyk auth` and copy the full OAuth URL
2. Open the URL in your **host** browser (not container)
3. Complete authentication
4. The callback will fail, but check for the auth code in the URL
5. Manually complete authentication (complex, not recommended)

**Note:** Token-based authentication is much simpler and recommended.

### Resources

- [Snyk CLI Documentation](https://docs.snyk.io/snyk-cli)
- [Snyk Authentication](https://docs.snyk.io/snyk-cli/authenticate-the-cli-with-your-account)
- [Token Management](https://docs.snyk.io/snyk-admin/manage-users-and-permissions/api-token-permissions)

### Summary

**TL;DR:**
1. Get token from https://app.snyk.io/account
2. Run: `snyk auth <token>` or `export SNYK_TOKEN=<token>`
3. Add to `.env` for persistence
4. Verify with: `snyk whoami`
