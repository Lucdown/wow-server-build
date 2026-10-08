-- CleanMove: move (and scale) the default UI pieces. Type /move to show the handles, drag them,
-- mouse wheel over a handle to resize, right-click a handle to put that piece back. /move again to finish.
-- /move reset puts everything back. Positions are saved per character. Nothing moves during combat.

CleanMoveDB = CleanMoveDB or {}
local SOLID = "Interface\\ChatFrame\\ChatFrameBackground"

-- { global frame name, label, reparent-to-UIParent? }
local FRAMES = {
  { "MainMenuBar", "Main action bar" },
  { "MultiBarBottomLeft", "Bottom left bar" },
  { "MultiBarBottomRight", "Bottom right bar" },
  { "MultiBarRight", "Right bar 1" },
  { "MultiBarLeft", "Right bar 2" },
  { "MainMenuExpBar", "XP bar", true },
  { "ReputationWatchBar", "Reputation bar", true },
  { "ShapeshiftBarFrame", "Stance / form bar", true },
  { "PetActionBarFrame", "Pet bar", true },
  { "PlayerFrame", "Player" },
  { "TargetFrame", "Target" },
  { "PartyMemberFrame1", "Party" },
  { "FocusFrame", "Focus" },
  { "MinimapCluster", "Minimap" },
  { "BuffFrame", "Buffs" },
  { "CastingBarFrame", "Cast bar", true },
  { "QuestWatchFrame", "Quest tracker" },
  { "DurabilityFrame", "Durability" },
  { "CharacterMicroButton", "Menu buttons" },
  { "MainMenuBarBackpackButton", "Bag buttons" },
}

local db
local handles = {}
local moving = false
local pending = false
local applying = false

local function Busy() return InCombatLockdown and InCombatLockdown() end
local function Msg(t) DEFAULT_CHAT_FRAME:AddMessage("|cffffd100CleanMove:|r "..t) end

local function Apply(name)
  local f = getglobal(name)
  local s = db[name]
  if not f or not s then return end
  if Busy() then pending = true return end
  applying = true
  if s.reparent and f:GetParent() ~= UIParent then f:SetParent(UIParent) end
  if s.scale then f:SetScale(s.scale) end
  -- saved spot is in screen (UIParent) units; SetPoint offsets are in the frame's own scale
  local rel = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
  if not rel or rel <= 0 then rel = 1 end
  f:ClearAllPoints()
  f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", s.x / rel, s.y / rel)
  if f.SetUserPlaced and f:IsMovable() then f:SetUserPlaced(true) end
  applying = false
end

local function ApplyAll()
  if Busy() then pending = true return end
  for name in pairs(db) do
    if type(db[name]) == "table" then Apply(name) end
  end
end

-- Blizzard re-positions some of these on its own (pet bar, stance bar, right bars...): put ours back after it.
local function HookBlizzard()
  for _, fn in ipairs({ "UIParent_ManageFramePositions", "ReputationWatchBar_Update", "MainMenuBar_UpdateExperienceBars" }) do
    if getglobal(fn) then hooksecurefunc(fn, function() if not applying then ApplyAll() end end) end
  end
end

local function MakeHandle(entry)
  local name, label, reparent = entry[1], entry[2], entry[3]
  local f = getglobal(name)
  if not f then return end
  local h = handles[name]
  if not h then
    h = CreateFrame("Button", nil, UIParent)
    h:SetFrameStrata("DIALOG")
    h:SetBackdrop({ bgFile = SOLID, edgeFile = SOLID, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
    h:SetBackdropColor(0.1, 0.5, 0.9, 0.35)
    h:SetBackdropBorderColor(0.3, 0.7, 1, 0.9)
    h:SetMovable(true)
    h:SetClampedToScreen(true)
    h:EnableMouse(true)
    h:EnableMouseWheel(true)
    h:RegisterForDrag("LeftButton")
    h:RegisterForClicks("RightButtonUp")
    h.text = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    h.text:SetPoint("CENTER", h, "CENTER", 0, 0)
    h.text:SetText(label)
    h:SetScript("OnDragStart", function() h:StartMoving() end)
    h:SetScript("OnDragStop", function()
      h:StopMovingOrSizing()
      local cx, cy = h:GetCenter()
      db[name] = db[name] or {}
      db[name].x, db[name].y = cx, cy
      db[name].scale = db[name].scale or f:GetScale()
      db[name].reparent = reparent and true or nil
      Apply(name)
      h:ClearAllPoints()
      h:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx, cy)
    end)
    h:SetScript("OnMouseWheel", function(_, delta)
      delta = delta or arg1
      if Busy() then return end
      local cx, cy = h:GetCenter()
      db[name] = db[name] or { x = cx, y = cy, reparent = reparent and true or nil }
      local sc = (db[name].scale or f:GetScale()) + (delta > 0 and 0.05 or -0.05)
      db[name].scale = math.max(0.5, math.min(2, sc))
      Apply(name)
      h:SetWidth(math.max(40, (f:GetWidth() or 40) * f:GetEffectiveScale() / UIParent:GetEffectiveScale()))
      h:SetHeight(math.max(16, (f:GetHeight() or 16) * f:GetEffectiveScale() / UIParent:GetEffectiveScale()))
    end)
    h:SetScript("OnClick", function()
      db[name] = nil
      Msg(label.." will go back to its normal spot after /reload.")
      h:Hide()
    end)
    h:SetScript("OnEnter", function()
      GameTooltip:SetOwner(h, "ANCHOR_TOP")
      GameTooltip:AddLine(label, 1, 0.82, 0)
      GameTooltip:AddLine("Drag to move. Mouse wheel to resize.", 0.8, 0.8, 0.8)
      GameTooltip:AddLine("Right-click to put it back (after /reload).", 0.8, 0.8, 0.8)
      GameTooltip:Show()
    end)
    h:SetScript("OnLeave", function() GameTooltip:Hide() end)
    handles[name] = h
  end
  local es = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
  local w, ht = (f:GetWidth() or 0) * es, (f:GetHeight() or 0) * es
  h:SetWidth(math.max(40, w)) h:SetHeight(math.max(16, ht))
  local cx, cy = f:GetCenter()
  h:ClearAllPoints()
  if cx then
    h:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx * es, cy * es)
  else
    h:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  end
  h:Show()
end

local function SetMoving(on)
  if on and Busy() then Msg("can't move things during combat.") return end
  moving = on
  for _, e in ipairs(FRAMES) do
    if on then MakeHandle(e) elseif handles[e[1]] then handles[e[1]]:Hide() end
  end
  Msg(on and "drag the blue boxes. Mouse wheel = size, right-click = reset that one. Type /move again when done."
         or "positions saved.")
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:SetScript("OnEvent", function(self, event)
  event = event or _G.event
  if event == "PLAYER_LOGIN" then
    db = CleanMoveDB
    HookBlizzard()
    ApplyAll()
  elseif event == "PLAYER_ENTERING_WORLD" then
    ApplyAll()
  elseif event == "PLAYER_REGEN_DISABLED" then
    if moving then SetMoving(false) end
  elseif event == "PLAYER_REGEN_ENABLED" then
    if pending then pending = false ApplyAll() end
  end
end)

SLASH_CLEANMOVE1 = "/move"
SLASH_CLEANMOVE2 = "/cmove"
SlashCmdList["CLEANMOVE"] = function(msg)
  msg = string.lower(msg or "")
  if msg == "reset" then
    for k in pairs(CleanMoveDB) do CleanMoveDB[k] = nil end
    Msg("everything goes back to normal - reloading.")
    ReloadUI()
  else
    SetMoving(not moving)
  end
end
