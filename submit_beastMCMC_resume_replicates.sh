#!/bin/bash
# --------------------------------------------------------------------------------------------------
# SCRIPT:      submit_beastMCMC_resume_replicates.sh
# AUTHOR:      Robert Haobo Yuan
# DATE:        2025-10-10
#
# DESCRIPTION:
# This script submits SLURM jobs to resume BEAST2 runs located in replicate folders created by make_beastMCMC_run_replicates.sh.
# It allows users to specify which runs to submit using the --run argument.
#
# USAGE:
# ./submit_beastMCMC_resume_replicates.sh [--run N|N-N,N,...|all]
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
resume_sh_files=( resume-submit*.sh )

if [[ ${#xml_files[@]} -ne 1 || ${#resume_sh_files[@]} -ne 1 ]]; then
  echo "Error: Make sure there is exactly one .xml file and one resume-submit*.sh file in the current directory."
  exit 1
fi

xml_file="${xml_files[0]}"
base_name="${xml_file%.xml}"
resume_sh_file="${resume_sh_files[0]}"
resume_sh_base="${resume_sh_file%.sh}"

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
            # Prepare and modify SH file
            new_xml_name="${base_name}-run${run_num}.xml"
            new_resume_sh_name="${resume_sh_base}-run${run_num}.sh"
            echo "→ Creating $(basename "$new_resume_sh_name") in $folder"
            sed \
            -e "s|^#SBATCH --job-name=.*|#SBATCH --job-name=resume-${base_name}-run${run_num}|" \
            -e "s|${xml_file}|${new_xml_name}|g" \
            "$resume_sh_file" > "$folder/$new_resume_sh_name"

            echo "→ Submitting $(basename "$new_resume_sh_name") from $folder"
            (cd "$folder" && sbatch "$(basename "$new_resume_sh_name")")
        fi
    fi
done

echo "✅ Submission complete."
