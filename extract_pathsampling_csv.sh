#!/bin/bash

# Check if output filename is provided
if [[ -z "$1" ]]; then
    echo "Usage: $0 <output_csv_filename>"
    exit 1
fi

output_csv="$1"

# Write CSV header
echo "filename,step,theta,likelihood,contribution,ESS,sum_ESS,marginal_L_estimate" > "$output_csv"

# Loop through all run directories
for dir in *-run*/; do
    # Remove trailing slash
    dir="${dir%/}"

    # Expected output file inside the directory
    out_file="$dir/$dir.out"

    if [[ ! -f "$out_file" ]]; then
        echo "⚠️  Output file not found: $out_file"
        continue
    fi

    # Extract sum(ESS)
    sum_ess=$(grep "sum(ESS)" "$out_file" | awk -F= '{print $2}' | tr -d ' ')

    # Extract marginal likelihood
    marginal_L=$(grep "marginal L estimate" "$out_file" | awk -F= '{print $2}' | tr -d ' ')

    # Extract table rows
    awk -v fname="$dir" -v sum_ess="$sum_ess" -v marginal_L="$marginal_L" '
        BEGIN { in_table=0 }
        /^[[:space:]]*Step[[:space:]]+/ { in_table=1; next }
        /^sum\(ESS\)/ { in_table=0 }
        in_table && NF >= 5 {
            printf("%s,%s,%s,%s,%s,%s,%s,%s\n",
                fname, $1, $2, $3, $4, $5, sum_ess, marginal_L)
        }
    ' "$out_file" >> "$output_csv"
done

echo "✔ Output written to $output_csv"
