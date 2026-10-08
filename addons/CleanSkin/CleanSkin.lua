-- CleanSkin: one visual identity for Blizzard's windows - the same flat dark panels, thin borders and gold
-- titles used by the Toolkit, bags, bars and Escape menu. Only the look changes; every button still works
-- exactly the same. /cskin off (then /reload) turns it off.

CleanSkinDB = CleanSkinDB or {}
local SOLID = "Interface\\ChatFrame\\ChatFrameBackground"
local ACCENT = { 1, 0.82, 0 }
local BG = { 0.05, 0.05, 0.06, 0.95 }
local BORDER = { 0.22, 0.22, 0.25, 1 }
local done = {}

local function Flat(f, a)
  if not f or not f.SetBackdrop then return end
  f:SetBackdrop({ bgFile = SOLID, edgeFile = SOLID, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
  f:SetBackdropColor(BG[1], BG[2], BG[3], a or BG[4])
  f:SetBackdropBorderColor(BORDER[1], BORDER[2], BORDER[3], BORDER[4])
end

-- the grey/red Blizzard push buttons (UIPanelButtonTemplate) -> flat buttons
local function FlatButton(btn)
  if not btn or done[btn] or not btn.GetObjectType or btn:GetObjectType() ~= "Button" then return end
  local name = btn:GetName()
  local isPanelButton = name and getglobal(name.."Left") and getglobal(name.."Middle") and getglobal(name.."Right")
  if not isPanelButton then return end
  done[btn] = true
  for _, part in ipairs({ "Left", "Middle", "Right" }) do getglobal(name..part):SetAlpha(0) end
  for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
    local t = btn[getter] and btn[getter](btn)
    if t then t:SetAlpha(0) end
  end
  Flat(btn, 1)
  btn:SetBackdropColor(0.12, 0.12, 0.14, 1)
  btn:HookScript("OnEnter", function()
    btn:SetBackdropColor(0.2, 0.2, 0.23, 1)
    btn:SetBackdropBorderColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.8)
  end)
  btn:HookScript("OnLeave", function()
    btn:SetBackdropColor(0.12, 0.12, 0.14, 1)
    btn:SetBackdropBorderColor(BORDER[1], BORDER[2], BORDER[3], 1)
  end)
end

-- dialog-style windows: flat panel, hide the parchment header, gold title, flat buttons
local function SkinDialog(name)
  local f = getglobal(name)
  if not f or done[f] then return end
  done[f] = true
  Flat(f)
  for _, r in ipairs({ f:GetRegions() }) do
    if r.GetObjectType and r:GetObjectType() == "Texture" then
      r:SetAlpha(0)
    elseif r.GetObjectType and r:GetObjectType() == "FontString" then
      local p = r:GetPoint()
      if p == "TOP" then r:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3]) end
    end
  end
  for _, c in ipairs({ f:GetChildren() }) do FlatButton(c) end
end

local function SkinTooltip(tt)
  if not tt then return end
  Flat(tt, 0.92)
  if not done[tt] then
    done[tt] = true
    tt:HookScript("OnShow", function(self)
      self = self or tt
      self:SetBackdropColor(BG[1], BG[2], BG[3], 0.92)
      -- keep Blizzard's quality-colored border if an item set one, otherwise use ours
      local r, g, b = self:GetBackdropBorderColor()
      if r and r > 0.95 and g > 0.95 and b > 0.95 then self:SetBackdropBorderColor(BORDER[1], BORDER[2], BORDER[3], 1) end
    end)
  end
end

local DIALOGS = {
  "StaticPopup1", "StaticPopup2", "StaticPopup3", "StaticPopup4",
  "OptionsFrame", "SoundOptionsFrame", "UIOptionsFrame", "VideoOptionsFrame", "AudioOptionsFrame",
  "InterfaceOptionsFrame", "ColorPickerFrame", "OpacityFrame", "ItemTextFrame",
  "ReadyCheckFrame", "LFGParentFrame", "GuildRegistrarFrame", "TabardFrame",
}

local function SkinAll()
  if CleanSkinDB.off then return end
  for _, n in ipairs(DIALOGS) do SkinDialog(n) end
  for _, t in ipairs({ GameTooltip, ItemRefTooltip, ShoppingTooltip1, ShoppingTooltip2, WorldMapTooltip }) do SkinTooltip(t) end
  for i = 1, 3 do
    local list = getglobal("DropDownList"..i.."Backdrop")
    if list then Flat(list) end
    local menu = getglobal("DropDownList"..i.."MenuBackdrop")
    if menu then Flat(menu) end
  end
  if ChatFrameEditBox then
    for _, part in ipairs({ "Left", "Mid", "Right" }) do
      local t = getglobal("ChatFrameEditBox"..part) if t then t:SetAlpha(0) end
    end
    Flat(ChatFrameEditBox, 0.85)
  end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("ADDON_LOADED")   -- load-on-demand Blizzard windows (key bindings, macros...)
ev:SetScript("OnEvent", function(self, event, name)
  event = event or _G.event
  name = name or arg1
  if CleanSkinDB.off then return end
  if event == "PLAYER_LOGIN" then
    SkinAll()
  elseif event == "ADDON_LOADED" then
    if name == "Blizzard_BindingUI" then SkinDialog("KeyBindingFrame") end
    if name == "Blizzard_MacroUI" then SkinDialog("MacroPopupFrame") end
  end
end)

SLASH_CLEANSKIN1 = "/cskin"
SlashCmdList["CLEANSKIN"] = function(msg)
  msg = string.lower(msg or "")
  if msg == "off" then CleanSkinDB.off = true DEFAULT_CHAT_FRAME:AddMessage("|cffffd100CleanSkin:|r off after /reload")
  elseif msg == "on" then CleanSkinDB.off = false DEFAULT_CHAT_FRAME:AddMessage("|cffffd100CleanSkin:|r on after /reload") end
end
