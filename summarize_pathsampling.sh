#!/bin/bash

# This script performs three main actions:
# 1. Runs the 'PathSampleAnalyser' for all run directories.
# 2. Compiles step-specific data (Step, Likelihood, Contribution) into a temporary file.
# 3. Calculates the Mean and Standard Deviation for Likelihood and Contribution for EACH STEP.

# --- Default Values and Configuration ---
alpha=0.3
burnIn=50
output_csv=""
SEARCH_PATTERN="./*run[0-9]*"
TEMP_CSV="temp_long_data_for_stats.csv" # Temporary file for aggregation

# --- Usage Function ---
usage() {
    echo "Usage: $0 [-alpha value] [-burnInPercentage value] <output_summary_csv_filename>"
    echo "Example: $0 -alpha 0.3 -burnInPercentage 50 step_summary.csv"
    exit 1
}

# --- Argument Parsing ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        -alpha)
            alpha="$2"
            shift 2
            ;;
        -burnInPercentage)
            burnIn="$2"
            if ! [[ "$burnIn" =~ ^[0-9]+$ ]]; then
                echo "Error: -burnInPercentage must be a non-negative integer."
                usage
            fi
            shift 2
            ;;
        -*)
            echo "Unknown option: $1"
            usage
            ;;
        *)
            if [[ -z "$output_csv" ]]; then
                output_csv="$1"
                shift 1
            else
                echo "Error: Too many positional arguments."
                usage
            fi
            ;;
    esac
done

# Final check for mandatory argument
if [[ -z "$output_csv" ]]; then
    echo "Error: Output CSV filename is required."
    usage
fi

# Clean up previous temporary file if it exists
if [[ -f "$TEMP_CSV" ]]; then
    rm "$TEMP_CSV"
fi

echo "--- Phase 1: Running Path Sample Analysis ---"
echo "Configuration: alpha=$alpha, burnInPercentage=$burnIn"

# --- Phase 1: Analysis Execution (Creates the *.out files) ---
for rundir in $SEARCH_PATTERN; do
    if [[ -d "$rundir" && -d "$rundir/tmp/step" ]]; then
        echo "  - Analyzing $rundir..."
        base=$(basename "$rundir")
        
        if [[ "$base" =~ PS([0-9]+) ]]; then
            nrOfSteps="${BASH_REMATCH[1]}"
        else
            echo "    Warning: Could not extract nrOfSteps (PS[N]) from $base. Skipping."
            continue
        fi

        (
            cd "$rundir" || exit 1
            applauncher PathSampleAnalyser \
                -rootdir tmp/step \
                -alpha "$alpha" \
                -nrOfSteps "$nrOfSteps" \
                -burnInPercentage "$burnIn" \
                &> "${base}.out"
        )
        if [ $? -ne 0 ]; then
            echo "    ERROR: PathSampleAnalyser failed for $rundir. Check ${base}.out."
        fi
    fi
done

echo "--- Phase 2: Compiling Step Data and Calculating Statistics ---"

# --- Phase 2A: Compile data into a temporary long-format CSV ---
# Header for temporary file
echo "filename,step,likelihood,contribution,marginal_L_estimate" > "$TEMP_CSV"

for dir in $SEARCH_PATTERN; do
    dir_name=$(basename "$dir")
    out_file="$dir/$dir_name.out"

    if [[ ! -f "$out_file" ]]; then
        echo "  ⚠️ Output file not found: $out_file"
        continue
    fi
    
    # Extract Marginal L estimate (constant per file)
    marginal_L=$(grep "marginal L estimate" "$out_file" | awk -F= '{print $2}' | tr -d ' ')

    # Use AWK to extract the step table rows and prepend constant data
    # NOTE: OFS="," ensures the output is comma-separated for the next AWK stage
    awk -v fname="$dir_name" -v ml="$marginal_L" '
        BEGIN { in_table=0; OFS="," }
        
        # Start tracking when we hit the table header (robust regex for leading spaces)
        /^[[:space:]]*Step[[:space:]]+theta[[:space:]]+likelihood[[:space:]]+contribution[[:space:]]+ESS/ { in_table=1; next }
        
        # Stop tracking after the table
        /^sum\(ESS\)/ { in_table=0 }
        
        # Process the data rows in the table
        # $1=Step, $3=Likelihood, $4=Contribution based on sample output
        in_table && NF >= 5 {
            print fname, $1, $3, $4, ml
        }
    ' "$out_file" >> "$TEMP_CSV"
done

# --- Phase 2B: Calculate Step-wise Stats from Temp CSV using AWK ---
# Reads the temporary CSV and groups values by step for calculation.

awk -F, -v OFS=, -v output_file="$output_csv" '
# --- AWK Functions for Statistics ---

# Function to calculate Mean
function get_mean(sum, n) {
    if (n > 0) return sum / n
    return "NA"
}

# Function to calculate Standard Deviation
function get_sd(sum_x_sq, sum_x, n) {
    if (n < 2) return "NA"
    var = sum_x_sq - (sum_x * sum_x) / n
    if (var < 0) var = 0; 
    return sqrt(var / (n - 1))
}

# --- Data Aggregation ---

NR > 1 {
    # Column indices from temp file:
    # $1=filename, $2=step, $3=likelihood, $4=contribution, $5=marginal_L_estimate
    
    step = $2 + 0
    L = $3 + 0
    C = $4 + 0
    ML = $5 + 0
    filename = $1 # Reset filename for the current row
    
    # Track all unique marginal L estimates for overall Mean/SD calculation
    # Only store the ML estimate once per unique filename
    if (!(filename in marginalL_values)) {
        marginalL_values[filename] = ML
        filename_list[++fcount] = filename
    }

    # Aggregate Likelihood per step (using step as array key)
    sum_L[step] += L
    sum_L_sq[step] += L * L
    count_L[step]++

    # Aggregate Contribution per step (using step as array key)
    sum_C[step] += C
    sum_C_sq[step] += C * C
    count_C[step]++
    
    # Keep track of all steps encountered
    if (!(step in steps)) {
        steps[step] = 1
        step_list[++step_count] = step
    }
}

# --- End Block: Calculate and Print Results ---
END {
    # 1. Calculate and print overall Marginal L Estimate Stats (across runs)
    sum_ML = 0; sum_ML_sq = 0; count_ML = 0;
    
    for (i=1; i<=fcount; i++) {
        ML = marginalL_values[filename_list[i]]
        sum_ML += ML
        sum_ML_sq += ML * ML
        count_ML++
    }
    
    mean_ML = get_mean(sum_ML, count_ML);
    sd_ML = get_sd(sum_ML_sq, sum_ML, count_ML);
    
    # Print Header
    print "Metric,Step,Mean,SD,Count" > output_file;
    print "Marginal_L_Estimate" OFS "Overall" OFS mean_ML OFS sd_ML OFS count_ML >> output_file;

    # Sort steps numerically for clean output
    asort(step_list)
    
    # 2. Calculate and print Likelihood and Contribution Stats (per step)
    for (i=1; i<=step_count; i++) {
        step = step_list[i]
        
        # Likelihood
        mean_L = get_mean(sum_L[step], count_L[step]);
        sd_L = get_sd(sum_L_sq[step], sum_L[step], count_L[step]);
        print "Likelihood" OFS step OFS mean_L OFS sd_L OFS count_L[step] >> output_file;
        
        # Contribution
        mean_C = get_mean(sum_C[step], count_C[step]);
        sd_C = get_sd(sum_C_sq[step], sum_C[step], count_C[step]);
        print "Contribution" OFS step OFS mean_C OFS sd_C OFS count_C[step] >> output_file;
    }
}
' "$TEMP_CSV"

# Clean up the temporary file
rm "$TEMP_CSV"

echo "--- Complete ---"
echo "✔ Final statistical summary written to $output_csv"