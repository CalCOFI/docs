# This script is kicked off by _quarto.yml project: pre-render: lib/pre-render.R

# download URL images (for static pdf/docx)
download.file(
  "https://contrib.rocks/image?repo=CalCOFI/docs",
  "figs/contrib.rocks.svg")

download.file(
  "https://docs.google.com/drawings/d/10gMrYC7wIo0ahz94KjGh8rc-vP1Nim1MI-hZdUK9BL4/export/svg",
  "figs/sw_arch.svg")


