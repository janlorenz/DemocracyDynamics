-- Shows a notice on automatically translated pages (translation-status: machine).
-- Stub pages carry their banner in the body (written by scripts/mirror.R).

local messages = {
  en = "This page was translated automatically and has not been checked by a human yet.",
  de = "Diese Seite wurde automatisch \u{00fc}bersetzt und noch nicht von einem Menschen gepr\u{00fc}ft.",
}

function Pandoc(doc)
  local status = pandoc.utils.stringify(doc.meta["translation-status"] or "")
  if status ~= "machine" then return nil end
  local lang = pandoc.utils.stringify(doc.meta.lang or "en"):sub(1, 2)
  local msg = messages[lang] or messages.en
  local banner = pandoc.Div({ pandoc.Para({ pandoc.Str(msg) }) },
    pandoc.Attr("", { "callout-warning" }))
  table.insert(doc.blocks, 1, banner)
  return doc
end
