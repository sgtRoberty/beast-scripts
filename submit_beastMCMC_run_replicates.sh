#!/bin/bash
# --------------------------------------------------------------------------------------------------
# SCRIPT:      submit_beastMCMC_run_replicates.sh
# AUTHOR:      Robert Haobo Yuan
# DATE:        2025-10-10
#
# DESCRIPTION:
# This script submits SLURM jobs for BEAST2 runs located in replicate folders created by make_beastMCMC_run_replicates.sh.
# It allows users to specify which runs to submit using the --run argument.
#
# USAGE:
# ./submit_beastMCMC_run_replicates.sh [--run N|N-N,N,...|all]
#
# --------------------------------------------------------------------------------------------------

# Default run argument
run_arg="all"

print_usage() {
    echo "Usage: $0 [--run N|N-N,N,...|all]"
    echo ""
    echo "Options:"
    echo "  --run N       Submit jobs only for specific runs or ranges (e.g., 1,3-5)"
    echo "  --run all     Submit jobs across all runs (default)"
    echo ""
    echo "Examples:"
    echo "  $0 --run all"
    echo "  $0 --run 2"
    echo "  $0 --run 1-3,5"
    exit 1
}

# Expand list like "1,3-5" to: 1 3 4 5
expand_list() {
    local input=$1
    local result=()
    IFS=',' read -ra items <<< "$input"
    for item in "${items[@]}"; do
        if [[ "$item" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            for ((i=${BASH_REMATCH[1]}; i<=${BASH_REMATCH[2]}; i++)); do
                result+=("$i")
            done
        elif [[ "$item" =~ ^[0-9]+$ ]]; then
            result+=("$item")
        fi
    done
    echo "${result[@]}"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --run)
            run_arg="$2"
            shift 2
            ;;
        -h|--help)
            print_usage
            ;;
        *)
            echo "Unknown argument: $1"
            print_usage
            ;;
    esac
done

# Get base name from the XML file
xml_files=( *.xml )
if [[ ${#xml_files[@]} -ne 1 ]]; then
    echo "Error: Could not determine base name (expecting one .xml file)."
    exit 1
fi

base_name="${xml_files[0]%.xml}"

# Expand run list if not "all"
if [[ "$run_arg" != "all" ]]; then
    run_list=( $(expand_list "$run_arg") )
fi

echo "Submitting with: run = $run_arg"
echo ""

# Main loop over folders
folders=( ${base_name}-run[0-9]* )
if [[ ${#folders[@]} -eq 0 ]]; then
    echo "No replicate folders found."
    exit 0
fi

for folder in "${folders[@]}"; do
    if [[ "$folder" =~ -run([0-9]+)$ ]]; then
        run_num="${BASH_REMATCH[1]}"
        submit=false

        if [[ "$run_arg" == "all" ]]; then
            submit=true
        elif [[ " ${run_list[*]} " =~ " $run_num " ]]; then
            submit=true
        fi

        if $submit; then
            sh_file=$(find "$folder" -maxdepth 1 -name "submit*.sh" | head -n 1)
            if [[ -f "$sh_file" ]]; then
                echo "→ Submitting $(basename "$sh_file") from $folder"
                (cd "$folder" && sbatch "$(basename "$sh_file")")
            else
                echo "⚠️  Warning: No .sh file found in $folder"
            fi
        fi
    fi
done

echo "✅ Submission complete."
