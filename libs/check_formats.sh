#!/usr/bin/env bash
# The docx and pdf downloads are the fragile formats (gt cells with & or _ have broken
# them; see git log 2026-09-07). Run this before pushing a chapter that adds or changes a
# table: it renders both formats locally and stops on the first failure, naming the chunk.
set -euo pipefail
cd "$(dirname "$0")/.."
CALCOFI_DOCS_OFFLINE=${CALCOFI_DOCS_OFFLINE:-1} quarto render --to docx
CALCOFI_DOCS_OFFLINE=${CALCOFI_DOCS_OFFLINE:-1} quarto render --to pdf
ls -la _book/*.docx _book/*.pdf
