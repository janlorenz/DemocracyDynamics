-- Adds an "EN | DE" switcher at the top of every page. Because every page
-- exists in every language (see scripts/mirror.R), no fallback logic is needed.

local languages = { "en", "de" }
local labels = { en = "EN", de = "DE" }
local titles = { en = "English", de = "Deutsch" }

local function current_page()
  local input = quarto.doc.input_file
  local dir = quarto.project.directory
  if not input or not dir then return nil end
  input = input:gsub("\\", "/")
  dir = dir:gsub("\\", "/")
  if input:sub(1, #dir) ~= dir then return nil end
  local rel = input:sub(#dir + 2)
  local lang, rest = rel:match("^(%a+)/(.+)%.qmd$")
  if not lang or not labels[lang] then return nil end
  local _, depth = rel:gsub("/", "")
  return lang, rest, string.rep("../", depth):gsub("/$", "")
end

function Pandoc(doc)
  local lang, rest, offset = current_page()
  if not lang then return nil end
  if offset == "" then offset = "." end

  local parts = {}
  for _, l in ipairs(languages) do
    if l == lang then
      parts[#parts + 1] = string.format('<strong>%s</strong>', labels[l])
    else
      parts[#parts + 1] = string.format(
        '<a href="%s/%s/%s.html" hreflang="%s" title="%s">%s</a>',
        offset, l, rest, l, titles[l], labels[l])
    end
  end
  local html = '<nav class="lang-switch" aria-label="Language">'
    .. table.concat(parts, " | ") .. '</nav>'
  table.insert(doc.blocks, 1, pandoc.RawBlock("html", html))
  return doc
end
