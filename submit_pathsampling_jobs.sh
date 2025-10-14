#!/bin/bash
# --------------------------------------------------------------------------------------------------
# SCRIPT:      submit_pathsampling_jobs.sh
# AUTHOR:      Robert Haobo Yuan
# DATE:        2025-10-14
#
# DESCRIPTION:
# This script submits SLURM jobs for BEAST2 path sampling / stepping-stone sampling.
# You can choose whether to submit the "run.sh" or "resume.sh" scripts.
# It allows filtering by run and step numbers.
#
# USAGE:
# ./submit_pathsampling_jobs.sh [--mode run|resume] [--run N|N-N,N,...|all] [--step N|N-N,N,...|all]
#
# --------------------------------------------------------------------------------------------------

# Defaults
run_arg="all"
step_arg="all"
mode="run"

# Usage info
print_usage() {
    echo "Usage: $0 [--mode run|resume] [--run N|N-N,N,...|all] [--step N|N-N,N,...|all]"
    echo ""
    echo "Options:"
    echo "  --mode run       Submit 'run.sh' jobs (default)"
    echo "  --mode resume    Submit 'resume.sh' jobs"
    echo "  --run N          Submit jobs for specific runs (e.g., 1,3-5)"
    echo "  --step N         Submit jobs for specific steps (e.g., 1,3-4)"
    echo "  --run all        Submit across all runs (default)"
    echo "  --step all       Submit across all steps (default)"
    echo ""
    echo "Examples:"
    echo "  $0 --mode run --run all --step all"
    echo "  $0 --mode resume --run 2 --step all"
    echo "  $0 --mode run --run 1-3,6 --step 2,4-5"
    exit 1
}

# Expand list like 1,3-5 into array: 1 3 4 5
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
    key="$1"
    case $key in
        --mode)
            mode="$2"
            shift 2
            ;;
        --run)
            run_arg="$2"
            shift 2
            ;;
        --step)
            step_arg="$2"
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

# Validate mode
if [[ "$mode" != "run" && "$mode" != "resume" ]]; then
    echo "❌ Error: --mode must be 'run' or 'resume'"
    exit 1
fi

# Expand runs and steps if not 'all'
if [[ "$run_arg" != "all" ]]; then
    run_list=($(expand_list "$run_arg"))
fi
if [[ "$step_arg" != "all" ]]; then
    step_list=($(expand_list "$step_arg"))
fi

echo "Submitting $mode jobs with: run = $run_arg, step = $step_arg"
echo ""

# Main loop: find all matching run/resume scripts
find . -type f -name "$mode.sh" | while read -r script; do
    # Expect path like: ./cephalopods-strClkSpk-run1/tmp/step3/run.sh
    if [[ "$script" =~ -run([0-9]+)/tmp/step([0-9]+)/$mode\.sh$ ]]; then
        run_num="${BASH_REMATCH[1]}"
        step_num="${BASH_REMATCH[2]}"
        script_dir=$(dirname "$script")
        script_name=$(basename "$script")
        submit=false

        # Determine whether to submit
        if [[ "$run_arg" == "all" && "$step_arg" == "all" ]]; then
            submit=true
        elif [[ "$run_arg" == "all" && " ${step_list[*]} " =~ " $step_num " ]]; then
            submit=true
        elif [[ "$step_arg" == "all" && " ${run_list[*]} " =~ " $run_num " ]]; then
            submit=true
        elif [[ " ${run_list[*]} " =~ " $run_num " && " ${step_list[*]} " =~ " $step_num " ]]; then
            submit=true
        fi

        if $submit; then
            echo "→ Submitting ${mode}.sh for run${run_num}, step${step_num}"
            (cd "$script_dir" && sbatch "$script_name")
        fi
    fi
done

echo ""
echo "✅ Submission complete."