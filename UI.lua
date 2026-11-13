-- Professional: main window, header, detail pane and profession window events.

local CM = Professional

local W, H = 810, 570
local LIST_W = 380
local ROW_H = 16
local LIST_ROWS = 24
local DETAIL_ROWS = 26
local DETAIL_ROW_H = 14
CM.DETAIL_WIDTH = 360

CM.view = {}
CM.collapsed = {}
CM.tabOrder = { "recipes", "missing", "skillup", "shopping", "alts" }
CM.Tabs = CM.Tabs or {}

local BACKDROP = {
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
  tile = true, tileSize = 16, edgeSize = 24,
  insets = { left = 6, right = 6, top = 6, bottom = 6 },
}
local PANEL_BACKDROP = {
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 12,
  insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

------------------------------------------------------------------------
-- View helpers
------------------------------------------------------------------------
function CM:ViewChar()
  local name = self.view.char or self.player
  return self.realmData.chars[name] or self.char, name
end

function CM:IsViewingSelf()
  return (self.view.char or self.player) == self.player
end

-- The open window ("trade"/"craft") that matches the viewed profession, if any
function CM:ViewLive()
  if not self:IsViewingSelf() then return nil end
  for _, mode in ipairs({ "trade", "craft" }) do
    local L = self.live[mode]
    if L.open and L.snap and L.prof == self.view.prof then return mode, L.snap end
  end
  return nil
end

function CM:ViewSkill()
  local mode, snap = self:ViewLive()
  if snap then return snap.rank, snap.max end
  local char = self:ViewChar()
  return self:CharSkill(char, self.view.prof)
end

-- Professions with a recipe window for a character
function CM:CharProfessions(char)
  local set, out = {}, {}
  for prof in pairs(char.profs or {}) do set[prof] = true end
  for prof in pairs(char.skills or {}) do
    if self:IsCraftProfession(prof) then set[prof] = true end
  end
  for prof in pairs(set) do table.insert(out, prof) end
  table.sort(out)
  return out
end

------------------------------------------------------------------------
-- Frame
------------------------------------------------------------------------
function CM:CreateUI()
  if self.frame then return self.frame end
  local f = CreateFrame("Frame", "ProfessionalFrame", UIParent)
  self.frame = f
  f:SetWidth(W)
  f:SetHeight(H)
  f:SetFrameStrata("HIGH")
  if f.SetToplevel then f:SetToplevel(1) end
  f:SetBackdrop(BACKDROP)
  f:SetBackdropColor(0.06, 0.06, 0.08, 0.96)
  f:EnableMouse(1)
  f:SetMovable(1)
  if f.SetClampedToScreen then f:SetClampedToScreen(1) end
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() this:StartMoving() end)
  f:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
    local x, y = this:GetLeft(), this:GetTop()
    CM.settings.pos = { x = x, y = y }
  end)
  f:SetScale(self.settings.scale or 1)
  if self.settings.pos then
    f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", self.settings.pos.x, self.settings.pos.y)
  else
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
  end
  f:Hide()
  table.insert(UISpecialFrames, "ProfessionalFrame")
  f:SetScript("OnHide", function() CM:OnWindowHidden() end)

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", f, "TOP", 0, -14)
  title:SetText("Professional")

  local close = CreateFrame("Button", "ProfessionalCloseButton", f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)

  -- header: profession icon, name, rank bar, viewed character
  local icon = f:CreateTexture(nil, "ARTWORK")
  icon:SetWidth(34); icon:SetHeight(34)
  icon:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -16)
  self.headerIcon = icon

  local profText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  profText:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, -1)
  profText:SetJustifyH("LEFT")
  self.headerText = profText

  local bar = CreateFrame("StatusBar", "ProfessionalRankBar", f)
  bar:SetWidth(200); bar:SetHeight(12)
  bar:SetPoint("TOPLEFT", profText, "BOTTOMLEFT", 0, -4)
  bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  bar:SetStatusBarColor(0.1, 0.55, 0.9)
  local barBg = bar:CreateTexture(nil, "BACKGROUND")
  barBg:SetAllPoints(bar)
  barBg:SetTexture(0, 0, 0, 0.6)
  bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  bar.text:SetPoint("CENTER", bar, "CENTER", 0, 0)
  self.rankBar = bar

  local charText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  charText:SetPoint("LEFT", bar, "RIGHT", 10, 0)
  charText:SetJustifyH("LEFT")
  self.headerChar = charText

  self.backButton = self:MakeButton("ProfessionalBackButton", f, "Back to me", 90, 18, function()
    CM.view.char = CM.player
    local profs = CM:CharProfessions(CM.char)
    local live = CM.live.trade.open and CM.live.trade.prof or (CM.live.craft.open and CM.live.craft.prof)
    CM.view.prof = live or profs[1]
    CM:Refresh(true)
  end)
  self.backButton:SetPoint("LEFT", charText, "RIGHT", 8, 0)
  self.backButton:Hide()

  -- profession switch buttons (top right)
  self.profButtons = {}
  for i = 1, 8 do
    local b = CreateFrame("Button", "ProfessionalProfButton" .. i, f)
    b:SetWidth(28); b:SetHeight(28)
    b:SetPoint("TOPRIGHT", f, "TOPRIGHT", -40 - (i - 1) * 32, -18)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetAllPoints(b)
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    b.border = b:CreateTexture(nil, "OVERLAY")
    b.border:SetTexture("Interface\\Buttons\\CheckButtonHilight")
    b.border:SetBlendMode("ADD")
    b.border:SetAllPoints(b)
    b:SetScript("OnClick", function() CM:ProfButtonClick(this.prof, arg1) end)
    b:SetScript("OnEnter", function()
      GameTooltip:SetOwner(this, "ANCHOR_BOTTOMLEFT")
      GameTooltip:AddLine(this.prof, 1, 1, 1)
      if CM:IsViewingSelf() then
        GameTooltip:AddLine("Click: open the profession", 1, 0.82, 0)
        GameTooltip:AddLine("Right-click: browse saved recipes", 1, 0.82, 0)
      end
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:Hide()
    self.profButtons[i] = b
  end

  -- tabs
  self.tabButtons = {}
  local labels = { recipes = "Recipes", missing = "Missing", skillup = "Skill-up", shopping = "Queue & Shopping", alts = "Alts" }
  local x = 16
  for i = 1, table.getn(self.tabOrder) do
    local key = self.tabOrder[i]
    local w = (key == "shopping") and 130 or 92
    local b = self:MakeButton("ProfessionalTab" .. key, f, labels[key], w, 22, function() CM:SelectTab(this.key) end)
    b.key = key
    b:SetPoint("TOPLEFT", f, "TOPLEFT", x, -60)
    x = x + w + 4
    self.tabButtons[key] = b
  end

  -- left panel (list)
  local left = CreateFrame("Frame", "ProfessionalLeft", f)
  left:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -114)
  left:SetWidth(LIST_W + 8)
  left:SetHeight(LIST_ROWS * ROW_H + 10)
  left:SetBackdrop(PANEL_BACKDROP)
  left:SetBackdropColor(0, 0, 0, 0.5)
  left:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.8)
  self.leftPanel = left

  self.filterArea = CreateFrame("Frame", "ProfessionalFilterArea", f)
  self.filterArea:SetPoint("BOTTOMLEFT", left, "TOPLEFT", 0, 2)
  self.filterArea:SetWidth(W - 28)
  self.filterArea:SetHeight(24)

  self.list = self:MakeList("ProfessionalList", left, {
    rows = LIST_ROWS, rowHeight = ROW_H, width = LIST_W,
    render = function(row, d, sel) CM:Tab():Render(row, d, sel) end,
    click = function(d, button) CM:Tab():Click(d, button) end,
    enter = function(row, d) local t = CM:Tab(); if t.Enter then t:Enter(row, d) end end,
  })
  self.list:SetPoint("TOPLEFT", left, "TOPLEFT", 5, -5)

  -- right panel (detail)
  local right = CreateFrame("Frame", "ProfessionalRight", f)
  right:SetPoint("TOPLEFT", left, "TOPRIGHT", 6, 0)
  right:SetPoint("BOTTOMRIGHT", left, "BOTTOMRIGHT", W - LIST_W - 36, 0)
  right:SetBackdrop(PANEL_BACKDROP)
  right:SetBackdropColor(0, 0, 0, 0.5)
  right:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.8)
  self.rightPanel = right

  local dIcon = CreateFrame("Button", "ProfessionalDetailIcon", right)
  dIcon:SetWidth(36); dIcon:SetHeight(36)
  dIcon:SetPoint("TOPLEFT", right, "TOPLEFT", 8, -8)
  dIcon.tex = dIcon:CreateTexture(nil, "ARTWORK")
  dIcon.tex:SetAllPoints(dIcon)
  dIcon:SetScript("OnEnter", function() if CM.detailInfo and CM.detailInfo.iconTooltip then CM.detailInfo.iconTooltip(this) end end)
  dIcon:SetScript("OnLeave", function() GameTooltip:Hide() end)
  dIcon:SetScript("OnClick", function() if CM.detailInfo and CM.detailInfo.iconClick then CM.detailInfo.iconClick() end end)
  self.detailIcon = dIcon

  local dTitle = right:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  dTitle:SetPoint("TOPLEFT", dIcon, "TOPRIGHT", 8, -2)
  dTitle:SetPoint("RIGHT", right, "RIGHT", -8, 0)
  dTitle:SetJustifyH("LEFT")
  dTitle:SetHeight(16)
  self.detailTitle = dTitle

  local dSub = right:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  dSub:SetPoint("TOPLEFT", dTitle, "BOTTOMLEFT", 0, -3)
  dSub:SetPoint("RIGHT", right, "RIGHT", -8, 0)
  dSub:SetJustifyH("LEFT")
  self.detailSub = dSub

  self.detail = self:MakeList("ProfessionalDetail", right, {
    rows = DETAIL_ROWS, rowHeight = DETAIL_ROW_H, width = W - LIST_W - 52,
    font = "GameFontHighlightSmall",
    render = function(row, d)
      row.text:SetText(d.text or "")
      row.text:SetTextColor(1, 1, 1)
      if d.icon then row.icon:SetTexture(d.icon) end
      if d.right then row.right:SetText(d.right) end
    end,
    click = function(d, button) CM:DetailClick(d, button) end,
    enter = function(row, d) CM:DetailEnter(row, d) end,
  })
  self.detail:SetPoint("TOPLEFT", right, "TOPLEFT", 6, -50)
  CM.DETAIL_WIDTH = W - LIST_W - 90

  -- bottom
  self.bottomArea = CreateFrame("Frame", "ProfessionalBottomArea", f)
  self.bottomArea:SetPoint("TOPLEFT", left, "BOTTOMLEFT", 0, -6)
  self.bottomArea:SetWidth(W - 28)
  self.bottomArea:SetHeight(26)

  self.status = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  self.status:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -18, 14)
  self.status:SetJustifyH("RIGHT")

  for i = 1, table.getn(self.tabOrder) do
    local tab = self.Tabs[self.tabOrder[i]]
    tab.filter = CreateFrame("Frame", "ProfessionalFilter" .. self.tabOrder[i], self.filterArea)
    tab.filter:SetAllPoints(self.filterArea)
    tab.filter:Hide()
    tab.bottom = CreateFrame("Frame", "ProfessionalBottom" .. self.tabOrder[i], self.bottomArea)
    tab.bottom:SetAllPoints(self.bottomArea)
    tab.bottom:Hide()
    tab:Init()
  end
  self.currentTab = self.settings.lastTab or "recipes"
  if not self.Tabs[self.currentTab] then self.currentTab = "recipes" end
  return f
end

function CM:Tab()
  return self.Tabs[self.currentTab]
end

function CM:SelectTab(key)
  if not self.Tabs[key] then return end
  self.currentTab = key
  self.settings.lastTab = key
  self:Refresh(true)
end

------------------------------------------------------------------------
-- Refresh
------------------------------------------------------------------------
function CM:Refresh(resetScroll)
  if not self.frame or not self.frame:IsVisible() then return end
  if not self.view.prof then
    local profs = self:CharProfessions(self:ViewChar())
    self.view.prof = profs[1]
  end
  self:UpdateHeader()
  for key, b in pairs(self.tabButtons) do
    if key == self.currentTab then b:LockHighlight() else b:UnlockHighlight() end
  end
  for i = 1, table.getn(self.tabOrder) do
    local k = self.tabOrder[i]
    local tab = self.Tabs[k]
    if k == self.currentTab then tab.filter:Show(); tab.bottom:Show() else tab.filter:Hide(); tab.bottom:Hide() end
  end
  local tab = self:Tab()
  local data = tab:Build() or {}
  -- keep the selection when its row is still there
  local sel
  if tab.selectedKey then
    for i = 1, table.getn(data) do
      if data[i].id == tab.selectedKey then sel = data[i]; break end
    end
  end
  self.list.selected = sel
  self.list:SetData(data, not resetScroll)
  if sel then
    tab:Detail(sel)
  else
    tab.selectedKey = nil
    tab:Detail(nil)
  end
  if tab.UpdateBottom then tab:UpdateBottom() end
end

function CM:RefreshSoon()
  self:Schedule("refresh", 0.15, function() CM:Refresh() end)
end

function CM:Select(d)
  local tab = self:Tab()
  tab.selectedKey = d and d.id
  self.list.selected = d
  self.list:Update()
  tab:Detail(d)
  if tab.UpdateBottom then tab:UpdateBottom() end
end

function CM:UpdateHeader()
  local prof = self.view.prof
  local char, charName = self:ViewChar()
  self.headerIcon:SetTexture(prof and self:ProfIcon(prof) or "Interface\\Icons\\INV_Misc_QuestionMark")
  local rank, max = self:ViewSkill()
  local live = self:ViewLive()
  self.headerText:SetText((prof or "No profession") .. (live and "" or " |cff999999(saved)|r"))
  if rank and max and max > 0 then
    self.rankBar:SetMinMaxValues(0, max)
    self.rankBar:SetValue(rank)
    self.rankBar.text:SetText(rank .. " / " .. max)
    self.rankBar:Show()
  else
    self.rankBar:Hide()
  end
  if not self:IsViewingSelf() then
    local cc = RAID_CLASS_COLORS and RAID_CLASS_COLORS[char.class or ""]
    local hex = cc and CM.Hex(cc) or "|cffffffff"
    self.headerChar:SetText("Viewing " .. hex .. charName .. "|r")
    self.backButton:Show()
  else
    self.headerChar:SetText(live and "" or "|cff999999Click an icon on the right to open a profession|r")
    self.backButton:Hide()
  end
  local profs = self:CharProfessions(char)
  for i = 1, table.getn(self.profButtons) do
    local b = self.profButtons[i]
    local p = profs[i]
    if p then
      b.prof = p
      b.tex:SetTexture(self:ProfIcon(p))
      if p == prof then b.border:Show() else b.border:Hide() end
      b:Show()
    else
      b:Hide()
    end
  end
end

function CM:ProfButtonClick(prof, button)
  if not prof then return end
  if self:IsViewingSelf() and button ~= "RightButton" then
    local open = (self.live.trade.open and self.live.trade.prof == prof) or (self.live.craft.open and self.live.craft.prof == prof)
    if not open then
      self.view.prof = prof
      self.pendingProf = prof
      CastSpellByName(CM.PROF_SPELL[prof] or prof)
    end
  end
  self.view.prof = prof
  self:Refresh(true)
end

------------------------------------------------------------------------
-- Detail pane
------------------------------------------------------------------------
-- info = { icon, title, sub, lines, iconTooltip(frame), iconClick() }
function CM:SetDetail(info)
  info = info or {}
  self.detailInfo = info
  if info.icon then
    self.detailIcon.tex:SetTexture(info.icon)
    self.detailIcon:Show()
  else
    self.detailIcon:Hide()
  end
  self.detailTitle:SetText(info.title or "")
  self.detailSub:SetText(info.sub or "")
  local keep = (self.lastDetailTitle == info.title) and info.title ~= nil
  self.lastDetailTitle = info.title
  self.detail:SetData(self:WrapLines(info.lines or {}, CM.DETAIL_WIDTH), keep)
end

function CM:DetailEnter(row, d)
  if d.live then
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    self.API[d.live.mode].tooltip(GameTooltip, d.live.index, d.live.j)
    GameTooltip:Show()
  elseif d.item then
    self:ShowItemTooltip(row, d.item)
  elseif d.tip then
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:AddLine(d.tip, 1, 1, 1, 1)
    GameTooltip:Show()
  end
end

function CM:DetailClick(d, button)
  if d.item and IsShiftKeyDown() and ChatFrameEditBox and ChatFrameEditBox:IsVisible() then
    local link = self:ItemChatLink(d.item)
    if link then ChatFrameEditBox:Insert(link) end
    return
  end
  if d.onClick then d.onClick(button) end
end

-- Only ask the client for item tooltips it already has cached (unknown items can disconnect a 1.12 client)
function CM:ShowItemTooltip(owner, id)
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  if self:ItemInfo(id) then
    GameTooltip:SetHyperlink("item:" .. id .. ":0:0:0")
  else
    GameTooltip:AddLine(self:ItemName(id), 1, 1, 1)
    GameTooltip:AddLine("Not seen by this client yet.", 0.6, 0.6, 0.6)
    GameTooltip:Show()
  end
end

-- Shared recipe detail (Recipes, Missing, Skill-up, Queue tabs)
-- ctx: { mode, index, char, skill, top = {lines}, multiplier, sourcesFirst }
function CM:RecipeDetail(rec, ctx)
  ctx = ctx or {}
  local L = {}
  local function add(text, extra)
    local e = extra or {}
    e.text = text
    table.insert(L, e)
  end
  local api = ctx.mode and self.API[ctx.mode]

  if ctx.top then
    for i = 1, table.getn(ctx.top) do table.insert(L, ctx.top[i]) end
  end

  if rec.y then
    local s = string.format("Skill-ups: |cffff8040%d|r  |cffffff00%d|r  |cff40c040%d|r  |cff808080%d|r", rec.learn or 0, rec.y, rec.g, rec.gr)
    if ctx.skill then
      local c = self:Chance(rec, ctx.skill)
      if c > 0 then
        s = s .. string.format("    |cffffffff%d%% chance at %d|r", math.floor(c * 100 + 0.5), ctx.skill)
      elseif rec.learn and ctx.skill >= rec.learn then
        s = s .. "    |cff808080no more skill-ups|r"
      end
    end
    add(s)
  elseif rec.learn then
    add("Learned at skill " .. rec.learn)
  end
  if rec.yieldMin and rec.yieldMax then
    if rec.yieldMin == rec.yieldMax then add("Makes " .. rec.yieldMin) else add("Makes " .. rec.yieldMin .. "-" .. rec.yieldMax) end
  end
  local tools = api and api.tools(ctx.index)
  if tools and table.getn(tools) > 0 then
    add("|cffffd100Requires:|r " .. table.concat(tools, ", "))
  elseif rec.cache and rec.cache.tl then
    add("|cffffd100Requires:|r " .. rec.cache.tl)
  end
  if api then
    local cd = api.cooldown(ctx.index)
    if cd and cd > 0 then
      local h = math.floor(cd / 3600)
      local m = math.floor(math.mod(cd, 3600) / 60)
      add("|cffff4040Cooldown:|r " .. (h > 0 and (h .. "h ") or "") .. m .. "m")
    end
  end

  local function sources()
    add(" ")
    add("|cffffd100How to learn|r")
    local src = self:SourceLines(rec)
    for i = 1, table.getn(src) do table.insert(L, src[i]) end
  end
  if ctx.sourcesFirst then sources() end

  local mult = ctx.multiplier or 1
  local char = ctx.char or self.char
  local isSelf = (char == self.char)
  if api then
    local n = api.numReagents(ctx.index)
    if n > 0 then
      add(" ")
      add(mult > 1 and ("|cffffd100Reagents|r (for " .. mult .. ")") or "|cffffd100Reagents|r")
      for j = 1, n do
        local name, tex, count = api.reagent(ctx.index, j)
        local id = CM.ItemId(api.reagentLink(ctx.index, j))
        local line = self:ReagentLine(id, name, tex, (count or 1) * mult, char, isSelf)
        line.live = { mode = ctx.mode, index = ctx.index, j = j }
        table.insert(L, line)
      end
    end
  elseif rec.reagents and table.getn(rec.reagents) > 0 then
    add(" ")
    add(mult > 1 and ("|cffffd100Reagents|r (for " .. mult .. ")") or "|cffffd100Reagents|r")
    for j = 1, table.getn(rec.reagents), 2 do
      local id, count = rec.reagents[j], rec.reagents[j + 1] or 1
      table.insert(L, self:ReagentLine(id, nil, nil, count * mult, char, isSelf))
    end
  end

  if api then
    local desc = api.desc(ctx.index)
    if desc and desc ~= "" then
      add(" ")
      add("|cffbbbbbb" .. desc .. "|r")
    end
  end

  if not ctx.sourcesFirst and not ctx.noSources then sources() end
  return L
end

function CM:ReagentLine(id, name, tex, need, char, isSelf)
  name = name or self:ItemName(id)
  tex = tex or self:ItemIcon(id) or "Interface\\Icons\\INV_Misc_QuestionMark"
  local bags = (char.bags and char.bags[id]) or 0
  local bank = (char.bank and char.bank[id]) or 0
  local alts = 0
  if isSelf then
    local _, _, a = self:ItemCounts(id)
    alts = a
  end
  local color = "|cffff4040"
  if bags >= need then color = "|cff40ff40" elseif bags + bank >= need then color = "|cffffff00" end
  local right = color .. bags .. "|r/" .. need
  if bank > 0 then right = right .. " |cff999999bank " .. bank .. "|r" end
  if alts > 0 then right = right .. " |cff999999alts " .. alts .. "|r" end
  local tag = ""
  if self:ItemSoldByVendor(id) then tag = " |cff80c0ff(vendor)|r" end
  return { icon = tex, text = need .. " x " .. self:ItemQualityHex(id) .. name .. "|r" .. tag, right = right, item = id }
end

------------------------------------------------------------------------
-- Opening and closing
------------------------------------------------------------------------
function CM:Show()
  if not self.ready then return end
  self:CreateUI()
  self.frame:Show()
  self:Refresh(true)
end

function CM:Toggle()
  if not self.ready then return end
  self:CreateUI()
  if self.frame:IsVisible() then
    self.frame:Hide()
  else
    self.view.char = self.player
    local live = (self.live.trade.open and self.live.trade.prof) or (self.live.craft.open and self.live.craft.prof)
    self.view.prof = live or self.view.prof or self.settings.lastProf
    local profs = self:CharProfessions(self.char)
    if self.view.prof and not self.char.profs[self.view.prof] and not (self.char.skills and self.char.skills[self.view.prof]) then
      self.view.prof = profs[1]
    end
    self:Show()
  end
end

function CM:OnWindowHidden()
  if self.view.prof then self.settings.lastProf = self.view.prof end
  if not self.settings.replaceWindow then return end
  self.hiding = true
  if self.live.trade.open then CloseTradeSkill() end
  if self.live.craft.open and self.craftIsOurs then CloseCraft() end
  self.hiding = false
end

function CM:LiveOpened(mode)
  local L = self.live[mode]
  L.open = true
  if mode == "trade" then
    if SetTradeSkillSubClassFilter then SetTradeSkillSubClassFilter(0, 1, 1) end
    if SetTradeSkillInvSlotFilter then SetTradeSkillInvSlotFilter(0, 1, 1) end
  end
  local snap = self:ScanLive(mode)
  if not snap then return end
  L.lastProf = snap.prof
  if self.settings.replaceWindow then
    self:CreateUI()
    self.view.char = self.player
    self.view.prof = snap.prof
    if self.currentTab == "alts" then self.currentTab = "recipes" end
    if self.frame:IsVisible() then self:Refresh(true) else self:Show() end
  else
    self:RefreshSoon()
  end
end

function CM:LiveClosed(mode)
  local L = self.live[mode]
  local wasViewed = L.open and self:IsViewingSelf() and L.prof == self.view.prof
  L.open = false
  L.snap = nil
  if mode == "craft" then self.craftIsOurs = false end
  if not self.frame or not self.frame:IsVisible() or self.hiding then return end
  if wasViewed then
    local other = (mode == "trade") and self.live.craft or self.live.trade
    if other.open and other.prof then
      self.view.prof = other.prof
      self:Refresh(true)
    elseif self.settings.replaceWindow and not self.keepOpen then
      self.frame:Hide()
    else
      self:Refresh()
    end
  else
    self:Refresh()
  end
end

function CM:LiveUpdated(mode)
  local L = self.live[mode]
  if not L.open then return end
  self:Schedule("live" .. mode, 0.1, function()
    if not L.open then return end
    local snap = CM:ScanLive(mode)
    if not snap then return end
    if snap.prof ~= L.lastProf then
      L.lastProf = snap.prof
      if CM:IsViewingSelf() then CM.view.prof = snap.prof end
    end
    CM:Refresh()
  end)
end

CM:On("TRADE_SKILL_SHOW", function() CM:LiveOpened("trade") end)
CM:On("TRADE_SKILL_CLOSE", function() CM:LiveClosed("trade") end)
CM:On("TRADE_SKILL_UPDATE", function() CM:LiveUpdated("trade") end)

CM:On("CRAFT_SHOW", function()
  local skill = GetCraftDisplaySkillLine()
  if not skill then
    -- Beast Training (hunters) uses the craft window: leave it to the default UI
    CM.craftIsOurs = false
    if CM.settings.replaceWindow then
      if CraftFrame_LoadUI then CraftFrame_LoadUI() end
      if CraftFrame_Show then CraftFrame_Show() elseif CraftFrame then ShowUIPanel(CraftFrame) end
    end
    return
  end
  CM.craftIsOurs = true
  CM:LiveOpened("craft")
end)
CM:On("CRAFT_CLOSE", function() CM:LiveClosed("craft") end)
CM:On("CRAFT_UPDATE", function()
  if CM.craftIsOurs or GetCraftDisplaySkillLine() then
    CM.craftIsOurs = true
    CM:LiveUpdated("craft")
  end
end)

function CM:OnInventoryChanged()
  self.makers = nil
  if self.frame and self.frame:IsVisible() then self:RefreshSoon() end
end

function CM:OnQueueChanged()
  if self.frame and self.frame:IsVisible() then self:RefreshSoon() end
end
