-- CleanPlates: flat, readable enemy health bars for the WoW 2.4.3 client.
-- Bigger bars, health percent, level with elite/boss markers, highlighted target, shown automatically.
-- /cp toggles friendly nameplates, /cp off disables the restyle (after /rl).

local SOLID = "Interface\\ChatFrame\\ChatFrameBackground"
local BAR_W, BAR_H = 130, 11

CleanPlatesDB = CleanPlatesDB or {}

local function IsNameplate(frame)
  if frame:GetName() then return false end
  for _, r in ipairs({ frame:GetRegions() }) do
    if r.GetObjectType and r:GetObjectType() == "Texture" then
      local tex = r:GetTexture()
      if tex and string.find(tex, "Nameplate%-Border") then return true end
    end
  end
  return false
end

local function Skin(frame)
  local health = frame:GetChildren()
  if not health or not health.GetStatusBarColor then return end

  local p = {}
  frame.cp = p
  p.health = health

  -- Sort the plate's own regions by what they are
  local fonts = {}
  for _, r in ipairs({ frame:GetRegions() }) do
    if r:GetObjectType() == "FontString" then
      table.insert(fonts, r)
    elseif r:GetObjectType() == "Texture" then
      local tex = r:GetTexture() or ""
      if string.find(tex, "Skull") then p.boss = r
      elseif string.find(tex, "RaidTargetingIcon") then p.raid = r
      elseif string.find(tex, "Nameplate%-Border") then
        p.border = r
        r:SetAlpha(0)
      elseif string.find(tex, "Glow") or string.find(tex, "Highlight") then
        p.highlight = r
        r:SetTexture(nil)
      end
    end
  end
  p.name, p.level = fonts[1], fonts[2]

  -- Health bar
  health:ClearAllPoints()
  health:SetPoint("CENTER", frame, "CENTER", 0, -6)
  health:SetWidth(BAR_W) health:SetHeight(BAR_H)
  health:SetStatusBarTexture(SOLID)

  local bg = CreateFrame("Frame", nil, health)
  bg:SetPoint("TOPLEFT", health, "TOPLEFT", -1, 1)
  bg:SetPoint("BOTTOMRIGHT", health, "BOTTOMRIGHT", 1, -1)
  bg:SetFrameLevel(health:GetFrameLevel() - 1)
  bg:SetBackdrop({ bgFile=SOLID, edgeFile=SOLID, edgeSize=1, insets={ left=1, right=1, top=1, bottom=1 } })
  bg:SetBackdropColor(0.05, 0.05, 0.05, 0.85)
  bg:SetBackdropBorderColor(0, 0, 0, 1)
  p.bg = bg

  p.pct = health:CreateFontString(nil, "OVERLAY")
  p.pct:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
  p.pct:SetPoint("RIGHT", health, "RIGHT", -3, 0)

  if p.name then
    p.name:ClearAllPoints()
    p.name:SetPoint("BOTTOM", health, "TOP", 0, 3)
    p.name:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    p.name:SetWidth(BAR_W + 30)
  end
  if p.level then
    p.level:ClearAllPoints()
    p.level:SetPoint("RIGHT", health, "LEFT", -3, 0)
    p.level:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
  end
  if p.boss then p.boss:ClearAllPoints() p.boss:SetPoint("RIGHT", health, "LEFT", -2, 0) end
  if p.raid then p.raid:ClearAllPoints() p.raid:SetPoint("BOTTOM", p.name or health, "TOP", 0, 2) p.raid:SetWidth(18) p.raid:SetHeight(18) end
end

local function Update(frame)
  local p = frame.cp
  if not p or not frame:IsShown() then return end
  local h = p.health
  local v = h:GetValue() or 0
  local _, max = h:GetMinMaxValues()
  if max and max > 0 then
    local pct = math.floor(v / max * 100 + 0.5)
    p.pct:SetText(pct < 100 and (pct.."%") or "")
  end
  if p.border then
    p.border:SetAlpha(0)
    local elite = string.find(p.border:GetTexture() or "", "Elite") ~= nil
    if p.level and elite then
      local t = p.level:GetText() or ""
      if not string.find(t, "%+") then p.level:SetText(t.."+") end
    end
  end
  -- Highlight your target with a gold border
  local isTarget = UnitExists("target") and p.name and p.name:GetText() == UnitName("target")
  if isTarget then
    p.bg:SetBackdropBorderColor(1, 0.82, 0, 1)
  else
    p.bg:SetBackdropBorderColor(0, 0, 0, 1)
  end
end

local known, numChildren = {}, 0
local scanner = CreateFrame("Frame")
local acc = 0
scanner:SetScript("OnUpdate", function(self, elapsed)
  if CleanPlatesDB.off then return end
  acc = acc + (elapsed or arg1 or 0)
  if acc < 0.1 then return end
  acc = 0
  local n = WorldFrame:GetNumChildren()
  if n ~= numChildren then
    numChildren = n
    for _, f in ipairs({ WorldFrame:GetChildren() }) do
      if not known[f] and IsNameplate(f) then
        known[f] = true
        local ok = pcall(Skin, f)
        if not ok then f.cp = nil end
      end
    end
  end
  for f in pairs(known) do Update(f) end
end)

scanner:RegisterEvent("PLAYER_ENTERING_WORLD")
scanner:SetScript("OnEvent", function()
  if CleanPlatesDB.off then return end
  if ShowNameplates then ShowNameplates() end
  if CleanPlatesDB.friends and ShowFriendNameplates then ShowFriendNameplates() end
end)

SLASH_CLEANPLATES1 = "/cp"
SlashCmdList["CLEANPLATES"] = function(msg)
  msg = string.lower(msg or "")
  if msg == "off" then
    CleanPlatesDB.off = true
    DEFAULT_CHAT_FRAME:AddMessage("|cffffd100CleanPlates:|r off after /rl. /cp on to turn back on.")
  elseif msg == "on" then
    CleanPlatesDB.off = false
    DEFAULT_CHAT_FRAME:AddMessage("|cffffd100CleanPlates:|r on after /rl.")
  else
    CleanPlatesDB.friends = not CleanPlatesDB.friends
    if CleanPlatesDB.friends then
      if ShowFriendNameplates then ShowFriendNameplates() end
    else
      if HideFriendNameplates then HideFriendNameplates() end
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cffffd100CleanPlates:|r friendly nameplates "..(CleanPlatesDB.friends and "on" or "off")..".")
  end
end
