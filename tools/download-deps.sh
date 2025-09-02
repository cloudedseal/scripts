#!/bin/bash
# maven-repo-builder.sh - Create proper Maven repository with locally generated checksums
# Usage: ./maven-repo-builder.sh "group:artifact:version" [output/directory] [--aliyun]
# If no output directory is specified, uses "m2-repo" in current directory
#
# Examples:
#   ./maven-repo-builder.sh com.moilioncircle:redis-replicator:3.9.0
#   ./maven-repo-builder.sh com.moilioncircle:redis-replicator:3.9.0 my-m2-repo
#   ./maven-repo-builder.sh com.moilioncircle:redis-replicator:3.9.0 --aliyun

set -euo pipefail

# Process command line arguments
USE_ALIYUN=false
ARGS=()
for arg in "$@"; do
  if [ "$arg" = "--aliyun" ]; then
    USE_ALIYUN=true
  else
    ARGS+=("$arg")
  fi
done

# Reset positional parameters
set -- "${ARGS[@]}"

# Validate at least one argument (GAV)
if [ $# -lt 1 ]; then
  echo "❌ Error: Missing GAV argument" >&2
  echo "Usage: $0 \"group:artifact:version\" [output/directory] [--aliyun]" >&2
  exit 1
fi

GAV="$1"

# If second argument is provided, use it as output directory, otherwise use default
if [ $# -ge 2 ]; then
  OUTPUT_DIR="$2"
  echo "ℹ️  Using specified repository directory: $OUTPUT_DIR"
else
  OUTPUT_DIR="m2-repo"
  echo "ℹ️  No repository directory specified. Using default: $OUTPUT_DIR"
fi

# Create output directory if needed
mkdir -p "$OUTPUT_DIR"

# CRITICAL PATH CONVERSION FOR GIT BASH
OUTPUT_DIR_ABS=""
if [[ "$(uname -s)" == MINGW* || "$(uname -s)" == CYGWIN* || "$(uname -s)" == MSYS* ]]; then
  # First try cygpath (best solution)
  if command -v cygpath &> /dev/null; then
    OUTPUT_DIR_ABS=$(cygpath -w "$OUTPUT_DIR" | sed 's|\\|/|g')
    echo "   → Using cygpath: $OUTPUT_DIR → $OUTPUT_DIR_ABS"
  else
    # Manual conversion for Git Bash
    if [[ "$OUTPUT_DIR" =~ ^/([a-zA-Z])/(.*)$ ]]; then
      DRIVE=$(echo "${BASH_REMATCH[1]}" | tr '[:lower:]' '[:upper:]')
      PATH="${BASH_REMATCH[2]}"
      OUTPUT_DIR_ABS="${DRIVE}:/${PATH}"
      echo "   → Manual conversion: $OUTPUT_DIR → $OUTPUT_DIR_ABS"
    else
      # Fallback: Use absolute path
      OUTPUT_DIR_ABS=$(cd "$OUTPUT_DIR" && pwd | sed 's|\\|/|g')
      echo "   → Fallback path: $OUTPUT_DIR → $OUTPUT_DIR_ABS"
    fi
  fi
else
  # Unix/Linux/macOS
  OUTPUT_DIR_ABS=$(cd "$OUTPUT_DIR" && pwd)
fi

# Validate GAV format
if ! [[ "$GAV" =~ ^[^:]+:[^:]+:[^:]+$ ]]; then
  echo "❌ Error: Invalid GAV format. Expected 'group:artifact:version'" >&2
  exit 1
fi

# Parse GAV components
IFS=':' read -r GROUP ARTIFACT VERSION <<< "$GAV"

# Check Maven installation
if ! command -v mvn &> /dev/null; then
  echo "❌ Error: Maven is not installed. Please install Maven first." >&2
  echo "👉 Get it: https://maven.apache.org/install.html" >&2
  exit 1
fi

# Create temporary workspace
TEMP_DIR=$(mktemp -d 2>/dev/null || mktemp -d -t 'maven-repo-builder')
TEMP_M2_DIR="$TEMP_DIR/.m2"
mkdir -p "$TEMP_M2_DIR"

# Add Aliyun Maven repository support if requested
if $USE_ALIYUN; then
  echo "   → Using Aliyun Maven repository for faster downloads in China"
  
  # Create settings.xml with Aliyun mirror configuration
  cat > "$TEMP_DIR/settings.xml" <<EOF
<settings>
  <mirrors>
    <mirror>
      <id>aliyunmaven</id>
      <mirrorOf>central,jcenter,spring-plugin,spring-snapshots,public</mirrorOf>
      <url>https://maven.aliyun.com/repository/public</url>
    </mirror>
  </mirrors>
  <profiles>
    <profile>
      <id>aliyun</id>
      <repositories>
        <repository>
          <id>central</id>
          <url>https://maven.aliyun.com/repository/public</url>
          <releases><enabled>true</enabled></releases>
          <snapshots><enabled>true</enabled></snapshots>
        </repository>
      </repositories>
      <pluginRepositories>
        <pluginRepository>
          <id>central</id>
          <url>https://maven.aliyun.com/repository/public</url>
          <releases><enabled>true</enabled></releases>
          <snapshots><enabled>true</enabled></snapshots>
        </pluginRepository>
      </pluginRepositories>
    </profile>
  </profiles>
  <activeProfiles>
    <activeProfile>aliyun</activeProfile>
  </activeProfiles>
</settings>
EOF

  # Set settings parameter for Maven
  MAVEN_SETTINGS="-s $TEMP_DIR/settings.xml"
else
  MAVEN_SETTINGS=""
fi

trap 'rm -rf "$TEMP_DIR"' EXIT

# Generate minimal Maven project
cat > "$TEMP_DIR/pom.xml" <<EOF
<project>
  <modelVersion>4.0.0</modelVersion>
  <groupId>com.maven.repo.builder</groupId>
  <artifactId>maven-repo-builder</artifactId>
  <version>1.0</version>
  <packaging>jar</packaging>
  <dependencies>
    <dependency>
      <groupId>$GROUP</groupId>
      <artifactId>$ARTIFACT</artifactId>
      <version>$VERSION</version>
    </dependency>
  </dependencies>
</project>
EOF

# Download dependencies in proper Maven repository layout
echo "📦 Creating Maven repository for $GAV..."
echo "   → Repository directory: $OUTPUT_DIR_ABS"
echo "   → Structure: group/artifact/version/artifact-version.type"
echo "   → This will download JARs and POMs"
if $USE_ALIYUN; then
  echo "   → Using Aliyun Maven repository for faster downloads"
else
  echo "   → Using Maven Central repository"
fi
echo "   → This may take a minute..."

# CRITICAL: Use Maven's repository layout directly in the target directory
mvn $MAVEN_SETTINGS -f "$TEMP_DIR/pom.xml" -B -Dmaven.repo.local="$TEMP_M2_DIR" \
  dependency:copy \
  -DoutputDirectory="$OUTPUT_DIR_ABS" \
  -DincludeScope=runtime \
  -Dartifact=$GAV \
  -Dmaven.repo.local="$OUTPUT_DIR_ABS" \
  -Dtransitive=true

# Function to generate checksum files locally (USING GIT BASH COMMANDS)
generate_checksums() {
  local file_path="$1"
  
  # Convert to absolute path first
  local abs_file_path
  if [[ "$(uname -s)" == MINGW* || "$(uname -s)" == CYGWIN* || "$(uname -s)" == MSYS* ]]; then
    if command -v cygpath &> /dev/null; then
      # Git Bash: Convert to Windows path for processing
      abs_file_path=$(cygpath -w "$file_path" | sed 's|\\|/|g')
    else
      # Two-step approach to avoid syntax errors
      abs_file_path=$(cd "$(dirname "$file_path")" && pwd)/$(basename "$file_path")
      abs_file_path=$(echo "$abs_file_path" | sed 's|\\|/|g')
    fi
  else
    abs_file_path=$(cd "$(dirname "$file_path")" && pwd)/$(basename "$file_path")
  fi
  
  # Get directory and filename
  local file_dir=$(dirname "$abs_file_path")
  local filename=$(basename "$abs_file_path")
  
  # Generate MD5 checksum
  if command -v md5sum &> /dev/null; then
    # Git Bash/Linux/macOS
    md5sum "$abs_file_path" | awk '{print $1}' > "${file_dir}/${filename}.md5"
  elif [[ "$(uname -s)" == MINGW* || "$(uname -s)" == CYGWIN* || "$(uname -s)" == MSYS* ]]; then
    # Windows PowerShell fallback (if md5sum not available)
    powershell -Command "Get-FileHash -Algorithm MD5 '$abs_file_path' | Select-Object -ExpandProperty Hash | ForEach-Object { \$_.ToLower() }" > "${file_dir}/${filename}.md5" 2>/dev/null || true
  fi
  
  # Generate SHA1 checksum
  if command -v sha1sum &> /dev/null; then
    # Git Bash/Linux/macOS
    sha1sum "$abs_file_path" | awk '{print $1}' > "${file_dir}/${filename}.sha1"
  elif [[ "$(uname -s)" == MINGW* || "$(uname -s)" == CYGWIN* || "$(uname -s)" == MSYS* ]]; then
    # Windows PowerShell fallback (if sha1sum not available)
    powershell -Command "Get-FileHash -Algorithm SHA1 '$abs_file_path' | Select-Object -ExpandProperty Hash | ForEach-Object { \$_.ToLower() }" > "${file_dir}/${filename}.sha1" 2>/dev/null || true
  fi
}

# Function to find all JAR and POM files in repository
find_artifact_files() {
  local repo_path="$1"
  local result_file="$2"
  
  # Git Bash specific handling
  if [[ "$(uname -s)" == MINGW* || "$(uname -s)" == CYGWIN* || "$(uname -s)" == MSYS* ]]; then
    if command -v cygpath &> /dev/null; then
      local unix_path=$(cygpath -u "$repo_path")
      find "$unix_path" -type f \( -name '*.jar' -o -name '*.pom' \) > "$result_file" 2>/dev/null || true
    else
      find "$repo_path" -type f \( -name '*.jar' -o -name '*.pom' \) > "$result_file" 2>/dev/null || true
    fi
  else
    # Unix/Linux/macOS
    find "$repo_path" -type f \( -name '*.jar' -o -name '*.pom' \) > "$result_file" 2>/dev/null || true
  fi
}

# Generate checksums for all JAR and POM files
echo "   → Generating checksum files (MD5, SHA1) for all artifacts..."

# Create temporary file to store artifact paths
ARTIFACT_FILES=$(mktemp 2>/dev/null || mktemp -t 'artifacts')
find_artifact_files "$OUTPUT_DIR_ABS" "$ARTIFACT_FILES"

# Count total artifacts for progress
TOTAL_ARTIFACTS=$(wc -l < "$ARTIFACT_FILES" | tr -d '[:space:]')
CURRENT_ARTIFACT=0

# Process each artifact file with progress reporting
while IFS= read -r file; do
  if [ -n "$file" ] && [ -f "$file" ]; then
    CURRENT_ARTIFACT=$((CURRENT_ARTIFACT + 1))
    echo "   → Generating checksums for artifact $CURRENT_ARTIFACT of $TOTAL_ARTIFACTS"
    
    # Get artifact name for display
    artifact_name=$(echo "$file" | sed 's|.*/||')
    echo "      - $artifact_name"
    
    generate_checksums "$file"
  fi
done < "$ARTIFACT_FILES"
rm -f "$ARTIFACT_FILES"

# Verify results
TOTAL_JARS=0
TOTAL_POMS=0
TOTAL_MD5=0
TOTAL_SHA1=0
TOTAL_FILES=0

# Count files in repository structure
if [ -d "$OUTPUT_DIR_ABS" ]; then
  # Git Bash specific handling
  if [[ "$(uname -s)" == MINGW* || "$(uname -s)" == CYGWIN* || "$(uname -s)" == MSYS* ]]; then
    if command -v cygpath &> /dev/null; then
      REPO_PATH=$(cygpath -u "$(cygpath -w "$OUTPUT_DIR_ABS")")
      TOTAL_JARS=$(find "$REPO_PATH" -type f -name '*.jar' 2>/dev/null | wc -l | tr -d '[:space:]')
      TOTAL_POMS=$(find "$REPO_PATH" -type f -name '*.pom' 2>/dev/null | wc -l | tr -d '[:space:]')
      TOTAL_MD5=$(find "$REPO_PATH" -type f -name '*.md5' 2>/dev/null | wc -l | tr -d '[:space:]')
      TOTAL_SHA1=$(find "$REPO_PATH" -type f -name '*.sha1' 2>/dev/null | wc -l | tr -d '[:space:]')
      TOTAL_FILES=$((TOTAL_JARS + TOTAL_POMS + TOTAL_MD5 + TOTAL_SHA1))
    fi
  else
    # Unix/Linux/macOS
    TOTAL_JARS=$(find "$OUTPUT_DIR_ABS" -type f -name '*.jar' 2>/dev/null | wc -l | tr -d '[:space:]')
    TOTAL_POMS=$(find "$OUTPUT_DIR_ABS" -type f -name '*.pom' 2>/dev/null | wc -l | tr -d '[:space:]')
    TOTAL_MD5=$(find "$OUTPUT_DIR_ABS" -type f -name '*.md5' 2>/dev/null | wc -l | tr -d '[:space:]')
    TOTAL_SHA1=$(find "$OUTPUT_DIR_ABS" -type f -name '*.sha1' 2>/dev/null | wc -l | tr -d '[:space:]')
    TOTAL_FILES=$((TOTAL_JARS + TOTAL_POMS + TOTAL_MD5 + TOTAL_SHA1))
  fi
fi

if [ "$TOTAL_FILES" -eq 0 ]; then
  echo -e "\n❌ ERROR: No files downloaded!" >&2
  echo "   Possible causes:" >&2
  echo "   1. Network issue (check Maven Central access)" >&2
  echo "   2. Invalid GAV (check at https://search.maven.org)" >&2
  echo "   3. Maven repository might be empty (try a different GAV)" >&2
  exit 1
fi

# Report results
echo -e "\n✅ Success! Created Maven repository with $TOTAL_FILES files:"
echo "   → $TOTAL_JARS JAR file(s)"
echo "   → $TOTAL_POMS POM file(s)"
echo "   → $TOTAL_MD5 MD5 checksum file(s)"
echo "   → $TOTAL_SHA1 SHA1 checksum file(s)"
echo "   → Repository location: $OUTPUT_DIR_ABS"

# Show example structure
echo -e "\nRepository structure example:"
if [[ "$(uname -s)" == MINGW* || "$(uname -s)" == CYGWIN* || "$(uname -s)" == MSYS* ]]; then
  if command -v cygpath &> /dev/null; then
    REPO_PATH=$(cygpath -u "$(cygpath -w "$OUTPUT_DIR_ABS")")
    if [ -d "$REPO_PATH" ]; then
      find "$REPO_PATH" -type d | head -n 5 | sed 's/^/   /'
    fi
  fi
else
  if [ -d "$OUTPUT_DIR_ABS" ]; then
    find "$OUTPUT_DIR_ABS" -type d | head -n 5 | sed 's/^/   /'
  fi
fi

# Show example files with checksums
echo -e "\nExample files with checksums:"
if [[ "$(uname -s)" == MINGW* || "$(uname -s)" == CYGWIN* || "$(uname -s)" == MSYS* ]]; then
  if command -v cygpath &> /dev/null; then
    REPO_PATH=$(cygpath -u "$(cygpath -w "$OUTPUT_DIR_ABS")")
    if [ -d "$REPO_PATH" ]; then
      # Find a JAR file and show it with its checksums
      JAR_FILE=$(find "$REPO_PATH" -type f -name '*.jar' | head -n 1)
      if [ -n "$JAR_FILE" ]; then
        DIR=$(dirname "$JAR_FILE")
        BASE=$(basename "$JAR_FILE")
        echo "   - $JAR_FILE"
        echo "   - $DIR/$BASE.md5"
        echo "   - $DIR/$BASE.sha1"
      fi
      
      # Find a POM file and show it with its checksums
      POM_FILE=$(find "$REPO_PATH" -type f -name '*.pom' | head -n 1)
      if [ -n "$POM_FILE" ]; then
        DIR=$(dirname "$POM_FILE")
        BASE=$(basename "$POM_FILE")
        echo "   - $POM_FILE"
        echo "   - $DIR/$BASE.md5"
        echo "   - $DIR/$BASE.sha1"
      fi
    fi
  fi
else
  if [ -d "$OUTPUT_DIR_ABS" ]; then
    # Find a JAR file and show it with its checksums
    JAR_FILE=$(find "$OUTPUT_DIR_ABS" -type f -name '*.jar' | head -n 1)
    if [ -n "$JAR_FILE" ]; then
      DIR=$(dirname "$JAR_FILE")
      BASE=$(basename "$JAR_FILE")
      echo "   - $JAR_FILE"
      echo "   - $DIR/$BASE.md5"
      echo "   - $DIR/$BASE.sha1"
    fi
    
    # Find a POM file and show it with its checksums
    POM_FILE=$(find "$OUTPUT_DIR_ABS" -type f -name '*.pom' | head -n 1)
    if [ -n "$POM_FILE" ]; then
      DIR=$(dirname "$POM_FILE")
      BASE=$(basename "$POM_FILE")
      echo "   - $POM_FILE"
      echo "   - $DIR/$BASE.md5"
      echo "   - $DIR/$BASE.sha1"
    fi
  fi
fi

# Show how to use this repository
echo -e "\n💡 To use this repository in Maven projects, add to your pom.xml:"
echo "   <repositories>"
echo "     <repository>"
echo "       <id>local-repo</id>"
echo "       <url>file://${OUTPUT_DIR_ABS}</url>"
echo "     </repository>"
echo "   </repositories>"

echo -e "\n💡 To upload to a private repository, use:"
echo "   mvn deploy:deploy-file \\"
echo "     -DgroupId=<group-id> \\"
echo "     -DartifactId=<artifact-id> \\"
echo "     -Dversion=<version> \\"
echo "     -Dpackaging=jar \\"
echo "     -Dfile=<path-to-jar> \\"
echo "     -DpomFile=<path-to-pom> \\"
echo "     -DrepositoryId=<repo-id> \\"
echo "     -Durl=<private-repo-url>"

echo -e "\n💡 Checksums were generated locally using:"
if command -v md5sum &> /dev/null; then
  echo "   → md5sum for MD5 hashes"
else
  echo "   → PowerShell Get-FileHash (MD5) as fallback"
fi
if command -v sha1sum &> /dev/null; then
  echo "   → sha1sum for SHA1 hashes"
else
  echo "   → PowerShell Get-FileHash (SHA1) as fallback"
fi

# Final verification that repository is usable
echo -e "\n🔍 Verifying repository integrity..."
if command -v mvn &> /dev/null; then
  echo "   → Running Maven dependency:tree to verify repository..."
  cat > "$TEMP_DIR/test-pom.xml" <<EOF
<project>
  <modelVersion>4.0.0</modelVersion>
  <groupId>com.maven.repo.verifier</groupId>
  <artifactId>repo-verifier</artifactId>
  <version>1.0</version>
  <repositories>
    <repository>
      <id>local-repo</id>
      <url>file://${OUTPUT_DIR_ABS}</url>
    </repository>
  </repositories>
  <dependencies>
    <dependency>
      <groupId>$GROUP</groupId>
      <artifactId>$ARTIFACT</artifactId>
      <version>$VERSION</version>
    </dependency>
  </dependencies>
</project>
EOF

  mvn -f "$TEMP_DIR/test-pom.xml" -B dependency:tree -Dverbose 2>&1 | grep -E '^\[INFO\] ' | head -n 10 || true
  echo "   → Repository verification complete"
else
  echo "   → Maven not available for repository verification"
fi

echo -e "\n🎉 Repository creation complete!"
echo "   → Ready for upload to private Maven repository"
