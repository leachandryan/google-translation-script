#!/bin/bash  # Use bash instead of sh for better compatibility

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

# Format target languages 
formatted_target_languages=$(printf '"%s" ' "${LANGUAGES_ARRAY[@]}")

# Echo formatted target languages
echo "Target Languages: $formatted_target_languages"

####################################################################################################

# Load variables from .env (assuming these are exported or sourced previously)
API_KEY="$GOOGLE_API_KEY"
SOURCE_LANGUAGE="$SOURCE_LANGUAGE"
TARGET_LANGUAGE="fr" # Adjust if needed
TEXT=$values # Example text to translate
echo "Text: $values"
# Construct the API URL
URL="https://translation.googleapis.com/language/translate/v2?key=${API_KEY}&source=${SOURCE_LANGUAGE}&target=${TARGET_LANGUAGE}&q=$(echo -n "$TEXT" | jq -sRr @uri)"

# Make the API request and parse the response
RESPONSE=$(curl -s "$URL")

# Check if the response is valid JSON
if ! echo "$RESPONSE" | jq . >/dev/null 2>&1; then
  echo "Error: Invalid response from API. Please check your request."
  echo "Response: $RESPONSE"
  exit 1
fi

# Extract the translated text from the JSON response
TRANSLATED_TEXT=$(echo "$RESPONSE" | jq -r '.data.translations[0].translatedText')

# Check for blank or missing translation
if [[ -z "$TRANSLATED_TEXT" || "$TRANSLATED_TEXT" == "null" ]]; then
  echo "Error: Translation came back blank or invalid."
  echo "Response: $RESPONSE"
  exit 1
fi

# Print the translated text
echo "Translated text: $TRANSLATED_TEXT"

# Check for API errors
error=$(echo "$response" | jq -r '.error.message // empty')
if [ -n "$error" ]; then
    echo "Translation API Error: $error"
    exit 1
fi

# Extract translated text
translated_text=$(echo "$response" | jq -r '.translations[0].translatedText')


# Update tracker file with current time
echo "$current_time" > "$TRACKER_FILE"