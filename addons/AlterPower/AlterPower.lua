-- AlterPower: shows the mana, rage and energy bars your class doesn't normally have (Alteroth server).
-- The server sends the numbers (cloud build patch 006). Shift-drag to move, /apower to reset or hide.

local SOLID = "Interface\\ChatFrame\\ChatFrameBackground"
local W, H = 130, 10
local COLORS = { mana = { 0.2, 0.45, 1 }, rage = { 0.9, 0.15, 0.15 }, energy = { 1, 0.85, 0.1 } }
local ORDER = { "mana", "rage", "energy" }
local PRIMARY = { [0] = "mana", [1] = "rage", [3] = "energy" }

AlterPowerDB = AlterPowerDB or {}
local frame, bars = nil, {}
local values = {}
local lastUpdate = 0

local function Create()
  frame = CreateFrame("Frame", "AlterPowerFrame", UIParent)
  frame:SetWidth(W + 4)
  frame:SetHeight(3 * (H + 2) + 2)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:SetClampedToScreen(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function() if IsShiftKeyDown() then frame:StartMoving() end end)
  frame:SetScript("OnDragStop", function()
    frame:StopMovingOrSizing()
    local p, _, rp, x, y = frame:GetPoint()
    AlterPowerDB.pos = { p, rp, x, y }
  end)
  local pos = AlterPowerDB.pos
  if pos then frame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
  else frame:SetPoint("TOPLEFT", PlayerFrame or UIParent, "BOTTOMLEFT", 110, 32) end

  for i, kind in ipairs(ORDER) do
    local b = CreateFrame("StatusBar", nil, frame)
    b:SetWidth(W) b:SetHeight(H)
    b:SetStatusBarTexture(SOLID)
    local c = COLORS[kind]
    b:SetStatusBarColor(c[1], c[2], c[3], 0.95)
    b:SetMinMaxValues(0, 1)
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", b, "TOPLEFT", -1, 1)
    bg:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 1, -1)
    bg:SetTexture(SOLID)
    bg:SetVertexColor(0, 0, 0, 0.8)
    b.text = b:CreateFontString(nil, "OVERLAY")
    b.text:SetFont("Fonts\\ARIALN.TTF", 9, "OUTLINE")
    b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
    b:Hide()
    bars[kind] = b
  end
  frame:SetScript("OnEnter", function()
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Extra power bars", 1, 0.82, 0)
    GameTooltip:AddLine("Shift-drag to move.  /apower reset  |  /apower hide", 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
  if AlterPowerDB.hidden then frame:Hide() end
end

local function Layout()
  local y = -2
  for _, kind in ipairs(ORDER) do
    local b, v = bars[kind], values[kind]
    if v and v.max > 0 and kind ~= values.primary then
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, y)
      b:SetMinMaxValues(0, v.max)
      b:SetValue(v.cur)
      b.text:SetText(v.cur.." / "..v.max)
      b:Show()
      y = y - (H + 2)
    else
      b:Hide()
    end
  end
  frame:SetHeight(math.max(4, -y + 2))
end

local function OnAddon(prefix, msg)
  if prefix ~= "ALTPWR" or not msg then return end
  local m, mm, r, rm, e, em, pt = string.match(msg, "^(%d+);(%d+);(%d+);(%d+);(%d+);(%d+);(%d+)")
  if not m then return end
  values.mana = { cur = tonumber(m), max = tonumber(mm) }
  values.rage = { cur = tonumber(r), max = tonumber(rm) }
  values.energy = { cur = tonumber(e), max = tonumber(em) }
  values.primary = PRIMARY[tonumber(pt)]
  lastUpdate = GetTime()
  if frame and not AlterPowerDB.hidden then frame:Show() Layout() end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("CHAT_MSG_ADDON")
ev:SetScript("OnEvent", function(self, event, a1, a2, a3, a4)
  event = event or _G.event
  if event == "PLAYER_LOGIN" then
    Create()
    frame:Hide()      -- shows itself once the server sends numbers
  elseif event == "CHAT_MSG_ADDON" then
    OnAddon(a1 or arg1, a2 or arg2)
  end
end)

SLASH_ALTERPOWER1 = "/apower"
SlashCmdList["ALTERPOWER"] = function(msg)
  msg = string.lower(msg or "")
  if msg == "reset" then
    AlterPowerDB.pos = nil
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", PlayerFrame or UIParent, "BOTTOMLEFT", 110, 32)
  elseif msg == "hide" then
    AlterPowerDB.hidden = true frame:Hide()
  else
    AlterPowerDB.hidden = false
    if values.primary then frame:Show() Layout() end
    DEFAULT_CHAT_FRAME:AddMessage("|cffffd100AlterPower:|r shown. /apower hide | /apower reset. "..
      (lastUpdate > 0 and "" or "(No numbers from the server yet - it needs the newest cloud build.)"))
  end
end
