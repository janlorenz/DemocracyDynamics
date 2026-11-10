# Project brief: Quarto wiki-like site (EN main, DE mirrored)

> Handoff document from a planning conversation. Use as `CLAUDE.md` (Claude Code)
> or attach to Positron Assistant. Treat "Decisions" as the current plan, and
> "Open questions" as things to resolve with the user **before** coding.

## 1. Goal

A static, wiki-like website built with **Quarto**:

- Highly interlinked pages.
- A few **summary pages**, each listing all pages of one *page class*
  (e.g. all `person` pages).
- **No editing UI** on the site. Content is authored as plain `.qmd` files.
- **Multilingual**: English is the main language, German is maintained closely.
  German pages sometimes come first. Stub translations are acceptable, but
  mirroring should be as automatic as possible.
- Extensible to more languages later (not planned in the short run).
- Author is fine with R. Prefer few dependencies / little hidden magic.
- Not an Obsidian workflow. Obsidian was only an analogy for the look and feel.

## 2. Background facts (checked Nov 2026)

- Quarto has **no native multilingual website support**. The `lang` option only
  translates UI strings (search, TOC, ...). An upstream issue for native
  support exists.
- `babelquarto` (rOpenSci, R package) renders multilingual projects and adds a
  language switcher. It does not translate content (translation lives in
  `babeldown`). It assumes one main language and suffix-paired files, which fits
  badly with "German sometimes first". Rejected for now, but a fallback option.
- Quarto profiles (`_quarto-en.yml`, `_quarto-de.yml`) allow one render per
  language with fully translated navbars, at the cost of manual build
  orchestration and a manual language switcher.
- Quarto has no native `[[wikilinks]]` and no native backlinks or graph view.
- Quarto **listings** can be filtered by front-matter fields, which is the
  mechanism for per-class summary pages.

## 3. Decisions so far

1. **Folder-per-language in a single Quarto project**: `en/`, `de/`, with
   identical relative paths and filenames across languages.
2. `_metadata.yml` per language folder sets `lang` and the sidebar.
   One sidebar per language in `_quarto.yml`.
3. **Pre-render R script on demand** (`scripts/mirror.R`, base R only) creates missing
   counterpart pages as stubs, in both directions:
   - stub = source front matter + `generated: true`,
     `translation-status: stub`, `translation-source: <lang>` + a callout
     banner "not translated yet" + the source body.
   - Generated stubs are refreshed on every render.
   - A human edit is signalled by deleting `generated: true`. The script then
     never touches that page again.
   - Stubs are never used as a mirror source. Hand-written pages are never
     overwritten.
   - Commit generated stubs to git so translators can edit them in place.
   - Perspectively, add a similar feature for automatic translation of pages with another translation-status. Important: Also this should in principle work in both directions without causing confusion for manual editors. 
4. **Language switcher**: Lua filter mapping `en/foo.html` <-> `de/foo.html`.
   Because every page exists in every language, no fallback logic is needed.
5. **Wikilinks**: Lua filter turning `[[people/ada]]` (or an agreed syntax) into
   a link within the *current* language folder, so links never switch language
   by accident.
6. **Summary pages**: per-language Quarto listings filtered by a front-matter
   field (provisionally `type: democratic_principle`). `translation-status: stub` can be used
   to badge, show or hide untranslated pages.
7. Root `index.html` redirects to `/en/` or `/de/` by browser language.
8. Adding a language = new folder + entry in `langs` + sidebar + banner string.

### Known limitations of the plan

- The top **navbar is global** in a single project. Keep it language-neutral
  (logo, search, switcher). Per-language sidebars are fine.
- Stubs handle *missing* pages, not *outdated* ones. Optional extension: store a
  hash of the source body in each translated page and flag mismatches. Check how this is feasible most user friendly. 
- Backlinks are not built in. Plan: extend the pre-render script to scan links
  and generate a "linked from" block per page (per language).
- No graph view unless custom JS is added. 

## 4. Intended structure

```
_quarto.yml
scripts/mirror.R            # pre-render: create/refresh stubs
filters/wikilinks.lua       # [[page]] -> language-aware link
filters/langswitch.lua      # EN | DE switcher on every page
index.html                  # language redirect
en/  _metadata.yml  index.qmd  democratic_principles/popular_sovereignity.qmd  ...
de/  _metadata.yml  index.qmd  people/ada.qmd  ...
```

In `_quarto.yml`: `project: pre-render: Rscript scripts/mirror.R`, filters
registered, one sidebar per language.

## 5. Draft of `scripts/mirror.R` (not yet tested)

```r
langs  <- c("en", "de")
banner <- c(
  en = "This page has not been translated yet. Showing the German original.",
  de = "Diese Seite wurde noch nicht übersetzt. Hier das englische Original."
)

read_qmd <- function(f) {
  x <- readLines(f, encoding = "UTF-8", warn = FALSE)
  d <- which(x == "---")
  if (length(d) >= 2 && d[1] == 1)
    list(yaml = x[2:(d[2] - 1)], body = x[-(1:d[2])])
  else list(yaml = character(), body = x)
}
is_generated <- function(f) any(grepl("^generated: true", readLines(f, warn = FALSE)))

for (src in langs) for (tgt in setdiff(langs, src)) {
  for (f in list.files(src, "\\.qmd$", recursive = TRUE)) {
    from <- file.path(src, f); to <- file.path(tgt, f)
    if (is_generated(from)) next
    if (file.exists(to) && !is_generated(to)) next
    p <- read_qmd(from)
    dir.create(dirname(to), recursive = TRUE, showWarnings = FALSE)
    writeLines(c(
      "---", p$yaml,
      "generated: true",
      "translation-status: stub",
      paste0("translation-source: ", src),
      "---", "",
      "::: {.callout-note}", banner[[tgt]], ":::", "",
      p$body
    ), to, useBytes = TRUE)
  }
}
```

Known issues to handle: the banner text assumes a 2-language setup (generalise
to name the source language); a stub whose source is later deleted should be
removed; the banner should not be duplicated if the script is rerun.

## 6. Open questions (resolve first)

1. **Listing structure**. Topics to settle:
   - Categories and a bit of basic content is listed in OUTLINE.md. 
   - Propose some useful front-matter fields for pages besides the category. Things like `definition` oder abstract
   - At first one listing per class is fine. Options for cross-cutting listings (by tag, by year, ...) should not be ruled out for later?
   - Table vs. cards vs. default listing, per class? This shall be customizable. Not decideable yet. 
   - Sort/filter/search behaviour; are category or tag pages needed?
   - Listing fields (titles, descriptions, categories) need not be translated when they are not exposed to the user. Ideally they do not be duplicated per language if possible.
   - Do stubs appear in listings, and how are they marked? This should be optional and if they are shown, then stub and automatic translation need to be clearly visible for the user. 
2. Should front-matter *values* that drive listings (e.g. `type`) be
   language-neutral keys with translated labels? Recommended: yes.
3. Wikilink syntax: path-based (`[[democratic_principle/popular_sovereignity]]`), slug-only, or by title?
   How are link targets validated at render time? Inform the user about options and implications.
4. Is backlink generation required in v1? No, but should not be ruled out. 
5. Do we want machine translation of stubs later (e.g. `babeldown`)? Yes, as option with a hierarchy: stub, automatic translation, human checked, human curated
6. Hosting target (GitHub Pages, Netlify, ...) affects the root redirect and `site-url` handling: 
   First target is GitHub Pages. Ideally deployed using GitHub Actions. Should perspectively also work on other infrastructure. 

## 7. Instructions for the coding assistant

- Start by discussing the **listing structure** with the user, then re-check
  whether the folder-per-language plan still holds or whether profiles /
  `babelquarto` fit better.
- Keep the stack minimal: Quarto + base R +tidyverse + Lua filters. Avoid extra R
  packages unless there is a clear benefit.
- Build in small steps: skeleton site -> mirror script -> language switcher ->
  wikilinks -> listings -> backlinks. Render and verify after each step.
- All pages shall be open to be populated with code cells for visuals and the like. 
  Also quarto dashboards, quarto closereads, quarto presentations with revealjs (embedded) are potential documents to be included. 
- Test the mirror script on a small fixture (EN-only page, DE-only page, edited
  stub, deleted source) before using it on real content.
- Do not overwrite hand-written content under any circumstance.
- Keep in mind that major work shall be done by humans and amount of pages shall grow. 
  The basic structure of categories is supposed to change not too much, but must alos be extendable. 
