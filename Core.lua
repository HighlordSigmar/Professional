-- Professional: a profession window replacement for the 1.12 client (OctoWoW)
-- Core: namespace, events, timers, saved variables, utilities, slash commands.

Professional = {}
local CM = Professional
CM.version = "1.0.0"

CM.PROF_ICONS = {
  ["Alchemy"] = "Interface\\Icons\\Trade_Alchemy",
  ["Blacksmithing"] = "Interface\\Icons\\Trade_BlackSmithing",
  ["Enchanting"] = "Interface\\Icons\\Trade_Engraving",
  ["Engineering"] = "Interface\\Icons\\Trade_Engineering",
  ["Leatherworking"] = "Interface\\Icons\\INV_Misc_ArmorKit_17",
  ["Tailoring"] = "Interface\\Icons\\Trade_Tailoring",
  ["Cooking"] = "Interface\\Icons\\INV_Misc_Food_15",
  ["First Aid"] = "Interface\\Icons\\Spell_Holy_SealOfSacrifice",
  ["Mining"] = "Interface\\Icons\\Trade_Mining",
  ["Poisons"] = "Interface\\Icons\\Trade_BrewPoison",
  ["Herbalism"] = "Interface\\Icons\\Trade_Herbalism",
  ["Skinning"] = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01",
  ["Fishing"] = "Interface\\Icons\\Trade_Fishing",
}
-- Spell that opens a profession window, when it differs from the profession name
CM.PROF_SPELL = { ["Mining"] = "Smelting" }
-- Skills that never have a recipe window
CM.GATHERING = { ["Herbalism"] = 1, ["Skinning"] = 1, ["Fishing"] = 1, ["Riding"] = 1, ["Lockpicking"] = 1 }

CM.DIFF_COLOR = {
  optimal = { r = 1.00, g = 0.50, b = 0.25 },
  medium  = { r = 1.00, g = 1.00, b = 0.00 },
  easy    = { r = 0.25, g = 0.75, b = 0.25 },
  trivial = { r = 0.50, g = 0.50, b = 0.50 },
  header  = { r = 1.00, g = 0.82, b = 0.00 },
  unknown = { r = 0.80, g = 0.80, b = 0.80 },
}
CM.DIFF_ORDER = { optimal = 1, medium = 2, easy = 3, trivial = 4 }

CM.QUALITY_HEX = { [0] = "|cff9d9d9d", [1] = "|cffffffff", [2] = "|cff1eff00", [3] = "|cff0070dd", [4] = "|cffa335ee", [5] = "|cffff8000" }

------------------------------------------------------------------------
-- Events and timers
------------------------------------------------------------------------
CM.handlers = {}
local eventFrame = CreateFrame("Frame", "ProfessionalEventFrame")
CM.eventFrame = eventFrame

function CM:On(ev, fn)
  if not self.handlers[ev] then
    self.handlers[ev] = {}
    eventFrame:RegisterEvent(ev)
  end
  table.insert(self.handlers[ev], fn)
end

eventFrame:SetScript("OnEvent", function()
  local list = CM.handlers[event]
  if not list then return end
  for i = 1, table.getn(list) do
    local ok, err = pcall(list[i], event, arg1, arg2, arg3, arg4)
    if not ok then CM:Error(event, err) end
  end
end)

CM.timers = {}
-- Debounced call: scheduling the same key again pushes it back.
function CM:Schedule(key, delay, fn)
  self.timers[key] = { at = GetTime() + delay, fn = fn }
end

eventFrame:SetScript("OnUpdate", function()
  if not next(CM.timers) then return end
  local now = GetTime()
  local due
  for key, t in pairs(CM.timers) do
    if now >= t.at then
      due = due or {}
      table.insert(due, t.fn)
      CM.timers[key] = nil
    end
  end
  if due then
    for i = 1, table.getn(due) do
      local ok, err = pcall(due[i])
      if not ok then CM:Error("timer", err) end
    end
  end
end)

------------------------------------------------------------------------
-- Utilities (Lua 5.0 safe)
------------------------------------------------------------------------
function CM:Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffProfessional|r: " .. tostring(msg))
end

CM.errorsShown = 0
function CM:Error(where, err)
  if self.errorsShown < 5 then
    self.errorsShown = self.errorsShown + 1
    self:Print("|cffff4040error in " .. tostring(where) .. ":|r " .. tostring(err))
  end
end

function CM.Key(name)
  if not name then return "" end
  local s = string.lower(name)
  s = string.gsub(s, "%s+", " ")
  s = string.gsub(s, "^ ", "")
  s = string.gsub(s, " $", "")
  return s
end

function CM.ItemId(link)
  if not link then return nil end
  local _, _, id = string.find(link, "item:(%d+)")
  return tonumber(id)
end

function CM.Split(str, sep)
  local out = {}
  local pos = 1
  while true do
    local a, b = string.find(str, sep, pos, true)
    if not a then
      table.insert(out, string.sub(str, pos))
      break
    end
    table.insert(out, string.sub(str, pos, a - 1))
    pos = b + 1
  end
  return out
end

function CM.Hex(c)
  return string.format("|cff%02x%02x%02x", math.floor(c.r * 255), math.floor(c.g * 255), math.floor(c.b * 255))
end

function CM.Money(copper)
  copper = math.floor(copper or 0)
  if copper <= 0 then return "free" end
  local g = math.floor(copper / 10000)
  local s = math.floor(math.mod(copper, 10000) / 100)
  local c = math.mod(copper, 100)
  local out = ""
  if g > 0 then out = out .. g .. "|cffffd700g|r " end
  if s > 0 then out = out .. s .. "|cffc7c7cfs|r " end
  if c > 0 then out = out .. c .. "|cffeda55fc|r" end
  out = string.gsub(out, " $", "")
  return out
end

function CM.Copy(t)
  if type(t) ~= "table" then return t end
  local o = {}
  for k, v in pairs(t) do o[k] = CM.Copy(v) end
  return o
end

function CM.Count(t)
  local n = 0
  if t then for _ in pairs(t) do n = n + 1 end end
  return n
end

------------------------------------------------------------------------
-- Saved variables
------------------------------------------------------------------------
local DEFAULTS = {
  replaceWindow = true,
  tooltip = true,
  tooltipAlts = true,
  scale = 1,
  sort = "category",
  planVendor = true,
  planDrops = false,
  showOtherFaction = false,
  lastTab = "recipes",
}

function CM:InitDB()
  if type(ProfessionalDB) ~= "table" then ProfessionalDB = {} end
  local db = ProfessionalDB
  db.version = CM.version
  db.settings = db.settings or {}
  for k, v in pairs(DEFAULTS) do
    if db.settings[k] == nil then db.settings[k] = v end
  end
  db.realms = db.realms or {}
  db.cache = db.cache or {}         -- [prof][key] = recipe details seen in a profession window
  db.learned = db.learned or {}     -- [prof][key] = recipes/sources recorded at trainers, vendors, loot
  db.itemNames = db.itemNames or {}
  db.icons = db.icons or {}
  self.db = db
  self.settings = db.settings
end

function CM:InitChar()
  local realm = GetRealmName()
  local name = UnitName("player")
  if not realm or not name or name == UNKNOWNOBJECT then return false end
  self.realm, self.player = realm, name
  local r = self.db.realms[realm]
  if not r then r = { chars = {} }; self.db.realms[realm] = r end
  local c = r.chars[name]
  if not c then c = {}; r.chars[name] = c end
  local _, class = UnitClass("player")
  c.class = class
  c.level = UnitLevel("player")
  c.faction = UnitFactionGroup("player")
  c.profs = c.profs or {}
  c.skills = c.skills or {}
  c.specs = c.specs or {}
  c.bags = c.bags or {}
  c.bank = c.bank or {}
  c.queue = c.queue or {}
  c.seen = time()
  self.char = c
  self.realmData = r
  self.factionCode = (c.faction == "Horde") and "H" or "A"
  return true
end

-- All characters on this realm (optionally only same faction)
function CM:Chars(sameFaction)
  local out = {}
  if not self.realmData then return out end
  for name, c in pairs(self.realmData.chars) do
    if not sameFaction or c.faction == self.char.faction then
      table.insert(out, { name = name, data = c })
    end
  end
  table.sort(out, function(a, b)
    if a.name == CM.player then return true end
    if b.name == CM.player then return false end
    return a.name < b.name
  end)
  return out
end

------------------------------------------------------------------------
-- Startup
------------------------------------------------------------------------
CM:On("ADDON_LOADED", function(ev, name)
  if name == "Professional" then
    CM:InitDB()
  end
end)

CM:On("PLAYER_ENTERING_WORLD", function()
  if CM.ready then return end
  if not CM.db then CM:InitDB() end
  if not CM:InitChar() then return end
  CM.ready = true
  CM:ApplyWindowReplacement()
  CM:ScanSkills()
  CM:ScanSpellbook()
  CM:ScanBags()
  if CM.InitTooltips then CM:InitTooltips() end
end)

-- Take over (or give back) the default profession windows
function CM:ApplyWindowReplacement()
  if self.settings.replaceWindow then
    UIParent:UnregisterEvent("TRADE_SKILL_SHOW")
    UIParent:UnregisterEvent("CRAFT_SHOW")
  else
    UIParent:RegisterEvent("TRADE_SKILL_SHOW")
    UIParent:RegisterEvent("CRAFT_SHOW")
  end
end

------------------------------------------------------------------------
-- Slash commands
------------------------------------------------------------------------
SLASH_PROFESSIONAL1 = "/professional"
SLASH_PROFESSIONAL2 = "/prof"
SlashCmdList["PROFESSIONAL"] = function(msg)
  msg = msg or ""
  local _, _, cmd, rest = string.find(msg, "^%s*(%S*)%s*(.-)%s*$")
  cmd = string.lower(cmd or "")
  if cmd == "" then
    CM:Toggle()
  elseif cmd == "blizzard" or cmd == "default" then
    CM.settings.replaceWindow = not CM.settings.replaceWindow
    CM:ApplyWindowReplacement()
    if CM.settings.replaceWindow then
      CM:Print("now replacing the default profession windows.")
    else
      CM:Print("using the default profession windows again. Type /prof to open Professional by hand.")
    end
  elseif cmd == "scale" then
    local s = tonumber(rest)
    if s and s >= 0.5 and s <= 2 then
      CM.settings.scale = s
      if ProfessionalFrame then ProfessionalFrame:SetScale(s) end
      CM:Print("scale set to " .. s)
    else
      CM:Print("usage: /prof scale 0.5 - 2")
    end
  elseif cmd == "reset" then
    CM.settings.pos = nil
    if ProfessionalFrame then
      ProfessionalFrame:ClearAllPoints()
      ProfessionalFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    end
    CM:Print("window position reset.")
  elseif cmd == "tooltip" then
    CM.settings.tooltip = not CM.settings.tooltip
    CM:Print("tooltip info " .. (CM.settings.tooltip and "on" or "off"))
  elseif cmd == "alts" then
    CM.settings.tooltipAlts = not CM.settings.tooltipAlts
    CM:Print("alt item counts in tooltips " .. (CM.settings.tooltipAlts and "on" or "off"))
  elseif cmd == "delete" and rest ~= "" then
    local found
    for name in pairs(CM.realmData.chars) do
      if string.lower(name) == string.lower(rest) then found = name end
    end
    if found and found ~= CM.player then
      CM.realmData.chars[found] = nil
      CM:Print("deleted " .. found .. ".")
      if CM.Refresh then CM:Refresh() end
    else
      CM:Print("no other character named " .. rest .. " on this realm.")
    end
  elseif cmd == "forget" then
    ProfessionalDB.learned = {}
    CM.db.learned = ProfessionalDB.learned
    CM:Print("forgot every recipe source recorded while playing.")
  else
    CM:Print("commands:")
    CM:Print("/prof - open or close the window")
    CM:Print("/prof blizzard - switch between Professional and the default profession windows")
    CM:Print("/prof scale <0.5-2>, /prof reset - window size and position")
    CM:Print("/prof tooltip - recipe info in item tooltips on/off")
    CM:Print("/prof alts - alt item counts in tooltips on/off")
    CM:Print("/prof delete <name> - forget a character")
    CM:Print("/prof forget - clear recipe sources recorded while playing")
  end
end
