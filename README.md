# Automated JSON Translation Script

## Overview

This Bash script automates the translation of JSON files using the Google Cloud Translation API. It supports translating JSON files from a source language to multiple target languages, with intelligent file tracking to only process recently modified files.

## Prerequisites

- Bash shell
- `jq` command-line JSON processor
- Google Cloud Translation API access
- A Google Cloud Project with Translation API enabled

## Setup

### 1. Install Dependencies

Make sure you have the following tools installed:
- Bash
- `jq` (JSON processor)
- `curl` (for API requests)

On Ubuntu/Debian:
```bash
sudo apt-get update
sudo apt-get install jq curl
```

On macOS (using Homebrew):
```bash
brew install jq curl
```

### 2. Configure Environment Variables

Create a `.env` file in the same directory as the script with the following variables:

```
GOOGLE_PROJECT_ID=your-google-cloud-project-id
GOOGLE_API_KEY=your-google-cloud-api-key
SOURCE_LANGUAGE=en
TARGET_LANGUAGES=es,fr,de
```

#### Environment Variable Explanation:
- `GOOGLE_PROJECT_ID`: Your Google Cloud project ID
- `GOOGLE_API_KEY`: API key with Translation API permissions
- `SOURCE_LANGUAGE`: The language code of the original JSON files (e.g., 'en' for English)
- `TARGET_LANGUAGES`: Comma-separated list of target language codes

#### Supported Language Codes:
- `en`: English
- `es`: Spanish
- `de`: German
- `fr`: French
- `pt`: Portuguese
- `ru`: Russian
- `ja`: Japanese
- `ko`: Korean
- `it`: Italian
- `nl`: Dutch
- `zh-CN`: Chinese (Simplified)
- `zh-TW`: Chinese (Traditional)
- `pl`: Polish
- `tr`: Turkish
- `ar`: Arabic

### 3. Make Script Executable

```bash
chmod +x translate.sh
```

## Usage

1. Place your JSON files in the same directory as the script.
2. Run the script:

```bash
./translate.sh
```

### How It Works

- Identifies JSON files in the current directory
- Creates a source language directory and copies original files
- Finds files modified since the last script run
- Translates strings within each JSON file
- Creates translated files in language-specific directories
- Tracks the last run time to optimize translation process

### Example Workflow

1. Initial run creates:
   - `en/` directory with original files
   - `es/`, `fr/`, `de/` directories with translated files

2. Subsequent runs will only translate files modified since the last run

## Important Notes

- Requires an active Google Cloud Translation API key
- Translates only string values in JSON files
- Preserves original JSON structure
- Uses a tracking file to optimize translation process

## Troubleshooting

- Ensure `.env` file is correctly configured
- Check Google Cloud API key permissions
- Verify `jq` and `curl` are installed
- Check network connectivity to Google Translation API

## Limitations

- Relies on Google Cloud Translation API (may incur costs)
- Works best with simple JSON structures
- May not perfectly translate context-dependent strings

## License

[Specify your license here]

## Contributing

Contributions are welcome! Please submit pull requests or open issues on the project repository.