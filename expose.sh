#!/usr/bin/env bash

# Expose Static Site Generator
# Generates responsive photo galleries from folder structures
# 
# Usage: ./expose.sh [-s] [-c] [-p <project>]
# Author: Expose Static Site Generator
# Version: 1.0

# Original Expose didn't use strict error handling

SECONDS=0

topdir=$(pwd)
scriptdir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

# Load Mustache-Light template engine
source "$scriptdir/lib/template.sh"

skip_images=false

# Check if we're in a project directory or need to detect it
if [ -f "project.config" ] && [ -d "input" ]; then
    # We're already in a project directory
    proj_dir="$topdir"
    project=$(basename "$topdir")
else
    # Use the original project detection logic
    project=$(ls "$topdir/projects" 2>/dev/null | head -1)
    proj_dir="$topdir/projects/$project"
fi

while getopts ":scp:" opt; do
    case "${opt}" in
        s)
            echo "Skipping image encoding"
            skip_images=true
            ;;
        c)
            echo "Disabling HTML cache"
            no_html_cache=true
            ;;
        p)
            if [ -d "$topdir/projects/${OPTARG}" ]; then
                echo "using project: ${OPTARG}"
                project=${OPTARG}
                proj_dir="$topdir/projects/${OPTARG}"
            else
                echo "project '${OPTARG}' not found"
                exit 1
            fi
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            echo "Usage: $0 [-s] [-c] [-p <project>]" >&2
            echo "  -s: Skip image encoding (HTML only)"
            echo "  -c: Disable HTML cache (useful for theme development)"
            echo "  -p: Specify project folder"
            exit 1
            ;;
    esac
done

# configuration

# Source project configuration file
if [ ! -f "$proj_dir/project.config" ]; then
	echo "❌ Project configuration not found: $proj_dir/project.config" >&2
	echo "" >&2
	echo "Create a new project with:" >&2
	echo "  ./new-project.sh -p $project" >&2
	exit 1
fi

. "$proj_dir/project.config"

# Load site config (overrides config defaults for content variables)
site_config=""
if [ -f "$proj_dir/site.config" ]; then
	site_config=$(cat "$proj_dir/site.config")
	
	# Parse site config and set variables
	while IFS=: read -r key value; do
		# Skip empty lines and comments
		[[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
		
		# Trim whitespace
		key=$(echo "$key" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
		value=$(echo "$value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
		
		# Set variable dynamically
		if [ -n "$key" ] && [ -n "$value" ]; then
			eval "$key=\"$value\""
		fi
	done <<< "$site_config"
fi

# Set defaults for content variables (if not set by site.config)
site_title=${site_title:-"My Awesome Photos"}
site_description=${site_description:-"A photography portfolio"}
site_author=${site_author:-""}
site_keywords=${site_keywords:-"photography, photos, gallery"}
site_copyright=${site_copyright:-"© $(date +%Y)"}
nav_title=${nav_title:-"Pages"}

# Root gallery display name (default: directory name)
root_gallery_name=${root_gallery_name:-""}

# Show root gallery in navigation (default: true)
show_home_in_nav=${show_home_in_nav:-"true"}

theme=${theme:-"default"}
theme_dir=${theme_dir:-"$scriptdir/themes/$theme"}
in_dir=${in_dir:-"$proj_dir/input"}
out_dir=${out_dir:-"$topdir/output/$project"}

# Load theme configuration (defines required image resolutions)
if [ -f "$theme_dir/theme.config" ]; then
  	. "$theme_dir/theme.config"
fi

# widths to scale images to (heights are calculated from source images)
resolution=${resolution:-(2560 1920 1280 1024 640)}

# jpeg compression quality for static photos
jpeg_quality=${jpeg_quality:-85}

# Apply default sort directions if not set in project.config
folder_sort_direction=${folder_sort_direction:-"asc"}
image_sort_direction=${image_sort_direction:-"asc"}

folder_sort_option="-r"
image_sort_option="-r"
if [ "$folder_sort_direction" = "asc" ]; then
  folder_sort_option=""
fi
if [ "$image_sort_direction" = "asc" ]; then
  image_sort_option=""
fi

# script starts here

# Check for required dependencies
missing_deps=()
required_tools=("exiftool" "vips" "rsync" "jq" "perl" "bc")

for tool in "${required_tools[@]}"; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        missing_deps+=("$tool")
    fi
done

if [ ${#missing_deps[@]} -gt 0 ]; then
    echo "❌ Missing required dependencies: ${missing_deps[*]}" >&2
    echo "" >&2
    echo "Please run the setup script to install all dependencies:" >&2
    echo "  ./setup.sh" >&2
    echo "" >&2
    exit 1
fi

# Set VIPS concurrency to 1 for maximum stability (prevents threading-related segfaults)
# Benchmarked: VIPS_CONCURRENCY=2 is 1.5% faster but we prioritize stability
export VIPS_CONCURRENCY=1

# Determine optimal parallelization for image processing
# Benchmarked optimal values for different CPU counts
nproc_count=$(nproc 2>/dev/null || echo "4")
if [ "$nproc_count" -le 4 ]; then
    MAX_PARALLEL_IMAGES=4
elif [ "$nproc_count" -le 8 ]; then
    MAX_PARALLEL_IMAGES=8
elif [ "$nproc_count" -le 16 ]; then
    MAX_PARALLEL_IMAGES=12
elif [ "$nproc_count" -le 24 ]; then
    MAX_PARALLEL_IMAGES=16
else
    MAX_PARALLEL_IMAGES=24  # Optimal for 32-core: 4.5s vs 5.7s with 12
fi



# directory structure will form nav structure
paths=() # relevant non-empty dirs in $in_dir
nav_name=() # a front-end friendly label for each item in paths[], with numeric prefixes stripped
nav_depth=() # depth of each navigation item
nav_type=() # 0 = structure, 1 = leaf. Where a leaf directory is a gallery of images
nav_url=() # a browser-friendly url for each path, relative to output
nav_image_url=() # url for images (root gallery gets subfolder)
nav_count=() # the number of images in each gallery, or -1 if not a leaf

metadata_file="metadata.txt" # search for this file in each gallery directory for gallery-wide metadata

gallery_files=() # a flat list of all gallery images
gallery_nav=() # index of nav item the gallery image belongs to
gallery_url=() # url-friendly name of each image
gallery_md5=() # md5 hash of original image 
gallery_maxwidth=() # maximum image size available
gallery_maxheight=() # maximum height

# scan working directory to populate $nav variables
root_depth=$(echo "$in_dir" | awk -F"/" "{ print NF }")

# $1: template, $2: {{ variable name }}, $3: replacement string
template () {
	key=$(echo "$2" | tr -d '[:space:]')
		
	value=$(echo $3 | sed -e 's/\\/\\\\/g' -e 's/\//\\\//g' -e 's/&/\\\&/g') # escape sed input
	echo "$1" | sed "s/{{$key}}/$value/g; s/{{$key:[^}]*}}/$value/g"
}

# Batch template processing - much faster than multiple individual calls
# Usage: template_batch "template_string" "key1:value1" "key2:value2" ...
template_batch() {
	local result="$1"
	shift
	
	# Process each key-value pair by calling template() function
	# This is slower than a single sed call, but handles multi-line values correctly
	for assignment in "$@"; do
		if [[ "$assignment" == *":"* ]]; then
			local key="${assignment%%:*}"
			local value="${assignment#*:}"
			result=$(template "$result" "$key" "$value")
		fi
	done
	
	echo "$result"
}

# Extract EXIF data for a specific file from individual JSON cache
# $1: filename (basename), $2: EXIF field name
get_exif_value() {
	local filename="$1"
	local field="$2"
	
	# Find the cache file for this image
	local cache_file=""
	for k in "${!gallery_files[@]}"; do
		if [ "$(basename "${gallery_files[k]}")" = "$filename" ]; then
			local file_cache_key="${gallery_md5[k]}"
			cache_file="$exif_cache_dir/$file_cache_key.json"
			break
		fi
	done
	
	# Check if cache file exists
	if [ ! -f "$cache_file" ]; then
		return
	fi
	
	# Parse JSON using jq for reliable extraction
	jq -r --arg field "$field" '.[$field] // empty' "$cache_file" 2>/dev/null
}

# Check if /tmpfs exists, otherwise use the system default temp folder
if [ -d "/tmpfs" ]; then
    tmpdir=$(mktemp -d -p /tmpfs -t expose.XXXXXXXX)
else
    tmpdir=$(mktemp -d -t expose.XXXXXXXX)
fi

if [ -z "$tmpdir" ]
then
	echo "Could not create scratch directory" >&2; exit 1;
fi

chmod -R 740 "$tmpdir"

printf "temp directory: $tmpdir\n"

cleanup() {
	echo "Cleaning up"
	
	if [ -d "$tmpdir" ]
    then
        rm -r "$tmpdir"
    fi
	
	echo "    ✅"
	echo "Elapsed time: $SECONDS seconds"  # Prints the time elapsed since SECONDS was initialized
	exit
}

trap cleanup INT TERM

printf "\nScanning directories\n   "

# Process subdirectories (Original behavior - root is handled automatically)
while read node
do
	echo -n " 📂"

	node_depth=$(echo "$node" | awk -F"/" "{ print NF-$root_depth }")
	
	# ignore empty directories
	if find "$node" -maxdepth 0 -empty | read v
	then
		continue
	fi
	
	node_name=$(basename "$node" | sed -e 's/^[0-9][0-9]* *//' | sed -e 's/^[[:space:]]*//;s/[[:space:]]*$//')
	if [ -z "$node_name" ]
	then
		node_name=$(basename "$node")
	fi
	
	# Special handling for root directory name
	if [ "$node" = "$in_dir" ] && [ -n "$root_gallery_name" ]
	then
		node_name="$root_gallery_name"
	fi
		
	dircount=$(find "$node" -maxdepth 1 -type d ! -path "$node" ! -path "$node*/_*" | wc -l)
	imagecount=$(find "$node" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.bmp" -o -iname "*.webp" \) | wc -l)
	
	# Determine node type:
	# Type 2 = Column (depth 1, only subdirs, no images)
	# Type 1 = Leaf/Mixed gallery (has images, optionally subdirs)
	# Type 0 = Structure (depth 2+, only subdirs, no images)
	if [ "$node_depth" -eq 1 ] && [ "$dircount" -gt 0 ] && [ "$imagecount" -eq 0 ]
	then
		node_type=2 # column header (depth 1, only subdirs)
	elif [ "$dircount" -gt 0 ] && [ "$imagecount" -gt 0 ]
	then
		node_type=1 # mixed: contains both dirs and images, treat as leaf gallery
	elif [ "$dircount" -gt 0 ]
	then
		node_type=0 # structure: dir contains other dirs, it is not a leaf
	else
		node_type=1 # leaf: does not contain other dirs, it is a leaf
	fi
	
	paths+=("$node")
	nav_name+=("$node_name")
	nav_depth+=("$node_depth")
	nav_type+=("$node_type")
	
	# Debug output for navigation structure (simplified)
	# echo "    📁 Index ${#paths[@]}: $node_name (depth: $node_depth, type: $node_type, dirs: $dircount, images: $imagecount) -> $node"
done < <(find "$in_dir" -type d ! -path "$in_dir*/_*" | sort -V)  # Version sort for numeric prefixes

# re-create directory structure
mkdir -p "$out_dir"

dir_stack=()
url_rel=""

printf "\nPopulating nav\n   "

for i in "${!paths[@]}"
do
	echo -n " 📄"
	
	path="${paths[i]}"
	if [ "$i" -gt 0 ]
	then	
		if [ "${nav_depth[i]}" -gt "${nav_depth[i-1]}" ]
		then
			# push onto stack when we go down a level
			prev_url_rel=$(echo "${nav_name[i-1]}" | sed 's/[^ a-zA-Z0-9]//g;s/ /-/g' | tr '[:upper:]' '[:lower:]')
			# Don't push root directory (depth 0) onto stack
			if [ "${nav_depth[i-1]}" -gt 0 ]; then
				dir_stack+=("$prev_url_rel")
			fi
		elif [ "${nav_depth[i]}" -lt "${nav_depth[i-1]}" ]
		then
			# pop stack with respect to current level
			diff="${nav_depth[i-1]}"
			while [ "$diff" -gt "${nav_depth[i]}" ] && [ "${#dir_stack[@]}" -gt 0 ]
			do
				unset dir_stack[${#dir_stack[@]}-1]
				((diff--))
			done
		fi
	fi
	
	url_rel=$(echo "${nav_name[$i]}" | sed 's/[^ a-zA-Z0-9]//g;s/ /-/g' | tr '[:upper:]' '[:lower:]')
	
	url=""
	for u in "${dir_stack[@]}"
	do
		url+="$u/"
	done
	
	# Columns (type 2) don't get their own URL - they only exist in navigation
	if [ "${nav_type[i]}" -ne 2 ]; then
		url+="$url_rel"
	fi
	
	# Special handling for root directory
	if [ "${paths[$i]}" = "$in_dir" ]
	then
		nav_url+=("")  # index.html goes to root
		nav_image_url+=("$url_rel")  # but images go to subfolder
		mkdir -p "$out_dir"
		mkdir -p "$out_dir/$url_rel"
	elif [ "${nav_type[i]}" -eq 2 ]
	then
		# Columns don't get output directories or URLs
		nav_url+=("")
		nav_image_url+=("")
	else
		nav_url+=("$url")
		nav_image_url+=("$url")
		mkdir -p "$out_dir/$url"
	fi
done

printf "\nReading files"

# read in each file to populate $gallery variables
for i in "${!paths[@]}"
do
	nav_count[i]=-1  # ALLE directories bekommen erstmal -1, auch non-galleries!
	
	dir="${paths[i]}"
	name="${nav_name[i]}"
	url="${nav_url[i]}"
	
	# Check if directory has images - if not, skip processing but keep in nav structure
	image_count=$(find "$dir" -maxdepth 1 ! -path "$dir" ! -path "$dir*/_*" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.gif" -o -iname "*.png" -o -iname "*.bmp" -o -iname "*.webp" \) | wc -l)
	
	if [ "$image_count" -eq 0 ]; then
		nav_count[i]=0
		continue
	fi
	
	mkdir -p "$out_dir"/"$url"

	printf "\n    📂 $url"

	index=0

	# loop over found files
	while read file
	do
		
		filename=$(basename "$file")
		filedir=$(dirname "$file")
		filepath="$file"
		
		printf "\n        %s" "$filename"  # Show filename for better progress feedback
		# printf "."  # Alternative: fast progress dots
		
		# Extract filename without extension
		filename_base="${filename%.*}"
		
		# Combined trimming and URL generation (fewer process calls)
		if [[ "$filename_base" =~ ^[[:space:]0-9]*(.+) ]]; then
			trimmed="${BASH_REMATCH[1]}"
		else
			trimmed="$filename_base"
		fi
		
		# URL-safe conversion - use stable hash-based ID to avoid reordering issues
		base_name=$(echo "$trimmed" | sed 's/[^ a-zA-Z0-9]//g;s/ /-/g' | tr '[:upper:]' '[:lower:]')
		image_id=$(echo "${file##*/}_$(stat -c '%Y_%s' "$file" 2>/dev/null || stat -f '%m_%z' "$file" 2>/dev/null)" | md5sum | cut -c1-12)
		image_url="$image_id"  # Use stable hash-based ID
		
		# Extract and normalize extension (already filtered by find)
		extension="${filename##*.}"
		extension=$(echo "$extension" | tr '[:upper:]' '[:lower:]')
		format="$extension"	
		
		
		image="$file"
		
		# Get the width and height of the image using VIPS
		width=$(vipsheader -f width "$image" 2>/dev/null)
		height=$(vipsheader -f height "$image" 2>/dev/null)

		maxwidth=0
		maxheight=0
		count=0
		
		for res in "${resolution[@]}"
		do
			((count++))
			# store max values for later use
			if [ "$width" -ge "$res" ] && [ "$res" -gt "$maxwidth" ]
			then
				maxwidth="$res"
				maxheight=$((res*height/width))
			elif [ "$maxwidth" -eq 0 ] && [ "$count" = "${#resolution[@]}" ]
			then
				maxwidth="$res"
				maxheight=$((res*height/width))
			fi
		done
				
		((index++))
		
		# store file and type for later use
		# Use file modification time + size for fast, reliable cache key
		mdx="${file##*/}_$(stat -c '%Y_%s' "$file" 2>/dev/null || stat -f '%m_%z' "$file" 2>/dev/null)"
		gallery_files+=("$file")
		gallery_nav+=("$i")
		gallery_url+=("$image_url")
		gallery_md5+=("$mdx")
		gallery_maxwidth+=("$maxwidth")
		gallery_maxheight+=("$maxheight")

	done < <(find "$dir" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.bmp" -o -iname "*.webp" \) ! -path "$dir*/_*" | sort $image_sort_option)
	
	nav_count[i]="$index"
	
done

# build html file for each gallery
template=$(cat "$theme_dir/template.html" | tr -d '\n' | sed 's/>[[:space:]]*</></g')
post_template=$(cat "$theme_dir/post-template.html" | tr -d '\n' | sed 's/>[[:space:]]*</></g')
# Minify navigation templates to single line for sed compatibility
# This allows the template files to be nicely formatted while avoiding sed multi-line issues
nav_branch_template=$(cat "$theme_dir/nav-branch-template.html" | tr -d '\n' | sed 's/>[[:space:]]*</></g')
nav_leaf_template=$(cat "$theme_dir/nav-leaf-template.html" | tr -d '\n' | sed 's/>[[:space:]]*</></g')
nav_column_template=$(cat "$theme_dir/nav-column-template.html" | tr -d '\n' | sed 's/>[[:space:]]*</></g')

# Extract EXIF placeholders from post template once (optimization)
exif_placeholders_global=$(echo "$post_template" | grep -o '{{exif_[^}]*}}' | sed 's/{{exif_\([^:}]*\)[^}]*}}/\1/' | sort -u)

gallery_index=0

# Build main navigation ONCE (not for every gallery)
printf "\nBuilding Navigation"

# Build hierarchical navigation using depth-first search (adapted from Jack's algorithm)
navigation=""

# Create markers for template replacement in hierarchical structure
depth=1
prevdepth=0
remaining="${#paths[@]}"
parent=-1

while [ "$remaining" -gt 0 ]; do
    items_processed_this_depth=0
    
    for j in "${!paths[@]}"; do
        if [ "$depth" -gt 1 ] && [ "${nav_depth[j]}" = "$prevdepth" ]; then
            parent="$j"
        fi
        
        # Skip root directory in navigation
        if [ "${nav_depth[j]}" = 0 ]; then
            ((remaining--))
            continue
        fi
        
        if [ "${nav_depth[j]}" = "$depth" ]; then
            # Skip root gallery if show_home_in_nav is false
            if [ "${paths[j]}" = "$in_dir" ] && [ "$show_home_in_nav" = "false" ]; then
                ((remaining--))
                continue
            fi
            
            items_processed_this_depth=1
            
            if [ "$parent" -lt 0 ] && [ "${nav_depth[j]}" = 1 ]; then
                # Top level items (depth 1)
                if [ "${nav_type[j]}" = 2 ]; then
                    # Column header (type 2)
                    nav_item="$nav_column_template"
                    nav_item=$(template "$nav_item" text "${nav_name[j]}")
                    nav_item=$(template "$nav_item" children "{{marker$j}}")
                    navigation+="$nav_item"
                elif [ "${nav_type[j]}" = 0 ]; then
                    # Structure node (has children, no own gallery)
                    nav_item="$nav_branch_template"
                    nav_item=$(template "$nav_item" text "${nav_name[j]}")
                    nav_item=$(template "$nav_item" children "{{marker$j}}")
                    navigation+="$nav_item"
                else
                    # Gallery node (has own page)
                    nav_item="$nav_leaf_template"
                    nav_item=$(template "$nav_item" text "${nav_name[j]}")
                    nav_item=$(template "$nav_item" uri "{{basepath}}${nav_url[j]}")
                    nav_item=$(template "$nav_item" children "{{marker$j}}")
                    navigation+="$nav_item"
                fi
                ((remaining--))
            elif [ "${nav_depth[j]}" = "$depth" ]; then
                # Nested items - replace parent marker
                if [ "${nav_type[j]}" = 2 ]; then
                    # Column (shouldn't happen at nested level, but handle it)
                    nav_item="$nav_column_template"
                    nav_item=$(template "$nav_item" text "${nav_name[j]}")
                    nav_item=$(template "$nav_item" children "{{marker$j}}")
                    substring="$nav_item{{marker$parent}}"
                elif [ "${nav_type[j]}" = 0 ]; then
                    # Structure node
                    nav_item="$nav_branch_template"
                    nav_item=$(template "$nav_item" text "${nav_name[j]}")
                    nav_item=$(template "$nav_item" children "{{marker$j}}")
                    substring="$nav_item{{marker$parent}}"
                else
                    # Gallery node  
                    nav_item="$nav_leaf_template"
                    nav_item=$(template "$nav_item" text "${nav_name[j]}")
                    nav_item=$(template "$nav_item" uri "{{basepath}}${nav_url[j]}")
                    nav_item=$(template "$nav_item" children "{{marker$j}}")
                    substring="$nav_item{{marker$parent}}"
                fi
                navigation=$(template "$navigation" "marker$parent" "$substring")
                ((remaining--))
            fi
        fi
    done
    
    # If no items were processed at this depth, break the loop
    if [ "$items_processed_this_depth" = 0 ]; then
        break
    fi
    
    ((prevdepth++))
    ((depth++))
done

# Clean up remaining markers (empty children placeholders)
navigation=$(echo "$navigation" | sed 's/{{marker[^}]*}}//g')

# Pre-extract all EXIF data in batch for massive performance boost
printf "\nExtracting EXIF data in batch..."

# Create persistent cache directories
cache_dir="$topdir/.cache/$project"
exif_cache_dir="$cache_dir/exif"
html_cache_dir="$cache_dir/html"
mkdir -p "$exif_cache_dir" "$html_cache_dir"

# Check which images need EXIF extraction
images_to_process=()
for i in "${!gallery_files[@]}"; do
    file_path="${gallery_files[i]}"
    file_cache_key="${gallery_md5[i]}"  # Already contains timestamp+size
    exif_cache_path="$exif_cache_dir/$file_cache_key.json"
    
    # Check if EXIF cache exists and is current
    if [ ! -f "$exif_cache_path" ]; then
        images_to_process+=("$file_path")
    fi
done

# Extract EXIF data only for changed/new images
if [ ${#images_to_process[@]} -gt 0 ]; then
    printf " (%d new/changed)" "${#images_to_process[@]}"
    
    # Process in chunks to avoid memory issues with large datasets
    chunk_size=100
    for ((i=0; i<${#images_to_process[@]}; i+=chunk_size)); do
        chunk_files=()
        
        # Prepare chunk
        for ((j=i; j<i+chunk_size && j<${#images_to_process[@]}; j++)); do
            chunk_files+=("${images_to_process[j]}")
        done
        
        # Extract EXIF for chunk
        if [ ${#chunk_files[@]} -gt 0 ]; then
            # Extract to temporary file
            temp_json="$tmpdir/exif_chunk_$i.json"
            exiftool -j -s2 "${chunk_files[@]}" > "$temp_json" 2>/dev/null
            
            # Split JSON by image and cache individually using bash/grep/sed
            for file_path in "${chunk_files[@]}"; do
                filename=$(basename "$file_path")
                
                # Find cache path for this file
                for k in "${!gallery_files[@]}"; do
                    if [ "${gallery_files[k]}" = "$file_path" ]; then
                        file_cache_key="${gallery_md5[k]}"
                        exif_cache_path="$exif_cache_dir/$file_cache_key.json"
                        break
                    fi
                done
                
                # Extract this image's EXIF from chunk JSON using jq
                # Find the JSON object for this filename and save directly as object
                jq --arg filename "$filename" '.[] | select(.FileName == $filename)' "$temp_json" > "$exif_cache_path"
            done
            
            rm -f "$temp_json"
        fi
    done
else
    printf " (all cached)"
fi

# Combine all cached EXIF data into working file
exif_cache_file="$tmpdir/exif_data.json"
echo "[" > "$exif_cache_file"
first=true
for i in "${!gallery_files[@]}"; do
    file_cache_key="${gallery_md5[i]}"
    exif_cache_path="$exif_cache_dir/$file_cache_key.json"
    
    if [ -f "$exif_cache_path" ]; then
        if [ "$first" = true ]; then
            first=false
        else
            echo "," >> "$exif_cache_file"
        fi
        # Extract the image object (remove outer array brackets)
        sed '1d;$d' "$exif_cache_path" >> "$exif_cache_file"
    fi
done
echo "]" >> "$exif_cache_file"

printf " ✅"

printf "\nBuilding HTML"

# Count galleries to build (skip structure directories and columns)
total_galleries=0
for i in "${!paths[@]}"
do
	# Skip columns (type 2) and structures without images
	if [ "${nav_type[i]}" = 2 ]; then
		continue
	fi
	if [ "${nav_type[i]}" -ge 1 ] || [ "${nav_count[i]}" -gt 0 ]
	then
		((total_galleries++))
	fi
done

current_gallery=0
for i in "${!paths[@]}"
do
	# Skip columns (type 2) and structure directories without images
	if [ "${nav_type[i]}" = 2 ]; then
		continue
	fi
	if [ "${nav_type[i]}" -lt 1 ] && [ "${nav_count[i]}" -le 0 ]
	then
		continue
	fi

	((current_gallery++))
	
	# Display gallery name with progress counter
	if [ -z "${nav_url[i]}" ]; then
		printf "\n    [$current_gallery/$total_galleries] ${nav_name[i]} (${nav_count[i]} files)"
	else
		printf "\n    [$current_gallery/$total_galleries] ${nav_name[i]} (${nav_count[i]} files)"
	fi
	
	if [ "${nav_count[i]}" -lt 0 ] || [ "${nav_count[i]}" -gt 1000 ]; then
		echo "ERROR: Invalid nav_count[${i}] = ${nav_count[i]}"
		continue
	fi
	
	html="$template"
	
	gallery_metadata=""
	if [ -e "${paths[i]}/$metadata_file" ]
	then
		gallery_metadata=$(cat "${paths[i]}/$metadata_file")
	fi
	
	# Process gallery content.md if it exists
	gallery_content_body=""
	gallery_content_file="${paths[i]}/content.md"
	if [ -f "$gallery_content_file" ] && [ -s "$gallery_content_file" ]
	then
		# Read content.md
		gallery_content_text=$(cat "$gallery_content_file" | tr -d $'\r')
		gallery_content_text=${gallery_content_text%$'\n'}
		
		# Check for YAML metadata block (between --- lines)
		metaline=$(echo "$gallery_content_text" | grep -n -m 2 -- "^---$" | tail -1 | cut -d ':' -f1)
		
		if [ "$metaline" ]
		then
			# YAML block exists - extract metadata and content separately
			sumlines=$(echo "$gallery_content_text" | wc -l)
			taillines=$((sumlines-metaline))
			
			gallery_content_metadata=$(echo "$gallery_content_text" | head -n "$metaline")
			gallery_content_body=$(echo "$gallery_content_text" | tail -n "$taillines")
		else
			# No YAML block - everything is content
			gallery_content_metadata=""
			gallery_content_body="$gallery_content_text"
		fi
		
		# Parse Markdown to HTML (same way Jack does it for posts)
		if command -v perl >/dev/null 2>&1
		then
			gallery_content_body=$(perl "$scriptdir/markdown/markdown.pl" --html4tags <(echo "$gallery_content_body"))
		fi
	fi
	
	# Set gallerybody variable for Mustache section
	# Will be truthy only if content.md exists and has content
	if [ -n "$gallery_content_body" ]; then
		# Collapse multi-line HTML to single line (like expose.sh does for all templates)
		template_set "gallerybody" "$(printf '%s' "$gallery_content_body" | tr -d '\n')"
	else
		template_set "gallerybody" ""
	fi
	
	# Set images variable for Mustache section - only render gallery if images exist
	if [ "${nav_count[i]}" -gt 0 ]; then
		template_set "images" "yes"
	else
		template_set "images" ""
	fi
	
	j=0
	while [ "$j" -lt "${nav_count[i]}" ]
	do	

		k=$((j+1))
		file_path="${gallery_files[gallery_index]}"
		
		# try to find a text file with the same name
		filename=$(basename "$file_path")
		printf "\n        $filename" 
		
		filename="${filename%.*}"

		filedir=$(dirname "$file_path")
				
		# Cache directories are created earlier in the script

		textfile=$(find "$in_dir/$filename".txt "$in_dir/$filename".md ! -path "$file_path" -print -quit 2>/dev/null)
		
		metadata=""
		content=""
		if [ ! -e "$html_cache_dir/${gallery_md5[gallery_index]}" ] || [ "$no_html_cache" = true ]
		then
			if LC_ALL=C file "$textfile" | grep -q text
			then
				# if there are two lines "---", the lines preceding the second "---" are assumed to be metadata
				text=$(cat "$textfile" | tr -d $'\r')
				text=${text%$'\n'}
				metaline=$(echo "$text" | grep -n -m 2 -- "^---$" | tail -1 | cut -d ':' -f1)
							
				if [ "$metaline" ]
				then
					sumlines=$(echo "$text" | wc -l)
					taillines=$((sumlines-metaline))
					
					metadata=$(head -n "$metaline" "$textfile")
					content=$(tail -n "$taillines" "$textfile")
				else
					metadata=""
					content=$(echo "$text")
				fi
			fi
			
			exif_metadata=""
			# Extract only EXIF data that's actually used in templates
			filename=$(basename "$file_path")
			
			# Use pre-extracted EXIF placeholders (optimization)
			if [ -n "$exif_placeholders_global" ]; then
				# Find cache file for this image
				cache_file=""
				for k in "${!gallery_files[@]}"; do
					if [ "$(basename "${gallery_files[k]}")" = "$filename" ]; then
						file_cache_key="${gallery_md5[k]}"
						cache_file="$exif_cache_dir/$file_cache_key.json"
						break
					fi
				done
				
				if [ -f "$cache_file" ]; then
					# Extract all needed fields in one jq call
					fields_query=""
					old_IFS="$IFS"
					IFS=$'\n'
					for field in $exif_placeholders_global; do
						if [ -n "$fields_query" ]; then
							fields_query="$fields_query, "
						fi
						fields_query="$fields_query\"$field\": (.${field} // empty)"
					done
					IFS="$old_IFS"
					
					# Get all values in one jq call
					exif_data=$(jq -r "{$fields_query}" "$cache_file" 2>/dev/null)
					
					# Parse the result and build metadata
					old_IFS="$IFS"
					IFS=$'\n'
					for field in $exif_placeholders_global; do
						value=$(echo "$exif_data" | jq -r --arg field "$field" '.[$field] // empty' 2>/dev/null)
						if [ -n "$value" ] && [ "$value" != "null" ]; then
							exif_metadata+="exif_$field:$value"$'\n'
						fi
					done
					IFS="$old_IFS"
				fi
			fi

			metadata+=$'\n'
			metadata+="$gallery_metadata"
			metadata+=$'\n'
			metadata+="$exif_metadata"
			metadata+=$'\n'
			
			# if perl available, pass content through markdown parser
			if command -v perl >/dev/null 2>&1
			then
				content=$(perl "$scriptdir/markdown/markdown.pl" --html4tags <(echo "$content"))
			fi
			
			# write to post template and collect all variables for batch processing
			post="$post_template"
			
			# Collect all template variables
			template_vars=()
			template_vars+=("index:$k")
			template_vars+=("post:$content")
			
			# Process metadata and collect variables
			while read line
			do
				key=$(echo "$line" | cut -d ':' -f1 | tr -d $'\r\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
				value=$(echo "$line" | cut -d ':' -f2- | tr -d $'\r\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
				colon=$(echo "$line" | grep ':')

				if [ "$key" ] && [ "$value" ] && [ "$colon" ]
				then
					if [ "$key" = "exif_LensModel" ]; then
						value=$(echo $value | sed 's/ (.*)//')
					elif [ "$key" = "exif_Model" ]; then
						value=$(echo $value| sed -e 's/ILCE-7M4/α 7 IV/' -e 's/ILCE-7M3/α 7 III/' -e 's/ILCE-7M2/α 7 II/' -e 's/ILCE-7/α 7/' -e 's/ILCE-7RM5/α 7R V/' -e 's/ILCE-7RM4/α 7R IV/' -e 's/ILCE-7RM3/α 7R III/' -e 's/ILCE-7RM2/α 7R II/' -e 's/ILCE-7R/α 7R/' -e 's/ILCE-7SM3/α 7S III/' -e 's/ILCE-7SM2/α 7S II/' -e 's/ILCE-7S/α 7S/')
					fi
					template_vars+=("$key:$value")
				fi
			done < <(echo "$metadata")
			
			# Add image parameters - use URL hash for consistent ID
			template_vars+=("imagemd5:${gallery_url[gallery_index]}")
		template_vars+=("imageurl:${gallery_url[gallery_index]}")
		template_vars+=("imagewidth:${gallery_maxwidth[gallery_index]}")
		template_vars+=("imageheight:${gallery_maxheight[gallery_index]}")
		
		# Add gallery-level variables that are needed in post templates
		if [ "${nav_depth[i]}" = 0 ]; then
			basepath="./"
		else
			basepath=$(yes "../" 2>/dev/null | head -n ${nav_depth[i]} | tr -d '\n')
		fi
		
		if [ "${paths[i]}" = "$in_dir" ]; then
			resourcepath="home/"
		else
			resourcepath=""
		fi
		
		template_vars+=("basepath:$basepath")
		template_vars+=("resourcepath:$resourcepath")
		
		# Apply all template variables in one batch operation
		post=$(template_batch "$post" "${template_vars[@]}")
		
		# Write to cache only if HTML caching is enabled
		if [ "$no_html_cache" != true ]; then
			echo "$post" > "$html_cache_dir/${gallery_md5[gallery_index]}"
		fi

	else
			post=$(cat "$html_cache_dir/${gallery_md5[gallery_index]}")
		fi

		html=$(template "$html" content "$post {{content}}" true)
		
		((gallery_index++))
		((j++))
	done

	# Write html file - batch process all gallery-level template variables
	resolutionstring=$(printf "%s " "${resolution[@]}")
	
	# basepath and resourcepath are now handled in post templates, 
	# but we need them again for the main gallery template
	if [ "${nav_depth[i]}" = 0 ]; then
		basepath="./"
	else
		basepath=$(yes "../" 2>/dev/null | head -n ${nav_depth[i]} | tr -d '\n')
	fi
	
	if [ "${paths[i]}" = "$in_dir" ]; then
		resourcepath="home/"
	else
		resourcepath=""
	fi
	
	# Batch process all gallery template variables
	gallery_vars=(
		"sitetitle:$site_title"
		"sitedescription:$site_description"
		"siteauthor:$site_author"
		"sitekeywords:$site_keywords"
		"sitecopyright:$site_copyright"
		"navtitle:$nav_title"
		"gallerytitle:${nav_name[i]}"
		"resolution:$resolutionstring"
		"navigation:$navigation"
		"basepath:$basepath"
		"resourcepath:$resourcepath"
	)
	
	# Add gallery metadata as template variables
	while read line
	do
		key=$(echo "$line" | cut -d ':' -f1 | tr -d $'\r\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
		value=$(echo "$line" | cut -d ':' -f2- | tr -d $'\r\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
		colon=$(echo "$line" | grep ':')
		
		if [ "$key" ] && [ "$value" ] && [ "$colon" ]
		then
			gallery_vars+=("gallery_$key:$value")
		fi
	done < <(echo "$gallery_metadata")
	
	
	# Set all template variables and render with Mustache-Light engine
	template_set_batch "${gallery_vars[@]}"
	
	# Render template with Mustache sections, variables, and defaults
	html=$(template_render "$html")
	
	# Now replace {{active}} for the current page (after all other template processing)
	current_url="${nav_url[i]}"
	if [ -n "$current_url" ]; then
		# Find href with current URL and replace {{active}} with "active" in the same tag
		html=$(echo "$html" | sed "s|\(href=\"[^\"]*$current_url\"[^>]*\){{active}}|\1active|g")
	fi

	printf "\n        Write index.html"
	
	echo "$html" > "$out_dir/${nav_url[i]}"/index.html
done

# Conditional image encoding based on -s flag
if [ "$skip_images" = false ]; then
printf "\nEncoding images (parallel: $MAX_PARALLEL_IMAGES)\n"

# Get total count for progress display
total_images=${#gallery_files[@]}

# Function to process a single image with all its resolutions
process_image() {
    local i=$1
    local navindex="${gallery_nav[i]}"
    local url="${nav_image_url[navindex]}/${gallery_url[i]}"
    local filename=$(basename "${gallery_files[i]}")
    local image="${gallery_files[i]}"
    local current_num=$((i + 1))
    
    # Build progress message
    local progress_msg="    [$current_num/$total_images] ${nav_image_url[navindex]} - $filename"
    
    mkdir -p "$out_dir/$url"
    
    # Use /tmp for temp files (stable, no segfaults)
    local temp_dir="/tmp/expose_$$_$i"
    mkdir -p "$temp_dir"
    
    # Copy to temp using VIPS with retry
    local max_retries=3
    local copy_success=false
    for retry in $(seq 1 $max_retries); do
        if vips copy "$image" "$temp_dir/source_image.v" 2>/dev/null; then
            copy_success=true
            break
        fi
        sleep 0.1
        rm -f "$temp_dir/source_image.v"
    done
    
    if [ "$copy_success" = false ]; then
        echo "$progress_msg ✘ (copy failed)"
        rm -rf "$temp_dir"
        return 1
    fi
    
    local source_width=$(vipsheader -f width "$temp_dir/source_image.v" 2>/dev/null)
    if [ -z "$source_width" ] || [ "$source_width" -eq 0 ] 2>/dev/null; then
        echo "$progress_msg ✘ (invalid source)"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Track progress symbols
    local symbols=""
    local image_failed=false
    
    # Process each resolution with retry logic
    for res in "${resolution[@]}"; do
        local output_file="$out_dir/$url/$res.jpg"
        
        # Skip if already exists
        if [ -s "$output_file" ]; then
            symbols+=" »"
            continue
        fi
        
        # Calculate scale factor
        local scale_factor=$(echo "$res / $source_width" | bc -l)
        local temp_resized="$temp_dir/resized_$res.v"
        
        # Resize with VIPS - with retry on segfault
        local resize_success=false
        for retry in $(seq 1 $max_retries); do
            if vips resize "$temp_dir/source_image.v" "$temp_resized" $scale_factor 2>/dev/null; then
                resize_success=true
                break
            fi
            sleep 0.2
            rm -f "$temp_resized"
        done
        
        if [ "$resize_success" = false ]; then
            symbols+=" ✘"
            image_failed=true
            break
        fi
        
        # Save as JPEG - with retry
        local save_success=false
        for retry in $(seq 1 $max_retries); do
            if vips jpegsave "$temp_resized" "$output_file" --Q $jpeg_quality --optimize-coding --strip 2>/dev/null; then
                save_success=true
                break
            fi
            sleep 0.1
            rm -f "$output_file"
        done
        
        if [ "$save_success" = false ]; then
            symbols+=" ✘"
            image_failed=true
            break
        fi
        
        # Verify output
        if [ ! -s "$output_file" ]; then
            symbols+=" ✘"
            image_failed=true
            break
        fi
        
        symbols+=" ■"
    done
    
    # Cleanup temp directory
    rm -rf "$temp_dir"
    
    # Output result
    if [ "$image_failed" = true ]; then
        echo "$progress_msg$symbols ✘"
        return 1
    else
        echo "$progress_msg$symbols ✔"
        return 0
    fi
}

# Export function for parallel execution
export -f process_image
export out_dir jpeg_quality resolution gallery_nav gallery_files nav_image_url gallery_url total_images

# Process images in parallel batches
active_pids=()
for i in "${!gallery_files[@]}"; do
    # Start background process
    process_image "$i" &
    active_pids+=($!)
    
    # Wait when we hit max parallel limit
    if [ ${#active_pids[@]} -ge $MAX_PARALLEL_IMAGES ]; then
        # Wait for any process to finish
        wait -n 2>/dev/null || wait ${active_pids[0]} 2>/dev/null
        # Clean up finished processes from array
        new_pids=()
        for pid in "${active_pids[@]}"; do
            if kill -0 $pid 2>/dev/null; then
                new_pids+=($pid)
            fi
        done
        active_pids=("${new_pids[@]}")
    fi
done

# Wait for all remaining processes
for pid in "${active_pids[@]}"; do
    wait $pid 2>/dev/null
done

else
    printf "\nSkipping image encoding (use without -s to enable)\n"
fi # End of conditional encoding


printf "Copying resources"
# copy resources to output
rsync -av --exclude="template.html" --exclude="post-template.html" --exclude="nav-branch-template.html" --exclude="nav-leaf-template.html" --exclude="nav-column-template.html" --exclude="theme.config" "$theme_dir/" "$out_dir/" >/dev/null

printf "\n    ✅\n"

cleanup
