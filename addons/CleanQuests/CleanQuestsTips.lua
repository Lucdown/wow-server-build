-- CleanQuests tooltips: shows your live quest progress on mob and item tooltips.
-- Hover a Kobold Vermin -> "Kobold Camp Cleanup: 8/10 Kobold Vermin slain" (green when done).

local MOBS = CleanQuests_MobTips or {}
local DATA = CleanQuests_Data or {}
local GIVERS = CleanQuests_Givers or {}

local function QuestTitle(id)
  local q = DATA[id] or GIVERS[id]
  return q and q[1]
end

-- Current quest log: title -> { complete=bool, boards = { {lower, text, finished} } }
local function ReadLog()
  local log = {}
  for i = 1, GetNumQuestLogEntries() do
    local title, _, _, _, isHeader, _, isComplete = GetQuestLogTitle(i)
    if title and not isHeader then
      local e = { complete = isComplete and isComplete > 0, boards = {} }
      for j = 1, GetNumQuestLeaderBoards(i) do
        local text, _, finished = GetQuestLogLeaderBoard(j, i)
        if text then table.insert(e.boards, { string.lower(text), text, finished }) end
      end
      log[title] = e
    end
  end
  return log
end

local function Pretty(text)
  local name, have, need = string.match(text, "^(.-):%s*(%d+)%s*/%s*(%d+)$")
  if name then return have.."/"..need.."  "..name end
  return text
end

local function AddLines(tt, matches)
  if #matches == 0 then return end
  tt:AddLine(" ")
  for _, m in ipairs(matches) do
    if m.finished then
      tt:AddLine(m.title..":  "..Pretty(m.text), 0.25, 1, 0.35)
    else
      tt:AddLine(m.title..":  "..Pretty(m.text), 1, 0.82, 0)
    end
  end
  tt:Show()
end

local function OnUnit(tt)
  local db = CleanQuestsDB
  if db and db.tipsOff then return end
  local name = tt:GetUnit()
  local list = name and MOBS[name]
  if not list then return end
  local log = ReadLog()
  local matches, seen = {}, {}
  for k = 1, #list, 2 do
    local title, objective = QuestTitle(list[k]), string.lower(list[k + 1])
    local e = title and log[title]
    if e and not e.complete then
      for _, b in ipairs(e.boards) do
        local key = title..b[2]
        if not seen[key] and string.find(b[1], objective, 1, true) then
          seen[key] = true
          table.insert(matches, { title = title, text = b[2], finished = b[3] })
        end
      end
    end
  end
  AddLines(tt, matches)
end

local function OnItem(tt)
  local db = CleanQuestsDB
  if db and db.tipsOff then return end
  local name = tt:GetItem()
  if not name or name == "" then return end
  local lname = string.lower(name)
  local matches = {}
  for title, e in pairs(ReadLog()) do
    for _, b in ipairs(e.boards) do
      if string.find(b[1], lname, 1, true) then
        table.insert(matches, { title = title, text = b[2], finished = b[3] })
      end
    end
  end
  AddLines(tt, matches)
end

local function Hook(tt, script, fn)
  if not tt then return end
  if tt.HookScript then
    tt:HookScript(script, function(self) fn(self or tt) end)
  else
    local old = tt:GetScript(script)
    tt:SetScript(script, function(...) if old then old(...) end fn(tt) end)
  end
end

Hook(GameTooltip, "OnTooltipSetUnit", OnUnit)
Hook(GameTooltip, "OnTooltipSetItem", OnItem)
Hook(ItemRefTooltip, "OnTooltipSetItem", OnItem)
