#!/usr/bin/env bash

echo "🚀 Installing Expose dependencies..."

# Update package list
sudo apt-get -y update

# Core image processing tools
echo "📸 Installing image processing tools..."
sudo apt-get install -y libvips-tools
sudo apt-get install -y exiftool

# File synchronization
echo "📁 Installing file sync tools..."
sudo apt-get install -y rsync

# JSON processing
echo "🔧 Installing JSON processor..."
sudo apt-get install -y jq

# OneDrive API dependencies
echo "☁️  Installing OneDrive sync dependencies..."
sudo apt-get install -y curl

# Markdown processing (optional but recommended)
echo "📝 Installing Perl for Markdown processing..."
sudo apt-get install -y perl

# Math calculations
echo "🧮 Installing calculator..."
sudo apt-get install -y bc

echo ""
echo "✅ All dependencies installed successfully!"
echo ""
echo "🔧 Setting execute permissions for scripts..."
chmod +x expose.sh
chmod +x deploy.sh
chmod +x onedrive.sh
chmod +x cleanup.sh
chmod +x new-project.sh
echo ""
echo "📦 Installed versions:"
echo "  VIPS: $(vips --version 2>/dev/null | head -1 || echo 'not found')"
echo "  ExifTool: $(exiftool -ver 2>/dev/null || echo 'not found')"
echo "  rsync: $(rsync --version 2>/dev/null | head -1 | awk '{print $3}' || echo 'not found')"
echo "  jq: $(jq --version 2>/dev/null || echo 'not found')"
echo "  curl: $(curl --version 2>/dev/null | head -1 | awk '{print $2}' || echo 'not found')"
echo "  Perl: $(perl -v 2>/dev/null | grep -oP 'v\d+\.\d+\.\d+' | head -1 || echo 'not found')"
echo "  bc: $(bc --version 2>/dev/null | head -1 | awk '{print $2}' || echo 'not found')"
echo ""
echo "⚙️  Performance optimizations:"
echo "  VIPS_CONCURRENCY=1 (prevents segfaults)"
echo "  Parallel processing: auto-detected based on CPU cores"
echo ""
echo "🎯 Next steps:"
echo ""
echo "1️⃣  Create a new project:"
echo "    ./new-project.sh"
echo ""
echo "2️⃣  Generate your site:"
echo "    ./expose.sh -p <project-name>"
echo ""
echo "3️⃣  Optional - Sync from OneDrive:"
echo "    ./onedrive.sh -p <project-name>"
echo ""
echo "4️⃣  Optional - Deploy to server:"
echo "    ./deploy.sh -p <project-name>"
echo ""
echo "📚 See QUICKSTART.md for detailed guide"