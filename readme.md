# Exposé

Exposé is a high-performance Bash script that helps photographers generate beautiful static websites to showcase their images. The result is a lightning-fast static website that focuses on displaying images without distracting elements or JavaScript dependencies.

Here are some examples of websites that use this script:
- https://kirkone.github.io/Expose/ (current example site)
- https://photo.kirk.one/ (my personal website)

## 🚀 Performance Features

- **Intelligent EXIF Caching**: Only processes changed images, dramatically reducing build times
- **Batch Processing**: Optimized for large collections (1000+ images)
- **Template Optimization**: Batch template processing reduces build time by 90%
- **Skip Images Mode**: HTML-only builds in seconds for quick previews

### Build Time Examples
- **1100 images (16GB)**: ~5 minutes initial, ~3 seconds subsequent builds
- **27 images**: 8 seconds initial, 3 seconds with cache
- **Template changes**: Seconds instead of minutes

## ✨ Features

- **Zero Dependencies**: Pure Bash script with standard Unix tools
- **Static Website**: No web server or database required
- **OneDrive Integration**: Automatic sync of images and markdown files from shared OneDrive folders
- **Gallery Content**: Rich text introductions for galleries using Markdown (`content.md` files)
- **Mustache-Light Templates**: Conditional sections for flexible template design
- **EXIF Integration**: Automatic camera settings display (F-stop, ISO, focal length, etc.)
- **Responsive Design**: Mobile-friendly image galleries
- **Hierarchical Navigation**: Intelligent nested folder structure with mixed content support
- **Smart Folder Types**: Automatic detection of gallery folders vs. structural folders
- **Markdown Support**: Rich text descriptions for images and galleries
- **Smart Caching**: File modification detection for incremental builds
- **Custom Themes**: Fully customizable HTML templates

## 📋 Requirements

- Unix-based system (Linux, macOS)
- Bash 4.0+
- VIPS (libvips-tools) for ultra-fast image processing
- ExifTool (for EXIF data extraction)
- rsync (for file synchronization)
- jq (for JSON processing)
- bc (for calculations)
- Perl (for Markdown parsing)

### Installation

Run the setup script to install all required dependencies:

```bash
./setup.sh
```

The setup script will:
- Install VIPS (libvips-tools) for blazing-fast image processing
- Install ExifTool for EXIF metadata extraction
- Install all supporting tools (rsync, jq, bc, perl)
- Display installed versions for verification

The script will automatically check for missing dependencies when you run it. If any tools are missing, you'll see a helpful message:

```
❌ Missing required dependencies: vips perl bc

Please run the setup script to install all dependencies:
  ./setup.sh
```

## 🚀 Quick Start

### Basic Usage
```bash
# Generate the website
./expose.sh -p example.site

# Deploy to your web server
./deploy.sh -p example.site
```

### With OneDrive Integration
```bash
# First, sync images from OneDrive
./onedrive.sh -p example.site

# Then generate the website
./expose.sh -p example.site

# Deploy to your web server
./deploy.sh -p example.site
```

### Fast HTML Preview (skip image encoding)  
```bash
./expose.sh -s -p example.site
```

### Disable HTML Cache (for structural changes)
```bash
./expose.sh -c -p example.site
```

### Deploy to Production
```bash
# First-time setup (interactive)
./deploy.sh -p example.site

# Subsequent deployments (uses saved config)
./deploy.sh -p example.site

# Build and deploy in one command
./expose.sh -p example.site && ./deploy.sh -p example.site
```

📚 **Complete deployment guide**: [Deployment Documentation (DEPLOYMENT.md)](DEPLOYMENT.md)

### Available Options
```bash
./expose.sh [options]
  -p PROJECT           Specify project folder (default: first in ./projects)
  -s, --skip-images    Skip image encoding (HTML only, much faster)
  -c, --disable-cache  Disable HTML cache (use after navigation/template changes)
  -d                   Draft mode (single low resolution, deprecated)
  -h, --help          Show help message
```

## 📁 Project Structure

```
projects/
├── example/
│   ├── project.config         # Project configuration
│   ├── site.config            # Site-wide content settings (optional)
│   └── input/                 # Source images folder
│       ├── image1.jpg         # Root gallery images (Homepage)
│       ├── image2.jpg         
│       ├── 01 Events/         # 📊 Column 1 (navigation section)
│       │   ├── Fireworks/     # 📁 Gallery folder
│       │   │   ├── photo1.jpg
│       │   │   └── photo2.jpg
│       │   └── Racing/        # 📁 Gallery folder
│       │       ├── race1.jpg
│       │       └── race2.jpg
│       ├── 02 Miscellaneous/  # 📊 Column 2 (navigation section)
│       │   ├── Branch 1/      # 🗂️ Structure folder (no own images)
│       │   │   └── Leaf 1/    # 📁 Gallery folder
│       │   │       ├── img1.jpg
│       │   │       └── img2.jpg
│       │   ├── Gallery 1/     # 📁 Gallery folder  
│       │   │   ├── photo1.jpg
│       │   │   └── IMG_001.txt # Image description (optional)
│       │   ├── Gallery 2/     # 📁 Gallery folder
│       │   │   └── photo2.jpg
│       │   └── Mixed/         # 📁🗂️ Mixed folder (images + subfolders)
│       │       ├── mixed1.jpg # Own images
│       │       └── Leaf 2/    # 📁 Subfolder gallery
│       │           └── sub1.jpg
│       └── 03 Pages/          # 📊 Column 3 (navigation section)
│           ├── About/         # 📁 Gallery folder
│           │   └── portrait.jpg
│           └── Gear/          # 📁 Gallery folder
│               └── camera.jpg
output/
└── example/                   # Generated static website
    ├── index.html             # Root gallery (Homepage)
    ├── events/                # Column URLs included!
    │   ├── fireworks/
    │   │   └── index.html     # Fireworks gallery
    │   └── racing/
    │       └── index.html     # Racing gallery
    ├── miscellaneous/         # Column URLs included!
    │   ├── branch-1/
    │   │   └── leaf-1/
    │   │       └── index.html # Leaf 1 gallery
    │   ├── gallery-1/
    │   │   └── index.html     # Gallery 1
    │   ├── gallery-2/
    │   │   └── index.html     # Gallery 2  
    │   └── mixed/
    │       ├── index.html     # Mixed gallery
    │       └── leaf-2/
    │           └── index.html # Leaf 2 gallery
    ├── pages/                 # Column URLs included!
    │   ├── about/
    │   │   └── index.html     # About page
    │   └── gear/
    │       └── index.html     # Gear page
    └── main.css               # Theme resources
```

**Important:** Depth 1 folders (01 Events, 02 Miscellaneous, 03 Pages) become navigation columns and are part of the URL structure!

## ⚙️ Configuration

Expose uses two configuration files:

### 1. Project Config (`project.config`) - Structure & Technical Settings

Located at `projects/<project>/project.config`:

```bash
# Structure Settings
root_gallery_name="Home"
show_home_in_nav="false"

# Theme
theme="default"

# Sorting
folder_sort_direction="desc"    # or "asc"
image_sort_direction="desc"

# Image Processing
jpeg_quality=90

# Infrastructure (optional)
SHARE_URL="https://..."          # OneDrive sync
REMOTE_HOST="example.com"        # Deployment
```

**Purpose:** Controls *how* the site is built (structure, theme, sorting, quality, deployment).

### 2. Site Metadata (`site.config`) - Content Settings

Located at `projects/<project>/site.config`:

```bash
# Site Content Settings
site_title: My Photography
site_description: A portfolio showcasing my best work
site_author: John Doe
site_keywords: photography, portfolio, landscape, portrait
site_copyright: © 2025 Your Name
nav_title: Portfolio
```

**Purpose:** Defines *what* is displayed (titles, copyright, labels). These values are available in all templates.

**Separation:** Config = Technical, Metadata = Content

### Theme Config (`themes/default/theme.config`)
```bash
# Image resolutions required by this theme
resolution=(640 1024 1280 1920 2560 3840)
```

### 🔢 Folder Sorting

Exposé supports intelligent folder sorting with numeric prefixes:

```
input/
├── 01 Moon/           # Displays as "Moon" in navigation
├── 02 Wood/           # Displays as "Wood" in navigation  
└── 03 Car/            # Displays as "Car" in navigation
```

- **Numeric prefixes** (like `01 `, `02 `, `99 `) are automatically stripped from display names
- **Sort order** follows the numeric prefix, not alphabetical
- **Mixed folders** work perfectly: `01 Gallery`, `02 Structure/Subfolder`, `03 Mixed`
- Configurable sort direction with `folder_sort_direction="asc"` or `"desc"`

## 📂 OneDrive Integration

Exposé includes a high-performance OneDrive sync script for automatic downloading of images and markdown files from shared folders with structure preservation.

### Quick Setup
```bash
# Add OneDrive share URL to your project config
echo 'SHARE_URL="https://1drv.ms/f/s/your-link"' >> projects/myproject/project.config

# Sync images and markdown files, then generate website
./onedrive.sh -p myproject && ./expose.sh -p myproject
```

**Key features**: Recursive folder processing, auto-optimized performance (up to 43% faster), zero-config authentication, smart progress tracking, **markdown file sync**.

📚 **Complete documentation**: [OneDrive Sync Guide (onedrive.md)](onedrive.md)

## 📝 Gallery Content & Descriptions

### Gallery Introduction with content.md

Add a `content.md` file to any gallery folder for a rich text introduction that appears before the images:

**input/Events/Fireworks/content.md:**
```markdown
---
custom_title: Fireworks Gallery
year: 2025
---
## Spectacular Fireworks

"<cite>Fireworks</cite>" - a celebration captured in light and color.

These photos showcase the **amazing displays** from various events.
```

**Features:**
- **YAML metadata block** (optional): Define custom template variables
- **Markdown formatting**: Full markdown support (headers, bold, italic, lists, links, etc.)
- **Conditional rendering**: Gallery intro section only appears when content.md exists
- **Automatic HTML conversion**: Markdown is parsed to HTML using Perl

The `content.md` file creates a `gallery-intro` section that appears **before** the image gallery, perfect for:
- Event descriptions
- Photo series context
- Gallery introductions
- Artist statements

# Sync images and generate website
./onedrive.sh -p myproject && ./expose.sh -p myproject
```

**Key features**: Recursive folder processing, auto-optimized performance (up to 43% faster), zero-config authentication, smart progress tracking.

📚 **Complete documentation**: [OneDrive Sync Guide (onedrive.md)](onedrive.md)

## 📝 Adding Descriptions

### Gallery Metadata Files

Add `metadata.txt` to any gallery folder (`input/Gallery/`) for gallery-wide settings:
```yaml
# input/Summer-Vacation/metadata.txt
title: "Summer Vacation 2024"
description: "Photos from our trip to the mountains"
width: 12    # Grid layout width
```

### Image Description Files

Create text files with the same name as your images:

**IMG_001.txt:**
```markdown
---
title: "Sunset at the Beach"
location: "California Coast"
---

This stunning sunset was captured during our evening walk. 
The golden hour light created perfect reflections on the wet sand.
```

## 🎨 EXIF Data Integration

Exposé automatically extracts and displays camera information:
- **Camera settings**: F-stop, shutter speed, ISO, focal length
- **Equipment**: Camera model, lens information
- **Smart formatting**: Sony camera models get friendly names (α 7 IV, etc.)

Example output: `F4.0 1/640 ISO800 162mm | Sony FE 70-200mm F4 G OSS on α 7 IV`

## 🗂️ Organization & Hierarchical Navigation

### Intelligent Folder Types
Exposé automatically detects folder types and generates appropriate navigation:

**� Column Folders** (Depth 1 - contain only subfolders):
- Displayed as navigation section headers
- Part of the URL structure (`/events/fireworks/`)
- Group related galleries together
- Perfect for main categories

**�📁 Gallery Folders** (contain images):
- Displayed as clickable navigation links
- Generate their own gallery pages
- Support EXIF data and descriptions

**🗂️ Structure Folders** (contain only subfolders, Depth 2+):
- Displayed as non-clickable navigation labels
- Organize galleries hierarchically
- Perfect for grouping by year, event, etc.

**📁🗂️ Mixed Folders** (contain both images AND subfolders):
- Displayed as clickable links (have their own gallery)
- Show nested subfolders in navigation
- Best of both worlds - gallery + organization

### Navigation Examples

```
� 01 Events/              ← Column (navigation section)
├── 📁 Fireworks/          ← Gallery folder (clickable)
├── 📁 Racing/             ← Gallery folder (clickable)
└── 📁🗂️ Summer 2024/      ← Mixed folder (clickable + has subfolders)
    ├── image1.jpg         ← Images in Summer 2024/
    ├── image2.jpg
    └── 📁 Conference/     ← Subfolder of Summer 2024/

📂 02 Miscellaneous/       ← Column (navigation section)
├── 📁 Gallery 1/          ← Gallery folder
└── 📁 Gallery 2/          ← Gallery folder

📂 03 Pages/               ← Column (navigation section)
└── 🗂️ Info/              ← Structure folder (label only)
    ├── 📁 About/          ← Gallery folder
    └── 📁 Gear/           ← Gallery folder
```

**Generated Navigation:**
```html
<section>
  <h3>Events</h3>
  <div>
    <a href="./events/fireworks/" class=" ">Fireworks</a>
  </div>
  <div>
    <a href="./events/racing/" class=" ">Racing</a>
  </div>
  <div>
    <a href="./events/summer-2024/" class="active">Summer 2024</a>
    <div>
      <a href="./events/summer-2024/conference/" class=" ">Conference</a>
    </div>
  </div>
</section>
<section>
  <h3>Miscellaneous</h3>
  <div>
    <a href="./miscellaneous/gallery-1/" class=" ">Gallery 1</a>
  </div>
  <div>
    <a href="./miscellaneous/gallery-2/" class=" ">Gallery 2</a>
  </div>
</section>
<section>
  <h3>Pages</h3>
  <div>
    <span>Info</span>
    <div>
      <a href="./pages/info/about/" class=" ">About</a>
    </div>
    <div>
      <a href="./pages/info/gear/" class=" ">Gear</a>
    </div>
  </div>
</section>
```

### Folder Structure
- **Depth 1**: Navigation columns (section headers)
- **Depth 2+**: Nested galleries and structure folders
- Unlimited nesting depth supported
- Folders starting with `_` are ignored
- Automatic active state highlighting in navigation

### Sorting
- **Images**: Reverse alphabetical by default
- **Folders**: Configurable via `folder_sort_direction`
- **Custom order**: Add numerical prefixes (e.g., `01 Events`, `02 Miscellaneous`)
- Prefixes are stripped from URLs and navigation (but not from section headers)

## 🏎️ Performance Optimization

### Intelligent Caching
- **EXIF Cache**: Persistent storage of camera data, only processes changed files
- **HTML Cache**: Template processing results cached per image
- **File Change Detection**: Uses modification time + file size for fast detection

### Build Strategies
1. **Initial Build**: Full processing of all images (~5 min for 1100 images)
2. **Incremental**: Only new/changed images processed (~seconds)
3. **HTML Only**: Skip image encoding for template testing (`-s` flag)

### Large Collections (1000+ images)
- **Chunked Processing**: Processes images in batches of 100
- **Memory Efficient**: Avoids loading all EXIF data into memory
- **Scalable**: Tested with 1100+ image collections

## 🎨 Theming & Customization

### Mustache-Light Template Engine

Exposé uses a custom Mustache-Light template engine that supports conditional sections for flexible template design:

**Sections** (conditional rendering):
```html
{{#images}}
<section class="gallery">
    <h2>{{gallerytitle}}</h2>
    {{content}}
</section>
{{/images}}
```

**Inverted Sections** (render when variable is empty/false):
```html
{{^images}}
<p>No images in this gallery</p>
{{/images}}
```

**Comments**:
```html
{{! This is a comment and won't appear in output }}
```

**Default Values**:
```html
{{width:50}}        <!-- defaults to 50 if not set -->
{{title:Untitled}}  <!-- defaults to "Untitled" -->
```

**Key Features:**
- Single-line processing for optimal performance
- Multi-line template authoring (automatically collapsed)
- Truthiness: Empty strings, "false", and "0" are falsy
- All templates support sections and variables

### Template Variables

**template.html** (main page layout):
- `{{sitetitle}}` - Site title from config
- `{{sitecopyright}}` - Copyright notice
- `{{gallerytitle}}` - Current gallery name
- `{{navigation}}` - Generated hierarchical navigation menu
- `{{content}}` - Gallery content area (images)
- `{{gallerybody}}` - Gallery introduction from content.md
- `{{basepath}}` - Relative path to site root
- `{{resourcepath}}` - Path to gallery resources
- `{{images}}` - Conditional: truthy when gallery has images
- `{{gallerybody}}` - Conditional: truthy when content.md exists

**post-template.html** (individual image):
- `{{imageurl}}` - Image directory path
- `{{imagewidth}}`, `{{imageheight}}` - Image dimensions
- `{{imagemd5}}` - Unique image identifier
- **EXIF variables**: `{{exif_FNumber}}`, `{{exif_ExposureTime}}`, `{{exif_ISO}}`, etc.
- **Custom metadata**: Any variables from image text files or content.md YAML

**nav-column-template.html** (column headers - depth 1):
- `{{text}}` - Column name
- `{{children}}` - Nested navigation items (galleries within column)

**nav-branch-template.html** (structure folders - depth 2+):
- `{{text}}` - Folder name
- `{{active}}` - CSS class for active state ("" or "active")
- `{{children}}` - Nested navigation items

**nav-leaf-template.html** (gallery folders):
- `{{text}}` - Folder name  
- `{{uri}}` - Link to gallery
- `{{active}}` - CSS class for active state ("" or "active")
- `{{children}}` - Nested navigation items (for mixed folders)

### Navigation Template Examples

**nav-column-template.html** (navigation columns):
```html
<section>
  <h3>{{text}}</h3>
  {{children}}
</section>
```

**nav-branch-template.html** (non-clickable structure):
```html
<div>
  <span>{{text}}</span>
  {{children}}
</div>
```

**nav-leaf-template.html** (clickable gallery):
```html
<a href="{{uri}}" class=" {{active}}">{{text}}</a>
{{children}}
```

### Default Values
Use fallback syntax for optional variables:
```html
{{width:50}}        <!-- defaults to 50 if not set -->
{{title:Untitled}}  <!-- defaults to "Untitled" -->
```

## 🔧 Advanced Usage

### Custom Themes
1. Copy `themes/default/` to `themes/mytheme/`
2. Modify templates as needed:
   - `template.html` - Main page layout
   - `post-template.html` - Individual images
   - `nav-column-template.html` - Column headers (depth 1)
   - `nav-branch-template.html` - Structure folders (depth 2+)
   - `nav-leaf-template.html` - Gallery folders
3. Update `project.config`: `theme="mytheme"`

### Workflow Examples

**Development Workflow:**
```bash
# Quick HTML preview while designing
./expose.sh -s -p myproject

# After changing navigation templates (disable cache)
./expose.sh -s -c -p myproject  

# Full build when ready
./expose.sh -p myproject
```

**Production Workflow:**
```bash
# Add new photos to project folder
cp new_photos/* projects/myproject/2024/

# Quick incremental build (only processes new photos)
./expose.sh -p myproject
```

## 📊 Performance Benchmarks

| Images | Initial Build | Cached Build | With Changes |
|--------|---------------|--------------|--------------|
| 27     | 8 seconds     | 3 seconds    | 4-6 seconds  |
| 100    | ~30 seconds   | 3 seconds    | 5-10 seconds |
| 1100   | ~5 minutes    | 3 seconds    | 10-60 seconds|

*Times measured on modern hardware with SSD storage*

## 🐛 Troubleshooting

### Common Issues
- **Slow builds**: Use `-s` flag first to test HTML generation
- **Missing EXIF**: Ensure ExifTool is installed (`apt install libimage-exiftool-perl`)
- **Image processing errors**: Check VIPS installation (`vips --version`)
- **Permission errors**: Ensure write access to output directory
- **Segfaults**: Already handled with VIPS_CONCURRENCY=1 and retry logic

### Cache Management
```bash
# Clear all cache (force full rebuild)
rm -rf .cache/

# Clear only EXIF cache
rm -rf .cache/*/exif/

# Clear only HTML cache  
rm -rf .cache/*/html/
```

## 📄 Examples

Live examples:
- [Demo Site](https://kirkone.github.io/Expose/) - Example gallery
- [Personal Portfolio](https://photo.kirk.one/) - Real-world usage

## 🏆 Credits

This project is heavily based on [Expose by Jack000](https://github.com/Jack000/Expose), an excellent static site generator for photographers. The core concept, templating system, and workflow remain largely inspired by the original work.

Key enhancements in this fork:
- **Performance optimizations**: Intelligent EXIF and HTML caching for 90% faster builds
- **Ultra-fast image processing**: VIPS with parallel processing (79x faster than sequential!)
- **Rock-solid stability**: VIPS_CONCURRENCY=1 + retry logic prevents segfaults
- **Batch processing**: Template optimization for large collections (1000+ images)
- **OneDrive integration**: Automatic sync of images and markdown files with optimized concurrency (c=24 for 32-core)
- **Gallery content feature**: Rich text introductions using `content.md` files with YAML metadata support
- **Mustache-Light engine**: Conditional sections (`{{#var}}...{{/var}}`) for flexible template design
- **Extended EXIF support**: Camera settings display with smart formatting
- **Improved navigation**: Support for mixed folders and hierarchical structures
- **Modern tooling**: VIPS for blazing-fast image processing with intelligent parallelization

## �📜 License

This project is licensed under the MIT License. See the [LICENSE](LICENSE.txt) file for details.

---

**Made with ❤️ for photographers who value performance and simplicity.**
The script operates on your current working directory, and outputs a `output` directory.

### Configuration

Technical settings (theme, sorting, quality) are in `project.config`, content settings (titles, copyright) are in `site.config`:

```bash
# project.config (structure & technical)
theme="default"
jpeg_quality=90

# site.config (content)
site_title: My Photography Site
site_description: Showcasing my photography journey
site_author: John Doe
site_keywords: photography, art, nature
site_copyright: © 2025 Your Name
```

### Flags

```
expose.sh -p example.site
```

The -p flag provides the name of the project folder that should be processed. Defaults to the first folder in the `./projects` folder.

```
expose.sh -d
```

The -d flag enables draft mode, where only a single low resolution is encoded. This can be used for a quick preview or for layout purposes.

Generated images are not overwritten, to do a completely clean build delete the existing output directory first.

## Adding text

The text associated with each image is read from any text file with the same filename as the image, eg:

## Sorting

Images are sorted by reverse alphabetical order. To arbitrarily order images, add a numerical prefix

## Organization

You can put images in folders to organize them. The folders can be nested any number of times, and are also sorted alphabetically. The folder structure is used to generate a nested html menu.

To arbitrarily order folders, add a numerical prefix to the folder name. Any numerical prefixes are stripped from the url.

Any folders or images with an "_" prefix are ignored and excluded from the build.

## Metadata Hierarchy

Exposé uses a hierarchical metadata system:

### 1. Site-wide metadata (`site.config`)

Located in `projects/<project>/site.config` - applies to the entire site:
```bash
site_title: My Photography
site_description: A portfolio showcasing my best work
site_author: John Doe
site_keywords: photography, portfolio, landscape
site_copyright: © 2025 Your Name
nav_title: Portfolio
```

### 2. Gallery metadata (`metadata.txt`)

Located in `projects/<project>/input/GalleryName/metadata.txt` - applies to a specific gallery:
```bash
width: 19
textcolor: #ffffff
```

These settings apply to all images in that gallery and override site-wide defaults.

### 3. Image metadata (`imagename.txt`)

Located next to the image file - applies to a single image:
```markdown
---
width: 50
textcolor: #ff0000
---
Image description with **Markdown** support.
```

Individual image settings override gallery and site-wide settings.

## Advanced usage

### Templating

If the two built-in themes aren't your thing, you can create a new theme. There are only two template files in a theme:

**template.html** contains the global html for your page. It has access to the following built-in variables:

- `{{basepath}}` - a path to the top level directory of the generated site with trailing slash, relative to the current html file
- `{{resourcepath}}` - a path to the gallery resource directory, relative to the current html file. This will be mostly empty (since the html page is in the resource directory), except for the top level index.html file, which necessarily draws resources from a subdirectory
- `{{resolution}}` - a list of horizontal resolutions, as specified in the config. This is a single string with space-delimited values
- `{{content}}` - where the text/images will go
- `{{sitetitle}}` - a global title for your site, as specified in the config
- `{{site_copyright}}` - a copyright for your site, as specified in the config
- `{{gallerytitle}}` - the title of the current gallery. This is just taken from the folder name
- `{{navigation}}` - a nested html menu generated from the folder structure

**post-template.html** contains the html fragment for each individual image. It has access to the following built-in variables:

- `{{imageurl}}` - url of the *directory* which contains the image resources, relative to the current html file.
	- For images, this folder will contain all the scaled versions of the images, where the file name is simply the width of the image - eg. 640.jpg
- `{{imagewidth}}` - maximum width that the source image can be downscaled to
- `{{imageheight}}` - maximum height, based on aspect ratio and max width

in addition to these, any variables specified in the YAML metadata of the post will also be available to the post template, eg:

	---
	mycustomvar: foo
	---

this will cause {{mycustomvar}} to be replaced by "foo", in this particular post

#### Additional notes:

Specify default values, in case of unset template variables in the form {{foo:bar}} eg:

	{{width:50}}

will set width to 50 if no specific value has been assigned to it by the time page generation has finished.

Any unused {{xxx}} variables that did not have defaults are removed from the generated page.

Any non-template files (css, images, javascript) in the theme directory are simply copied into the output directory.

To avoid additional dependencies, the YAML parser and template engine is simply a sed regex. This means that YAML metadata must take the form of simple key:value pairs, and more complex liquid template syntax are not available.

## License

This project is licensed under the MIT License. For more information, see the LICENSE file.