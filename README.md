# Lemma Greek Dictionary for Kindle

A comprehensive Greek dictionary generator for Kindle e-readers, supporting both Greek-English and Greek-Greek (monolingual) dictionaries. This tool processes Wiktionary data to create `.mobi` dictionary files optimized for Kindle devices.

![krybontas](https://github.com/user-attachments/assets/b4720bd2-b3d6-4bbc-9295-5e0944cd0393)

## Quick Install

### Installing Dictionaries on Your Kindle

1. **Connect your Kindle** to your computer via USB cable
2. **Open the Kindle drive** on your computer
3. **Navigate to the `documents/dictionaries` folder** on your Kindle
   - If the `dictionaries` folder doesn't exist, create it inside `documents`
4. **Copy the `.mobi` file** from the `/dist` folder to `documents/dictionaries`
5. **Safely eject your Kindle** from your computer
6. **Restart your Kindle**:
   - Hold the power button for 40 seconds, or
   - Go to Settings → Device Options → Restart
7. The dictionary will be available after restart

### Setting as Default Greek Dictionary

1. **Open any Greek text** on your Kindle
2. **Select a Greek word** to look up
3. **Tap the dictionary name** at the bottom of the popup
4. **Select "Lemma Greek Dictionary"** from the list
5. The dictionary is now your default for Greek lookups

## Pre-built Dictionaries

Ready-to-use dictionary files are available in the `/dist` folder:

- `lemma_greek_en_[date].mobi` - Greek-English dictionary
- `lemma_greek_el_[date].mobi` - Greek-Greek (monolingual) dictionary

## Features

## Features

- **Bilingual & Monolingual Support**: Generate Greek-English or Greek-Greek dictionaries
- **Inflection Support**: Automatically links inflected forms to their lemmas
- **Etymology Information**: Includes word origins where available
- **Clean Formatting**: Optimized for Kindle's dictionary popup interface
- **Testing Mode**: Create smaller dictionaries for testing (1-100% of entries)

## Building from Source

### Prerequisites

- Ruby (2.5 or higher)
- Kindle Previewer 3 (for `.mobi` generation)
- Git LFS (for handling large dictionary data files)

### Installation

```bash
# Clone the repository
git clone https://github.com/fr2019/lemma.git
cd lemma

# Install Git LFS if not already installed
git lfs install
git lfs pull

# Run the generator
ruby greek_kindle_dictionary.rb [options]
```

### Options

```bash
# Generate Greek-English dictionary (default)
ruby greek_kindle_dictionary.rb

# Generate Greek-Greek monolingual dictionary
ruby greek_kindle_dictionary.rb -s el

# Generate a test dictionary with only 10% of entries
ruby greek_kindle_dictionary.rb -l 10

# Combine options
ruby greek_kindle_dictionary.rb -s el -l 5
```

### Command Line Arguments

- `-s, --source LANG`: Source Wiktionary language ('en' for English or 'el' for Greek)
- `-l, --limit PERCENT`: Limit to first X% of words (useful for testing)
- `-h, --help`: Show help message

## Data Sources

The dictionaries are built from:

- **Primary Source**: [Kaikki.org](https://kaikki.org/) - Machine-readable Wiktionary data
- **Fallback Data**: Pre-downloaded JSONL files in the repository (via Git LFS)

Data files:

- `greek_data_en_20250716.jsonl` - English Wiktionary Greek entries
- `greek_data_el_20250717.jsonl` - Greek Wiktionary Greek entries

## Dictionary Content

The dictionaries include:

- **Headwords**: Main dictionary entries
- **Inflected Forms**: Automatically redirect to their lemmas
- **Part of Speech**: Grammatical category
- **Definitions**: Multiple numbered definitions where applicable
- **Etymology**: Word origins and history
- **Domain Tags**: Subject area indicators (e.g., γλωσσολογία, γραμματική)

### Excluded Content

The following are filtered out as they cannot be selected in Kindle texts:

- Prefixes and suffixes (e.g., `-ικός`, `προ-`)
- Combining forms and clitics
- Individual letters and symbols
- Abbreviations and contractions

## Output Structure

Generated files are placed in timestamped directories:

```
lemma_greek_en_20250717/          # Full English source dictionary
lemma_greek_el_20250717_10pct/    # 10% Greek source test dictionary
├── content.html                  # Main dictionary content
├── cover.html                    # Cover page
├── copyright.html                # Copyright information
├── usage.html                    # Usage instructions
└── lemma_greek_XX_[date].opf    # Kindle package file
```

## Troubleshooting

### Dictionary Not Appearing

- Ensure the `.mobi` file is in the `documents/dictionaries` folder
- **Always restart your Kindle** after adding new dictionaries
- If still not appearing, try a hard restart (hold power button for 40 seconds)

### Lookup Not Working

- Make sure you've set the dictionary as default for Greek
- Some older Kindle models may have limited Greek support

### Building Issues

- **Kindle Previewer not found**: Install from [Amazon's website](https://www.amazon.com/gp/feature.html?docId=1000765261)
- **Download freezes**: Use pre-downloaded data files from the repository
- **Memory issues**: Use the `-l` option to build smaller test dictionaries first

## License

Dictionary content is derived from Wiktionary and is available under the Creative Commons Attribution-ShareAlike License.

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## Acknowledgments

- Wiktionary contributors for the source data
- [Kaikki.org](https://kaikki.org/) for providing machine-readable Wiktionary dumps
