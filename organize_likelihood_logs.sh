#!/bin/bash
#
# Top-level folder to store all stepX folders
output_root="organized_likelihood_logs"
mkdir -p "$output_root"

# Loop through all folders matching *-run*
for run_dir in *-run*; do
    # Ensure it's a directory
    [[ -d "$run_dir" ]] || continue

    # Extract base name (before -run) and run number (after -run)
    if [[ "$run_dir" =~ ^(.+)-run([0-9]+)$ ]]; then
        base_name="${BASH_REMATCH[1]}"
        run_number="${BASH_REMATCH[2]}"
    else
        echo "Skipping $run_dir — name format not matched"
        continue
    fi

    step_root="$run_dir/tmp/step"

    # Loop through step folders
    for step_path in "$step_root"/step*; do
        [[ -d "$step_path" ]] || continue

        step_name=$(basename "$step_path")  # e.g., step0
        if [[ "$step_name" =~ step([0-9]+) ]]; then
            step_number="${BASH_REMATCH[1]}"
        else
            echo "Skipping $step_path — step number not found"
            continue
        fi

        # Check for likelihood.log
        log_file="$step_path/likelihood.log"
        if [[ -f "$log_file" ]]; then
            # Construct new filename and target directory
            new_name="${base_name}-run${run_number}-step${step_number}-likelihood.log"
            target_dir="$output_root/step${step_number}"

            mkdir -p "$target_dir"
            cp "$log_file" "$target_dir/$new_name"
            echo "Copied $log_file → $target_dir/$new_name"
        else
            echo "Missing: $log_file"
        fi
    done
done
