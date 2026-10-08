-- CleanBars: extra movable action bars for the WoW 2.4.3 client.
-- Drag items, spells or macros onto a button. Shift-drag a button to clear it.
-- "Consumables" bar fills itself with the food, drink, potions, elixirs, flasks, bandages and scrolls in your bags.
-- /cb (or click the bar header while unlocked) for settings. /cb unlock, /cb lock, /cb add, /cb reset.

local SOLID = "Interface\\ChatFrame\\ChatFrameBackground"
local SIZE, GAP = 34, 4
local MAX_BUTTONS = 12
local AUTO_TYPES = { ["Food & Drink"]=1, ["Potion"]=2, ["Elixir"]=3, ["Flask"]=4, ["Bandage"]=5, ["Scroll"]=6,
  ["Consumable"]=7, ["Other"]=8 }

CleanBarsDB = CleanBarsDB or {}
local db
local bars = {}
local unlocked = false
local pending = false  -- changes waiting for combat to end

local function Msg(t) DEFAULT_CHAT_FRAME:AddMessage("|cffffd100CleanBars:|r "..t) end
local function Busy() return InCombatLockdown and InCombatLockdown() end

local function DefaultBars()
  return {
    { name="Consumables", count=10, vertical=false, scale=1, auto=true, buttons={},
      pos={ "BOTTOM", "BOTTOM", 0, 150 } },
    { name="Mounts & Utility", count=8, vertical=false, scale=1, auto=false, buttons={},
      pos={ "BOTTOM", "BOTTOM", 0, 194 } },
  }
end

---------------------------------------------------------------------------------------------------
-- Buttons
---------------------------------------------------------------------------------------------------
local function ItemIdFromLink(link) return link and tonumber(string.match(link, "item:(%d+)")) end

local function ApplyAction(btn)
  local a = btn.action
  if Busy() then pending = true return end
  btn:SetAttribute("type", nil) btn:SetAttribute("item", nil) btn:SetAttribute("spell", nil) btn:SetAttribute("macro", nil)
  if a then
    if a.kind == "item" then btn:SetAttribute("type", "item") btn:SetAttribute("item", a.name)
    elseif a.kind == "spell" then btn:SetAttribute("type", "spell") btn:SetAttribute("spell", a.name)
    elseif a.kind == "macro" then btn:SetAttribute("type", "macro") btn:SetAttribute("macro", a.name) end
  end
end

local function UpdateButton(btn)
  local a = btn.action
  btn.count:SetText("")
  if not a then
    btn.icon:SetTexture(nil)
    btn.cooldown:Hide()
    btn.empty:Show()
    return
  end
  btn.empty:Hide()
  if a.kind == "item" then
    local _, _, _, _, _, _, _, _, _, tex = GetItemInfo(a.id or a.name)
    btn.icon:SetTexture(tex or a.tex or "Interface\\Icons\\INV_Misc_QuestionMark")
    local n = GetItemCount(a.name) or 0
    if n > 1 then btn.count:SetText(n) end
    if n == 0 then btn.icon:SetVertexColor(0.4, 0.4, 0.4) else btn.icon:SetVertexColor(1, 1, 1) end
    if a.id and GetItemCooldown then
      local s, d, e = GetItemCooldown(a.id)
      if s and d and d > 0 then CooldownFrame_SetTimer(btn.cooldown, s, d, e) btn.cooldown:Show() else btn.cooldown:Hide() end
    end
  elseif a.kind == "spell" then
    btn.icon:SetTexture(GetSpellTexture(a.name) or a.tex or "Interface\\Icons\\INV_Misc_QuestionMark")
    btn.icon:SetVertexColor(1, 1, 1)
    local s, d, e = GetSpellCooldown(a.name)
    if s and d and d > 1.5 then CooldownFrame_SetTimer(btn.cooldown, s, d, e) btn.cooldown:Show() else btn.cooldown:Hide() end
  elseif a.kind == "macro" then
    local _, tex = GetMacroInfo(a.name)
    btn.icon:SetTexture(tex or a.tex or "Interface\\Icons\\INV_Misc_QuestionMark")
    btn.icon:SetVertexColor(1, 1, 1)
    btn.cooldown:Hide()
  end
end

local function SetAction(btn, action)
  btn.action = action
  btn.cfg.buttons[btn.index] = action
  ApplyAction(btn)
  UpdateButton(btn)
end

local function TakeFromCursor(btn)
  if Busy() then Msg("Can't change buttons during combat.") return end
  local kind, a1, a2 = GetCursorInfo()
  local action
  if kind == "item" then
    local name, _, _, _, _, _, _, _, _, tex = GetItemInfo(a1)
    if name then action = { kind="item", id=a1, name=name, tex=tex } end
  elseif kind == "spell" then
    local name = GetSpellName(a1, a2)
    if name then action = { kind="spell", name=name, tex=GetSpellTexture(a1, a2) } end
  elseif kind == "macro" then
    local name, tex = GetMacroInfo(a1)
    if name then action = { kind="macro", name=name, tex=tex } end
  end
  if action then
    ClearCursor()
    SetAction(btn, action)
    if btn.cfg.auto then btn.cfg.auto = false Msg("Auto-fill turned off for \""..btn.cfg.name.."\" since you placed something yourself.") end
  end
end

local function CreateButton(bar, i)
  local name = "CleanBars"..bar.id.."Button"..i
  local b = CreateFrame("Button", name, bar, "SecureActionButtonTemplate")
  b:SetWidth(SIZE) b:SetHeight(SIZE)
  b:RegisterForClicks("AnyUp")
  b:RegisterForDrag("LeftButton")
  b.index = i
  b.cfg = bar.cfg

  b:SetBackdrop({ bgFile=SOLID, edgeFile=SOLID, edgeSize=1, insets={ left=1, right=1, top=1, bottom=1 } })
  b:SetBackdropColor(0.06, 0.06, 0.07, 0.8)
  b:SetBackdropBorderColor(0.25, 0.25, 0.28, 1)

  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
  b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
  b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  b.empty = b:CreateTexture(nil, "BACKGROUND")
  b.empty:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
  b.empty:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
  b.empty:SetTexture(1, 1, 1, 0.04)
  b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  b.count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
  b.cooldown = CreateFrame("Cooldown", name.."Cooldown", b, "CooldownFrameTemplate")
  b.cooldown:SetAllPoints(b.icon)
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints(b.icon)
  hl:SetTexture(1, 1, 1, 0.15)

  b:SetScript("OnReceiveDrag", function() TakeFromCursor(b) end)
  b:SetScript("OnDragStart", function()
    if IsShiftKeyDown() and not Busy() and b.action then
      local a = b.action
      if a.kind == "item" then PickupItem(a.id or a.name)
      elseif a.kind == "macro" then PickupMacro(a.name) end
      SetAction(b, nil)
      if b.cfg.auto then b.cfg.auto = false end
    end
  end)
  b:SetScript("PostClick", function()
    if GetCursorInfo() then TakeFromCursor(b) end
  end)
  b:SetScript("OnEnter", function()
    GameTooltip:SetOwner(b, "ANCHOR_TOPLEFT")
    local a = b.action
    if a and a.kind == "item" and a.id then GameTooltip:SetHyperlink("item:"..a.id..":0:0:0:0:0:0:0")
    elseif a then GameTooltip:AddLine(a.name, 1, 1, 1)
    else GameTooltip:AddLine("Empty slot", 0.7, 0.7, 0.7) GameTooltip:AddLine("Drag an item, spell or macro here", 0.6, 0.6, 0.6) end
    GameTooltip:AddLine("Shift-drag to remove", 0.5, 0.5, 0.5)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return b
end

---------------------------------------------------------------------------------------------------
-- Bars
---------------------------------------------------------------------------------------------------
local Layout, Refresh, AutoFill, OpenSettings

local function SavePos(bar)
  local point, _, relPoint, x, y = bar:GetPoint()
  bar.cfg.pos = { point, relPoint, x, y }
end

function Layout(bar)
  if Busy() then pending = true return end
  local cfg = bar.cfg
  local n = math.max(1, math.min(MAX_BUTTONS, cfg.count))
  for i = 1, MAX_BUTTONS do
    local b = bar.buttons[i]
    b:ClearAllPoints()
    if i <= n then
      if cfg.vertical then b:SetPoint("TOP", bar, "TOP", 0, -GAP - (i - 1) * (SIZE + GAP))
      else b:SetPoint("LEFT", bar, "LEFT", GAP + (i - 1) * (SIZE + GAP), 0) end
      b:Show()
    else
      b:Hide()
    end
  end
  if cfg.vertical then bar:SetWidth(SIZE + GAP * 2) bar:SetHeight(n * (SIZE + GAP) + GAP)
  else bar:SetWidth(n * (SIZE + GAP) + GAP) bar:SetHeight(SIZE + GAP * 2) end
  bar:SetScale(cfg.scale or 1)
  bar:ClearAllPoints()
  bar:SetPoint(cfg.pos[1], UIParent, cfg.pos[2], cfg.pos[3], cfg.pos[4])
  if cfg.hidden then bar:Hide() else bar:Show() end
end

local function ShowMover(bar, show)
  if show then
    bar:SetBackdropColor(1, 0.82, 0, 0.18)
    bar:SetBackdropBorderColor(1, 0.82, 0, 0.9)
    bar.header:Show()
    bar:EnableMouse(true)
  else
    bar:SetBackdropColor(0, 0, 0, 0)
    bar:SetBackdropBorderColor(0, 0, 0, 0)
    bar.header:Hide()
    bar:EnableMouse(false)
  end
end

local function CreateBar(id, cfg)
  local bar = CreateFrame("Frame", "CleanBarsBar"..id, UIParent)
  bar.id, bar.cfg = id, cfg
  bar:SetMovable(true)
  bar:SetClampedToScreen(true)
  bar:SetBackdrop({ bgFile=SOLID, edgeFile=SOLID, edgeSize=1, insets={ left=1, right=1, top=1, bottom=1 } })
  bar:RegisterForDrag("LeftButton")
  bar:SetScript("OnDragStart", function() if unlocked and not Busy() then bar:StartMoving() end end)
  bar:SetScript("OnDragStop", function() bar:StopMovingOrSizing() SavePos(bar) end)

  -- Header shown while unlocked: name + settings button
  local header = CreateFrame("Button", nil, bar)
  header:SetHeight(16)
  header:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, 2)
  header:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", 0, 2)
  header:SetBackdrop({ bgFile=SOLID, tile=false })
  header:SetBackdropColor(0.1, 0.1, 0.11, 0.95)
  header.text = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  header.text:SetPoint("LEFT", header, "LEFT", 4, 0)
  header.gear = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  header.gear:SetPoint("RIGHT", header, "RIGHT", -4, 0)
  header.gear:SetText("settings")
  header:RegisterForDrag("LeftButton")
  header:SetScript("OnDragStart", function() if not Busy() then bar:StartMoving() end end)
  header:SetScript("OnDragStop", function() bar:StopMovingOrSizing() SavePos(bar) end)
  header:SetScript("OnClick", function() OpenSettings(bar) end)
  header:Hide()
  bar.header = header

  bar.buttons = {}
  for i = 1, MAX_BUTTONS do
    local b = CreateButton(bar, i)
    b.action = cfg.buttons[i]
    bar.buttons[i] = b
  end
  return bar
end

function Refresh()
  for _, bar in ipairs(bars) do
    bar.header.text:SetText(bar.cfg.name..(bar.cfg.auto and "  |cff33ff99(auto)|r" or ""))
    for i = 1, MAX_BUTTONS do UpdateButton(bar.buttons[i]) end
  end
end

-- Fill auto bars with the consumables currently in your bags (one button per item type)
function AutoFill()
  if Busy() then pending = true return end
  local found, seen = {}, {}
  for bag = 0, 4 do
    for slot = 1, GetContainerNumSlots(bag) do
      local id = ItemIdFromLink(GetContainerItemLink(bag, slot))
      if id and not seen[id] then
        local name, _, _, _, minLevel, itemType, subType, _, _, tex = GetItemInfo(id)
        if itemType == "Consumable" and AUTO_TYPES[subType or "Other"] then
          seen[id] = true
          table.insert(found, { kind="item", id=id, name=name, tex=tex, order=AUTO_TYPES[subType or "Other"], lvl=minLevel or 0 })
        end
      end
    end
  end
  table.sort(found, function(a, b) if a.order ~= b.order then return a.order < b.order end return a.lvl > b.lvl end)
  for _, bar in ipairs(bars) do
    if bar.cfg.auto then
      for i = 1, MAX_BUTTONS do
        local a = found[i]
        local b = bar.buttons[i]
        if a then a.order, a.lvl = nil, nil end
        local same = (b.action and a and b.action.id == a.id) or (not b.action and not a)
        if not same then SetAction(b, a) end
      end
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Settings window
---------------------------------------------------------------------------------------------------
local settings
local function FlatButton(parent, text, w)
  local b = CreateFrame("Button", nil, parent)
  b:SetWidth(w) b:SetHeight(22)
  b:SetBackdrop({ bgFile=SOLID, edgeFile=SOLID, edgeSize=1, insets={ left=1, right=1, top=1, bottom=1 } })
  b:SetBackdropColor(0.17, 0.17, 0.19, 1)
  b:SetBackdropBorderColor(0.3, 0.3, 0.33, 1)
  b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
  b.text:SetText(text)
  b:SetScript("OnEnter", function() b:SetBackdropColor(0.25, 0.25, 0.28, 1) end)
  b:SetScript("OnLeave", function() b:SetBackdropColor(0.17, 0.17, 0.19, 1) end)
  return b
end

function OpenSettings(bar)
  if not settings then
    settings = CreateFrame("Frame", "CleanBarsSettings", UIParent)
    settings:SetWidth(260) settings:SetHeight(196)
    settings:SetPoint("CENTER")
    settings:SetFrameStrata("DIALOG")
    settings:SetBackdrop({ bgFile=SOLID, edgeFile=SOLID, edgeSize=1, insets={ left=1, right=1, top=1, bottom=1 } })
    settings:SetBackdropColor(0.07, 0.07, 0.08, 0.97)
    settings:SetBackdropBorderColor(1, 0.82, 0, 0.8)
    settings:EnableMouse(true) settings:SetMovable(true) settings:RegisterForDrag("LeftButton")
    settings:SetScript("OnDragStart", function() settings:StartMoving() end)
    settings:SetScript("OnDragStop", function() settings:StopMovingOrSizing() end)
    table.insert(UISpecialFrames, "CleanBarsSettings")
    settings.title = settings:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    settings.title:SetPoint("TOPLEFT", settings, "TOPLEFT", 12, -10)
    local close = FlatButton(settings, "X", 22)
    close:SetPoint("TOPRIGHT", settings, "TOPRIGHT", -6, -6)
    close:SetScript("OnClick", function() settings:Hide() end)

    local function row(y, label)
      local t = settings:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      t:SetPoint("TOPLEFT", settings, "TOPLEFT", 12, y - 5)
      t:SetText(label)
      return t
    end
    row(-36, "Buttons")
    settings.countText = settings:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    settings.countText:SetPoint("TOPLEFT", settings, "TOPLEFT", 150, -40)
    local minus = FlatButton(settings, "-", 26) minus:SetPoint("TOPLEFT", settings, "TOPLEFT", 116, -36)
    local plus = FlatButton(settings, "+", 26) plus:SetPoint("TOPLEFT", settings, "TOPLEFT", 176, -36)
    row(-64, "Scale")
    settings.scaleText = settings:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    settings.scaleText:SetPoint("TOPLEFT", settings, "TOPLEFT", 146, -68)
    local sminus = FlatButton(settings, "-", 26) sminus:SetPoint("TOPLEFT", settings, "TOPLEFT", 116, -64)
    local splus = FlatButton(settings, "+", 26) splus:SetPoint("TOPLEFT", settings, "TOPLEFT", 176, -64)
    settings.rotate = FlatButton(settings, "", 236) settings.rotate:SetPoint("TOPLEFT", settings, "TOPLEFT", 12, -94)
    settings.auto = FlatButton(settings, "", 236) settings.auto:SetPoint("TOPLEFT", settings, "TOPLEFT", 12, -120)
    settings.hide = FlatButton(settings, "", 115) settings.hide:SetPoint("TOPLEFT", settings, "TOPLEFT", 12, -146)
    local del = FlatButton(settings, "Delete bar", 115) del:SetPoint("TOPLEFT", settings, "TOPLEFT", 133, -146)
    local hint = settings:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("BOTTOMLEFT", settings, "BOTTOMLEFT", 12, 8)
    hint:SetText("Drag the bar's header to move it.  /cb lock when done.")

    local function redraw()
      local c = settings.bar.cfg
      settings.title:SetText(c.name)
      settings.countText:SetText(c.count)
      settings.scaleText:SetText(string.format("%.1f", c.scale or 1))
      settings.rotate.text:SetText(c.vertical and "Layout: vertical (click for horizontal)" or "Layout: horizontal (click for vertical)")
      settings.auto.text:SetText(c.auto and "Auto-fill consumables: ON" or "Auto-fill consumables: off")
      settings.hide.text:SetText(c.hidden and "Show bar" or "Hide bar")
    end
    local function change(fn)
      if Busy() then Msg("Can't change bars during combat.") return end
      fn(settings.bar.cfg)
      Layout(settings.bar) AutoFill() Refresh() redraw()
    end
    minus:SetScript("OnClick", function() change(function(c) c.count = math.max(1, c.count - 1) end) end)
    plus:SetScript("OnClick", function() change(function(c) c.count = math.min(MAX_BUTTONS, c.count + 1) end) end)
    sminus:SetScript("OnClick", function() change(function(c) c.scale = math.max(0.5, (c.scale or 1) - 0.1) end) end)
    splus:SetScript("OnClick", function() change(function(c) c.scale = math.min(2, (c.scale or 1) + 0.1) end) end)
    settings.rotate:SetScript("OnClick", function() change(function(c) c.vertical = not c.vertical end) end)
    settings.auto:SetScript("OnClick", function() change(function(c) c.auto = not c.auto end) end)
    settings.hide:SetScript("OnClick", function() change(function(c) c.hidden = not c.hidden end) end)
    del:SetScript("OnClick", function()
      if Busy() then return end
      settings.bar.cfg.deleted = true
      settings.bar:Hide()
      settings:Hide()
      Msg("Bar deleted. It's gone after /rl.")
    end)
    settings.redraw = redraw
  end
  settings.bar = bar
  settings.redraw()
  settings:Show()
end

---------------------------------------------------------------------------------------------------
-- Setup and events
---------------------------------------------------------------------------------------------------
local function Init()
  db = CleanBarsDB
  db.bars = db.bars or DefaultBars()
  for i, cfg in ipairs(db.bars) do
    if not cfg.deleted then
      cfg.buttons = cfg.buttons or {}
      local bar = CreateBar(i, cfg)
      table.insert(bars, bar)
      Layout(bar)
      ShowMover(bar, false)
      for j = 1, MAX_BUTTONS do ApplyAction(bar.buttons[j]) end
    end
  end
  AutoFill()
  Refresh()
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "VARIABLES_LOADED", "PLAYER_ENTERING_WORLD", "BAG_UPDATE", "BAG_UPDATE_COOLDOWN",
  "SPELL_UPDATE_COOLDOWN", "ACTIONBAR_UPDATE_COOLDOWN", "PLAYER_REGEN_ENABLED", "UPDATE_MACROS" }) do
  ev:RegisterEvent(e)
end
local dirtyBags = false
ev:SetScript("OnEvent", function(self, event)
  event = event or _G.event
  if event == "VARIABLES_LOADED" then Init() return end
  if not db then return end
  if event == "BAG_UPDATE" or event == "PLAYER_ENTERING_WORLD" then dirtyBags = true end
  if event == "PLAYER_REGEN_ENABLED" and pending then
    pending = false
    for _, bar in ipairs(bars) do Layout(bar) for i = 1, MAX_BUTTONS do ApplyAction(bar.buttons[i]) end end
    dirtyBags = true
  end
  Refresh()
end)
local acc = 0
ev:SetScript("OnUpdate", function(self, elapsed)
  acc = acc + (elapsed or arg1 or 0)
  if acc < 0.5 then return end
  acc = 0
  if dirtyBags and db then dirtyBags = false AutoFill() Refresh() end
end)

SLASH_CLEANBARS1 = "/cb"
SLASH_CLEANBARS2 = "/cleanbars"
SlashCmdList["CLEANBARS"] = function(msg)
  msg = string.lower(msg or "")
  if not db then return end
  if Busy() then Msg("Wait until combat ends.") return end
  if msg == "lock" then
    unlocked = false
    for _, bar in ipairs(bars) do ShowMover(bar, false) end
    if settings then settings:Hide() end
    Msg("Bars locked.")
  elseif msg == "add" then
    local cfg = { name="Bar "..(#db.bars + 1), count=8, vertical=false, scale=1, auto=false, buttons={},
      pos={ "CENTER", "CENTER", 0, 0 } }
    table.insert(db.bars, cfg)
    local bar = CreateBar(#db.bars, cfg)
    table.insert(bars, bar)
    Layout(bar) Refresh()
    unlocked = true
    for _, b in ipairs(bars) do ShowMover(b, true) end
    Msg("New bar added in the middle of your screen. Drag its header to move it.")
  elseif CleanBarsExtra and CleanBarsExtra.Command(msg) then
    return
  elseif msg == "reset" then
    db.bars = nil
    Msg("Bars reset to default after /rl.")
  else
    unlocked = true
    for _, bar in ipairs(bars) do ShowMover(bar, true) end
    Msg("Bars unlocked: drag a header to move a bar, click it for settings. /cb lock when done. /cb add for a new bar.")
    Msg("/cb bind = hover-and-press key binding | /cb size 0.8-1.4 = default bars size | /cb style | /cb art")
  end
end
