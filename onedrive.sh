#!/bin/bash

# OneDrive Folder Sync Script
# Downloads images from OneDrive shared folders maintaining original folder structure
# Uses Badger token authentication with Microsoft OneDrive API
#
# Usage: ./onedrive.sh -p <project> [-c <concurrency>] [-f]
# 
# Author: Expose Static Site Generator
# Version: 2.0

set -euo pipefail
IFS=$'\n\t'

# Script configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly BADGER_APP_ID="5cbed6ac-a083-4e14-b191-b4ba07653de2"
readonly ONEDRIVE_API_BASE="https://api.onedrive.com/v1.0"
readonly BADGER_API_BASE="https://api-badgerp.svc.ms/v1.0"

# Default values
FORCE_DOWNLOAD=false
CONCURRENCY=1
PROJECT=""
SHARE_URL=""

# Logging functions with colorful emojis
log_error() {
    echo "❌ $*" >&2
}

log_warn() {
    echo "⚠️  $*" >&2
}

log_debug() {
    if [[ "${DEBUG:-}" == "1" ]]; then
        echo "🔍 $*" >&2
    fi
}

# URL encode function for OneDrive paths (preserves forward slashes)
url_encode_path() {
    local string="$1"
    # Replace spaces with %20 and other special characters but preserve forward slashes
    echo "$string" | sed 's/ /%20/g' | sed 's/!/%21/g' | sed 's/"/%22/g' | sed 's/#/%23/g' | sed 's/\$/%24/g' | sed 's/&/%26/g' | sed "s/'/%27/g" | sed 's/(/%28/g' | sed 's/)/%29/g' | sed 's/\*/%2A/g' | sed 's/+/%2B/g' | sed 's/,/%2C/g'
}

# Function to check if required commands are installed
check_dependencies() {
    local missing_deps=()
    local required_commands=(curl jq base64 tr mkdir)
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_error "Please install missing commands and try again."
        exit 1
    fi
    
    log_debug "All dependencies satisfied"
}

# Function to validate project configuration
validate_project_config() {
    local project_folder="$1"
    local config_file="${project_folder}/config.sh"
    
    if [[ ! -d "$project_folder" ]]; then
        log_error "Project folder not found: $project_folder"
        return 1
    fi
    
    if [[ ! -f "$config_file" ]]; then
        log_error "Configuration file not found: $config_file"
        return 1
    fi
    
    # Source and validate config
    # shellcheck source=/dev/null
    source "$config_file"
    
    if [[ -z "${SHARE_URL:-}" ]]; then
        log_error "SHARE_URL not defined in $config_file"
        return 1
    fi
    
    log_debug "Project configuration validated: $project_folder"
    return 0
}

# Function to create the project input folder
create_project_folder() {
    local folder="$1"
    
    if [[ ! -d "$folder" ]]; then
        if ! mkdir -p "$folder"; then
            log_error "Failed to create directory: $folder"
            return 1
        fi
        log_debug "Created directory: $folder"
    fi
    
    return 0
}

# Function to encode OneDrive share URL for API usage
encode_share_url() {
    local share_url="$1"
    echo -n "$share_url" | base64 -w 0 | tr -d '=' | tr '/' '_' | tr '+' '-'
}

# Function to generate share ID from URL
get_share_id() {
    local share_url="$1"
    local encoded_url
    encoded_url=$(encode_share_url "$share_url")
    echo "u!${encoded_url}"
}

# Function to generate OneDrive API URL for root folder contents
get_root_api_url() {
    local share_url="$1"
    local share_id
    share_id=$(get_share_id "$share_url")
    
    echo "${ONEDRIVE_API_BASE}/shares/${share_id}/root/children?\$select=name,description,@content.downloadUrl,file,folder,id"
}

# Function to make authenticated API request
make_api_request() {
    local url="$1"
    local token="$2"
    local additional_headers="${3:-}"
    
    local curl_args=(-s -H "Authorization: Badger $token")
    
    if [[ -n "$additional_headers" ]]; then
        curl_args+=(-H "$additional_headers")
    fi
    
    local response
    if ! response=$(curl "${curl_args[@]}" "$url"); then
        log_error "Failed to make API request to: $url"
        return 1
    fi
    
    # Check if response is empty
    if [[ -z "$response" ]]; then
        log_error "Empty response from API: $url"
        return 1
    fi
    
    # Check if response is valid JSON
    if ! echo "$response" | jq empty 2>/dev/null; then
        log_error "Invalid JSON response from API: $url"
        log_debug "Response content: $(echo "$response" | head -c 200)..."
        return 1
    fi
    
    # Check for API errors
    if echo "$response" | jq -e '.error' >/dev/null 2>&1; then
        local error_message
        error_message=$(echo "$response" | jq -r '.error.message // "Unknown API error"')
        log_error "API Error: $error_message"
        return 1
    fi
    
    echo "$response"
}

# Function to get Badger token from Microsoft API
get_badger_token() {
    local response
    local token_data='{"appId":"'"$BADGER_APP_ID"'"}'
    
    log_debug "🔑 Requesting Badger token from Microsoft API"
    
    if ! response=$(curl -s -H "Content-Type: application/json" -d "$token_data" \
        "${BADGER_API_BASE}/token"); then
        log_error "Failed to connect to Badger token API"
        return 1
    fi
    
    if [[ -z "$response" ]]; then
        log_error "Empty response when retrieving Badger token"
        return 1
    fi
    
    # Extract and validate token
    local token
    if ! token=$(echo "$response" | jq -r '.token // empty' 2>/dev/null); then
        log_error "Failed to parse token response"
        return 1
    fi
    
    if [[ -z "$token" || "$token" == "null" ]]; then
        log_error "Invalid token received from API"
        return 1
    fi
    
    log_debug "✅ Successfully obtained Badger token"
    echo "$token"
}

# Function to extract image data from API response
extract_images_from_response() {
    local response="$1"
    local folder_path="${2:-}"
    
    local jq_filter='.value[]? | select(.file != null and .file.mimeType != null and (.file.mimeType | startswith("image/")))'
    local image_transform='{
        src: ."@content.downloadUrl",
        name: (.name | sub("\\.[^/.]+$"; "")),
        file: .name,
        description: (.description // ""),
        folder: $folder_path
    } | @base64'
    
    echo "$response" | jq -r --arg folder_path "$folder_path" "$jq_filter | $image_transform"
}

# Function to count images in API response
count_images_in_response() {
    local response="$1"
    echo "$response" | jq -r '.value[]? | select(.file != null and .file.mimeType != null and (.file.mimeType | startswith("image/"))) | .name' | wc -l
}

# Function to count folders in API response
count_folders_in_response() {
    local response="$1"
    echo "$response" | jq -r '.value[]? | select(.folder) | .name' | wc -l
}

# Function to fetch subfolder contents recursively using drive and folder IDs from share
fetch_folder_contents() {
    local folder_id="$1"
    local folder_name="$2" 
    local token="$3"
    local share_drive_id="$4"
    local share_folder_id="$5"
    local parent_path="${6:-}"  # Optional parent path for nested folders
    
    # Build full path for nested folders
    local full_path="$folder_name"
    if [[ -n "$parent_path" ]]; then
        full_path="${parent_path}/${folder_name}"
    fi
    
    # URL encode the path to handle spaces and special characters
    local encoded_path
    encoded_path=$(url_encode_path "$full_path")
    
    # Construct URL for subfolder contents using path-based addressing
    local url="${ONEDRIVE_API_BASE}/drives/${share_drive_id}/items/${share_folder_id}:/${encoded_path}:/children?\$select=name,description,@content.downloadUrl,file,folder,id"
    
    local response
    if ! response=$(make_api_request "$url" "$token"); then
        log_error "Failed to fetch contents of folder: $full_path"
        return 1
    fi
    
    # Debug: Check if response is valid JSON
    if ! echo "$response" | jq empty 2>/dev/null; then
        log_error "Invalid JSON response for folder '$full_path': $(echo "$response" | head -c 100)..."
        return 1
    fi
    
    # Count images and folders
    local image_count folder_count
    image_count=$(count_images_in_response "$response")
    folder_count=$(count_folders_in_response "$response")
    
    # Always show folder scan results, even for empty folders
    if [[ "$image_count" -gt 0 && "$folder_count" -gt 0 ]]; then
        echo "  $full_path: $image_count images, $folder_count folders" >&2
    elif [[ "$image_count" -gt 0 ]]; then
        echo "  $full_path: $image_count images" >&2
    elif [[ "$folder_count" -gt 0 ]]; then
        echo "  $full_path: $folder_count folders" >&2
    else
        echo "  $full_path: empty" >&2
    fi
    
    if [[ "$image_count" -gt 0 ]]; then
        extract_images_from_response "$response" "$full_path"
    else
        log_debug "No images found in folder: $full_path"
    fi
    
    # Process subfolders recursively
    local subfolder_data
    while IFS='|' read -r subfolder_id subfolder_name; do
        if [[ -n "$subfolder_id" && -n "$subfolder_name" ]]; then
            log_debug "Found subfolder: $subfolder_name in $full_path"
            if ! fetch_folder_contents "$subfolder_id" "$subfolder_name" "$token" "$share_drive_id" "$share_folder_id" "$full_path"; then
                log_warn "Failed to process subfolder: $full_path/$subfolder_name"
            fi
        fi
    done < <(echo "$response" | jq -r '.value[]? | select(.folder) | "\(.id)|\(.name)"')
    
    return 0
}

# Function to get share metadata for subfolder processing
get_share_metadata() {
    local share_url="$1"
    local token="$2"
    
    local share_id
    share_id=$(get_share_id "$share_url")
    
    local metadata_url="${ONEDRIVE_API_BASE}/shares/${share_id}/driveItem"
    local response
    
    if ! response=$(make_api_request "$metadata_url" "$token" "Prefer: autoredeem"); then
        log_warn "Could not fetch share metadata for subfolder processing"
        return 1
    fi
    
    echo "$response"
}

# Function to process subfolders from root response
process_subfolders() {
    local root_response="$1"
    local token="$2"
    local share_drive_id="$3"
    local share_folder_id="$4"
    
    local folder_data
    while IFS='|' read -r folder_id folder_name; do
        if [[ -n "$folder_id" && -n "$folder_name" ]]; then
            if ! fetch_folder_contents "$folder_id" "$folder_name" "$token" "$share_drive_id" "$share_folder_id"; then
                log_warn "Failed to process subfolder: $folder_name"
            fi
        fi
    done < <(echo "$root_response" | jq -r '.value[]? | select(.folder) | "\(.id)|\(.name)"')
}

# Function to recursively fetch all images from OneDrive folder structure
fetch_data_recursive() {
    local token="$1"
    
    local root_url
    root_url=$(get_root_api_url "$SHARE_URL")
    
    local root_response
    if ! root_response=$(make_api_request "$root_url" "$token"); then
        log_error "Failed to fetch root folder contents"
        return 1
    fi
    
    # Process images in root folder
    local root_image_count root_folder_count
    root_image_count=$(count_images_in_response "$root_response")
    root_folder_count=$(count_folders_in_response "$root_response")
    
    # Show root folder scan results
    if [[ "$root_image_count" -gt 0 && "$root_folder_count" -gt 0 ]]; then
        echo "  root: $root_image_count images, $root_folder_count folders" >&2
    elif [[ "$root_image_count" -gt 0 ]]; then
        echo "  root: $root_image_count images" >&2
    elif [[ "$root_folder_count" -gt 0 ]]; then
        echo "  root: $root_folder_count folders" >&2
    else
        echo "  root: empty" >&2
    fi
    
    if [[ "$root_image_count" -gt 0 ]]; then
        extract_images_from_response "$root_response" ""
    fi
    
    # Get share metadata for subfolder processing
    local share_metadata
    if share_metadata=$(get_share_metadata "$SHARE_URL" "$token"); then
        local share_drive_id share_folder_id
        share_drive_id=$(echo "$share_metadata" | jq -r '.parentReference.driveId // empty')
        share_folder_id=$(echo "$share_metadata" | jq -r '.id // empty')
        
        if [[ -n "$share_drive_id" && -n "$share_folder_id" ]]; then
            log_debug "Processing subfolders with drive ID: $share_drive_id"
            process_subfolders "$root_response" "$token" "$share_drive_id" "$share_folder_id"
        else
            log_warn "Could not extract drive/folder IDs from share metadata"
        fi
    else
        log_warn "Skipping subfolder processing due to metadata fetch failure"
    fi
}

# Function to activate Badger token by accessing the shared item
activate_badger_token() {
    local token="$1"
    local share_url="$2"
    
    local share_id
    share_id=$(get_share_id "$share_url")
    
    local activation_url="${ONEDRIVE_API_BASE}/shares/${share_id}/driveItem"
    
    log_debug "Activating Badger token"
    
    if ! make_api_request "$activation_url" "$token" "Prefer: autoredeem" >/dev/null; then
        log_error "Failed to activate Badger token with shared item"
        return 1
    fi
    
    log_debug "Badger token activated successfully"
    return 0
}

# Main function to fetch all image data from OneDrive
fetch_data() {
    echo "🔎 Scanning OneDrive folder structure:" >&2
    
    # Step 1: Get Badger token for authentication
    local token
    if ! token=$(get_badger_token); then
        log_error "Failed to obtain Badger authentication token"
        return 1
    fi
    
    # Step 2: Activate the token by accessing the shared item
    if ! activate_badger_token "$token" "$SHARE_URL"; then
        log_error "Failed to activate authentication token"
        return 1
    fi
    
    # Step 3: Recursively fetch all images from folder structure
    if ! fetch_data_recursive "$token"; then
        log_error "Failed to fetch image data from OneDrive"
        return 1
    fi
    
    echo "✅ Scan completed successfully" >&2
    return 0
}

# Function to decode base64 image data safely
decode_image_data() {
    local encoded_data="$1"
    
    if ! echo "$encoded_data" | base64 --decode 2>/dev/null; then
        log_error "Failed to decode image data"
        return 1
    fi
}

# Function to download a single image maintaining OneDrive folder structure
download_image() {
    local src="$1"
    local name="$2"
    local file="$3"
    local folder_path="$4"
    local project_input_folder="$5"
    
    # Determine target folder based on OneDrive structure
    local target_folder
    if [[ -n "$folder_path" ]]; then
        target_folder="${project_input_folder}/${folder_path}"
    else
        target_folder="${project_input_folder}"
    fi
    
    local target_file="${target_folder}/${file}"
    
    # Create subdirectory if needed
    if ! create_project_folder "$target_folder"; then
        log_error "Failed to create target folder: $target_folder"
        return 1
    fi
    
    # Check if file already exists and force download is not enabled
    if [[ "$FORCE_DOWNLOAD" != "true" && -f "$target_file" ]]; then
        log_debug "Skipped $file, already exists in ${folder_path:-root}"
        return 0
    fi
    
    # Download the image with error handling
    log_debug "Downloading $file from $src"
    
    if ! curl -s -o "$target_file" "$src"; then
        log_error "Failed to download: $file"
        return 1
    fi
    
    # Verify download was successful
    if [[ ! -f "$target_file" || ! -s "$target_file" ]]; then
        log_error "Download verification failed: $file"
        return 1
    fi
    
    return 0
}

# Function to process a single image entry
process_single_image() {
    local encoded_image="$1"
    local project_input_folder="$2"
    
    local decoded_data
    if ! decoded_data=$(decode_image_data "$encoded_image"); then
        log_error "Failed to decode image data"
        return 1
    fi
    
    # Extract image metadata using jq
    local src name file folder
    src=$(echo "$decoded_data" | jq -r '.src // empty')
    name=$(echo "$decoded_data" | jq -r '.name // empty') 
    file=$(echo "$decoded_data" | jq -r '.file // empty')
    folder=$(echo "$decoded_data" | jq -r '.folder // empty')
    
    # Validate required fields
    if [[ -z "$src" || -z "$file" ]]; then
        log_error "Invalid image data: missing src or file"
        return 1
    fi
    
    # Download the image
    if ! download_image "$src" "$name" "$file" "$folder" "$project_input_folder"; then
        log_error "Failed to download image: $file"
        return 1
    fi
    
    return 0
}



# Function to process single image for parallel execution (wrapper for xargs)
process_image_parallel() {
    local encoded_image="$1"
    local project_input_folder="$2"
    
    # Disable strict mode for subshells to handle errors gracefully
    set +e
    
    # This function will be called by xargs in parallel
    if ! process_single_image "$encoded_image" "$project_input_folder" 2>/dev/null; then
        echo "FAILED: $(echo "$encoded_image" | head -c 20)..." >&2
        return 1
    fi
    
    return 0
}

# Export functions and variables for parallel execution
export -f process_image_parallel
export -f process_single_image
export -f decode_image_data
export -f download_image
export -f create_project_folder
export -f log_error
export -f log_debug
export -f log_warn
export FORCE_DOWNLOAD
export DEBUG

# Function to download images in parallel with error handling
download_images_parallel() {
    local images="$1"
    local project_input_folder="$2"
    local concurrency="${3:-1}"
    
    local total_images=0
    
    # Count total images
    total_images=$(echo "$images" | grep -c .)
    
    if [[ "$total_images" -eq 0 ]]; then
        echo "  No images found to download" >&2
        return 0
    fi
    

    
    echo "⬇️  Downloading $total_images images" >&2
    
    # Simpler approach: Use parallel processing with immediate progress output  
    local image_array=()
    local pids=()
    local successful_downloads=0
    local failed_downloads=0
    local active_jobs=0
    local completed_downloads=0
    
    # Convert images to array for better handling
    while IFS= read -r image; do
        if [[ -n "$image" ]]; then
            image_array+=("$image")
        fi
    done <<< "$images"
    
    # Process images with controlled parallelism
    for image in "${image_array[@]}"; do
        # Wait if we've reached max concurrency
        while [[ "$active_jobs" -ge "$concurrency" ]]; do
            # Check for completed jobs
            for i in "${!pids[@]}"; do
                if ! kill -0 "${pids[i]}" 2>/dev/null; then
                    wait "${pids[i]}"
                    local exit_status=$?
                    if [[ "$exit_status" -eq 0 ]]; then
                        ((successful_downloads++))
                    else
                        ((failed_downloads++))
                    fi
                    unset "pids[i]"
                    ((active_jobs--))
                fi
            done
            sleep 0.1
        done
        
        # Extract filename and folder for progress display
        local decoded_data filename folder_path display_path
        if decoded_data=$(decode_image_data "$image" 2>/dev/null); then
            filename=$(echo "$decoded_data" | jq -r '.file // "unknown"' 2>/dev/null)
            folder_path=$(echo "$decoded_data" | jq -r '.folder // ""' 2>/dev/null)
            
            # Build display path
            if [[ -n "$folder_path" ]]; then
                display_path="${folder_path}/${filename}"
            else
                display_path="root/${filename}"
            fi
        else
            display_path="unknown"
        fi
        
        ((completed_downloads++))
        echo "  [$completed_downloads/$total_images] $display_path" >&2
        
        # Start background process
        {
            if process_single_image "$image" "$project_input_folder" 2>/dev/null; then
                # Success - no output needed, progress is visible from next download starting
                exit 0
            else
                echo "  ❌ Failed: $display_path" >&2
                exit 1
            fi
        } &
        
        pids+=($!)
        ((active_jobs++))
    done
    
    # Wait for all remaining jobs
    for pid in "${pids[@]}"; do
        if [[ -n "$pid" ]]; then
            wait "$pid"
            local exit_status=$?
            if [[ "$exit_status" -eq 0 ]]; then
                ((successful_downloads++))
            else
                ((failed_downloads++))
            fi
        fi
    done
    
    # Report results
    echo "✅ Download completed: $successful_downloads successful, $failed_downloads failed" >&2
    
    if [[ "$failed_downloads" -gt 0 ]]; then
        log_warn "Some parallel downloads failed. Check logs for details."
        return 1
    fi
    
    return 0
}

# Function to show usage information
show_usage() {
    cat << EOF
Usage: $(basename "$0") -p <project> [-c <concurrency>] [-f] [-d] [-h]

Download images from OneDrive shared folders maintaining original folder structure.

Options:
    -p <project>      Project name (required) - must have config.sh with SHARE_URL
    -c <concurrency>  Number of concurrent downloads (default: auto-optimized for I/O)
    -f                Force download (overwrite existing files)
    -d                Enable debug logging
    -h                Show this help message

Examples:
    $(basename "$0") -p example              # Auto-optimized concurrency
    $(basename "$0") -p example -c 8         # Force 8 parallel downloads  
    $(basename "$0") -p myproject -f -d      # Force download with debug
    
Project Structure:
    projects/<project>/config.sh    - Must contain SHARE_URL variable
    projects/<project>/input/       - Images will be downloaded here

Requirements:
    - curl, jq, base64, tr, mkdir commands
    - OneDrive share URL in project config file
    - Internet connection for API access
EOF
}

# Function to get default concurrency optimized for I/O-bound downloads
get_default_concurrency() {
    local nproc_count
    nproc_count=$(nproc 2>/dev/null || echo "2")
    
    # Downloads are I/O-bound, not CPU-bound
    # Minimum concurrency of 2 ensures better performance even on single-core
    # Optimal concurrency is higher than CPU cores for network downloads
    if [[ "$nproc_count" -eq 1 ]]; then
        echo "4"    # Even single-core can handle multiple downloads
    elif [[ "$nproc_count" -eq 2 ]]; then
        echo "6"    # Sweet spot for 2-core systems based on testing
    elif [[ "$nproc_count" -le 4 ]]; then
        echo "8"    # Good for 4-core systems
    else
        echo "10"   # High-end systems can handle more
    fi
}

# Function to parse and validate command-line arguments
parse_arguments() {
    local concurrency project force_download debug_mode
    
    # Set defaults
    concurrency=$(get_default_concurrency)
    project=""
    force_download="false"
    debug_mode="false"
    concurrency_specified="false"

    while getopts ":c:p:fdh" opt; do
        case $opt in
            c) 
                if [[ "$OPTARG" =~ ^[1-9][0-9]*$ ]]; then
                    concurrency="$OPTARG"
                    concurrency_specified="true"
                else
                    log_error "Invalid concurrency value: $OPTARG (must be positive integer)"
                    exit 1
                fi
                ;;
            p) 
                if [[ -n "$OPTARG" && "$OPTARG" != -* ]]; then
                    project="$OPTARG"
                else
                    log_error "Invalid project name: $OPTARG"
                    exit 1
                fi
                ;;
            f) force_download="true" ;;
            d) debug_mode="true" ;;
            h) show_usage; exit 0 ;;
            \?) 
                log_error "Invalid option: -$OPTARG"
                show_usage >&2
                exit 1 
                ;;
            :) 
                log_error "Option -$OPTARG requires an argument"
                show_usage >&2
                exit 1 
                ;;
        esac
    done
    
    # Validate required arguments
    if [[ -z "$project" ]]; then
        log_error "Project name is required (-p option)"
        show_usage >&2
        exit 1
    fi

    # Set global debug mode
    if [[ "$debug_mode" == "true" ]]; then
        export DEBUG=1
    fi

    # Return parsed values
    echo "$concurrency"
    echo "$project" 
    echo "$force_download"
    echo "$concurrency_specified"
}

# Main script execution
main() {
    # Handle help option early
    for arg in "$@"; do
        if [[ "$arg" == "-h" ]]; then
            show_usage
            exit 0
        fi
    done
    
    local concurrency project force_download concurrency_specified
    local project_folder project_input_folder
    
    # Parse command line arguments
    {
        read -r concurrency
        read -r project
        read -r force_download
        read -r concurrency_specified
    } <<< "$(parse_arguments "$@")"
    
    # Initialize and validate environment
    if ! check_dependencies; then
        exit 1
    fi
    
    # Adjust concurrency for optimal I/O performance
    local original_concurrency="$concurrency"
    if [[ "$concurrency" -eq 1 ]]; then
        concurrency=2
    fi
    
    # Set global variables
    PROJECT="$project"
    FORCE_DOWNLOAD="$force_download"
    CONCURRENCY="$concurrency"
    
    project_folder="${SCRIPT_DIR}/projects/${project}"
    project_input_folder="${project_folder}/input"
    
    echo "🌟 OneDrive Sync Script v2.0" >&2
    
    echo "⚙️  Configuration:" >&2
    echo "  Project: $project" >&2
    echo "  Project folder: $project_folder" >&2
    echo "  Input folder: $project_input_folder" >&2
    echo "  Force download: $force_download" >&2
    if [[ "$original_concurrency" -eq 1 && "$concurrency_specified" == "true" ]]; then
        echo "  Concurrency: $concurrency (auto-optimized from user-specified $original_concurrency for I/O performance)" >&2
    elif [[ "$concurrency_specified" == "true" ]]; then
        echo "  Concurrency: $concurrency (user-specified)" >&2
    else
        echo "  Concurrency: $concurrency (auto-detected from $(nproc) CPU cores)" >&2
    fi
    
    # Validate project configuration
    if ! validate_project_config "$project_folder"; then
        exit 1
    fi
    
    # Create input folder structure
    if ! create_project_folder "$project_input_folder"; then
        log_error "Failed to create project input folder"
        exit 1
    fi
    
    # Fetch image data from OneDrive
    local images
    if ! images=$(fetch_data); then
        log_error "Failed to fetch image data from OneDrive"
        exit 1
    fi
    
    # Download images
    if ! download_images_parallel "$images" "$project_input_folder" "$concurrency"; then
        log_error "Image download process completed with errors"
        exit 1
    fi
    
    echo "🎉 OneDrive sync completed successfully" >&2
}

# Script entry point with error handling
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    set -euo pipefail
    main "$@"
fi
