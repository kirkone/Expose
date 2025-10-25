#!/usr/bin/env bash

echo "🚀 Installing Expose dependencies..."

# Update package list
sudo apt-get -y update

# Core image processing tools
echo "📸 Installing image processing tools..."
sudo apt-get install -y exiftool
sudo apt-get install -y libvips-tools

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
echo "You can now run:"
echo "  ./expose.sh      - Generate static site"
echo "  ./onedrive.sh    - Sync from OneDrive"
echo "  ./cleanup.sh     - Clean cache and output"