#!/bin/bash
# --------------------------------------------------------------------------------------------------
# SCRIPT:      submit_pathsampling_jobs.sh
# AUTHOR:      Robert Haobo Yuan
# DATE:        2025-10-14
#
# DESCRIPTION:
# Submits SLURM jobs for BEAST2 path-sampling/stepping-stone setups.
# Supports two modes:
#   --mode run       submits run.sh files
#   --mode resume    submits resume.sh files
#
# Works with directory layout:
#   ./<basename>-run1/tmp/step/step0/run.sh
#
# USAGE:
#   ./submit_pathsampling_jobs.sh [--mode run|resume] [--run N|N-N,N,...|all] [--step N|N-N,N,...|all]
# --------------------------------------------------------------------------------------------------

# Defaults
run_arg="all"
step_arg="all"
mode="run"

print_usage() {
    echo "Usage: $0 [--mode run|resume] [--run N|N-N,N,...|all] [--step N|N-N,N,...|all]"
    echo ""
    echo "Examples:"
    echo "  $0 --mode run --run all --step all"
    echo "  $0 --mode resume --run 2 --step all"
    echo "  $0 --mode run --run 1-3,6 --step 2,4-5"
    exit 1
}

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

# Parse args
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
            echo "❌ Unknown argument: $1"
            print_usage
            ;;
    esac
done

if [[ "$mode" != "run" && "$mode" != "resume" ]]; then
    echo "❌ Error: --mode must be 'run' or 'resume'"
    exit 1
fi

if [[ "$run_arg" != "all" ]]; then
    run_list=($(expand_list "$run_arg"))
fi
if [[ "$step_arg" != "all" ]]; then
    step_list=($(expand_list "$step_arg"))
fi

echo "🔧 Submitting mode: $mode | runs: $run_arg | steps: $step_arg"
echo ""

submitted_count=0

# ✅ Use process substitution instead of a pipe
while read -r script; do
    [[ -z "$script" ]] && continue

    if [[ "$script" =~ -run([0-9]+)/tmp/step/step([0-9]+)/${mode}\.sh$ ]]; then
        run_num="${BASH_REMATCH[1]}"
        step_num="${BASH_REMATCH[2]}"
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
            echo "→ Submitting ${mode}.sh for run${run_num}, step${step_num}"
            (cd "$script_dir" && sbatch "${mode}.sh")
            ((submitted_count++))
        fi
    fi
done < <(find . -type f -path "*/tmp/step/step*/${mode}.sh" | sort)

echo ""
echo "✅ Submission complete. Total jobs submitted: $submitted_count"