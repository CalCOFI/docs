# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

The Quarto book published at <https://calcofi.io/docs/>. One chapter is one `.qmd`; chapter order and
the five audience "parts" are in `_quarto.yml` (`book.chapters`). It is **not an R package**:
`DESCRIPTION` only lists the R dependencies that CI's `setup-r-dependencies` installs, so the
package rules (roxygen, testthat, NEWS.md bumps) do not apply here. Add a package to `DESCRIPTION`
`Imports` when a chapter or `libs/pre-render.R` starts loading it.

## Commands

```bash
quarto render --to html          # pre-render.R refreshes data/ if the snapshot is >1 h old, then renders to _book/
quarto preview                   # live reload while editing
CALCOFI_DOCS_OFFLINE=1 quarto render --to html   # render from the committed data/ snapshot, no network
CALCOFI_DOCS_REFRESH=1 quarto render --to html   # force a refetch (what CI does)
quarto render db.qmd --to html   # one chapter (pre-render still runs)
libs/render_diagrams.sh [name …] # diagrams/*.mmd -> diagrams/*.svg (npm install once); commit both
libs/check_formats.sh            # docx + pdf locally (offline); run before pushing a chapter that adds/changes a table
Rscript libs/check_links.R       # after an html render: the external-link check CI runs
Rscript libs/status_git-logs.R 2026-11-02   # git logs of every CalCOFI repo since a date, raw material for a status.qmd entry
```

R deps: `remotes::install_deps()` from the root. The PDF needs TinyTeX and librsvg (`brew install librsvg`).

## Architecture: the book reads a snapshot of the record

- **`libs/pre-render.R` is the only code that touches the network** (it runs as `project.pre-render`
  on every render and preview). It snapshots, under `data/`:
  - the *promoted* DuckLake release's sidecars from GCS (`calcofi-db/ducklake/releases/<version>/`)
    into `data/release/`. That covers `catalog.json`, `metadata.json`, `relationships.json`,
    `datasets.json`, `integrity.json`, `measurements.json`, `versions.json`, `test_results.json`
    and the release notes, plus small released tables read through the catalog's object list
    (`dataset.csv`, `grid_crosswalk.csv`)
  - the registries from `CalCOFI/workflows` `metadata/` into `data/registry/`
  - the product cards and ship's-log rows from `CalCOFI/CalCOFI.github.io` (`data/products.yml`,
    `data/news.yml`)
  - the download bundles' manifest (`data/zip_manifest.json`, optional), which says which datasets
    come as Excel; no chapter reads it since the FAQ's Excel note was dropped (2026-11-24)
  - a stamp in `data/_snapshot.json`, which records the version and the `measurements_source`

  If a required fetch fails, the render stops. Optional sources are skipped or fall back
  (`measurements.json` → `MEASUREMENTS_RELEASE_URL`; `variable.csv` → `measurement_type.csv`).
- **`data/` is committed**, but CI refetches it on every render and never commits it back, so the
  committed snapshot lags the promoted release. A local render rewrites `data/release/*`, which then
  shows as modified: that is a new snapshot, not an edit. Commit it only on purpose (a snapshot
  refresh of its own), never mixed into a prose change. Don't hand-edit anything under
  `data/release/` or `data/registry/`. Fix the source upstream (`CalCOFI/workflows` or
  `calcofi4db`) instead.
- **Chapters never type a number or a list.** Counts, column lists, coverage, status and versions are
  computed in R chunks (`execute: echo: false`) from `data/`. The chunks use `here()`,
  `jsonlite::fromJSON(..., simplifyVector = FALSE)` and `gt` tables. When a source is missing, a
  chapter prints prose that says so; it never shows a stale value. Follow the same pattern in new
  content: find the file that carries the fact.
- **The book consumes the release; it does not define it.** CI re-renders on push to `main`, on a
  `repository_dispatch` `release-promoted` (sent by `CalCOFI/workflows`
  `scripts/deploy_consumers.sh`), weekly, and on `workflow_dispatch`. Whatever release is
  promoted at render time is what the pages describe.
- **Diagrams are pre-rendered SVGs.** Edit `diagrams/*.mmd`, run `libs/render_diagrams.sh`, and
  commit the `.svg`. No browser runs during `quarto render` or in CI. Embed them as
  `![caption](diagrams/x.svg){#fig-… .cc-diagram .nolightbox}`; `libs/diagram.js` adds pan, zoom and
  fullscreen in HTML, and librsvg rasterises them for the PDF.
- **Shared fragments**: `_gates.qmd` (the table of release gates) is included by `keys.qmd` and
  `releases.qmd`. Edit it once.
- **`match/index.html`** is a standalone DuckDB-WASM app, copied as a project resource. It is
  linked from `data-access.qmd` and `api.qmd`.
- **Branding** follows the calcofi.io brand v3 contract (README § Brand):
  - `brand-head.html` loads the brand from calcofi.io, keeps Quarto's light/dark toggle in step
    with the cross-site theme, and adds the feedback button.
  - `libs/brand-nav.js` draws the navbar's words from `https://calcofi.io/brand/v3/nav.json`, so
    the words are never typed here. The one `book.navbar` item in `_quarto.yml` is a stand-in.
  - `brand-navbar.scss` styles the navbar; `brand-light.scss` and `brand-dark.scss` hold the
    colours; `brand-wave.html` puts the wave under the navbar.
  - `libs/preview_brand.sh <brand dir> <out dir>` previews a rendered book against an undeployed
    brand.
- **Citations**: `refs/refs.bib` (literature) and `refs/packages.bib` (software, regenerated by
  `libs/manual-updates.R`); cite with `[@key]`.

## CI (`.github/workflows/render_book.yml`)

There are two jobs on pinned Quarto (1.8.25) and R (4.5.1):

1. Render the HTML, run `check_links.R`, and publish to `gh-pages`. This is the only job that can fail.
2. Build the DOCX and PDF, non-blocking, and upload them as assets of the rolling `documents`
   release that the sidebar links.

**The DOCX and PDF are the fragile formats.** A bare `&` or `_` in a markdown `gt` cell has broken
the Word export before. Apply `fmt_markdown()` only under `knitr::is_html_output()`, as `db.qmd`
does.
