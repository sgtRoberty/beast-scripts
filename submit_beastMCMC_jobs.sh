#!/bin/bash
# --------------------------------------------------------------------------------------------------
# SCRIPT:      submit_beastMCMC_jobs.sh
# AUTHOR:      Robert Haobo Yuan
# DATE:        2025-10-14
#
# DESCRIPTION:
# This script submits SLURM jobs for BEAST2 MCMC replicate runs created by make_beastMCMC_jobs.sh.
# Supports two modes:
#   --mode overwrite → submits submit-*.sh files
#   --mode resume    → submits resume-submit-*.sh files
#
# Allows selection of which runs to submit using --run.
#
# USAGE:
# ./submit_beastMCMC_jobs.sh [--mode overwrite|resume] [--run N|N-N,N,...|all]
#
# --------------------------------------------------------------------------------------------------

# Default settings
run_arg="all"
mode="overwrite"

print_usage() {
    echo "Usage: $0 [--mode overwrite|resume] [--run N|N-N,N,...|all]"
    echo ""
    echo "Options:"
    echo "  --mode overwrite    Submit jobs using submit-*.sh (default)"
    echo "  --mode resume       Submit jobs using resume-submit-*.sh"
    echo "  --run N             Submit jobs only for specific runs or ranges (e.g., 1,3-5)"
    echo "  --run all           Submit jobs across all runs (default)"
    echo ""
    echo "Examples:"
    echo "  $0 --mode overwrite --run all"
    echo "  $0 --mode resume --run 2"
    echo "  $0 --mode overwrite --run 1-3,5"
    exit 1
}

# Expand list like "1,3-5" → "1 3 4 5"
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
        --mode)
            mode="$2"
            shift 2
            ;;
        --run)
            run_arg="$2"
            shift 2
            ;;
        -h|--help)
            print_usage
            ;;
        *)
            echo "❌ Unknown argument: $1"
            print_usage
            ;;
    esac
done

# Validate mode
if [[ "$mode" != "overwrite" && "$mode" != "resume" ]]; then
    echo "❌ Error: --mode must be 'overwrite' or 'resume'"
    exit 1
fi

# Determine base name from XML file
xml_files=( *.xml )
if [[ ${#xml_files[@]} -ne 1 ]]; then
    echo "❌ Error: Could not determine base name (expecting one .xml file in current dir)."
    exit 1
fi
base_name="${xml_files[0]%.xml}"

# Expand run list if needed
if [[ "$run_arg" != "all" ]]; then
    run_list=( $(expand_list "$run_arg") )
fi

echo "🔧 Submitting in '$mode' mode for: run = $run_arg"
echo ""

# Find all replicate folders
folders=( ${base_name}-run[0-9]* )
if [[ ${#folders[@]} -eq 0 ]]; then
    echo "⚠️  No replicate folders found."
    exit 0
fi

submitted_count=0

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
            if [[ "$mode" == "overwrite" ]]; then
                sh_file=$(find "$folder" -maxdepth 1 -name "submit-*.sh" | head -n 1)
            else
                sh_file=$(find "$folder" -maxdepth 1 -name "resume-submit-*.sh" | head -n 1)
            fi

            if [[ -f "$sh_file" ]]; then
                echo "→ Submitting $(basename "$sh_file") from $folder"
                (cd "$folder" && sbatch "$(basename "$sh_file")")
                ((submitted_count++))
            else
                echo "⚠️  No ${mode} script found in $folder"
            fi
        fi
    fi
done

echo ""
echo "✅ Submission complete. Total jobs submitted: $submitted_count"