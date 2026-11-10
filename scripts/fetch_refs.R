#!/usr/bin/env Rscript
# Download the public Zotero group library as CSL-JSON into references.json.
# Run manually (or in CI) whenever the library changes; the file is committed
# so rendering works offline.
#
# Cite keys are Zotero's own "Citation Key" field (falls back to the item key).
#   Rscript scripts/fetch_refs.R

library(jsonlite)

group <- 6756276
base <- sprintf("https://api.zotero.org/groups/%s/items/top", group)
page_size <- 100

fetch_all <- function(format) {
  out <- list()
  start <- 0
  repeat {
    url <- sprintf("%s?format=%s&limit=%d&start=%d&itemType=-attachment",
                   base, format, page_size, start)
    res <- fromJSON(url, simplifyVector = FALSE)
    items <- if (format == "csljson") res$items else res
    out <- c(out, items)
    if (length(items) < page_size) break
    start <- start + page_size
  }
  out
}

csl <- fetch_all("csljson")
meta <- fetch_all("json")

keys <- vapply(meta, function(m) {
  ck <- m$data$citationKey
  if (is.null(ck) || !nzchar(ck)) m$data$key else ck
}, character(1))
names(keys) <- vapply(meta, function(m) m$data$key, character(1))

for (i in seq_along(csl)) {
  item_key <- sub("^.*/", "", csl[[i]]$id)
  csl[[i]]$id <- unname(keys[[item_key]])
}

write_json(csl, "references.json", auto_unbox = TRUE, pretty = TRUE)
message("Wrote ", length(csl), " references to references.json")
