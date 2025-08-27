#!/bin/bash

# Script: find_class.sh
# Usage: ./find_class.sh <directory> <target_class_name>
# Description: Finds a target class in JAR and WAR files, including nested JARs within WAR files

# Check if correct number of arguments are provided
if [ $# -ne 2 ]; then
    echo "Usage: $0 <directory> <target_class_name>"
    echo "Example: $0 /opt/tomcat/lib org/springframework/web/servlet/DispatcherServlet"
    exit 1
fi

SEARCH_DIR="$1"
TARGET_CLASS="$2"

# Convert class name to proper format if needed (dots to slashes, add .class extension)
NORMALIZED_CLASS=$(echo "$TARGET_CLASS" | sed 's/\./\//g')
# Ensure it ends with .class
if [[ ! "$NORMALIZED_CLASS" =~ \.class$ ]]; then
    NORMALIZED_CLASS="${NORMALIZED_CLASS}.class"
fi

echo "Searching for class: $NORMALIZED_CLASS"
echo "In directory: $SEARCH_DIR"
echo "----------------------------------------"

# Check if the directory exists
if [ ! -d "$SEARCH_DIR" ]; then
    echo "Error: Directory '$SEARCH_DIR' does not exist."
    exit 1
fi

# Function to search for class in a JAR file
search_jar() {
    local jar_file="$1"
    if jar -tf "$jar_file" | grep -q "$NORMALIZED_CLASS"; then
        echo "Found in: $(readlink -f "$jar_file")"
        return 0
    fi
    return 1
}

# Function to search for class in a WAR file (including nested JARs)
search_war() {
    local war_file="$1"
    local found_in_war=1
    
    # Create a temporary directory for extracting WAR contents
    local temp_dir=$(mktemp -d)
    
    # Extract the WAR file
    if unzip -q "$war_file" -d "$temp_dir"; then
        # Search in WEB-INF/classes
        if find "$temp_dir/WEB-INF/classes" -name "*.class" 2>/dev/null | grep -q "$NORMALIZED_CLASS"; then
            echo "Found in WAR classes: $(readlink -f "$war_file")"
            found_in_war=0
        fi
        
        # Search in nested JARs in WEB-INF/lib
        if [ -d "$temp_dir/WEB-INF/lib" ]; then
            while IFS= read -r -d '' nested_jar; do
                if jar -tf "$nested_jar" | grep -q "$NORMALIZED_CLASS"; then
                    echo "Found in nested JAR: $(readlink -f "$war_file") -> $(basename "$nested_jar")"
                    found_in_war=0
                fi
            done < <(find "$temp_dir/WEB-INF/lib" -name "*.jar" -print0 2>/dev/null)
        fi
    fi
    
    # Clean up
    rm -rf "$temp_dir"
    return $found_in_war
}

# Main search logic
found=0
while IFS= read -r -d '' archive_file; do
    case "${archive_file##*.}" in
        jar)
            if search_jar "$archive_file"; then
                found=1
            fi
            ;;
        war)
            if search_war "$archive_file"; then
                found=1
            fi
            ;;
    esac
done < <(find "$SEARCH_DIR" \( -name "*.jar" -o -name "*.war" \) -print0)

if [ $found -eq 0 ]; then
    echo "Class '$TARGET_CLASS' was not found in any JAR or WAR files under '$SEARCH_DIR'."
    exit 1
else
    exit 0
fi
