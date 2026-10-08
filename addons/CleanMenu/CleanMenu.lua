-- CleanMenu: flat, modern look for the Escape menu, plus quick buttons for the Toolkit, meters and reload.
-- Only changes how things look; every Blizzard button still does exactly what it did. /cmenu off to disable.

local SOLID = "Interface\\ChatFrame\\ChatFrameBackground"
CleanMenuDB = CleanMenuDB or {}

local ACCENT = { 1, 0.82, 0 }

local function Flat(frame, r, g, b, a, br, bg, bb)
  frame:SetBackdrop({ bgFile = SOLID, edgeFile = SOLID, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
  frame:SetBackdropColor(r, g, b, a)
  frame:SetBackdropBorderColor(br or 0.22, bg or 0.22, bb or 0.25, 1)
end

local function StyleButton(btn)
  if not btn or btn.cmStyled then return end
  btn.cmStyled = true
  for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
    local t = btn[getter] and btn[getter](btn)
    if t then t:SetTexture(nil) t:SetAlpha(0) end
  end
  local name = btn:GetName()
  for _, part in ipairs({ "Left", "Middle", "Right" }) do
    local t = name and getglobal(name..part)
    if t then t:SetAlpha(0) end
  end
  Flat(btn, 0.12, 0.12, 0.14, 1)
  btn:SetHeight(26)
  local fs = btn.GetFontString and btn:GetFontString()
  if fs then fs:SetFont("Fonts\\FRIZQT__.TTF", 12) fs:SetTextColor(0.92, 0.92, 0.92) end
  btn:HookScript("OnEnter", function()
    btn:SetBackdropColor(0.2, 0.2, 0.23, 1)
    btn:SetBackdropBorderColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.8)
  end)
  btn:HookScript("OnLeave", function()
    btn:SetBackdropColor(0.12, 0.12, 0.14, 1)
    btn:SetBackdropBorderColor(0.22, 0.22, 0.25, 1)
  end)
end

local function NewButton(parent, text, onClick)
  local b = CreateFrame("Button", nil, parent)
  b:SetWidth(144) b:SetHeight(26)
  Flat(b, 0.12, 0.12, 0.14, 1)
  local fs = b:CreateFontString(nil, "OVERLAY")
  fs:SetFont("Fonts\\FRIZQT__.TTF", 12)
  fs:SetTextColor(0.92, 0.92, 0.92)
  fs:SetPoint("CENTER", b, "CENTER", 0, 0)
  fs:SetText(text)
  b:SetScript("OnEnter", function() b:SetBackdropColor(0.2, 0.2, 0.23, 1) b:SetBackdropBorderColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.8) end)
  b:SetScript("OnLeave", function() b:SetBackdropColor(0.12, 0.12, 0.14, 1) b:SetBackdropBorderColor(0.22, 0.22, 0.25, 1) end)
  b:SetScript("OnClick", function() HideUIPanel(GameMenuFrame) onClick() end)
  return b
end

local function Style()
  if CleanMenuDB.off or not GameMenuFrame then return end
  local m = GameMenuFrame
  Flat(m, 0.05, 0.05, 0.06, 0.95)
  -- hide the parchment header and its text background
  for _, r in ipairs({ m:GetRegions() }) do
    if r.GetObjectType and r:GetObjectType() == "Texture" then r:SetAlpha(0) end
    if r.GetObjectType and r:GetObjectType() == "FontString" then
      r:ClearAllPoints()
      r:SetPoint("TOP", m, "TOP", 0, -10)
      r:SetFont("Fonts\\FRIZQT__.TTF", 14)
      r:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])
    end
  end
  local line = m:CreateTexture(nil, "OVERLAY")
  line:SetPoint("TOPLEFT", m, "TOPLEFT", 12, -30)
  line:SetPoint("TOPRIGHT", m, "TOPRIGHT", -12, -30)
  line:SetHeight(1)
  line:SetTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.6)
  for _, child in ipairs({ m:GetChildren() }) do
    if child.GetObjectType and child:GetObjectType() == "Button" then StyleButton(child) end
  end

  -- Side panel with quick buttons
  local side = CreateFrame("Frame", "CleanMenuSide", m)
  side:SetWidth(164)
  side:SetPoint("TOPLEFT", m, "TOPRIGHT", 6, 0)
  Flat(side, 0.05, 0.05, 0.06, 0.95)
  local t = side:CreateFontString(nil, "OVERLAY")
  t:SetFont("Fonts\\FRIZQT__.TTF", 14)
  t:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])
  t:SetPoint("TOP", side, "TOP", 0, -10)
  t:SetText("Quick")
  local items = {
    { "Toolkit (/gf)", function() if SlashCmdList.GEARFINDER then SlashCmdList.GEARFINDER("") end end },
    { "Damage meter", function() if SlashCmdList.CLEANMETER then SlashCmdList.CLEANMETER("") end end },
    { "Quest tracker", function() if SlashCmdList.CLEANQUESTS then SlashCmdList.CLEANQUESTS("show") end end },
    { "Bags", function() if ToggleBackpack then ToggleBackpack() end end },
    { "Key bindings mode", function() if SlashCmdList.CLEANBARS then SlashCmdList.CLEANBARS("bind") end end },
    { "Reload UI", function() ReloadUI() end },
  }
  for i, it in ipairs(items) do
    local b = NewButton(side, it[1], it[2])
    b:SetPoint("TOP", side, "TOP", 0, -36 - (i - 1) * 30)
  end
  side:SetHeight(44 + #items * 30)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function() Style() end)

SLASH_CLEANMENU1 = "/cmenu"
SlashCmdList["CLEANMENU"] = function(msg)
  msg = string.lower(msg or "")
  if msg == "off" then CleanMenuDB.off = true DEFAULT_CHAT_FRAME:AddMessage("|cffffd100CleanMenu:|r off after /rl")
  elseif msg == "on" then CleanMenuDB.off = false DEFAULT_CHAT_FRAME:AddMessage("|cffffd100CleanMenu:|r on after /rl") end
end
