#!/usr/bin/env bash
# preview the rendered book against a LOCAL copy of the calcofi.io brand ------------------------------
#
# the book loads the brand from https://calcofi.io/brand/ (brand-head.html, _quarto.yml). to see it wear
# a brand that is not deployed yet — a branch of CalCOFI/CalCOFI.github.io with new header words, say —
# this copies _book/ to a folder, puts that brand beside it as /brand/ and points every page there.
# brand/v3/header.js reads nav.json from beside itself, so the navbar's words are the local copy's.
# _book/ itself is not touched, and nothing here is published.
#
#   libs/preview_brand.sh <a built site's brand/ folder> <output folder>
#   python3 -m http.server 4047 --directory <output folder>
set -euo pipefail

brand="${1:?usage: libs/preview_brand.sh <brand folder> <output folder>}"
out="${2:?usage: libs/preview_brand.sh <brand folder> <output folder>}"
[ -f "$brand/v3/nav.json" ] || { echo "no v3/nav.json under $brand (a BUILT site's brand/ is needed)" >&2; exit 1; }
[ -d _book ] || { echo "no _book/ here: run 'quarto render --to html' first" >&2; exit 1; }

rm -rf "$out"
mkdir -p "$out"
cp -R _book/. "$out/"
cp -R "$brand" "$out/brand"
# the pages' brand URLs -> the copy served beside them
find "$out" -maxdepth 1 -name '*.html' -exec perl -pi -e 's{https://calcofi\.io/brand/}{/brand/}g' {} +
echo "preview in $out: $(find "$out" -maxdepth 1 -name '*.html' | wc -l | tr -d ' ') pages, words from $out/brand/v3/nav.json"
