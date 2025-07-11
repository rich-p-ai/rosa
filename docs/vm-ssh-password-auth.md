# VM SSH Password Authentication Configuration

## Overview

This document provides instructions for customers who need to configure SSH access to their VMs running in ROSA clusters using username/password authentication instead of SSH keys.

## Prerequisites

- ROSA cluster with OpenShift Virtualization enabled
- VM deployed and accessible via NodePort service
- Access to OpenShift console or CLI
- VM console access through OpenShift

## Problem Statement

When connecting to VMs via SSH through AWS Load Balancer and NodePort, you may encounter:
```
admin@rosa-nodeport-xxxx.elb.us-east-1.amazonaws.com: Permission denied (publickey,gssapi-keyex,gssapi-with-mic)
```

This occurs when the VM is configured for SSH key authentication but you want to use password authentication instead.

## Solution: Enable Password Authentication

### Step 1: Access VM Console

1. **Via OpenShift Web Console:**
   - Navigate to: **Virtualization → Virtual Machines**
   - Find your VM (e.g., "test2")
   - Click on the VM name
   - Go to **Console** tab
   - Login with existing credentials

2. **Via OpenShift CLI:**
   ```bash
   # Login to your ROSA cluster
   oc login

   # Find your VM
   oc get vm -A | grep test2

   # Get console access information
   oc describe vm test2
   ```

### Step 2: Configure SSH for Password Authentication

Once you have console access to the VM, run these commands:

```bash
# First, check current SSH configuration
sudo grep -E "^#?PasswordAuthentication|^#?PubkeyAuthentication" /etc/ssh/sshd_config

# Edit SSH configuration
sudo nano /etc/ssh/sshd_config

# For RHEL 9, look for these lines and modify them:
# Find and uncomment/change:
#PasswordAuthentication no
# Change to:
PasswordAuthentication yes

# Find and change:
#PubkeyAuthentication yes  
# Change to:
PubkeyAuthentication no

# Add these lines if they don't exist:
ChallengeResponseAuthentication yes
UsePAM yes

# Optional: Force password authentication only (add this line)
AuthenticationMethods password

# Save the file (Ctrl+X, then Y, then Enter in nano)

# Test configuration syntax before restarting
sudo sshd -t

# Restart SSH service
sudo systemctl restart sshd

# Verify SSH service is running
sudo systemctl status sshd
```

### Step 3: Set User Password

```bash
# Set password for existing admin user
sudo passwd admin

# Or create a new user with password
sudo useradd -m -s /bin/bash myuser
sudo passwd myuser
sudo usermod -aG sudo myuser  # Add to sudo group if needed
```

### Step 4: Test SSH Connection

```bash
# Test SSH with password authentication
ssh admin@rosa-nodeport-ddaa814ca551b53e.elb.us-east-1.amazonaws.com -p 30522

# Force password authentication (ignore SSH keys)
ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no admin@rosa-nodeport-ddaa814ca551b53e.elb.us-east-1.amazonaws.com -p 30522
```

## Permanent Configuration (Recommended)

To ensure these settings persist across VM restarts, update the VM configuration with cloud-init:

### Method 1: Edit Existing VM

```bash
# Edit the VM configuration
oc edit vm test2
```

Add or update the cloud-init section:

```yaml
spec:
  template:
    spec:
      volumes:
      - cloudInitNoCloud:
          userData: |
            #cloud-config
            users:
              - name: admin
                sudo: ALL=(ALL) NOPASSWD:ALL
                lock_passwd: false
                plain_text_passwd: your_secure_password_here
            ssh_pwauth: true
            package_update: true
            runcmd:
              - sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
              - sed -i 's/#PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
              - sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
              - sed -i 's/PubkeyAuthentication yes/PubkeyAuthentication no/' /etc/ssh/sshd_config
              - sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication no/' /etc/ssh/sshd_config
              - echo "ChallengeResponseAuthentication yes" >> /etc/ssh/sshd_config
              - echo "UsePAM yes" >> /etc/ssh/sshd_config
              - sshd -t && systemctl restart sshd
        name: cloudinitdisk
```

### Method 2: New VM Creation Template

If creating a new VM, use this cloud-init configuration:

```yaml
#cloud-config
users:
  - name: admin
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: false
    plain_text_passwd: your_secure_password_here
ssh_pwauth: true
package_update: true
runcmd:
  - sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
  - sed -i 's/#PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
  - sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
  - sed -i 's/PubkeyAuthentication yes/PubkeyAuthentication no/' /etc/ssh/sshd_config
  - sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication no/' /etc/ssh/sshd_config
  - echo "ChallengeResponseAuthentication yes" >> /etc/ssh/sshd_config
  - echo "UsePAM yes" >> /etc/ssh/sshd_config
  - sshd -t && systemctl restart sshd
```

## Troubleshooting

### RHEL 9 Specific Configuration

RHEL 9 has some differences in SSH configuration. If you don't see the expected configuration options:

1. **Check for include files:**
   ```bash
   # RHEL 9 may use additional config files
   sudo ls -la /etc/ssh/sshd_config.d/
   sudo cat /etc/ssh/sshd_config.d/*
   ```

2. **Complete RHEL 9 SSH configuration:**
   ```bash
   # Check current effective configuration
   sudo sshd -T | grep -E "passwordauthentication|pubkeyauthentication"
   
   # Edit main config file
   sudo nano /etc/ssh/sshd_config
   
   # Look for these specific lines and ensure they are set:
   # (Some may be commented out with # - uncomment them)
   
   # Around line 58-65, find and modify:
   #PasswordAuthentication no
   # Change to:
   PasswordAuthentication yes
   
   # Around line 43-50, find and modify:
   #PubkeyAuthentication yes
   # Change to:
   PubkeyAuthentication no
   
   # Add these if not present:
   ChallengeResponseAuthentication yes
   UsePAM yes
   
   # Test and restart
   sudo sshd -t
   sudo systemctl restart sshd
   ```

3. **Alternative: Use sed commands for RHEL 9:**
   ```bash
   # Make backup
   sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
   
   # Apply changes
   sudo sed -i 's/^#PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
   sudo sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
   sudo sed -i 's/^#PubkeyAuthentication yes/PubkeyAuthentication no/' /etc/ssh/sshd_config
   sudo sed -i 's/^PubkeyAuthentication yes/PubkeyAuthentication no/' /etc/ssh/sshd_config
   
   # Add required settings if not present
   grep -q "^ChallengeResponseAuthentication" /etc/ssh/sshd_config || echo "ChallengeResponseAuthentication yes" | sudo tee -a /etc/ssh/sshd_config
   grep -q "^UsePAM" /etc/ssh/sshd_config || echo "UsePAM yes" | sudo tee -a /etc/ssh/sshd_config
   
   # Test and restart
   sudo sshd -t && sudo systemctl restart sshd
   ```

### Connection Still Fails

1. **Check SSH service status:**
   ```bash
   sudo systemctl status sshd
   sudo journalctl -u sshd -f
   ```

2. **Verify SSH configuration:**
   ```bash
   # Check current SSH configuration
   sudo sshd -T | grep -E "(PasswordAuthentication|PubkeyAuthentication)"
   
   # Or check the config file directly
   sudo grep -E "^PasswordAuthentication|^PubkeyAuthentication" /etc/ssh/sshd_config
   
   # For RHEL 9, also check included config files
   sudo grep -r "PasswordAuthentication\|PubkeyAuthentication" /etc/ssh/sshd_config.d/
   ```

3. **Check user account:**
   ```bash
   # Verify user exists and has password set
   sudo getent passwd admin
   sudo passwd -S admin
   ```

### Network Connectivity Issues

1. **Test port connectivity:**
   ```bash
   telnet rosa-nodeport-ddaa814ca551b53e.elb.us-east-1.amazonaws.com 30522
   ```

2. **Check NodePort service:**
   ```bash
   oc get svc -A | grep nodeport
   oc describe svc your-nodeport-service
   ```

3. **Verify VM network configuration:**
   ```bash
   oc get vmi test2 -o yaml | grep -A 10 -B 10 network
   ```

### VM Access Issues

1. **Check VM status:**
   ```bash
   oc get vm test2 -o wide
   oc get vmi test2 -o wide
   ```

2. **Check VM logs:**
   ```bash
   oc logs -f $(oc get pods -l vm.kubevirt.io/name=test2 -o name)
   ```

## Security Considerations

⚠️ **Important Security Notes:**

1. **Password Strength:** Use strong, complex passwords
2. **Access Control:** Consider restricting SSH access by IP address if possible
3. **Monitoring:** Monitor login attempts and failed authentication
4. **Fail2ban:** Consider installing fail2ban for brute force protection:
   ```bash
   sudo dnf install fail2ban -y  # For RHEL/CentOS
   sudo apt install fail2ban -y  # For Ubuntu/Debian
   sudo systemctl enable --now fail2ban
   ```

## Alternative: SSH Key + Password Fallback

If you want to allow both SSH keys and password authentication:

```bash
# Edit SSH configuration
sudo nano /etc/ssh/sshd_config

# Set these values:
PasswordAuthentication yes
PubkeyAuthentication yes
AuthenticationMethods publickey,password

# Restart SSH
sudo systemctl restart sshd
```

## Quick Reference Commands

```bash
# Check VM status
oc get vm test2 -o wide

# Access VM console
oc get vm test2 -o yaml | grep -A 5 console

# Test SSH connection
ssh -o PreferredAuthentications=password admin@your-loadbalancer:30522

# Check SSH service in VM
sudo systemctl status sshd

# View SSH configuration (RHEL 9)
sudo cat /etc/ssh/sshd_config | grep -E "(Password|Pubkey)Authentication"
sudo sshd -T | grep -E "passwordauthentication|pubkeyauthentication"

# Monitor SSH logs
sudo journalctl -u sshd -f

# Quick RHEL 9 SSH config check
sudo grep -n -E "^#?PasswordAuthentication|^#?PubkeyAuthentication" /etc/ssh/sshd_config
```

## Common RHEL 9 SSH Configuration Lines

When editing `/etc/ssh/sshd_config` in RHEL 9, look for these specific lines:

```bash
# Around line 43 (may be commented with #):
#PubkeyAuthentication yes
# Change to:
PubkeyAuthentication no

# Around line 65 (may be commented with #):
#PasswordAuthentication no  
# Change to:
PasswordAuthentication yes

# These should already be present but verify:
ChallengeResponseAuthentication yes
UsePAM yes
```

## Support

For additional assistance:
- Check VM console logs in OpenShift
- Review NodePort service configuration
- Verify AWS Load Balancer health checks
- Contact your OpenShift administrator for cluster-specific networking issues
