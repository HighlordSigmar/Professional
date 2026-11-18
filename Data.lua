-- Professional: data access, recipe merging, sources, skill-up math and leveling plans.

local CM = Professional

local REP_LEVELS = { [3] = "Unfriendly", [4] = "Neutral", [5] = "Friendly", [6] = "Honored", [7] = "Revered", [8] = "Exalted" }
local CLASS_NAMES = { ROGUE = "Rogue", WARRIOR = "Warrior", MAGE = "Mage", PRIEST = "Priest", WARLOCK = "Warlock", HUNTER = "Hunter", DRUID = "Druid", SHAMAN = "Shaman", PALADIN = "Paladin" }
local RECIPE_PREFIXES = { "Recipe: ", "Pattern: ", "Plans: ", "Schematic: ", "Formula: ", "Manual: ", "Design: ", "Book: " }
CM.RECIPE_PREFIXES = RECIPE_PREFIXES

------------------------------------------------------------------------
-- Profession ranks taught by trainers ("Journeyman Blacksmith", "Expert Cook") are not recipes
------------------------------------------------------------------------
local RANK_WORDS = { "Apprentice", "Journeyman", "Expert", "Artisan", "Master", "Grand Master" }
function CM.IsRankName(name)
  if not name then return false end
  for i = 1, table.getn(RANK_WORDS) do
    local w = RANK_WORDS[i]
    if name == w then return true end
    if string.sub(name, 1, string.len(w) + 1) == w .. " " then
      -- "Journeyman Blacksmith", "Expert First Aid", but not "Master Engineer's Goggles"
      local rest = string.sub(name, string.len(w) + 2)
      local words = 0
      for _ in string.gfind(rest, "%S+") do words = words + 1 end
      if words <= 2 and not string.find(rest, "'", 1, true) then return true end
    end
  end
  return false
end

-- Remove rank entries that older versions recorded at trainers as if they were recipes
function CM:CleanLearned()
  for prof, list in pairs(self.db.learned) do
    for key, e in pairs(list) do
      if CM.IsRankName(e.n) then list[key] = nil end
    end
  end
end

------------------------------------------------------------------------
-- Built-in data indexes
------------------------------------------------------------------------
function CM:Index()
  if self.idx then return self.idx end
  local idx = { byName = {}, byRecipeItem = {}, byCreated = {} }
  for prof, list in pairs(CM_DATA.recipes) do
    local names = {}
    idx.byName[prof] = names
    for i = 1, table.getn(list) do
      local r = list[i]
      r.prof = prof
      names[CM.Key(r.n)] = r
      if r.ri then
        for j = 1, table.getn(r.ri) do idx.byRecipeItem[r.ri[j]] = r end
      end
      if r.i then
        if not idx.byCreated[r.i] then idx.byCreated[r.i] = {} end
        table.insert(idx.byCreated[r.i], r)
      end
    end
  end
  self.idx = idx
  return idx
end

function CM:DBRecipe(prof, name)
  local names = self:Index().byName[prof]
  return names and names[CM.Key(name)]
end

-- Every profession we know anything about (built-in, recorded, or the characters')
function CM:AllProfessions()
  local set = {}
  for prof in pairs(CM_DATA.recipes) do set[prof] = true end
  for prof in pairs(self.db.cache) do set[prof] = true end
  for prof in pairs(self.db.learned) do set[prof] = true end
  local out = {}
  for prof in pairs(set) do table.insert(out, prof) end
  table.sort(out)
  return out
end

-- Is this a recipe-window profession?
function CM:IsCraftProfession(name)
  if not name or CM.GATHERING[name] then return false end
  if CM_DATA.recipes[name] or self.db.cache[name] then return true end
  return false
end

------------------------------------------------------------------------
-- World data (NPCs, zones, quests...)
------------------------------------------------------------------------
CM.npcCache = {}
function CM:NPC(id)
  local c = self.npcCache[id]
  if c then return c end
  local s = CM_DATA.npcs[id]
  if not s then return nil end
  local p = CM.Split(s, "|")
  c = { id = id, name = p[1], zone = tonumber(p[2]) or 0, x = tonumber(p[3]) or 0, y = tonumber(p[4]) or 0, fac = p[5] or "N", lvl = p[6] or "" }
  c.zoneName = CM_DATA.zones[c.zone] or ""
  self.npcCache[id] = c
  return c
end

function CM:Quest(id)
  local s = CM_DATA.quests[id]
  if not s then return { name = "Quest #" .. id, lvl = 0 } end
  local p = CM.Split(s, "|")
  return { name = p[1], lvl = tonumber(p[2]) or 0, npc = tonumber(p[3]) }
end

function CM:Object(id)
  local s = CM_DATA.objects[id]
  if not s then return { name = "Object #" .. id, zoneName = "" } end
  local p = CM.Split(s, "|")
  return { name = p[1], zoneName = CM_DATA.zones[tonumber(p[2]) or 0] or "" }
end

function CM:FactionOK(fac)
  if self.settings.showOtherFaction then return true end
  return fac == "N" or fac == "" or fac == nil or fac == self.factionCode
end

local function where(zoneName, x, y)
  if not zoneName or zoneName == "" then return "" end
  if x and x > 0 then
    return string.format("%s (%.0f, %.0f)", zoneName, x, y)
  end
  return zoneName
end
CM.Where = where

function CM:NPCText(id)
  local n = self:NPC(id)
  if not n then return "NPC #" .. id end
  local tag = ""
  if n.fac ~= "N" and n.fac ~= self.factionCode then
    tag = (n.fac == "A") and " |cff4080ff(Alliance)|r" or " |cffff4040(Horde)|r"
  end
  local w = where(n.zoneName, n.x, n.y)
  if w ~= "" then w = " |cff999999- " .. w .. "|r" end
  return "|cffffffff" .. n.name .. "|r" .. tag .. w
end

------------------------------------------------------------------------
-- Items
------------------------------------------------------------------------
function CM:ItemInfo(id)
  if not id then return nil end
  local name, link, quality, _, _, _, _, _, texture = GetItemInfo("item:" .. id .. ":0:0:0")
  return name, link, quality, texture
end

function CM:ItemName(id)
  if not id then return "?" end
  local name = self:ItemInfo(id)
  if name then return name end
  if self.db.itemNames[id] then return self.db.itemNames[id] end
  local s = CM_DATA.items[id]
  if s then
    local a = string.find(s, "|", 1, true)
    if a then return string.sub(s, 1, a - 1) end
    return s
  end
  return "Item #" .. id
end

function CM:ItemSoldByVendor(id)
  local s = id and CM_DATA.items[id]
  return s and string.find(s, "|v", 1, true) and true or false
end

function CM:ItemIcon(id)
  if not id then return nil end
  local _, _, _, tex = self:ItemInfo(id)
  return tex or self.db.icons[id]
end

function CM:ItemQualityHex(id, default)
  local _, _, q = self:ItemInfo(id)
  if not q and CM_DATA.recipeItems[id] then q = CM_DATA.recipeItems[id].qa end
  return CM.QUALITY_HEX[q or default or 1] or "|cffffffff"
end

-- Full chat link, only when the item is in the client cache (never query the server)
function CM:ItemChatLink(id)
  local name, link, q = self:ItemInfo(id)
  if not name then return nil end
  return (CM.QUALITY_HEX[q or 1] or "|cffffffff") .. "|H" .. link .. "|h[" .. name .. "]|h|r"
end

function CM:IsRecipeItemName(name)
  if not name then return nil end
  for i = 1, table.getn(RECIPE_PREFIXES) do
    local p = RECIPE_PREFIXES[i]
    if string.sub(name, 1, string.len(p)) == p then
      return string.sub(name, string.len(p) + 1)
    end
  end
  return nil
end

------------------------------------------------------------------------
-- Merged recipe view: built-in data + what the game showed us + recorded sources
------------------------------------------------------------------------
function CM:Recipe(prof, name)
  local key = CM.Key(name)
  local db = self:DBRecipe(prof, name)
  local cache = self.db.cache[prof] and self.db.cache[prof][key]
  local learned = self.db.learned[prof] and self.db.learned[prof][key]
  local rec = { prof = prof, key = key, name = name, db = db, cache = cache, learned = learned }
  if db then
    rec.name = cache and cache.n or db.n
    rec.learn, rec.y, rec.g, rec.gr = db.l, db.y, db.g, db.r
    rec.item = db.i
    rec.reagents = db.rg
    rec.tools = db.tl
  end
  if learned and not rec.learn then rec.learn = learned.l end
  if cache then
    rec.item = cache.i or rec.item
    if cache.rg and table.getn(cache.rg) > 0 then rec.reagents = cache.rg end
    rec.icon = cache.ic
    rec.yieldMin, rec.yieldMax = cache.mn, cache.mx
    rec.header = cache.hd
  end
  if db and db.y2 and not rec.yieldMin then
    local p = CM.Split(db.y2, "-")
    rec.yieldMin, rec.yieldMax = tonumber(p[1]), tonumber(p[2] or p[1])
  end
  if not rec.icon then
    rec.icon = (rec.item and self:ItemIcon(rec.item)) or CM.PROF_ICONS[prof] or "Interface\\Icons\\INV_Misc_QuestionMark"
  end
  return rec
end

-- Difficulty colour of a recipe at a given skill, from its skill-up levels
function CM:Difficulty(rec, skill)
  if not rec.y then return nil end
  if skill < rec.y then return "optimal" end
  if skill < rec.g then return "medium" end
  if skill < rec.gr then return "easy" end
  return "trivial"
end

-- Chance for one craft to give a skill point (classic formula)
function CM:Chance(rec, skill)
  if not rec.y or not rec.learn or skill < rec.learn then return 0 end
  if skill < rec.y then return 1 end
  if skill >= rec.gr then return 0 end
  if rec.gr <= rec.y then return 0 end
  return (rec.gr - skill) / (rec.gr - rec.y)
end

function CM:DiffChanceFromType(diff)
  if diff == "optimal" then return 1 end
  return nil
end

------------------------------------------------------------------------
-- Characters and recipes
------------------------------------------------------------------------
-- Known by name, or by the item it makes (covers small name differences on custom servers)
function CM:CharKnows(char, prof, key, item)
  local p = char and char.profs and char.profs[prof]
  if not p or not p.known then return false end
  if p.known[key] then return true end
  if item and p.items and p.items[item] then return true end
  return false
end

function CM:KnownBy(prof, key, exceptSelf, item)
  local out = {}
  for _, c in ipairs(self:Chars(true)) do
    if not (exceptSelf and c.name == self.player) and self:CharKnows(c.data, prof, key, item) then
      table.insert(out, c.name)
    end
  end
  return out
end

function CM:CharSkill(char, prof)
  local p = char.profs and char.profs[prof]
  if p and p.rank then return p.rank, p.max end
  local s = char.skills and char.skills[prof]
  if s then return s.rank, s.max end
  return nil
end

-- Does any source of this recipe fit the player's faction?
function CM:RecipeFactionOK(rec)
  if self.settings.showOtherFaction then return true end
  local r = rec.db
  local any, ok = false, false
  local function check(npcs)
    for i = 1, table.getn(npcs) do
      any = true
      local n = self:NPC(npcs[i])
      if not n or self:FactionOK(n.fac) then ok = true end
    end
  end
  if r then
    if r.au or r.ct or r.qu or r.ob or r.sa then return true end
    if r.tr then check(r.tr) end
    if r.ri then
      for i = 1, table.getn(r.ri) do
        local it = CM_DATA.recipeItems[r.ri[i]]
        if it then
          if it.d or it.wd or it.qu or it.ob or it.sa or it.ho then return true end
          if it.v then
            local list = {}
            for npc in pairs(it.v) do table.insert(list, npc) end
            check(list)
          end
        end
      end
    end
  end
  if rec.learned and rec.learned.src then
    for i = 1, table.getn(rec.learned.src) do
      local s = rec.learned.src[i]
      any = true
      if self:FactionOK(s.f) then ok = true end
    end
  end
  if table.getn(self:KnownBy(rec.prof, rec.key, true, rec.item)) > 0 then return true end
  return ok or not any
end

-- Why a character can't use/learn a recipe yet (nil when nothing blocks it)
function CM:Blockers(rec, char)
  local r = rec.db
  if not r then return nil end
  local out = {}
  if r.sp then
    local hasSpec = char.specs and char.specs[r.sp]
    if not hasSpec then table.insert(out, "needs " .. r.sp) end
  end
  if r.cl then
    if not string.find(r.cl, char.class or "", 1, true) then table.insert(out, (CLASS_NAMES[r.cl] or r.cl) .. " only") end
  end
  if r.lv and (char.level or 0) < r.lv then table.insert(out, "level " .. r.lv) end
  if table.getn(out) == 0 then return nil end
  return table.concat(out, ", ")
end

-- "known", "now", "soon", "later", "blocked"
function CM:LearnState(rec, char, skill)
  if self:CharKnows(char, rec.prof, rec.key, rec.item) then return "known" end
  if self:Blockers(rec, char) then return "blocked" end
  local learn = rec.learn or 0
  if skill and learn <= skill then return "now" end
  if skill and learn <= skill + 25 then return "soon" end
  return "later"
end

CM.STATE_COLOR = {
  known = "|cff808080", now = "|cff40ff40", soon = "|cffffff00", later = "|cffff8040", blocked = "|cffff4040",
}

------------------------------------------------------------------------
-- Source descriptions
------------------------------------------------------------------------
local MAX_NPCS = 4

function CM:SourceLines(rec)
  local L = {}
  local function add(text, extra)
    local t = extra or {}
    t.text = text
    table.insert(L, t)
  end
  local function npcList(ids, prefix, suffixFn)
    local shown, hidden, other = 0, 0, 0
    local sorted = {}
    for i = 1, table.getn(ids) do
      local n = self:NPC(ids[i])
      if n and not self:FactionOK(n.fac) then
        other = other + 1
      else
        table.insert(sorted, ids[i])
      end
    end
    -- same-faction NPCs first, then by zone name
    table.sort(sorted, function(a, b)
      local na, nb = self:NPC(a), self:NPC(b)
      if not na or not nb then return a < b end
      local fa = (na.fac == self.factionCode) and 0 or 1
      local fb = (nb.fac == self.factionCode) and 0 or 1
      if fa ~= fb then return fa < fb end
      return na.zoneName < nb.zoneName
    end)
    for i = 1, table.getn(sorted) do
      if shown < MAX_NPCS then
        local suffix = suffixFn and suffixFn(sorted[i]) or ""
        add("   " .. prefix .. self:NPCText(sorted[i]) .. suffix)
        shown = shown + 1
      else
        hidden = hidden + 1
      end
    end
    if hidden > 0 then add("   |cff999999...and " .. hidden .. " more|r") end
    if shown == 0 and other > 0 then add("   |cffff8080Only available to the other faction|r") end
  end

  local r = rec.db
  if r then
    if r.tw then
      add("|cff33ccffTurtle WoW / OctoWoW recipe.|r Where to learn it isn't in the built-in data; Professional records the trainer, vendor or drop once you meet it.")
    end
    if r.au then add("|cffffd100Learned automatically|r with the profession") end
    if r.tr then
      add("|cffffd100Trainer|r" .. (r.tp and ("  " .. CM.Money(r.tp)) or ""))
      npcList(r.tr, "")
    elseif r.ct then
      add("|cffffd100Class trainer|r (" .. (CLASS_NAMES[r.ct] or r.ct) .. ")  " .. CM.Money(r.tp))
    end
    if r.qu then
      for i = 1, table.getn(r.qu) do
        local q = self:Quest(r.qu[i])
        add("|cffffd100Quest|r " .. q.name .. (q.lvl > 0 and (" |cff999999(level " .. q.lvl .. "+)|r") or ""))
        if q.npc and CM_DATA.npcs[q.npc] then add("   from " .. self:NPCText(q.npc)) end
      end
    end
    if r.ob then
      for i = 1, table.getn(r.ob) do
        local o = self:Object(r.ob[i])
        add("|cffffd100Found|r at " .. o.name .. (o.zoneName ~= "" and (" |cff999999- " .. o.zoneName .. "|r") or ""))
      end
    end
    if r.sa then add("|cffffd100Note:|r " .. r.sa) end
    if r.ri then
      for i = 1, table.getn(r.ri) do
        local id = r.ri[i]
        local it = CM_DATA.recipeItems[id]
        if it then
          add("|cffffd100Recipe item|r " .. self:ItemQualityHex(id, it.qa) .. "[" .. it.n .. "]|r", { item = id })
          if it.v then
            local ids = {}
            for npc in pairs(it.v) do table.insert(ids, npc) end
            npcList(ids, "|cff80c0ffVendor|r ", function(npc)
              local s = ""
              if it.vp and it.vp > 0 then s = "  " .. CM.Money(it.vp) end
              if it.v[npc] and it.v[npc] > 0 then s = s .. " |cffff9933(limited)|r" end
              return s
            end)
          end
          if it.d then
            local ids, chance = {}, {}
            for npc, c in pairs(it.d) do table.insert(ids, npc); chance[npc] = c end
            table.sort(ids, function(a, b) return (chance[a] or 0) > (chance[b] or 0) end)
            local shown = 0
            for j = 1, table.getn(ids) do
              if shown < 5 then
                local n = self:NPC(ids[j])
                local c = chance[ids[j]]
                local ctext = (c and c > 0) and string.format(" |cff999999%s%%|r", (c >= 1) and string.format("%.0f", c) or string.format("%.1f", c)) or ""
                local lvl = (n and n.lvl ~= "") and (" |cff999999lvl " .. n.lvl .. "|r") or ""
                add("   |cffff8080Drop|r " .. self:NPCText(ids[j]) .. lvl .. ctext)
                shown = shown + 1
              end
            end
            if table.getn(ids) > shown then add("   |cff999999...and " .. (table.getn(ids) - shown) .. " more|r") end
          end
          if it.wd then
            if it.wd[1] and it.wd[1] > 0 then
              add("   |cffff8080World drop|r from level " .. it.wd[1] .. "-" .. it.wd[2] .. " mobs")
            else
              add("   |cffff8080World drop|r")
            end
          end
          if it.qu then
            for j = 1, table.getn(it.qu) do
              local q = self:Quest(it.qu[j])
              add("   |cffffd100Quest reward|r " .. q.name .. (q.lvl > 0 and (" |cff999999(level " .. q.lvl .. "+)|r") or ""))
              if q.npc and CM_DATA.npcs[q.npc] then add("      from " .. self:NPCText(q.npc)) end
            end
          end
          if it.rp then
            add("   |cffff80ffReputation|r " .. (CM_DATA.factions[it.rp[1]] or "?") .. " - " .. (REP_LEVELS[it.rp[2]] or "?"))
          end
          if it.ho then add("   |cffff80ffSeasonal|r " .. it.ho) end
          if it.ob then
            for j = 1, table.getn(it.ob) do
              local o = self:Object(it.ob[j])
              add("   |cffffd100Found|r at " .. o.name .. (o.zoneName ~= "" and (" |cff999999- " .. o.zoneName .. "|r") or ""))
            end
          end
          if it.sa then add("   |cffffd100Note:|r " .. it.sa) end
        end
      end
    end
    if r.rp then
      add("|cffff80ffReputation|r " .. (CM_DATA.factions[r.rp[1]] or "?") .. " - " .. (REP_LEVELS[r.rp[2]] or "?"))
    end
    if r.sp then add("|cffff8040Requires specialization:|r " .. r.sp) end
    if r.cl then add("|cffff8040Class:|r " .. (CLASS_NAMES[r.cl] or r.cl)) end
    if r.lv then add("|cffff8040Requires character level|r " .. r.lv) end
  end

  local l = rec.learned
  if l and l.src and table.getn(l.src) > 0 then
    add("|cff33ccffRecorded while playing:|r")
    for i = 1, table.getn(l.src) do
      local s = l.src[i]
      local what = (s.t == "T" and "Trainer") or (s.t == "V" and "Vendor") or (s.t == "D" and "Drop") or "Seen"
      local extra = ""
      if s.p and s.p > 0 then extra = "  " .. CM.Money(s.p) end
      if s.lim then extra = extra .. " |cffff9933(limited)|r" end
      local tag = ""
      if s.f and s.f ~= "N" and s.f ~= self.factionCode then tag = " |cffff8080(other faction)|r" end
      add("   " .. what .. " |cffffffff" .. (s.n or "?") .. "|r" .. tag .. " |cff999999- " .. where(s.z, s.x, s.y) .. "|r" .. extra)
    end
  end

  local alts = self:KnownBy(rec.prof, rec.key, true, rec.item)
  if table.getn(alts) > 0 then
    add("|cff33ccffKnown by:|r " .. table.concat(alts, ", "))
  end

  if table.getn(L) == 0 then
    add("|cff999999No source information yet. Professional records trainers, vendors and drops as you meet them.|r")
  end
  return L
end

-- Short tag for list rows: T(rainer) V(endor) D(rop) Q(uest) R(eputation)
function CM:SourceTags(rec)
  local tags = {}
  local seen = {}
  local function tag(t) if not seen[t] then seen[t] = true; table.insert(tags, t) end end
  local r = rec.db
  if r then
    if r.tw then tag("C") end
    if r.au then tag("A") end
    if r.tr or r.ct then tag("T") end
    if r.qu then tag("Q") end
    if r.ri then
      for i = 1, table.getn(r.ri) do
        local it = CM_DATA.recipeItems[r.ri[i]]
        if it then
          if it.v then tag("V") end
          if it.d or it.wd then tag("D") end
          if it.qu then tag("Q") end
          if it.rp then tag("R") end
        end
      end
    end
  end
  if rec.learned and rec.learned.src then
    for i = 1, table.getn(rec.learned.src) do tag(rec.learned.src[i].t) end
  end
  return table.concat(tags, "")
end

-- Is the recipe obtainable in a way the planner may use?
function CM:PlanSourceOK(rec, opts)
  local r = rec.db
  if r then
    if r.au or r.tr or r.ct then return true end
    if r.ri then
      for i = 1, table.getn(r.ri) do
        local it = CM_DATA.recipeItems[r.ri[i]]
        if it then
          if opts.vendor and it.v then
            for npc, lim in pairs(it.v) do
              local n = self:NPC(npc)
              if lim == 0 and (not n or self:FactionOK(n.fac)) and not it.rp then return true end
            end
          end
          if opts.drops and (it.d or it.wd or it.qu or it.rp) then return true end
        end
      end
    end
    if opts.drops and r.qu then return true end
  end
  if rec.learned and rec.learned.src then
    for i = 1, table.getn(rec.learned.src) do
      local s = rec.learned.src[i]
      if s.t == "T" then return true end
      if s.t == "V" and opts.vendor and not s.lim then return true end
      if s.t == "D" and opts.drops then return true end
    end
  end
  return false
end

function CM:LearnCost(rec)
  local r = rec.db
  if not r then return 0 end
  if r.tr or r.ct then return r.tp or 0 end
  if r.ri then
    local it = CM_DATA.recipeItems[r.ri[1]]
    if it and it.vp then return it.vp end
  end
  return 0
end

local function reagentWeight(rec)
  local w = 0
  if rec.reagents then
    for i = 2, table.getn(rec.reagents), 2 do w = w + (rec.reagents[i] or 1) end
  end
  return w
end

------------------------------------------------------------------------
-- Every recipe of a profession (built-in + recorded + seen on any character)
------------------------------------------------------------------------
function CM:ProfessionRecipes(prof)
  local out, seen = {}, {}
  local list = CM_DATA.recipes[prof]
  if list then
    for i = 1, table.getn(list) do
      local key = CM.Key(list[i].n)
      if not seen[key] then seen[key] = true; table.insert(out, self:Recipe(prof, list[i].n)) end
    end
  end
  local l = self.db.learned[prof]
  if l then
    for key, v in pairs(l) do
      if not seen[key] and not CM.IsRankName(v.n) then seen[key] = true; table.insert(out, self:Recipe(prof, v.n)) end
    end
  end
  local c = self.db.cache[prof]
  if c then
    for key, v in pairs(c) do
      if not seen[key] then seen[key] = true; table.insert(out, self:Recipe(prof, v.n)) end
    end
  end
  return out
end

------------------------------------------------------------------------
-- Leveling plan
------------------------------------------------------------------------
-- Recipes on a cooldown can't be spammed for skill points
local COOLDOWN_PATTERNS = { "^transmute", "^mooncloth$", "^refined deeprock salt$" }
function CM:HasCooldown(rec)
  for i = 1, table.getn(COOLDOWN_PATTERNS) do
    if string.find(rec.key, COOLDOWN_PATTERNS[i]) then return true end
  end
  return false
end

-- Returns { steps = { {rec, from, to, crafts, known}, or {note=text} }, reagents = {[id]=n}, cost = copper, stuck = skill or nil }
function CM:Plan(prof, char, from, to, opts)
  local candidates = {}
  for _, rec in ipairs(self:ProfessionRecipes(prof)) do
    if rec.y and rec.learn and not self:HasCooldown(rec) then
      local known = self:CharKnows(char, prof, rec.key, rec.item)
      if known or (not self:Blockers(rec, char) and self:RecipeFactionOK(rec) and self:PlanSourceOK(rec, opts)) then
        rec.known = known
        rec.weight = reagentWeight(rec)
        table.insert(candidates, rec)
      end
    end
  end

  local caps = {}
  local ranks = CM_DATA.ranks[prof]
  local _, curMax = self:CharSkill(char, prof)
  if ranks then
    for i = 1, table.getn(ranks) - 1 do
      local cur, nxt = ranks[i], ranks[i + 1]
      if not curMax or cur.mx >= curMax then
        caps[cur.mx] = nxt
      end
    end
  end

  local steps, reagents = {}, {}
  local cost = 0
  local learnedSet = {}
  local last
  local plan = { steps = steps, reagents = reagents }
  for s = from, to - 1 do
    if caps[s] then
      local nr = caps[s]
      local bits = {}
      if nr.mn and nr.mn > 0 then table.insert(bits, "skill " .. nr.mn) end
      if nr.lv and nr.lv > 0 then table.insert(bits, "level " .. nr.lv) end
      if nr.tp and nr.tp > 0 then table.insert(bits, CM.Money(nr.tp)) end
      table.insert(steps, { note = "Train " .. nr.n .. (table.getn(bits) > 0 and (" (" .. table.concat(bits, ", ") .. ")") or "") })
      cost = cost + (nr.tp or 0)
      last = nil
    end
    local best, bestChance = nil, 0
    for i = 1, table.getn(candidates) do
      local rec = candidates[i]
      local c = self:Chance(rec, s)
      if c > 0 then
        local better = false
        if c > bestChance + 0.001 then
          better = true
        elseif best and math.abs(c - bestChance) <= 0.001 then
          if rec.known ~= best.known then
            better = rec.known
          elseif rec.weight ~= best.weight then
            better = rec.weight < best.weight
          else
            better = rec.gr > best.gr
          end
        end
        if better then best, bestChance = rec, c end
      end
    end
    if not best then
      plan.stuck = s
      break
    end
    -- avoid buying a new recipe when one you already have (or already planned) is nearly as good
    if not best.known and not learnedSet[best.key] then
      local alt, altChance = nil, 0
      for i = 1, table.getn(candidates) do
        local rec = candidates[i]
        if rec.known or learnedSet[rec.key] then
          local c = self:Chance(rec, s)
          if c >= bestChance * 0.8 and c > altChance then alt, altChance = rec, c end
        end
      end
      if alt then best, bestChance = alt, altChance end
    end
    if last and last.rec == best then
      last.to = s + 1
      last.exact = last.exact + 1 / bestChance
    else
      last = { rec = best, from = s, to = s + 1, exact = 1 / bestChance, known = best.known }
      table.insert(steps, last)
      if not best.known and not learnedSet[best.key] then
        learnedSet[best.key] = true
        cost = cost + self:LearnCost(best)
      end
    end
  end
  for i = 1, table.getn(steps) do
    local st = steps[i]
    if st.rec then
      st.crafts = math.ceil(st.exact - 0.05)
      local rg = st.rec.reagents
      if rg then
        for j = 1, table.getn(rg), 2 do
          reagents[rg[j]] = (reagents[rg[j]] or 0) + (rg[j + 1] or 1) * st.crafts
        end
      end
    end
  end
  plan.cost = cost
  return plan
end

------------------------------------------------------------------------
-- Item counts across bags, bank and alts
------------------------------------------------------------------------
function CM:ItemCounts(id)
  local bags = (self.char.bags and self.char.bags[id]) or 0
  local bank = (self.char.bank and self.char.bank[id]) or 0
  local alts, altList = 0, {}
  for _, c in ipairs(self:Chars(true)) do
    if c.name ~= self.player then
      local b = (c.data.bags and c.data.bags[id]) or 0
      local k = (c.data.bank and c.data.bank[id]) or 0
      if b + k > 0 then
        alts = alts + b + k
        table.insert(altList, { name = c.name, bags = b, bank = k })
      end
    end
  end
  return bags, bank, alts, altList
end

-- Recipes known by the player that create an item (for intermediate reagents)
function CM:MakersOf(id)
  if not self.makers then
    local m = {}
    for prof, p in pairs(self.char.profs) do
      if p.known then
        for key in pairs(p.known) do
          local c = self.db.cache[prof] and self.db.cache[prof][key]
          local item = c and c.i
          if not item then
            local r = self:Index().byName[prof] and self:Index().byName[prof][key]
            item = r and r.i
          end
          if item then
            if not m[item] then m[item] = {} end
            table.insert(m[item], { prof = prof, name = (c and c.n) or key })
          end
        end
      end
    end
    self.makers = m
  end
  return self.makers[id]
end

-- Every recipe that uses an item, by profession: [prof][key] = { name, count }
-- Built from the built-in data, with recipes seen in a profession window taking priority.
function CM:ReagentRecipes(id)
  if not self.reagentIndex then
    local idx = {}
    local function add(prof, key, name, rg)
      if not rg then return end
      for j = 1, table.getn(rg), 2 do
        local item = rg[j]
        if not idx[item] then idx[item] = {} end
        if not idx[item][prof] then idx[item][prof] = {} end
        idx[item][prof][key] = { name = name, count = rg[j + 1] or 1 }
      end
    end
    for prof, list in pairs(CM_DATA.recipes) do
      local cache = self.db.cache[prof]
      for i = 1, table.getn(list) do
        local key = CM.Key(list[i].n)
        if not (cache and cache[key] and cache[key].rg and table.getn(cache[key].rg) > 0) then
          add(prof, key, list[i].n, list[i].rg)
        end
      end
    end
    for prof, list in pairs(self.db.cache) do
      for key, c in pairs(list) do
        if c.rg and table.getn(c.rg) > 0 then add(prof, key, c.n, c.rg) end
      end
    end
    self.reagentIndex = idx
  end
  return self.reagentIndex[id]
end

-- Which professions use an item as a reagent: [prof] = number of recipes
function CM:ReagentUses(id)
  local r = self:ReagentRecipes(id)
  if not r then return nil end
  local out = {}
  for prof, list in pairs(r) do out[prof] = CM.Count(list) end
  return out
end

function CM:CharHasProfession(char, prof)
  if char.skills and char.skills[prof] then return true end
  if char.profs and char.profs[prof] then return true end
  return false
end

-- Should recipes of this profession be listed in item tooltips?
-- Unset means "only if this character has the profession".
function CM:TooltipProfEnabled(prof)
  local v = self.settings.tooltipProfs and self.settings.tooltipProfs[prof]
  if v ~= nil then return v end
  return self:CharHasProfession(self.char, prof)
end
