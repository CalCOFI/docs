# check_links: every external link in the rendered book answers -------------------
#
# Probes each distinct external href in _book/*.html with a ranged GET (never HEAD:
# EDI's mapbrowse answers 405 to HEAD, and EDI hosts most of the bio datasets — the
# rule from workflows' build_workflows_index.R). 404 / 410 / 451 fail the run; anything
# else that is not 2xx/3xx is reported as a warning (5xx and timeouts are the other
# server's problem, and failing a deploy over them teaches people to skip the check).
#
#   Rscript libs/check_links.R            # after `quarto render --to html`
#   CALCOFI_SKIP_LINK_CHECK=1             # skip (the workflows convention)

if (nzchar(Sys.getenv("CALCOFI_SKIP_LINK_CHECK"))) { cat("check_links: skipped\n"); quit(status = 0) }
suppressPackageStartupMessages(library(curl))

htmls <- list.files("_book", pattern = "\\.html$", full.names = TRUE)
if (!length(htmls)) stop("check_links: no _book/*.html — render first")

hrefs <- unlist(lapply(htmls, function(f) {
  x <- paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  m <- regmatches(x, gregexpr('href="https?://[^"#]+', x))[[1]]
  sub('^href="', "", m)
}))
hrefs <- unique(hrefs)
# quarto's own assets, its share buttons (a |url| placeholder), the two hosts that answer
# only to a browser session, and this repo's own rolling `documents` assets, which the
# second CI job creates after this check runs
skip <- grepl("^https?://(cdn\\.jsdelivr\\.net|fonts\\.googleapis\\.com|fonts\\.gstatic\\.com|docs\\.google\\.com|drive\\.google\\.com|twitter\\.com/intent|www\\.facebook\\.com/sharer|www\\.linkedin\\.com/share)", hrefs) |
  grepl("^https://github\\.com/CalCOFI/docs/releases/download/", hrefs)
hrefs <- hrefs[!skip]
cat(sprintf("check_links: %d distinct external links\n", length(hrefs)))

probe <- function(u) {
  h <- curl::new_handle(range = "0-0", followlocation = TRUE, timeout = 25, useragent = "calcofi-docs-check-links")
  r <- tryCatch(curl::curl_fetch_memory(u, handle = h), error = function(e) NULL)
  if (is.null(r)) return(NA_integer_)
  r$status_code
}
codes <- vapply(hrefs, probe, integer(1))
dead  <- hrefs[!is.na(codes) & codes %in% c(404L, 410L, 451L)]
odd   <- hrefs[is.na(codes) | !(codes %in% c(200:399, 404L, 410L, 451L))]

if (length(odd)) {
  cat("check_links: WARN (not fatal)\n")
  for (u in odd) cat(sprintf("  %s  %s\n", ifelse(is.na(codes[u]), "timeout", codes[u]), u))
}
if (length(dead)) {
  cat("check_links: DEAD links\n")
  for (u in dead) cat(sprintf("  %s  %s\n", codes[u], u))
  quit(status = 1)
}
cat("check_links: ok\n")
