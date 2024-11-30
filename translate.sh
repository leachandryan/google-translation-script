#!/bin/bash

# Tracker file to keep track of last script run time
TRACKER_FILE="translation-tracker"

# Get last script run time
if [ ! -f "$TRACKER_FILE" ]; then
    last_run=0
else
    last_run=$(cat "$TRACKER_FILE")
fi

# Find JSON files in the current directory
json_files=$(find . -maxdepth 1 -type f -name "*.json")
recent_files=""

# Get current timestamp
current_time=$(date +%s)

# Check if .env file exists
if [ ! -f .env ]; then
    echo "Error: .env file not found."
    exit 1
fi

# Load environment variables from .env file
export $(grep -v '^#' .env | xargs)

# Print out configuration
echo "Google Project ID: $GOOGLE_PROJECT_ID"
echo "Source Language: $SOURCE_LANGUAGE"

# Create source language directory and copy original files
mkdir -p "${SOURCE_LANGUAGE}"
chmod 755 "${SOURCE_LANGUAGE}"
for file in $json_files; do
    # Only copy if it's in the root directory
    if [ "$(dirname "$file")" = "." ]; then
        cp "$file" "${SOURCE_LANGUAGE}/"
        echo "Copied original file to ${SOURCE_LANGUAGE}/$(basename "$file")"
    fi
done

# Split target languages into an array
IFS=',' read -ra LANGUAGES_ARRAY <<< "$TARGET_LANGUAGES"

# Filter files changed since last run
for file in $json_files; do
    file_mod_time=$(stat -c %Y "$file")
    if [ "$file_mod_time" -gt "$last_run" ]; then
        recent_files="$recent_files $file"
    fi
done

# Process recent files
for file in $recent_files; do
    # Extract paths and strings
    paths=$(jq -r 'path(.. | select(type == "string")) | join("/")' "$file")
    values=$(jq -c '[.. | select(type == "string")]' "$file")

    echo "File: $file"
    echo "Values to translate: $values"
    echo "---"

    # Translate for each target language
    for TARGET_LANGUAGE in "${LANGUAGES_ARRAY[@]}"; do
        # Make API request
        RESPONSE=$(curl -s -X POST "https://translation.googleapis.com/language/translate/v2?key=${GOOGLE_API_KEY}" \
            -H "Content-Type: application/json" \
            -d "{
                \"q\": $values,
                \"source\": \"$SOURCE_LANGUAGE\",
                \"target\": \"$TARGET_LANGUAGE\",
                \"format\": \"text\"
            }")

        # Check for API errors
        if echo "$RESPONSE" | jq -e '.error' > /dev/null; then
            echo "Translation API Error for $TARGET_LANGUAGE: $(echo "$RESPONSE" | jq -r '.error.message')"
            continue
        fi

        # Extract translations
        translations=$(echo "$RESPONSE" | jq -r '.data.translations[].translatedText')

        # Create language-specific directory
        mkdir -p "${TARGET_LANGUAGE}"
        chmod 755 "${TARGET_LANGUAGE}"

        # Create new translated file starting with original
        translated_file="${TARGET_LANGUAGE}/${file##*/}"
        cp "$file" "$translated_file"

        # Replace each string in the JSON with its translation
        counter=0
        while IFS= read -r path; do
            translation=$(echo "$translations" | sed -n "$((counter + 1))p")
            if [ -n "$translation" ]; then
                # Convert path string back to jq path array notation
                jq_path=$(echo "$path" | awk -F'/' '{printf "["; for(i=1;i<=NF;i++){printf "\"%s\"%s", $i, (i==NF?"":",")};printf "]"}')
                # Update the value at the path
                jq --arg translation "$translation" "setpath($jq_path; \$translation)" "$translated_file" > "${translated_file}.tmp" && mv "${translated_file}.tmp" "$translated_file"
            fi
            ((counter++))
        done <<< "$paths"

        echo "Translated to $TARGET_LANGUAGE"
    done
done

# Update tracker file with current time
echo "$current_time" > "$TRACKER_FILE"