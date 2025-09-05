#!/bin/bash

# Loop through all files ending with .trees
for file in */*.trees; do
    # Check if the last non-empty line is exactly "End;"
	if ! awk 'NF {line = $0} END {if (line != "End;") exit 1}' "$file"; then
        echo "Fixing file: $file"
        echo "End;" >> "$file"
    else
        echo "File OK: $file"
    fi
done
