#!/bin/bash
# --------------------------------------------------------------------------------------------------
# SCRIPT:      summarize_beastMCMC.sh
# AUTHOR:      Robert Haobo Yuan
# DATE:        2026-01-08
#
# DESCRIPTION:
# This script summarizes and combines BEAST2 MCMC outputs from multiple replicate runs.
#
# USAGE:
# ./summarize_beastMCMC.sh --burnin <value> [--resample <freq>] [--runs <ranges>] [--ignore-trees]
# EAXMPLE:
# ./summarize_beastMCMC.sh --burnin 10
#
# --------------------------------------------------------------------------------------------------

# ----------------------------
# Argument parsing
# ----------------------------
burnin=""
resample=""
runs_raw=""
ignore_trees=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --burnin) burnin="$2"; shift ;;
        --resample) resample="$2"; shift ;;
        --runs) runs_raw="$2"; shift ;;
        --ignore-trees) ignore_trees=true ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

if [ -z "$burnin" ]; then
  echo "Error: --burnin is required."
  echo "Usage: summarize_beastMCMC.sh --burnin <value> [--resample <freq>] [--runs <ranges>] [--ignore-trees]"
  exit 1
fi

# ----------------------------
# Detect base filename
# ----------------------------
first_run_dir=$(ls -d *-run[0-9]* 2>/dev/null | head -n 1)
if [ -z "$first_run_dir" ]; then
  echo "Error: No run directories (e.g., filename-runN) found in current directory."
  exit 1
fi

filename=$(echo "$first_run_dir" | sed -E 's/-run[0-9]+$//')

# ----------------------------
# Expand run numbers
# ----------------------------
runs=()
if [ -n "$runs_raw" ]; then
    IFS=',' read -ra tokens <<< "$runs_raw"
    for token in "${tokens[@]}"; do
        if [[ "$token" =~ ^[0-9]+$ ]]; then
            runs+=("$token")
        elif [[ "$token" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            for i in $(seq "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"); do
                runs+=("$i")
            done
        else
            echo "Invalid run format: $token"
            exit 1
        fi
    done
else
    for dir in ${filename}-run[0-9]*; do
        if [[ "$dir" =~ -run([0-9]+)$ ]]; then
            runs+=("${BASH_REMATCH[1]}")
        fi
    done
fi

# ----------------------------
# Sort and format run numbers
# ----------------------------
sorted_runs_array=($(echo "${runs[@]}" | tr ' ' '\n' | sort -n | uniq))
sorted_runs_csv=$(IFS=','; echo "${sorted_runs_array[*]}")
sorted_runs_str=$(IFS=; echo "${sorted_runs_array[*]}")

# ----------------------------
# Create output folder
# ----------------------------
output_dir="${filename}-runs${sorted_runs_str}-combined"
mkdir -p "$output_dir"
exec > >(tee "$output_dir/README.txt") 2>&1

echo "Filename base: $filename"
echo "Combining runs: $sorted_runs_csv"
echo "Using burn-in: $burnin"
[ -n "$resample" ] && echo "Using resample frequency: $resample"
$ignore_trees && echo "Ignoring trees files!"
echo "Output directory: $output_dir"

# ----------------------------
# Prepare input file lists
# ----------------------------
log_files=()
trees_files=()

for run in "${sorted_runs_array[@]}"; do
    log_file="${filename}-run${run}/${filename}-run${run}.log"
    trees_file="${filename}-run${run}/${filename}-run${run}.trees"

    if [[ -f "$log_file" ]]; then
        log_files+=("-log ../$log_file")
    else
        echo "Warning: Missing $log_file"
    fi

    if ! $ignore_trees; then
        if [[ -f "$trees_file" ]]; then
            trees_files+=("-log ../$trees_file")
        else
            echo "Warning: Missing $trees_file"
        fi
    fi
done

if [ ${#log_files[@]} -eq 0 ]; then
  echo "Error: No log files found. Exiting."
  exit 1
fi

# ----------------------------
# Combine log files
# ----------------------------
cd "$output_dir" || exit 1

resample_arg=""
[ -n "$resample" ] && resample_arg="-resample $resample"

echo "Running logcombiner on log files..."
logcombiner "${log_files[@]}" -o "${filename}.log" -b "$burnin" $resample_arg

# ----------------------------
# Optionally combine and summarize trees
# ----------------------------
if ! $ignore_trees; then
    if [ ${#trees_files[@]} -eq 0 ]; then
        echo "Warning: No trees files found; skipping tree summarization."
    else
        echo "Running logcombiner on trees files..."
        logcombiner "${trees_files[@]}" -o "${filename}.trees" -b "$burnin" $resample_arg

        echo "Summarzing SA trees (mean)..."
        treeannotator -height mean -burnin 0 -topology MCC -file "${filename}.trees" "${filename}-mcc-mean.tre"

        echo "Summarzing SA trees (median)..."
        treeannotator -height median -burnin 0 -topology MCC -file "${filename}.trees" "${filename}-mcc-median.tre"

        echo "Printing SA frequencies..."
        applauncher SampledAncestorTreeAnalyser -file "${filename}.trees" > "${filename}-sa-frequencies.txt"

        echo "Converting to extant trees..."
        applauncher FullToExtantTreeConverter -trees "${filename}.trees" -output "${filename}-extant.trees"

        echo "Summarizing extant trees (CA)..."
        treeannotator -height CA -burnin 0 -topology CCD0 -file "${filename}-extant.trees" "${filename}-extant-ccd0map-CA.tre"

        echo "Summarizing extant trees (median)..."
        treeannotator -height median -burnin 0 -topology CCD0 -file "${filename}-extant.trees" "${filename}-extant-ccd0map-median.tre"
    fi
else
    echo "Skipping all tree processing due to --ignore-trees"
fi

echo "✅ All steps complete. See README.txt for log."