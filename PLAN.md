# Plan: Quarto wiki-like site (EN main, DE mirrored)

Companion to `PROJECT_BRIEF.md` (goals, decisions) and `OUTLINE.md` (content).
This file holds the build plan, resolved decisions, and the few remaining open questions. Edit freely.

## 1. Resolved decisions

| # | Topic | Decision |
|---|---|---|
| 1 | Class folders | `democratic_principles`, `powers`, `selection_principles`, `case_stories`, `democratic_innovations`, `data_stories`, `mechanism_explorables`. Spelling: "sovereignty". Folder defines the class (no `type` field needed). |
| 2 | Powers hierarchy | One flat listing with a `group` field (`foundational` / `operational`), grouped display. |
| 3 | Mixed-language OUTLINE text | Isolate languages. Mixed passages are split into one EN page and one DE page. Pages that exist in only one language get stubs from the mirror script. |
| 4 | Non-mirrorable pages (dashboards, slides, explorables) | Undecided; in principle they may be mirrored too. Not implemented now. Leave room for a per-page opt-out (e.g. `mirror: false`) later. |
| 5 | Stubs in listings | Shown, with a visible badge (stub / machine / checked / curated). |
| 6 | Class pages | Each class `index.qmd` = handwritten intro, optional handwritten structured links, then the automatic listing below. The class `index.qmd` also supplies the class metadata (title, description). The main `index.qmd` explains the classes and links to them. |
| 7 | Tooling | Quarto + base R + Lua; tidyverse is allowed in content pages. |
| 8 | R environment | Always latest packages. See "Notes" for `renv`. |
| 9 | GitHub | Repo does not exist yet. See "Notes" and question 3. |
| 10 | Mirror script | Run **locally and manually**, not as pre-render. Two modes: check only (report what is missing or out of date, nonzero exit if so) and write (create/refresh stubs). CI only renders; it may run check mode to fail on stale stubs. |
| 11 | Content scope | Implement everything in OUTLINE (all bullets become pages). |
| 12 | Bibliography | From a public Zotero library, fetched automatically with no manual download. A page shows references only if it cites something. |

## 2. Build plan

Keep the folder-per-language design. Build in small steps; render and verify after each.

| Step | Deliverable | Check |
|---|---|---|
| 0 | `git init`, `.gitignore`, Quarto skeleton: `_quarto.yml`, `en/` and `de/` with `_metadata.yml`, root redirect, one sidebar per language. | Renders and navigates in both languages. |
| 1 | Content from OUTLINE: class `index.qmd` per language, main `index.qmd` (with the "Core assumption" text), and one page per outline bullet, including existing text (languages split per decision 3). | Listings show all pages. |
| 2 | `scripts/mirror.R` with `--check` / `--write`, tested first on a fixture: EN-only page, DE-only page, edited stub, deleted source. Fixes: banner names the source language, orphaned stubs removed, banner never duplicated. | Fixture passes; no hand-written page is ever overwritten. Then run on real content. |
| 3 | `filters/langswitch.lua` | `en/x` and `de/x` link to each other from every page. |
| 4 | `filters/wikilinks.lua`, with a render-time warning for broken targets. | A deliberately broken link is flagged. |
| 5 | Listings polish: translation-status badge, `group` display for powers, status field. | Stubs clearly marked. |
| 6 | Bibliography: `scripts/fetch_refs.R` pulls the Zotero library to a cached `references.json`; `bibliography:` set project-wide. | A page with a citation shows references; one without shows none. Works offline from the cached file. |
| 7 | GitHub Actions deployment to GitHub Pages; `site-url` and redirect host-agnostic. | A deployed test site works. |
| 8 (later) | Backlinks, hash-based "outdated" detection, machine translation, graph view, non-mirrorable page handling. | Not in v1. |

## 3. Design

### Page class from folder
Each class's `index.qmd` lists `contents: "*.qmd"` from its own folder. Paths are relative, so the same listing file structure works in both languages. A `type` field stays allowed for later cross-cutting listings.

### Translation status (ordered)
`stub` < `machine` < `checked` < `curated`. Listings and badges key off it. The mirror script only refreshes pages with `generated: true` and never touches a page once a human removes that flag. Machine translation later reuses this: it sets `generated: true`, `translation-status: machine`, `translation-source`.

### Front-matter fields

| Field | Purpose |
|---|---|
| `title` | Page title (translated). |
| `definition` | One-line summary, used as listing description. |
| `categories` | Free tags, for cross-cutting listings later. |
| `status` | `draft` / `review` / `published`. |
| `date` | Sorting, by-year listings. |
| `related` | List of wikilinks. |
| `tension-with`, `sources` | Principles pages. |
| `region`, `period` | Case stories. |
| `group` | Powers hierarchy. |

Values that drive listings are language-neutral keys; translated labels live in a lookup table.

### Wikilinks
Path-based, relative to the language root: `[[democratic_principles/popular_sovereignty]]`. The filter checks at render time that the file exists. Slug-only links are shorter but break once two classes share a name; title links are fragile because titles differ between languages and get edited.

### Bibliography
One shared bibliography file for both languages. Pandoc/Quarto lists references only for pages with citations, which matches the requirement. The Zotero library must be public for unauthenticated access. A fetch script (Zotero web API, CSL-JSON export) writes a cached file that is committed, so renders work offline and CI does not depend on Zotero availability.

## 4. Notes on your questions

- **Do we need `renv`?** Not for rendering text-only pages. It matters once pages contain R code cells (explorables, data stories), because CI must install packages. It conflicts mildly with "always latest": `renv` pins versions in `renv.lock`, and "latest" then means "latest at the last `renv::snapshot()`". Suggestion: introduce `renv` at step 7 (when CI is built), or earlier if code cells appear. Alternative without a lockfile: CI installs the latest versions via `r-lib/actions/setup-r-dependencies` from a `DESCRIPTION` file. That is simpler but not reproducible.
- **Should you make the GitHub repo?** I'd initialise git locally now (step 0). Creating the remote is quick but needs your account; I can do it with `gh` if it is installed and authenticated, or you can create an empty repo and give me its URL. Pages-from-Actions needs the repo to be public (or a paid plan for private).

## 5. Remaining questions

1. **Zotero.** Do you already have a Zotero account and a public group library? I need its group ID (or user ID) and optionally a collection key. Until then step 6 uses a placeholder and an empty `references.json`.
2. **GitHub.** Should I create the repo with `gh` (name and public/private?), or will you create it and give me the URL later? This only blocks step 7.
3. **`renv`.** Is "introduce at step 7 / when code cells appear" acceptable, or do you prefer the no-lockfile `DESCRIPTION` approach?
4. **German content.** For class intros, the main page and the German-language outline passages (Amthor quote, German principle texts, German power names), should I (a) write DE versions of the English class intros myself as handwritten `de` pages, or (b) leave them as stubs for you to translate? The mirror script handles (b) automatically; (a) costs more review effort for you.
5. **Outline passages that are notes to self.** OUTLINE contains drafting residue ("deine Punkte 1-8", "tying back to your political-equality principle", the stray "communicated data points)." fragment, and typos like "Monetray"). I'd clean obvious typos and strip remarks addressed to a collaborator when making pages, but flag each in a log. OK?
6. **Site title and name.** Use "Democracy Dynamics" (EN) and "Demokratie-Dynamik" (DE) as titles? Suggestions welcome.
7. **Sub-lists inside bullets.** Powers (and the taxation breakdown) have nested structure. Powers become one page each. Should the IMF GFS taxation breakdown stay one long page, or be split into several pages?

## 6. Your answers

1. https://www.zotero.org/groups/6756276/democracy_dynamics
2. Repo is now created on GitHub
3. I don't get it. I always try to avoid environments and go to most recent version of packages locally. For R this mostly works. Not sure if this is a good solution here.
4. Yes, please write limited amounts of translated texts yourself. 
5. OK
6. OK
7. No split for now.  
