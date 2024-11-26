#!/bin/bash

# Load configuration from the .env file, skipping comment lines and empty lines
if [ -f .env ]; then
    # Skip lines that are comments or empty, and export the variables
    while IFS= read -r line; do
        # Ignore lines that are empty or start with #
        if [[ ! "$line" =~ ^[[:space:]]*(#|$) ]]; then
            export "$line"
        fi
    done < .env
else
    echo ".env file not found!"
    exit 1
fi

# Check if required environment variables are set
if [[ -z "$GOOGLE_API_KEY" || -z "$GOOGLE_PROJECT_ID" || -z "$SOURCE_LANGUAGE" || -z "$TARGET_LANGUAGES" ]]; then
    echo "Missing required environment variables. Please check the .env file."
    exit 1
fi

# Directory containing i18next JSON files (e.g., ./locales/en)
INPUT_DIR="./locales/$SOURCE_LANGUAGE"

# Base directory for translated files
OUTPUT_DIR="./locales"

# Function to URL encode a string
urlencode() {
    local raw="$1"
    echo "$raw" | jq -s -R -r @uri
}

# Translate function
translate_text() {
    local text="$1"
    local target_lang="$2"

    # API Endpoint
    local url="https://translation.googleapis.com/language/translate/v2"

    # Make the request using curl
    local response=$(curl -s -X POST -H "Content-Type: application/json" \
        -d "{
                'q': \"$text\",
                'target': \"$target_lang\",
                'source': \"$SOURCE_LANGUAGE\",
                'format': 'text'
             }" \
        "$url?key=$GOOGLE_API_KEY")

    # Extract translated text using jq
    local translated_text=$(echo "$response" | jq -r '.data.translations[0].translatedText')
    echo "$translated_text"
}

# Loop through target languages
IFS=',' read -r -a LANGUAGES <<< "$TARGET_LANGUAGES"

# Loop through each JSON file in the input directory
for file in "$INPUT_DIR"/*.json; do
    filename=$(basename "$file")

    # Read the JSON content
    content=$(cat "$file")

    echo "Translating file: $filename"

    # Loop through each target language
    for lang in "${LANGUAGES[@]}"; do
        # Output file path
        output_file="$OUTPUT_DIR/$lang/$filename"
        mkdir -p "$OUTPUT_DIR/$lang"

        # Create a new JSON file with translated content
        translated_content=$(echo "$content" | jq -c 'to_entries | map(.value = (env.TRANSLATED_TEXT = "'"$(translate_text "$(urlencode "$(jq -c .value <<< "$content")")" "$lang")"'")) | from_entries')
        
        echo "$translated_content" > "$output_file"
        echo "Translated $filename to $lang: $output_file"
    done
done
