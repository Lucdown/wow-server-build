-- CleanQuests: a clean, Questie-style quest tracker for the WoW 2.4.3 client.
-- Tracks every quest in your log automatically, grouped by zone, with live objective progress.
-- /cq toggles it, /cq lock, /cq unlock, /cq reset, /cq map, /cq minimap, /cq givers, /cq lowlevel, /cq tips, /cq blizzard (default tracker).

local WIDTH = 260
local SOLID = "Interface\\ChatFrame\\ChatFrameBackground"
local ACCENT = { 1, 0.82, 0 }

CleanQuestsDB = CleanQuestsDB or {}
local db

local f, bar, body, titleText, toggleBtn
local lines, used = {}, 0
local dirty = true

local function Msg(t) DEFAULT_CHAT_FRAME:AddMessage("|cffffd100CleanQuests:|r "..t) end

local function DifficultyColor(level)
  if GetDifficultyColor then
    local c = GetDifficultyColor(level)
    if c then return c.r, c.g, c.b end
  end
  local d = level - (UnitLevel("player") or 1)
  if d >= 5 then return 1, 0.1, 0.1 elseif d >= 3 then return 1, 0.5, 0.25
  elseif d >= -2 then return 1, 1, 0 elseif d >= -8 then return 0.25, 0.75, 0.25 end
  return 0.5, 0.5, 0.5
end

-- A pooled clickable line (zone header, quest title or objective)
local function GetLine()
  used = used + 1
  local l = lines[used]
  if not l then
    l = CreateFrame("Button", nil, body)
    l:SetWidth(WIDTH - 16)
    l:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    l.text = l:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    l.text:SetPoint("TOPLEFT", l, "TOPLEFT", 0, 0)
    l.text:SetJustifyH("LEFT")
    l.hl = l:CreateTexture(nil, "BACKGROUND")
    l.hl:SetAllPoints(l)
    l.hl:SetTexture(1, 1, 1, 0.06)
    l.hl:Hide()
    l:SetScript("OnEnter", function() if l.questIndex then l.hl:Show() end end)
    l:SetScript("OnLeave", function() l.hl:Hide() GameTooltip:Hide() end)
    l:SetScript("OnClick", function(self, button)
      button = button or arg1
      if not l.questIndex then return end
      if button == "RightButton" then
        db.hidden[l.questTitle] = true
        Msg("Hid \""..l.questTitle.."\" from the tracker. /cq show to bring hidden quests back.")
        dirty = true
      elseif IsShiftKeyDown() and ChatFrameEditBox and ChatFrameEditBox:IsVisible() and GetQuestLink then
        local link = GetQuestLink(l.questIndex)
        if link then ChatFrameEditBox:Insert(link) end
      else
        ShowUIPanel(QuestLogFrame)
        QuestLog_SetSelection(l.questIndex)
        QuestLog_Update()
      end
    end)
    lines[used] = l
  end
  l.questIndex, l.questTitle = nil, nil
  l.text:SetFontObject(GameFontHighlightSmall)
  l.text:SetWidth(WIDTH - 24)
  l:Show()
  return l
end

local function TH(fs)
  local h = fs:GetHeight() or 0
  if h < 8 then h = 12 end
  return h
end

local MAX_H = 620

local function Rebuild()
  dirty = false
  if not f then return end
  -- make sure no zone is collapsed in the quest log, or its quests would be invisible to us
  for i = 1, GetNumQuestLogEntries() do
    local _, _, _, _, isHeader, isCollapsed = GetQuestLogTitle(i)
    if isHeader and isCollapsed then ExpandQuestHeader(0) break end
  end
  used = 0
  for _, l in ipairs(lines) do l:Hide() end

  local numEntries, numQuests = GetNumQuestLogEntries()
  local y, shown = 0, 0
  local zone, zoneShown = nil, false
  local truncated = false

  if not db.collapsed then
    for i = 1, numEntries do
      local title, level, tag, group, isHeader, isCollapsed, isComplete = GetQuestLogTitle(i)
      if isHeader then
        zone, zoneShown = title, false
      elseif title and not db.hidden[title] and y > MAX_H then
        if not truncated then
          local m = GetLine()
          m:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -y)
          m.text:SetText("More quests... (open your quest log)")
          m.text:SetTextColor(0.6, 0.6, 0.6)
          m:SetHeight(14)
          y = y + 14
          truncated = true
        end
      elseif title and not db.hidden[title] then
        if zone and not zoneShown then
          local h = GetLine()
          h:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y - (y > 0 and 6 or 0))
          y = y + (y > 0 and 6 or 0)
          h.text:SetFontObject(GameFontNormalSmall)
          h.text:SetText(string.upper(zone))
          h.text:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.85)
          h:SetHeight(TH(h.text)+ 3)
          y = y + TH(h.text)+ 3
          zoneShown = true
        end
        shown = shown + 1

        local q = GetLine()
        q:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -y)
        q.questIndex, q.questTitle = i, title
        q.text:SetFontObject(GameFontNormal)
        local label = "["..level..((tag and tag ~= "") and "+" or "").."] "..title
        if isComplete and isComplete > 0 then
          q.text:SetText(label)
          q.text:SetTextColor(0.25, 1, 0.35)
        elseif isComplete and isComplete < 0 then
          q.text:SetText(label.."  (Failed)")
          q.text:SetTextColor(1, 0.25, 0.25)
        else
          q.text:SetText(label)
          q.text:SetTextColor(DifficultyColor(level))
        end
        q:SetHeight(TH(q.text)+ 2)
        y = y + TH(q.text)+ 2

        local numObj = GetNumQuestLeaderBoards(i)
        if isComplete and isComplete > 0 then
          local o = GetLine()
          o:SetPoint("TOPLEFT", body, "TOPLEFT", 16, -y)
          o.text:SetWidth(WIDTH - 36)
          o.text:SetText("Ready to turn in")
          o.text:SetTextColor(0.25, 1, 0.35)
          o:SetHeight(TH(o.text)+ 1)
          y = y + TH(o.text)+ 1
        elseif numObj == 0 then
          local o = GetLine()
          o:SetPoint("TOPLEFT", body, "TOPLEFT", 16, -y)
          o.text:SetWidth(WIDTH - 36)
          o.text:SetText("- Talk to the quest's contact (see quest log)")
          o.text:SetTextColor(0.7, 0.7, 0.7)
          o:SetHeight(TH(o.text)+ 1)
          y = y + TH(o.text)+ 1
        else
          for j = 1, numObj do
            local text, objType, finished = GetQuestLogLeaderBoard(j, i)
            if text then
              local o = GetLine()
              o:SetPoint("TOPLEFT", body, "TOPLEFT", 16, -y)
              o.text:SetWidth(WIDTH - 36)
              -- Show "3/8 Boar Meat" instead of "Boar Meat: 3/8"
              local name, have, need = string.match(text, "^(.-):%s*(%d+)%s*/%s*(%d+)$")
              if name then text = have.."/"..need.."  "..name end
              o.text:SetText("- "..text)
              if finished then o.text:SetTextColor(0.25, 1, 0.35) else o.text:SetTextColor(0.85, 0.85, 0.85) end
              o:SetHeight(TH(o.text)+ 1)
              y = y + TH(o.text)+ 1
            end
          end
        end
        y = y + 4
      end
    end
  end

  titleText:SetText("Quests  |cff999999"..(numQuests or 0).."/25|r")
  toggleBtn.label:SetText(db.collapsed and "+" or "-")
  if db.collapsed or shown == 0 then
    body:SetHeight(1)
    f:SetHeight(26)
    body:Hide()
    if not db.collapsed and shown == 0 then
      f:SetHeight(26)
    end
  else
    body:Show()
    body:SetHeight(y)
    f:SetHeight(y + 36)
  end
end

local function SavePosition()
  local point, _, relPoint, x, y = f:GetPoint()
  db.pos = { point, relPoint, x, y }
end

local function ApplyPosition()
  f:ClearAllPoints()
  if db.pos then
    f:SetPoint(db.pos[1], UIParent, db.pos[2], db.pos[3], db.pos[4])
  else
    f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -40, -240)
  end
end

local function HideBlizzardTracker()
  if db.blizzard or not QuestWatchFrame then return end
  QuestWatchFrame:Hide()
  QuestWatchFrame.Show = function() end
end

local function Build()
  f = CreateFrame("Frame", "CleanQuestsFrame", UIParent)
  f:SetWidth(WIDTH)
  f:SetBackdrop({ bgFile=SOLID, edgeFile=SOLID, tile=false, edgeSize=1, insets={ left=1, right=1, top=1, bottom=1 } })
  f:SetBackdropColor(0.06, 0.06, 0.07, 0.72)
  f:SetBackdropBorderColor(0.22, 0.22, 0.24, 0.9)
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  f:SetFrameStrata("LOW")

  bar = CreateFrame("Button", nil, f)
  bar:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
  bar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
  bar:SetHeight(24)
  local barBg = bar:CreateTexture(nil, "BACKGROUND")
  barBg:SetAllPoints(bar)
  barBg:SetTexture(0.12, 0.12, 0.13, 0.9)
  local line = bar:CreateTexture(nil, "ARTWORK")
  line:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
  line:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
  line:SetHeight(1)
  line:SetTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.7)
  titleText = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  titleText:SetPoint("LEFT", bar, "LEFT", 8, 0)
  bar:RegisterForDrag("LeftButton")
  bar:SetScript("OnDragStart", function() if not db.locked then f:StartMoving() end end)
  bar:SetScript("OnDragStop", function() f:StopMovingOrSizing() SavePosition() end)
  bar:SetScript("OnEnter", function()
    GameTooltip:SetOwner(bar, "ANCHOR_LEFT")
    GameTooltip:AddLine("CleanQuests", 1, 0.82, 0)
    GameTooltip:AddLine(db.locked and "Locked (/cq unlock to move)" or "Drag to move", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Click a quest: open it in the quest log", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Shift-click: link it in chat", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Right-click: hide it from the tracker", 0.8, 0.8, 0.8)
    GameTooltip:Show()
  end)
  bar:SetScript("OnLeave", function() GameTooltip:Hide() end)

  toggleBtn = CreateFrame("Button", nil, bar)
  toggleBtn:SetWidth(20) toggleBtn:SetHeight(18)
  toggleBtn:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
  toggleBtn.label = toggleBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  toggleBtn.label:SetPoint("CENTER", toggleBtn, "CENTER", 0, 1)
  toggleBtn:SetScript("OnClick", function() db.collapsed = not db.collapsed Rebuild() end)

  body = CreateFrame("Frame", nil, f)
  body:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 8, -6)
  body:SetWidth(WIDTH - 16)
  body:SetHeight(1)

  ApplyPosition()
  if db.hiddenFrame then f:Hide() end

  f:SetScript("OnUpdate", function() if dirty then Rebuild() end end)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("VARIABLES_LOADED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("QUEST_LOG_UPDATE")
ev:RegisterEvent("UNIT_QUEST_LOG_CHANGED")
ev:RegisterEvent("PLAYER_LEVEL_UP")
ev:SetScript("OnEvent", function(self, event)
  event = event or _G.event
  if event == "VARIABLES_LOADED" then
    db = CleanQuestsDB
    db.hidden = db.hidden or {}
    if not f then Build() end
    HideBlizzardTracker()
  end
  dirty = true
end)

SLASH_CLEANQUESTS1 = "/cq"
SLASH_CLEANQUESTS2 = "/cleanquests"
SlashCmdList["CLEANQUESTS"] = function(msg)
  msg = string.lower(msg or "")
  if not f then return end
  if msg == "lock" then db.locked = true Msg("Locked.")
  elseif msg == "unlock" then db.locked = false Msg("Unlocked - drag the title bar to move.")
  elseif msg == "reset" then db.pos = nil ApplyPosition() Msg("Position reset.")
  elseif msg == "show" then db.hidden = {} dirty = true Msg("All hidden quests are back.")
  elseif msg == "map" then
    db.mapOff = not db.mapOff
    Msg(db.mapOff and "Map pins off." or "Map pins on.")
    if CleanQuests_RedrawMap then CleanQuests_RedrawMap() end
  elseif msg == "minimap" then
    db.minimapOff = not db.minimapOff
    Msg(db.minimapOff and "Minimap markers off." or "Minimap markers on.")
    if CleanQuests_RedrawMap then CleanQuests_RedrawMap() end
  elseif msg == "givers" then
    db.giversOff = not db.giversOff
    Msg(db.giversOff and "Quest giver (!) markers off." or "Quest giver (!) markers on.")
    if CleanQuests_RedrawMap then CleanQuests_RedrawMap() end
  elseif msg == "lowlevel" then
    db.lowLevel = not db.lowLevel
    Msg(db.lowLevel and "Showing low-level (grey) quests too." or "Hiding low-level (grey) quests.")
    if CleanQuests_RedrawMap then CleanQuests_RedrawMap() end
  elseif msg == "tips" then
    db.tipsOff = not db.tipsOff
    Msg(db.tipsOff and "Quest progress on tooltips off." or "Quest progress on tooltips on.")
  elseif msg == "blizzard" then
    db.blizzard = not db.blizzard
    Msg(db.blizzard and "Default tracker will return after /rl." or "Default tracker hidden after /rl.")
  else
    if f:IsShown() then f:Hide() db.hiddenFrame = true else f:Show() db.hiddenFrame = false dirty = true end
  end
end
