#!/usr/bin/env Rscript

librarian::shelf(
  glue,
  quiet = T)

# Define the base directory and output directory
base_dir   <- "~/Github/CalCOFI"
date_beg   <- "2025-07-01"
output_dir <- "~/Github/CalCOFI/_git-logs_{date_beg}-to-{Sys.Date()}" |> glue()

# List of repository folders
# from visiting https://github.com/orgs/CalCOFI/repositories sorted by Last pushed
repos <- c(
  "int-app", "workflows", "server", "CalCOFI.github.io",
  "docs", "calcofi4db", "calcofi4r")

# Ensure output directory exists
if (!dir.exists(output_dir))
  dir.create(output_dir, recursive = T)

# Loop through each repository
for (repo in repos) {

  cat(sprintf("\n=== Processing repository: %s ===\n", repo))

  # Full path to repository
  repo_path <- file.path(base_dir, repo)

  # Check if repository exists
  if (!dir.exists(repo_path)) {
    warning(sprintf("Repository not found: %s\n", repo_path))
    next
  }

  # Check for uncommitted changes
  status_output <- tryCatch({
    system2(
      command = "git",
      args = c("-C", repo_path, "status", "--porcelain"),
      stdout = TRUE,
      stderr = TRUE
    )
  }, error = function(e) {
    return(NULL)
  })

  # Warn if there are uncommitted changes
  if (!is.null(status_output) && length(status_output) > 0) {
    warning(sprintf("⚠️  Repository '%s' has uncommitted changes:\n", repo),
            immediate. = TRUE)
    cat(paste("  ", status_output, collapse = "\n"), "\n")
  }

  # Run git log command
  git_output <- tryCatch({
    system2(
      command = "git",
      args = c("-C", repo_path, "log", glue("--since={date_beg}"), "--oneline"),
      stdout = TRUE,
      stderr = TRUE
    )
  }, error = function(e) {
    return(paste("Error:", e$message))
  })

  # Write output to file
  output_file <- file.path(output_dir, paste0(repo, ".txt"))
  writeLines(git_output, output_file)

  cat(sprintf("✓ Saved to: %s (%d commits)\n",
              output_file, length(git_output)))
}

cat("\n=== Done! All git logs saved. ===\n")
