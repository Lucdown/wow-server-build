-- CleanBars style + keybinds for the default action bars (WoW 2.4.3).
--   Flat square buttons with cropped icons, short hotkey text, gryphons/art hidden.
--   /cb bind   hover over ANY action button (default bars or CleanBars) and press a key to bind it.
--   /cb style  toggle the flat style   /cb art  toggle the default bar art   /cb size 0.8-1.4  default bars scale

local SOLID = "Interface\\ChatFrame\\ChatFrameBackground"
CleanBarsDB = CleanBarsDB or {}
local function Msg(t) DEFAULT_CHAT_FRAME:AddMessage("|cffffd100CleanBars:|r "..t) end
local function Busy() return InCombatLockdown and InCombatLockdown() end

-- Default bar buttons and their key binding commands
local GROUPS = {
  { "ActionButton", "ACTIONBUTTON" },
  { "BonusActionButton", "ACTIONBUTTON" },
  { "MultiBarBottomLeftButton", "MULTIACTIONBAR1BUTTON" },
  { "MultiBarBottomRightButton", "MULTIACTIONBAR2BUTTON" },
  { "MultiBarRightButton", "MULTIACTIONBAR3BUTTON" },
  { "MultiBarLeftButton", "MULTIACTIONBAR4BUTTON" },
}

local function ShortKey(key)
  if not key or key == "" then return "" end
  key = string.upper(key)
  key = string.gsub(key, "SHIFT%-", "S")
  key = string.gsub(key, "CTRL%-", "C")
  key = string.gsub(key, "ALT%-", "A")
  key = string.gsub(key, "MOUSEWHEELUP", "WU")
  key = string.gsub(key, "MOUSEWHEELDOWN", "WD")
  key = string.gsub(key, "BUTTON", "M")
  key = string.gsub(key, "NUMPAD", "N")
  key = string.gsub(key, "PAGEUP", "PU")
  key = string.gsub(key, "PAGEDOWN", "PD")
  key = string.gsub(key, "SPACE", "Sp")
  key = string.gsub(key, "INSERT", "Ins")
  key = string.gsub(key, "DELETE", "Del")
  key = string.gsub(key, "HOME", "Hm")
  return key
end

---------------------------------------------------------------------------------------------------
-- Flat style
---------------------------------------------------------------------------------------------------
local styled = {}
local function StyleButton(b)
  if not b or styled[b] then return end
  styled[b] = true
  local name = b:GetName()
  local icon = getglobal(name.."Icon")
  local nt = getglobal(name.."NormalTexture") or (b.GetNormalTexture and b:GetNormalTexture())
  if nt then nt:SetAlpha(0) end
  if icon then
    -- The icon lives on the BACKGROUND layer like our dark backing square, so the game could draw the square
    -- on top of it (greyed-out look). Lift the icon one layer up so it's always above the backing.
    if icon.SetDrawLayer then icon:SetDrawLayer("ARTWORK") end
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    icon:ClearAllPoints()
    icon:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
  end
  local border = getglobal(name.."Border")   -- green "equipped item" border
  if border then border:SetAlpha(0.6) end
  local bg = b:CreateTexture(nil, "BACKGROUND")
  bg:SetPoint("TOPLEFT", b, "TOPLEFT", -1, 1)
  bg:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 1, -1)
  bg:SetTexture(SOLID)
  bg:SetVertexColor(0, 0, 0, 0.85)
  b.cbBg = bg
  local hk = getglobal(name.."HotKey")
  if hk then
    hk:SetFont("Fonts\\ARIALN.TTF", 11, "OUTLINE")
    hk:ClearAllPoints()
    hk:SetPoint("TOPRIGHT", b, "TOPRIGHT", -1, -2)
  end
  local mn = getglobal(name.."Name")
  if mn then mn:SetFont("Fonts\\ARIALN.TTF", 9, "OUTLINE") end
  local ct = getglobal(name.."Count")
  if ct then ct:SetFont("Fonts\\ARIALN.TTF", 12, "OUTLINE") end
end

local function FixHotkey(b)
  if not b then return end
  local hk = getglobal(b:GetName().."HotKey")
  if not hk then return end
  local t = hk:GetText()
  if t and t ~= "" and t ~= RANGE_INDICATOR then hk:SetText(ShortKey(t)) end
end

local function StyleAll()
  if CleanBarsDB.styleOff then return end
  for _, g in ipairs(GROUPS) do
    for i = 1, 12 do
      local b = getglobal(g[1]..i)
      if b then StyleButton(b) FixHotkey(b) end
    end
  end
  for i = 1, 10 do
    StyleButton(getglobal("ShapeshiftButton"..i))
    StyleButton(getglobal("PetActionButton"..i))
  end
end

local function HideArt()
  if CleanBarsDB.artOn then return end
  for _, n in ipairs({ "MainMenuBarLeftEndCap", "MainMenuBarRightEndCap", "MainMenuBarTexture0", "MainMenuBarTexture1",
                       "MainMenuBarTexture2", "MainMenuBarTexture3", "BonusActionBarTexture0", "BonusActionBarTexture1",
                       "ShapeshiftBarLeft", "ShapeshiftBarMiddle", "ShapeshiftBarRight", "SlidingActionBarTexture0",
                       "SlidingActionBarTexture1" }) do
    local t = getglobal(n)
    if t then t:SetAlpha(0) end
  end
end

local function ApplyScale()
  if Busy() then return end
  local s = CleanBarsDB.blizzScale or 1
  for _, n in ipairs({ "MainMenuBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft" }) do
    local f = getglobal(n)
    if f and f:GetParent() == UIParent then f:SetScale(s) end
  end
end

---------------------------------------------------------------------------------------------------
-- CleanBars buttons: show their hotkeys too
---------------------------------------------------------------------------------------------------
local function UpdateCleanBarsHotkeys()
  for bar = 1, 30 do
    for i = 1, 12 do
      local b = getglobal("CleanBars"..bar.."Button"..i)
      if b then
        if not b.cbHotkey then
          b.cbHotkey = b:CreateFontString(nil, "OVERLAY")
          b.cbHotkey:SetFont("Fonts\\ARIALN.TTF", 11, "OUTLINE")
          b.cbHotkey:SetPoint("TOPRIGHT", b, "TOPRIGHT", -2, -2)
          b.cbHotkey:SetTextColor(0.8, 0.8, 0.8)
        end
        b.cbHotkey:SetText(ShortKey(GetBindingKey("CLICK "..b:GetName()..":LeftButton")))
      end
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Hover-to-bind mode
---------------------------------------------------------------------------------------------------
local binder

local function TargetUnderMouse()
  local f = GetMouseFocus and GetMouseFocus()
  if not f or not f.GetName or not f:GetName() then return end
  local name = f:GetName()
  for _, g in ipairs(GROUPS) do
    local n = string.match(name, "^"..g[1].."(%d+)$")
    if n then return { command = g[2]..n, label = name } end
  end
  if string.match(name, "^CleanBars%d+Button%d+$") then
    return { click = name, command = "CLICK "..name..":LeftButton", label = name }
  end
end

local function ClearKeys(command)
  local k1, k2 = GetBindingKey(command)
  if k1 then SetBinding(k1) end
  if k2 then SetBinding(k2) end
end

local function OnKey(self, key)
  if key == "ESCAPE" then binder:Hide() return end
  if key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" or key == "RCTRL" or key == "LALT" or key == "RALT"
     or key == "UNKNOWN" then return end
  local t = TargetUnderMouse()
  if not t then binder.info:SetText("Hover over an action button first.") return end
  if key == "BACKSPACE" then
    ClearKeys(t.command)
    binder.info:SetText("Cleared keys for "..t.label)
  else
    local combo = (IsAltKeyDown() and "ALT-" or "")..(IsControlKeyDown() and "CTRL-" or "")..(IsShiftKeyDown() and "SHIFT-" or "")..key
    if t.click then SetBindingClick(combo, t.click, "LeftButton") else SetBinding(combo, t.command) end
    binder.info:SetText("|cff33ff99"..combo.."|r  ->  "..t.label)
  end
  SaveBindings(GetCurrentBindingSet())
  UpdateCleanBarsHotkeys()
end

local function StartBinding()
  if Busy() then Msg("Wait until combat ends.") return end
  if not binder then
    binder = CreateFrame("Frame", "CleanBarsBinder", UIParent)
    binder:SetFrameStrata("DIALOG")
    binder:SetWidth(420) binder:SetHeight(58)
    binder:SetPoint("TOP", UIParent, "TOP", 0, -120)
    binder:SetBackdrop({ bgFile=SOLID, edgeFile=SOLID, edgeSize=1, insets={ left=1, right=1, top=1, bottom=1 } })
    binder:SetBackdropColor(0.05, 0.05, 0.06, 0.95)
    binder:SetBackdropBorderColor(1, 0.82, 0, 0.9)
    local t = binder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t:SetPoint("TOP", binder, "TOP", 0, -10)
    t:SetText("Key binding mode: hover a button and press a key")
    binder.info = binder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    binder.info:SetPoint("TOP", t, "BOTTOM", 0, -6)
    binder:EnableKeyboard(true)
    binder:SetScript("OnKeyDown", OnKey)
    binder:SetScript("OnHide", function() Msg("Key binding mode off. Bindings saved.") end)
  end
  binder.info:SetText("Backspace clears a button.  Esc to finish.")
  binder:Show()
end

---------------------------------------------------------------------------------------------------
-- Commands for /cb (called from CleanBars.lua)
---------------------------------------------------------------------------------------------------
CleanBarsExtra = {}
function CleanBarsExtra.Command(msg)
  local cmd, arg = string.match(msg or "", "^(%S*)%s*(.-)$")
  if cmd == "bind" then StartBinding() return true
  elseif cmd == "style" then
    CleanBarsDB.styleOff = not CleanBarsDB.styleOff
    Msg("Flat button style "..(CleanBarsDB.styleOff and "off" or "on").." after /rl.") return true
  elseif cmd == "art" then
    CleanBarsDB.artOn = not CleanBarsDB.artOn
    Msg("Default bar art (gryphons) "..(CleanBarsDB.artOn and "shown" or "hidden").." after /rl.") return true
  elseif cmd == "size" and tonumber(arg) then
    CleanBarsDB.blizzScale = math.max(0.6, math.min(1.5, tonumber(arg)))
    ApplyScale()
    Msg("Default bars scale: "..CleanBarsDB.blizzScale) return true
  end
  return false
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("UPDATE_BINDINGS")
ev:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
ev:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
ev:SetScript("OnEvent", function(self, event)
  event = event or _G.event
  if event == "PLAYER_LOGIN" then
    StyleAll() HideArt() ApplyScale() UpdateCleanBarsHotkeys()
    if hooksecurefunc and ActionButton_UpdateHotkeys then
      hooksecurefunc("ActionButton_UpdateHotkeys", function() if this and not CleanBarsDB.styleOff then FixHotkey(this) end end)
    end
  elseif event == "UPDATE_BINDINGS" then
    UpdateCleanBarsHotkeys()
    StyleAll()
  else
    StyleAll()
  end
end)
