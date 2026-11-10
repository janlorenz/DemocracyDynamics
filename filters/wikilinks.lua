-- Turns [[path/to/page]] or [[path/to/page|label]] into a link inside the
-- *current* language folder, so links never switch language by accident.
-- Targets are checked at render time; broken ones produce a warning and are
-- marked in red on the page.

local known = { en = true, de = true }

local function context()
  local input = quarto.doc.input_file
  local dir = quarto.project.directory
  if not input or not dir then return nil end
  input = input:gsub("\\", "/")
  dir = dir:gsub("\\", "/")
  if input:sub(1, #dir) ~= dir then return nil end
  local rel = input:sub(#dir + 2)
  local lang = rel:match("^(%a+)/")
  if not lang or not known[lang] then return nil end
  local _, depth = rel:gsub("/", "")
  local offset = string.rep("../", depth):gsub("/$", "")
  if offset == "" then offset = "." end
  return { lang = lang, offset = offset, dir = dir, rel = rel }
end

local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

local function title_of(file)
  local f = io.open(file, "r")
  if not f then return nil end
  local n = 0
  local title
  for line in f:lines() do
    n = n + 1
    if n == 1 and trim(line) ~= "---" then break end
    if n > 1 and trim(line) == "---" then break end
    local t = line:match("^title:%s*(.-)%s*$")
    if t then
      t = t:gsub('^"(.*)"$', "%1"):gsub("^'(.*)'$", "%1"):gsub('\\"', '"')
      title = t
      break
    end
  end
  f:close()
  return title
end

local function words(s)
  local out = pandoc.List()
  local first = true
  for w in s:gmatch("%S+") do
    if not first then out:insert(pandoc.Space()) end
    out:insert(pandoc.Str(w))
    first = false
  end
  return out
end

local function make_link(inner, ctx)
  local target, label = inner:match("^(.-)|(.*)$")
  if not target then target = inner end
  target = trim(target)
  local anchor
  local t, a = target:match("^(.-)#(.*)$")
  if t then target, anchor = t, a end
  target = target:gsub("^/", ""):gsub("%.qmd$", ""):gsub("%.html$", "")

  local file = ctx.dir .. "/" .. ctx.lang .. "/" .. target .. ".qmd"
  local exists = false
  local fh = io.open(file, "r")
  if fh then fh:close(); exists = true end

  local text
  if label and trim(label) ~= "" then
    text = trim(label)
  else
    text = (exists and title_of(file)) or target:match("([^/]+)$") or target
  end

  if not exists then
    io.stderr:write(string.format(
      "WARNING [wikilinks] broken link [[%s]] in %s (no %s/%s.qmd)\n",
      inner, ctx.rel, ctx.lang, target))
    return pandoc.Span(words(text),
      pandoc.Attr("", { "wikilink-broken" }, { title = "Broken wikilink: " .. inner }))
  end

  local href = ctx.offset .. "/" .. ctx.lang .. "/" .. target .. ".html"
  if anchor then href = href .. "#" .. anchor end
  return pandoc.Link(words(text), href, "", pandoc.Attr("", { "wikilink" }))
end

function Inlines(inlines)
  local ctx = context()
  if not ctx then return nil end

  local items = pandoc.List(inlines)
  local out = pandoc.List()
  local changed = false
  local i = 1
  while i <= #items do
    local el = items[i]
    if el.t == "Str" and el.text:find("[[", 1, true) then
      -- Collect text up to the Str that closes the link.
      local buf, j, found = {}, i, false
      while j <= #items do
        local e = items[j]
        if e.t == "Str" then
          buf[#buf + 1] = e.text
        elseif e.t == "Space" or e.t == "SoftBreak" then
          buf[#buf + 1] = " "
        else
          break
        end
        if e.t == "Str" and table.concat(buf):find("]]", 1, true) then
          found = true
          break
        end
        j = j + 1
      end
      local s = table.concat(buf)
      local pre, inner, post
      if found then pre, inner, post = s:match("^(.-)%[%[(.-)%]%](.*)$") end
      if inner then
        if pre ~= "" then out:insert(pandoc.Str(pre)) end
        out:insert(make_link(inner, ctx))
        changed = true
        if post ~= "" then
          items[j] = pandoc.Str(post)
          i = j
        else
          i = j + 1
        end
      else
        out:insert(el)
        i = i + 1
      end
    else
      out:insert(el)
      i = i + 1
    end
  end
  if changed then return out end
  return nil
end
