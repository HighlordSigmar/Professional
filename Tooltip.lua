-- Professional: extra lines on item tooltips
--  * recipe items: which of your characters know it or can learn it
--  * reagents: the recipes that use it (for the professions ticked in Options),
--    what the queue needs, how many your alts hold

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

  local uses = self:ReagentRecipes(id)
  if uses then
    local profs = {}
    for p in pairs(uses) do table.insert(profs, p) end
    table.sort(profs)
    local hidden = {}
    local max = self.settings.tooltipMax or 10
    for _, p in ipairs(profs) do
      if self:TooltipProfEnabled(p) then
        local rank = self:CharSkill(self.char, p)
        local list = {}
        for key, u in pairs(uses[p]) do
          local rec = self:Recipe(p, u.name)
          local known = self:CharKnows(self.char, p, key, rec.item)
          if known or not self.settings.tooltipKnownOnly then
            table.insert(list, { rec = rec, known = known, count = u.count })
          end
        end
        table.sort(list, function(a, b)
          if a.known ~= b.known then return a.known end
          local la, lb = a.rec.learn or 0, b.rec.learn or 0
          if la ~= lb then return la < lb end
          return a.rec.name < b.rec.name
        end)
        local n = table.getn(list)
        if n > 0 then
          line(p .. " |cff999999(" .. n .. ")|r", nil, 1, 0.82, 0)
          for i = 1, math.min(n, max) do
            local e = list[i]
            local c
            if e.known then
              c = CM.DIFF_COLOR[(rank and self:Difficulty(e.rec, rank)) or "unknown"] or CM.DIFF_COLOR.unknown
              if not e.rec.y then c = { r = 1, g = 1, b = 1 } end
            else
              c = { r = 0.5, g = 0.5, b = 0.5 }
            end
            local right = "x" .. e.count
            if e.known then
              local can = self.Tabs.recipes:Craftable(e.rec, self.char)
              if can > 0 then right = "|cff40ff40[" .. can .. "]|r " .. right end
            else
              right = right .. " |cff808080learn " .. (e.rec.learn or "?") .. "|r"
            end
            tip:AddDoubleLine("  " .. e.rec.name, right, c.r, c.g, c.b, 1, 1, 1)
            added = true
          end
          if n > max then line("  ...and " .. (n - max) .. " more", nil, 0.5, 0.5, 0.5) end
        end
      else
        table.insert(hidden, p)
      end
    end
    if self.settings.tooltipOthers and table.getn(hidden) > 0 then
      line("Also used in: " .. table.concat(hidden, ", "), nil, 0.5, 0.5, 0.5)
    end
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
