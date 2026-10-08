-- CleanQuests map and minimap markers.
--   Colored dots = objectives still to do      "?" = turn in here      "!" = quest you can pick up
-- /cq map (world map markers), /cq minimap (minimap markers), /cq givers ("!" markers), /cq lowlevel

local DATA = CleanQuests_Data or {}
local GIVERS = CleanQuests_Givers or {}
local ZSIZE = CleanQuests_ZoneSize or {}
local COLORS = {
  {1, 0.82, 0}, {0.3, 0.8, 1}, {1, 0.4, 0.4}, {0.5, 1, 0.4}, {0.85, 0.5, 1},
  {1, 0.6, 0.2}, {0.4, 1, 0.9}, {1, 0.5, 0.8}, {0.7, 0.7, 1}, {0.9, 0.9, 0.5},
}
local KIND = { k="Kill", i="Collect", o="Use / interact", e="Explore" }
local DOT = "Interface\\WorldMap\\WorldMapPartyIcon"
local TURNIN = "Interface\\GossipFrame\\ActiveQuestIcon"
local AVAIL = "Interface\\GossipFrame\\AvailableQuestIcon"
local RACE_BIT = { Human=1, Orc=2, Dwarf=4, NightElf=8, Scourge=16, Tauren=32, Gnome=64, Troll=128, BloodElf=512, Draenei=1024 }
local CLASS_BIT = { WARRIOR=1, PALADIN=2, HUNTER=4, ROGUE=8, PRIEST=16, SHAMAN=64, MAGE=128, WARLOCK=256, DRUID=1024 }

local function DB() return CleanQuestsDB or {} end
local function HasBit(mask, bit) return math.floor(mask / bit) % 2 == 1 end

---------------------------------------------------------------------------------------------------
-- Which quests are done (server sync file + turn-ins recorded since)
---------------------------------------------------------------------------------------------------
local byTitle
local function TitleIndex()
  if byTitle then return byTitle end
  byTitle = {}
  for id, q in pairs(DATA) do byTitle[q[1]] = byTitle[q[1]] or {} table.insert(byTitle[q[1]], id) end
  for id, q in pairs(GIVERS) do
    byTitle[q[1]] = byTitle[q[1]] or {}
    local seen = false
    for _, x in ipairs(byTitle[q[1]]) do if x == id then seen = true end end
    if not seen then table.insert(byTitle[q[1]], id) end
  end
  return byTitle
end

local function IsDone(id)
  local me = UnitName("player")
  local synced = CleanQuests_Done and me and CleanQuests_Done[me]
  if synced and synced[id] then return true end
  local db = DB()
  return db.done and db.done[id]
end

-- Record turn-ins as they happen so markers update without re-syncing
if hooksecurefunc then
  hooksecurefunc("GetQuestReward", function()
    local title = GetTitleText and GetTitleText()
    local db = CleanQuestsDB
    if not title or not db then return end
    db.done = db.done or {}
    for _, id in ipairs(TitleIndex()[title] or {}) do db.done[id] = true end
  end)
end

---------------------------------------------------------------------------------------------------
-- Build the list of markers for one zone map
---------------------------------------------------------------------------------------------------
local function QuestIdsFor(index, title, level)
  if GetQuestLink then
    local link = GetQuestLink(index)
    local id = link and tonumber(string.match(link, "quest:(%d+)"))
    if id and DATA[id] then return { id } end
  end
  local list = TitleIndex()[title]
  if not list then return {} end
  local exact = {}
  for _, id in ipairs(list) do if DATA[id] and DATA[id][2] == level then table.insert(exact, id) end end
  if #exact > 0 then return exact end
  local any = {}
  for _, id in ipairs(list) do if DATA[id] then table.insert(any, id) end end
  return any
end

local function Collect(mapName)
  local out = {}
  local db = DB()
  local inLog = {}
  local color = 0
  for i = 1, GetNumQuestLogEntries() do
    local title, level, _, _, isHeader, _, isComplete = GetQuestLogTitle(i)
    if not isHeader and title then
      inLog[title] = true
      if not (db.hidden and db.hidden[title]) then
        color = color % #COLORS + 1
        local c = COLORS[color]
        local boards = {}
        for j = 1, GetNumQuestLeaderBoards(i) do
          local text, _, finished = GetQuestLogLeaderBoard(j, i)
          if text then table.insert(boards, { string.lower(text), finished, text }) end
        end
        local done = isComplete and isComplete > 0
        for _, id in ipairs(QuestIdsFor(i, title, level)) do
          local q = DATA[id]
          if not done then
            for _, o in ipairs(q[5]) do
              local pts = o[3][mapName]
              if pts then
                local finished, progress = false, nil
                local lname = string.lower(o[2] or "")
                for _, b in ipairs(boards) do
                  if lname ~= "" and string.find(b[1], lname, 1, true) then finished, progress = b[2], b[3] end
                end
                if not finished then
                  local line = (KIND[o[1]] or "")..": "..(progress or o[2] or "")
                  for k = 1, #pts, 2 do
                    table.insert(out, { x=pts[k], y=pts[k+1], tex=DOT, size=12, c=c, title=title, line=line })
                  end
                end
              end
            end
          end
          local ender = q[4][mapName]
          if ender and (done or #q[5] == 0 or #boards == 0) then
            local line = "Turn in to "..(q[3] ~= "" and q[3] or "quest contact")
            for k = 1, #ender, 2 do
              table.insert(out, { x=ender[k], y=ender[k+1], tex=TURNIN, size=18, c={1,0.82,0}, title=title, line=line })
            end
          end
        end
      end
    end
  end

  -- "!" quests you can pick up
  if not db.giversOff then
    local lvl = UnitLevel("player") or 1
    local _, race = UnitRace("player")
    local _, class = UnitClass("player")
    local rbit, cbit = RACE_BIT[race] or 0, CLASS_BIT[class] or 0
    local exclDone = {}
    for id, g in pairs(GIVERS) do
      if g[8] > 0 and (IsDone(id) or inLog[g[1]]) then exclDone[g[8]] = true end
    end
    for id, g in pairs(GIVERS) do
      local pts = g[11][mapName]
      if pts and not inLog[g[1]] and (g[9] == 1 or not IsDone(id))
        and g[3] <= lvl and (db.lowLevel or g[2] >= lvl - 6 or g[2] <= 0)
        and (g[4] == 0 or HasBit(g[4], rbit)) and (g[5] == 0 or HasBit(g[5], cbit))
        and not (g[8] > 0 and exclDone[g[8]]) then
        local ok = true
        if g[6] > 0 then ok = DATA[g[6]] and inLog[DATA[g[6]][1]] or (GIVERS[g[6]] and inLog[GIVERS[g[6]][1]]) end
        if ok then
          for _, grp in ipairs(g[7]) do
            local any = false
            for _, pre in ipairs(grp) do if IsDone(pre) then any = true end end
            if not any then ok = false break end
          end
        end
        if ok then
          local line = "Quest giver: "..(g[10] ~= "" and g[10] or "?")
          for k = 1, #pts, 2 do
            table.insert(out, { x=pts[k], y=pts[k+1], tex=AVAIL, size=16, c={1,0.82,0},
              title="["..g[2].."] "..g[1], line=line, avail=true })
          end
        end
      end
    end
  end
  return out
end

---------------------------------------------------------------------------------------------------
-- Pin pools
---------------------------------------------------------------------------------------------------
local function MakePool(parent, tooltip)
  local pool = { pins = {}, used = 0 }
  function pool:Reset() self.used = 0 for _, p in ipairs(self.pins) do p:Hide() end end
  function pool:Get()
    self.used = self.used + 1
    local p = self.pins[self.used]
    if not p then
      p = CreateFrame("Button", nil, parent)
      p:SetFrameLevel(parent:GetFrameLevel() + 5)
      p.tex = p:CreateTexture(nil, "OVERLAY")
      p.tex:SetAllPoints(p)
      p:SetScript("OnEnter", function()
        local tt = tooltip()
        tt:SetOwner(p, "ANCHOR_RIGHT")
        for _, m in ipairs(p.markers) do
          tt:AddLine(m.title, m.c[1], m.c[2], m.c[3])
          tt:AddLine(m.line, 0.9, 0.9, 0.9)
        end
        tt:Show()
      end)
      p:SetScript("OnLeave", function() tooltip():Hide() end)
      self.pins[self.used] = p
    end
    p:Show()
    return p
  end
  return pool
end

local function Style(p, m)
  p.markers = { m }
  p.tex:SetTexture(m.tex)
  if m.tex == DOT then p.tex:SetVertexColor(m.c[1], m.c[2], m.c[3]) else p.tex:SetVertexColor(1, 1, 1) end
end

-- World map ---------------------------------------------------------------------------------------
local worldPool
local function RedrawWorld()
  if not WorldMapButton then return end
  worldPool = worldPool or MakePool(WorldMapButton, function() return WorldMapTooltip end)
  worldPool:Reset()
  local db = DB()
  if db.mapOff or not WorldMapFrame:IsShown() then return end
  local mapName = GetMapInfo()
  if not mapName then return end
  local w, h = WorldMapButton:GetWidth(), WorldMapButton:GetHeight()
  for _, m in ipairs(Collect(mapName)) do
    local p = worldPool:Get()
    Style(p, m)
    p:SetWidth(m.size) p:SetHeight(m.size)
    p:ClearAllPoints()
    p:SetPoint("CENTER", WorldMapButton, "TOPLEFT", m.x / 1000 * w, -m.y / 1000 * h)
  end
end

-- Minimap -----------------------------------------------------------------------------------------
local OUT_DIAM = { [0]=466.6667, 400, 333.3333, 266.6667, 200, 133.3333 }
local IN_DIAM = { [0]=300, 240, 180, 120, 80, 50 }
local miniPool, miniMarkers, miniZone, miniDirty = nil, {}, nil, true

local function RefreshMiniMarkers()
  miniDirty = false
  miniMarkers = {}
  if WorldMapFrame and WorldMapFrame:IsShown() then miniDirty = true return end
  SetMapToCurrentZone()
  miniZone = GetMapInfo()
  if not miniZone or DB().minimapOff then return end
  miniMarkers = Collect(miniZone)
end

local function UpdateMinimap()
  if not miniPool then miniPool = MakePool(Minimap, function() return GameTooltip end) end
  miniPool:Reset()
  if DB().minimapOff or not miniZone then return end
  local size = ZSIZE[miniZone]
  if not size then return end
  local px, py = GetPlayerMapPosition("player")
  if not px or (px == 0 and py == 0) then return end
  local zoom = Minimap:GetZoom()
  local indoors = tonumber(GetCVar("minimapZoom") or -1) ~= zoom
  local diam = (indoors and IN_DIAM[zoom] or OUT_DIAM[zoom]) or 400
  local radiusYards = diam / 2
  local radiusPx = Minimap:GetWidth() / 2
  local shown = 0
  for _, m in ipairs(miniMarkers) do
    local dx = (m.x / 1000 - px) * size[1]
    local dy = (m.y / 1000 - py) * size[2]
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < radiusYards * 0.92 and shown < 80 then
      shown = shown + 1
      local p = miniPool:Get()
      Style(p, m)
      local s = math.max(8, m.size - 4)
      p:SetWidth(s) p:SetHeight(s)
      p:ClearAllPoints()
      p:SetPoint("CENTER", Minimap, "CENTER", dx / radiusYards * radiusPx, -dy / radiusYards * radiusPx)
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------------------------------
local ev = CreateFrame("Frame")
for _, e in ipairs({ "WORLD_MAP_UPDATE", "QUEST_LOG_UPDATE", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED",
  "PLAYER_ENTERING_WORLD", "PLAYER_LEVEL_UP" }) do ev:RegisterEvent(e) end
ev:SetScript("OnEvent", function(self, event)
  event = event or _G.event
  if event == "WORLD_MAP_UPDATE" and not (WorldMapFrame and WorldMapFrame:IsShown()) then return end
  miniDirty = true
  if event ~= "ZONE_CHANGED" and WorldMapFrame and WorldMapFrame:IsShown() then RedrawWorld() end
end)
local elapsedTotal = 0
ev:SetScript("OnUpdate", function(self, elapsed)
  elapsedTotal = elapsedTotal + (elapsed or arg1 or 0)
  if elapsedTotal < 0.1 then return end
  elapsedTotal = 0
  if miniDirty then RefreshMiniMarkers() end
  if not (WorldMapFrame and WorldMapFrame:IsShown()) then UpdateMinimap() end
end)

if WorldMapFrame then
  if WorldMapFrame.HookScript then
    WorldMapFrame:HookScript("OnShow", function() RedrawWorld() end)
    WorldMapFrame:HookScript("OnHide", function() miniDirty = true end)
  else
    local oldShow, oldHide = WorldMapFrame:GetScript("OnShow"), WorldMapFrame:GetScript("OnHide")
    WorldMapFrame:SetScript("OnShow", function(...) if oldShow then oldShow(...) end RedrawWorld() end)
    WorldMapFrame:SetScript("OnHide", function(...) if oldHide then oldHide(...) end miniDirty = true end)
  end
end

CleanQuests_RedrawMap = function() RedrawWorld() miniDirty = true end
