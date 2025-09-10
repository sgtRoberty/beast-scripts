#!/bin/bash

# --- R Script Executor ---
# This script automates running 'summarize_posteriors.R' across multiple folders.
# It accepts a required --burnin argument and an optional --name tag for output files.

# Exit immediately if a command exits with a non-zero status.
set -e

# --- 1. PARSE & VALIDATE ARGUMENTS ---
# Initialize variables
BURNIN=""
NAME_TAG="" # New: Variable for the optional name tag
FOLDERS=()

# Loop through all provided arguments.
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --burnin)
            if [ -n "$2" ]; then
                BURNIN="$2"
                shift 2
            else
                echo "❌ Error: --burnin flag requires a value." >&2
                exit 1
            fi
            ;;
        # New: Case for the optional --name argument
        --name)
            if [ -n "$2" ]; then
                NAME_TAG="$2"
                shift 2
            else
                echo "❌ Error: --name flag requires a value." >&2
                exit 1
            fi
            ;;
        *)
            # Assume any other argument is a folder name
            FOLDERS+=("$1")
            shift
            ;;
    esac
done

# Update the usage message to include the new optional argument
USAGE_MSG="Usage: ./run_posterior_summaries.sh --burnin <value> [--name <tag>] <folder1> [folder2] ..."
EXAMPLE_MSG="Example: ./run_posterior_summaries.sh --burnin 0.2 --name simExpmt3 analysis_A"

# Check if the required arguments were provided.
if [ -z "$BURNIN" ]; then
    echo "❌ Error: --burnin <value> is a required argument."
    echo "$USAGE_MSG"
    echo "$EXAMPLE_MSG"
    exit 1
fi
if [ ${#FOLDERS[@]} -eq 0 ]; then
    echo "❌ Error: At least one folder must be specified."
    echo "$USAGE_MSG"
    echo "$EXAMPLE_MSG"
    exit 1
fi

# --- 2. PROCESS EACH FOLDER ---
echo "🚀 Starting batch processing with burn-in = $BURNIN..."
if [ -n "$NAME_TAG" ]; then
    echo "   Using name tag: '$NAME_TAG'"
fi

for FOLDER in "${FOLDERS[@]}"; do
    echo "----------------------------------------"
    echo "➡️ Processing folder: '$FOLDER'"

    # Define paths
    SCRIPTS_DIR="$FOLDER/scripts"
    TEMPLATES_DIR="$FOLDER/templates"
    R_SCRIPT_PATH="$SCRIPTS_DIR/summarize_posteriors.R"

    # Validations
    if [ ! -d "$FOLDER" ] || [ ! -d "$TEMPLATES_DIR" ] || [ ! -f "$R_SCRIPT_PATH" ]; then
        echo "⚠️  Warning: A required file or directory was not found in '$FOLDER'. Skipping."
        continue
    fi

    # Calculate Parameters
    NSIMS=$(find "$TEMPLATES_DIR" -mindepth 1 -maxdepth 1 -type d -printf '.' | wc -c)
    echo "   Found $NSIMS simulation subfolders in '$TEMPLATES_DIR'."

    # New: Conditionally construct the output file name
    FOLDER_BASENAME=$(basename "$FOLDER")
    if [ -n "$NAME_TAG" ]; then
        OUTPUT_FILE="posterior_summary_${NAME_TAG}_${FOLDER_BASENAME}.rds"
    else
        OUTPUT_FILE="posterior_summary_${FOLDER_BASENAME}.rds"
    fi
    echo "   Output file will be named '$OUTPUT_FILE'."

    # Execute the R Script in a subshell
    (
        cd "$SCRIPTS_DIR"
        echo "   Executing command in '$(pwd)'..."
        Rscript summarize_posteriors.R \
            --nsims=$NSIMS \
            --burnin=$BURNIN \
            --out=../$OUTPUT_FILE
    )

    echo "✅ Finished processing '$FOLDER'."
done

echo "----------------------------------------"
echo "🎉 All tasks completed!"