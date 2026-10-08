-- CleanMeter: a small damage / healing meter for you, your party (bots included) and pets. WoW 2.4.3.
-- Click the title to switch Damage / Healing, the segment text to switch Current fight / Overall.
-- Hover a bar for that member's top spells. /cm (show/hide), /cm reset, /cm lock.

local SOLID = "Interface\\ChatFrame\\ChatFrameBackground"
local BAR_H, BARS, WIDTH = 16, 8, 230

CleanMeterDB = CleanMeterDB or {}
local db

local MINE, PARTY, RAID = 0x1, 0x2, 0x4
local TYPE_PET, TYPE_GUARDIAN = 0x1000, 0x2000
local GROUP_MASK = MINE + PARTY + RAID

local CLASS_COLOR = RAID_CLASS_COLORS or {}

local overall = { start = nil, time = 0, members = {} }
local current = nil      -- active or last fight
local inFight, lastActivity = false, 0
local mode, segment = "damage", "current"
local petOwner = {}      -- pet GUID -> owner name
local classOf = {}       -- name -> class token

local function Now() return GetTime() end

local function NewSegment() return { start = Now(), time = 0, members = {} } end

local function Member(seg, name)
  local m = seg.members[name]
  if not m then
    m = { damage = 0, healing = 0, spells = { damage = {}, healing = {} } }
    seg.members[name] = m
  end
  return m
end

local function Add(name, kind, amount, spell)
  if not amount or amount <= 0 then return end
  if not inFight then
    inFight = true
    current = NewSegment()
    if not overall.start then overall.start = Now() end
  end
  lastActivity = Now()
  for _, seg in ipairs({ current, overall }) do
    local m = Member(seg, name)
    m[kind] = m[kind] + amount
    spell = spell or "Melee"
    m.spells[kind][spell] = (m.spells[kind][spell] or 0) + amount
  end
end

local function RefreshRoster()
  petOwner = {}
  local function note(unit, petUnit)
    if UnitExists(unit) then
      local n = UnitName(unit)
      local _, cls = UnitClass(unit)
      if n then classOf[n] = cls end
      if UnitExists(petUnit) and UnitGUID then
        local g = UnitGUID(petUnit)
        if g then petOwner[g] = n end
      end
    end
  end
  note("player", "pet")
  for i = 1, 4 do note("party"..i, "partypet"..i) end
  for i = 1, 40 do if UnitExists("raid"..i) then note("raid"..i, "raidpet"..i) end end
end

local function SourceName(guid, name, flags)
  if not flags or bit.band(flags, GROUP_MASK) == 0 then return nil end
  if bit.band(flags, TYPE_PET + TYPE_GUARDIAN) > 0 then
    local owner = petOwner[guid]
    if owner then return owner end
    return name and (name.." (pet)") or nil
  end
  return name
end

local DAMAGE = { SWING_DAMAGE = true, RANGE_DAMAGE = true, SPELL_DAMAGE = true, SPELL_PERIODIC_DAMAGE = true,
  DAMAGE_SHIELD = true, DAMAGE_SPLIT = true }
local HEAL = { SPELL_HEAL = true, SPELL_PERIODIC_HEAL = true }

local function OnCombatEvent(...)
  local _, ev, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags = ...
  if DAMAGE[ev] then
    local who = SourceName(srcGUID, srcName, srcFlags)
    if not who then return end
    -- don't count damage to your own group (e.g. Hellfire on yourself)
    if dstFlags and bit.band(dstFlags, GROUP_MASK) > 0 then return end
    local amount, spell
    if ev == "SWING_DAMAGE" then
      amount = select(9, ...)
    else
      spell = select(10, ...)
      amount = select(12, ...)
    end
    Add(who, "damage", amount, spell)
  elseif HEAL[ev] then
    local who = SourceName(srcGUID, srcName, srcFlags)
    if not who then return end
    Add(who, "healing", select(12, ...), select(10, ...))
  end
end

local function AnyoneInCombat()
  if UnitAffectingCombat("player") then return true end
  for i = 1, 4 do if UnitExists("party"..i) and UnitAffectingCombat("party"..i) then return true end end
  return false
end

---------------------------------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------------------------------
local frame, bars, titleBtn, segBtn, offset = nil, {}, nil, nil, 0

local function Short(n)
  if n >= 1000000 then return string.format("%.1fM", n / 1000000) end
  if n >= 10000 then return string.format("%.1fk", n / 1000) end
  return tostring(math.floor(n + 0.5))
end

local function SegTime(seg)
  if not seg or not seg.start then return 1 end
  local t
  if seg == overall then
    t = overall.time + ((inFight and current) and (Now() - current.start) or 0)
  else
    t = inFight and (Now() - seg.start) or seg.time
  end
  return math.max(1, t)
end

local sorted = {}
local function Update()
  if not frame or not frame:IsShown() then return end
  local seg = (segment == "current") and current or overall
  titleBtn.text:SetText(mode == "damage" and "Damage" or "Healing")
  segBtn.text:SetText((segment == "current") and "Current fight" or "Overall")
  for k in pairs(sorted) do sorted[k] = nil end
  local total, top = 0, 0
  if seg then
    for name, m in pairs(seg.members) do
      if m[mode] > 0 then
        table.insert(sorted, { name = name, value = m[mode], m = m })
        total = total + m[mode]
        if m[mode] > top then top = m[mode] end
      end
    end
  end
  table.sort(sorted, function(a, b) return a.value > b.value end)
  local secs = SegTime(seg)
  offset = math.max(0, math.min(offset, #sorted - BARS))
  for i = 1, BARS do
    local b = bars[i]
    local e = sorted[i + offset]
    b.entry = e
    if e then
      local cls = classOf[e.name] or classOf[string.gsub(e.name, " %(pet%)$", "")]
      local c = CLASS_COLOR[cls] or { r = 0.5, g = 0.5, b = 0.55 }
      b.fill:SetVertexColor(c.r, c.g, c.b, 0.85)
      b.fill:SetWidth(math.max(1, (WIDTH - 4) * e.value / math.max(1, top)))
      b.left:SetText((i + offset)..". "..e.name)
      local pct = total > 0 and (e.value * 100 / total) or 0
      b.right:SetText(Short(e.value).." ("..Short(e.value / secs)..", "..string.format("%d%%", pct)..")")
      b:Show()
    else
      b:Hide()
    end
  end
  frame.footer:SetText(string.format("%s  |  %d:%02d  |  %s %s/s",
    Short(total), math.floor(secs / 60), math.floor(secs % 60), Short(total / secs), mode == "damage" and "dmg" or "heal"))
end

local function SavePos()
  local p, _, rp, x, y = frame:GetPoint()
  db.pos = { p, rp, x, y }
end

local function Create()
  frame = CreateFrame("Frame", "CleanMeterFrame", UIParent)
  frame:SetWidth(WIDTH)
  frame:SetHeight(22 + BARS * (BAR_H + 1) + 18)
  frame:SetBackdrop({ bgFile = SOLID, edgeFile = SOLID, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
  frame:SetBackdropColor(0.04, 0.04, 0.05, 0.85)
  frame:SetBackdropBorderColor(0.2, 0.2, 0.23, 1)
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  local function DragStart() if not db.locked then frame:StartMoving() end end
  local function DragStop() frame:StopMovingOrSizing() SavePos() end
  frame:SetScript("OnDragStart", DragStart)
  frame:SetScript("OnDragStop", DragStop)
  -- the header buttons and bars cover most of the window, so let them drag it too
  local function Draggable(b) b:RegisterForDrag("LeftButton") b:SetScript("OnDragStart", DragStart) b:SetScript("OnDragStop", DragStop) end
  local p = db.pos or { "BOTTOMRIGHT", "BOTTOMRIGHT", -300, 120 }
  frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])

  local head = frame:CreateTexture(nil, "ARTWORK")
  head:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
  head:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
  head:SetHeight(20)
  head:SetTexture(SOLID)
  head:SetVertexColor(0.1, 0.1, 0.12, 1)

  local function headButton(w)
    local b = CreateFrame("Button", nil, frame)
    Draggable(b)
    b:SetHeight(20) b:SetWidth(w)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.text:SetAllPoints(b)
    return b
  end
  titleBtn = headButton(70)
  titleBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -1)
  titleBtn.text:SetJustifyH("LEFT")
  titleBtn:SetScript("OnClick", function() mode = (mode == "damage") and "healing" or "damage" Update() end)
  segBtn = headButton(100)
  segBtn:SetPoint("LEFT", titleBtn, "RIGHT", 0, 0)
  segBtn.text:SetTextColor(0.7, 0.7, 0.7)
  segBtn:SetScript("OnClick", function() segment = (segment == "current") and "overall" or "current" Update() end)
  local reset = headButton(40)
  reset:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -1)
  reset.text:SetText("reset")
  reset.text:SetJustifyH("RIGHT")
  reset.text:SetTextColor(0.6, 0.6, 0.6)
  reset:SetScript("OnClick", function()
    overall = { start = nil, time = 0, members = {} } current = nil inFight = false Update()
  end)

  for i = 1, BARS do
    local b = CreateFrame("Button", nil, frame)
    Draggable(b)
    b:SetHeight(BAR_H)
    b:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -22 - (i - 1) * (BAR_H + 1))
    b:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -22 - (i - 1) * (BAR_H + 1))
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(b)
    bg:SetTexture(SOLID)
    bg:SetVertexColor(0.12, 0.12, 0.14, 0.8)
    b.fill = b:CreateTexture(nil, "BORDER")
    b.fill:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
    b.fill:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
    b.fill:SetTexture(SOLID)
    b.left = b:CreateFontString(nil, "OVERLAY")
    b.left:SetFont("Fonts\\ARIALN.TTF", 11, "OUTLINE")
    b.left:SetPoint("LEFT", b, "LEFT", 4, 0)
    b.right = b:CreateFontString(nil, "OVERLAY")
    b.right:SetFont("Fonts\\ARIALN.TTF", 11, "OUTLINE")
    b.right:SetPoint("RIGHT", b, "RIGHT", -4, 0)
    b:SetScript("OnEnter", function()
      local e = b.entry
      if not e then return end
      GameTooltip:SetOwner(b, "ANCHOR_LEFT")
      GameTooltip:AddLine(e.name.." - "..(mode == "damage" and "damage" or "healing").." by spell", 1, 0.82, 0)
      local list = {}
      for s, v in pairs(e.m.spells[mode]) do table.insert(list, { s, v }) end
      table.sort(list, function(a, c) return a[2] > c[2] end)
      for k = 1, math.min(8, #list) do
        GameTooltip:AddDoubleLine(list[k][1], Short(list[k][2]).." ("..string.format("%d%%", list[k][2] * 100 / e.value)..")", 1, 1, 1, 1, 1, 1)
      end
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    bars[i] = b
  end
  frame:EnableMouseWheel(true)
  frame:SetScript("OnMouseWheel", function(self, delta) offset = offset - (delta or arg1 or 0) Update() end)

  frame.footer = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  frame.footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 5, 4)

  if db.hidden then frame:Hide() end
end

---------------------------------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
ev:RegisterEvent("PARTY_MEMBERS_CHANGED")
ev:RegisterEvent("RAID_ROSTER_UPDATE")
ev:RegisterEvent("UNIT_PET")
ev:SetScript("OnEvent", function(self, event, ...)
  event = event or _G.event
  if event == "COMBAT_LOG_EVENT_UNFILTERED" then
    if ... then OnCombatEvent(...) else OnCombatEvent(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12) end
  elseif event == "PLAYER_LOGIN" then
    db = CleanMeterDB
    Create()
    RefreshRoster()
  else
    RefreshRoster()
  end
end)

local acc = 0
ev:SetScript("OnUpdate", function(self, elapsed)
  acc = acc + (elapsed or arg1 or 0)
  if acc < 0.5 then return end
  acc = 0
  if inFight and not AnyoneInCombat() and Now() - lastActivity > 2 then
    inFight = false
    if current then
      current.time = Now() - current.start
      overall.time = overall.time + current.time
    end
  end
  Update()
end)

SLASH_CLEANMETER1 = "/cm"
SLASH_CLEANMETER2 = "/cleanmeter"
SlashCmdList["CLEANMETER"] = function(msg)
  msg = string.lower(msg or "")
  if msg == "reset" then
    overall = { start = nil, time = 0, members = {} } current = nil inFight = false Update()
  elseif msg == "lock" then
    db.locked = not db.locked
    DEFAULT_CHAT_FRAME:AddMessage("|cffffd100CleanMeter:|r "..(db.locked and "locked" or "unlocked"))
  else
    if frame:IsShown() then frame:Hide() db.hidden = true else frame:Show() db.hidden = false Update() end
  end
end
