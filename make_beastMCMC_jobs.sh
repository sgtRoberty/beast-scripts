#!/bin/bash
# --------------------------------------------------------------------------------------------------
# SCRIPT:      make_beastMCMC_jobs.sh
# AUTHOR:      Robert Haobo Yuan
# DATE:        2025-10-14
#
# DESCRIPTION:
# This script makes replicate folders for a BEAST2 MCMC analysis based on an existing XML file and SLURM submission (SH) script in the current directory.
# It copies and renames the XML and SH files into each replicate folder, adjusting the job name and XML filename in the SH file accordingly.
# The user should adjust the submission details (time, memory, etc.) in the SLURM submission script as needed before running this script.
# Ensure that only one .xml and one submit*.sh file are present in the directory.
#
# USAGE:
# ./make_beastMCMC_jobs.sh <number_of_replicates> [starting_run_number]
#
# --------------------------------------------------------------------------------------------------

# Check for exactly one .xml and one submit*.sh file in the current directory
xml_files=( *.xml )
sh_files=( submit*.sh )

if [[ ${#xml_files[@]} -ne 1 || ${#sh_files[@]} -ne 1 ]]; then
  echo "Error: Make sure there is exactly one .xml file and one submit*.sh file in the current directory."
  exit 1
fi

xml_file="${xml_files[0]}"
sh_file="${sh_files[0]}"
base_name="${xml_file%.xml}"
sh_base="${sh_file%.sh}"

# Show usage if arguments are missing or excessive
if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 <number_of_replicates> [starting_run_number]"
  echo "  <number_of_replicates>   Required. Number of replicate folders to create."
  echo "  [starting_run_number]    Optional. Run number to start from. If omitted, the next available run number is used."
  exit 1
fi

replicate_count="$1"

# Validate replicate count
if ! [[ "$replicate_count" =~ ^[1-9][0-9]*$ ]]; then
  echo "Error: <number_of_replicates> must be a positive integer."
  exit 1
fi

# Determine starting run number
if [[ -n "$2" ]]; then
  if ! [[ "$2" =~ ^[0-9]+$ ]]; then
    echo "Error: [starting_run_number] must be a non-negative integer."
    exit 1
  fi
  starting_run_number="$2"
else
  # Auto-detect next available run number
  existing_folders=( $(ls -d ${base_name}-run[0-9]* 2>/dev/null) )
  max_run_number=0
  for folder in "${existing_folders[@]}"; do
    if [[ $folder =~ -run([0-9]+)$ ]]; then
      run_number="${BASH_REMATCH[1]}"
      if (( run_number > max_run_number )); then
        max_run_number=$run_number
      fi
    fi
  done
  starting_run_number=$((max_run_number + 1))
fi

echo "Creating $replicate_count replicates starting from run${starting_run_number}..."

# Create replicate folders safely
created_count=0
for (( i = 0; i < replicate_count; i++ )); do
  current_run_number=$((starting_run_number + i))
  folder_name="${base_name}-run${current_run_number}"

  if [[ -d "$folder_name" ]]; then
    echo "Warning: Folder '$folder_name' already exists. Skipping."
    continue
  fi

  mkdir -p "$folder_name"

  # Copy and rename XML
  new_xml_name="${base_name}-run${current_run_number}.xml"
  cp "$xml_file" "$folder_name/$new_xml_name"

  # Prepare and copy SH file
  new_sh_name="${sh_base}-run${current_run_number}.sh"
  sed \
    -e "s|^#SBATCH --job-name=.*|#SBATCH --job-name=${base_name}-run${current_run_number}|" \
    -e "s|${xml_file}|-overwrite ${new_xml_name}|g" \
    "$sh_file" > "$folder_name/$new_sh_name"

 # Prepare and copy resume SH file
  new_resume_sh_name="resume-${sh_base}-run${current_run_number}.sh"
  sed \
    -e "s|^#SBATCH --job-name=.*|#SBATCH --job-name=resume-${base_name}-run${current_run_number}|" \
    -e "s|${xml_file}|-resume ${new_xml_name}|g" \
    "$sh_file" > "$folder_name/$new_resume_sh_name"

  ((created_count++))
done

echo "✅ Created $created_count replicate folder(s)."