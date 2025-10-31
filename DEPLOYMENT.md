# Deployment Guide

This guide explains how to deploy your generated static site to a remote web server using the `deploy.sh` script.

## Quick Start

```bash
# Deploy the first project in projects/ directory
./deploy.sh

# Deploy a specific project
./deploy.sh -p example.site
```

On first run, the script will ask for your server details and optionally save them.

## Setup

### Option 1: SSH Config (Recommended)

This is the most secure method and keeps credentials out of your project files.

1. **Generate SSH key** (if you don't have one):
   ```bash
   ssh-keygen -t ed25519 -C "your_email@example.com"
   # Press Enter to accept default location (~/.ssh/id_ed25519)
   # Optionally set a passphrase
   ```

2. **Copy key to server**:
   ```bash
   ssh-copy-id username@your-server.com
   # Enter your password when prompted
   ```

3. **Test SSH connection**:
   ```bash
   ssh username@your-server.com
   # Should connect without password prompt
   ```

4. **Create SSH config** (`~/.ssh/config`):
   ```
   Host myserver
     HostName your-server.com
     User username
     IdentityFile ~/.ssh/id_ed25519
   ```

5. **Create project deploy config** (`projects/yourproject/project.config`):
   ```bash
   # Add to your existing project.config:
   
   #━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   # Deployment Configuration
   #━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   
   # Remote server hostname or SSH config alias
   REMOTE_HOST="myserver"
   
   # Remote path where the site will be deployed
   REMOTE_PATH="/var/www/html"
   ```

   Note: `REMOTE_USER` is not needed when using SSH config.

### Option 2: Project Config File

1. **Copy template**:
   ```bash
   cp project.config.template projects/yourproject/project.config
   ```

2. **Edit the config** (`projects/yourproject/project.config`):
   Add the deployment section:
   ```bash
   #━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   # Deployment Configuration
   #━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   
   REMOTE_HOST="your-server.com"
   REMOTE_USER="username"
   REMOTE_PATH="/var/www/html"
   ```

3. **Set up SSH key authentication** (same as Option 1, steps 1-3).

### Option 3: Environment Variables

Set these before running deploy.sh:
```bash
export DEPLOY_HOST="your-server.com"
export DEPLOY_USER="username"
export DEPLOY_PATH="/var/www/html"
./deploy.sh
```

### Option 4: Interactive

Just run `./deploy.sh` and answer the prompts. You'll be asked if you want to save the configuration.

## How It Works

The deployment script uses `rsync` to efficiently transfer only changed files:

```bash
rsync -avz --delete --progress --stats --partial \
  projects/yourproject/output/ \
  username@server:/var/www/html/
```

**Flags explained:**
- `-a` (archive): Preserves permissions, timestamps, symlinks
- `-v` (verbose): Shows files being transferred
- `-z` (compress): Compresses data during transfer
- `--delete`: Removes files on server that don't exist locally
- `--progress`: Shows transfer progress
- `--stats`: Shows transfer statistics at the end
- `--partial`: Keeps partially transferred files (resume if interrupted)

## Performance

rsync only transfers changed files, making deployments very fast:

- **First deployment** (~1 GB): ~5 minutes
- **CSS change only** (~500 KB): ~3 seconds
- **10 new images** (~2 MB): ~15 seconds
- **Rebuild without changes**: ~1 second (0 bytes transferred)

That's a **4000x speedup** compared to re-uploading everything!

## Security

✅ **DO:**
- Use SSH key authentication (no passwords in scripts)
- Keep `project.config` deployment sections private
- Use SSH config aliases for credentials
- Set restrictive permissions: `chmod 600 projects/*/project.config`

❌ **DON'T:**
- Commit `project.config` files with deployment credentials to git
- Use password authentication
- Hardcode credentials in scripts
- Share your private SSH keys

## Multiple Projects

Each project can have its own deployment configuration in `project.config`:

```
projects/
  blog/
    project.config     # Contains REMOTE_HOST="blog.example.com"
  portfolio/
    project.config     # Contains REMOTE_HOST="portfolio.example.com"
  company/
    project.config     # Contains REMOTE_HOST="company-site.com"
```

Deploy each project separately:
```bash
./deploy.sh -p blog
./deploy.sh -p portfolio
./deploy.sh -p company
```

## Troubleshooting

### "Permission denied (publickey)"

Your SSH key isn't set up correctly:
```bash
# Test SSH connection
ssh username@your-server.com

# If it asks for a password, copy your key:
ssh-copy-id username@your-server.com
```

### "No route to host"

Check the hostname:
```bash
ping your-server.com
```

### "Permission denied" on remote path

The remote user needs write access to the deployment path:
```bash
# On the server:
sudo chown -R username:username /var/www/html
# Or:
sudo chmod 755 /var/www/html
```

### Changes not appearing on website

Check the remote path is correct:
```bash
# Connect to server
ssh username@your-server.com

# Check web server document root
# For Apache:
grep DocumentRoot /etc/apache2/sites-enabled/000-default.conf

# For Nginx:
grep root /etc/nginx/sites-enabled/default
```

## Integration with expose.sh

You can automatically deploy after building:

```bash
# Build and deploy
./expose.sh -p example.site && ./deploy.sh -p example.site
```

Or create a combined script (`build-and-deploy.sh`):
```bash
#!/bin/bash
set -e

PROJECT=${1:-$(ls projects/ | head -1)}

echo "🔨 Building $PROJECT..."
./expose.sh -p "$PROJECT"

echo ""
echo "🚀 Deploying $PROJECT..."
./deploy.sh -p "$PROJECT"

echo ""
echo "✅ Done! Your site is live."
```

## Advanced Options

### Dry Run

See what would be transferred without actually transferring:
```bash
rsync -avz --delete --dry-run \
  projects/yourproject/output/ \
  username@server:/var/www/html/
```

### Bandwidth Limiting

Limit transfer speed to 1000 KB/s:
```bash
rsync -avz --delete --bwlimit=1000 \
  projects/yourproject/output/ \
  username@server:/var/www/html/
```

### Exclude Files

Skip certain files or directories:
```bash
rsync -avz --delete --exclude='.DS_Store' --exclude='*.tmp' \
  projects/yourproject/output/ \
  username@server:/var/www/html/
```

## SSH Config Examples

### Multiple servers with different keys

```
Host production
  HostName prod.example.com
  User produser
  IdentityFile ~/.ssh/id_production

Host staging
  HostName staging.example.com
  User staginguser
  IdentityFile ~/.ssh/id_staging
  Port 2222
```

### Using a jump host (bastion)

```
Host webserver
  HostName 10.0.1.50
  User webuser
  ProxyJump bastion

Host bastion
  HostName bastion.example.com
  User jumpuser
  IdentityFile ~/.ssh/id_bastion
```

Then deploy through the jump host:
```bash
REMOTE_HOST="webserver"
REMOTE_PATH="/var/www/html"
```
