#!/bin/bash

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

# Check if the .env file exists
if [ ! -f .env ]; then
    echo "Error: .env file not found."
    exit 1
fi

# Export the variables from the .env file
export $(grep -v '^#' .env | xargs)

# Access individual variables
echo "Google Project ID: $GOOGLE_PROJECT_ID"
echo "Google API Key: $GOOGLE_API_KEY"
echo "Source Language: $SOURCE_LANGUAGE"

# Split TARGET_LANGUAGES into an array
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
    # Extract every string value from JSON file as a JSON array
    values=$(jq -c '[.. | select(type == "string")]' "$file")
    
    # Print file and its values
    echo "File: $file"
    echo "Values to translate: $values"
    echo "---"

    # Prepare API request with entire array
    API_KEY="$GOOGLE_API_KEY"
    SOURCE_LANGUAGE="$SOURCE_LANGUAGE"
    TARGET_LANGUAGE="fr" # Adjust if needed

    # Construct the API URL
    # Note: Google Translate API supports multiple queries in a single request
    URL="https://translation.googleapis.com/language/translate/v2?key=${API_KEY}"

    # Make the API request with the array of strings
    RESPONSE=$(curl -s -X POST "$URL" \
        -H "Content-Type: application/json" \
        -d "{
            \"q\": $values,
            \"source\": \"$SOURCE_LANGUAGE\",
            \"target\": \"$TARGET_LANGUAGE\",
            \"format\": \"text\"
        }")

    # Check if the response is valid JSON
    if ! echo "$RESPONSE" | jq . >/dev/null 2>&1; then
        echo "Error: Invalid response from API. Please check your request."
        echo "Response: $RESPONSE"
        continue
    fi

    # Check for API errors
    error=$(echo "$RESPONSE" | jq -r '.error.message // empty')
    if [ -n "$error" ]; then
        echo "Translation API Error: $error"
        continue
    fi

    # Extract the translated texts from the JSON response
    TRANSLATED_TEXTS=$(echo "$RESPONSE" | jq -c '.data.translations[].translatedText')

    # Print the translated texts
    echo "Translated texts:"
    echo "$TRANSLATED_TEXTS"

    # Optional: Create a new JSON file with translations
    echo "$TRANSLATED_TEXTS" | jq -c '.' > "${file%.json}_translations.json"
done

# Update tracker file with current time
echo "$current_time" > "$TRACKER_FILE"