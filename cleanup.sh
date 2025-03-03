#!/bin/bash

# Function to display usage
usage() {
    echo "Usage: $0 -p <projectname>"
    exit 1
}

# Parse command line arguments
while getopts ":p:" opt; do
    case ${opt} in
        p )
            projectname=$OPTARG
            ;;
        \? )
            usage
            ;;
    esac
done

# Check if project name is provided
if [ -z "$projectname" ]; then
    usage
fi

# Define the directories to be deleted
cache_dir=".cache/$projectname"
output_dir="output/$projectname"

# Delete the directories
if [ -d "$cache_dir" ]; then
    rm -rf "$cache_dir"
    echo "Deleted $cache_dir"
else
    echo "$cache_dir does not exist"
fi

if [ -d "$output_dir" ]; then
    rm -rf "$output_dir"
    echo "Deleted $output_dir"
else
    echo "$output_dir does not exist"
fi
