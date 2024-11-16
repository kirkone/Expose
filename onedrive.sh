#!/bin/bash

# Enable strict mode
set -euo pipefail
IFS=$'\n\t'

FORCE_DOWNLOAD=false

# Function to check if required commands are installed
check_dependencies() {
    for cmd in curl jq xargs base64 tr; do
        if ! command -v "$cmd" &> /dev/null; then
            echo "Error: $cmd is not installed." >&2
            exit 1
        fi
    done
}

# Function to create the project folder if it doesn't exist
create_project_folder() {
    mkdir -p "$PROJECT_INPUT_FOLDER"
}

# Function to generate OneDrive API URL from share link
get_api_url() {
    local share="$1"
    local ondrive_uri_encoded
    ondrive_uri_encoded=$(echo -n "$share" | base64 -w 0 | tr -d '=' | tr '/' '_' | tr '+' '-')
    local share_id="u!${ondrive_uri_encoded}"
    local url="https://api.onedrive.com/v1.0/shares/${share_id}/root/children?\$top=2147483647&\$filter=startswith(file/mimeType,%27image%27)&\$select=name,description,image,photo,@content.downloadUrl&\$orderby=photo/takenDateTime%20asc"
    
    echo "$url"
}

# Function to fetch data from OneDrive
fetch_data() {
    local url
    url=$(get_api_url "$SHARE_URL")

    local response
    response=$(curl -s "$url")
    if [ $? -ne 0 ]; then
        echo "Error: Failed to fetch data from OneDrive." >&2
        exit 1
    fi

    echo "$response"
}

# Function to process the JSON response
process_images() {
    local response="$1"
    echo "$response" | jq -r '.value[] | {
        src: ."@content.downloadUrl",
        name: (.name | sub("\\.[^/.]+$"; "")),
        file: .name,
        description: .description,
        date: .photo.takenDateTime
    } | @base64'
}

# Function to download an image
download_image() {
    local src="$1"
    local name="$2"
    local file="$3"
    local date="$4"
    local year=$(echo "$date" | cut -d'-' -f1)
    local folder="${PROJECT_INPUT_FOLDER}/${year}"

    # Ensure subdirectory exists
    mkdir -p "$folder"

    if [ "$FORCE_DOWNLOAD" = true ] || [ ! -f "${folder}/${file}" ]; then
        # Download the image
        curl -s -o "${folder}/${file}" "$src"
        echo "Downloaded ${file}"
    else
        echo "Skipped ${file}, already exists."
    fi
}

# Export the download_image function and necessary variables to make them available in subshells
export -f download_image
export PROJECT_INPUT_FOLDER
export FORCE_DOWNLOAD

# Function to download images in parallel
download_images_parallel() {
    local images="$1"
    local concurrent_processes="$2"

    echo "$FORCE_DOWNLOAD"

    echo "$images" | while read -r image; do
        echo "$image" | base64 --decode | jq -r '.src, .name, .file, .date'
    done | xargs -n 4 -P "$concurrent_processes" bash -c '
        download_image "$0" "$1" "$2" "$3"
    '
}

# Function to determine the number of concurrent processes
get_default_concurrency() {
    echo $(( $(nproc) - 1 ))
}

# Function to parse command-line arguments
parse_arguments() {
    local concurrency
    local project
    local force_download=false

    concurrency=$(get_default_concurrency)
    project=""

    while getopts ":c:p:f" opt; do
        case $opt in
            c) concurrency=$OPTARG ;;
            p) project=$OPTARG ;;
            f) force_download=true ;;
            \?) echo "Invalid option: -$OPTARG" >&2; exit 1 ;;
            :) echo "Option -$OPTARG requires an argument." >&2; exit 1 ;;
        esac
    done

    echo "$concurrency"
    echo "$project"
    echo "$force_download"
}

# Main script execution
main() {
    check_dependencies
    {
        read -r concurrency
        read -r project
        read -r force_download
    } <<< "$(parse_arguments "$@")"
    PROJECT_FOLDER="projects/$project"
    PROJECT_INPUT_FOLDER="$PROJECT_FOLDER/input"
    FORCE_DOWNLOAD=$force_download
    
    # Debugging: Check values of variables
    echo "Concurrency: $concurrency"
    echo "Project: $project"
    echo "Project Folder: $PROJECT_FOLDER"
    echo "Project Input Folder: $PROJECT_INPUT_FOLDER"
    echo "Force Download: $FORCE_DOWNLOAD"

    # Source the configuration file from the project folder
    if [ ! -f "${PROJECT_FOLDER}/config.sh" ]; then
        echo "Error: Configuration file not found in ${PROJECT_FOLDER}." >&2
        exit 1
    fi
    source "${PROJECT_FOLDER}/config.sh"
    
    create_project_folder
    response=$(fetch_data)
    images=$(process_images "$response")

    # Process and download images in parallel
    echo "--- Processing remote images ---"
    download_images_parallel "$images" "$concurrency"
    echo "--- Done ---"
}

main "$@"
