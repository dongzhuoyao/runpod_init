#!/usr/bin/env bash
set -e

# 1. Prepare .ssh directory
mkdir -p /root/.ssh
chmod 700 /root/.ssh

# 2. Copy the private key
cp /workspace/my_key /root/.ssh/id_rsa
chmod 600 /root/.ssh/id_rsa

# 3. Create SSH config for GitHub
cat > /root/.ssh/config << 'EOF'
Host github.com
    HostName github.com
    User git
    IdentityFile /root/.ssh/id_rsa
    IdentitiesOnly yes
    StrictHostKeyChecking accept-new
EOF

chmod 600 /root/.ssh/config

# 4. Start ssh-agent and add key
eval "$(ssh-agent -s)"
ssh-add /root/.ssh/id_rsa

# 5. Test GitHub SSH connection
ssh -T git@github.com || true
git config --global user.email "taohu620@gmail.com"
git config --global user.name "Tao"

echo "SSH key installed. You can now git clone using SSH."
