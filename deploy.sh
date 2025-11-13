#!/bin/bash
# Expose Deployment Script
# Deploys built galleries to remote server via rsync
#
# Usage: ./deploy.sh [-p <project>] [-h]

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Show help
show_help() {
    cat << EOF
🚀 Expose Deployment Script

Usage: ./deploy.sh [OPTIONS]

OPTIONS:
  -p <project>   Project name to deploy (default: first project in projects/)
  -h, --help     Show this help message

EXAMPLES:
  ./deploy.sh                    Deploy first available project
  ./deploy.sh -p example.site    Deploy specific project
  
CONFIGURATION:
  Config is loaded from project.config:
    1. projects/PROJECT/project.config (REMOTE_HOST, REMOTE_USER, REMOTE_PATH)
    2. Environment variables (DEPLOY_HOST, DEPLOY_USER, DEPLOY_PATH)
    3. Interactive prompts (with option to save to project.config)

  See DEPLOYMENT.md for detailed setup instructions.

EOF
    exit 0
}

# Parse command line arguments
PROJECT=""
while getopts ":p:h" opt; do
    case ${opt} in
        p )
            PROJECT=$OPTARG
            ;;
        h )
            show_help
            ;;
        \? )
            echo -e "${RED}❌ Invalid option: -$OPTARG${NC}" >&2
            show_help
            ;;
        : )
            echo -e "${RED}❌ Option -$OPTARG requires an argument${NC}" >&2
            show_help
            ;;
    esac
done

# Check for --help flag (for backward compatibility)
if [ "$1" = "--help" ]; then
    show_help
fi

# Get project from argument or detect
if [ -z "$PROJECT" ]; then
    # Auto-detect first project
    PROJECT=$(ls projects/ 2>/dev/null | head -1)
    if [ -z "$PROJECT" ]; then
        echo -e "${RED}❌ No projects found in projects/ directory${NC}"
        exit 1
    fi
    echo -e "${BLUE}ℹ️  No project specified, using: $PROJECT${NC}"
fi

PROJ_DIR="projects/$PROJECT"

# Validate project exists
if [ ! -d "$PROJ_DIR" ]; then
    echo -e "${RED}❌ Project not found: $PROJECT${NC}"
    echo "Available projects:"
    ls -1 projects/ 2>/dev/null || echo "  (none)"
    exit 1
fi

# Check if output exists (expose.sh writes to output/$PROJECT)
OUTPUT_DIR="output/$PROJECT"
if [ ! -d "$OUTPUT_DIR" ]; then
    echo -e "${RED}❌ Output directory not found: $OUTPUT_DIR${NC}"
    echo -e "${YELLOW}💡 Tip: Run ./expose.sh -p $PROJECT first${NC}"
    exit 1
fi

# Load project config
if [ ! -f "$PROJ_DIR/project.config" ]; then
    echo -e "${RED}❌ Project configuration not found: $PROJ_DIR/project.config${NC}"
    echo -e "${YELLOW}💡 Create a new project with: ./new-project.sh -p $PROJECT${NC}"
    exit 1
fi

source "$PROJ_DIR/project.config"

# Get deployment settings (from config, environment, or prompt)
# Prioritize project.config values, then environment variables
REMOTE_HOST=${REMOTE_HOST:-${DEPLOY_HOST:-}}
REMOTE_USER=${REMOTE_USER:-${DEPLOY_USER:-${USER}}}
REMOTE_PATH=${REMOTE_PATH:-${DEPLOY_PATH:-}}

# Interactive prompt if not set
if [ -z "$REMOTE_HOST" ] || [ -z "$REMOTE_PATH" ]; then
    echo ""
    echo -e "${YELLOW}🔧 Deployment configuration needed for: $PROJECT${NC}"
    echo ""
    
    if [ -z "$REMOTE_HOST" ]; then
        read -p "🌐 Server hostname (or SSH config alias): " REMOTE_HOST
    fi
    
    if [ -z "$REMOTE_USER" ] || [ "$REMOTE_USER" = "$(whoami)" ]; then
        read -p "👤 Username [${USER}]: " input_user
        REMOTE_USER=${input_user:-${USER}}
    fi
    
    if [ -z "$REMOTE_PATH" ]; then
        read -p "📁 Remote path (e.g., /var/www/html/example.site): " REMOTE_PATH
    fi
    
    # Offer to save settings to project.config
    echo ""
    read -p "💾 Save these settings to project.config? (y/N): " save
    if [[ "$save" =~ ^[Yy]$ ]]; then
        # Add deployment section to project.config if not present
        if ! grep -q "^# Deployment Configuration" "$PROJ_DIR/project.config" 2>/dev/null; then
            cat >> "$PROJ_DIR/project.config" << EOF

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Deployment Configuration
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Remote server hostname or SSH config alias
REMOTE_HOST="$REMOTE_HOST"

# Remote username (optional if using SSH config)
REMOTE_USER="$REMOTE_USER"

# Remote path where the site will be deployed
REMOTE_PATH="$REMOTE_PATH"
EOF
            echo -e "${GREEN}✅ Saved to project.config${NC}"
        else
            echo -e "${YELLOW}⚠️  Deployment section already exists in project.config${NC}"
            echo -e "${YELLOW}💡 Edit manually: $PROJ_DIR/project.config${NC}"
        fi
    fi
fi

# Validate required settings
if [ -z "$REMOTE_HOST" ]; then
    echo -e "${RED}❌ REMOTE_HOST is required${NC}"
    exit 1
fi

if [ -z "$REMOTE_PATH" ]; then
    echo -e "${RED}❌ REMOTE_PATH is required${NC}"
    exit 1
fi

# Test SSH connection (optional but helpful)
echo ""
echo -e "${BLUE}🔐 Testing SSH connection to ${REMOTE_USER}@${REMOTE_HOST}...${NC}"
if ! ssh -q -o BatchMode=yes -o ConnectTimeout=5 "${REMOTE_USER}@${REMOTE_HOST}" exit 2>/dev/null; then
    echo -e "${YELLOW}⚠️  SSH connection test failed${NC}"
    echo -e "${YELLOW}💡 Make sure:${NC}"
    echo "   1. SSH key is set up (ssh-keygen & ssh-copy-id)"
    echo "   2. Or add server to ~/.ssh/config"
    echo "   3. Or you'll be prompted for password during deploy"
    echo ""
    read -p "Continue anyway? (y/N): " continue
    if [[ ! "$continue" =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Prepare rsync command
RSYNC_FLAGS=${RSYNC_FLAGS:-"--exclude='.DS_Store' --exclude='Thumbs.db' --exclude='.gitignore'"}

# Display deployment info
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🚀 Deploying: ${BLUE}$PROJECT${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "   ${BLUE}From:${NC} $OUTPUT_DIR/"
echo -e "   ${BLUE}To:${NC}   ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}/"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Confirm before deploying
read -p "▶️  Continue with deployment? (Y/n): " confirm
if [[ "$confirm" =~ ^[Nn]$ ]]; then
    echo -e "${YELLOW}⏸️  Deployment cancelled${NC}"
    exit 0
fi

# Execute rsync
echo ""
echo -e "${BLUE}📦 Transferring files...${NC}"
echo ""

rsync -avz --delete --progress --stats \
    $RSYNC_FLAGS \
    "$OUTPUT_DIR/" \
    "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}/" || {
    echo ""
    echo -e "${RED}❌ Deployment failed!${NC}"
    exit 1
}

# Success
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Deployment successful!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}🌐 Your site should now be live at:${NC}"
echo -e "   ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}/"
echo ""
