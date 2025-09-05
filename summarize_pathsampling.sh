#!/bin/bash

# Default values
alpha=0.3
burnIn=50

# Usage message
usage() {
    echo "Usage: $0 [-alpha value] [-burnInPercentage value]"
    echo "Example: $0 -alpha 0.3 -burnInPercentage 50"
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -alpha)
            alpha="$2"
            shift 2
            ;;
        -burnInPercentage)
            burnIn="$2"
            shift 2
            ;;
        *)
            usage
            ;;
    esac
done

echo "Using alpha = $alpha"
echo "Using burnInPercentage = $burnIn"
echo

# Loop through all run(N) folders in the current directory
for rundir in ./*run[0-9]*; do
    if [[ -d "$rundir/tmp/step" ]]; then
        echo "Analyzing $rundir..."

        base=$(basename "$rundir")  # e.g., 8+dna_R-gradual-netDiv-PS20-run1
        outfile="${base}"

        # Extract the number after PS using regex
        if [[ "$base" =~ PS([0-9]+) ]]; then
            nrOfSteps="${BASH_REMATCH[1]}"
        else
            echo "Warning: Could not extract nrOfSteps from $base. Skipping."
            continue
        fi

        (
            cd "$rundir" || exit
            applauncher PathSampleAnalyser \
                -rootdir tmp/step \
                -alpha "$alpha" \
                -nrOfSteps "$nrOfSteps" \
                -burnInPercentage "$burnIn" \
                &> "${base}.out"
        )
    fi
done
