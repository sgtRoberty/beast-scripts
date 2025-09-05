#!/usr/bin/env Rscript

# Load required package
suppressMessages(library(tools))  # For safer file handling

# Handle command-line arguments
args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 2) {
  stop("Usage: Rscript compute_sd.R <input_csv_file> <column_prefix>")
}

input_file <- args[1]
column_prefix <- args[2]

# Check if file exists
if (!file.exists(input_file)) {
  stop(paste("File does not exist:", input_file))
}

# Read CSV file
df <- read.csv(input_file, stringsAsFactors = FALSE)

# Identify columns starting with the specified prefix
target_cols <- grep(paste0("^", column_prefix), names(df), value = TRUE)

if (length(target_cols) == 0) {
  stop(paste("No columns found starting with prefix:", column_prefix))
}

# Compute mean and standard deviation for each target column
means <- sapply(df[target_cols], mean, na.rm = TRUE)
sds <- sapply(df[target_cols], sd, na.rm = TRUE)

# Create result table and print it
result <- data.frame(
  Step = target_cols,
  Mean = means,
  SD = sds,
  row.names = NULL
)

print(result)
