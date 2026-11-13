-- Professional: small UI building blocks (1.12 FrameXML templates only)

local CM = Professional

function CM:MakeButton(name, parent, text, w, h, onClick)
  local b = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
  b:SetWidth(w)
  b:SetHeight(h or 22)
  b:SetText(text)
  if onClick then b:SetScript("OnClick", onClick) end
  return b
end

function CM:SetTooltip(frame, title, text)
  frame:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_TOPLEFT")
    GameTooltip:AddLine(title, 1, 1, 1)
    if text then GameTooltip:AddLine(text, 1, 0.82, 0, 1) end
    GameTooltip:Show()
  end)
  frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

function CM:MakeCheck(name, parent, label, onClick, tip)
  local c = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
  c:SetWidth(22)
  c:SetHeight(22)
  local t = getglobal(name .. "Text")
  if t then t:SetText("") end
  c.label = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  c.label:SetPoint("LEFT", c, "RIGHT", 0, 1)
  c.label:SetText(label)
  c:SetScript("OnClick", function()
    onClick(this:GetChecked() and true or false)
  end)
  if tip then CM:SetTooltip(c, label, tip) end
  c.width = 26 + (string.len(label) * 5.5)
  return c
end

function CM:MakeEdit(name, parent, w, placeholder, onChange)
  local e = CreateFrame("EditBox", name, parent, "InputBoxTemplate")
  e:SetWidth(w)
  e:SetHeight(20)
  e:SetAutoFocus(false)
  e:SetFontObject(GameFontHighlightSmall)
  e.hint = e:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  e.hint:SetPoint("LEFT", e, "LEFT", 2, 0)
  e.hint:SetText(placeholder or "")
  e:SetScript("OnEscapePressed", function() this:SetText(""); this:ClearFocus() end)
  e:SetScript("OnEnterPressed", function() this:ClearFocus() end)
  e:SetScript("OnEditFocusGained", function() this.hasFocus = true; this.hint:Hide(); this:HighlightText() end)
  e:SetScript("OnEditFocusLost", function()
    this.hasFocus = nil
    this:HighlightText(0, 0)
    if this:GetText() == "" then this.hint:Show() end
  end)
  e:SetScript("OnTextChanged", function()
    if this:GetText() ~= "" then this.hint:Hide() elseif not this.hasFocus then this.hint:Show() end
    if onChange then onChange(this:GetText(), this.hasFocus) end
  end)
  return e
end

function CM:MakeText(parent, font, justify)
  local f = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
  f:SetJustifyH(justify or "LEFT")
  return f
end

------------------------------------------------------------------------
-- Scrolling list with fixed rows (FauxScrollFrame)
------------------------------------------------------------------------
-- opts: rows, rowHeight, width, render(row, data, selected), click(data, button), enter(row, data)
function CM:MakeList(name, parent, opts)
  local list = CreateFrame("Frame", name, parent)
  list:SetWidth(opts.width)
  list:SetHeight(opts.rows * opts.rowHeight)
  list.rows = {}
  list.data = {}
  list.opts = opts
  list:EnableMouseWheel(1)

  local scroll = CreateFrame("ScrollFrame", name .. "Scroll", list, "FauxScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", list, "TOPLEFT", 0, 0)
  scroll:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", -26, 0)
  scroll:SetScript("OnVerticalScroll", function()
    FauxScrollFrame_OnVerticalScroll(opts.rowHeight, function() list:Update() end)
  end)
  list.scroll = scroll
  list.scrollBar = getglobal(name .. "ScrollScrollBar")

  list:SetScript("OnMouseWheel", function()
    local bar = list.scrollBar
    if not bar or not scroll:IsShown() then return end
    local minV, maxV = bar:GetMinMaxValues()
    local v = bar:GetValue() - arg1 * opts.rowHeight * 3
    if v < minV then v = minV end
    if v > maxV then v = maxV end
    bar:SetValue(v)
  end)

  for i = 1, opts.rows do
    local row = CreateFrame("Button", name .. "Row" .. i, list)
    row:SetHeight(opts.rowHeight)
    row:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -(i - 1) * opts.rowHeight)
    row:SetPoint("RIGHT", list, "RIGHT", -28, 0)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    row:GetHighlightTexture():SetBlendMode("ADD")
    row:GetHighlightTexture():SetAlpha(0.5)

    row.sel = row:CreateTexture(nil, "BACKGROUND")
    row.sel:SetAllPoints(row)
    row.sel:SetTexture(1, 0.82, 0, 0.15)
    row.sel:Hide()

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetWidth(opts.rowHeight - 2)
    row.icon:SetHeight(opts.rowHeight - 2)
    row.icon:SetPoint("LEFT", row, "LEFT", 2, 0)
    row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    row.right = row:CreateFontString(nil, "OVERLAY", opts.rightFont or "GameFontHighlightSmall")
    row.right:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    row.right:SetJustifyH("RIGHT")

    row.text = row:CreateFontString(nil, "OVERLAY", opts.font or "GameFontNormalSmall")
    row.text:SetJustifyH("LEFT")
    row.text:SetHeight(opts.rowHeight)

    row:SetScript("OnClick", function()
      if this.data and opts.click then opts.click(this.data, arg1) end
    end)
    row:SetScript("OnEnter", function()
      if this.data and opts.enter then opts.enter(this, this.data) end
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:EnableMouseWheel(1)
    row:SetScript("OnMouseWheel", function() list:GetScript("OnMouseWheel")() end)
    list.rows[i] = row
  end

  function list:SetData(data, keepScroll)
    self.data = data or {}
    if not keepScroll then
      self.scroll.offset = 0
      if self.scrollBar then self.scrollBar:SetValue(0) end
    end
    self:Update()
  end

  function list:Update()
    local n = table.getn(self.data)
    FauxScrollFrame_Update(self.scroll, n, self.opts.rows, self.opts.rowHeight)
    local offset = FauxScrollFrame_GetOffset(self.scroll) or 0
    if offset > 0 and offset + 1 > n then
      offset = 0
      self.scroll.offset = 0
    end
    for i = 1, self.opts.rows do
      local row = self.rows[i]
      local d = self.data[offset + i]
      row.data = d
      if d then
        row.icon:SetTexture(nil)
        row.right:SetText("")
        row.text:SetTextColor(1, 0.82, 0)
        self.opts.render(row, d, d == self.selected)
        local hasIcon = row.icon:GetTexture() ~= nil
        if hasIcon then row.icon:Show() else row.icon:Hide() end
        row.text:ClearAllPoints()
        row.text:SetPoint("LEFT", row, "LEFT", (hasIcon and self.opts.rowHeight + 2 or 4) + (d.indent or 0), 0)
        row.text:SetPoint("RIGHT", row.right, "LEFT", -4, 0)
        if d == self.selected then row.sel:Show() else row.sel:Hide() end
        row:Show()
      else
        row:Hide()
      end
    end
  end

  return list
end

------------------------------------------------------------------------
-- Word wrapping (measured with a hidden font string, keeps colour codes)
------------------------------------------------------------------------
function CM:Measure(text)
  if not self.measureFS then
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetWidth(1); f:SetHeight(1)
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -2000, 2000)
    f:Show()
    self.measureFS = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.measureFS:SetPoint("TOPLEFT", f, "TOPLEFT")
  end
  self.measureFS:SetText(text)
  local w = self.measureFS:GetStringWidth()
  if not w or w <= 0 then
    local plain = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
    plain = string.gsub(plain, "|r", "")
    w = string.len(plain) * 5.6
  end
  return w
end

local function lastColor(s, current)
  local i = 1
  while true do
    local a = string.find(s, "|[cr]", i)
    if not a then break end
    if string.sub(s, a + 1, a + 1) == "c" then
      current = string.sub(s, a, a + 9)
      i = a + 10
    else
      current = nil
      i = a + 2
    end
  end
  return current
end

-- Wrap one line table {text=...} into several, copying extra fields to the first piece
function CM:WrapLine(line, width)
  local out = {}
  local text = line.text or ""
  local _, _, lead = string.find(text, "^( *)")
  lead = lead or ""
  local color
  local current = ""
  local first = true
  local function push(s)
    local t
    if first then
      t = {}
      for k, v in pairs(line) do t[k] = v end
      first = false
    else
      t = { cont = true }
    end
    t.text = s
    table.insert(out, t)
  end
  local any = false
  for word in string.gfind(text, "%S+") do
    any = true
    local test = (current == "") and (lead .. word) or (current .. " " .. word)
    if current ~= "" and self:Measure(test) > width then
      push(current)
      current = lead .. "  " .. (color or "") .. word
    else
      current = test
    end
    color = lastColor(word, color)
  end
  if not any then current = "" end
  push(current)
  return out
end

function CM:WrapLines(lines, width)
  local out = {}
  for i = 1, table.getn(lines) do
    local l = lines[i]
    if l.icon then
      table.insert(out, l)
    else
      local w = self:WrapLine(l, width)
      for j = 1, table.getn(w) do table.insert(out, w[j]) end
    end
  end
  return out
end
