require('dotenv').config();  // Load environment variables from .env
const fs = require('fs-extra');
const path = require('path');
const { Translate } = require('@google-cloud/translate').v3;
const glob = require('glob');

// Load project configuration from environment variables
const projectId = process.env.GOOGLE_PROJECT_ID;
const apiKey = process.env.GOOGLE_API_KEY;
const sourceLanguage = process.env.SOURCE_LANGUAGE;  // Source language (e.g., 'en' for English)
const targetLanguages = process.env.TARGET_LANGUAGES.split(','); // Convert comma-separated string to array

// Google Translate Client
const translateClient = new Translate({
  projectId: projectId,
  key: apiKey,
});

// Function to translate a single string
async function translateText(text, targetLang) {
  try {
    const [translation] = await translateClient.translateText({
      parent: `projects/${projectId}/locations/global`,
      contents: [text],
      mimeType: 'text/plain',
      sourceLanguageCode: sourceLanguage,  // Specify the source language
      targetLanguageCode: targetLang,
    });
    return translation.translations[0].translatedText;
  } catch (err) {
    console.error(`Error translating text: ${text}`, err);
    return text; // If translation fails, return original text
  }
}

// Function to recursively translate JSON object values
async function translateJsonObject(obj, targetLang) {
  const translatedObj = {};
  for (const key in obj) {
    if (typeof obj[key] === 'object' && obj[key] !== null) {
      translatedObj[key] = await translateJsonObject(obj[key], targetLang);
    } else if (typeof obj[key] === 'string') {
      translatedObj[key] = await translateText(obj[key], targetLang);
    } else {
      translatedObj[key] = obj[key];
    }
  }
  return translatedObj;
}

// Function to process a single file
async function processFile(filePath) {
  const originalContent = await fs.readJson(filePath);
  for (const lang of targetLanguages) {
    const translatedContent = await translateJsonObject(originalContent, lang);
    const newFileName = `${path.basename(filePath, '.json')}.${lang}.json`;
    const newFilePath = path.join(path.dirname(filePath), newFileName);
    await fs.writeJson(newFilePath, translatedContent, { spaces: 2 });
    console.log(`Translated file saved: ${newFilePath}`);
  }
}

// Function to search and process all i18next files in the current directory
async function translateI18nextFiles() {
  const files = glob.sync('**/*.json', { ignore: ['node_modules/**'] });

  for (const file of files) {
    console.log(`Processing file: ${file}`);
    await processFile(file);
  }
}

// Run the translation process
translateI18nextFiles().catch(console.error);
