#!/bin/bash

# Default arguments
run_arg="all"
step_arg="all"
update_mode=false
new_chainlength=""

# Usage
print_usage() {
    echo "Usage: $0 [--run N|all] [--step M|all] [--set <new_chainLength>]"
    echo ""
    echo "Options:"
    echo "  --run N           Process only run number N"
    echo "  --step M          Process only step number M"
    echo "  --set VALUE       Update chainLength to the specified VALUE"
    echo "  --help, -h        Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --run 2 --step all"
    echo "  $0 --step 5 --set 50000000"
    echo "  $0 --run all --step all --set 100000000"
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --run)
            run_arg="$2"
            shift 2
            ;;
        --step)
            step_arg="$2"
            shift 2
            ;;
        --set)
            update_mode=true
            new_chainlength="$2"
            shift 2
            ;;
        --help|-h)
            print_usage
            ;;
        *)
            echo "Unknown argument: $1"
            print_usage
            ;;
    esac
done

# Summary
if $update_mode; then
    echo "Will update chainLength to: $new_chainlength"
fi
echo "Filtering by: run = $run_arg, step = $step_arg"
echo

# Process each beast.xml
find . -type f -path "*/tmp/step/step*/beast.xml" | while read -r xmlfile; do
    # Extract run and step numbers from path
    if [[ "$xmlfile" =~ -run([0-9]+)/tmp/step/step([0-9]+)/beast\.xml$ ]]; then
        run_num="${BASH_REMATCH[1]}"
        step_num="${BASH_REMATCH[2]}"
    else
        echo "Skipping (unrecognized path): $xmlfile"
        continue
    fi

    # Determine if file should be processed
    should_process=false
    if [[ "$run_arg" == "all" && "$step_arg" == "all" ]]; then
        should_process=true
    elif [[ "$run_arg" == "$run_num" && "$step_arg" == "all" ]]; then
        should_process=true
    elif [[ "$step_arg" == "$step_num" && "$run_arg" == "all" ]]; then
        should_process=true
    elif [[ "$run_arg" == "$run_num" && "$step_arg" == "$step_num" ]]; then
        should_process=true
    fi

    if $should_process; then
        current_chainlength=$(grep 'spec="modelselection.inference.PathSamplingStep"' "$xmlfile" | \
            sed -n 's/.*chainLength="\([0-9]*\)".*/\1/p')

        if [[ -n "$current_chainlength" ]]; then
            echo "$xmlfile: chainLength = $current_chainlength"
        else
            echo "$xmlfile: chainLength NOT FOUND"
            continue
        fi

        if $update_mode; then
            sed -i.bak -E 's/(<run[^>]*spec="modelselection\.inference\.PathSamplingStep"[^>]*chainLength=")[0-9]+"/\1'"$new_chainlength"'"/' "$xmlfile"
            echo "→ Updated to: $new_chainlength"
        fi
    fi
done
