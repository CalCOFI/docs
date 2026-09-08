# CalCOFI.io Documentation

The book at [calcofi.io/docs](https://calcofi.io/docs/), a [Quarto book](https://quarto.org/docs/books/)
rendered and published by GitHub Actions on every push to `main`
(`.github/workflows/render_book.yml`). One chapter is one `.qmd`; the order and the parts are in
`_quarto.yml`.

## How the book is built

- **Every table of fact is generated from the record.** `libs/pre-render.R` runs first on every
  render and snapshots, under `data/`, the promoted release's sidecars (`catalog.json`,
  `metadata.json`, `relationships.json`, `datasets.json`, the `dataset` table, the release notes),
  the registries in `CalCOFI/workflows` `metadata/`, and the product cards from `calcofi.io`. The
  chapters read those files; nothing else touches the network at render time. `data/` is committed,
  so a change in the numbers shows up in a diff. A fetch that fails stops the render.
  `CALCOFI_DOCS_REFRESH=1` refetches a snapshot younger than an hour (CI always does);
  `CALCOFI_DOCS_OFFLINE=1` renders from the committed snapshot without fetching.
- **Diagrams are SVGs, pre-rendered, committed.** The source is `diagrams/*.mmd`;
  `libs/render_diagrams.sh` renders each to `diagrams/*.svg` with the mermaid-cli pinned in
  `package.json` (`npm install` once). Chapters embed the SVG as a figure, `lightbox: true` makes it
  zoomable, and librsvg rasterises it for the PDF. No browser runs during `quarto render`.
  After editing a `.mmd`, run the script and commit the `.svg` beside it.
- **The site never waits for the PDF.** The workflow's first job renders HTML, checks every external
  link (`libs/check_links.R`: a ranged GET, never HEAD; 404/410/451 fail, anything else warns) and
  publishes to `gh-pages`. A second, non-blocking job builds the PDF and DOCX and attaches them to the
  rolling [`documents` release](https://github.com/CalCOFI/docs/releases/tag/documents), which the
  sidebar links. Before pushing a chapter that adds or changes a table, `libs/check_formats.sh`
  renders both formats locally; the Word export in particular has failed on a `&` in a dataset name.
- **Pinned.** Quarto and R versions are pinned in the workflow; R packages come from `DESCRIPTION`
  (not a package, just the dependency list `setup-r-dependencies` installs).

## Rendering locally

```bash
quarto render --to html          # data/ is refreshed if older than an hour, then the book renders
quarto preview                   # live reload while editing
libs/render_diagrams.sh          # after editing diagrams/*.mmd (needs `npm install` once)
libs/check_formats.sh            # docx + pdf, before pushing a chapter with a new table
Rscript libs/check_links.R       # after a render, what CI will check
```

R packages: `remotes::install_deps()` from the repo root (or `pak::local_install_deps()`). The PDF
needs TinyTeX (`quarto install tinytex`) and librsvg (`brew install librsvg`).

## Editing a chapter

Click *Edit this page* on any chapter (the pencil in the right margin) or edit the `.qmd` in a
clone; push to `main` and the site rebuilds in a few minutes. Prose is authored; anything measurable
(a count, a coverage, a column list, a status) is read from `data/` so it cannot go stale — if you
find yourself typing a number, look for the file that carries it.

The revamp of 2026-09 that gave the book its parts, its build and its keys chapter is planned in
`CalCOFI/workflows` `.claude/plans/2026-09-08 Docs revamp — ….md`.
