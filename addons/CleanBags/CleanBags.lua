-- CleanBags: one clean bag window with search, sorting (manual + automatic), sell values and gear comparison.
-- WoW 2.4.3. /cbag for options. Click the bag button, press B, or open any bag to show it.

local SOLID = "Interface\\ChatFrame\\ChatFrameBackground"
local SIZE, GAP, PAD = 36, 3, 8

CleanBagsDB = CleanBagsDB or {}
local db
local PRICES = CleanBags_Prices or {}

local function Msg(t) DEFAULT_CHAT_FRAME:AddMessage("|cffffd100CleanBags:|r "..t) end
local function Busy() return InCombatLockdown and InCombatLockdown() end
local function ItemId(link) return link and tonumber(string.match(link, "item:(%d+)")) end

local function Money(c)
  c = math.floor(c or 0)
  local g, s, cp = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
  local t = ""
  if g > 0 then t = t.."|cffffd700"..g.."g|r " end
  if s > 0 or g > 0 then t = t.."|cffc7c7cf"..s.."s|r " end
  return t.."|cffeda55f"..cp.."c|r"
end

-- Bags that can hold anything (quivers, soul bags, herb bags etc. are left alone by sorting)
local function IsNormalBag(bag)
  if bag == 0 then return true end
  local link = GetInventoryItemLink("player", ContainerIDToInventoryID(bag))
  if not link then return false end
  local _, _, _, _, _, _, subType = GetItemInfo(link)
  return subType == nil or subType == "Bag"
end

---------------------------------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------------------------------
local frame, bagFrames, buttons = nil, {}, {}
local searchText = ""

local QCOLOR = {
  [0] = { 0.45, 0.45, 0.45 }, [1] = { 0.3, 0.3, 0.32 }, [2] = { 0.12, 1, 0 }, [3] = { 0, 0.44, 0.87 },
  [4] = { 0.64, 0.21, 0.93 }, [5] = { 1, 0.5, 0 }, [6] = { 0.9, 0.8, 0.5 },
}

local function FlatButton(parent, text, w)
  local b = CreateFrame("Button", nil, parent)
  b:SetWidth(w) b:SetHeight(20)
  b:SetBackdrop({ bgFile=SOLID, edgeFile=SOLID, edgeSize=1, insets={ left=1, right=1, top=1, bottom=1 } })
  b:SetBackdropColor(0.17, 0.17, 0.19, 1)
  b:SetBackdropBorderColor(0.3, 0.3, 0.33, 1)
  b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
  b.text:SetText(text)
  b:SetScript("OnEnter", function(self)
    b:SetBackdropColor(0.25, 0.25, 0.28, 1)
    if b.tip then GameTooltip:SetOwner(b, "ANCHOR_TOP") GameTooltip:AddLine(b.tip, 1, 1, 1, 1) GameTooltip:Show() end
  end)
  b:SetScript("OnLeave", function() b:SetBackdropColor(0.17, 0.17, 0.19, 1) GameTooltip:Hide() end)
  return b
end

local function GetButton(bag, slot)
  local key = bag * 100 + slot
  local b = buttons[key]
  if b then return b end
  if not bagFrames[bag] then
    local bf = CreateFrame("Frame", "CleanBagsBag"..bag, frame)
    bf:SetID(bag)
    bf:SetAllPoints(frame)
    bagFrames[bag] = bf
  end
  b = CreateFrame("Button", "CleanBagsItem"..bag.."_"..slot, bagFrames[bag], "ContainerFrameItemButtonTemplate")
  b:SetID(slot)
  b:SetWidth(SIZE) b:SetHeight(SIZE)
  local nt = getglobal(b:GetName().."NormalTexture")
  if nt then nt:SetTexture(nil) end
  local icon = getglobal(b:GetName().."IconTexture")
  if icon then
    icon:ClearAllPoints()
    icon:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  end
  b.icon = icon
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints(b)
  b.bg:SetTexture(SOLID)
  b.bg:SetVertexColor(0.07, 0.07, 0.08, 0.9)
  -- Quality border: four thin edges
  b.edges = {}
  for i, pts in ipairs({ { "TOPLEFT", "TOPRIGHT", 0, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", 0, 1 },
                         { "TOPLEFT", "BOTTOMLEFT", 1, 0 }, { "TOPRIGHT", "BOTTOMRIGHT", 1, 0 } }) do
    local t = b:CreateTexture(nil, "OVERLAY")
    t:SetTexture(SOLID)
    t:SetPoint(pts[1], b, pts[1], 0, 0)
    t:SetPoint(pts[2], b, pts[2], 0, 0)
    if pts[3] == 1 then t:SetWidth(1) else t:SetHeight(1) end
    b.edges[i] = t
  end
  b.bag, b.slot = bag, slot
  buttons[key] = b
  return b
end

local function UpdateButton(b)
  local bag, slot = b.bag, b.slot
  local tex, count, locked, quality = GetContainerItemInfo(bag, slot)
  local link = GetContainerItemLink(bag, slot)
  SetItemButtonTexture(b, tex)
  SetItemButtonCount(b, count)
  SetItemButtonDesaturated(b, locked, 0.5, 0.5, 0.5)
  b.hasItem = tex and 1 or nil
  if link and (not quality or quality < 0) then
    local _, _, q = GetItemInfo(link)
    quality = q
  end
  local c = (tex and QCOLOR[quality or 1]) or { 0.18, 0.18, 0.2 }
  if tex and (quality or 1) <= 1 then c = { 0.3, 0.3, 0.32 } end
  for _, e in ipairs(b.edges) do e:SetVertexColor(c[1], c[2], c[3], 1) end
  if ContainerFrame_UpdateCooldown then pcall(ContainerFrame_UpdateCooldown, bag, b) end
  -- search dimming
  local match = true
  if searchText ~= "" then
    match = false
    if link then
      local name, _, _, _, _, itemType, subType = GetItemInfo(link)
      local hay = string.lower((name or "").." "..(itemType or "").." "..(subType or ""))
      match = string.find(hay, searchText, 1, true) ~= nil
    end
  end
  b:SetAlpha(match and 1 or 0.25)
end

local function Layout()
  if not frame then return end
  local cols = db.cols or 10
  local i = 0
  for _, b in pairs(buttons) do b:Hide() end
  local total, free = 0, 0
  for bag = 0, 4 do
    local n = GetContainerNumSlots(bag) or 0
    for slot = 1, n do
      local b = GetButton(bag, slot)
      local row, col = math.floor(i / cols), i % cols
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + col * (SIZE + GAP), -30 - row * (SIZE + GAP))
      b:Show()
      UpdateButton(b)
      i = i + 1
      total = total + 1
      if not GetContainerItemLink(bag, slot) then free = free + 1 end
    end
  end
  local rows = math.max(1, math.ceil(i / cols))
  frame:SetWidth(PAD * 2 + cols * (SIZE + GAP) - GAP)
  frame:SetHeight(30 + rows * (SIZE + GAP) - GAP + 34)
  frame.gold:SetText(Money(GetMoney()))
  frame.slots:SetText(free.."/"..total.." free")
end

local function Update()
  if not frame or not frame:IsShown() then return end
  Layout()
end

---------------------------------------------------------------------------------------------------
-- Sorting
---------------------------------------------------------------------------------------------------
local CLASS_ORDER = { ["Consumable"]=1, ["Quest"]=2, ["Weapon"]=3, ["Armor"]=4, ["Container"]=5, ["Quiver"]=5,
  ["Projectile"]=6, ["Gem"]=7, ["Trade Goods"]=8, ["Reagent"]=9, ["Recipe"]=10, ["Key"]=11, ["Miscellaneous"]=12 }
local sorting, sortTimer, sortMoves = nil, 0, 0

local function SortKey(link, count)
  local name, _, q, ilvl, _, itemType, subType, _, equipLoc = GetItemInfo(link)
  local id = ItemId(link) or 0
  local order = CLASS_ORDER[itemType or ""] or 12
  if id == 6948 then order = 0 end          -- Hearthstone first
  if q == 0 then order = 99 end              -- grey junk last
  return { order = order, q = q or 1, ilvl = ilvl or 0, sub = subType or "", loc = equipLoc or "",
           name = name or "", id = id, count = count or 1, link = link }
end

local function KeyLess(a, b)
  if a.order ~= b.order then return a.order < b.order end
  if a.q ~= b.q then return a.q > b.q end
  if a.loc ~= b.loc then return a.loc < b.loc end
  if a.ilvl ~= b.ilvl then return a.ilvl > b.ilvl end
  if a.sub ~= b.sub then return a.sub < b.sub end
  if a.name ~= b.name then return a.name < b.name end
  return a.count > b.count
end

local function Same(a, link, count) return a and link and a.id == ItemId(link) and a.count == (count or 1) end

local function AnyLocked(slots)
  for _, s in ipairs(slots) do
    local _, _, locked = GetContainerItemInfo(s[1], s[2])
    if locked then return true end
  end
  return false
end

local rebuilds = 0
local function StartSort(quiet, isRebuild)
  if isRebuild then rebuilds = rebuilds + 1 else rebuilds = 0 end
  if rebuilds > 20 then sorting = nil return end
  if Busy() then if not quiet then Msg("Can't sort during combat.") end return end
  if CursorHasItem and CursorHasItem() then return end
  local slots, items = {}, {}
  for bag = 0, 4 do
    if IsNormalBag(bag) then
      for slot = 1, GetContainerNumSlots(bag) or 0 do
        table.insert(slots, { bag, slot })
        local link = GetContainerItemLink(bag, slot)
        if link then
          local _, count = GetContainerItemInfo(bag, slot)
          table.insert(items, SortKey(link, count))
        end
      end
    end
  end
  table.sort(items, KeyLess)
  sorting = { slots = slots, want = items, quiet = quiet }
  sortMoves, sortTimer = 0, 0
end

-- One move per step: put the item that belongs in the first wrong slot there (swap), then wait for locks.
local function SortStep()
  local s = sorting
  if Busy() or sortMoves > 400 then sorting = nil return end
  if AnyLocked(s.slots) then return end
  for i, pos in ipairs(s.slots) do
    local want = s.want[i]
    local link = GetContainerItemLink(pos[1], pos[2])
    local _, count = GetContainerItemInfo(pos[1], pos[2])
    if want then
      if not Same(want, link, count) then
        for j = i + 1, #s.slots do
          local p2 = s.slots[j]
          local l2 = GetContainerItemLink(p2[1], p2[2])
          local _, c2 = GetContainerItemInfo(p2[1], p2[2])
          if Same(want, l2, c2) then
            ClearCursor()
            PickupContainerItem(p2[1], p2[2])
            PickupContainerItem(pos[1], pos[2])
            if CursorHasItem and CursorHasItem() then PickupContainerItem(p2[1], p2[2]) end
            sortMoves = sortMoves + 1
            return
          end
        end
        -- wanted item not found anymore (looted/used during sort): rebuild and continue
        StartSort(s.quiet, true)
        return
      end
    else
      break
    end
  end
  sorting = nil
  if not s.quiet then Msg("Bags sorted.") end
  Update()
end

---------------------------------------------------------------------------------------------------
-- Build the window
---------------------------------------------------------------------------------------------------
local function CreateWindow()
  frame = CreateFrame("Frame", "CleanBagsFrame", UIParent)
  frame:SetFrameStrata("HIGH")
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function() frame:StartMoving() end)
  frame:SetScript("OnDragStop", function()
    frame:StopMovingOrSizing()
    local p, _, rp, x, y = frame:GetPoint()
    db.pos = { p, rp, x, y }
  end)
  frame:SetBackdrop({ bgFile=SOLID, edgeFile=SOLID, edgeSize=1, insets={ left=1, right=1, top=1, bottom=1 } })
  frame:SetBackdropColor(0.05, 0.05, 0.06, 0.94)
  frame:SetBackdropBorderColor(0.22, 0.22, 0.25, 1)
  frame:SetScale(db.scale or 1)
  local p = db.pos or { "BOTTOMRIGHT", "BOTTOMRIGHT", -60, 110 }
  frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
  table.insert(UISpecialFrames, "CleanBagsFrame")

  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -9)
  title:SetText("Bags")

  local close = FlatButton(frame, "X", 20)
  close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
  close:SetScript("OnClick", function() frame:Hide() end)

  local sort = FlatButton(frame, "Sort", 44)
  sort:SetPoint("RIGHT", close, "LEFT", -4, 0)
  sort.tip = "Sort your bags now."
  sort:SetScript("OnClick", function() StartSort(false) end)
  frame.sortBtn = sort

  -- Search box
  local box = CreateFrame("EditBox", "CleanBagsSearch", frame)
  box:SetWidth(120) box:SetHeight(18)
  box:SetPoint("RIGHT", sort, "LEFT", -6, 0)
  box:SetAutoFocus(false)
  box:SetFontObject(GameFontHighlightSmall)
  box:SetTextInsets(5, 5, 0, 0)
  box:SetBackdrop({ bgFile=SOLID, edgeFile=SOLID, edgeSize=1, insets={ left=1, right=1, top=1, bottom=1 } })
  box:SetBackdropColor(0.1, 0.1, 0.11, 1)
  box:SetBackdropBorderColor(0.3, 0.3, 0.33, 1)
  box.hint = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  box.hint:SetPoint("LEFT", box, "LEFT", 6, 0)
  box.hint:SetText("Search")
  box:SetScript("OnTextChanged", function()
    searchText = string.lower(box:GetText() or "")
    if searchText == "" then box.hint:Show() else box.hint:Hide() end
    Update()
  end)
  box:SetScript("OnEscapePressed", function() box:SetText("") box:ClearFocus() end)
  box:SetScript("OnEnterPressed", function() box:ClearFocus() end)

  frame.gold = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.gold:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, 10)
  frame.slots = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  frame.slots:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PAD, 10)

  frame:SetScript("OnShow", function() Layout() end)
  frame:Hide()
  frame:SetScript("OnHide", function()
    if db.autoSort and not Busy() and not (MerchantFrame and MerchantFrame:IsShown())
       and not (BankFrame and BankFrame:IsShown()) and not (TradeFrame and TradeFrame:IsShown())
       and not (MailFrame and MailFrame:IsShown()) and not (AuctionFrame and AuctionFrame:IsShown()) then
      StartSort(true)
    end
  end)
end

---------------------------------------------------------------------------------------------------
-- Replace the default bag opening
---------------------------------------------------------------------------------------------------
local function Show() if frame then frame:Show() end end
local function Hide() if frame then frame:Hide() end end
local function Toggle() if frame then if frame:IsShown() then frame:Hide() else frame:Show() end end end

local function HookBags()
  if db.off then return end
  local function isBackpackBag(id) return id and id >= 0 and id <= 4 end
  ToggleBackpack = Toggle
  OpenBackpack = Show
  CloseBackpack = Hide
  OpenAllBags = function(force) if force then Show() else Toggle() end end  -- B key: open/close
  CloseAllBags = function() Hide() end
  local origToggleBag = ToggleBag
  ToggleBag = function(id)
    if isBackpackBag(id) then Toggle() else origToggleBag(id) end
  end
  local origOpenBag = OpenBag
  if origOpenBag then OpenBag = function(id) if isBackpackBag(id) then Show() else origOpenBag(id) end end end
end

---------------------------------------------------------------------------------------------------
-- Tooltips: sell value + comparison with what you have equipped
---------------------------------------------------------------------------------------------------
local LOC_SLOTS = {
  INVTYPE_HEAD={1}, INVTYPE_NECK={2}, INVTYPE_SHOULDER={3}, INVTYPE_BODY={4}, INVTYPE_CHEST={5}, INVTYPE_ROBE={5},
  INVTYPE_WAIST={6}, INVTYPE_LEGS={7}, INVTYPE_FEET={8}, INVTYPE_WRIST={9}, INVTYPE_HAND={10}, INVTYPE_FINGER={11,12},
  INVTYPE_TRINKET={13,14}, INVTYPE_CLOAK={15}, INVTYPE_WEAPON={16,17}, INVTYPE_SHIELD={17}, INVTYPE_2HWEAPON={16},
  INVTYPE_WEAPONMAINHAND={16}, INVTYPE_WEAPONOFFHAND={17}, INVTYPE_HOLDABLE={17}, INVTYPE_RANGED={18},
  INVTYPE_THROWN={18}, INVTYPE_RANGEDRIGHT={18}, INVTYPE_RELIC={18}, INVTYPE_TABARD={19},
}

local scan = CreateFrame("GameTooltip", "CleanBagsScan", nil, "GameTooltipTemplate")
scan:SetOwner(UIParent, "ANCHOR_NONE")

local PATTERNS = {
  { "^%+(%d+) (.+)$", function(v, n) return n, v end },
  { "^(%d+) Armor$", function(v) return "Armor", v end },
  { "^%(([%d%.]+) damage per second%)$", function(v) return "DPS", v end },
  { "^(%d+) Block$", function(v) return "Block", v end },
  { "Increases damage and healing done by magical spells and effects by up to (%d+)", function(v) return "Spell Power", v end },
  { "Increases healing done by spells and effects by up to (%d+)", function(v) return "Healing", v end },
  { "Increases attack power by (%d+)", function(v) return "Attack Power", v end },
  { "Restores (%d+) mana per 5 sec", function(v) return "Mana per 5", v end },
  { "Increases your (.-) rating by (%d+)", function(n, v) return n.." Rating", v end },
  { "Improves your (.-) rating by (%d+)", function(n, v) return n.." Rating", v end },
  { "Improves (.-) rating by (%d+)", function(n, v) return n.." Rating", v end },
  { "Increases (.-) by (%d+)%.$", function(n, v) return n, v end },
}

local function ReadStats(setter)
  scan:SetOwner(UIParent, "ANCHOR_NONE")
  scan:ClearLines()
  setter()
  local stats, order = {}, {}
  for i = 2, scan:NumLines() do
    local fs = getglobal("CleanBagsScanTextLeft"..i)
    local text = fs and fs:GetText()
    if text then
      text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
      text = string.gsub(text, "|r", "")
      text = string.gsub(text, "^%s+", "")
      text = string.gsub(text, "^Equip: ", "")
      for _, p in ipairs(PATTERNS) do
        local a, b = string.match(text, p[1])
        if a then
          local name, v = p[2](a, b)
          v = tonumber(v)
          if name and v then
            if not stats[name] then table.insert(order, name) end
            stats[name] = (stats[name] or 0) + v
          end
          break
        end
      end
    end
  end
  return stats, order
end

local function AddCompare(tt, link)
  local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(link)
  local slots = equipLoc and LOC_SLOTS[equipLoc]
  if not slots then return false end
  local slot = slots[1]
  -- rings/trinkets: fill an empty second slot first
  if (equipLoc == "INVTYPE_FINGER" or equipLoc == "INVTYPE_TRINKET")
     and GetInventoryItemLink("player", slots[1]) and not GetInventoryItemLink("player", slots[2]) then slot = slots[2] end
  -- one-handers and off-hands: if you hold a two-hander, that's what this replaces
  local mh = GetInventoryItemLink("player", 16)
  local mhLoc = mh and select(9, GetItemInfo(mh))
  if slot == 17 and mhLoc == "INVTYPE_2HWEAPON" then slot = 16 end
  local eqLink = GetInventoryItemLink("player", slot)
  local new, order = ReadStats(function() scan:SetHyperlink(link) end)
  local old, oldOrder = {}, {}
  if eqLink then
    if eqLink == link then return false end
    old, oldOrder = ReadStats(function() scan:SetInventoryItem("player", slot) end)
  end
  for _, n in ipairs(oldOrder) do if not new[n] then table.insert(order, n) end end
  local lines = {}
  for _, n in ipairs(order) do
    local d = (new[n] or 0) - (old[n] or 0)
    if math.abs(d) > 0.05 then
      local txt = (d > 0 and "+" or "")..(math.floor(d) == d and d or string.format("%.1f", d)).." "..n
      table.insert(lines, { txt, d > 0 })
    end
  end
  if #lines == 0 then return true end
  tt:AddLine(eqLink and "Compared to what you're wearing:" or "Empty slot - all of this is an upgrade:", 0.6, 0.6, 0.6)
  for _, l in ipairs(lines) do
    if l[2] then tt:AddLine("  "..l[1], 0.25, 1, 0.35) else tt:AddLine("  "..l[1], 1, 0.3, 0.3) end
  end
  return true
end

-- Which bag slot is the mouse over? (works for CleanBags and the default bags)
local function BagSlotUnderMouse()
  local f = GetMouseFocus and GetMouseFocus()
  if not f or not f.GetID or not f.GetParent then return end
  local p = f:GetParent()
  local name = f.GetName and f:GetName() or ""
  if p and p.GetID and (string.find(name, "^CleanBagsItem") or string.find(name, "^ContainerFrame%d+Item")) then
    return p:GetID(), f:GetID()
  end
end

local function OnItemTip(tt)
  if db.tipsOff then return end
  local _, link = tt:GetItem()
  if not link then return end
  local id = ItemId(link)
  local bag, slot = BagSlotUnderMouse()
  local fromBag = bag ~= nil and tt == GameTooltip
  -- sell value (the merchant window already shows it while you're at a vendor)
  local price = id and PRICES[id]
  if price and price > 0 and not (MerchantFrame and MerchantFrame:IsShown() and fromBag) then
    local count = 1
    if fromBag then local _, c = GetContainerItemInfo(bag, slot) count = c or 1 end
    if count > 1 then
      tt:AddLine("Sells for "..Money(price * count).."  |cff999999("..Money(price).." each)|r", 1, 1, 1)
    else
      tt:AddLine("Sells for "..Money(price), 1, 1, 1)
    end
  end
  -- comparison for gear in your bags
  if fromBag and not db.compareOff then
    local shown = AddCompare(tt, link)
    if shown and GameTooltip_ShowCompareItem and not tt.cbComparing then
      tt.cbComparing = true
      pcall(GameTooltip_ShowCompareItem)
      tt.cbComparing = nil
    end
  end
  tt:Show()
end

local function HookTip(tt)
  if not tt then return end
  if tt.HookScript then tt:HookScript("OnTooltipSetItem", function(self) OnItemTip(self or tt) end) return end
  local old = tt:GetScript("OnTooltipSetItem")
  tt:SetScript("OnTooltipSetItem", function(self, ...)
    if old then old(self, ...) end
    OnItemTip(self or tt)
  end)
end

---------------------------------------------------------------------------------------------------
-- Events and slash command
---------------------------------------------------------------------------------------------------
local ev = CreateFrame("Frame")
-- Sorting runs here (this frame never hides, so sorting keeps going after the bag window closes)
ev:SetScript("OnUpdate", function(self, elapsed)
  if sorting then
    sortTimer = sortTimer + (elapsed or arg1 or 0)
    if sortTimer > 0.06 then sortTimer = 0 SortStep() end
  end
end)
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("BAG_UPDATE")
ev:RegisterEvent("BAG_UPDATE_COOLDOWN")
ev:RegisterEvent("ITEM_LOCK_CHANGED")
ev:RegisterEvent("PLAYER_MONEY")
ev:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
ev:SetScript("OnEvent", function(self, event)
  event = event or _G.event
  if event == "PLAYER_LOGIN" then
    db = CleanBagsDB
    -- automatic sorting is off unless you turn it on with /cbag auto
    CreateWindow()
    HookBags()
    HookTip(GameTooltip)
    HookTip(ItemRefTooltip)
  else
    Update()
  end
end)

SLASH_CLEANBAGS1 = "/cbag"
SLASH_CLEANBAGS2 = "/cleanbags"
SlashCmdList["CLEANBAGS"] = function(msg)
  msg = string.lower(msg or "")
  local cmd, arg = string.match(msg, "^(%S*)%s*(.-)$")
  if cmd == "sort" then StartSort(false)
  elseif cmd == "auto" then
    db.autoSort = not db.autoSort
    Msg("Auto-sort when bags close: "..(db.autoSort and "ON" or "off"))
  elseif cmd == "cols" and tonumber(arg) then
    db.cols = math.max(6, math.min(20, tonumber(arg))) Layout()
  elseif cmd == "scale" and tonumber(arg) then
    db.scale = math.max(0.5, math.min(2, tonumber(arg))) frame:SetScale(db.scale)
  elseif cmd == "compare" then
    db.compareOff = not db.compareOff
    Msg("Gear comparison: "..(db.compareOff and "off" or "ON"))
  elseif cmd == "tips" then
    db.tipsOff = not db.tipsOff
    Msg("Sell value + comparison on tooltips: "..(db.tipsOff and "off" or "ON"))
  elseif cmd == "reset" then
    db.pos = nil db.scale = 1 db.cols = 10
    frame:ClearAllPoints() frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -60, 110) frame:SetScale(1) Layout()
  elseif cmd == "off" then
    db.off = true Msg("Default bags come back after /rl. /cbag on to undo.")
  elseif cmd == "on" then
    db.off = false Msg("CleanBags window back after /rl.")
  else
    Toggle()
    Msg("/cbag sort | auto | cols <6-20> | scale <0.5-2> | compare | tips | reset | off")
  end
end
