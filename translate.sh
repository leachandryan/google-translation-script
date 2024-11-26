#!/bin/bash

# Load configuration from the .env file
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo ".env file not found!"
    exit 1
fi

# Check if required environment variables are set
if [[ -z "$API_KEY" || -z "$PROJECT_ID" || -z "$INPUT_LANGUAGE" || -z "$TRANSLATE_LANGUAGES" ]]; then
    echo "Missing required environment variables. Please check the .env file."
    exit 1
fi

# Directory containing i18next JSON files (e.g., ./locales/en)
INPUT_DIR="./locales/$INPUT_LANGUAGE"

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
                'source': \"$INPUT_LANGUAGE\",
                'format': 'text'
             }" \
        "$url?key=$API_KEY")

    # Extract translated text using jq
    local translated_text=$(echo "$response" | jq -r '.data.translations[0].translatedText')
    echo "$translated_text"
}

# Loop through target languages
IFS=',' read -r -a LANGUAGES <<< "$TRANSLATE_LANGUAGES"

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
