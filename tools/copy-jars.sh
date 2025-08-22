#!/bin/bash
# ref https://chat.qwen.ai/c/28bce67c-2b47-43b4-a545-e8e7b55e085b

# Check for correct number of arguments
if [ $# -ne 2 ]; then
    echo "Usage: $0 <source_directory> <destination_directory>"
    exit 1
fi

source_dir="$1"
dest_dir="$2"

# Validate source directory
if [ ! -d "$source_dir" ]; then
    echo "Error: Source directory '$source_dir' does not exist or is not a directory."
    exit 1
fi

# Create destination directory if it doesn't exist
if [ ! -d "$dest_dir" ]; then
    mkdir -p "$dest_dir" || {
        echo "Error: Failed to create destination directory '$dest_dir'"
        exit 1
    }
fi

# Find and copy all .jar files (case-insensitive)
find "$source_dir" -type f -iname '*.jar' -exec cp -f {} "$dest_dir" \;

echo "Successfully copied all .jar files from '$source_dir' to '$dest_dir'"
