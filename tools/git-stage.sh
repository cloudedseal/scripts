#!/bin/bash

# Check if we're in a Git repository
if ! git rev-parse --is-inside-work-tree &> /dev/null; then
    echo -e "\033[1;31m❌ Error: Not in a Git repository.\033[0m" >&2
    exit 1
fi

# Arrays to hold files and their types
files=()
types=()

# Get unstaged modified files (tracked and changed)
while IFS= read -r -d $'\0' file; do
    files+=("$file")
    types+=("modified")
done < <(git diff --name-only -z 2>/dev/null)

# Get untracked files (new files)
while IFS= read -r -d $'\0' file; do
    files+=("$file")
    types+=("untracked")
done < <(git ls-files --others --exclude-standard -z 2>/dev/null)

# Check if there are any files to process
if [ ${#files[@]} -eq 0 ]; then
    echo -e "\033[1;32m✅ No unstaged changes or new files found.\033[0m"
    exit 0
fi

echo -e "\033[1;34m🔍 Found ${#files[@]} changes to review...\033[0m"

# Process each file
for i in "${!files[@]}"; do
    file="${files[$i]}"
    type="${types[$i]}"
    clear

    # Header based on file type
    if [ "$type" = "modified" ]; then
        header="MODIFIED FILE: $file"
        header_color="\033[1;44m\033[1;37m"
    else
        header="NEW FILE: $file"
        header_color="\033[1;42m\033[1;30m"  # Green background for new files
    fi

    echo -e "${header_color} ${header} \033[0m"
    echo -e "\033[1;36m$(printf '%.0s=' {1..80})\033[0m"

    # Show content based on file type
    if [ "$type" = "modified" ]; then
        # Show diff with word-level highlighting
        if ! git diff --color=always --word-diff=color -- "$file" 2>/dev/null; then
            echo -e "\033[1;33m⚠️  Warning: Could not show diff (binary file or error)\033[0m"
            git diff -- "$file" 2>/dev/null || echo -e "\033[1;31m❌ Failed to show diff\033[0m"
        fi
    else
        # Handle new/untracked files
        if [ ! -f "$file" ]; then
            echo -e "\033[1;31m❌ File not found: $file\033[0m"
        else
            # Check if it's a text file (using mime type)
            if command -v file &> /dev/null && file --brief --mime-type "$file" | grep -q '^text/'; then
                lines=$(wc -l < "$file" 2>/dev/null)
                if [ -n "$lines" ] && [ "$lines" -le 100 ]; then
                    echo -e "\033[1;37m$(cat "$file")\033[0m"
                else
                    echo -e "\033[1;37m$(head -n 100 "$file" 2>/dev/null)\033[0m"
                    [ -n "$lines" ] && echo -e "\033[1;33m... and $((lines-100)) more lines\033[0m"
                fi
            else
                echo -e "\033[1;33m⚠️  Binary or non-text file (content not displayed)\033[0m"
                echo -e "\033[1;34mFile size: $(du -h "$file" 2>/dev/null | cut -f1)\033[0m"
            fi
        fi
    fi

    echo -e "\033[1;36m$(printf '%.0s=' {1..80})\033[0m"

    # Reset terminal and clear input buffer
    stty sane
    while read -r -t 0; do read -r -d '' -n 1; done 2>/dev/null

    # Show prompt with clear options
    echo -e "\n\033[1;32m❓ Stage this ${type} file?\033[0m"
    echo -e "   \033[1;34m[y]\033[0m - Stage this file"
    echo -e "   \033[1;33m[n]\033[0m - Skip this file"
    echo -e "   \033[1;35m[a]\033[0m - Stage ALL remaining files"
    echo -e "   \033[1;31m[q]\033[0m - Quit immediately\n"

    # Read input with timeout
    if ! read -rp $'\033[1;37mYour choice (y/n/a/q): \033[0m' -t 30 answer; then
        echo -e "\n\033[1;31m⏰ Input timed out - skipping\033[0m"
        answer="n"
    fi

    case "$answer" in
        [yY]|[yY][eE][sS])
            if git add -- "$file" &> /dev/null; then
                echo -e "\033[1;32m✅ Staged: $file\033[0m"
            else
                echo -e "\033[1;31m❌ Failed to stage: $file\033[0m"
            fi
            ;;
        [aA])
            echo -e "\n\033[1;35m⚡ Staging ALL remaining changes...\033[0m"
            git add -A &> /dev/null  # Stages ALL changes (modified + new)
            echo -e "\033[1;32m✅ All changes staged!\033[0m"
            echo -e "\n\033[1;34m💡 Use 'git status' to review staged changes\033[0m"
            exit 0
            ;;
        [qQ])
            echo -e "\n\033[1;31m🛑 Process aborted by user\033[0m"
            echo -e "\033[1;34m💡 Use 'git status' to review current state\033[0m"
            exit 0
            ;;
        *)
            echo -e "\033[1;33m⏭️  Skipped: $file\033[0m"
            ;;
    esac

    echo -e "\033[1;36m$(printf '%.0s-' {1..80})\033[0m\n"
done

echo -e "\033[1;32m🎉 All changes processed!\033[0m"
echo -e "\033[1;34m💡 Use 'git status' to review staged changes\033[0m"
exit 0
