-- Professional: extra lines on item tooltips
--  * recipe items: which of your characters know it or can learn it
--  * reagents: which professions use it, what the queue needs, how many your alts hold

local CM = Professional

function CM:RecipeItemTarget(id)
  local r = self:Index().byRecipeItem[id]
  if r then return r.prof, r.n, r.l end
  for prof, list in pairs(self.db.learned) do
    for _, e in pairs(list) do
      if e.ri == id then return prof, e.n, e.l end
    end
  end
  return nil
end

function CM:AddTooltipInfo(tip, id)
  if not self.ready or not self.settings.tooltip or not id then return end
  local added = false
  local function line(left, right, r, g, b)
    if not added then
      added = true
    end
    if right then
      tip:AddDoubleLine(left, right, r or 0.2, g or 0.8, b or 1, 1, 1, 1)
    else
      tip:AddLine(left, r or 0.2, g or 0.8, b or 1)
    end
  end

  local prof, name, learn = self:RecipeItemTarget(id)
  if prof then
    local key = CM.Key(name)
    for _, c in ipairs(self:Chars(true)) do
      local rank = self:CharSkill(c.data, prof)
      if rank then
        local status
        local p = c.data.profs and c.data.profs[prof]
        if self:CharKnows(c.data, prof, key) then
          status = "|cff808080already known|r"
        elseif not learn or rank >= learn then
          status = "|cff40ff40can learn|r" .. ((not p or not p.list) and " |cff999999(?)|r" or "")
        else
          status = "|cffff8040at " .. learn .. "|r |cff999999(" .. rank .. ")|r"
        end
        line(c.name .. " (" .. prof .. ")", status)
      end
    end
  end

  local uses = self:ReagentUses(id)
  if uses then
    local list = {}
    for p in pairs(uses) do table.insert(list, p) end
    table.sort(list)
    line("Reagent: " .. table.concat(list, ", "), nil, 1, 0.82, 0)
    if self.char and self.Tabs and self.Tabs.shopping then
      local need = self.Tabs.shopping:Needs()[id]
      if need then
        local have = (self.char.bags[id] or 0) + (self.char.bank[id] or 0)
        line("Craft queue needs " .. need, "have " .. have, 0.2, 0.8, 1)
      end
    end
    if self.settings.tooltipAlts then
      local _, _, _, altList = self:ItemCounts(id)
      for i = 1, table.getn(altList) do
        local a = altList[i]
        local txt = tostring(a.bags + a.bank)
        if a.bank > 0 then txt = txt .. " |cff999999(bank " .. a.bank .. ")|r" end
        line("  " .. a.name, txt, 0.6, 0.6, 0.6)
      end
    end
  end
  if added then tip:Show() end
end

local function hook(tip, method, getLink)
  if not tip then return end
  local orig = tip[method]
  if not orig then return end
  tip[method] = function(self, a, b, c)
    local r1, r2, r3 = orig(self, a, b, c)
    local ok, err = pcall(function()
      local link = getLink(a, b, c)
      local id = link and CM.ItemId(link)
      if id then CM:AddTooltipInfo(self, id) end
    end)
    if not ok then CM:Error("tooltip", err) end
    return r1, r2, r3
  end
end

function CM:InitTooltips()
  if self.tooltipsHooked then return end
  self.tooltipsHooked = true
  hook(GameTooltip, "SetBagItem", function(bag, slot) return GetContainerItemLink(bag, slot) end)
  hook(GameTooltip, "SetInventoryItem", function(unit, slot) return GetInventoryItemLink(unit, slot) end)
  hook(GameTooltip, "SetMerchantItem", function(i) return GetMerchantItemLink(i) end)
  hook(GameTooltip, "SetLootItem", function(i) return GetLootSlotLink(i) end)
  hook(GameTooltip, "SetHyperlink", function(link) return link end)
  hook(ItemRefTooltip, "SetHyperlink", function(link) return link end)
  hook(GameTooltip, "SetAuctionItem", function(t, i) return GetAuctionItemLink(t, i) end)
  hook(GameTooltip, "SetQuestItem", function(t, i) return GetQuestItemLink(t, i) end)
  hook(GameTooltip, "SetQuestLogItem", function(t, i) return GetQuestLogItemLink(t, i) end)
  hook(GameTooltip, "SetTradeSkillItem", function(i, j)
    if j then return GetTradeSkillReagentItemLink(i, j) end
    return GetTradeSkillItemLink(i)
  end)
  hook(GameTooltip, "SetCraftItem", function(i, j)
    if j then return GetCraftReagentItemLink(i, j) end
    return nil
  end)
end
