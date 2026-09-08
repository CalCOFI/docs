#!/usr/bin/env bash
# Pre-render every diagrams/*.mmd to diagrams/*.svg with the mermaid-cli pinned in
# package.json, so the book embeds SVGs (zoomable through lightbox, rasterised by
# librsvg for pdf/docx) and no browser runs during `quarto render`. Run after
# editing a .mmd; commit the .svg beside it. CI re-renders nothing here.
#
#   npm install            # once, installs the pinned @mermaid-js/mermaid-cli
#   libs/render_diagrams.sh [name ...]   # all, or the named diagrams
set -euo pipefail
cd "$(dirname "$0")/.."
MMDC=node_modules/.bin/mmdc
[ -x "$MMDC" ] || { echo "run: npm install   (pins @mermaid-js/mermaid-cli in package.json)" >&2; exit 1; }
names=("$@")
[ ${#names[@]} -eq 0 ] && names=($(ls diagrams/*.mmd | xargs -n1 basename | sed 's/\.mmd$//'))
for n in "${names[@]}"; do
  "$MMDC" -q -i "diagrams/$n.mmd" -o "diagrams/$n.svg" -b transparent -c libs/mermaid.config.json
  # mmdc writes an <svg> with a max-width style; strip it so the figure fills its column
  # and lightbox scales it. mermaid emits each word as a <tspan> with a leading space,
  # which librsvg (the pdf path) strips under the default whitespace mode; xml:space=
  # "preserve" on the root keeps the spaces in every renderer (the file has no indentation)
  sed -i '' -E -e 's/ style="max-width: [0-9.]+px;"//' -e 's/^<svg /<svg xml:space="preserve" /' "diagrams/$n.svg"
  echo "diagrams/$n.svg  $(wc -c < "diagrams/$n.svg") bytes"
done
