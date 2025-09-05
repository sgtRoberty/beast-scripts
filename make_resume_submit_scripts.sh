#!/bin/bash

# --------------------------------------
# Defaults
# --------------------------------------
OVERWRITE=false
run_arg="all"
step_arg="all"

# --------------------------------------
# Usage info
# --------------------------------------
print_usage() {
    echo "Usage: $0 [--run N|N-N,N,...|all] [--step N|N-N,N,...|all] [-overwrite]"
    echo ""
    echo "Options:"
    echo "  --run N       Generate submit scripts only for these runs"
    echo "  --step N      Generate submit scripts only for these steps"
    echo "  --run all     (default) Generate for all runs"
    echo "  --step all    (default) Generate for all steps"
    echo "  -overwrite    Replace existing submit scripts"
    echo ""
    exit 1
}

# --------------------------------------
# Expand list like 1,3-5 into array
# --------------------------------------
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

# --------------------------------------
# Parse arguments
# --------------------------------------
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
        -overwrite)
            OVERWRITE=true
            shift
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

# Expand run/step lists if not 'all'
if [[ "$run_arg" != "all" ]]; then
    run_list=($(expand_list "$run_arg"))
fi
if [[ "$step_arg" != "all" ]]; then
    step_list=($(expand_list "$step_arg"))
fi

# --------------------------------------
# Main generation loop
# --------------------------------------
for run_dir in *-run[0-9]*; do
    if [[ -d "$run_dir" ]]; then
        filename=$(echo "$run_dir" | sed -E 's/^(.*)-run[0-9]+$/\1/')
        run_num=$(echo "$run_dir" | sed -E 's/^.*-run([0-9]+)$/\1/')

        # Skip if run doesn't match filter
        if [[ "$run_arg" != "all" && ! " ${run_list[*]} " =~ " $run_num " ]]; then
            continue
        fi

        step_base="$run_dir/tmp/step"
        if [[ -d "$step_base" ]]; then
            for step_dir in "$step_base"/step*; do
                if [[ -d "$step_dir" ]]; then
                    step_name=$(basename "$step_dir")
                    step_num=$(echo "$step_name" | sed -E 's/^step([0-9]+)$/\1/')

                    # Skip if step doesn't match filter
                    if [[ "$step_arg" != "all" && ! " ${step_list[*]} " =~ " $step_num " ]]; then
                        continue
                    fi

                    resume_script="$step_dir/resume.sh"
                    if [[ -f "$resume_script" ]]; then
                        submit_script_name="submit-${filename}-run${run_num}-step${step_num}-resume.sh"
                        submit_script_path="${step_dir}/${submit_script_name}"
                        job_name="${filename}-run${run_num}-step${step_num}-resume"

                        if [[ -f "$submit_script_path" && "$OVERWRITE" == false ]]; then
                            echo "SKIPPED: $submit_script_name already exists in $step_dir"
                        else
                            cat <<EOF > "$submit_script_path"
#!/bin/bash
#SBATCH --time=240:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=2G
#SBATCH --job-name=$job_name
#SBATCH --output=slurm-%x-%j.out

chmod +x resume.sh
./resume.sh
EOF

                            if [[ "$OVERWRITE" == true ]]; then
                                echo "OVERWRITTEN: $submit_script_name in $step_dir"
                            else
                                echo "CREATED: $submit_script_name in $step_dir"
                            fi
                        fi
                    fi
                fi
            done
        fi
    fi
done
