# CalCOFI integrated database release v2026.09.06

**Release date:** 2026-09-06 · **promoted** (`latest.txt`)

## The dataset catalog record says what a page needs to say (schema 1.1)

`datasets.json` grew five fields, all additive, all read from a registry the team already edits
(calcofi4db 4.5.0; UI plan 2026-09-05 § D-9). Each of them retires a hand-typed map in
calcofi.io's own generator — a fact with two homes drifts:

- `category.description` — the one line a category tile shows. Already a column of
  `metadata/category.csv`, simply not carried.
- `distributions[].grain_description` — what an ERDDAP grain *means*. A page that says
  `length/stage frequency` and nothing else asks the reader to guess.
- `objects[].table_description` — the first sentence of what `metadata.json` already says the
  table is, so a parquet row names more than a table and a size.
- `registrations[].id` and `.title` — the identifier a portal knows the dataset by
  (`edi.109.4`, `gov.noaa.nodc:0301029`, an OBIS uuid) and what it calls it. Curated in
  `metadata/distribution.csv` where a row exists — **all 31 rows that name one already did**,
  and every one agrees with `derive_registration_id()`, which is the same rule the site used as
  its fallback. The one row with no id is a UC San Diego Library *search* URL, which names none.
- `portals[]` — every portal the record can mention, with what it is, from `metadata/portal.csv`.
- **CalCOFI's own ERDDAP has one id, `erddap`** (calcofi4db 4.6.0). The record used to carry it
  twice — `erddap` from `portal.csv` and the registrations, `erddap-calcofi` from the
  distribution registry's vocabulary — so `portals[]` listed the same portal under both and a
  consumer had to look either up. `distribution_portals()`, `classify_portal()` and the seven
  legacy-id rows of `metadata/distribution.csv` now say `erddap`; the old value is rejected by
  `read_distribution_registry()` rather than aliased. **Consumers:** a reader keyed on the
  literal `erddap-calcofi` (calcofi.io's `_plugins/datasets.rb` accepted both) finds only `erddap`.
- **`distributions[]` opens with the dataset's STAC collection** (`format: stac`,
  `{stac root}/collections/{dataset_key}/collection.json`; calcofi4db 4.6.0). The catalog
  `build_stac()` writes was on the bucket but nothing in the record pointed at it, so the dataset
  pages linked a site-side guess. Holdings, which have no collection, get no row.

## Coverage measures the season, and a second extent

- `coverage.months` — observations by calendar month, twelve counts per dataset. CalCOFI is a
  quarterly survey, so *which* quarters a dataset covers is coverage; a years sparkline cannot
  show it.
- `coverage.bbox_robust` — the 2.5–97.5 percentile of a dataset's own sampling positions, with
  `n_positions`. **Not a correction.** A second, measured number beside the asserted `bbox` so
  the two can be compared, which is what the new `bbox_implausible` warning does. It fires for
  `swfsc_ichthyo`: its record extent reads 0–54° N × 180–77° W from bad upstream coordinates
  while its sampled positions sit in the California Current. The bbox is the provider's to fix —
  **question Q16 to SWFSC** (`metadata/swfsc/ichthyo/questions.csv`, `proposed`, asking whether
  there are sentinel or mis-signed coordinates and a flag to filter on) — and until it is
  answered the release carries both numbers so a consumer can choose. Nothing is deleted:
  `check_measurement_bounds()` bounds a *value*, not a coordinate.

**Consumers:** nothing removed or renamed, so a reader on schema 1.0 is unaffected.
`test_release.qmd` now asserts `schema_version == "1.1"` and blocks on
`grain_without_description`; `registration_without_id` and `bbox_implausible` are reported as
warnings a human reads. calcofi.io deletes its five marked fallbacks when this release renders.

## Every biological dataset can now leave as a Darwin Core Archive

`publish_to-obis.qmd` (generic, `calcofi4db::dwc_*()`, ≥ 4.4.0) builds one archive per dataset
whose taxa resolve to WoRMS — Event core from `sample`'s adjacency list, Occurrence from
`obs_bio` + `taxon`, eMoF from `sample_measurement` + `obs_attribute` + `obs_env`, `meta.xml`
from the term map and `eml.xml` from the release's own `eml/{dataset_key}.xml`. It supersedes
`publish_ichthyo_to-obis.qmd`, which read the `swfsc_ichthyo` source tables directly and has
been unrunnable since the core consolidation retired them, and which is why nine other
biological datasets had no OBIS route at all. Ten archives build clean at v2026.09.05:
213,813 / 482,250 / 613,576 events / occurrences / eMoF for ichthyo, plus cufes, bird-mammal,
phytoplankton, zooscan, euphausiids, zoodb, phyllosoma, dungeness-crab and mesopelagic-fish.
Nothing is uploaded by the pipeline: the IPT copy is a deliberate manual act gated on the
archive manifest's `content_hash`.

The vocabulary ids the registries carry now reach a portal for the first time.
`measurement_type.nerc_p01` / `units_nerc_p06` become `measurementTypeID` / `measurementUnitID`
(241,871 of ichthyo's 613,576 eMoF rows carry a P01, all of them a P06 — the published 2026-03
archive carried none); `gear.csv` supplies a per-gear `samplingProtocol` sentence in place of one
hand-typed string; `life_stage.csv` supplies `lifeStage`, and its two "not a life stage" values
(`damaged`, `invert`) go to `occurrenceRemarks` instead. An id absent from a registry ships empty,
never invented.

**`occurrenceStatus` is measured, not assumed.** Six datasets record their zeros (cufes,
phytoplankton, zoodb, zooscan, phyllosoma, dungeness-crab) and those rows publish as `absent`.
Four are positive-only (ichthyo, euphausiids, bird-mammal, mesopelagic-fish): a surveyed-empty
sample simply has no row, so an absence could only be derived from `sample_root` minus the
positives — a claim about a sampling protocol, not about the data. None is derived; each is a
question for its provider.

**Gaps the export measured, and did not paper over.** 409 `calcofi_phytoplankton` region pools
carry no `datetime`, so 64,643 of its occurrences cannot index at OBIS; 155 `cce-lter_zoodb` tows
carry neither date nor coordinates (12,573 records); 1,563 `swfsc_cufes` underway samples carry no
coordinates (8,897 records); 123 `farallon_bird-mammal` occurrences have no WoRMS id; and 26,049
`obs_bio` rows across four datasets carry a dataset-local taxon key with no scientific name
(zooscan 23,380, phytoplankton 1,906, bird-mammal 762, mesopelagic-fish 1) and cannot be
Occurrences at all. Each is reported per dataset, never dropped silently.

## A generic EDI publisher turns the release EML into a data package, per dataset

`publish_to-edi.qmd` (plan § D-6/D-8, WS-E3) is the third generic publisher over the
frozen release, alongside `publish_to-netcdf.qmd` and `publish_to-erddap.qmd`: parameterised
by `dataset_key` (default the three program datasets with no existing archive —
`calcofi_bottle`, `calcofi_ctd-cast`, `calcofi_mets`), it exports each core table's rows for
the dataset as a CSV `dataTable` entity, pairs them with the release's own `eml/{dataset_key}.xml`
(`calcofi4db::build_eml()`, entity `physical` rewritten from the release parquet object to the
exported CSV), and writes `data/edi/{dataset_key}/{dataset_key}_{version}/` plus a manifest
(`content_hash`, `package_id`, `evaluated_utc`, `uploaded_utc`). A shared vocabulary table with
no `dataset_key` column (`measurement_type`) is named whole as an `otherEntity` rather than
duplicated per dataset; a `supplemental` full-resolution table (`obs_ctd_full`, `obs_mets_full`
— hundreds of millions of rows, partitioned by `cruise_key` not `dataset_key`) is excluded and
the exclusion recorded in the EML's own `additionalMetadata`, never silently dropped.

**The non-interference rule from `publish_to-obis.qmd` applies here too**: a dataset whose own
`link_data_source` is itself an EDI/PASTA package, or whose record already carries a
`kind = "archive"` distribution on `portal %in% c("edi", "knb-lter-cce")`, is refused — reported,
not published — so a CCE-LTER-owned package (or any provider's own EDI record) is never
republished under a CalCOFI-owned one.

`EDIutils::evaluate_data_package()` runs against EDI's PASTA **staging** environment on every
render that has credentials (`EDI_KEY`, or `EDI_USER`/`EDI_PASS`); without them the notebook says
so and skips cleanly. `create_data_package()` / `update_data_package()` — which mint or revise a
real package — run only under `CALCOFI_PUBLISH_EDI=true`, against `env = "production"`, and
record the minted package id in the new `metadata/edi_packages.csv` registry. The pure
classification/entity-rewrite logic lives in `libs/edi_entities.R`
(`scripts/test_publish_edi.R`, no network).

## The release record now has a public rendering, one page per dataset

`datasets.json` (schema 1.0, `build_dataset_catalog()`) is no longer only a sidecar: calcofi.io
opens on the dataset grid it describes, and every dataset and holding has a page at
`https://calcofi.io/datasets/{dataset_key}/` with its coverage, every endpoint it can be reached
through, its registrations, its citation and schema.org JSON-LD. The machine surfaces ship with it —
`calcofi.io/data.json` (DCAT-US 1.1, harvestable by any CKAN), `calcofi.io/datasets/sitemap.xml`,
and `{dataset_key}.json` / `.jsonld` beside each page.

Nothing about a dataset is written in the landing repo: the pages are a rendering of the promoted
release, refreshed by `CalCOFI/CalCOFI.github.io` `refresh.yml` on the `gh_dispatch` row
`test_release.qmd` already carries, so they follow a promotion within minutes and can never describe
an unpromoted release. Until the next promoted release carries `datasets.json`, the site builds from
the 2026-09-05 staging record through a documented `DATASETS_RELEASE_URL` bridge.

**Consumers:** a record's `visibility: internal` is now load-bearing in public — such a dataset gets
no page, no sitemap entry, no `data.json` row and no search row. The two record gaps the pages found
are fixed in the same round (calcofi4db 4.2.x): ERDDAP titles no longer reach the record as a literal
`\u2014`, `coverage.variables[]` carry units and NERC P01 URIs, and `coverage.taxa[]` names the top
50 taxa so the catalog's search can match a taxon.

## Every dataset ships an EML 2.2 document: `eml/{dataset_key}.xml`

The release now writes **one EML 2.2 document per dataset** into `eml/` beside `datasets.json`
(`calcofi4db::build_eml()`, >= 4.2.0), generated from the record and the descriptive sidecar. It is
the metadata document every publisher shares: the Darwin Core archive's `eml.xml`, the EDI data
package, ERDDAP's globals and the dataset page's JSON-LD all derive from it, so those four cannot
disagree, because none of them is typed twice. Until now the only EML CalCOFI produced was
`publish_ichthyo_to-obis.qmd`'s, built from strings hand-typed inside that notebook — the one place
a provider cannot edit and the record cannot see — and only for `swfsc_ichthyo`.

Each document carries the title, short name and abstract from the record; the creators (the
sidecar's `creators[]`, else `pi_names` with the provider organization); the licence and its URL
from `metadata/license.csv`; the GCMD keywords under their thesaurus plus the category and the
observed variables; the **measured** geographic bounding box and year span, and the taxonomic
coverage `coverage.json` resolved (WoRMS / ITIS `taxonId` per taxon — 963 classifications for
`swfsc_ichthyo`); the methods, study extent and sampling description from the sidecar with
`metadata/gear.csv`'s `dwc_samplingProtocol` sentences for the dataset's `tow_type`s; a `dataTable`
per released table whose `attributeList` comes from `metadata.json`'s `columns{}` (label,
definition, unit, storage type) and whose `physical` block carries the content-addressed object's
bytes, SHA-256 and URL; and an `additionalMetadata` block with the release and dataset citations.

- **A release gate**: `check_eml()` runs `eml_validate()` against EML 2.2's XSDs (local, no network)
  plus the required-element checklist EDI's evaluate applies, and `assert_eml()` fails the release
  on any non-exempt error — `invalid_eml`, `no_title`, `no_abstract`, `no_creator`, `no_pub_date`,
  `no_license`, `no_geographic_coverage`, `no_temporal_coverage`, `no_data_table`. `eml/` joins
  `RELEASE_REQUIRED_OBJECTS`, so `promote_release()` refuses a release without it.
- **Nothing is invented.** An absent optional field is omitted; a missing required field is a
  finding, exempt only while an open/proposed `questions.csv` row on `related_table = dataset` names
  it — the same rule the citation contract uses. Two fallbacks are derivations from a registry, not
  values typed into code, and each is reported so it stays visible: an `organizationName`-only
  creator taken from `provider.csv` when the record names no person (4 of 16 datasets), and the
  CalCOFI role address `data@calcofi.io` as the contact when no provider address is on record
  (16 of 16 — `contact` is the emptiest field in the catalog and this is what it costs). A unit
  becomes an EML `standardUnit` only on an exact match; `count/10m2` and `count/1000m3` travel as
  `customUnit` carrying the release's own string rather than being coerced onto a near-neighbour.
- **Measured over the 16 records** (v2026.09.05 staging sidecars): 16/16 documents valid, 18 KB
  (`sio_pic-zooplankton`) to 366 KB (`swfsc_ichthyo`), 1.3 MB in all; 0 blocking findings; 6 `no_license` exempt
  on an open licence question (bottle Q10, ctd-cast Q28, mets Q29, picoplankton-bacteria Q06,
  pic-zooplankton Q08, ichthyo Q11); warnings `contact_role_address` x 16,
  `undocumented_attributes` x 16, `no_methods` x 14 (only ichthyo and the Dungeness crab have gear
  in `gear.csv`; no sidecar carries `methods_md` yet), `short_abstract` x 5 and
  `creator_from_provider` x 4, and `no_taxonomic_coverage` x 1 (`sio_pic-zooplankton`, whose taxa
  do not reach `coverage.json`). Every warning names a field a provider can fill in the Sheet.

## The release publishes a STAC catalog, and the sitemap follows the record

The release now also writes a static **SpatioTemporal Asset Catalog** (STAC 1.0.0) to
`gs://calcofi-db/stac/` — `calcofi4db::build_stac()` (≥ 4.3.0), a pure function of `datasets.json`,
`metadata.json` and `spatial_layers.json`: a root catalog, one collection per **public** dataset
(extent from the observed bbox and year span, `license`, `providers[]`, GCMD `keywords`,
`table:tables`, `sci:doi` / `sci:citation`), one **item per release** whose assets are that
dataset's parquet objects (`application/x-parquet`, `roles: [data]`, each with `table:columns` from
`metadata.json`, `file:size` and a sha256 `file:checksum`), its CF netCDF, its ERDDAP pages and its
ISO 19115 record, and one collection per spatial layer with its PMTiles. A `superseded` or
`retired` distribution is never published as an asset, and an `internal` dataset gets no collection.
`check_stac()` runs `stac-validator` when it is installed and always runs a structural check;
`test_release.qmd` fetches the published documents back off the bucket and re-checks them, so the
gate is on what is served, not on what was built. A staging run writes `stac-staging/`.
`stac-browser` at **calcofi.io/stac/** reads the root. **Consumers:** nothing changes for existing
readers — STAC is an addition beside `catalog.json`, and the pages keep reading `datasets.json`.

`datasets/sitemap.xml` (ODISCat record 3318) is now generated from the record too
(`build_datasets_sitemap()`): the calcofi.io dataset pages first — 16 datasets + 17 holdings — then
every `current`/`external` record at another portal, and **never** a `superseded` or `retired` one;
`lastmod` is the release date or the sidecar's own edit for a page, and what the portal itself said
for an external record. `observe_distributions()` asks each portal weekly by its `portal.csv`
`observe_method` and writes `metadata/distribution_observed.json` — 58 distributions at 2026-09-05
(32 curated rows + the holdings' links): 53 live, 4 EDI packages superseded by a newer revision, 1
unreachable. Nothing is ever deleted from `distribution.csv`, and an unanswered request is
`unreachable`, never `retired`.

## Every dataset has a record: `datasets.json` (the dataset catalog, Phase 0)

The release now writes **`datasets.json`** beside `catalog.json` — one generated record per
`dataset_key` (schema 1.0; `calcofi4db::build_dataset_catalog()`, ≥ 4.1.0) joining what the release
already measured (the `metadata.json` dataset block, `coverage.json` rolled up per dataset —
years, stations, variables, taxa, depth span, the env variables a dataset contributes to another
category — and the content-addressed `catalog.json` objects that belong to it) with the reviewable
registries and with what the live services answer at release time. Each record carries
`distributions[]` (every endpoint: parquet objects with bytes/sha256/since, the CF netCDF, the
ERDDAP ids that exist on erddap.calcofi.io, the ISO 19115 record, the ingest notebook, the
calcofi.org page, the source portal, and the curated mirrors/archives — CoastWatch, EDI, NCEI,
OBIS, the IPT — with `status` and `superseded_by`), `registrations[]` (per portal
`published | planned | n/a`; ERDDAP and OBIS measured, Zenodo from the release DOI), `status`
(stage, priority, issue, blockers, open questions) and `visibility` (`public | internal`). It also
lists `holdings[]` (datasets CalCOFI has but has not ingested, from a sidecar with
`status: planned | external | archived`) and `reference[]` (cruise, ship, grid, spatial, the 19
boundary layers, the GEBCO bathymetry). One `datasets/{dataset_key}.json` per dataset sits beside
it. Nothing on calcofi.io's dataset pages (Phase 1) is authored by hand: they read this file.

- **A release gate**: `check_dataset_catalog()` fails the release on a record without a name, a
  registered category and provider, a description, a bbox or a download; a missing citation is
  exempt only while a provider question covers it (the citation contract's rule); every listed URL
  must answer a one-byte ranged GET (behind `CALCOFI_SKIP_LINK_CHECK`); `datasets.json` joins
  `RELEASE_REQUIRED_OBJECTS`, so `promote_release()` refuses a release without it, and
  `test_release.qmd` checks the file against `datasets.schema.json`, counts it against
  `metadata.json` and re-runs the check before promoting. At v2026.09.04 the finding table is
  `no_citation` × 5 (zoodb, zooscan, farallon, pic-zooplankton, cufes — all exempt, questions open).
- **Three new registries** under `metadata/`: `distribution.csv` (27 curated endpoints —
  the OBIS dataset `0e223f55…` and its IPT resource `calcofi_ichthyo`, eight CoastWatch mirrors of
  the ichthyoplankton, the SIO hydrographic mirrors, EDI/NCEI/DataZoo records, and the seven legacy
  erddap.calcofi.io ids marked `superseded` with their successor), `portal.csv` (16 portals with
  `harvests_from_us` and `observe_method`) and the generated `holdings.csv`;
  `dataset_status.csv` gains `publish_ncei` and `publish_caloos`, and `publish_erddap` now says
  `done` for the 16 datasets erddap.calcofi.io serves.
- **Descriptive metadata leaves the notebooks** (plan § D-9): a dataset's citation, licence, DOI,
  links, contact, keywords, creators and narrative now live in
  `metadata/{provider}/{dataset}/dataset_meta.yml`, the file a provider edits through the
  `metadata` tab of their question Sheet; the notebook keeps the structural keys. `read_calcofi_meta()`
  merges the two, so the release `dataset` table and every consumer see exactly what they saw
  before; a descriptive key left in a notebook now fails the workflows index.
- `coverage.json` `datasets[]` gains `life_stages` per dataset (the dataset's own values).
- Imported the CalOOS working sheet (41 rows) via the new idempotent `scripts/import_caloos_sheet.R`: 24 rows
  matched to already-integrated datasets became `dataset_meta.proposed.yml` proposals (creators, contact,
  keywords, funding, associated parties, QC notes, maintenance) plus 5 new `distribution.csv` rows (3 CalOOS
  module ids, a DataZoo phytoplankton mirror, a NOAA seabird/mammal transect-effort source); 17 unmatched rows
  became new holding sidecars (`metadata/{provider}/{dataset}/dataset_meta.yml`), including the discovery that
  EDI package knb-lter-cce.104 is mislabeled in the sheet (titled "nitrate isotopes", actually POC/PON). Added
  providers `jcvi`, `calpoly`, `stanford`; added category *Genomics & eDNA* and widened *Nutrients & Chemistry*
  / *Phytoplankton*. Filled GCMD Science Keywords (`keywords_gcmd`, 2–5 each, verified against the live GCMD
  KMS export) for all 16 ingested datasets.
- Descriptive dataset metadata split out of the 16 ingest notebooks into per-dataset sidecars
  (`metadata/{provider}/{dataset}/dataset_meta.yml`), editable by providers in a new `metadata` tab of
  their Google Sheet; `scripts/migrate_dataset_meta.R` did the one-off move byte-identically (117 keys,
  comments preserved, the release `dataset` table unchanged before/after), `scripts/sync_dataset_meta_sheets.R`
  does the push/pull (a `holdings` tab in the `calcofi` Sheet is the triage board for the 17 holdings). Both sheet
  scripts now authenticate as the calcofi-admin service account only (`scripts/lib_google_auth.R`), never interactively.
- **sccoos gets a question/metadata Sheet, and two CalOOS-import findings are on record with providers.**
  `sync_dataset_meta_sheets.R push` can now create a provider's spreadsheet itself when none exists yet
  (sccoos: two holdings, no ingest, so the questions script had nothing of its own to push) — sccoos's
  `metadata` tab is live. Two findings from importing the CalOOS working sheet are open provider questions
  rather than asserted facts: CCE-LTER's `knb-lter-cce.104` accession names a POC/PON dataset, not the
  nitrate-isotope dataset the sheet describes (`cce-lter_poc-pon-cce-region` Q01); and the CC0 licence the
  sheet claims for four NOAA CoastWatch ERDDAP mirrors is not confirmed by their own `.das` `license`
  globals, which carry only the generic ERDDAP disclaimer (`swfsc_ichthyo` Q11, `swfsc_cufes` Q07,
  `calcofi_bottle` Q10, `sio_pic-zooplankton` Q08).
- **`climatology` re-exports byte-identically now** (calcofi4db 4.1.1). `clim_mean` / `clim_sd` came out
  of DuckDB's parallel `avg()` / `stddev_samp()` with last-bit differences (≤ 1.8e-16 relative) on every
  run, so 60 of 71 partitions re-uploaded and were stamped as changed at each re-cut even with no data
  change (v2026.09.04 vs its staging twin, and two staging runs on 2026-09-05). Both are now rounded to six
  decimal places — nine orders of magnitude above the noise, well below any instrument's resolution — so an
  unchanged climatology reuses its objects. Row counts, grouping and the 1993–2013 / ≥ 3-cruise definition are
  unchanged. **Consumers:** the next release's `climatology` values differ from v2026.09.04's beyond the 6th
  decimal only.

## ERDDAP's own globals now say what the record says (WS-P2)

`publish_to-erddap.qmd`'s generated `datasets.xml` no longer states a program-wide default for
things the record can answer per dataset. `infoUrl` is now the dataset's own
`https://calcofi.io/datasets/{dataset_key}/` page — built from the key, never a per-dataset URL
list — instead of `link_calcofi_org` (which many datasets do not carry) or the bare
`https://calcofi.org` fallback. `license` reads the dataset's own `dataset_meta.yml` `license` id
through `metadata/license.csv` (its full name, e.g. "Creative Commons Attribution 4.0
International") and states `not specified` rather than the previous blanket `CC-BY 4.0` default —
which had been asserting a licence for datasets (`calcofi_bottle` among them) whose own citation
questions are still open. New `creator_name` / `creator_type` / `creator_email` / `creator_url` /
`institution` / `keywords` globals resolve from the sidecar's `pi_names` / `contact` /
`keywords_gcmd`, falling back to the registered provider organization (`metadata/provider.csv`) —
never CalCOFI program-wide — and are omitted, not written as the literal string `"NA"`, when the
record states none. **Also fixed at the source (I-13):** `title_of()`'s dataset-block suffix
(" — observations", " — sampling events", …) used a real em dash, which erddap.calcofi.io's own
`allDatasets` metadata re-serializes as the six-character literal `"—"` — a plain hyphen
(" - ") reads the same and survives every consumer, so titles are now ASCII-safe at the source
instead of being decoded downstream (as `observe_distributions()`, calcofi4db ≥ 4.2.x, already
does for existing ERDDAP metadata). **Consumers:** erddap.calcofi.io's `datasets.xml` and its
served globals change on the next deploy; no table, column or row is affected.

## Contents (generated)

| table | rows | |
|---|---:|---|
| `climatology` | 768,880 | partitioned |
| `cruise` | 842 |  |
| `dataset` | 16 |  |
| `dataset_taxon` | 1,917 |  |
| `grid` | 218 |  |
| `lookup` | 26 |  |
| `measurement_type` | 200 |  |
| `obs` | 26,265,248 | deprecated → `obs_bio`, `obs_env` (objects removed in next) |
| `obs_attribute` | 458,184 |  |
| `obs_bio` | 1,258,665 |  |
| `obs_env` | 25,006,583 | partitioned |
| `region` | 4 |  |
| `sample` | 1,469,155 |  |
| `sample_measurement` | 589,603 |  |
| `sample_spatial` | 929,664 |  |
| `ship` | 49 |  |
| `spatial` | 13,206 |  |
| `spatial_attribute` | 148,461 |  |
| `taxon` | 2,614 |  |
| `taxon_group` | 441 |  |
| `obs_ctd_full` | 271,394,164 | supplemental |
| `obs_mets_full` | 19,927,416 | supplemental |
| `sample_root` | 421,454 | supplemental |

**23 tables, 348,657,010 rows, 2.46 GB.**

**Datasets (16):** `calcofi_bottle`, `calcofi_ctd-cast`, `calcofi_dic`, `calcofi_mets`, `calcofi_phyllosoma`, `calcofi_phytoplankton`, `cce-lter_euphausiids`, `cce-lter_picoplankton-bacteria`, `cce-lter_zoodb`, `cce-lter_zooscan`, `cdfw_dungeness-crab`, `farallon_bird-mammal`, `sio_mesopelagic-fish`, `sio_pic-zooplankton`, `swfsc_cufes`, `swfsc_ichthyo`

**Validation:** 69 pass / 0 fail / 4 skip (consumer-contract suite, 2026-09-06T09:05:02Z).

**Software:** calcofi4db 4.6.0, calcofi4r 1.18.0.

## How to cite

> CalCOFI (2026). CalCOFI Integrated Database, release v2026.09.06 [Data set]. Scripps Institution of Oceanography, NOAA Fisheries, and California Department of Fish and Wildlife. https://doi.org/10.5281/zenodo.22514953

Cite the source datasets you use alongside the release:

- `calcofi_bottle` — CalCOFI. (2023). CalCOFI Bottle Database 194903-202105. CalCOFI.org. · *license pending*
- `calcofi_ctd-cast` — CalCOFI. (2023). CalCOFI CTD Cast Files. CalCOFI.org. · *license pending*
- `calcofi_dic` — Keeling, C.D.; Lueker, T.J.; Emanuele, G.; Dickson, A.G.; Martz, T.R.; Wolfe, W.H.; Mau, A. (2025). Discrete profile dissolved inorganic carbon, total alkalinity, water temperature and salinity measurements for CalCOFI (NCEI Accession 0301029). NOAA NCEI. https://doi.org/10.25921/3w9f-jd72 · CC-BY-4.0
- `calcofi_mets` — CalCOFI. Underway (METS) TSG/Meteorology Data. CalCOFI.org. · *license pending*
- `calcofi_phyllosoma` — CalCOFI - Scripps Institution of Oceanography and T. Koslow. 2017. Data pertaining to lobster phyllosoma, Panulirus interruptus, collection methods, locations, identification and staging (1951-2008, months of July and August) ver 4. Environmental Data Initiative. https://doi.org/10.6073/pasta/9e38121ebb26f1b59b7b39b2eff844fa · custom (https://portal.edirepository.org/nis/metadataviewer?packageid=knb-lter-cce.188.4)
- `calcofi_phytoplankton` — CalCOFI - Scripps Institution of Oceanography, California Current Ecosystem LTER, and E. Venrick. 2023. Temporal and spatial changes of the abundance and species composition of phytoplankton in the California Current from samples collected aboard CalCOFI cruises from summer 1996 through 2022. ver 4. Environmental Data Initiative. https://doi.org/10.6073/pasta/60edabfbfd85c623fce05822befaa071 · CC0-1.0 (https://creativecommons.org/publicdomain/zero/1.0/)
- `cce-lter_euphausiids` — Ohman, M.D. 2022. California Current Ecosystem Euphausiid data, Brinton and Townsend Euphausiid Database (BTEDB) ver 1. Environmental Data Initiative. https://doi.org/10.6073/pasta/4a92a0044bcd1523a4f994ece874a57d · custom (https://portal.edirepository.org/nis/metadataviewer?packageid=knb-lter-cce.313.1)
- `cce-lter_picoplankton-bacteria` — Landry, M. (2004-2023). Picoplankton and Bacteria Abundance (CalCOFI Cruise). CCE LTER. · *license pending*
- `cce-lter_zoodb` — *citation pending* · custom (https://oceaninformatics.ucsd.edu/zoodb/)
- `cce-lter_zooscan` — *citation pending* · custom (https://oceaninformatics.ucsd.edu/zooscandb/)
- `cdfw_dungeness-crab` — Rogers-Bennett, L.; Jones, E.; Klemmedson, A. (2026). CDFW Dungeness Crab Megalopae from archived CalCOFI plankton samples (1949-2014). California Department of Fish and Wildlife, published through CalCOFI / Scripps Institution of Oceanography.
 · CC-BY-4.0
- `farallon_bird-mammal` — *citation pending* · custom (https://oceanview.pfeg.noaa.gov/CalCOFI/app/resources/docs/Data_Sharing_Agreement_FarallonInstitute.pdf)
- `sio_mesopelagic-fish` — Koslow, J. Anthony (2016). CalCOFI Trawl Data. In California Cooperative Oceanic Fisheries Investigations (CalCOFI): Acoustic and Trawl Data. UC San Diego Library Digital Collections. https://doi.org/10.6075/J0BZ64DH
 · CC-BY-4.0
- `sio_pic-zooplankton` — *citation pending* · *license pending*
- `swfsc_cufes` — *citation pending* · custom (https://coastwatch.pfeg.noaa.gov/erddap/tabledap/erdCalCOFIcufes.das)
- `swfsc_ichthyo` — NOAA Fisheries SWFSC. CalCOFI Ichthyoplankton Database. · *license pending*

## Access

```r
con <- calcofi4r::cc_get_db(version = "v2026.09.06")
```
```python
con = calcofi4py.cc_get_db("v2026.09.06")
```
Parquet: `https://storage.googleapis.com/calcofi-db/ducklake/releases/v2026.09.06/parquet/{table}.parquet`; 
full history: [RELEASES.md](https://storage.googleapis.com/calcofi-db/ducklake/releases/RELEASES.md).
