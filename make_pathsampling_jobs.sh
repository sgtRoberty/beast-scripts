#!/usr/bin/env bash
# --------------------------------------------------------------------------------------------------
# SCRIPT:      make_pathsampling_jobs.sh
# AUTHOR:      Robert Haobo Yuan
# DATE:        2025-10-14
#
# USAGE:
# ./make_pathsampling_jobs.sh input.xml <chainLength> <preBurnin> <numSteps> <alpha> <posterior2prior:true|false> <logEvery> <numReplicates>
#
# EXAMPLE:
# ./make_pathsampling_jobs.sh cephalopods-strClkSpk.xml 1000000 100000 20 0.3 true 1000000 10
# --------------------------------------------------------------------------------------------------

set -euo pipefail

if [ "$#" -ne 8 ]; then
  echo "Usage: $0 <xml_file> <chainLength> <preBurnin> <numSteps> <alpha> <posterior2prior:true|false> <logEvery> <numReplicates>"
  exit 1
fi

XML_FILE="$1"
CHAIN_LENGTH="$2"
PRE_BURNIN="$3"
NUM_STEPS="$4"
ALPHA="$5"
POSTERIOR2PRIOR="$6"
LOG_EVERY="$7"
NUM_REPLICATES="$8"

# --- Validation ---
if ! [[ "$NUM_STEPS" =~ ^[0-9]+$ ]] || [ "$NUM_STEPS" -lt 2 ]; then
  echo "Error: numSteps must be an integer >= 2"
  exit 1
fi
if ! [[ "$NUM_REPLICATES" =~ ^[0-9]+$ ]] || [ "$NUM_REPLICATES" -lt 1 ]; then
  echo "Error: numReplicates must be >= 1"
  exit 1
fi

case "$POSTERIOR2PRIOR" in
  true|TRUE|1) POSTERIOR2PRIOR=1 ;;
  false|FALSE|0) POSTERIOR2PRIOR=0 ;;
  *) echo "Error: posterior2prior must be 'true' or 'false'"; exit 1 ;;
esac

# --- Setup names and paths ---
XML_DIR="$(cd "$(dirname "$XML_FILE")" && pwd)"
XML_BASENAME="$(basename "$XML_FILE")"
XML_NAME_NOEXT="${XML_BASENAME%.*}"

TEMPLATE_SUBMIT="submit-${XML_NAME_NOEXT}.sh"

if [ ! -f "$TEMPLATE_SUBMIT" ]; then
  echo "❌ Error: Template submit script '$TEMPLATE_SUBMIT' not found in current directory."
  exit 1
fi

echo "✅ Creating $NUM_REPLICATES replicates × $NUM_STEPS steps"
echo "Base XML: $XML_FILE"
echo "Using submit template: $TEMPLATE_SUBMIT"
echo "Alpha: $ALPHA | Chain length: $CHAIN_LENGTH | Pre-burnin: $PRE_BURNIN | Log every: $LOG_EVERY"

# --- Outer loop: replicates ---
for ((r=1; r<=NUM_REPLICATES; r++)); do
  RUN_DIR="${XML_NAME_NOEXT}-run${r}"
  BASE_DIR="${RUN_DIR}/tmp/step"
  mkdir -p "$BASE_DIR"
  BETAS_FILE="$BASE_DIR/betas.txt"
  : > "$BETAS_FILE"
  echo "step_index beta" >> "$BETAS_FILE"

  echo "▶️ Setting up replicate $r in $RUN_DIR"

  # --- Inner loop: steps ---
  for ((i=0; i<NUM_STEPS; i++)); do
    STEP_DIR="$BASE_DIR/step${i}"
    mkdir -p "$STEP_DIR"

    # Compute beta
    BETA=$(perl -Mstrict -Mwarnings -e '
      my ($i,$N,$alpha,$posterior) = @ARGV;
      my $p = $posterior ? ($N-1-$i)/($N-1) : $i/($N-1);
      my $beta;
      if ($p <= 0) { $beta = 0.0; }
      elsif ($p >= 1) { $beta = 1.0; }
      else { $beta = $p ** (1.0/$alpha); }
      printf "%.16f", $beta;
    ' "$i" "$NUM_STEPS" "$ALPHA" "$POSTERIOR2PRIOR")

    echo "$i $BETA" >> "$BETAS_FILE"

    STEP_XML="${XML_NAME_NOEXT}-run${r}-step${i}.xml"

    # Replace <run ...> line in XML
    perl -pe "if (/^(\s*)<run[^>]*\\bspec=\"MCMC\"[^>]*>/) {
      \$_ = \$1 . qq{<run id=\"PathSamplingStep\" spec=\"modelselection.inference.PathSamplingStep\" chainLength=\"$CHAIN_LENGTH\" preBurnin=\"$PRE_BURNIN\" beta=\"$BETA\">} . \"\\n\"
    }" "$XML_FILE" > "$STEP_DIR/$STEP_XML"

    # Insert likelihood logger
    perl -e '
      use strict; use warnings;
      my ($file, $logEvery) = @ARGV;
      open my $fh, "<", $file or die "open < $file: $!";
      my @lines = <$fh>;
      close $fh;
      my $last_logger = -1;
      for my $idx (0..$#lines) {
          if ($lines[$idx] =~ m{</logger>}) { $last_logger = $idx; }
      }
      my $insert = <<"END_LOG";
        <logger id="likelihoodLog" spec="Logger" fileName="likelihood.log" logEvery="$logEvery">
            <log idref="likelihood"/>
        </logger>
END_LOG
      if ($last_logger >= 0) {
          splice @lines, $last_logger+1, 0, $insert . "\n";
      } else {
          push @lines, $insert . "\n";
      }
      open my $out, ">", $file or die "open > $file: $!";
      print $out @lines;
      close $out;
    ' "$STEP_DIR/$STEP_XML" "$LOG_EVERY"

    # --- Create run.sh and resume.sh from template ---
    for mode in run resume; do
      DST="$STEP_DIR/${mode}.sh"
      cp "$TEMPLATE_SUBMIT" "$DST"
      chmod +x "$DST"

      if [[ "$mode" == "resume" ]]; then
        JOBNAME="resume-${XML_NAME_NOEXT}-run${r}-step${i}"
        XML_REF="-resume ${XML_NAME_NOEXT}-run${r}-step${i}.xml"
      else
        JOBNAME="${XML_NAME_NOEXT}-run${r}-step${i}"
        XML_REF="${XML_NAME_NOEXT}-run${r}-step${i}.xml"
      fi

      # Replace SBATCH job name
      perl -i -pe "
        if (/^\\s*#\\s*SBATCH\\b/ && /--job-name/) {
          s|^\\s*#\\s*SBATCH\\s+--job-name\\S*|#SBATCH --job-name=${JOBNAME}|;
        }
      " "$DST"

      # Replace XML file name references
      perl -i -pe "
        s/\\b\Q${XML_BASENAME}\E\\b/${XML_REF}/g;
      " "$DST"
    done

    echo "  • run${r} step${i}: beta=${BETA}"
  done

  echo "  ✅ Completed replicate $r → $RUN_DIR"
done

echo "🎉 Finished generating $NUM_REPLICATES replicates × $NUM_STEPS steps."
echo "Each run folder contains tmp/step*/ with modified XMLs and scripts."