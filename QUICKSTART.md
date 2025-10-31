# 🚀 Quickstart Guide

Get started with Expose - from zero to a complete website in minutes.

## Prerequisites

```bash
# Make setup script executable
chmod +x setup.sh

# Install all dependencies
./setup.sh
```

This automatically installs:
- **libvips-tools** - Fast image processing
- **exiftool** - EXIF data extraction
- **rsync** - Deployment
- **jq** - JSON processing
- **curl** - OneDrive integration
- **perl** - Markdown processing
- **bc** - Calculations

And sets execute permissions for all scripts.

## 1️⃣ Create a New Project

```bash
./new-project.sh
```

The interactive script guides you through all settings:
- **Project name** (e.g., `my-gallery`)
- **Site title** and copyright
- **Theme** selection (default: `default`)
- **Sorting** for folders and images
- **Image quality** (JPEG compression)
- **Optional:** OneDrive integration
- **Optional:** Deployment configuration

**Result:** Project folder with `project.config`, `site.config`, and example structure

## 2️⃣ Add Images

```bash
projects/my-gallery/input/
├── Gallery 1/
│   ├── image1.jpg
│   ├── image2.jpg
│   └── metadata.txt     # Optional: descriptions
├── Gallery 2/
│   └── Branch/
│       └── Leaf/
│           └── image3.jpg
└── metadata.txt         # Optional: root description
```

**Tip:** Folder names with number prefixes control sorting:
```
01 First Gallery/
02 Second Gallery/
03 Third Gallery/
```

## 3️⃣ Generate Website

```bash
./expose.sh -p my-gallery
```

**Options:**
- `-s` - Skip: Skip already processed images (faster!)
- `-c` - Clean: Delete old files before building

**Result:** Complete website in `output/my-gallery/`

## 4️⃣ Preview

```bash
cd output/my-gallery
python3 -m http.server 8000
```

Open in browser: `http://localhost:8000`

## 5️⃣ Deployment (Optional)

### Set up SSH key

```bash
# Generate SSH key (if you don't have one yet)
ssh-keygen -t ed25519 -C "deploy@example.com"

# Copy public key to server
ssh-copy-id user@example.com
```

### Deploy website

```bash
./deploy.sh -p my-gallery
```

The first time, you'll be asked interactively for:
- Remote Host
- Remote User
- Remote Path

The settings are saved in `project.config`.

## 🎯 Typical Workflow

```bash
# 1. Add new images
cp ~/Downloads/*.jpg projects/my-gallery/input/New-Gallery/

# 2. Regenerate website (only new images)
./expose.sh -s -p my-gallery

# 3. Test locally
cd output/my-gallery && python3 -m http.server 8000

# 4. Deploy
./deploy.sh -p my-gallery
```

## 📦 OneDrive Integration (Optional)

### Setup

During project setup, provide OneDrive share URL or add later in `project.config`:

```bash
# OneDrive Integration
SHARE_URL="https://1drv.ms/f/s!xxxxxx"
```

### Download images from OneDrive

```bash
# Download all new images
./onedrive.sh -p my-gallery

# With more parallel downloads (default: 4)
./onedrive.sh -p my-gallery -c 8

# Only specific folders
./onedrive.sh -p my-gallery -d "Gallery 1"
```

**Workflow with OneDrive:**

```bash
# 1. Fetch images from OneDrive
./onedrive.sh -p my-gallery

# 2. Generate website
./expose.sh -s -p my-gallery

# 3. Deploy
./deploy.sh -p my-gallery
```

## 🧹 Cleanup

```bash
# Clean up old/deleted images
./cleanup.sh -p my-gallery
```

Removes output files for images that no longer exist in input.

## ⚙️ Configuration

Expose uses two configuration files with clear separation:

### Technical Settings (`project.config`)

`projects/my-gallery/project.config`:

```bash
# Structure
root_gallery_name="Home"
show_home_in_nav="false"

# Theme
theme="default"

# Sorting
folder_sort_direction="desc"    # desc or asc
image_sort_direction="desc"     # desc or asc

# Image processing
jpeg_quality=90                 # 1-100
```

**Purpose:** How is the site built? (Structure, theme, sorting, quality)

### Content Settings (`site.config`)

`projects/my-gallery/site.config`:

```bash
# Site Content Settings
site_title: My Photo Gallery
site_description: A collection of my best photos
site_author: John Doe
site_keywords: photography, portfolio, landscape, nature
site_copyright: © 2025 John Doe
nav_title: Navigation
```

**Purpose:** What is displayed? (Title, copyright, labels)

These values are available in all templates.

**Separation:** Config = Technical, Metadata = Content

### Theme Customization

`themes/default/theme.config`:

```bash
# Image resolutions for responsive design
resolution=(3840 2560 1920 1280 1024 640 320 160 80 20)
```

Create your own theme:

```bash
cp -r themes/default themes/my-theme
# Then customize templates and CSS
```

Activate in project:

```bash
# In project.config
theme="my-theme"
```

## 📝 Metadata

### Site-wide Metadata (Content Settings)

The global `site.config` in the project root contains content variables for all pages:

```
# projects/my-gallery/site.config
site_title: My Photo Gallery
site_description: A collection of my best photos
site_author: John Doe
site_keywords: photography, portfolio, landscape, nature
site_copyright: © 2025 John Doe
nav_title: Navigation
```

These values appear on all generated pages (header, footer, browser tab, SEO meta tags).

### Gallery-wide Metadata

`metadata.txt` in a gallery folder sets defaults for all images in that gallery:

```
# projects/my-gallery/input/Gallery-1/metadata.txt
top: 30
left: 5
width: 30
height: 20
textcolor: #ffffff
```

Available parameters:
- `top`, `left`, `width`, `height` - Position and size for text overlays
- `textcolor` - Text color (hex code)

### Image-specific Metadata

For each image, you can create a `.txt` or `.md` file with the **same name**:

```
# projects/my-gallery/input/Gallery/image1.txt
---
width: 50
textcolor: #ff0000
---
This is the description of image 1.

Supports **Markdown** formatting!
```

**Format:**
- Metadata between `---` separators (YAML-style)
- Below that, the actual text/description
- Text is processed by Markdown parser

**Example without metadata:**
```
# image2.txt
Just text, no special settings.
```

**Hierarchy:** Site metadata → Gallery metadata → Image metadata (each level overrides higher levels)

## 🔧 Troubleshooting

### "Project configuration not found"
```bash
# Project doesn't exist - create new one
./new-project.sh
```

### Images not being processed
```bash
# Clear cache and regenerate
./expose.sh -c -p my-gallery
```

### Deployment fails
```bash
# Test SSH connection
ssh user@example.com

# Check deployment settings
cat projects/my-gallery/project.config
```

## 📚 Further Documentation

- **[README.md](readme.md)** - Complete documentation
- **[DEPLOYMENT.md](DEPLOYMENT.md)** - Deployment details
- **[onedrive.md](onedrive.md)** - OneDrive integration

## ⏱️ Performance Tips

```bash
# For large projects (1000+ images):
# 1. Always use -s (skip processed images)
./expose.sh -s -p my-gallery

# 2. OneDrive with more parallelism
./onedrive.sh -p my-gallery -c 8

# 3. Deployment uses automatic compression
./deploy.sh -p my-gallery
```

**Typical build times:**
- Initial build (1000 images): ~20-30 minutes
- Incremental build (10 new images): ~30 seconds
- Deployment (15GB, delta): ~2-5 minutes

---

**Good luck with your gallery!** 🎨📸
