#!/bin/bash

# audio_extractor - Extract audio from all video files in a directory or single file

# Check if FFmpeg is installed
if ! command -v ffmpeg &> /dev/null; then
    echo "Error: FFmpeg is not installed. Please install it first."
    exit 1
fi

# Usage instructions
usage() {
    echo "Usage: $0 [OPTIONS] <input_file_or_directory> [output_directory]"
    echo "Options:"
    echo "  -f, --format FORMAT   Output format: aac (default), mp3, wav"
    echo "  -h, --help            Show this help message"
    echo "Examples:"
    echo "  $0 -f aac \"镰仓殿的13人.mp4\""
    echo "  $0 -f mp3 ~/Videos ~/Audio"
    echo "  $0 -f wav ~/Videos"
    exit 1
}

# Parse command-line arguments
FORMAT="aac"
ARGS=()

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -f|--format)
            FORMAT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        -*)
            echo "Unknown option: $1"
            usage
            ;;
        *)
            ARGS+=("$1")
            shift
            ;;
    esac
done

# Assign input and output
INPUT="${ARGS[0]}"
OUTPUT_DIR="${ARGS[1]}"

# Validate input
if [[ -z "$INPUT" ]]; then
    echo "Error: Input file or directory not specified."
    usage
fi

# Check if input is valid
if [[ ! -e "$INPUT" ]]; then
    echo "Error: Input '$INPUT' does not exist."
    exit 1
fi

# Check if output directory is valid (if provided)
if [[ -n "$OUTPUT_DIR" && ! -d "$OUTPUT_DIR" ]]; then
    echo "Error: Output directory '$OUTPUT_DIR' does not exist."
    exit 1
fi

# Map format to file extension
case $FORMAT in
    aac)
        EXT="m4a"
        ;;
    mp3)
        EXT="mp3"
        ;;
    wav)
        EXT="wav"
        ;;
    *)
        echo "Error: Unsupported format '$FORMAT'."
        exit 1
        ;;
esac

# Function to extract audio from a single video
extract_audio() {
    local VIDEO="$1"
    local OUTPUT

    if [[ -n "$OUTPUT_DIR" ]]; then
        OUTPUT="$OUTPUT_DIR/$(basename "${VIDEO%.*}").$EXT"
    else
        OUTPUT="${VIDEO%.*}.$EXT"
    fi

    # Skip if output already exists
    if [[ -f "$OUTPUT" ]]; then
        echo "⚠️  Skipping: '$OUTPUT' already exists."
        return
    fi

    echo "🔄 Processing: '$VIDEO' -> '$OUTPUT'"
    case $FORMAT in
        aac)
            ffmpeg -i "$VIDEO" -vn -acodec copy "$OUTPUT" 2>/dev/null && \
                echo "✅ Copied AAC audio: '$OUTPUT'"
            ;;
        mp3)
            ffmpeg -i "$VIDEO" -vn -acodec libmp3lame -q:a 2 "$OUTPUT" 2>/dev/null && \
                echo "✅ Converted to MP3: '$OUTPUT'"
            ;;
        wav)
            ffmpeg -i "$VIDEO" -vn -acodec pcm_s16le "$OUTPUT" 2>/dev/null && \
                echo "✅ Converted to WAV: '$OUTPUT'"
            ;;
    esac
}

# Main processing logic
if [[ -f "$INPUT" ]]; then
    # Single file mode
    extract_audio "$INPUT"
elif [[ -d "$INPUT" ]]; then
    # Directory mode (flat, one level only)
    echo "📂 Processing directory: '$INPUT'"
    for VIDEO in "$INPUT"/*; do
        if [[ -f "$VIDEO" && "$VIDEO" =~ \.(mp4|mkv|avi|mov|flv|wmv|webm)$ ]]; then
            extract_audio "$VIDEO"
        else
            echo "🚫 Skipped non-video file: '$VIDEO'"
        fi
    done
fi