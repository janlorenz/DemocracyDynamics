#!/usr/bin/env Rscript
# Create and refresh stub translations so every page exists in every language.
#
#   Rscript scripts/mirror.R           check only (default); exit 1 if work is pending
#   Rscript scripts/mirror.R --write   create / refresh / remove generated stubs
#   --root=DIR                         project root (default ".")
#
# Rules
# - Only hand-written original pages are mirror sources. Pages with
#   `generated: true` or a `translation-source` are never sources, and a page
#   with `mirror: false` is skipped.
# - A stub is marked `generated: true`. Deleting that flag means "a human owns
#   this page now": the script never touches it again.
# - A stub also stores `translation-hash`, the hash of the body it wrote. If the
#   body no longer matches (edited but flag still set), the page is reported as
#   a conflict and never overwritten or deleted.

langs <- c("en", "de")
lang_names <- list(
  en = c(en = "English", de = "German"),
  de = c(en = "Englisch", de = "Deutsch")
)
banner <- c(
  en = "This page has not been translated yet. Showing the original (%s).",
  de = "Diese Seite wurde noch nicht \u00fcbersetzt. Hier das Original (%s)."
)
stub_keys <- c("generated", "translation-status", "translation-source", "translation-hash")

read_lines <- function(f) readLines(f, encoding = "UTF-8", warn = FALSE)

split_qmd <- function(x) {
  if (length(x) >= 2 && trimws(x[1]) == "---") {
    close <- which(trimws(x[-1]) == "---")[1] + 1L
    if (!is.na(close)) {
      return(list(
        yaml = x[seq_len(close - 2L) + 1L],
        body = x[seq_len(length(x) - close) + close]
      ))
    }
  }
  list(yaml = character(), body = x)
}

yaml_get <- function(yaml, key) {
  m <- grep(paste0("^", key, ":"), yaml, value = TRUE)
  if (!length(m)) return(NA_character_)
  v <- trimws(sub(paste0("^", key, ":"), "", m[1]))
  gsub("^[\"']|[\"']$", "", v)
}

hash_lines <- function(x) {
  f <- tempfile()
  on.exit(unlink(f))
  writeLines(x, f, useBytes = TRUE)
  unname(tools::md5sum(f))
}

read_page <- function(path) {
  lines <- read_lines(path)
  p <- split_qmd(lines)
  p$path <- path
  p$lines <- lines
  p$generated <- isTRUE(tolower(yaml_get(p$yaml, "generated")) == "true")
  p$source <- yaml_get(p$yaml, "translation-source")
  p$hash <- yaml_get(p$yaml, "translation-hash")
  p$mirror <- !isTRUE(tolower(yaml_get(p$yaml, "mirror")) == "false")
  p$is_source <- !p$generated && is.na(p$source) && p$mirror
  p
}

is_pristine <- function(p) !is.na(p$hash) && hash_lines(p$body) == p$hash

make_stub <- function(p, src, tgt) {
  body <- c(
    "", "::: {.callout-note}",
    sprintf(banner[[tgt]], lang_names[[tgt]][[src]]),
    ":::", "", p$body
  )
  yaml <- p$yaml[!grepl(paste0("^(", paste(stub_keys, collapse = "|"), "):"), p$yaml)]
  c(
    "---", yaml,
    "generated: true",
    "translation-status: stub",
    paste0("translation-source: ", src),
    paste0("translation-hash: ", hash_lines(body)),
    "---", body
  )
}

mirror_main <- function(args = commandArgs(trailingOnly = TRUE)) {
  write_mode <- "--write" %in% args
  root_arg <- sub("^--root=", "", grep("^--root=", args, value = TRUE))
  root <- if (length(root_arg)) root_arg[1] else "."

  pages <- lapply(setNames(langs, langs), function(l) {
    files <- list.files(file.path(root, l), "\\.qmd$", recursive = TRUE)
    files <- files[!startsWith(basename(files), "_")]
    setNames(lapply(files, function(f) read_page(file.path(root, l, f))), files)
  })

  todo <- list()
  add <- function(type, lang, f, detail = "", text = NULL) {
    todo[[length(todo) + 1L]] <<- list(
      type = type, lang = lang, file = f, detail = detail, text = text,
      path = file.path(root, lang, f)
    )
  }

  for (src in langs) for (f in names(pages[[src]])) {
    p <- pages[[src]][[f]]
    if (!p$is_source) next
    for (tgt in setdiff(langs, src)) {
      stub <- make_stub(p, src, tgt)
      cur <- pages[[tgt]][[f]]
      if (is.null(cur)) {
        add("create", tgt, f, paste("from", src), stub)
      } else if (cur$generated && !identical(cur$lines, stub)) {
        if (is_pristine(cur)) {
          add("refresh", tgt, f, paste("source", src, "changed"), stub)
        } else {
          add("conflict", tgt, f,
              "edited but still `generated: true`; remove the flag to keep your edits")
        }
      }
    }
  }

  for (tgt in langs) for (f in names(pages[[tgt]])) {
    cur <- pages[[tgt]][[f]]
    if (!cur$generated) next
    src <- cur$source
    has_source <- !is.na(src) && src %in% langs &&
      !is.null(pages[[src]][[f]]) && pages[[src]][[f]]$is_source
    if (has_source) next
    if (is_pristine(cur)) {
      add("remove", tgt, f, "source page is gone")
    } else {
      add("conflict", tgt, f,
          "generated page without a source and with edits; remove the flag to keep it")
    }
  }

  if (!length(todo)) {
    message("Everything up to date.")
    return(invisible(0L))
  }

  for (a in todo) {
    message(sprintf("%-9s %s/%s  %s", a$type, a$lang, a$file, a$detail))
    if (write_mode && a$type %in% c("create", "refresh")) {
      dir.create(dirname(a$path), recursive = TRUE, showWarnings = FALSE)
      writeLines(a$text, a$path, useBytes = TRUE)
    } else if (write_mode && a$type == "remove") {
      file.remove(a$path)
    }
  }

  pending <- Filter(function(a) !write_mode || a$type == "conflict", todo)
  if (write_mode) {
    message(sprintf("Done. %d action(s) applied, %d conflict(s) left.",
                    length(todo) - length(pending), length(pending)))
  } else {
    message(sprintf("%d action(s) pending. Run with --write to apply.", length(pending)))
  }
  invisible(if (length(pending)) 1L else 0L)
}

if (sys.nframe() == 0L) quit(status = mirror_main(), save = "no")
