#!/bin/sh

# Tracker file path
TRACKER_FILE="translation-tracker"

# Get last script run time
if [ ! -f "$TRACKER_FILE" ]; then
    last_run=0
else
    last_run=$(cat "$TRACKER_FILE")
fi

# Identify recent JSON files
json_files=$(find . -maxdepth 1 -type f -name "*.json")
recent_files=""

current_time=$(date +%s)

# Filter files changed since last run
for file in $json_files; do
    file_mod_time=$(stat -c %Y "$file")
    if [ "$file_mod_time" -gt "$last_run" ]; then
        recent_files="$recent_files $file"
    fi
done

# Process recent files
for file in $recent_files; do
    # Extract every string value from JSON file
    values=$(jq -r '.. | select(type == "string")' "$file")
    
    # Print file and its values
    echo "File: $file"
    echo "$values"
    echo "---"
done

# Update tracker file with current time
echo "$current_time" > "$TRACKER_FILE"