#!/usr/bin/env bash
set -euo pipefail

# =========================================================
# extract_audio.sh
# Wraps ffmpeg to detect audio codec & extract at max quality
# =========================================================

# --- Dependency Check ---
for cmd in ffmpeg ffprobe; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "Error: '$cmd' is not installed. Please install FFmpeg first."; exit 1; }
done

# --- Usage & Input Validation ---
if [ $# -lt 1 ]; then
    echo "Usage: $0 <video_file>"
    exit 1
fi

INPUT="$1"
if [ ! -f "$INPUT" ]; then
    echo "Error: File '$INPUT' not found."
    exit 1
fi

# --- Audio Detection ---
# Get the codec name of the first audio stream (a:0)
CODEC=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$INPUT")

if [ -z "$CODEC" ]; then
    echo "Error: No audio stream detected in '$INPUT'."
    exit 1
fi

echo "🎵 Detected audio codec: $CODEC"

# --- Quality & Format Selection Logic ---
# Strategy: 
# 1. Lossy codecs → Stream copy (-c:a copy) to avoid generational quality loss
# 2. Lossless/PCM/Unknown → Encode to FLAC (lossless compression, universal compatibility)
case "$CODEC" in
    flac|alac|wavpack|truehd|dtshd_ma|dtshd_hra|pcm_*)
        OUT_CODEC="-c:a flac -compression_level 12"
        OUT_EXT="flac"
        echo "✅ Lossless/PCM detected. Converting to FLAC (bit-perfect, high compatibility)."
        ;;
    aac|aac_he|aac_he_v2)
        OUT_CODEC="-c:a copy"
        OUT_EXT="m4a"
        echo "✅ AAC detected. Stream copying (original quality preserved)."
        ;;
    mp3)
        OUT_CODEC="-c:a copy"
        OUT_EXT="mp3"
        echo "✅ MP3 detected. Stream copying (original quality preserved)."
        ;;
    opus)
        OUT_CODEC="-c:a copy"
        OUT_EXT="opus"
        echo "✅ Opus detected. Stream copying (original quality preserved)."
        ;;
    vorbis)
        OUT_CODEC="-c:a copy"
        OUT_EXT="ogg"
        echo "✅ Vorbis detected. Stream copying (original quality preserved)."
        ;;
    ac3|eac3|dts)
        OUT_CODEC="-c:a copy"
        OUT_EXT="$CODEC"
        echo "✅ $CODEC detected. Stream copying (original quality preserved)."
        ;;
    *)
        OUT_CODEC="-c:a flac -compression_level 12"
        OUT_EXT="flac"
        echo "⚠️  Unknown codec ('$CODEC'). Re-encoding to high-quality FLAC."
        ;;
esac

# --- Output Filename Generation ---
BASENAME="${INPUT%.*}"
OUTPUT="${BASENAME}.${OUT_EXT}"

if [ -f "$OUTPUT" ]; then
    echo "⚠️  Output file already exists: $OUTPUT"
    read -p "Overwrite? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
fi

# --- Extraction ---
echo "🚀 Extracting audio to: $OUTPUT"
ffmpeg -i "$INPUT" -vn -map 0:a:0 -loglevel warning $OUT_CODEC "$OUTPUT"

echo "🎉 Done. Audio extracted successfully."