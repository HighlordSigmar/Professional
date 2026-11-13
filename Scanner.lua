-- Professional: reading the profession windows, skills, bags and bank,
-- and recording recipe sources at trainers, vendors and loot.

local CM = Professional

------------------------------------------------------------------------
-- One interface over the two profession window APIs (TradeSkill and Craft)
------------------------------------------------------------------------
local function packTools(...)
  local names = {}
  for i = 1, arg.n do
    if type(arg[i]) == "string" and arg[i] ~= "" then table.insert(names, arg[i]) end
  end
  return names
end

CM.API = {
  trade = {
    line = function() return GetTradeSkillLine() end,
    num = function() return GetNumTradeSkills() or 0 end,
    info = function(i) local n, t, a, e = GetTradeSkillInfo(i); return n, t, a, e end,
    icon = function(i) return GetTradeSkillIcon(i) end,
    link = function(i) return GetTradeSkillItemLink(i) end,
    made = function(i) return GetTradeSkillNumMade(i) end,
    numReagents = function(i) return GetTradeSkillNumReagents(i) or 0 end,
    reagent = function(i, j) return GetTradeSkillReagentInfo(i, j) end,
    reagentLink = function(i, j) return GetTradeSkillReagentItemLink(i, j) end,
    tools = function(i) return packTools(GetTradeSkillTools(i)) end,
    cooldown = function(i) return GetTradeSkillCooldown(i) end,
    desc = function(i) if GetTradeSkillDescription then return GetTradeSkillDescription(i) end end,
    select = function(i) SelectTradeSkill(i) end,
    expandAll = function() ExpandTradeSkillSubClass(0) end,
    make = function(i, n) SelectTradeSkill(i); DoTradeSkill(i, n) end,
    close = function() CloseTradeSkill() end,
    tooltip = function(tip, i, j) tip:SetTradeSkillItem(i, j) end,
  },
  craft = {
    line = function() return GetCraftDisplaySkillLine() end,
    num = function() return GetNumCrafts() or 0 end,
    info = function(i) local n, _, t, a, e = GetCraftInfo(i); return n, t, a, e end,
    icon = function(i) return GetCraftIcon(i) end,
    link = function(i) return GetCraftItemLink(i) end,
    made = function(i) return 1, 1 end,
    numReagents = function(i) return GetCraftNumReagents(i) or 0 end,
    reagent = function(i, j) return GetCraftReagentInfo(i, j) end,
    reagentLink = function(i, j) return GetCraftReagentItemLink(i, j) end,
    tools = function(i) return packTools(GetCraftSpellFocus(i)) end,
    cooldown = function(i) return nil end,
    desc = function(i) if GetCraftDescription then return GetCraftDescription(i) end end,
    select = function(i) SelectCraft(i) end,
    expandAll = function() ExpandCraftSkillLine(0) end,
    make = function(i, n) SelectCraft(i); DoCraft(i) end,
    close = function() CloseCraft() end,
    tooltip = function(tip, i, j)
      if j then tip:SetCraftItem(i, j) else
        local link = GetCraftItemLink(i)
        if link and string.find(link, "item:", 1, true) then tip:SetCraftItem(i) else tip:SetCraftSpell(i) end
      end
    end,
  },
}

CM.live = { trade = {}, craft = {} }
CM.detailed = {}

------------------------------------------------------------------------
-- Scan an open profession window
------------------------------------------------------------------------
function CM:ScanLive(mode)
  local api = self.API[mode]
  local L = self.live[mode]
  if not L.open then return nil end
  local prof, rank, max = api.line()
  if not prof or prof == "" or prof == "UNKNOWN" then return nil end

  -- make sure every header is expanded so all recipes are visible
  local n = api.num()
  for i = 1, n do
    local _, t, _, expanded = api.info(i)
    if t == "header" and not expanded then
      api.expandAll()
      n = api.num()
      break
    end
  end

  local p = self.char.profs[prof]
  if not p then p = {}; self.char.profs[prof] = p end
  p.rank, p.max, p.mode, p.t = rank, max, mode, time()
  p.known, p.list, p.items = {}, {}, {}
  self.db.cache[prof] = self.db.cache[prof] or {}
  local cache = self.db.cache[prof]
  self.detailed[prof] = self.detailed[prof] or {}
  local detailed = self.detailed[prof]

  local snap = { mode = mode, prof = prof, rank = rank, max = max, entries = {}, byKey = {} }
  local header
  for i = 1, n do
    local name, t, avail = api.info(i)
    if name then
      if t == "header" then
        header = name
        table.insert(snap.entries, { kind = "header", name = name })
        table.insert(p.list, "#" .. name)
      else
        local key = CM.Key(name)
        local e = { kind = "recipe", name = name, key = key, diff = t, avail = avail or 0, index = i, header = header }
        table.insert(snap.entries, e)
        snap.byKey[key] = e
        p.known[key] = 1
        table.insert(p.list, name)
        if not detailed[key] or not cache[key] then
          detailed[key] = true
          self:CacheRecipe(api, prof, i, name, header)
        end
        if cache[key] and cache[key].i then p.items[cache[key].i] = 1 end
      end
    end
  end
  L.snap = snap
  L.prof = prof
  self.makers = nil
  return snap
end

function CM:CacheRecipe(api, prof, i, name, header)
  local key = CM.Key(name)
  local c = self.db.cache[prof][key] or {}
  self.db.cache[prof][key] = c
  c.n = name
  c.hd = header
  local link = api.link(i)
  c.i = CM.ItemId(link)
  c.ic = api.icon(i)
  local mn, mx = api.made(i)
  if mn and mx and (mn > 1 or mx > 1) then c.mn, c.mx = mn, mx else c.mn, c.mx = nil, nil end
  local rg = {}
  for j = 1, api.numReagents(i) do
    local rname, rtex, count = api.reagent(i, j)
    local rid = CM.ItemId(api.reagentLink(i, j))
    if rid then
      table.insert(rg, rid)
      table.insert(rg, count or 1)
      if rname then self.db.itemNames[rid] = rname end
      if rtex then self.db.icons[rid] = rtex end
    end
  end
  c.rg = rg
  local tools = api.tools(i)
  c.tl = (table.getn(tools) > 0) and table.concat(tools, ", ") or nil
  if c.i and c.ic then self.db.icons[c.i] = c.ic end
  self.reagentIndex = nil
end

------------------------------------------------------------------------
-- Skills, specializations, inventory
------------------------------------------------------------------------
local PROF_HEADERS = { ["Professions"] = true, ["Secondary Skills"] = true }

function CM:ScanSkills()
  if not self.char then return end
  -- temporarily expand collapsed profession headers in the skill list
  local reCollapse = {}
  local i = 1
  while i <= GetNumSkillLines() do
    local name, isHeader, isExpanded = GetSkillLineInfo(i)
    if isHeader and PROF_HEADERS[name] and not isExpanded then
      ExpandSkillHeader(i)
      table.insert(reCollapse, name)
    end
    i = i + 1
  end
  local skills = {}
  local current
  for j = 1, GetNumSkillLines() do
    local name, isHeader, _, rank, _, _, max = GetSkillLineInfo(j)
    if isHeader then
      current = name
    elseif name and ((current and PROF_HEADERS[current]) or name == "Poisons") then
      skills[name] = { rank = rank, max = max }
      local p = self.char.profs[name]
      if p then p.rank, p.max = rank, max end
    end
  end
  if next(skills) then
    self.char.skills = skills
    -- forget professions this character no longer has
    for prof in pairs(self.char.profs) do
      if not skills[prof] and prof ~= "Poisons" then self.char.profs[prof] = nil end
    end
  end
  for k = 1, table.getn(reCollapse) do
    for j = 1, GetNumSkillLines() do
      local name, isHeader = GetSkillLineInfo(j)
      if isHeader and name == reCollapse[k] then CollapseSkillHeader(j); break end
    end
  end
end

function CM:ScanSpellbook()
  if not self.char then return end
  local specNames = {}
  for _, list in pairs(CM_DATA.recipes) do
    for i = 1, table.getn(list) do
      if list[i].sp then specNames[list[i].sp] = true end
    end
  end
  local specs = {}
  self.db.profIcons = self.db.profIcons or {}
  local i = 1
  while true do
    local name = GetSpellName(i, "spell")
    if not name then break end
    if specNames[name] then specs[name] = true end
    if CM.PROF_ICONS[name] or name == "Smelting" or (self.char.skills and self.char.skills[name]) then
      local key = (name == "Smelting") and "Mining" or name
      self.db.profIcons[key] = GetSpellTexture(i, "spell")
    end
    i = i + 1
  end
  self.char.specs = specs
end

function CM:ProfIcon(prof)
  return (self.db.profIcons and self.db.profIcons[prof]) or CM.PROF_ICONS[prof] or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function scanContainers(first, last, extra)
  local t = {}
  local bags = {}
  if extra then table.insert(bags, extra) end
  for b = first, last do table.insert(bags, b) end
  for k = 1, table.getn(bags) do
    local bag = bags[k]
    local slots = GetContainerNumSlots(bag) or 0
    for slot = 1, slots do
      local link = GetContainerItemLink(bag, slot)
      local id = CM.ItemId(link)
      if id then
        local _, count = GetContainerItemInfo(bag, slot)
        t[id] = (t[id] or 0) + (count or 1)
      end
    end
  end
  return t
end

function CM:ScanBags()
  if not self.char then return end
  self.char.bags = scanContainers(0, 4)
end

function CM:ScanBank()
  if not self.char or not self.bankOpen then return end
  self.char.bank = scanContainers(5, 10, -1)
  self.char.bankTime = time()
end

------------------------------------------------------------------------
-- Recording recipe sources while playing (learn-as-you-go)
------------------------------------------------------------------------
function CM:ScanTip()
  if not self.scanTip then
    self.scanTip = CreateFrame("GameTooltip", "ProfessionalScanTip", nil, "GameTooltipTemplate")
  end
  local tip = self.scanTip
  tip:SetOwner(WorldFrame, "ANCHOR_NONE")
  tip:ClearLines()
  return tip
end

function CM:TipLines(tip)
  local lines = {}
  for i = 1, tip:NumLines() do
    local fs = getglobal("ProfessionalScanTipTextLeft" .. i)
    if fs then table.insert(lines, fs:GetText() or "") end
  end
  return lines
end

-- Find "Requires Alchemy (125)" in a recipe item's tooltip
function CM:RecipeRequirement(lines)
  for i = 1, table.getn(lines) do
    local _, _, skill, lvl = string.find(lines[i], "^Requires (.+) %((%d+)%)$")
    if skill and not string.find(skill, "^Level") then return skill, tonumber(lvl) end
  end
  return nil
end

function CM:PlayerPos()
  if WorldMapFrame and WorldMapFrame:IsVisible() then return 0, 0 end
  SetMapToCurrentZone()
  local x, y = GetPlayerMapPosition("player")
  return math.floor((x or 0) * 1000) / 10, math.floor((y or 0) * 1000) / 10
end

function CM:Record(prof, recipeName, src, level, itemId)
  if not prof or not recipeName then return end
  local key = CM.Key(recipeName)
  self.db.learned[prof] = self.db.learned[prof] or {}
  local e = self.db.learned[prof][key]
  if not e then
    e = { n = recipeName, src = {} }
    self.db.learned[prof][key] = e
  end
  if level and level > 0 then e.l = level end
  if itemId then e.ri = itemId end
  if not src then return end
  for i = 1, table.getn(e.src) do
    local s = e.src[i]
    if s.t == src.t and s.n == src.n then
      e.src[i] = src
      return
    end
  end
  if table.getn(e.src) < 10 then table.insert(e.src, src) end
end

local function dbHasNpcNamed(ids, name)
  if not ids or not name then return false end
  for i = 1, table.getn(ids) do
    local n = CM:NPC(ids[i])
    if n and n.name == name then return true end
  end
  return false
end

function CM:ScanTrainer()
  if not self.char then return end
  local npc = UnitName("npc")
  if not npc then return end
  local zone = GetRealZoneText()
  local x, y = self:PlayerPos()
  local filters = { "available", "unavailable", "used" }
  local saved = {}
  for i = 1, 3 do
    saved[i] = GetTrainerServiceTypeFilter(filters[i])
    if not saved[i] then SetTrainerServiceTypeFilter(filters[i], 1) end
  end
  for i = 1, GetNumTrainerServices() do
    local name, sub, kind = GetTrainerServiceInfo(i)
    if name and kind ~= "header" then
      local skill, level = GetTrainerServiceSkillReq(i)
      local isRank = sub and (string.find(sub, "Apprentice") or string.find(sub, "Journeyman") or string.find(sub, "Expert") or string.find(sub, "Artisan") or string.find(sub, "Master"))
      if skill and skill ~= "" and not CM.GATHERING[skill] and name ~= skill and not isRank then
        local cost = GetTrainerServiceCost(i)
        local db = self:DBRecipe(skill, name)
        if not db or not dbHasNpcNamed(db.tr, npc) then
          self:Record(skill, name, { t = "T", n = npc, z = zone, x = x, y = y, p = cost, f = self.factionCode }, level)
        end
      end
    end
  end
  for i = 1, 3 do
    if not saved[i] then SetTrainerServiceTypeFilter(filters[i], 0) end
  end
end

function CM:ScanMerchant()
  if not self.char then return end
  local npc = UnitName("npc")
  if not npc then return end
  local zone = GetRealZoneText()
  local x, y = self:PlayerPos()
  for i = 1, GetMerchantNumItems() do
    local name, _, price, _, numAvailable = GetMerchantItemInfo(i)
    local taught = self:IsRecipeItemName(name)
    if taught then
      local id = CM.ItemId(GetMerchantItemLink(i))
      local tip = self:ScanTip()
      tip:SetMerchantItem(i)
      local prof, level = self:RecipeRequirement(self:TipLines(tip))
      if prof and id then
        self.db.itemNames[id] = name
        local item = CM_DATA.recipeItems[id]
        local known = false
        if item and item.v then
          local ids = {}
          for n in pairs(item.v) do table.insert(ids, n) end
          known = dbHasNpcNamed(ids, npc)
        end
        if not known then
          local db = self:Index().byRecipeItem[id]
          self:Record(prof, db and db.n or taught, { t = "V", n = npc, z = zone, x = x, y = y, p = price, lim = (numAvailable and numAvailable >= 0) and 1 or nil, f = self.factionCode }, level, id)
        end
      end
    end
  end
end

function CM:ScanLoot()
  if not self.char then return end
  local zone = GetRealZoneText()
  local mob
  if UnitExists("target") and UnitIsDead("target") then mob = UnitName("target") end
  for slot = 1, GetNumLootItems() do
    local _, name = GetLootSlotInfo(slot)
    local taught = self:IsRecipeItemName(name)
    if taught then
      local id = CM.ItemId(GetLootSlotLink(slot))
      if id and not CM_DATA.recipeItems[id] then
        local tip = self:ScanTip()
        tip:SetLootItem(slot)
        local prof, level = self:RecipeRequirement(self:TipLines(tip))
        if prof then
          self.db.itemNames[id] = name
          self:Record(prof, taught, { t = "D", n = mob or "Container", z = zone }, level, id)
        end
      end
    end
  end
end

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------
CM:On("BAG_UPDATE", function()
  CM:Schedule("bags", 0.4, function()
    CM:ScanBags()
    if CM.bankOpen then CM:ScanBank() end
    if CM.OnInventoryChanged then CM:OnInventoryChanged() end
  end)
end)

CM:On("BANKFRAME_OPENED", function()
  CM.bankOpen = true
  CM:ScanBank()
end)
CM:On("PLAYERBANKSLOTS_CHANGED", function()
  CM:Schedule("bank", 0.4, function() CM:ScanBank(); if CM.OnInventoryChanged then CM:OnInventoryChanged() end end)
end)
CM:On("BANKFRAME_CLOSED", function()
  if CM.bankOpen then CM:ScanBank() end
  CM.bankOpen = false
end)

CM:On("SKILL_LINES_CHANGED", function()
  if CM.ready then CM:Schedule("skills", 0.5, function() CM:ScanSkills() end) end
end)
CM:On("LEARNED_SPELL_IN_TAB", function()
  if CM.ready then CM:Schedule("spells", 0.5, function() CM:ScanSpellbook() end) end
end)
CM:On("PLAYER_LEVEL_UP", function(ev, level)
  if CM.char then CM.char.level = level end
end)

CM:On("TRAINER_SHOW", function()
  CM:Schedule("trainer", 0.3, function() CM:ScanTrainer() end)
end)
CM:On("MERCHANT_SHOW", function()
  CM:Schedule("merchant", 0.5, function() CM:ScanMerchant() end)
end)
CM:On("LOOT_OPENED", function()
  CM:ScanLoot()
end)

------------------------------------------------------------------------
-- Craft queue
------------------------------------------------------------------------
function CM:QueueAdd(prof, name, count)
  if not self.char or not prof or not name then return end
  count = math.max(1, math.floor(count or 1))
  local q = self.char.queue
  for i = 1, table.getn(q) do
    if q[i].p == prof and CM.Key(q[i].n) == CM.Key(name) then
      q[i].c = q[i].c + count
      return
    end
  end
  table.insert(q, { p = prof, n = name, c = count })
end

function CM:QueueRemove(i)
  if self.char.queue[i] then table.remove(self.char.queue, i) end
end

-- Craft the first queue entry that the open window can make
function CM:QueueProcess()
  local q = self.char.queue
  for _, mode in ipairs({ "trade", "craft" }) do
    local L = self.live[mode]
    if L.open and L.snap then
      for i = 1, table.getn(q) do
        local e = L.snap.byKey[CM.Key(q[i].n)]
        if e and q[i].p == L.prof then
          if e.avail <= 0 then
            self:Print("not enough reagents for " .. q[i].n .. ".")
            return
          end
          local count = math.min(q[i].c, e.avail)
          self.queueCasting = { name = q[i].n, prof = q[i].p }
          self.API[mode].make(e.index, count)
          return
        end
      end
    end
  end
  self:Print("open the profession window for the next queued item first.")
end

CM:On("SPELLCAST_START", function(ev, spell)
  local qc = CM.queueCasting
  if qc and spell and CM.Key(spell) == CM.Key(qc.name) then
    qc.casting = true
  end
end)
CM:On("SPELLCAST_STOP", function()
  local qc = CM.queueCasting
  if qc and qc.casting then
    qc.casting = false
    local q = CM.char.queue
    for i = 1, table.getn(q) do
      if q[i].p == qc.prof and CM.Key(q[i].n) == CM.Key(qc.name) then
        q[i].c = q[i].c - 1
        if q[i].c <= 0 then
          table.remove(q, i)
          CM.queueCasting = nil
        end
        break
      end
    end
    if CM.OnQueueChanged then CM:OnQueueChanged() end
  end
end)
local function castFailed()
  if CM.queueCasting then CM.queueCasting.casting = false end
end
CM:On("SPELLCAST_FAILED", castFailed)
CM:On("SPELLCAST_INTERRUPTED", castFailed)
