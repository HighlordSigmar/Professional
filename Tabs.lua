-- Professional: the five tabs (Recipes, Missing, Skill-up, Queue & Shopping, Alts)

local CM = Professional
CM.Tabs = CM.Tabs or {}

local function matches(text, search)
  if not search or search == "" then return true end
  return text and string.find(string.lower(text), search, 1, true) and true or false
end

local function infoRow(text, id)
  return { id = id or ("info:" .. text), kind = "info", text = text }
end

local function headerRow(text, id)
  return { id = id or ("head:" .. text), kind = "section", text = text }
end

-- rendering shared by every tab for info / section rows
local function renderCommon(row, d)
  if d.kind == "info" then
    row.text:SetText(d.text)
    row.text:SetTextColor(0.7, 0.7, 0.7)
    return true
  elseif d.kind == "section" then
    row.text:SetText(d.text)
    row.text:SetTextColor(0.2, 0.8, 1)
    if d.right then row.right:SetText(d.right) end
    return true
  end
  return false
end

local function linkRecipe(prof, name, index, mode)
  if not (ChatFrameEditBox and ChatFrameEditBox:IsVisible()) then return end
  local link
  if mode and index then link = CM.API[mode].link(index) end
  if not link then
    local rec = CM:Recipe(prof, name)
    if rec.item then link = CM:ItemChatLink(rec.item) end
  end
  ChatFrameEditBox:Insert(link or name)
end

local function placeholderDetail(title, lines)
  CM:SetDetail({ icon = CM.view.prof and CM:ProfIcon(CM.view.prof), title = title, lines = lines })
end

------------------------------------------------------------------------
-- RECIPES
------------------------------------------------------------------------
local R = { search = "", count = 1 }
CM.Tabs.recipes = R
local SORTS = { "category", "difficulty", "name", "level" }
local SORT_LABEL = { category = "Sort: Category", difficulty = "Sort: Difficulty", name = "Sort: Name", level = "Sort: Skill level" }

function R:Init()
  local f = self.filter
  self.searchBox = CM:MakeEdit("ProfessionalRecipeSearch", f, 150, "Search names, reagents", function(text)
    R.search = string.lower(text or "")
    CM:RefreshSoon()
  end)
  self.searchBox:SetPoint("LEFT", f, "LEFT", 8, 0)
  self.haveCheck = CM:MakeCheck("ProfessionalHaveMats", f, "Have mats", function(v) R.haveMats = v; CM:Refresh(true) end,
    "Only show recipes you have all the reagents for.")
  self.haveCheck:SetPoint("LEFT", self.searchBox, "RIGHT", 6, 0)
  self.skillCheck = CM:MakeCheck("ProfessionalSkillUps", f, "Skill-ups only", function(v) R.skillUps = v; CM:Refresh(true) end,
    "Hide grey recipes that no longer give skill points.")
  self.skillCheck:SetPoint("LEFT", self.haveCheck.label, "RIGHT", 6, -1)
  self.sortButton = CM:MakeButton("ProfessionalSortButton", f, SORT_LABEL[CM.settings.sort] or "Sort", 120, 20, function()
    local cur = CM.settings.sort
    local nxt = SORTS[1]
    for i = 1, table.getn(SORTS) do
      if SORTS[i] == cur then nxt = SORTS[i + 1] or SORTS[1] end
    end
    CM.settings.sort = nxt
    this:SetText(SORT_LABEL[nxt])
    CM:Refresh(true)
  end)
  self.sortButton:SetPoint("LEFT", self.skillCheck.label, "RIGHT", 10, 1)
  self.collapseButton = CM:MakeButton("ProfessionalCollapseAll", f, "Collapse all", 90, 20, function()
    local prof = CM.view.prof or ""
    local any = false
    for k, v in pairs(CM.collapsed) do
      if v and string.sub(k, 1, string.len(prof) + 1) == prof .. ":" then any = true end
    end
    if any then
      for k in pairs(CM.collapsed) do
        if string.sub(k, 1, string.len(prof) + 1) == prof .. ":" then CM.collapsed[k] = nil end
      end
    else
      for _, d in ipairs(CM.list.data) do
        if d.kind == "header" then CM.collapsed[CM.view.prof .. ":" .. d.name] = true end
      end
    end
    CM:Refresh()
  end)
  self.collapseButton:SetPoint("LEFT", self.sortButton, "RIGHT", 4, 0)

  local b = self.bottom
  self.minus = CM:MakeButton("ProfessionalMinus", b, "-", 24, 22, function() R:SetCount(R.count - 1) end)
  self.minus:SetPoint("LEFT", b, "LEFT", 4, 0)
  local box = CreateFrame("EditBox", "ProfessionalCountBox", b, "InputBoxTemplate")
  box:SetWidth(34); box:SetHeight(20)
  box:SetAutoFocus(false)
  box:SetJustifyH("CENTER")
  box:SetPoint("LEFT", self.minus, "RIGHT", 8, 0)
  box:SetScript("OnEnterPressed", function() this:ClearFocus() end)
  box:SetScript("OnEscapePressed", function() this:ClearFocus() end)
  box:SetScript("OnTextChanged", function()
    local n = tonumber(this:GetText())
    if n and n >= 1 then R.count = math.floor(n) end
  end)
  self.countBox = box
  self.plus = CM:MakeButton("ProfessionalPlus", b, "+", 24, 22, function() R:SetCount(R.count + 1) end)
  self.plus:SetPoint("LEFT", box, "RIGHT", 2, 0)
  self.create = CM:MakeButton("ProfessionalCreate", b, "Create", 80, 22, function() R:Create(false) end)
  self.create:SetPoint("LEFT", self.plus, "RIGHT", 6, 0)
  self.createAll = CM:MakeButton("ProfessionalCreateAll", b, "Create All", 90, 22, function() R:Create(true) end)
  self.createAll:SetPoint("LEFT", self.create, "RIGHT", 4, 0)
  self.queueBtn = CM:MakeButton("ProfessionalQueueAdd", b, "Add to queue", 100, 22, function()
    local d = CM.list.selected
    if d and d.kind == "recipe" then
      CM:QueueAdd(CM.view.prof, d.name, R.count)
      CM:Print("queued " .. R.count .. " x " .. d.name .. ".")
      CM:Refresh()
    end
  end)
  self.queueBtn:SetPoint("LEFT", self.createAll, "RIGHT", 10, 0)
  self:SetCount(1)
end

function R:SetCount(n)
  self.count = math.max(1, math.min(999, n or 1))
  self.countBox:SetText(tostring(self.count))
end

function R:Craftable(rec, char)
  local rg = rec.reagents
  if not rg or table.getn(rg) == 0 then return 0 end
  local best
  for j = 1, table.getn(rg), 2 do
    local have = (char.bags and char.bags[rg[j]]) or 0
    local n = math.floor(have / (rg[j + 1] or 1))
    if not best or n < best then best = n end
  end
  return best or 0
end

function R:Build()
  local prof = CM.view.prof
  if not prof then return { infoRow("This character has no professions with recipes yet.") } end
  local mode, snap = CM:ViewLive()
  local char = CM:ViewChar()
  local skill = CM:ViewSkill() or 0
  local entries = {}
  if snap then
    entries = snap.entries
  else
    local p = char.profs[prof]
    if not p or not p.list then
      if CM:IsViewingSelf() then
        return { infoRow("Open your " .. prof .. " window once so Professional"), infoRow("can read the recipes you know.") }
      end
      return { infoRow("No recipes saved for this character yet.") }
    end
    local header
    for i = 1, table.getn(p.list) do
      local name = p.list[i]
      if string.sub(name, 1, 1) == "#" then
        header = string.sub(name, 2)
        table.insert(entries, { kind = "header", name = header })
      else
        local rec = CM:Recipe(prof, name)
        table.insert(entries, { kind = "recipe", name = name, key = rec.key, diff = CM:Difficulty(rec, skill) or "unknown", avail = self:Craftable(rec, char), header = header })
      end
    end
  end

  local queued = {}
  if CM:IsViewingSelf() then
    for _, q in ipairs(CM.char.queue) do
      if q.p == prof then queued[CM.Key(q.n)] = (queued[CM.Key(q.n)] or 0) + q.c end
    end
  end

  local search = self.search
  local sort = CM.settings.sort
  local out, flat = {}, {}
  local group, emitted
  for i = 1, table.getn(entries) do
    local e = entries[i]
    if e.kind == "header" then
      group = { id = "h:" .. e.name, kind = "header", name = e.name, collapsed = CM.collapsed[prof .. ":" .. e.name] }
      emitted = false
    else
      local ok = true
      if self.haveMats and (e.avail or 0) <= 0 then ok = false end
      if ok and self.skillUps and e.diff == "trivial" then ok = false end
      if ok and search ~= "" and not matches(e.name, search) then
        ok = false
        local rec = CM:Recipe(prof, e.name)
        if rec.reagents then
          for j = 1, table.getn(rec.reagents), 2 do
            if matches(CM:ItemName(rec.reagents[j]), search) then ok = true; break end
          end
        end
      end
      if ok then
        local row = { id = "r:" .. e.key, kind = "recipe", name = e.name, key = e.key, diff = e.diff, avail = e.avail, index = e.index, header = e.header, queued = queued[e.key] }
        if sort == "category" then
          if group and not emitted then
            table.insert(out, group)
            emitted = true
          end
          if not (group and group.collapsed) then
            row.indent = group and 6 or 0
            table.insert(out, row)
          end
        else
          table.insert(flat, row)
        end
      end
    end
  end
  if sort ~= "category" then
    local levels = {}
    if sort == "level" then
      for i = 1, table.getn(flat) do
        local rec = CM:Recipe(prof, flat[i].name)
        levels[flat[i].key] = rec.learn or 0
      end
    end
    table.sort(flat, function(a, b)
      if sort == "difficulty" then
        local da, db = CM.DIFF_ORDER[a.diff] or 5, CM.DIFF_ORDER[b.diff] or 5
        if da ~= db then return da < db end
      elseif sort == "level" then
        local la, lb = levels[a.key] or 0, levels[b.key] or 0
        if la ~= lb then return la > lb end
      end
      return a.name < b.name
    end)
    out = flat
  end
  if table.getn(out) == 0 then
    table.insert(out, infoRow("No recipes match the filters."))
  end
  local anyCollapsed = false
  for k, v in pairs(CM.collapsed) do
    if v and string.sub(k, 1, string.len(prof) + 1) == prof .. ":" then anyCollapsed = true end
  end
  self.collapseButton:SetText(anyCollapsed and "Expand all" or "Collapse all")
  local known = 0
  for i = 1, table.getn(entries) do if entries[i].kind == "recipe" then known = known + 1 end end
  CM.status:SetText(known .. " recipes known")
  return out
end

function R:Render(row, d, sel)
  if renderCommon(row, d) then return end
  if d.kind == "header" then
    row.text:SetText((d.collapsed and "|cffffffff+|r " or "|cffffffff-|r ") .. d.name)
    row.text:SetTextColor(1, 0.82, 0)
    return
  end
  local c = CM.DIFF_COLOR[d.diff] or CM.DIFF_COLOR.unknown
  row.text:SetText(d.name)
  row.text:SetTextColor(c.r, c.g, c.b)
  local cache = CM.db.cache[CM.view.prof]
  local icon = cache and cache[d.key] and cache[d.key].ic
  row.icon:SetTexture(icon or CM:ProfIcon(CM.view.prof))
  local right = ""
  if d.avail and d.avail > 0 then right = "|cff40ff40[" .. d.avail .. "]|r" end
  if d.queued then right = right .. " |cff33ccffQ" .. d.queued .. "|r" end
  row.right:SetText(right)
end

function R:Click(d, button)
  if d.kind == "header" then
    local k = CM.view.prof .. ":" .. d.name
    CM.collapsed[k] = not CM.collapsed[k]
    CM:Refresh()
    return
  end
  if d.kind ~= "recipe" then return end
  local mode = CM:ViewLive()
  if IsShiftKeyDown() then
    linkRecipe(CM.view.prof, d.name, d.index, mode)
    return
  end
  if IsControlKeyDown() then
    local rec = CM:Recipe(CM.view.prof, d.name)
    local link = rec.item and CM:ItemChatLink(rec.item)
    if link and DressUpItemLink then DressUpItemLink(link) end
    return
  end
  if button == "RightButton" and CM:IsViewingSelf() then
    CM:QueueAdd(CM.view.prof, d.name, 1)
    CM:Refresh()
    return
  end
  if mode and d.index then CM.API[mode].select(d.index) end
  CM:Select(d)
end

function R:Detail(d)
  local prof = CM.view.prof
  if not d or d.kind ~= "recipe" then
    local char = CM:ViewChar()
    local rank, max = CM:ViewSkill()
    local lines = {}
    table.insert(lines, { text = "Select a recipe to see its reagents and skill-ups." })
    table.insert(lines, { text = " " })
    table.insert(lines, { text = "|cffffd100Tips|r" })
    table.insert(lines, { text = "Shift-click a recipe to link it in chat." })
    table.insert(lines, { text = "Ctrl-click to preview it in the dressing room." })
    table.insert(lines, { text = "Right-click to add one to the craft queue." })
    table.insert(lines, { text = "Click a header to fold it." })
    table.insert(lines, { text = "Recipe colours: |cffff8040orange|r always gives a point, |cffffff00yellow|r usually, |cff40c040green|r sometimes, |cff808080grey|r never." })
    placeholderDetail(prof and (prof .. (rank and (" " .. rank .. "/" .. (max or "?")) or "")) or "Professional", lines)
    return
  end
  local rec = CM:Recipe(prof, d.name)
  local mode = CM:ViewLive()
  local char = CM:ViewChar()
  local skill = CM:ViewSkill()
  local ctx = { mode = mode, index = d.index, char = char, skill = skill }
  local lines = CM:RecipeDetail(rec, ctx)
  local icon = rec.icon
  if mode and d.index then icon = CM.API[mode].icon(d.index) or icon end
  local c = CM.DIFF_COLOR[d.diff] or CM.DIFF_COLOR.unknown
  local title = rec.item and (CM:ItemQualityHex(rec.item) .. d.name .. "|r") or d.name
  local sub = CM.Hex(c) .. (d.diff == "optimal" and "Orange" or d.diff == "medium" and "Yellow" or d.diff == "easy" and "Green" or d.diff == "trivial" and "Grey" or "Known") .. "|r"
  if d.header then sub = sub .. "  |cff999999" .. d.header .. "|r" end
  if d.avail and d.avail > 0 then sub = sub .. "  |cff40ff40can make " .. d.avail .. "|r" end
  CM:SetDetail({
    icon = icon, title = title, sub = sub, lines = lines,
    iconTooltip = function(owner)
      if mode and d.index then
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        CM.API[mode].tooltip(GameTooltip, d.index)
        GameTooltip:Show()
      elseif rec.item then
        CM:ShowItemTooltip(owner, rec.item)
      end
    end,
    iconClick = function()
      if IsShiftKeyDown() then linkRecipe(prof, d.name, d.index, mode) end
    end,
  })
end

function R:UpdateBottom()
  local d = CM.list.selected
  local mode = CM:ViewLive()
  local isRecipe = d and d.kind == "recipe"
  if isRecipe and mode and d.index and (d.avail or 0) > 0 then
    self.create:Enable(); self.createAll:Enable()
  else
    self.create:Disable(); self.createAll:Disable()
  end
  if mode == "craft" then self.createAll:Disable() end
  if isRecipe and CM:IsViewingSelf() then self.queueBtn:Enable() else self.queueBtn:Disable() end
end

function R:Create(all)
  local d = CM.list.selected
  local mode, snap = CM:ViewLive()
  if not d or d.kind ~= "recipe" or not snap then return end
  local e = snap.byKey[d.key]
  if not e then return end
  local n = all and e.avail or math.min(self.count, math.max(e.avail, 1))
  if n < 1 then return end
  CM.API[mode].make(e.index, n)
end

------------------------------------------------------------------------
-- MISSING
------------------------------------------------------------------------
local M = { search = "" }
CM.Tabs.missing = M

function M:Init()
  local f = self.filter
  self.searchBox = CM:MakeEdit("ProfessionalMissingSearch", f, 150, "Search missing recipes", function(text)
    M.search = string.lower(text or "")
    CM:RefreshSoon()
  end)
  self.searchBox:SetPoint("LEFT", f, "LEFT", 8, 0)
  self.nowCheck = CM:MakeCheck("ProfessionalLearnNow", f, "Learnable now", function(v) M.nowOnly = v; CM:Refresh(true) end,
    "Only recipes your current skill is high enough for.")
  self.nowCheck:SetPoint("LEFT", self.searchBox, "RIGHT", 6, 0)
  self.factionCheck = CM:MakeCheck("ProfessionalOtherFaction", f, "Other faction", function(v)
    CM.settings.showOtherFaction = v
    CM:Refresh(true)
  end, "Also list recipes that only the other faction can get, and their trainers and vendors.")
  self.factionCheck:SetPoint("LEFT", self.nowCheck.label, "RIGHT", 6, -1)
  self.typeButton = CM:MakeButton("ProfessionalSourceFilter", f, "Source: All", 120, 20, function()
    local order = { "all", "T", "V", "D", "Q", "R", "C" }
    local cur = M.source or "all"
    local nxt = "all"
    for i = 1, table.getn(order) do if order[i] == cur then nxt = order[i + 1] or "all" end end
    M.source = nxt
    local labels = { all = "Source: All", T = "Source: Trainer", V = "Source: Vendor", D = "Source: Drop", Q = "Source: Quest", R = "Source: Reputation", C = "Source: Custom" }
    this:SetText(labels[nxt])
    CM:Refresh(true)
  end)
  self.typeButton:SetPoint("LEFT", self.factionCheck.label, "RIGHT", 10, 1)

  local b = self.bottom
  self.summary = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  self.summary:SetPoint("LEFT", b, "LEFT", 6, 0)
  self.legend = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  self.legend:SetPoint("LEFT", self.summary, "RIGHT", 16, 0)
  self.legend:SetText("|cff40ff40learnable now|r  |cffffff00within 25 points|r  |cffff8040later|r  |cffff4040blocked|r   A auto  T trainer  V vendor  D drop  Q quest  R rep  C custom")
end

function M:Build()
  local prof = CM.view.prof
  if not prof then return { infoRow("No profession selected.") } end
  local char = CM:ViewChar()
  local skill = CM:ViewSkill() or 0
  self.factionCheck:SetChecked(CM.settings.showOtherFaction and 1 or nil)
  local out = {}
  local p = char.profs[prof]
  if not p or not p.list then
    table.insert(out, infoRow("|cffff8040Open the " .. prof .. " window once so known recipes are hidden.|r", "warn"))
  end
  local total, now = 0, 0
  local rows = {}
  for _, rec in ipairs(CM:ProfessionRecipes(prof)) do
    if not CM:CharKnows(char, prof, rec.key, rec.item) and CM:RecipeFactionOK(rec) then
      local state = CM:LearnState(rec, char, skill)
      local tags = CM:SourceTags(rec)
      total = total + 1
      if state == "now" then now = now + 1 end
      local ok = (not self.nowOnly or state == "now") and matches(rec.name, self.search)
      if ok and self.source and self.source ~= "all" and not string.find(tags, self.source, 1, true) then ok = false end
      if ok then
        table.insert(rows, { id = "m:" .. rec.key, kind = "missing", rec = rec, state = state, tags = tags })
      end
    end
  end
  table.sort(rows, function(a, b)
    local la, lb = a.rec.learn or 0, b.rec.learn or 0
    if la ~= lb then return la < lb end
    return a.rec.name < b.rec.name
  end)
  for i = 1, table.getn(rows) do table.insert(out, rows[i]) end
  if total == 0 then
    table.insert(out, infoRow("Nothing missing - every known recipe is learned!"))
  elseif table.getn(rows) == 0 then
    table.insert(out, infoRow("No missing recipes match the filters."))
  end
  self.summary:SetText(total .. " missing, |cff40ff40" .. now .. " learnable now|r")
  CM.status:SetText("")
  return out
end

function M:Render(row, d)
  if renderCommon(row, d) then return end
  local rec = d.rec
  row.icon:SetTexture(rec.icon)
  row.text:SetText((CM.STATE_COLOR[d.state] or "") .. rec.name .. "|r")
  row.text:SetTextColor(1, 1, 1)
  row.right:SetText("|cff999999" .. (rec.learn or "?") .. "|r  " .. d.tags)
end

function M:Click(d, button)
  if d.kind ~= "missing" then return end
  if IsShiftKeyDown() then linkRecipe(CM.view.prof, d.rec.name) return end
  CM:Select(d)
end

function M:Detail(d)
  if not d or d.kind ~= "missing" then
    placeholderDetail("Missing recipes", {
      { text = "Every recipe of this profession you don't know yet, with where to get it." },
      { text = " " },
      { text = "Professional ships with the vanilla recipe list and also records new trainers, vendors and drops as you play, so custom OctoWoW recipes show up once you've seen them (or once an alt knows them)." },
    })
    return
  end
  local rec = d.rec
  local char = CM:ViewChar()
  local skill = CM:ViewSkill() or 0
  local top = {}
  if d.state == "now" then
    table.insert(top, { text = "|cff40ff40You can learn this now.|r" })
  elseif d.state == "blocked" then
    table.insert(top, { text = "|cffff4040Not available yet: " .. (CM:Blockers(rec, char) or "?") .. "|r" })
  else
    table.insert(top, { text = (CM.STATE_COLOR[d.state] or "") .. "Learnable at skill " .. (rec.learn or "?") .. " (you have " .. skill .. ").|r" })
  end
  local lines = CM:RecipeDetail(rec, { char = char, skill = skill, top = top, sourcesFirst = true })
  CM:SetDetail({
    icon = rec.icon,
    title = rec.item and (CM:ItemQualityHex(rec.item) .. rec.name .. "|r") or rec.name,
    sub = CM.view.prof .. "  |cff999999learned at " .. (rec.learn or "?") .. "|r",
    lines = lines,
    iconTooltip = function(owner) if rec.item then CM:ShowItemTooltip(owner, rec.item) end end,
  })
end

------------------------------------------------------------------------
-- SKILL-UP
------------------------------------------------------------------------
local S = {}
CM.Tabs.skillup = S

function S:Init()
  local f = self.filter
  local label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  label:SetPoint("LEFT", f, "LEFT", 10, 0)
  label:SetText("Plan up to")
  self.targetBox = CM:MakeEdit("ProfessionalTargetBox", f, 40, "", function(text, focused)
    if not focused then return end
    local n = tonumber(text)
    if n and n > 0 then S.target = n; CM:RefreshSoon() elseif text == "" then S.target = nil; CM:RefreshSoon() end
  end)
  self.targetBox:SetPoint("LEFT", label, "RIGHT", 8, 0)
  self.vendorCheck = CM:MakeCheck("ProfessionalPlanVendor", f, "Use vendor recipes", function(v) CM.settings.planVendor = v; CM:Refresh(true) end,
    "Let the plan use recipes you can buy from vendors with unlimited stock.")
  self.vendorCheck:SetPoint("LEFT", self.targetBox, "RIGHT", 8, 0)
  self.dropCheck = CM:MakeCheck("ProfessionalPlanDrops", f, "Use drop/quest/rep recipes", function(v) CM.settings.planDrops = v; CM:Refresh(true) end,
    "Also use recipes that come from drops, quests, reputation or limited vendors.")
  self.dropCheck:SetPoint("LEFT", self.vendorCheck.label, "RIGHT", 8, -1)

  local b = self.bottom
  self.queueStep = CM:MakeButton("ProfessionalQueueStep", b, "Queue this step", 120, 22, function()
    local d = CM.list.selected
    if d and d.kind == "step" then
      CM:QueueAdd(CM.view.prof, d.st.rec.name, d.st.crafts)
      CM:Print("queued " .. d.st.crafts .. " x " .. d.st.rec.name .. ".")
      CM:Refresh()
    end
  end)
  self.queueStep:SetPoint("LEFT", b, "LEFT", 4, 0)
  self.queuePlan = CM:MakeButton("ProfessionalQueuePlan", b, "Queue whole plan", 130, 22, function()
    if not S.plan then return end
    local n = 0
    for _, st in ipairs(S.plan.steps) do
      if st.rec then CM:QueueAdd(CM.view.prof, st.rec.name, st.crafts); n = n + 1 end
    end
    CM:Print("queued " .. n .. " plan steps. See the Queue & Shopping tab for the shopping list.")
    CM:Refresh()
  end)
  self.queuePlan:SetPoint("LEFT", self.queueStep, "RIGHT", 4, 0)
  self.hint = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  self.hint:SetPoint("LEFT", self.queuePlan, "RIGHT", 10, 0)
  self.hint:SetText("Craft counts are averages: yellow and green recipes don't always give a point.")
end

function S:DefaultTarget(prof, max)
  local ranks = CM_DATA.ranks[prof]
  if ranks and table.getn(ranks) > 0 then return ranks[table.getn(ranks)].mx end
  return math.max(max or 0, 300)
end

function S:Build()
  local prof = CM.view.prof
  if not prof then return { infoRow("No profession selected.") } end
  local char = CM:ViewChar()
  local skill, max = CM:ViewSkill()
  self.vendorCheck:SetChecked(CM.settings.planVendor and 1 or nil)
  self.dropCheck:SetChecked(CM.settings.planDrops and 1 or nil)
  if not skill then return { infoRow("Learn " .. prof .. " first.") } end
  local target = self.target or self:DefaultTarget(prof, max)
  if not self.targetBox.hasFocus then self.targetBox:SetText(tostring(target)) end
  local out = {}

  -- best known recipes right now
  table.insert(out, headerRow("Best skill-ups you know at " .. skill, "sec:best"))
  local mode, snap = CM:ViewLive()
  local best = {}
  local p = char.profs[prof]
  if p and p.list then
    for i = 1, table.getn(p.list) do
      local name = p.list[i]
      if string.sub(name, 1, 1) ~= "#" then
        local rec = CM:Recipe(prof, name)
        local chance = rec.y and CM:Chance(rec, skill)
        local diff = CM:Difficulty(rec, skill)
        if snap and snap.byKey[rec.key] then diff = snap.byKey[rec.key].diff end
        if not chance then
          chance = (diff == "optimal" and 1) or (diff == "medium" and 0.6) or (diff == "easy" and 0.25) or 0
        end
        if chance > 0 then
          table.insert(best, { id = "b:" .. rec.key, kind = "best", rec = rec, chance = chance, diff = diff })
        end
      end
    end
  end
  table.sort(best, function(a, b)
    if a.chance ~= b.chance then return a.chance > b.chance end
    return (a.rec.learn or 0) > (b.rec.learn or 0)
  end)
  if table.getn(best) == 0 then
    table.insert(out, infoRow(p and p.list and "None of your recipes give skill-ups any more." or "Open the profession window once to see your recipes."))
  end
  for i = 1, math.min(8, table.getn(best)) do table.insert(out, best[i]) end

  -- leveling plan
  if target > skill then
    table.insert(out, headerRow("Leveling plan " .. skill .. " -> " .. target, "sec:plan"))
    local plan = CM:Plan(prof, char, skill, target, { vendor = CM.settings.planVendor, drops = CM.settings.planDrops })
    self.plan = plan
    for i = 1, table.getn(plan.steps) do
      local st = plan.steps[i]
      if st.note then
        table.insert(out, { id = "note:" .. i, kind = "note", text = st.note })
      else
        table.insert(out, { id = "step:" .. st.from .. ":" .. st.rec.key, kind = "step", st = st })
      end
    end
    if plan.stuck then
      table.insert(out, infoRow("|cffff4040No recipe found that gives points at " .. plan.stuck .. ".|r"))
      table.insert(out, infoRow("Try the vendor or drop options above."))
    end
    table.insert(out, { id = "totals", kind = "totals", text = "Plan totals: reagents and costs" })
  else
    self.plan = nil
    table.insert(out, infoRow("Target reached. Raise the target to plan further."))
  end
  CM.status:SetText("")
  return out
end

function S:Render(row, d)
  if renderCommon(row, d) then return end
  if d.kind == "best" then
    local c = CM.DIFF_COLOR[d.diff] or CM.DIFF_COLOR.unknown
    row.icon:SetTexture(d.rec.icon)
    row.text:SetText(d.rec.name)
    row.text:SetTextColor(c.r, c.g, c.b)
    local can = R:Craftable(d.rec, CM:ViewChar())
    row.right:SetText((can > 0 and ("|cff40ff40[" .. can .. "]|r  ") or "") .. math.floor(d.chance * 100 + 0.5) .. "%")
  elseif d.kind == "note" then
    row.text:SetText("|cffffd100>> " .. d.text .. "|r")
  elseif d.kind == "step" then
    local st = d.st
    row.icon:SetTexture(st.rec.icon)
    local tag
    if st.known then tag = "" else
      local tags = CM:SourceTags(st.rec)
      tag = " |cff40c040(learn: " .. tags .. ")|r"
    end
    row.text:SetText("|cff999999" .. st.from .. "-" .. st.to .. "|r  " .. st.rec.name .. tag)
    row.text:SetTextColor(1, 1, 1)
    row.right:SetText("x" .. st.crafts)
  elseif d.kind == "totals" then
    row.text:SetText("|cff33ccff" .. d.text .. "|r")
  end
end

function S:Click(d)
  if d.kind == "best" or d.kind == "step" or d.kind == "totals" then
    if IsShiftKeyDown() and d.kind ~= "totals" then
      linkRecipe(CM.view.prof, (d.rec or d.st.rec).name)
      return
    end
    CM:Select(d)
  end
end

function S:Detail(d)
  local char = CM:ViewChar()
  local skill = CM:ViewSkill() or 0
  if d and (d.kind == "best" or d.kind == "step") then
    local rec = d.rec or d.st.rec
    local top = {}
    local mult = 1
    if d.kind == "step" then
      local st = d.st
      mult = st.crafts
      table.insert(top, { text = "Craft about |cffffffff" .. st.crafts .. "|r to go from " .. st.from .. " to " .. st.to .. "." })
      if st.known then
        table.insert(top, { text = "|cff40ff40You know this recipe.|r" })
      else
        table.insert(top, { text = "|cffffff00Learn it first|r (" .. CM.Money(CM:LearnCost(rec)) .. ") - see How to learn below." })
      end
      table.insert(top, { text = " " })
    end
    local mode = CM:ViewLive()
    local snap = mode and CM.live[mode].snap
    local e = snap and snap.byKey[rec.key]
    local lines = CM:RecipeDetail(rec, { mode = e and mode, index = e and e.index, char = char, skill = skill, top = top, multiplier = mult, noSources = d.kind == "best" })
    CM:SetDetail({
      icon = rec.icon,
      title = rec.item and (CM:ItemQualityHex(rec.item) .. rec.name .. "|r") or rec.name,
      sub = CM.view.prof .. "  |cff999999learned at " .. (rec.learn or "?") .. "|r",
      lines = lines,
      iconTooltip = function(owner) if rec.item then CM:ShowItemTooltip(owner, rec.item) end end,
    })
    return
  end
  -- plan summary
  local lines = {}
  local plan = self.plan
  if plan then
    local crafts, steps = 0, 0
    for _, st in ipairs(plan.steps) do if st.rec then crafts = crafts + st.crafts; steps = steps + 1 end end
    table.insert(lines, { text = "About |cffffffff" .. crafts .. "|r crafts over " .. steps .. " recipes." })
    table.insert(lines, { text = "Training and recipe costs: " .. CM.Money(plan.cost) })
    table.insert(lines, { text = " " })
    table.insert(lines, { text = "|cffffd100Reagents for the whole plan|r" })
    local ids = {}
    for id in pairs(plan.reagents) do table.insert(ids, id) end
    table.sort(ids, function(a, b) return CM:ItemName(a) < CM:ItemName(b) end)
    local isSelf = CM:IsViewingSelf()
    for i = 1, table.getn(ids) do
      table.insert(lines, CM:ReagentLine(ids[i], nil, nil, plan.reagents[ids[i]], char, isSelf))
    end
    table.insert(lines, { text = " " })
    table.insert(lines, { text = "|cff999999The planner picks the recipe with the best skill-up chance at each point, preferring ones you know and ones with fewer reagents. Untick the options above to limit it to trainer recipes.|r" })
  else
    table.insert(lines, { text = "Pick a target skill above to get a leveling plan." })
  end
  placeholderDetail("Skill-up guide", lines)
end

function S:UpdateBottom()
  local d = CM.list.selected
  if d and d.kind == "step" and CM:IsViewingSelf() then self.queueStep:Enable() else self.queueStep:Disable() end
  if self.plan and CM:IsViewingSelf() then self.queuePlan:Enable() else self.queuePlan:Disable() end
end

------------------------------------------------------------------------
-- QUEUE & SHOPPING
------------------------------------------------------------------------
local Q = { useBank = true }
CM.Tabs.shopping = Q

function Q:Init()
  local f = self.filter
  self.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  self.title:SetPoint("LEFT", f, "LEFT", 10, 0)
  self.bankCheck = CM:MakeCheck("ProfessionalUseBank", f, "Count bank items as owned", function(v) Q.useBank = v; CM:Refresh() end,
    "When on, reagents in your bank count toward the shopping list. Professional remembers your bank from the last visit.")
  self.bankCheck:SetPoint("LEFT", self.title, "RIGHT", 16, 0)
  self.bankCheck:SetChecked(1)

  local b = self.bottom
  self.craftNext = CM:MakeButton("ProfessionalCraftNext", b, "Craft next", 100, 22, function() CM:QueueProcess() end)
  self.craftNext:SetPoint("LEFT", b, "LEFT", 4, 0)
  self.remove = CM:MakeButton("ProfessionalQueueRemove", b, "Remove", 80, 22, function()
    local d = CM.list.selected
    if d and d.kind == "queue" then CM:QueueRemove(d.i); CM:Refresh() end
  end)
  self.remove:SetPoint("LEFT", self.craftNext, "RIGHT", 4, 0)
  self.clear = CM:MakeButton("ProfessionalQueueClear", b, "Clear queue", 100, 22, function()
    CM.char.queue = {}
    CM:Refresh()
  end)
  self.clear:SetPoint("LEFT", self.remove, "RIGHT", 4, 0)
  self.hint = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  self.hint:SetPoint("LEFT", self.clear, "RIGHT", 10, 0)
  self.hint:SetText("Right-click a queued recipe to remove it.")
end

function Q:Needs()
  local needs = {}
  for _, q in ipairs(CM.char.queue) do
    local rec = CM:Recipe(q.p, q.n)
    if rec.reagents then
      for j = 1, table.getn(rec.reagents), 2 do
        local id = rec.reagents[j]
        needs[id] = (needs[id] or 0) + (rec.reagents[j + 1] or 1) * q.c
      end
    end
  end
  return needs
end

function Q:Build()
  self.title:SetText("Queue for |cffffffff" .. CM.player .. "|r")
  local out = {}
  local q = CM.char.queue
  table.insert(out, headerRow("Craft queue", "sec:queue"))
  if table.getn(q) == 0 then
    table.insert(out, infoRow("The queue is empty. Use \"Add to queue\" on the Recipes tab,"))
    table.insert(out, infoRow("or queue a leveling plan on the Skill-up tab."))
  end
  for i = 1, table.getn(q) do
    local rec = CM:Recipe(q[i].p, q[i].n)
    table.insert(out, { id = "q:" .. q[i].p .. ":" .. rec.key, kind = "queue", i = i, e = q[i], rec = rec })
  end
  local needs = self:Needs()
  local ids = {}
  for id in pairs(needs) do table.insert(ids, id) end
  if table.getn(ids) > 0 then
    table.insert(out, headerRow("Shopping list", "sec:shop"))
    local rows = {}
    for _, id in ipairs(ids) do
      local bags = CM.char.bags[id] or 0
      local bank = self.useBank and (CM.char.bank[id] or 0) or 0
      local missing = needs[id] - bags - bank
      table.insert(rows, { id = "i:" .. id, kind = "reagent", item = id, need = needs[id], bags = bags, bank = bank, missing = missing })
    end
    table.sort(rows, function(a, b)
      if (a.missing > 0) ~= (b.missing > 0) then return a.missing > 0 end
      return CM:ItemName(a.item) < CM:ItemName(b.item)
    end)
    for i = 1, table.getn(rows) do table.insert(out, rows[i]) end
  end
  CM.status:SetText(table.getn(q) .. " queued")
  return out
end

function Q:Render(row, d)
  if renderCommon(row, d) then return end
  if d.kind == "queue" then
    row.icon:SetTexture(d.rec.icon)
    row.text:SetText(d.e.c .. " x " .. d.e.n)
    local known = CM:CharKnows(CM.char, d.e.p, d.rec.key)
    if known then row.text:SetTextColor(1, 1, 1) else row.text:SetTextColor(1, 0.5, 0.25) end
    row.right:SetText("|cff999999" .. d.e.p .. (known and "" or ", not learned") .. "|r")
  elseif d.kind == "reagent" then
    row.icon:SetTexture(CM:ItemIcon(d.item) or "Interface\\Icons\\INV_Misc_QuestionMark")
    local tag = ""
    if d.missing > 0 then
      if CM:MakersOf(d.item) then tag = " |cff40c040(you can craft)|r"
      elseif CM:ItemSoldByVendor(d.item) then tag = " |cff80c0ff(vendor)|r" end
    end
    row.text:SetText(CM:ItemQualityHex(d.item) .. CM:ItemName(d.item) .. "|r" .. tag)
    row.text:SetTextColor(1, 1, 1)
    local have = d.bags + d.bank
    local color = (d.missing <= 0) and "|cff40ff40" or (have > 0 and "|cffffff00" or "|cffff4040")
    row.right:SetText(color .. have .. "/" .. d.need .. "|r" .. (d.missing > 0 and (" |cffff8080need " .. d.missing .. "|r") or ""))
  end
end

function Q:Click(d, button)
  if d.kind == "queue" then
    if button == "RightButton" then
      CM:QueueRemove(d.i)
      CM:Refresh()
      return
    end
    CM:Select(d)
  elseif d.kind == "reagent" then
    if IsShiftKeyDown() and ChatFrameEditBox and ChatFrameEditBox:IsVisible() then
      local link = CM:ItemChatLink(d.item)
      ChatFrameEditBox:Insert(link or CM:ItemName(d.item))
      return
    end
    CM:Select(d)
  end
end

function Q:Enter(row, d)
  if d.kind == "reagent" then CM:ShowItemTooltip(row, d.item) end
end

function Q:Detail(d)
  if d and d.kind == "queue" then
    local rec = d.rec
    local mode
    for _, m in ipairs({ "trade", "craft" }) do
      if CM.live[m].open and CM.live[m].prof == d.e.p then mode = m end
    end
    local e = mode and CM.live[mode].snap and CM.live[mode].snap.byKey[rec.key]
    local lines = CM:RecipeDetail(rec, { mode = e and mode, index = e and e.index, char = CM.char, skill = CM:CharSkill(CM.char, d.e.p), multiplier = d.e.c, noSources = CM:CharKnows(CM.char, d.e.p, rec.key) })
    CM:SetDetail({
      icon = rec.icon,
      title = d.e.c .. " x " .. rec.name,
      sub = d.e.p,
      lines = lines,
      iconTooltip = function(owner) if rec.item then CM:ShowItemTooltip(owner, rec.item) end end,
    })
    return
  end
  if d and d.kind == "reagent" then
    local id = d.item
    local lines = {}
    local function add(t, x) local e = x or {}; e.text = t; table.insert(lines, e) end
    add("Needed for the queue: |cffffffff" .. d.need .. "|r")
    add("In your bags: " .. d.bags .. "    In your bank: " .. (CM.char.bank[id] or 0))
    if d.missing > 0 then add("|cffff8080Still missing: " .. d.missing .. "|r") else add("|cff40ff40You have enough.|r") end
    local _, _, alts, altList = CM:ItemCounts(id)
    if alts > 0 then
      add(" ")
      add("|cffffd100On your alts|r")
      for _, a in ipairs(altList) do
        add("   " .. a.name .. ": " .. a.bags .. " in bags, " .. a.bank .. " in bank")
      end
    end
    local makers = CM:MakersOf(id)
    if makers then
      add(" ")
      add("|cffffd100You can craft it|r")
      for _, m in ipairs(makers) do
        add("   " .. m.prof .. ": " .. m.name, { onClick = function() CM:QueueAdd(m.prof, m.name, math.max(1, d.missing)); CM:Refresh() end, tip = "Click to queue enough of this" })
      end
    end
    if CM:ItemSoldByVendor(id) then
      add(" ")
      add("|cff80c0ffSold by vendors|r (trade goods or general goods).")
    end
    local uses = CM:ReagentUses(id)
    if uses then
      local list = {}
      for prof, n in pairs(uses) do table.insert(list, prof .. " (" .. n .. ")") end
      table.sort(list)
      add(" ")
      add("|cffffd100Used in|r " .. table.concat(list, ", "))
    end
    CM:SetDetail({
      icon = CM:ItemIcon(id) or "Interface\\Icons\\INV_Misc_QuestionMark",
      title = CM:ItemQualityHex(id) .. CM:ItemName(id) .. "|r",
      sub = "Reagent",
      lines = lines,
      iconTooltip = function(owner) CM:ShowItemTooltip(owner, id) end,
    })
    return
  end
  placeholderDetail("Queue & shopping list", {
    { text = "Queue recipes here, then press \"Craft next\" with the profession window open." },
    { text = " " },
    { text = "The shopping list adds up every reagent the queue needs and compares it with your bags (and bank, if ticked). Click a reagent to see which alts hold it and whether you can craft it yourself." },
  })
end

function Q:UpdateBottom()
  local d = CM.list.selected
  if d and d.kind == "queue" then self.remove:Enable() else self.remove:Disable() end
  if table.getn(CM.char.queue) > 0 then self.clear:Enable(); self.craftNext:Enable() else self.clear:Disable(); self.craftNext:Disable() end
end

------------------------------------------------------------------------
-- ALTS
------------------------------------------------------------------------
local A = { search = "" }
CM.Tabs.alts = A

StaticPopupDialogs["PROFESSIONAL_DELETE_CHAR"] = {
  text = "Forget everything Professional saved about %s?",
  button1 = YES,
  button2 = NO,
  OnAccept = function()
    if CM.pendingDelete and CM.pendingDelete ~= CM.player then
      CM.realmData.chars[CM.pendingDelete] = nil
      CM.pendingDelete = nil
      CM:Refresh(true)
    end
  end,
  timeout = 0,
  whileDead = 1,
  hideOnEscape = 1,
}

function A:Init()
  local f = self.filter
  self.searchBox = CM:MakeEdit("ProfessionalWhoSearch", f, 220, "Who can craft... (type a recipe)", function(text)
    A.search = string.lower(text or "")
    CM:RefreshSoon()
  end)
  self.searchBox:SetPoint("LEFT", f, "LEFT", 8, 0)
  local b = self.bottom
  self.viewBtn = CM:MakeButton("ProfessionalViewAlt", b, "View recipes", 110, 22, function()
    local d = CM.list.selected
    if d and d.kind == "prof" then
      CM.view.char = d.char
      CM.view.prof = d.prof
      CM:SelectTab("recipes")
    end
  end)
  self.viewBtn:SetPoint("LEFT", b, "LEFT", 4, 0)
  self.missing = CM:MakeButton("ProfessionalViewAltMissing", b, "Missing recipes", 120, 22, function()
    local d = CM.list.selected
    if d and d.kind == "prof" then
      CM.view.char = d.char
      CM.view.prof = d.prof
      CM:SelectTab("missing")
    end
  end)
  self.missing:SetPoint("LEFT", self.viewBtn, "RIGHT", 4, 0)
  self.delete = CM:MakeButton("ProfessionalDeleteAlt", b, "Forget character", 130, 22, function()
    local d = CM.list.selected
    local name = d and (d.char or d.name)
    if name and name ~= CM.player then
      CM.pendingDelete = name
      StaticPopup_Show("PROFESSIONAL_DELETE_CHAR", name)
    end
  end)
  self.delete:SetPoint("LEFT", self.missing, "RIGHT", 16, 0)
end

function A:Build()
  local out = {}
  if self.search ~= "" and string.len(self.search) >= 2 then
    local results = {}
    for _, prof in ipairs(CM:AllProfessions()) do
      for _, rec in ipairs(CM:ProfessionRecipes(prof)) do
        if matches(rec.name, self.search) then
          table.insert(results, { id = "w:" .. prof .. ":" .. rec.key, kind = "who", rec = rec, knownBy = CM:KnownBy(prof, rec.key, false, rec.item) })
        end
      end
    end
    table.sort(results, function(a, b)
      local ka, kb = table.getn(a.knownBy) > 0, table.getn(b.knownBy) > 0
      if ka ~= kb then return ka end
      return a.rec.name < b.rec.name
    end)
    for i = 1, math.min(80, table.getn(results)) do table.insert(out, results[i]) end
    if table.getn(out) == 0 then table.insert(out, infoRow("No recipe matches \"" .. self.search .. "\".")) end
    CM.status:SetText(table.getn(results) .. " recipes found")
    return out
  end
  for _, c in ipairs(CM:Chars(false)) do
    table.insert(out, { id = "c:" .. c.name, kind = "char", name = c.name, data = c.data })
    local profs = {}
    for prof, s in pairs(c.data.skills or {}) do profs[prof] = true end
    for prof in pairs(c.data.profs or {}) do profs[prof] = true end
    local list = {}
    for prof in pairs(profs) do table.insert(list, prof) end
    table.sort(list)
    for _, prof in ipairs(list) do
      local rank, max = CM:CharSkill(c.data, prof)
      local p = c.data.profs[prof]
      table.insert(out, { id = "p:" .. c.name .. ":" .. prof, kind = "prof", char = c.name, prof = prof, rank = rank, max = max, count = p and p.known and CM.Count(p.known), indent = 10 })
    end
  end
  CM.status:SetText(table.getn(CM:Chars(false)) .. " characters on " .. CM.realm)
  return out
end

function A:Render(row, d)
  if renderCommon(row, d) then return end
  if d.kind == "char" then
    local cc = RAID_CLASS_COLORS and RAID_CLASS_COLORS[d.data.class or ""]
    row.text:SetText((cc and CM.Hex(cc) or "|cffffffff") .. d.name .. "|r  |cff999999level " .. (d.data.level or "?") .. "|r")
    local fac = d.data.faction == "Horde" and "|cffff4040Horde|r" or "|cff4080ffAlliance|r"
    row.right:SetText(fac)
  elseif d.kind == "prof" then
    row.icon:SetTexture(CM:ProfIcon(d.prof))
    row.text:SetText(d.prof)
    row.text:SetTextColor(1, 1, 1)
    local r = (d.rank and d.max) and (d.rank .. "/" .. d.max) or ""
    if d.count then r = r .. "  |cff999999" .. d.count .. " recipes|r" end
    row.right:SetText(r)
  elseif d.kind == "who" then
    row.icon:SetTexture(d.rec.icon)
    row.text:SetText(d.rec.name)
    if table.getn(d.knownBy) > 0 then row.text:SetTextColor(0.25, 1, 0.25) else row.text:SetTextColor(0.6, 0.6, 0.6) end
    row.right:SetText(table.getn(d.knownBy) > 0 and table.concat(d.knownBy, ", ") or ("|cff999999" .. d.rec.prof .. "|r"))
  end
end

function A:Click(d, button)
  if d.kind == "who" and IsShiftKeyDown() then linkRecipe(d.rec.prof, d.rec.name) return end
  CM:Select(d)
end

function A:Detail(d)
  if d and d.kind == "char" then
    local c = d.data
    local lines = {}
    local function add(t) table.insert(lines, { text = t }) end
    add("Level " .. (c.level or "?") .. " " .. (c.class and string.sub(c.class, 1, 1) .. string.lower(string.sub(c.class, 2)) or "") .. ", " .. (c.faction or "?"))
    if c.seen then add("Last logged in: " .. date("%Y-%m-%d %H:%M", c.seen)) end
    add("Bank saved: " .. (c.bankTime and date("%Y-%m-%d", c.bankTime) or "|cffff8080never - visit a bank once|r"))
    add(" ")
    add("|cffffd100Professions|r")
    for prof, s in pairs(c.skills or {}) do
      local p = c.profs and c.profs[prof]
      add("   " .. prof .. "  " .. (s.rank or "?") .. "/" .. (s.max or "?") .. ((p and p.known) and ("  |cff999999" .. CM.Count(p.known) .. " recipes|r") or ""))
    end
    local specs = {}
    for name in pairs(c.specs or {}) do table.insert(specs, name) end
    if table.getn(specs) > 0 then add("Specializations: " .. table.concat(specs, ", ")) end
    if c.queue and table.getn(c.queue) > 0 then add("Craft queue: " .. table.getn(c.queue) .. " recipes") end
    placeholderDetail(d.name, lines)
    return
  end
  if d and d.kind == "prof" then
    local c = CM.realmData.chars[d.char]
    local lines = {}
    local function add(t) table.insert(lines, { text = t }) end
    add(d.char .. "'s " .. d.prof .. ": " .. ((d.rank and d.max) and (d.rank .. "/" .. d.max) or "?"))
    if CM:IsCraftProfession(d.prof) then
      local missing, now = 0, 0
      for _, rec in ipairs(CM:ProfessionRecipes(d.prof)) do
        if not CM:CharKnows(c, d.prof, rec.key, rec.item) and CM:RecipeFactionOK(rec) then
          missing = missing + 1
          if CM:LearnState(rec, c, d.rank or 0) == "now" then now = now + 1 end
        end
      end
      add("Known recipes: " .. (d.count or "|cffff8080not scanned yet - open the window on that character|r"))
      add("Missing: " .. missing .. " (|cff40ff40" .. now .. " learnable now|r)")
      add(" ")
      add("Use the buttons below to browse this character's recipes or missing recipes.")
    else
      add("Gathering skill - no recipes.")
    end
    CM:SetDetail({ icon = CM:ProfIcon(d.prof), title = d.prof, sub = d.char, lines = lines })
    return
  end
  if d and d.kind == "who" then
    local rec = d.rec
    local top = {}
    if table.getn(d.knownBy) > 0 then
      table.insert(top, { text = "|cff40ff40Known by:|r " .. table.concat(d.knownBy, ", ") })
    else
      table.insert(top, { text = "|cff999999None of your characters know this recipe.|r" })
    end
    local lines = CM:RecipeDetail(rec, { char = CM.char, top = top })
    CM:SetDetail({
      icon = rec.icon,
      title = rec.item and (CM:ItemQualityHex(rec.item) .. rec.name .. "|r") or rec.name,
      sub = rec.prof .. "  |cff999999learned at " .. (rec.learn or "?") .. "|r",
      lines = lines,
      iconTooltip = function(owner) if rec.item then CM:ShowItemTooltip(owner, rec.item) end end,
    })
    return
  end
  CM:SetDetail({ icon = "Interface\\Icons\\INV_Misc_GroupNeedMore", title = "Your characters", lines = {
    { text = "Every character you log in with is saved here: professions, known recipes, bags and bank." },
    { text = " " },
    { text = "Type in the box above to find which of your characters can craft something." },
    { text = "Select a profession and press \"View recipes\" to browse an alt's recipe list." },
  } })
end

function A:UpdateBottom()
  local d = CM.list.selected
  local isProf = d and d.kind == "prof" and CM:IsCraftProfession(d.prof)
  if isProf then self.viewBtn:Enable(); self.missing:Enable() else self.viewBtn:Disable(); self.missing:Disable() end
  local name = d and (d.char or d.name)
  if name and name ~= CM.player and (d.kind == "char" or d.kind == "prof") then self.delete:Enable() else self.delete:Disable() end
end

------------------------------------------------------------------------
-- OPTIONS
------------------------------------------------------------------------
local O = {}
CM.Tabs.options = O

local OPTION_INFO = {
  tooltip = { "Show Professional info in tooltips", "Master switch for everything Professional adds to item tooltips." },
  tooltipKnownOnly = { "Only list recipes this character knows", "When on, reagent tooltips only list recipes you can already craft. When off, recipes you haven't learned are listed too, in grey with the skill they're learned at." },
  tooltipOthers = { "Name the hidden professions in one line", "Adds a single grey \"Also used in: ...\" line for professions you've hidden, instead of nothing." },
  tooltipAlts = { "Show how many of a reagent each alt has", "Lists your other characters that hold the item, with bank counts." },
  replaceWindow = { "Replace the default profession windows", "When off, the normal Blizzard windows open and Professional only opens with /prof." },
}
local MAX_STEPS = { 5, 10, 20, 50 }

function O:Init()
  local f = self.filter
  local t = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  t:SetPoint("LEFT", f, "LEFT", 10, 0)
  t:SetText("Click a line to change it.")
  local b = self.bottom
  self.reset = CM:MakeButton("ProfessionalOptionsReset", b, "Reset to my professions", 170, 22, function()
    CM.settings.tooltipProfs = {}
    CM:Refresh()
  end)
  self.reset:SetPoint("LEFT", b, "LEFT", 4, 0)
  self.allOn = CM:MakeButton("ProfessionalOptionsAll", b, "Show all", 90, 22, function()
    for _, p in ipairs(CM:AllProfessions()) do CM.settings.tooltipProfs[p] = true end
    CM:Refresh()
  end)
  self.allOn:SetPoint("LEFT", self.reset, "RIGHT", 4, 0)
  self.allOff = CM:MakeButton("ProfessionalOptionsNone", b, "Hide all", 90, 22, function()
    for _, p in ipairs(CM:AllProfessions()) do CM.settings.tooltipProfs[p] = false end
    CM:Refresh()
  end)
  self.allOff:SetPoint("LEFT", self.allOn, "RIGHT", 4, 0)
end

function O:Build()
  local out = {}
  table.insert(out, headerRow("Reagent tooltips: list recipes from these professions", "sec:profs"))
  for _, p in ipairs(CM:AllProfessions()) do
    if CM:IsCraftProfession(p) then
      table.insert(out, { id = "p:" .. p, kind = "prof", prof = p })
    end
  end
  table.insert(out, headerRow("Tooltip options", "sec:tip"))
  for _, k in ipairs({ "tooltip", "tooltipKnownOnly", "tooltipOthers", "tooltipAlts" }) do
    table.insert(out, { id = "o:" .. k, kind = "opt", key = k })
  end
  table.insert(out, { id = "o:max", kind = "max" })
  table.insert(out, headerRow("Window", "sec:win"))
  table.insert(out, { id = "o:replaceWindow", kind = "opt", key = "replaceWindow" })
  CM.status:SetText("")
  return out
end

local function onOff(v)
  return v and "|cff40ff40On|r" or "|cff808080Off|r"
end

function O:Render(row, d)
  if renderCommon(row, d) then return end
  if d.kind == "prof" then
    row.icon:SetTexture(CM:ProfIcon(d.prof))
    local on = CM:TooltipProfEnabled(d.prof)
    row.text:SetText(d.prof)
    if on then row.text:SetTextColor(1, 1, 1) else row.text:SetTextColor(0.5, 0.5, 0.5) end
    local auto = CM.settings.tooltipProfs[d.prof] == nil
    row.right:SetText((on and "|cff40ff40Shown|r" or "|cff808080Hidden|r") .. (auto and " |cff666666(auto)|r" or ""))
  elseif d.kind == "opt" then
    row.text:SetText(OPTION_INFO[d.key][1])
    row.text:SetTextColor(1, 1, 1)
    row.right:SetText(onOff(CM.settings[d.key]))
  elseif d.kind == "max" then
    row.text:SetText("Recipes listed per profession")
    row.text:SetTextColor(1, 1, 1)
    row.right:SetText("|cffffffff" .. (CM.settings.tooltipMax or 10) .. "|r")
  end
end

function O:Click(d)
  if d.kind == "prof" then
    CM.settings.tooltipProfs[d.prof] = not CM:TooltipProfEnabled(d.prof)
  elseif d.kind == "opt" then
    CM.settings[d.key] = not CM.settings[d.key]
    if d.key == "replaceWindow" then CM:ApplyWindowReplacement() end
  elseif d.kind == "max" then
    local cur = CM.settings.tooltipMax or 10
    local nxt = MAX_STEPS[1]
    for i = 1, table.getn(MAX_STEPS) do
      if MAX_STEPS[i] == cur then nxt = MAX_STEPS[i + 1] or MAX_STEPS[1] end
    end
    CM.settings.tooltipMax = nxt
  else
    return
  end
  CM:Select(d)
  CM.list:Update()
end

function O:Detail(d)
  local lines = {}
  local function add(t) table.insert(lines, { text = t }) end
  local title = "Options"
  if d and d.kind == "prof" then
    title = d.prof
    local on = CM:TooltipProfEnabled(d.prof)
    add(on and "|cff40ff40Shown in reagent tooltips.|r" or "|cff808080Hidden from reagent tooltips.|r")
    if CM.settings.tooltipProfs[d.prof] == nil then
      add("Not set yet, so it follows whether this character has " .. d.prof .. ".")
    end
    add(" ")
    add("When you hover a reagent, the tooltip lists the " .. d.prof .. " recipes that use it: recipes you know first, coloured by difficulty, with how many you can make from your bags in green brackets and how many of the reagent each one needs.")
  elseif d and (d.kind == "opt") then
    title = OPTION_INFO[d.key][1]
    add(OPTION_INFO[d.key][2])
  elseif d and d.kind == "max" then
    title = "Recipes per profession"
    add("How many recipes each profession lists in a tooltip before it says \"...and N more\". Click to cycle 5, 10, 20, 50.")
  else
    add("Choose which professions list their recipes in reagent tooltips.")
    add(" ")
    add("Professions you haven't set follow this character: a blacksmith sees Blacksmithing recipes by default, and nothing from professions they don't have.")
    add(" ")
    add("These settings are shared by all your characters, except that \"(auto)\" professions follow whichever character you're on.")
  end
  CM:SetDetail({ icon = "Interface\\Icons\\INV_Misc_Gear_01", title = title, lines = lines })
end
