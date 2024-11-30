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

# Print out configuration (be cautious with API keys)
echo "Google Project ID: $GOOGLE_PROJECT_ID"
echo "Source Language: $SOURCE_LANGUAGE"

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
    # Extract string values from JSON file
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

        # Validate response
        if ! echo "$RESPONSE" | jq . >/dev/null 2>&1; then
            echo "Error: Invalid response from API for $TARGET_LANGUAGE"
            echo "Response: $RESPONSE"
            continue
        fi

        # Check for API errors
        error=$(echo "$RESPONSE" | jq -r '.error.message // empty')
        if [ -n "$error" ]; then
            echo "Translation API Error for $TARGET_LANGUAGE: $error"
            continue
        fi

        # Extract translated texts
        TRANSLATED_TEXTS=$(echo "$RESPONSE" | jq -c '.data.translations[].translatedText')

        # Create a new JSON file with translations
        echo "$TRANSLATED_TEXTS" | jq -c '.' > "${file%.json}_${TARGET_LANGUAGE}_translations.json"
        
        echo "Translated to $TARGET_LANGUAGE"
    done
done

# Update tracker file with current time
echo "$current_time" > "$TRACKER_FILE"