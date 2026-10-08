-- CleanSpellbook: an "Other Classes" tab inside your spellbook (the book icon under your spell school tabs on
-- the right edge). It lists every spell you learned that isn't from your own class (codexes, tomes, .learn).
-- Drag (or click) a spell to put it on an action bar. Click any other spellbook tab to go back. /csb opens it.

local SOLID = "Interface\\ChatFrame\\ChatFrameBackground"
local ROWS = 12          -- two columns of six, like the real spellbook pages
local DATA = CleanSpellbook_Class or {}

CleanSpellbookDB = CleanSpellbookDB or {}

local panel, tab, rows, list, page = nil, nil, {}, {}, 1
local active = false
local myClass
local dirty = true

local function Busy() return InCombatLockdown and InCombatLockdown() end

-- Which other class teaches this spell?
local function OwnerClass(name)
  for cls, names in pairs(DATA) do
    if cls ~= myClass and names[name] then return cls end
  end
end

local CLASS_NAME = { WARRIOR="Warrior", PALADIN="Paladin", HUNTER="Hunter", ROGUE="Rogue", PRIEST="Priest",
  SHAMAN="Shaman", MAGE="Mage", WARLOCK="Warlock", DRUID="Druid" }

local function Collect()
  list = {}
  local mine = DATA[myClass] or {}
  local best = {}
  local tabs = GetNumSpellTabs() or 0
  for t = 1, tabs do
    local _, _, offset, num = GetSpellTabInfo(t)
    for i = offset + 1, offset + num do
      local name, rank = GetSpellName(i, BOOKTYPE_SPELL)
      if name and not mine[name] then
        local cls = OwnerClass(name)
        if cls then best[name] = { index = i, name = name, rank = rank or "", cls = cls } end  -- later = higher rank
      end
    end
  end
  for _, e in pairs(best) do table.insert(list, e) end
  table.sort(list, function(a, b) if a.cls ~= b.cls then return a.cls < b.cls end return a.name < b.name end)
end

local function Refresh()
  if not panel or not active then return end
  if dirty then Collect() dirty = false end
  local pages = math.max(1, math.ceil(#list / ROWS))
  if page > pages then page = pages end
  for r = 1, ROWS do
    local row = rows[r]
    local e = list[(page - 1) * ROWS + r]
    row.entry = e
    if e then
      row.icon:SetTexture(GetSpellTexture(e.index, BOOKTYPE_SPELL))
      row.text:SetText(e.name)
      local passive = IsPassiveSpell and IsPassiveSpell(e.index, BOOKTYPE_SPELL)
      row.sub:SetText((CLASS_NAME[e.cls] or e.cls)..(e.rank ~= "" and ("  "..e.rank) or "")..(passive and "  (passive)" or ""))
      local s, d = GetSpellCooldown(e.index, BOOKTYPE_SPELL)
      if s and d and d > 1.5 then CooldownFrame_SetTimer(row.cd, s, d, 1) row.cd:Show() else row.cd:Hide() end
      row:Show()
    else
      row:Hide()
    end
  end
  panel.pageText:SetText(#list == 0 and "No spells from other classes yet." or ("Page "..page.." of "..pages))
  if page > 1 then panel.prev:Enable() else panel.prev:Disable() end
  if page < pages then panel.nextb:Enable() else panel.nextb:Disable() end
end

-- Blizzard pieces our page covers while it's open
local function BlizzardPieces()
  local t = {}
  for i = 1, 12 do local b = getglobal("SpellButton"..i) if b then table.insert(t, b) end end
  for _, n in ipairs({ "SpellBookPrevPageButton", "SpellBookNextPageButton", "SpellBookPageText" }) do
    local o = getglobal(n) if o then table.insert(t, o) end
  end
  return t
end

local function SetActive(on)
  if not panel then return end
  active = on
  if on then
    for _, o in ipairs(BlizzardPieces()) do o:Hide() end
    panel:Show()
    tab:SetChecked(1)
    -- un-highlight the spell school tabs
    for i = 1, 8 do local t = getglobal("SpellBookSkillLineTab"..i) if t and t.SetChecked then t:SetChecked(nil) end end
    Refresh()
  else
    panel:Hide()
    tab:SetChecked(nil)
    if SpellBookFrame:IsShown() and SpellBookFrame_Update then SpellBookFrame_Update() end
  end
end

local function PlaceTab()
  if not tab then return end
  local n = GetNumSpellTabs() or 1
  local anchor = getglobal("SpellBookSkillLineTab"..n)
  tab:ClearAllPoints()
  if anchor then tab:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -17)
  else tab:SetPoint("TOPLEFT", SpellBookFrame, "TOPRIGHT", -32, -65) end
  if SpellBookFrame.bookType and SpellBookFrame.bookType ~= BOOKTYPE_SPELL then tab:Hide() else tab:Show() end
end

local function Create()
  -- the page sits exactly where the 12 spell buttons are
  panel = CreateFrame("Frame", "CleanSpellbookPanel", SpellBookFrame)
  panel:SetPoint("TOPLEFT", SpellButton1, "TOPLEFT", -4, 22)
  panel:SetPoint("BOTTOMRIGHT", SpellButton12, "BOTTOMRIGHT", 118, -26)
  panel:SetFrameLevel(SpellBookFrame:GetFrameLevel() + 2)
  panel:Hide()

  local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -2)
  title:SetText("Other Classes")

  for r = 1, ROWS do
    local row = CreateFrame("Frame", nil, panel)
    row:SetWidth(150) row:SetHeight(40)
    -- same order as the real book: left, right, left, right...
    local col, line = (r - 1) % 2, math.floor((r - 1) / 2)
    local ref = getglobal("SpellButton"..r)
    if ref then row:SetPoint("TOPLEFT", ref, "TOPLEFT", 0, 0)
    else row:SetPoint("TOPLEFT", panel, "TOPLEFT", 4 + col * 160, -22 - line * 48) end
    local btn = CreateFrame("Button", "CleanSpellbookRow"..r, row)
    btn:SetWidth(36) btn:SetHeight(36)
    btn:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    btn:RegisterForClicks("AnyUp")
    btn:RegisterForDrag("LeftButton")
    row.icon = btn:CreateTexture(nil, "ARTWORK")
    row.icon:SetAllPoints(btn)
    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(btn)
    hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    hl:SetBlendMode("ADD")
    row.cd = CreateFrame("Cooldown", "CleanSpellbookRow"..r.."Cooldown", btn, "CooldownFrameTemplate")
    row.cd:SetAllPoints(btn)
    local function pick() if row.entry then PickupSpell(row.entry.index, BOOKTYPE_SPELL) end end
    btn:SetScript("OnDragStart", pick)
    btn:SetScript("OnClick", pick)
    btn:SetScript("OnEnter", function()
      if not row.entry then return end
      GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
      GameTooltip:SetSpell(row.entry.index, BOOKTYPE_SPELL)
      GameTooltip:AddLine("Drag or click to put it on an action bar", 0.5, 0.5, 0.5)
      GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.btn = btn
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.text:SetPoint("TOPLEFT", btn, "TOPRIGHT", 4, -4)
    row.text:SetWidth(112) row.text:SetJustifyH("LEFT")
    row.sub = row:CreateFontString(nil, "OVERLAY", "SubSpellFont")
    row.sub:SetPoint("TOPLEFT", row.text, "BOTTOMLEFT", 0, -2)
    row.sub:SetWidth(112) row.sub:SetJustifyH("LEFT")
    rows[r] = row
  end

  panel.prev = CreateFrame("Button", nil, panel)
  panel.prev:SetWidth(32) panel.prev:SetHeight(32)
  panel.prev:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, -6)
  panel.prev:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
  panel.prev:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
  panel.prev:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Disabled")
  panel.prev:SetScript("OnClick", function() if page > 1 then page = page - 1 Refresh() end end)
  panel.nextb = CreateFrame("Button", nil, panel)
  panel.nextb:SetWidth(32) panel.nextb:SetHeight(32)
  panel.nextb:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, -6)
  panel.nextb:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
  panel.nextb:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
  panel.nextb:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Disabled")
  panel.nextb:SetScript("OnClick", function() page = page + 1 Refresh() end)
  panel.pageText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  panel.pageText:SetPoint("BOTTOM", panel, "BOTTOM", 0, 4)

  -- the tab: looks like the spell school tabs on the right edge of the book
  tab = CreateFrame("CheckButton", "CleanSpellbookTab", SpellBookFrame)
  tab:SetWidth(32) tab:SetHeight(32)
  local bg = tab:CreateTexture(nil, "BACKGROUND")
  bg:SetTexture("Interface\\SpellBook\\SpellBook-SkillLineTab")
  bg:SetWidth(64) bg:SetHeight(64)
  bg:SetPoint("TOPLEFT", tab, "TOPLEFT", -3, 11)
  tab:SetNormalTexture("Interface\\Icons\\INV_Misc_Book_09")
  tab:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
  tab:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight")
  tab:SetScript("OnClick", function() SetActive(not active) end)
  tab:SetScript("OnEnter", function()
    GameTooltip:SetOwner(tab, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Other Classes")
    GameTooltip:AddLine("Spells you learned from other classes", 0.8, 0.8, 0.8)
    GameTooltip:Show()
  end)
  tab:SetScript("OnLeave", function() GameTooltip:Hide() end)

  -- leave our page whenever you pick something else in the book, or close it
  if SpellBookSkillLineTab_OnClick then hooksecurefunc("SpellBookSkillLineTab_OnClick", function() if active then SetActive(false) end end) end
  if ToggleSpellBook then hooksecurefunc("ToggleSpellBook", function() if active then SetActive(false) end PlaceTab() end) end
  if SpellBookFrame_Update then hooksecurefunc("SpellBookFrame_Update", function()
    PlaceTab()
    if active then for _, o in ipairs(BlizzardPieces()) do o:Hide() end end
  end) end
  SpellBookFrame:HookScript("OnHide", function() if active then SetActive(false) end end)
  SpellBookFrame:HookScript("OnShow", PlaceTab)
  PlaceTab()
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("SPELLS_CHANGED")
ev:RegisterEvent("LEARNED_SPELL_IN_TAB")
ev:RegisterEvent("SPELL_UPDATE_COOLDOWN")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function(self, event)
  event = event or _G.event
  if event == "PLAYER_LOGIN" then
    local _, cls = UnitClass("player")
    myClass = cls
    Create()
  elseif event == "SPELLS_CHANGED" or event == "LEARNED_SPELL_IN_TAB" then
    dirty = true
    Refresh()
  else
    Refresh()
  end
end)

SLASH_CLEANSPELLBOOK1 = "/csb"
SlashCmdList["CLEANSPELLBOOK"] = function()
  if not SpellBookFrame:IsShown() then ToggleSpellBook(BOOKTYPE_SPELL) end
  SetActive(true)
end
