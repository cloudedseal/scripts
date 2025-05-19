#!/bin/bash

# Check for required tools
command -v ffmpeg >/dev/null 2>&1 || { echo >&2 "ffmpeg not found. Please install FFmpeg."; exit 1; }

if [ $# -ne 2 ]; then
    echo "Usage: $0 <input_video> <segments_file>"
    exit 1
fi

input_video="$1"
segments_file="$2"

# Count total segments
total_segments=$(wc -l < "$segments_file")
current_segment=0

# Function to draw progress bar
draw_progress_bar() {
    local progress=$1
    local filename=$2
    local width=40
    local filled=$(( progress * width / 100 ))
    local empty=$(( width - filled ))

# \r               Carrage return, overwrites the current line (live updates the bar)
# \033[K           Clears from cursor to end of line (removes old text)
# %-${width}s      Ensures the bar stays exactly 40 characters wide
# printf '#%.0s'   Efficient way to repeat a character multiple times
# $(seq 1 $filled) Generates the correct number of # characters
# "%3d%%"          Ensures percentage is always 3 digits (e.g.,0%,45%,100%)

    printf "\r\033[K\033[32m[%-${width}s]\033[0m \033[1m%3d%%\033[0m - %s" \
    "$(printf '#%.0s' $(seq 1 $filled))" "$progress" "$filename"
    sleep 0.05
}

# Function to map format to encoder
get_encoder() {
    case "$1" in
        mp3) echo "libmp3lame" ;;
        aac) echo "aac" ;;
        opus) echo "libopus" ;;
        flac) echo "flac" ;;
        wav) echo "pcm_s16le" ;;
        *) echo "libmp3lame" ;;
    esac
}

# Validate format
validate_format() {
    case "$1" in
        mp3|aac|opus|flac|wav) return 0 ;;
        *) return 1 ;;
    esac
}

# Open segments file on a dedicated file descriptor
exec 3< "$segments_file"

line_number=0
while IFS= read -r -u 3 line; do
    ((line_number++))
    line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if [[ -z "$line" ]]; then
        echo "Line $line_number: SKIPPED (empty)" >&2
        continue
    fi

    # Extract fields
    start_time=$(echo "$line" | awk '{print $1}')
    end_time=$(echo "$line" | awk '{print $2}')
    format=$(echo "$line" | awk '{print $NF}')
    output_name=$(echo "$line" | awk '{ $1=$2=""; $NF=""; sub(/^  /, ""); sub(/ $/, ""); print }')

    # Validate fields
    if [[ -z "$start_time" || -z "$end_time" || -z "$output_name" || -z "$format" ]]; then
        echo "Line $line_number: INVALID ('$line')" >&2
        continue
    fi

    if ! validate_format "$format"; then
        echo "Line $line_number: Unsupported format '$format'" >&2
        continue
    fi

    # Build output filename
    output_file="${output_name}.${format}"
    encoder=$(get_encoder "$format")

    ((current_segment++))
    progress=$(( current_segment * 100 / total_segments ))

    draw_progress_bar "$progress" "$output_file"

    # Check if output file already exists

    if [[ -e "$output_file" ]]; then
        echo -e "\n⚠️  File already exists: $output_file"
        continue
    fi

    ffmpeg -i "$input_video" \
           -ss "$start_time" \
           -to "$end_time" \
           -vn \
           -c:a "$encoder" \
           -q:a 2 \
           "$output_file" > /dev/null 2>&1 || {
        echo -e "\n❌ Failed to extract: $output_file" >&2
        exit 1
    }
done

# Close file descriptor
exec 3<&-
echo -e "\n🏁 All segments extracted successfully."