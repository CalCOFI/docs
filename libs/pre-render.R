# pre-render: snapshot the record the book reads -------------------------------
#
# Every table of fact in the book is generated from the record — the promoted release's
# sidecars, the registries in CalCOFI/workflows, the product cards on calcofi.io — and
# this script is the ONE place the network is touched at render time. It writes the
# snapshot under data/ (committed, so a change in the numbers shows up in a diff), and
# the chapters read those files. A fetch that fails stops the render: a book that says
# "the record is missing" must never be published because GCS blinked.
#
#   CALCOFI_DOCS_REFRESH=1   refetch even if the snapshot is younger than an hour (CI sets it)
#   CALCOFI_DOCS_OFFLINE=1   do not fetch at all; render from the committed snapshot
#
# Runs on every `quarto render` and `quarto preview` (project.pre-render in _quarto.yml).

suppressPackageStartupMessages({
  library(jsonlite); library(readr); library(yaml); library(duckdb); library(DBI)
})

root     <- normalizePath(".")
dir_data <- file.path(root, "data")
dir_rel  <- file.path(dir_data, "release")
dir_reg  <- file.path(dir_data, "registry")
for (d in c(dir_data, dir_rel, dir_reg)) dir.create(d, showWarnings = FALSE, recursive = TRUE)
snap_path <- file.path(dir_data, "_snapshot.json")

offline <- nzchar(Sys.getenv("CALCOFI_DOCS_OFFLINE"))
refresh <- nzchar(Sys.getenv("CALCOFI_DOCS_REFRESH"))

if (offline) {
  if (!file.exists(snap_path)) stop("CALCOFI_DOCS_OFFLINE is set but data/_snapshot.json does not exist")
  cat("pre-render: offline, rendering from the committed snapshot\n")
  quit(save = "no", status = 0)
}

if (!refresh && file.exists(snap_path)) {
  age_min <- as.numeric(difftime(Sys.time(), file.info(snap_path)$mtime, units = "mins"))
  if (age_min < 60) {
    cat(sprintf("pre-render: snapshot is %.0f min old, reusing it (CALCOFI_DOCS_REFRESH=1 to refetch)\n", age_min))
    quit(save = "no", status = 0)
  }
}

# sources -------------------------------------------------------------------------
gcs_releases <- "https://storage.googleapis.com/calcofi-db/ducklake/releases"
wf_raw       <- "https://raw.githubusercontent.com/CalCOFI/workflows/main"
site_raw     <- "https://raw.githubusercontent.com/CalCOFI/CalCOFI.github.io/main"

fetch <- function(url, dest, required = TRUE) {
  ok <- tryCatch({
    download.file(url, dest, quiet = TRUE, mode = "wb"); TRUE
  }, error = function(e) FALSE, warning = function(w) FALSE)
  if (!ok) {
    if (file.exists(dest)) unlink(dest)
    if (required) stop("pre-render: could not fetch ", url)
    cat("pre-render: optional ", basename(dest), " not available at ", url, "\n", sep = "")
  }
  invisible(ok)
}

# the promoted release ------------------------------------------------------------
version <- trimws(readLines(url(file.path(gcs_releases, "latest.txt")), warn = FALSE)[1])
stopifnot(grepl("^v\\d{4}\\.\\d{2}\\.\\d{2}$", version))
rel <- function(f) file.path(gcs_releases, version, f)

fetch(rel("catalog.json"),       file.path(dir_rel, "catalog.json"))
fetch(rel("metadata.json"),      file.path(dir_rel, "metadata.json"))
fetch(rel("relationships.json"), file.path(dir_rel, "relationships.json"))
fetch(rel("datasets.json"),      file.path(dir_rel, "datasets.json"))
fetch(rel("RELEASE_NOTES.md"),   file.path(dir_rel, "RELEASE_NOTES.md"))
fetch(rel("test_results.json"),  file.path(dir_rel, "test_results.json"), required = FALSE)
fetch(rel("integrity.json"),     file.path(dir_rel, "integrity.json"),    required = FALSE)
fetch(file.path(gcs_releases, "versions.json"), file.path(dir_rel, "versions.json"))
fetch(file.path(gcs_releases, "RELEASES.md"),   file.path(dir_rel, "RELEASES.md"))

# the `dataset` table itself (citations, licenses, measured coverage), read through the
# catalog's object list — never a hand-built releases/{v}/parquet path
catalog <- jsonlite::fromJSON(file.path(dir_rel, "catalog.json"), simplifyVector = FALSE)
tbl_entry <- Filter(function(t) identical(t$name, "dataset"), catalog$tables)[[1]]
obj_path  <- tbl_entry$objects[[1]]$path
obj_url   <- if (grepl("^https?://", obj_path)) obj_path else
  if (grepl("^gs://", obj_path)) sub("^gs://", "https://storage.googleapis.com/", obj_path) else
  file.path("https://storage.googleapis.com/calcofi-db", obj_path)
con <- DBI::dbConnect(duckdb::duckdb())
DBI::dbExecute(con, "INSTALL httpfs; LOAD httpfs;")
ds <- DBI::dbGetQuery(con, sprintf("SELECT * FROM read_parquet('%s')", obj_url))
DBI::dbDisconnect(con, shutdown = TRUE)
# geometry cannot go in a CSV, and the book never plots it
ds <- ds[, !vapply(ds, function(x) inherits(x, "blob") || is.list(x), logical(1)), drop = FALSE]
readr::write_csv(ds, file.path(dir_rel, "dataset.csv"), na = "")

# the registries (CalCOFI/workflows main) -------------------------------------------
registries <- c("field_dictionary.csv", "measurement_type.csv", "measurement_qual.csv",
                "category.csv", "life_stage.csv", "gear.csv", "provider.csv", "license.csv",
                "portal.csv", "distribution.csv", "dataset_meta_fields.csv", "dataset_status.csv",
                "release_policy.yml", "relationships_cross.csv")
for (r in registries) fetch(file.path(wf_raw, "metadata", r), file.path(dir_reg, r))

# the products on calcofi.io ----------------------------------------------------------
fetch(file.path(site_raw, "_data/products.yml"), file.path(dir_data, "products.yml"))

# the stamp -------------------------------------------------------------------------
snap <- list(
  fetched_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  version     = version,
  n_datasets  = nrow(ds),
  sources     = list(releases = gcs_releases, workflows = wf_raw, site = site_raw))
jsonlite::write_json(snap, snap_path, auto_unbox = TRUE, pretty = TRUE)
cat(sprintf("pre-render: snapshot of %s (%d datasets) written to data/\n", version, nrow(ds)))
