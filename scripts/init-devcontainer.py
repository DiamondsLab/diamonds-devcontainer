#!/usr/bin/env python3
"""
Diamonds DevContainer Initialization Script
Generates devcontainer.json from template using values from .env file

This script runs on the HOST machine before the DevContainer starts.
It ensures WORKSPACE_NAME and other variables are properly configured.
"""

import os
import sys
import json
from pathlib import Path
from typing import Dict, Optional

class Colors:
    """ANSI color codes for terminal output"""
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    RED = '\033[0;31m'
    NC = '\033[0m'  # No Color

def log(message: str, color: str = Colors.NC):
    """Print colored log message"""
    print(f"{color}{message}{Colors.NC}")

def load_env_file(env_path: Path) -> Dict[str, str]:
    """
    Load environment variables from .env file
    
    Args:
        env_path: Path to .env file
        
    Returns:
        Dictionary of environment variables
    """
    env_vars = {}
    
    if not env_path.exists():
        log(f"Warning: .env file not found at {env_path}", Colors.YELLOW)
        log("Creating default .env file...", Colors.BLUE)
        create_default_env(env_path)
        
    try:
        with open(env_path, 'r', encoding='utf-8') as f:
            for line_num, line in enumerate(f, 1):
                line = line.strip()
                
                # Skip empty lines and comments
                if not line or line.startswith('#'):
                    continue
                    
                # Parse key=value
                if '=' in line:
                    key, value = line.split('=', 1)
                    key = key.strip()
                    value = value.strip()
                    
                    # Remove quotes if present
                    if value.startswith('"') and value.endswith('"'):
                        value = value[1:-1]
                    elif value.startswith("'") and value.endswith("'"):
                        value = value[1:-1]
                    
                    env_vars[key] = value
                else:
                    log(f"Warning: Invalid line {line_num} in .env: {line}", Colors.YELLOW)
                    
    except Exception as e:
        log(f"Error reading .env file: {e}", Colors.RED)
        sys.exit(1)
        
    return env_vars

def create_default_env(env_path: Path):
    """Create a default .env file with standard values"""
    default_content = """# Diamonds DevContainer Configuration
# Generated automatically - customize as needed

# Project Identity
WORKSPACE_NAME=diamonds_project
DIAMOND_NAME=ExampleDiamond

# Vault Configuration
VAULT_COMMAND=server -dev -dev-root-token-id=root -dev-listen-address=0.0.0.0:8200
VAULT_PORT=8200

# Port Mappings
HARDHAT_PORT=8545
ADDITIONAL_BLOCKCHAIN_PORT=8556
FRONTEND_PORT=3001
API_PORT=5001
DOC_PORT=8081
"""
    
    try:
        env_path.parent.mkdir(parents=True, exist_ok=True)
        with open(env_path, 'w', encoding='utf-8') as f:
            f.write(default_content)
        log(f"✓ Created default .env file at {env_path}", Colors.GREEN)
    except Exception as e:
        log(f"Error creating default .env: {e}", Colors.RED)
        sys.exit(1)

def generate_devcontainer(
    template_path: Path,
    output_path: Path,
    env_vars: Dict[str, str]
) -> None:
    """
    Generate devcontainer.json from template
    
    Args:
        template_path: Path to devcontainer.template.json
        output_path: Path where devcontainer.json will be written
        env_vars: Dictionary of environment variables to substitute
    """
    # Get values with defaults
    workspace_name = env_vars.get('WORKSPACE_NAME', 'diamonds_project')
    diamond_name = env_vars.get('DIAMOND_NAME', 'ExampleDiamond')
    
    # Validate workspace name (must be valid for Docker)
    if not workspace_name.replace('_', '').replace('-', '').isalnum():
        log(f"Error: Invalid WORKSPACE_NAME '{workspace_name}'", Colors.RED)
        log("WORKSPACE_NAME must contain only letters, numbers, underscores, and hyphens", Colors.YELLOW)
        sys.exit(1)
    
    if not template_path.exists():
        log(f"Error: Template file not found at {template_path}", Colors.RED)
        log("Please ensure devcontainer.template.json exists", Colors.YELLOW)
        sys.exit(1)
    
    try:
        # Read template
        with open(template_path, 'r', encoding='utf-8') as f:
            template = f.read()
        
        # Replace placeholders
        output = template
        output = output.replace('__WORKSPACE_NAME__', workspace_name)
        output = output.replace('__DIAMOND_NAME__', diamond_name)
        
        # Validate JSON
        try:
            json.loads(output)
        except json.JSONDecodeError as e:
            log(f"Error: Generated JSON is invalid: {e}", Colors.RED)
            sys.exit(1)
        
        # Write output
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(output)
        
        log(f"✓ Generated devcontainer.json", Colors.GREEN)
        log(f"  WORKSPACE_NAME: {Colors.BLUE}{workspace_name}{Colors.NC}")
        log(f"  DIAMOND_NAME: {Colors.BLUE}{diamond_name}{Colors.NC}")
        
    except Exception as e:
        log(f"Error generating devcontainer.json: {e}", Colors.RED)
        sys.exit(1)
    
    # Also set environment variables for current process
    # This makes them available to VS Code via ${localEnv:WORKSPACE_NAME}
    os.environ['WORKSPACE_NAME'] = workspace_name
    os.environ['DIAMOND_NAME'] = diamond_name
    
    # Export all other variables from .env as well
    for key, value in env_vars.items():
        os.environ[key] = value

def verify_generated_config(output_path: Path) -> bool:
    """
    Verify the generated devcontainer.json is valid
    
    Args:
        output_path: Path to generated devcontainer.json
        
    Returns:
        True if valid, False otherwise
    """
    try:
        with open(output_path, 'r', encoding='utf-8') as f:
            config = json.load(f)
        
        # Check required fields
        required_fields = ['name', 'dockerComposeFile', 'service', 'workspaceFolder']
        for field in required_fields:
            if field not in config:
                log(f"Warning: Missing required field '{field}' in generated config", Colors.YELLOW)
                return False
        
        return True
        
    except Exception as e:
        log(f"Error verifying generated config: {e}", Colors.RED)
        return False

def main():
    """Main entry point"""
    # Determine paths
    script_dir = Path(__file__).parent.resolve()
    devcontainer_dir = script_dir.parent
    
    env_path = devcontainer_dir / '.env'
    template_path = devcontainer_dir / 'devcontainer.template.json'
    output_path = devcontainer_dir / 'devcontainer.json'
    
    log("=" * 60, Colors.BLUE)
    log("Diamonds DevContainer Initialization", Colors.BLUE)
    log("=" * 60, Colors.BLUE)
    log("")
    
    # Load environment variables
    log("Loading environment variables from .env...", Colors.BLUE)
    env_vars = load_env_file(env_path)
    log(f"✓ Loaded {len(env_vars)} variables", Colors.GREEN)
    log("")
    
    # Generate devcontainer.json
    log("Generating devcontainer.json from template...", Colors.BLUE)
    generate_devcontainer(template_path, output_path, env_vars)
    log("")
    
    # Verify generated config
    log("Verifying generated configuration...", Colors.BLUE)
    if verify_generated_config(output_path):
        log("✓ Configuration is valid", Colors.GREEN)
    else:
        log("⚠ Configuration may have issues", Colors.YELLOW)
    log("")
    
    log("=" * 60, Colors.GREEN)
    log("Initialization complete!", Colors.GREEN)
    log("=" * 60, Colors.GREEN)
    log("")
    log("The DevContainer will now start with your configured settings.", Colors.BLUE)
    log("")

if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        log("\n\nOperation cancelled by user", Colors.YELLOW)
        sys.exit(1)
    except Exception as e:
        log(f"\n\nUnexpected error: {e}", Colors.RED)
        import traceback
        traceback.print_exc()
        sys.exit(1)