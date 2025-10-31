#!/bin/bash
# Expose New Project Setup Script
# Interactive setup for creating new photography projects
#
# Usage: ./new-project.sh [-p <project-name>]

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Show help
show_help() {
    cat << EOF
📦 Expose New Project Setup

Usage: ./new-project.sh [OPTIONS]

OPTIONS:
  -p <project>   Project name (will be prompted if not provided)
  -h, --help     Show this help message

EXAMPLES:
  ./new-project.sh                  Interactive setup
  ./new-project.sh -p mysite        Create project 'mysite' with prompts
  
WHAT IT DOES:
  ✅ Creates project folder structure
  ✅ Creates project.config with all settings
  ✅ Optionally sets up deployment configuration
  ✅ Creates example input folder structure
  ✅ Shows next steps for getting started

EOF
    exit 0
}

# Parse command line arguments
PROJECT_NAME=""
while getopts ":p:h" opt; do
    case ${opt} in
        p )
            PROJECT_NAME=$OPTARG
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

# Check for --help flag
if [ "$1" = "--help" ]; then
    show_help
fi

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}   📦 Expose New Project Setup${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Get project name
if [ -z "$PROJECT_NAME" ]; then
    echo -e "${BLUE}Enter project name:${NC}"
    echo -e "${YELLOW}  (e.g., 'my-portfolio', 'wedding-photos', 'photo.example.com')${NC}"
    read -p "Project name: " PROJECT_NAME
fi

# Validate project name
if [ -z "$PROJECT_NAME" ]; then
    echo -e "${RED}❌ Project name cannot be empty${NC}"
    exit 1
fi

# Check if project already exists
PROJECT_DIR="$SCRIPT_DIR/projects/$PROJECT_NAME"
if [ -d "$PROJECT_DIR" ]; then
    echo -e "${RED}❌ Project '$PROJECT_NAME' already exists!${NC}"
    echo -e "${YELLOW}   Location: $PROJECT_DIR${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✅ Project name: $PROJECT_NAME${NC}"
echo ""

# Collect configuration
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Site Configuration${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Site title
echo -e "${BLUE}Site title (shown in browser tab):${NC}"
read -p "Title [$PROJECT_NAME]: " SITE_TITLE
SITE_TITLE=${SITE_TITLE:-$PROJECT_NAME}

# Copyright
CURRENT_YEAR=$(date +%Y)
echo ""
echo -e "${BLUE}Copyright notice:${NC}"
read -p "Copyright [© $CURRENT_YEAR]: " SITE_COPYRIGHT
SITE_COPYRIGHT=${SITE_COPYRIGHT:-"© $CURRENT_YEAR"}

# Navigation title
echo ""
echo -e "${BLUE}Navigation menu title:${NC}"
read -p "Menu title [Menu]: " NAV_TITLE
NAV_TITLE=${NAV_TITLE:-"Menu"}

# Root gallery name
echo ""
echo -e "${BLUE}Homepage/Root gallery name:${NC}"
read -p "Root gallery name [Home]: " ROOT_GALLERY_NAME
ROOT_GALLERY_NAME=${ROOT_GALLERY_NAME:-"Home"}

# Show home in navigation
echo ""
echo -e "${BLUE}Show homepage in navigation menu? (y/n)${NC}"
read -p "Show home [n]: " SHOW_HOME_RESPONSE
SHOW_HOME_RESPONSE=${SHOW_HOME_RESPONSE:-"n"}
if [[ "$SHOW_HOME_RESPONSE" =~ ^[Yy] ]]; then
    SHOW_HOME_IN_NAV="true"
else
    SHOW_HOME_IN_NAV="false"
fi

# Theme
echo ""
echo -e "${BLUE}Theme to use:${NC}"
echo -e "${YELLOW}  Available themes: default${NC}"
read -p "Theme [default]: " THEME
THEME=${THEME:-"default"}

# Sort directions
echo ""
echo -e "${BLUE}Folder sort direction (asc/desc):${NC}"
read -p "Folder sort [desc]: " FOLDER_SORT
FOLDER_SORT=${FOLDER_SORT:-"desc"}

echo ""
echo -e "${BLUE}Image sort direction (asc/desc):${NC}"
read -p "Image sort [desc]: " IMAGE_SORT
IMAGE_SORT=${IMAGE_SORT:-"desc"}

# Image quality
echo ""
echo -e "${BLUE}JPEG quality (1-100):${NC}"
read -p "JPEG quality [90]: " JPEG_QUALITY
JPEG_QUALITY=${JPEG_QUALITY:-90}

# OneDrive integration
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  OneDrive Integration (Optional)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}Configure OneDrive sync? (y/n)${NC}"
read -p "Setup OneDrive [n]: " SETUP_ONEDRIVE
SETUP_ONEDRIVE=${SETUP_ONEDRIVE:-"n"}

SHARE_URL=""
if [[ "$SETUP_ONEDRIVE" =~ ^[Yy] ]]; then
    echo ""
    echo -e "${BLUE}OneDrive shared folder URL:${NC}"
    echo -e "${YELLOW}  (e.g., https://1drv.ms/f/s/...)${NC}"
    read -p "Share URL: " SHARE_URL
fi

# Deployment configuration
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Deployment Configuration (Optional)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}Configure deployment settings now? (y/n)${NC}"
echo -e "${YELLOW}  (You can always configure this later)${NC}"
read -p "Setup deployment [n]: " SETUP_DEPLOY
SETUP_DEPLOY=${SETUP_DEPLOY:-"n"}

REMOTE_HOST=""
REMOTE_USER=""
REMOTE_PATH=""
if [[ "$SETUP_DEPLOY" =~ ^[Yy] ]]; then
    echo ""
    echo -e "${BLUE}Remote server hostname or SSH config alias:${NC}"
    echo -e "${YELLOW}  (e.g., 'example.com' or 'myserver' from ~/.ssh/config)${NC}"
    read -p "Remote host: " REMOTE_HOST
    
    if [ -n "$REMOTE_HOST" ]; then
        echo ""
        echo -e "${BLUE}Remote username:${NC}"
        echo -e "${YELLOW}  (Leave empty if using SSH config)${NC}"
        read -p "Remote user: " REMOTE_USER
        
        echo ""
        echo -e "${BLUE}Remote path (absolute path where site will be deployed):${NC}"
        echo -e "${YELLOW}  (e.g., /var/www/html or /home/user/public_html)${NC}"
        read -p "Remote path: " REMOTE_PATH
    fi
fi

# Create project structure
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Creating Project Structure${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

mkdir -p "$PROJECT_DIR/input"
echo -e "${GREEN}✅ Created: $PROJECT_DIR/input/${NC}"

# Create example folder structure
mkdir -p "$PROJECT_DIR/input/01 Gallery One"
mkdir -p "$PROJECT_DIR/input/02 Gallery Two"
echo -e "${GREEN}✅ Created: Example gallery folders${NC}"

# Create project.config
CONFIG_FILE="$PROJECT_DIR/project.config"
cat > "$CONFIG_FILE" << EOF
# Expose Project Configuration
# Project: $PROJECT_NAME
# Generated: $(date +"%Y-%m-%d %H:%M:%S")

# Expose Project Configuration
# Project: $PROJECT_NAME

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Structure Settings
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Root gallery display name (homepage folder name in output)
root_gallery_name="$ROOT_GALLERY_NAME"

# Show root gallery in navigation (true/false)
show_home_in_nav="$SHOW_HOME_IN_NAV"

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Theme Settings
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Theme to use (folder name in themes/ directory)
theme="$THEME"

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Sorting Settings
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Sort direction for folders (asc or desc)
folder_sort_direction="$FOLDER_SORT"

# Sort direction for images (asc or desc)
image_sort_direction="$IMAGE_SORT"

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Image Processing Settings
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# JPEG quality (1-100, higher = better quality but larger files)
jpeg_quality=$JPEG_QUALITY

# Note: Image resolutions are defined by the theme
# See: themes/default/theme.config
EOF

# Add OneDrive config if provided
if [ -n "$SHARE_URL" ]; then
    cat >> "$CONFIG_FILE" << EOF

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# OneDrive Integration
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# OneDrive shared folder URL
# Use: ./onedrive.sh -p $PROJECT_NAME to sync images
SHARE_URL="$SHARE_URL"
EOF
fi

# Add deployment config if provided
if [ -n "$REMOTE_HOST" ]; then
    cat >> "$CONFIG_FILE" << EOF

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Deployment Configuration
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Remote server hostname or SSH config alias
REMOTE_HOST="$REMOTE_HOST"
EOF
    
    if [ -n "$REMOTE_USER" ]; then
        cat >> "$CONFIG_FILE" << EOF

# Remote username (optional if using SSH config)
REMOTE_USER="$REMOTE_USER"
EOF
    fi
    
    if [ -n "$REMOTE_PATH" ]; then
        cat >> "$CONFIG_FILE" << EOF

# Remote path where the site will be deployed
REMOTE_PATH="$REMOTE_PATH"
EOF
    fi
fi

echo -e "${GREEN}✅ Created: $CONFIG_FILE${NC}"

# Create site.config for site-wide content
SITE_CONFIG_FILE="$PROJECT_DIR/site.config"
cat > "$SITE_CONFIG_FILE" << EOF
# Site Content Settings
# These variables are available in all templates across the entire site

# Site title (shown in browser tab and page header)
site_title: $SITE_TITLE

# Site description (for meta tags and SEO)
site_description: A photography portfolio showcasing my best work

# Author name (for meta tags)
site_author: Your Name

# Keywords for SEO (comma-separated)
site_keywords: photography, portfolio, photos, gallery

# Copyright notice (shown in footer)
site_copyright: $SITE_COPYRIGHT

# Navigation menu title
nav_title: $NAV_TITLE
EOF

echo -e "${GREEN}✅ Created: $SITE_CONFIG_FILE${NC}"

# Create README for the project
README_FILE="$PROJECT_DIR/README.md"
cat > "$README_FILE" << EOF
# $SITE_TITLE

Photography project created with Expose.

## Folder Structure

\`\`\`
input/
├── 01 Gallery One/     # First gallery
├── 02 Gallery Two/     # Second gallery
└── ...                 # Add more galleries here
\`\`\`

## Adding Images

1. Place your images in the gallery folders under \`input/\`
2. Optionally add image descriptions as text files (e.g., \`IMG_001.txt\`)
3. Build the site: \`./expose.sh -p $PROJECT_NAME\`

## Building the Site

\`\`\`bash
# Full build
./expose.sh -p $PROJECT_NAME

# Fast preview (HTML only, skip image processing)
./expose.sh -s -p $PROJECT_NAME
\`\`\`
EOF

# Add OneDrive instructions if configured
if [ -n "$SHARE_URL" ]; then
    cat >> "$README_FILE" << EOF

## OneDrive Sync

This project is configured to sync images from OneDrive.

\`\`\`bash
# Sync images from OneDrive
./onedrive.sh -p $PROJECT_NAME

# Then build the site
./expose.sh -p $PROJECT_NAME
\`\`\`
EOF
fi

# Add deployment instructions if configured
if [ -n "$REMOTE_HOST" ]; then
    cat >> "$README_FILE" << EOF

## Deployment

This project is configured to deploy to: \`$REMOTE_HOST\`

\`\`\`bash
# Deploy to server
./deploy.sh -p $PROJECT_NAME

# Build and deploy in one command
./expose.sh -p $PROJECT_NAME && ./deploy.sh -p $PROJECT_NAME
\`\`\`

**Note:** Make sure SSH key authentication is set up. See DEPLOYMENT.md for details.
EOF
fi

cat >> "$README_FILE" << EOF

## Configuration

Edit \`project.config\` to customize:
- Site title and copyright
- Theme and colors
- Image quality and resolutions
- Sort order
- And more...

## Documentation

- Main README: [../../readme.md](../../readme.md)
- Deployment Guide: [../../DEPLOYMENT.md](../../DEPLOYMENT.md)
- OneDrive Sync: [../../onedrive.md](../../onedrive.md)
EOF

echo -e "${GREEN}✅ Created: $README_FILE${NC}"

# Create example metadata file
METADATA_FILE="$PROJECT_DIR/input/metadata.txt"
cat > "$METADATA_FILE" << EOF
---
width: 12
---

Welcome to $SITE_TITLE! Add your images to the gallery folders.
EOF

echo -e "${GREEN}✅ Created: $METADATA_FILE${NC}"

# Summary
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  ✅ Project Created Successfully!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}Project:${NC} $PROJECT_NAME"
echo -e "${BLUE}Location:${NC} $PROJECT_DIR"
echo ""
echo -e "${CYAN}📁 Project Structure:${NC}"
echo "   projects/$PROJECT_NAME/"
echo "   ├── project.config         # Main configuration"
echo "   ├── README.md              # Project documentation"
echo "   └── input/                 # Place your images here"
echo "       ├── 01 Gallery One/"
echo "       ├── 02 Gallery Two/"
echo "       └── metadata.txt       # Gallery metadata"
echo ""
echo -e "${CYAN}🚀 Next Steps:${NC}"
echo ""

if [ -n "$SHARE_URL" ]; then
    echo -e "${YELLOW}1.${NC} Sync images from OneDrive:"
    echo "   ./onedrive.sh -p $PROJECT_NAME"
    echo ""
    echo -e "${YELLOW}2.${NC} Build the site:"
else
    echo -e "${YELLOW}1.${NC} Add your images to:"
    echo "   $PROJECT_DIR/input/"
    echo ""
    echo -e "${YELLOW}2.${NC} Build the site:"
fi
echo "   ./expose.sh -p $PROJECT_NAME"
echo ""

if [ -n "$REMOTE_HOST" ]; then
    echo -e "${YELLOW}3.${NC} Set up SSH key authentication (if not done yet):"
    echo "   ssh-keygen -t ed25519"
    echo "   ssh-copy-id ${REMOTE_USER:+$REMOTE_USER@}$REMOTE_HOST"
    echo ""
    echo -e "${YELLOW}4.${NC} Deploy to server:"
    echo "   ./deploy.sh -p $PROJECT_NAME"
    echo ""
else
    echo -e "${YELLOW}3.${NC} View the generated site:"
    echo "   Open: output/$PROJECT_NAME/index.html"
    echo ""
    echo -e "${YELLOW}4.${NC} (Optional) Set up deployment later:"
    echo "   Edit project.config and add deployment settings"
    echo "   See: DEPLOYMENT.md for details"
    echo ""
fi

echo -e "${CYAN}📚 Documentation:${NC}"
echo "   Project README:    $PROJECT_DIR/README.md"
echo "   Main README:       readme.md"
if [ -n "$REMOTE_HOST" ]; then
    echo "   Deployment Guide:  DEPLOYMENT.md"
fi
if [ -n "$SHARE_URL" ]; then
    echo "   OneDrive Guide:    onedrive.md"
fi
echo ""
echo -e "${GREEN}Happy photographing! 📸${NC}"
echo ""
