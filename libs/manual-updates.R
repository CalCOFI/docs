# to be run manually to update the project
# NOTE: could also be moved to libs/pre-render.R to update every time

# add package dependencies to DESCRIPTION for Github Action
sapply(
  c("knitr", "rmarkdown", "quarto"),
  usethis::use_package)

# add package references
c("plumber", "quarto", "shiny") |>
  knitr::write_bib(
    file = "refs/packages.bib")

# download URL images (for static pdf/docx)
download.file(
  "https://contrib.rocks/image?repo=CalCOFI/docs",
  "figs/contrib.rocks.svg")
download.file(
  "https://docs.google.com/drawings/d/10gMrYC7wIo0ahz94KjGh8rc-vP1Nim1MI-hZdUK9BL4/export/svg",
  "figs/sw_arch.svg")

