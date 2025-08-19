#!/bin/bash
set -e

echo "Running post-start setup..."

# Start SSH agent and load keys immediately
echo "Starting SSH agent and loading keys..."
if [ -z "$SSH_AUTH_SOCK" ]; then
    eval $(ssh-agent -s) > /dev/null
fi

# Load SSH keys
if [ -d ~/.ssh ]; then
    ssh-add ~/.ssh/github ~/.ssh/ancora ~/.ssh/azure_devops 2>/dev/null || true
    echo "SSH keys loaded successfully!"
    
    # Show loaded keys (optional)
    echo "Loaded SSH keys:"
    ssh-add -l 2>/dev/null || echo "No keys loaded"
else
    echo "SSH directory not found"
fi

echo "Post-start setup completed successfully!"
