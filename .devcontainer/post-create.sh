#!/bin/bash
set -e

echo "Running post-create setup..."

# Check Maven installation
mvn -v || true

# Add SSH setup to bashrc for persistent sessions
echo "Setting up SSH agent for future shell sessions..."
cat >> ~/.bashrc << 'EOF'

# SSH Agent setup for dev container
if [ -z "$SSH_AUTH_SOCK" ]; then
    eval $(ssh-agent -s) > /dev/null
fi

# Load SSH keys if they exist
if [ -d ~/.ssh ]; then
    ssh-add ~/.ssh/github ~/.ssh/ancora ~/.ssh/azure_devops 2>/dev/null || true
fi
EOF

echo "Post-create setup completed successfully!"
