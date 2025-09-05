#!/bin/bash

# Find the .xml file in the current directory
xml_files=( *.xml )

# Ensure exactly one .xml file is present
if [[ ${#xml_files[@]} -ne 1 ]]; then
  echo "Error: Exactly one .xml file must be present in the current directory."
  exit 1
fi

xml_file="${xml_files[0]}"
base_name="${xml_file%.xml}"
submit_script="submit-${base_name}.sh"

# Write the submit script
cat > "$submit_script" <<EOF
#!/bin/bash
#SBATCH --time=24:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=1G
#SBATCH --job-name=${base_name}
#SBATCH --output=slurm-%x-%j.out

~/BEAST2/beast/bin/beast -threads 1 ${base_name}.xml
EOF

echo "Submit script created: $submit_script"
