#!/bin/bash

# Defaults
run_arg="all"
step_arg="all"

# Usage info
print_usage() {
    echo "Usage: $0 [--run N|N-N,N,...|all] [--step N|N-N,N,...|all]"
    echo ""
    echo "Options:"
    echo "  --run N       Submit jobs only for specific runs or ranges (e.g., 1,3-5)"
    echo "  --step N      Submit jobs only for specific steps or ranges (e.g., 1-2,4)"
    echo "  --run all     Submit jobs across all runs (default)"
    echo "  --step all    Submit jobs across all steps (default)"
    echo ""
    echo "Examples:"
    echo "  $0 --run all --step all"
    echo "  $0 --run 2 --step all"
    echo "  $0 --run all --step 5"
    echo "  $0 --run 3 --step 7"
    echo "  $0 --run 1-3,6 --step 2,4-5"
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

# Expand runs and steps if not 'all'
if [[ "$run_arg" != "all" ]]; then
    run_list=($(expand_list "$run_arg"))
fi

if [[ "$step_arg" != "all" ]]; then
    step_list=($(expand_list "$step_arg"))
fi

echo "Submitting jobs with: run = $run_arg, step = $step_arg"
echo ""

# Main loop to find and submit matching scripts
find . -type f -name "submit-*.sh" | while read -r script; do
    if [[ "$script" =~ submit-(.+)-run([0-9]+)-step([0-9]+)\.sh$ ]]; then
        run_num="${BASH_REMATCH[2]}"
        step_num="${BASH_REMATCH[3]}"
        script_name=$(basename "$script")
        script_dir=$(dirname "$script")
        submit=false

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
            echo "→ Submitting $script_name from $script_dir"
            (cd "$script_dir" && sbatch "$script_name")
        fi
    fi
done
