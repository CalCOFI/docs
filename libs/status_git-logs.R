#!/usr/bin/env Rscript
# Collect the git log of every CalCOFI repository since a date, one file per repo, as the raw
# material for a dated entry in status.qmd. The repository list comes from the landing page's
# product cards (data/products.yml, snapshotted by libs/pre-render.R), so a product added to
# calcofi.io is reviewed here without editing this script.
#
#   Rscript libs/status_git-logs.R 2026-09-01        # since the last entry
librarian::shelf(glue, yaml, quiet = TRUE)

date_beg   <- if (length(commandArgs(trailingOnly = TRUE))) commandArgs(trailingOnly = TRUE)[1] else "2026-09-01"
base_dir   <- "~/Github/CalCOFI"
output_dir <- glue("~/Github/CalCOFI/_git-logs_{date_beg}-to-{Sys.Date()}")

prod  <- yaml::read_yaml("data/products.yml")
urls  <- vapply(prod$products, function(p) p$source_url %||% "", character(1))
repos <- unique(sub("/.*$", "", sub("^https://github.com/CalCOFI/", "", urls[grepl("^https://github.com/CalCOFI/", urls)])))
repos <- union(repos, c("workflows", "calcofi4db", "server", "uptime", "analytics"))   # the ones with no card

if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

for (repo in repos) {
  repo_path <- file.path(base_dir, repo)
  if (!dir.exists(repo_path)) { warning(sprintf("not cloned: %s", repo_path)); next }
  cat(sprintf("\n=== %s ===\n", repo))
  dirty <- system2("git", c("-C", repo_path, "status", "--porcelain"), stdout = TRUE)
  if (length(dirty)) cat(sprintf("  (%d uncommitted change(s))\n", length(dirty)))
  log <- system2("git", c("-C", repo_path, "log", glue("--since={date_beg}"), "--date=short",
                          "--format='%ad %h %s'", "--no-merges"), stdout = TRUE)
  writeLines(log, file.path(output_dir, glue("{repo}.log")))
  cat(sprintf("  %d commits since %s\n", length(log), date_beg))
}
cat(glue("\nlogs in {output_dir}\n"))
