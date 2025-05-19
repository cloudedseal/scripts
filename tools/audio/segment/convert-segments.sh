#!/bin/bash

# Check for required tools
command -v ffprobe >/dev/null 2>&1 || { echo >&2 "ffprobe not found. Please install FFmpeg."; exit 1; }

# Usage
if [ $# -ne 2 ]; then
    echo "Usage: $0 <input_video> <segments_file>"
    exit 1
fi

input_video="$1"
segments_file="$2"
output_segments="segments_with_end.txt"
format="mp3"

# Arrays to store parsed data
start_times=()
output_names=()

# Function to convert seconds to HH:MM:SS
sec_to_hms() {
    local seconds="$1"
    local h=$(( seconds / 3600 ))
    local remainder=$(( seconds % 3600 ))
    local m=$(( remainder / 60 ))
    local s=$(( remainder % 60 ))
    printf "%02d:%02d:%02d\n" "$h" "$m" "$s"
}

# Get video duration in seconds
video_duration_seconds=$(ffprobe -v error -show_entries format=duration -of default=nw=1 "$input_video" 2>/dev/null)
if [ -z "$video_duration_seconds" ]; then
    echo "Error: Could not retrieve video duration." >&2
    exit 1
fi

# Convert video duration to HH:MM:SS
video_duration_hms=$(sec_to_hms "${video_duration_seconds%.*}")

# Read and parse segments file
while IFS= read -r line; do
    # Trim leading/trailing whitespace
    line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if [[ -z "$line" ]]; then
        continue # Skip empty lines
    fi

    # Split into start time and output name
    start_time_str=$(echo "$line" | awk '{print $1}')
    output_name=$(echo "$line" | awk '{$1=""; print substr($0, 2)}') # Handles spaces in filenames
    if [[ -z "$start_time_str" || -z "$output_name" ]]; then
        echo "Invalid line: $line" >&2
        exit 1
    fi

    start_times+=("$start_time_str")
    output_names+=("$output_name")
done < "$segments_file"

num_segments=${#start_times[@]}
if [ "$num_segments" -eq 0 ]; then
    echo "No valid segments found in $segments_file"
    exit 1
fi

# Generate output file
> "$output_segments"

for ((i = 0; i < num_segments; i++)); do
    current_start=${start_times[i]}
    
    if (( i < num_segments - 1 )); then
        current_end=${start_times[i+1]}
    else
        current_end="$video_duration_hms"
    fi

    current_name=${output_names[i]}
    echo "$current_start $current_end $current_name $format" >> "$output_segments"
done

echo "✅ New segments file created: $output_segments"