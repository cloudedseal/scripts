#!/bin/bash
set -euo pipefail

# ========= USAGE =========
# ./upload-maven.sh \
#   -r https://nexus.example.com/repository/maven-releases \
#   -u username \
#   -p password
# =========================

while getopts ":r:u:p:" opt; do
  case "$opt" in
    r) REPO_URL="${OPTARG%/}" ;;   # strip trailing slash
    u) USERNAME="$OPTARG" ;;
    p) PASSWORD="$OPTARG" ;;
    *) echo "Usage: $0 -r <repo_url> -u <user> -p <password>" && exit 1 ;;
  esac
done

if [[ -z "${REPO_URL:-}" || -z "${USERNAME:-}" || -z "${PASSWORD:-}" ]]; then
  echo "ERROR: Missing required arguments"
  exit 1
fi

echo "Uploading to repository:"
echo "  $REPO_URL"
echo

# Only valid Maven artifacts
find . -type f \( \
    -name "*.jar" \
    -o -name "*.pom" \
    -o -name "*.war" \
    -o -name "*.aar" \
    -o -name "*.zip" \
    -o -name "*.sha1" \
    -o -name "*.md5" \
\) \
! -name "maven-metadata*.xml*" \
! -name "_remote.repositories" \
! -name "*.lastUpdated" \
-print0 | while IFS= read -r -d '' file; do

    rel_path="${file#./}"

    echo "Uploading $rel_path"

    curl -u "$USERNAME:$PASSWORD" \
         --fail \
         --silent \
         --show-error \
         -T "$file" \
         "$REPO_URL/$rel_path"
done

echo
echo "✔ Upload complete"
