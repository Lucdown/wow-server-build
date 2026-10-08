-- CleanDefaults: applies Alteroth's preferred settings the first time each character logs in.
-- Type /defaults to apply them again any time. You can still change anything afterwards in the game's options.

CleanDefaultsDB = CleanDefaultsDB or {}

local CVARS = {
  { "autoLootDefault", "1" },      -- auto loot on (hold Shift to loot manually)
  { "autoSelfCast", "1" },         -- helpful spells land on you when you have no friendly target
  { "autoQuestWatch", "1" },       -- newly accepted quests show in the tracker
  { "showTargetOfTarget", "1" },   -- target of target frame
  { "UberTooltips", "1" },         -- full spell tooltips
  { "showTutorials", "0" },        -- no tutorial pop-ups
  { "showNewbieTips", "0" },
  { "cameraDistanceMaxFactor", "2" }, -- zoom the camera out further
  { "lootUnderMouse", "0" },
  { "showLootSpam", "1" },
}

local function Msg(t) DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Alteroth defaults:|r "..t) end

local function SetC(name, value)
  if SetCVar then pcall(SetCVar, name, value) end
end

local function Apply(quiet)
  if InCombatLockdown and InCombatLockdown() then Msg("will apply after combat.") CleanDefaultsDB.pending = true return end
  for _, c in ipairs(CVARS) do SetC(c[1], c[2]) end

  -- all four extra action bars on (bottom left, bottom right, right, right 2)
  if SetActionBarToggles then SetActionBarToggles(1, 1, 1, 1) end
  SHOW_MULTI_ACTIONBAR_1, SHOW_MULTI_ACTIONBAR_2, SHOW_MULTI_ACTIONBAR_3, SHOW_MULTI_ACTIONBAR_4 = "1", "1", "1", "1"
  if MultiActionBar_Update then MultiActionBar_Update() end
  if UIParent_ManageFramePositions then UIParent_ManageFramePositions() end

  -- target of target (older option name too)
  SHOW_TARGET_OF_TARGET = "1"
  if TargetofTarget_Update then pcall(TargetofTarget_Update) end

  -- B opens and closes all bags
  if SetBinding then
    SetBinding("B", "OPENALLBAGS")
    if SaveBindings then SaveBindings(GetCurrentBindingSet and GetCurrentBindingSet() or 1) end
  end

  CleanDefaultsDB.applied = 1
  CleanDefaultsDB.pending = nil
  if not quiet then Msg("applied: auto loot, 4 action bars, B = bags, target of target, self-cast, quest tracking, further camera zoom.") end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function(self, event)
  event = event or _G.event
  if event == "PLAYER_LOGIN" then
    if not CleanDefaultsDB.applied then Apply(false) end
  elseif event == "PLAYER_REGEN_ENABLED" and CleanDefaultsDB.pending then
    Apply(false)
  end
end)

SLASH_CLEANDEFAULTS1 = "/defaults"
SlashCmdList["CLEANDEFAULTS"] = function() Apply(false) end
