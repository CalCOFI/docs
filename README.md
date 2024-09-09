# CalCOFI Docs

This repository is rendered as a Quarto book.

## Rendering the book on your local machine (_optional_)

A Github Action will build the book automatically when you push changes to the repository. However, you can also build the book locally on your machine, which is especially helpful for testing output and debugging any issues.

## Setup software (R, Rstudio, Quarto, TinyTex) and download the repository

* Make sure you have the most recent version of R and R Studio

* Check that [Quarto](https://quarto.org/docs/get-started/) is installed and functioning on your machine. Check the version of Quarto installed in the R **Console**:
  ```r
  quarto::quarto_version()
  ```

* Install [TinyTex](https://yihui.org/tinytex/) (used for rendering to PDF) in the bash **Terminal**:
  ```bash
  quarto install tinytex
  ```

* In R Studio, File > New Project... > Version Control > Git.

* Fork or clone the GitHub repository from this Repository URL: 
  ```
  https://github.com/ioos/bio_data_guide.git
  ```

* Install all the required packages listed in the `DESCRIPTION` from the R **Console**:
  ```r
  remotes::install_deps()
  ```

## Render the Quarto book

* Render all Quarto output formats (i.e., `html`, `pdf`, `epub`) from source files (\*.qmd) listed in the `_quarto.yaml` (starting with `chapters:`) into the `output-dir` (i.e.,`_book`)  from the bash **Terminal**:
  ```bash
  quarto render
  ```

* If you have any problems, be sure to show versions of quarto and tinytex in the bash **Terminal**:
  ```bash
  quarto check
  ```
  
* Inspect results (`index.html`, `CalCOFI.io-Docs.pdf|docx|epub`) in the output directory `_book/`.

* Commit and push changes to all modified files via the **Git** pane in R Studio. Note that the `_book` directory is ignored by git (per the `.gitignore` file), since the book is rendered and published by the Github Action (`.github/workflows/render_book.yml`) into the `gh-pages` Github branch.

### Adding R package dependencies to `DESCRIPTION`

Depending on the type of R package:

* CRAN
  ```r
  usethis::use_package("dplyr")
  ```
  
* Github (and not CRAN)
  ```r
  usethis::use_dev_package("obistools", remote = "iobis/obistools")
  ```
  
* CRAN meta-package
  ```r
  usethis::use_package("tidyverse", type = "depends")
  ```
