-- GearFinder: search every weapon and armor item on your server and add it with one click.
-- Written for the WoW 2.4.3 client. Type /gf (or /gearfinder) to open, /rl to reload the UI.

local ROWS, ROW_H = 15, 26
local W, H = 880, 628
local items, results = nil, {}
local playerClassId = 0

local QHEX = { [0]="9d9d9d", "ffffff", "1eff00", "0070dd", "a335ee", "ff8000", "e6cc80" }
local QRGB = { [0]={0.62,0.62,0.62}, {1,1,1}, {0.12,1,0}, {0,0.44,0.87}, {0.64,0.21,0.93}, {1,0.5,0}, {0.9,0.8,0.5} }
local CLASS_ID = { WARRIOR=1, PALADIN=2, HUNTER=3, ROGUE=4, PRIEST=5, SHAMAN=7, MAGE=8, WARLOCK=9, DRUID=11 }

-- Palette (dark, flat, Wowhead-like)
local C = {
  bg = {0.067, 0.067, 0.071, 0.97}, panel = {0.10, 0.10, 0.11, 1}, header = {0.14, 0.14, 0.15, 1},
  border = {0.24, 0.24, 0.26, 1}, rowA = {0.105, 0.105, 0.115, 1}, rowB = {0.125, 0.125, 0.135, 1},
  hover = {0.20, 0.20, 0.23, 1}, btn = {0.17, 0.17, 0.19, 1}, btnHover = {0.24, 0.24, 0.27, 1},
  accent = {1, 0.82, 0}, accentBtn = {0.45, 0.33, 0.05, 1}, accentBtnHover = {0.58, 0.43, 0.07, 1},
  text = {0.92, 0.92, 0.92}, muted = {0.58, 0.58, 0.62},
}
local SOLID = "Interface\\ChatFrame\\ChatFrameBackground"

local SLOT_NAME = { [1]="Head", [2]="Neck", [3]="Shoulder", [4]="Shirt", [5]="Chest", [6]="Waist", [7]="Legs",
  [8]="Feet", [9]="Wrist", [10]="Hands", [11]="Finger", [12]="Trinket", [13]="One-Hand", [14]="Shield",
  [15]="Ranged", [16]="Back", [17]="Two-Hand", [18]="Bag", [19]="Tabard", [20]="Chest", [21]="Main Hand",
  [22]="Off Hand", [23]="Held In Off-hand", [24]="Ammo", [25]="Thrown", [26]="Ranged", [28]="Relic" }
local WEAPON_NAME = { [0]="Axe", "Axe", "Bow", "Gun", "Mace", "Mace", "Polearm", "Sword", "Sword",
  nil, "Staff", nil, nil, "Fist Weapon", "Misc", "Dagger", "Thrown", "Spear", "Crossbow", "Wand", "Fishing Pole" }
local ARMOR_NAME = { [0]="Misc", "Cloth", "Leather", "Mail", "Plate", nil, "Shield", "Libram", "Idol", "Totem" }

local SKILL_UNLOCKS = {
  ["Axes"]={2,0}, ["Two-Handed Axes"]={2,1}, ["Bows"]={2,2}, ["Guns"]={2,3}, ["Maces"]={2,4},
  ["Two-Handed Maces"]={2,5}, ["Polearms"]={2,6}, ["Swords"]={2,7}, ["Two-Handed Swords"]={2,8},
  ["Staves"]={2,10}, ["Fist Weapons"]={2,13}, ["Daggers"]={2,15}, ["Thrown"]={2,16}, ["Crossbows"]={2,18},
  ["Wands"]={2,19}, ["Fishing"]={2,20},
  ["Cloth"]={4,1}, ["Leather"]={4,2}, ["Mail"]={4,3}, ["Plate Mail"]={4,4}, ["Shield"]={4,6},
}

local SLOT_FILTERS = {
  { "All slots" }, { "Head", {1} }, { "Neck", {2} }, { "Shoulder", {3} }, { "Back", {16} },
  { "Chest", {5,20} }, { "Wrist", {9} }, { "Hands", {10} }, { "Waist", {6} }, { "Legs", {7} },
  { "Feet", {8} }, { "Finger", {11} }, { "Trinket", {12} }, { "Main hand / 2H", {13,17,21} },
  { "Off hand / Shield", {13,14,22,23} }, { "Ranged / Wand", {15,25,26} }, { "Relic", {28} },
  { "Shirt / Tabard", {4,19} },
}
local TYPE_FILTERS = {
  { "All types" }, { "Cloth", 4,1 }, { "Leather", 4,2 }, { "Mail", 4,3 }, { "Plate", 4,4 }, { "Shield", 4,6 },
  { "Jewelry / Misc", 4,0 }, { "Daggers", 2,15 }, { "One-Hand Swords", 2,7 }, { "Two-Hand Swords", 2,8 },
  { "One-Hand Axes", 2,0 }, { "Two-Hand Axes", 2,1 }, { "One-Hand Maces", 2,4 }, { "Two-Hand Maces", 2,5 },
  { "Fist Weapons", 2,13 }, { "Polearms", 2,6 }, { "Staves", 2,10 }, { "Bows", 2,2 }, { "Guns", 2,3 },
  { "Crossbows", 2,18 }, { "Thrown", 2,16 }, { "Wands", 2,19 }, { "Librams", 4,7 }, { "Idols", 4,8 },
  { "Totems", 4,9 },
}
local QUALITY_FILTERS = { { "Any quality", 0 }, { "Uncommon +", 2 }, { "Rare +", 3 }, { "Epic +", 4 } }
-- "Most of a stat" sorting. Codes match the short names in the Stats column.
local STAT_SORT = {
  { "Sort by stat..." }, { "Most Stamina", {"Sta"} }, { "Most Strength", {"Str"} }, { "Most Agility", {"Agi"} },
  { "Most Intellect", {"Int"} }, { "Most Spirit", {"Spi"} }, { "Most Armor", {"Arm"} }, { "Highest DPS", {"DPS"} },
  { "Most Crit", {"Crit"} }, { "Most Spell Crit", {"SCrit"} }, { "Most Hit", {"Hit"} }, { "Most Spell Hit", {"SHit"} },
  { "Most Haste", {"Haste","SHaste"} }, { "Most Defense", {"Def"} }, { "Most Dodge", {"Dodge"} },
  { "Most Parry", {"Parry"} }, { "Most Block", {"Block"} }, { "Most Expertise", {"Exp"} },
  { "Most Resilience", {"Resil"} }, { "Most total stats", {"Sta","Str","Agi","Int","Spi"} },
}

local state = { slot=1, type=1, quality=1, stat=1, sortKey="ilvl", desc=true, usable=true, offset=0 }

-- value of one or more stats on an item, read from its stats text (cached)
local function StatValue(it, codes)
  it.sv = it.sv or {}
  local total = 0
  for _, code in ipairs(codes) do
    local v = it.sv[code]
    if v == nil then
      v = 0
      for num, name in string.gmatch(it.stats or "", "([%d%.]+) (%a+)") do
        if name == code then v = v + (tonumber(num) or 0) end
      end
      it.sv[code] = v
    end
    total = total + v
  end
  return total
end

---------------------------------------------------------------------------------------------------
-- Data
---------------------------------------------------------------------------------------------------
local function LoadItems()
  if items then return end
  items = {}
  for _, blob in ipairs(GearFinder_RAW or {}) do
    for line in string.gmatch(blob, "[^\n]+") do
      local id, name, q, cls, sub, inv, req, ilvl, mask, set, stats =
        string.match(line, "^(%d+)%^([^%^]*)%^(%d+)%^(%d+)%^(%d+)%^(%d+)%^(%d+)%^(%d+)%^(%d+)%^(%d+)%^(.*)$")
      if id then
        table.insert(items, { id=tonumber(id), name=name, lname=string.lower(name), q=tonumber(q),
          cls=tonumber(cls), sub=tonumber(sub), inv=tonumber(inv), req=tonumber(req), ilvl=tonumber(ilvl),
          mask=tonumber(mask), set=tonumber(set), stats=stats, lstats=string.lower(stats) })
      end
    end
  end
  GearFinder_RAW = nil
end

local function KnownProficiencies()
  local known = { ["2:14"]=true, ["4:0"]=true }
  for i = 1, GetNumSkillLines() do
    local name, isHeader = GetSkillLineInfo(i)
    local u = name and not isHeader and SKILL_UNLOCKS[name]
    if u then known[u[1]..":"..u[2]] = true end
  end
  local _, token = UnitClass("player")
  if token == "PALADIN" then known["4:7"] = true end
  if token == "DRUID" then known["4:8"] = true end
  if token == "SHAMAN" then known["4:9"] = true end
  return known
end

local function ClassAllowed(mask)
  if mask == 0 or playerClassId == 0 then return true end
  return math.floor(mask / 2^(playerClassId - 1)) % 2 == 1
end

local function ItemLink(it)
  return "|cff"..(QHEX[it.q] or "ffffff").."|Hitem:"..it.id..":0:0:0:0:0:0:0|h["..it.name.."]|h|r"
end

local function SlotText(it) return SLOT_NAME[it.inv] or "" end
local function TypeText(it)
  if it.cls == 2 then return WEAPON_NAME[it.sub] or "Weapon" end
  if it.sub == 0 then return "" end
  return ARMOR_NAME[it.sub] or ""
end

---------------------------------------------------------------------------------------------------
-- Small UI helpers (flat style)
---------------------------------------------------------------------------------------------------
local function Paint(frame, bg, border)
  frame:SetBackdrop({ bgFile=SOLID, edgeFile=SOLID, tile=false, edgeSize=1, insets={ left=1, right=1, top=1, bottom=1 } })
  frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
  local b = border or C.border
  frame:SetBackdropBorderColor(b[1], b[2], b[3], b[4] or 1)
end

local function Text(parent, font, r, g, b)
  local s = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
  if r then s:SetTextColor(r, g, b) end
  return s
end

local function FlatButton(parent, label, w, h, accent)
  local b = CreateFrame("Button", nil, parent)
  b:SetWidth(w) b:SetHeight(h)
  local base, over = accent and C.accentBtn or C.btn, accent and C.accentBtnHover or C.btnHover
  Paint(b, base)
  b.label = Text(b, "GameFontHighlightSmall")
  b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
  b.label:SetText(label)
  b:SetScript("OnEnter", function()
    b:SetBackdropColor(over[1], over[2], over[3], 1)
    if b.tip then
      GameTooltip:SetOwner(b, "ANCHOR_TOP")
      GameTooltip:AddLine(b.tip[1], 1, 1, 1)
      if b.tip[2] then GameTooltip:AddLine(b.tip[2], 0.8, 0.8, 0.8, true) end
      if b.tip[3] then GameTooltip:AddLine(b.tip[3], 0.55, 0.55, 0.55, true) end
      GameTooltip:Show()
    end
  end)
  b:SetScript("OnLeave", function() b:SetBackdropColor(base[1], base[2], base[3], 1) GameTooltip:Hide() end)
  return b
end

local function FlatEditBox(parent, w, placeholder, numeric)
  local e = CreateFrame("EditBox", nil, parent)
  e:SetWidth(w) e:SetHeight(24)
  Paint(e, C.panel)
  e:SetFontObject(ChatFontNormal)
  e:SetTextInsets(8, 8, 0, 0)
  e:SetAutoFocus(false)
  if numeric then e:SetNumeric(true) e:SetMaxLetters(2) e:SetJustifyH("CENTER") end
  e.ph = Text(e, "GameFontDisableSmall")
  e.ph:SetPoint("LEFT", e, "LEFT", 8, 0)
  e.ph:SetText(placeholder or "")
  local function ph() if (e:GetText() or "") == "" and not e.focused then e.ph:Show() else e.ph:Hide() end end
  e:SetScript("OnEditFocusGained", function() e.focused = true e:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 0.8) ph() end)
  e:SetScript("OnEditFocusLost", function() e.focused = false e:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1) ph() end)
  e:SetScript("OnEscapePressed", function() e:ClearFocus() end)
  e.UpdatePlaceholder = ph
  return e
end

---------------------------------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------------------------------
local f, rows, countText, searchBox, minBox, maxBox, slider, usableBtn
local headers = {}
local openMenu
local dropdowns = {}
local pending, equipTimer, equipBagId

local function CloseMenus() if openMenu then openMenu:Hide() openMenu = nil end end

local function UpdateRows()
  local total = #results
  local maxOff = math.max(0, total - ROWS)
  if state.offset > maxOff then state.offset = maxOff end
  for i = 1, ROWS do
    local row, it = rows[i], results[i + state.offset]
    if it then
      row.item = it
      local _, _, _, _, _, _, _, _, _, tex = GetItemInfo(it.id)
      row.icon:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")
      local q = QRGB[it.q] or QRGB[1]
      row.iconBorder:SetTexture(q[1], q[2], q[3], 0.9)
      row.name:SetText(it.name)
      row.name:SetTextColor(q[1], q[2], q[3])
      row.name:ClearAllPoints()
      if it.set > 0 then
        row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 44, -3)
        row.sub:SetText("Part of a set")
      else
        row.name:SetPoint("LEFT", row, "LEFT", 44, 0)
        row.sub:SetText("")
      end
      row.req:SetText(it.req > 0 and it.req or "-")
      row.ilvl:SetText(it.ilvl)
      row.slot:SetText(SlotText(it))
      row.kind:SetText(TypeText(it))
      row.stats:SetText(it.stats)
      if it.set > 0 then row.setBtn:Show() else row.setBtn:Hide() end
      row:Show()
    else
      row.item = nil
      row:Hide()
    end
  end
  if total == 0 then
    countText:SetText("No items match these filters")
  else
    countText:SetText(string.format("Showing %d-%d of %d items", state.offset + 1, math.min(total, state.offset + ROWS), total))
  end
  slider:SetMinMaxValues(0, maxOff)
  slider.updating = true
  slider:SetValue(state.offset)
  slider.updating = false
  if maxOff > 0 then slider:Show() else slider:Hide() end
end

local function UpdateHeaders()
  for _, h in ipairs(headers) do
    if h.key == state.sortKey and state.stat == 1 then
      h.label:SetText(h.title..(state.desc and "  v" or "  ^"))
      h.label:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
    else
      h.label:SetText(h.title)
      h.label:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
    end
  end
end

local function Refresh()
  LoadItems()
  local text = string.lower(searchBox:GetText() or "")
  local minL = tonumber(minBox:GetText()) or 0
  local maxL = tonumber(maxBox:GetText()) or 70
  local slotSet
  local sf = SLOT_FILTERS[state.slot]
  if sf[2] then slotSet = {} for _, v in ipairs(sf[2]) do slotSet[v] = true end end
  local tf = TYPE_FILTERS[state.type]
  local minQ = QUALITY_FILTERS[state.quality][2]
  local known = state.usable and KnownProficiencies()

  results = {}
  for _, it in ipairs(items) do
    if it.req >= minL and it.req <= maxL and it.q >= minQ
      and (not slotSet or slotSet[it.inv])
      and (not tf[2] or (it.cls == tf[2] and it.sub == tf[3]))
      and (not known or (known[it.cls..":"..it.sub] and ClassAllowed(it.mask)))
      and (text == "" or string.find(it.lname, text, 1, true) or string.find(it.lstats, text, 1, true)) then
      table.insert(results, it)
    end
  end

  local statCodes = STAT_SORT[state.stat] and STAT_SORT[state.stat][2]
  if statCodes then
    local kept = {}
    for _, it in ipairs(results) do
      it.sortv = StatValue(it, statCodes)
      if it.sortv > 0 then table.insert(kept, it) end
    end
    results = kept
    table.sort(results, function(a, b)
      if a.sortv ~= b.sortv then return a.sortv > b.sortv end
      if a.ilvl ~= b.ilvl then return a.ilvl > b.ilvl end
      return a.lname < b.lname
    end)
    state.offset = 0
    UpdateHeaders()
    UpdateRows()
    return
  end

  local key, desc = state.sortKey, state.desc
  table.sort(results, function(a, b)
    local x, y = a[key], b[key]
    if key == "name" then x, y = a.lname, b.lname end
    if x ~= y then if desc then return x > y else return x < y end end
    return a.lname < b.lname
  end)

  state.offset = 0
  UpdateHeaders()
  UpdateRows()
end

local function RefreshSoon() pending = 0.3 end

-- Smart filters: if the slot and type you picked can never go together (Neck + Plate, Back + Daggers...),
-- the other filter goes back to "All" so you never stare at an empty list. Sorting by a stat clears the
-- column sort highlight and vice versa.
local function FixFilters(changed)
  LoadItems()
  if changed == "slot" or changed == "type" then
    local sf, tf = SLOT_FILTERS[state.slot], TYPE_FILTERS[state.type]
    if sf[2] and tf[2] then
      local slotSet = {}
      for _, v in ipairs(sf[2]) do slotSet[v] = true end
      local any = false
      for _, it in ipairs(items) do
        if slotSet[it.inv] and it.cls == tf[2] and it.sub == tf[3] then any = true break end
      end
      if not any then
        local other = (changed == "slot") and "type" or "slot"
        state[other] = 1
        for _, d in ipairs(dropdowns) do if d.key == other then d.relabel() end end
      end
    end
  end
end

local function MakeDropdown(parent, list, key, w)
  local function txt(v) return type(v) == "table" and v[1] or v end
  local b = FlatButton(parent, "", w, 24)
  b.label:ClearAllPoints()
  b.label:SetPoint("LEFT", b, "LEFT", 10, 0)
  local arrow = Text(b, "GameFontDisableSmall")
  arrow:SetPoint("RIGHT", b, "RIGHT", -10, 0)
  arrow:SetText("v")
  local function label() b.label:SetText(txt(list[state[key]])) end
  label()
  b.relabel = label
  b.key = key
  table.insert(dropdowns, b)

  local PER_COL, OPT_W, OPT_H = 13, 150, 20
  local cols = math.ceil(#list / PER_COL)
  local menu = CreateFrame("Frame", nil, f)
  menu:SetFrameStrata("DIALOG")
  Paint(menu, C.header)
  menu:SetWidth(cols * OPT_W + 8)
  menu:SetHeight(math.min(#list, PER_COL) * OPT_H + 8)
  menu:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -2)
  menu:EnableMouse(true)
  menu:Hide()
  menu.opts = {}
  for i, v in ipairs(list) do
    local o = CreateFrame("Button", nil, menu)
    o:SetWidth(OPT_W) o:SetHeight(OPT_H)
    o:SetPoint("TOPLEFT", menu, "TOPLEFT", 4 + math.floor((i - 1) / PER_COL) * OPT_W, -4 - ((i - 1) % PER_COL) * OPT_H)
    local hl = o:CreateTexture(nil, "BACKGROUND")
    hl:SetAllPoints(o)
    hl:SetTexture(C.hover[1], C.hover[2], C.hover[3], 1)
    hl:Hide()
    o.text = Text(o, "GameFontHighlightSmall")
    o.text:SetPoint("LEFT", o, "LEFT", 8, 0)
    o.text:SetText(txt(v))
    o:SetScript("OnEnter", function() hl:Show() end)
    o:SetScript("OnLeave", function() hl:Hide() end)
    o:SetScript("OnClick", function()
      state[key] = i
      label()
      CloseMenus()
      FixFilters(key)
      Refresh()
    end)
    menu.opts[i] = o
  end
  b:SetScript("OnClick", function()
    local wasOpen = (openMenu == menu)
    CloseMenus()
    if not wasOpen then
      for i, o in ipairs(menu.opts) do
        if i == state[key] then o.text:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
        else o.text:SetTextColor(C.text[1], C.text[2], C.text[3]) end
      end
      menu:Show()
      openMenu = menu
    end
  end)
  return b
end

-- Quick actions ------------------------------------------------------------------------------------
local function Say(cmd) SendChatMessage(cmd, "SAY") end
local function Msg(t) DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Gear Finder:|r "..t) end
local function TargetName()
  if UnitExists("target") and UnitIsPlayer("target") and not UnitIsUnit("target", "player") then
    return UnitName("target")
  end
  Msg("Target one of your bots first.")
end

local function EquipNewBags()
  local used = {}
  for invBag = 1, 4 do
    local inv = ContainerIDToInventoryID(invBag)
    if not GetInventoryItemLink("player", inv) then
      local placed = false
      for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
          local link = GetContainerItemLink(bag, slot)
          if not placed and not used[bag..":"..slot] and link
            and tonumber(string.match(link, "item:(%d+)") or 0) == equipBagId then
            PickupContainerItem(bag, slot)
            PutItemInBag(inv)
            used[bag..":"..slot] = true
            placed = true
          end
        end
      end
    end
  end
end
local function AddBags(id) Say(".additem "..id.." 4") equipBagId, equipTimer = id, 1.5 end

local BuildTabs, BuildPages
---------------------------------------------------------------------------------------------------
-- Tabs and the non-gear pages (Character, Buffs, Bots, World)
---------------------------------------------------------------------------------------------------
local pages, tabButtons = {}, {}
local TAB_LIST = { { "gear", "Gear" }, { "char", "Character" }, { "buffs", "Buffs" }, { "bots", "Bots" }, { "group", "Group" }, { "world", "World" } }
local currentTab = "gear"

local function ShowTab(key)
  currentTab = key
  for _, t in ipairs(TAB_LIST) do
    local k = t[1]
    if k == key then pages[k]:Show() else pages[k]:Hide() end
    local b = tabButtons[k]
    if k == key then
      b:SetBackdropColor(C.panel[1], C.panel[2], C.panel[3], 1)
      b.label:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
      b.line:Show()
    else
      b:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], 1)
      b.label:SetTextColor(0.75, 0.75, 0.75)
      b.line:Hide()
    end
  end
  CloseMenus()
  GearFinderDB = GearFinderDB or {}
  GearFinderDB.tab = key
end

BuildTabs = function(parent)
  for i, t in ipairs(TAB_LIST) do
    local b = CreateFrame("Button", nil, parent)
    b:SetWidth(120) b:SetHeight(26)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", 16 + (i - 1) * 124, -44)
    Paint(b, C.bg)
    b.label = Text(b, "GameFontNormal")
    b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.label:SetText(t[2])
    b.line = b:CreateTexture(nil, "OVERLAY")
    b.line:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 1, 1)
    b.line:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
    b.line:SetHeight(2)
    b.line:SetTexture(C.accent[1], C.accent[2], C.accent[3], 1)
    b:SetScript("OnClick", function() ShowTab(t[1]) end)
    tabButtons[t[1]] = b
    local p = CreateFrame("Frame", nil, parent)
    p:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -34)
    p:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    pages[t[1]] = p
  end
end

-- A titled box of buttons. items = { { label, onClick, tooltip }, ... }. Returns the box.
local function Section(page, title, note, items, x, y, w, cols, bw)
  cols, bw = cols or 4, bw or 128
  local rowsN = math.ceil(#items / cols)
  local box = CreateFrame("Frame", nil, page)
  box:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
  box:SetWidth(w)
  box:SetHeight(34 + rowsN * 28 + (note and 16 or 0))
  Paint(box, C.panel)
  local t = Text(box, "GameFontNormalSmall")
  t:SetPoint("TOPLEFT", box, "TOPLEFT", 10, -9)
  t:SetText(title)
  t:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
  local top = -28
  if note then
    local n = Text(box, "GameFontDisableSmall")
    n:SetPoint("TOPLEFT", box, "TOPLEFT", 10, -24)
    n:SetWidth(w - 20) n:SetJustifyH("LEFT")
    n:SetText(note)
    top = -44
  end
  box.buttons = {}
  for i, it in ipairs(items) do
    local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
    local b = FlatButton(box, it[1], bw, 24, it.accent)
    b:SetPoint("TOPLEFT", box, "TOPLEFT", 10 + col * (bw + 4), top - row * 28)
    b.tip = { it[1], it[3], it[4] }
    b:SetScript("OnClick", it[2])
    box.buttons[i] = b
  end
  return box
end

-- Chat helpers for bots ----------------------------------------------------------------------------
local function Party(cmd)
  if GetNumPartyMembers and GetNumPartyMembers() > 0 then SendChatMessage(cmd, "PARTY")
  else Msg("You're not in a party. Invite some bots first.") end
end
local function WhisperTarget(cmd)
  local n = TargetName()
  if n then SendChatMessage(cmd, "WHISPER", nil, n) end
end

-- Buffs ----------------------------------------------------------------------------------------------
-- { label, { {minLevel, spellId}, ... } } - the highest rank you meet is used.
local CLASS_BUFFS = {
  { "Fortitude", { {1,1243},{12,1244},{24,1245},{36,2791},{48,10937},{60,10938},{70,25389} } },
  { "Arcane Intellect", { {1,1459},{14,1460},{28,1461},{42,10156},{56,10157},{70,27126} } },
  { "Mark of the Wild", { {1,1126},{10,5232},{20,6756},{30,5234},{40,8907},{50,9884},{60,9885},{70,26990} } },
  { "Blessing of Kings", { {1,20217} } },
  { "Blessing of Might", { {1,19740},{12,19834},{22,19835},{32,19836},{42,19837},{52,19838},{60,25291},{70,27140} } },
  { "Blessing of Wisdom", { {1,19742},{24,19850},{34,19852},{44,19853},{54,19854},{60,25290},{65,27142} } },
  { "Divine Spirit", { {1,14752},{40,14818},{50,14819},{60,27841},{70,25312} } },
  { "Shadow Protection", { {1,976},{42,10957},{56,10958},{68,25433} } },
  { "Thorns", { {1,467},{14,782},{24,1075},{34,8914},{44,9756},{54,9910},{64,26992} } },
  { "Battle Shout", { {1,6673},{12,5242},{22,6192},{32,11549},{42,11550},{52,11551},{60,25289},{69,2048} } },
  { "Trueshot Aura", { {1,19506},{50,20905},{60,20906},{70,27066} } },
  { "Amplify Magic", { {1,1008},{30,8455},{42,10169},{54,10170},{63,27130},{69,33946} } },
}
local SCROLLS = {
  { "Stamina", { {1,8099},{30,8100},{45,8101},{60,12178},{65,33081} } },
  { "Intellect", { {1,8096},{30,8097},{45,8098},{60,12176},{65,33078} } },
  { "Spirit", { {1,8112},{25,8113},{40,8114},{55,12177},{65,33080} } },
  { "Agility", { {1,8115},{35,8116},{50,8117},{60,12174},{65,33077} } },
  { "Strength", { {1,8118},{35,8119},{50,8120},{60,12179},{65,33082} } },
  { "Protection", { {1,8091},{25,8094},{40,8095},{55,12175},{65,33079} } },
}
local ELIXIRS = {
  { "Agility (battle)", { {1,2374},{15,3158},{20,3160},{27,11328},{38,11334},{46,17538},{60,28497} } },
  { "Strength (battle)", { {1,2367},{15,3162},{20,3164},{27,11331},{46,11405},{60,28490} } },
  { "Spell power (battle)", { {40,16889},{60,33721} } },
  { "Attack power (battle)", { {60,33720} } },
  { "All stats (battle)", { {60,33726} } },
  { "Intellect (guardian)", { {1,2376},{15,3166},{20,3168},{27,11393},{38,11396},{46,17535},{60,39627} } },
  { "Armor (guardian)", { {1,673},{10,834},{17,3220},{30,11349},{40,11348},{60,28502} } },
  { "Health (guardian)", { {1,3593},{60,39625} } },
}
local FLASKS = {
  { "Titans (health)", { {50,17626} } },
  { "Relentless Assault (AP)", { {65,28520} } },
  { "Pure Death (shadow/fire/frost)", { {65,28540} } },
  { "Blinding Light (arcane/holy/nature)", { {65,28521} } },
  { "Mighty Restoration (mp5)", { {65,28519} } },
  { "Fortification (tank)", { {65,28518} } },
}
local POTIONS = {
  heal = { {1,118},{10,858},{15,929},{21,1710},{35,3928},{45,13446},{55,22829} },
  mana = { {1,2455},{14,3385},{22,3827},{31,6149},{41,13443},{49,13444},{55,22832} },
}

local function BestRank(list, lvl)
  local id
  for _, r in ipairs(list) do if lvl >= r[1] then id = r[2] end end
  return id
end
local function BuffLevel()
  if UnitExists("target") and UnitIsPlayer("target") then return UnitLevel("target") or 1 end
  return UnitLevel("player") or 1
end
local function ApplyAura(list, label)
  if UnitExists("target") and not UnitIsPlayer("target") then Msg("Clear your target (or target yourself or a bot) first.") return end
  local id = BestRank(list, BuffLevel())
  if not id then Msg(label.." needs a higher level.") return end
  Say(".aura "..id)
end
local function AuraItems(list)
  local out = {}
  for _, b in ipairs(list) do
    table.insert(out, { b[1], function() ApplyAura(b[2], b[1]) end,
      "Applies the best rank for your level (or your target bot's level).", "No target = you. Target a bot to buff it." })
  end
  return out
end

-- Armor skills a class normally has (Mail/Plate come from the class trainer at level 40).
local CLASS_ARMOR = {
  WARRIOR = { {1,9077}, {1,8737}, {1,9116}, {40,750} },
  PALADIN = { {1,9077}, {1,8737}, {1,9116}, {40,750} },
  HUNTER  = { {1,9077}, {40,8737} },
  SHAMAN  = { {1,9077}, {1,9116}, {40,8737} },
  ROGUE   = { {1,9077} },
  DRUID   = { {1,9077} },
}
local function LearnClassArmor()
  local _, class = UnitClass("player")
  local lvl = UnitLevel("player") or 1
  Say(".learn 9078")
  for _, a in ipairs(CLASS_ARMOR[class] or {}) do
    if lvl >= a[1] then Say(".learn "..a[2]) end
  end
end

-- Pages ------------------------------------------------------------------------------------------------
BuildPages = function()
  local FULL = W - 32
  local HALF = (W - 40) / 2

  -- Character
  local cp = pages.char
  Section(cp, "LEVEL", "Applies to your target if a player or bot is selected.", {
    { "+1 level", function() Say(".levelup 1") end, "Gain one level" },
    { "+5 levels", function() Say(".levelup 5") end, "Gain five levels" },
    { "Level 60", function() local l = UnitLevel("player") or 60 if l < 60 then Say(".levelup "..(60 - l)) end end, "Jump to level 60" },
    { "Level 70", function() local l = UnitLevel("player") or 70 if l < 70 then Say(".levelup "..(70 - l)) end end, "Jump to level 70" },
  }, 16, -50, HALF, 2, 200)
  Section(cp, "GOLD", nil, {
    { "+10 gold", function() Say(".modify money 100000") end, "Add 10 gold" },
    { "+100 gold", function() Say(".modify money 1000000") end, "Add 100 gold" },
    { "+1000 gold", function() Say(".modify money 10000000") end, "Add 1000 gold" },
  }, 24 + HALF, -50, HALF, 3, 130)
  Section(cp, "BAGS & ITEMS", nil, {
    { "16-slot bags", function() AddBags(21841) end, "Four Netherweave Bags, placed into empty bag slots" },
    { "18-slot bags", function() AddBags(21843) end, "Four Imbued Netherweave Bags, placed into empty bag slots" },
    { "Repair", function() Say(".repairitems") end, "Repair every item" },
  }, 24 + HALF, -130, HALF, 3, 130)
  Section(cp, "SKILLS & SPELLS", nil, {
    { "Max skills", function() Say(".maxskill") end, "Max weapon and other skills for your level" },
    { "All weapons", function()
        for _, id in ipairs({196,197,198,199,200,201,202,227,264,266,1180,2567,5009,5011,15590,674}) do Say(".learn "..id) end
      end, "Learn every weapon type plus Dual Wield" },
    { "Class spells", function() Say(".learn all_myclass") LearnClassArmor() end, "Learn every spell of your own class, plus its armor types (Mail/Plate at 40)" },
    { "All armor", function() for _, id in ipairs({9078,9077,8737,750,9116}) do Say(".learn "..id) end end, "Learn Cloth, Leather, Mail, Plate and Shield for any class" },
    { "Reset talents", function() Say(".reset talents") end, "Refund all talent points" },
    { "Cooldowns", function() Say(".cooldown") end, "Reset all spell cooldowns" },
    { "Revive", function() Say(".revive") end, "Bring your target (or you) back to life" },
  }, 16, -210, FULL, 6, 134)
  Section(cp, "MOVEMENT", nil, {
    { "Speed x1.5", function() Say(".modify speed 1.5") end, "Run 50% faster (until you log out)" },
    { "Speed x2", function() Say(".modify speed 2") end, "Run twice as fast" },
    { "Normal speed", function() Say(".modify speed 1") end, "Back to normal speed" },
  }, 16, -308, FULL, 6, 134)

  Section(cp, "XP RATE  (this character - clear your target first)", "Locked = no XP at all, for staying at a level. Needs the server running the newest settings.", {
    { "Locked (x0)", function() Say(".hardcore xp 0") end, "Stop gaining XP" },
    { "x0.5", function() Say(".hardcore xp 0.5") end, "Half XP" },
    { "x1", function() Say(".hardcore xp 1") end, "Normal XP (on top of the server rate)" },
    { "x2", function() Say(".hardcore xp 2") end, "Double XP" },
    { "x5", function() Say(".hardcore xp 5") end, "Five times XP" },
  }, 16, -388, FULL, 6, 134)

  -- Buffs
  local bp = pages.buffs
  local b1 = Section(bp, "CLASS BUFFS", "Best rank for your level. No target = you, target a bot to buff it.", AuraItems(CLASS_BUFFS), 16, -50, FULL, 6, 134)
  local b2 = Section(bp, "SCROLLS", nil, AuraItems(SCROLLS), 16, -50 - b1:GetHeight() - 8, FULL, 6, 134)
  local b3 = Section(bp, "ELIXIRS  (one battle + one guardian at a time)", nil, AuraItems(ELIXIRS), 16, -50 - b1:GetHeight() - b2:GetHeight() - 16, FULL, 4, 205)
  local b4 = Section(bp, "FLASKS  (level 50+ / 65+)", nil, AuraItems(FLASKS), 16, -50 - b1:GetHeight() - b2:GetHeight() - b3:GetHeight() - 24, FULL, 3, 275)
  Section(bp, "POTIONS & EVERYTHING", nil, {
    { "5 healing potions", function() Say(".additem "..BestRank(POTIONS.heal, UnitLevel("player") or 1).." 5") end, "Best healing potion for your level" },
    { "5 mana potions", function() Say(".additem "..BestRank(POTIONS.mana, UnitLevel("player") or 1).." 5") end, "Best mana potion for your level" },
    { "All class buffs", function() for _, b in ipairs(CLASS_BUFFS) do ApplyAura(b[2], b[1]) end end, "Every class buff at once" },
    { "All scrolls", function() for _, b in ipairs(SCROLLS) do ApplyAura(b[2], b[1]) end end, "Every scroll at once" },
    { "Remove all buffs", function() Say(".unaura all") end, "Clears every aura from you (or your target)" },
  }, 16, -50 - b1:GetHeight() - b2:GetHeight() - b3:GetHeight() - b4:GetHeight() - 32, FULL, 5, 164)

  -- Bots
  local tp = pages.bots
  Section(tp, "TARGETED BOT", "Target one of your bots first.", {
    { "Init", function() local n = TargetName() if n then Say(".bot init "..n) end end, "Bot jumps to your level with gear, spells and supplies" },
    { "Upgrade gear", function() local n = TargetName() if n then Say(".bot upgrade "..n) end end, "Upgrade the bot's current gear" },
    { "Enchant", function() local n = TargetName() if n then Say(".bot enchants "..n) end end, "Enchant the bot's gear for its spec" },
    { "Prepare", function() local n = TargetName() if n then Say(".bot prepare "..n) end end, "Food, ammo, potions and reagents" },
    { "Train", function() local n = TargetName() if n then Say(".bot train "..n) end end, "Learn every spell for its level" },
    { "Summon", function() local n = TargetName() if n then Say(".summon "..n) end end, "Teleport the bot to you" },
    { "Show gear", function() WhisperTarget("c equip") end, "The bot whispers you a link for every item it's wearing (works at any range)" },
    { "Show bags", function() WhisperTarget("c") end, "The bot whispers you what's in its bags" },
    { "Stats", function() WhisperTarget("stats") end, "Gold, bag space, durability and XP" },
    { "Give bags", function() if TargetName() then Say(".additem 21843 4") end end, "Four 18-slot bags into the bot's bags" },
    { "Level to me", function()
        local n = TargetName()
        if n then local d = (UnitLevel("player") or 1) - (UnitLevel("target") or 1)
          if d > 0 then Say(".levelup "..d) else Msg(n.." is already your level or higher.") end end
      end, "Raise the bot to your level" },
  }, 16, -50, FULL, 6, 134)
  Section(tp, "WHOLE PARTY  (party chat commands)", "Every bot in your group listens.", {
    { "Hunt mobs: on", function() Party("nc +grind") end, "Bots look for and attack nearby mobs on their own" },
    { "Hunt mobs: off", function() Party("nc -grind") end, "Bots only fight when you do" },
    { "Assist: on", function() Party("co +dps assist") end, "Damage bots attack anything fighting the group" },
    { "Tank assist: on", function() Party("co +tank assist") end, "Tanks grab anything hitting the group" },
    { "Follow me", function() Party("follow") end, "Bots follow you" },
    { "Stay here", function() Party("stay") end, "Bots stay where they are" },
    { "Attack my target", function() Party("attack") end, "Everyone attacks what you're targeting" },
    { "Summon all", function()
        for i = 1, GetNumPartyMembers() do local n = UnitName("party"..i) if n then Say(".summon "..n) end end
      end, "Teleport every party member to you" },
    { "Repair all", function() Party("repair") end, "Bots repair at a nearby vendor" },
    { "Release spirit", function() Party("release") end, "Dead bots release" },
    { "Reset AI", function() Party("reset ai") end, "Clears every strategy change back to default" },
    { "Leave party", function() Party("leave") end, "All bots leave your group" },
  }, 16, -170, FULL, 6, 134)

  local PET_SPELLS = {
    { "Fireball", { {1,133},{6,143},{12,145},{18,3140},{24,8400},{30,8401},{36,8402},{42,10148},{48,10149},{54,10150},{60,10151},{66,27070} } },
    { "Frostbolt", { {1,116},{8,205},{14,837},{20,7322},{26,8406},{32,8407},{38,8408},{44,10179},{50,10180},{56,10181},{60,25304},{63,27071},{69,27072} } },
    { "Frost Nova", { {1,122},{26,865},{40,6131},{54,10230},{67,27088} } },
    { "Arcane Missiles", { {1,5143},{16,5144},{24,5145},{32,8416},{40,8417},{48,10211},{56,10212},{60,25345},{63,27075},{64,27076} } },
    { "Shadow Bolt", { {1,686},{6,695},{12,705},{20,1088},{28,1106},{36,7641},{44,11659},{52,11660},{60,11661},{69,27209} } },
    { "Lightning Bolt", { {1,403},{8,529},{14,548},{20,915},{26,943},{32,6041},{38,10391},{44,10392},{50,15207},{56,15208},{60,19874},{62,25448},{67,25449} } },
    { "Chain Lightning", { {1,421},{40,930},{48,2860},{56,10605},{63,25439},{70,25442} } },
    { "Moonfire", { {1,8921},{10,8924},{16,8925},{22,8926},{28,8927},{34,8928},{40,8929},{46,9833},{52,9834},{58,9835},{63,26987},{70,26988} } },
    { "Smite", { {1,585},{6,591},{14,598},{22,984},{30,1004},{38,6060},{46,10933},{54,10934},{61,25363},{69,25364} } },
    { "Renew", { {1,139},{14,6074},{20,6075},{26,6076},{32,6077},{38,6078},{44,10927},{50,10928},{56,10929},{60,25315},{65,25221},{70,25222} } },
    { "Flash Heal", { {1,2061},{26,9472},{32,9473},{38,9474},{44,10915},{50,10916},{56,10917},{61,25233},{67,25235} } },
    { "Healing Touch", { {1,5185},{8,5186},{14,5187},{20,5188},{26,5189},{32,6778},{38,8903},{44,9758},{50,9888},{56,9889},{60,25297},{62,26978},{69,26979} } },
  }
  local petItems = {}
  for _, ps in ipairs(PET_SPELLS) do
    table.insert(petItems, { ps[1], function()
      local id = BestRank(ps[2], UnitLevel("pet") or UnitLevel("player") or 1)
      if id then Say(".pet learn "..id) end
    end, "Teach your pet the best rank for its level", "Uses the pet's own mana. Hunter pets have no mana, so this is for warlock pets." })
  end
  local petBox = Section(tp, "TEACH YOUR PET A SPELL  (cloud build)", "Summon your pet first. It casts the spell from its pet bar; right-click the button there to toggle autocast.", petItems, 16, -296, FULL, 6, 134)
  Section(tp, "DEATH ROLL A BOT FOR GOLD  (cloud build - target the bot first)", "You both roll 1-1000, then 1-(last roll), back and forth. Whoever rolls a 1 pays up automatically.", {
    { "Roll for 1g", function() Say(".deathroll 1") end, "Wager 1 gold" },
    { "Roll for 10g", function() Say(".deathroll 10") end, "Wager 10 gold" },
    { "Roll for 50g", function() Say(".deathroll 50") end, "Wager 50 gold" },
    { "Roll for 100g", function() Say(".deathroll 100") end, "Wager 100 gold" },
    { "Roll for 500g", function() Say(".deathroll 500") end, "Wager 500 gold" },
  }, 16, -296 - petBox:GetHeight() - 8, FULL, 6, 134)

  -- Group (cloud build: .recruit)
  local gp = pages.group
  Section(gp, "RECRUIT BOTS  (cloud build)", "Free bots near your level join your group and come to you. Bots far from your level get rebuilt at your level.", {
    { "Tank", function() Say(".recruit tank") end, "Add a tank" },
    { "Healer", function() Say(".recruit healer") end, "Add a healer" },
    { "Damage", function() Say(".recruit dps") end, "Add a damage dealer" },
    { "Questing buddy", function() Say(".recruit any") end, "Add one bot of any role" },
    { "Fill dungeon group", function() Say(".recruit group") end, "Fill up to 5: one tank, one healer, the rest damage (counts you too)", accent = true },
    { "Dismiss bots", function() Say(".recruit dismiss") end, "Every bot leaves your group" },
  }, 16, -50, FULL, 6, 134)
  Section(gp, "RECRUIT A CLASS", nil, {
    { "Warrior", function() Say(".recruit warrior") end, "Add a Warrior bot" },
    { "Paladin", function() Say(".recruit paladin") end, "Add a Paladin bot" },
    { "Hunter", function() Say(".recruit hunter") end, "Add a Hunter bot" },
    { "Rogue", function() Say(".recruit rogue") end, "Add a Rogue bot" },
    { "Priest", function() Say(".recruit priest") end, "Add a Priest bot" },
    { "Shaman", function() Say(".recruit shaman") end, "Add a Shaman bot" },
    { "Mage", function() Say(".recruit mage") end, "Add a Mage bot" },
    { "Warlock", function() Say(".recruit warlock") end, "Add a Warlock bot" },
    { "Druid", function() Say(".recruit druid") end, "Add a Druid bot" },
  }, 16, -136, FULL, 6, 134)
  Section(gp, "LOOKING FOR GROUP", "Every few minutes a bot near your level posts an LFM in the LFG chat channel. Click Join within 3 minutes and you all go in.", {
    { "Join LFM", function() Say(".recruit join") end, "Answer the latest LFM: the group fills up and teleports into the dungeon", accent = true },
    { "Dungeon for my level", function() Say(".recruit go") end, "Take your group into a dungeon that fits your level" },
  }, 16, -234, FULL, 6, 134)
  Section(gp, "TAKE MY GROUP INTO A DUNGEON", "Teleports you and every bot in your group inside. Recruit first, then click.", {
    { "Ragefire Chasm", function() Say(".recruit go ragefire") end, "Levels 13-18" },
    { "Wailing Caverns", function() Say(".recruit go wailing") end, "Levels 17-24" },
    { "Deadmines", function() Say(".recruit go deadmines") end, "Levels 17-26" },
    { "Shadowfang Keep", function() Say(".recruit go shadowfang") end, "Levels 22-30" },
    { "Blackfathom Deeps", function() Say(".recruit go blackfathom") end, "Levels 24-32" },
    { "Stockade", function() Say(".recruit go stockade") end, "Levels 24-32" },
    { "Gnomeregan", function() Say(".recruit go gnomeregan") end, "Levels 29-38" },
    { "Razorfen Kraul", function() Say(".recruit go kraul") end, "Levels 29-38" },
    { "Scarlet Monastery", function() Say(".recruit go scarlet") end, "Levels 34-45" },
    { "Razorfen Downs", function() Say(".recruit go downs") end, "Levels 37-46" },
    { "Uldaman", function() Say(".recruit go uldaman") end, "Levels 41-51" },
    { "Zul'Farrak", function() Say(".recruit go zulfarrak") end, "Levels 44-54" },
    { "Maraudon", function() Say(".recruit go maraudon") end, "Levels 46-55" },
    { "Sunken Temple", function() Say(".recruit go sunken") end, "Levels 50-56" },
    { "Blackrock Depths", function() Say(".recruit go depths") end, "Levels 52-60" },
    { "Lower BRS", function() Say(".recruit go spire") end, "Levels 55-60" },
    { "Dire Maul", function() Say(".recruit go dire") end, "Levels 55-60" },
    { "Scholomance", function() Say(".recruit go scholomance") end, "Levels 58-60" },
    { "Stratholme", function() Say(".recruit go stratholme") end, "Levels 58-60" },
    { "Ramparts", function() Say(".recruit go ramparts") end, "Levels 59-63" },
    { "Blood Furnace", function() Say(".recruit go furnace") end, "Levels 61-64" },
    { "Slave Pens", function() Say(".recruit go slave") end, "Levels 62-65" },
    { "Underbog", function() Say(".recruit go underbog") end, "Levels 63-66" },
    { "Mana-Tombs", function() Say(".recruit go mana") end, "Levels 64-67" },
    { "Auchenai Crypts", function() Say(".recruit go crypts") end, "Levels 65-68" },
    { "Old Hillsbrad", function() Say(".recruit go hillsbrad") end, "Levels 66-69" },
    { "Sethekk Halls", function() Say(".recruit go sethekk") end, "Levels 67-70" },
    { "Steamvault", function() Say(".recruit go steamvault") end, "Levels 68-70" },
    { "Shattered Halls", function() Say(".recruit go shattered") end, "Levels 69-70" },
    { "Shadow Lab", function() Say(".recruit go labyrinth") end, "Levels 69-70" },
    { "Botanica", function() Say(".recruit go botanica") end, "Levels 70" },
    { "Mechanar", function() Say(".recruit go mechanar") end, "Levels 70" },
    { "Arcatraz", function() Say(".recruit go arcatraz") end, "Levels 70" },
    { "Black Morass", function() Say(".recruit go morass") end, "Levels 70" },
    { "Magisters' Terrace", function() Say(".recruit go magisters") end, "Levels 70" },
  }, 16, -320, FULL, 6, 134)

  -- World
  local wp = pages.world
  local tele = FlatEditBox(wp, 300, "Place name, e.g. Shattrath, Stormwind, Orgrimmar")
  local tb = Section(wp, "TELEPORT", "Type a place and press Enter. If it's not found, try a shorter name - .lookup tele <name> lists matches.", {}, 16, -50, FULL)
  tb:SetHeight(84)
  tele:SetParent(tb)
  tele:ClearAllPoints()
  tele:SetPoint("TOPLEFT", tb, "TOPLEFT", 10, -48)
  tele:SetScript("OnEnterPressed", function()
    local t = string.gsub(tele:GetText() or "", "^%s+", "")
    if t ~= "" then Say(".tele "..t) end
    tele:ClearFocus()
  end)
  local go = FlatButton(tb, "Go", 60, 24, true)
  go:SetPoint("LEFT", tele, "RIGHT", 6, 0)
  go:SetScript("OnClick", function() local t = tele:GetText() or "" if t ~= "" then Say(".tele "..t) end end)
  local look = FlatButton(tb, "Find places", 100, 24)
  look:SetPoint("LEFT", go, "RIGHT", 6, 0)
  look:SetScript("OnClick", function() local t = tele:GetText() or "" if t ~= "" then Say(".lookup tele "..t) end end)
  Section(wp, "SPAWN AN NPC WHERE YOU STAND", "They stay there permanently.", {
    { "Master of Trades", function() Say(".npc add 190200") end, "Trainer for every profession" },
    { "Spellbook vendor", function() Say(".npc add 190100") end, "Lorekeeper Vaelith - tomes and runes" },
    { "Remove target NPC", function() Say(".npc delete") end, "Deletes the NPC you're targeting (careful!)" },
  }, 16, -142, FULL, 6, 134)
  Section(wp, "SERVER", nil, {
    { "Save", function() Say(".save") end, "Save your character now" },
    { "Reset instances", function() Say(".instance unbind all") end, "Unlock every dungeon/raid you're saved to" },
    { "Reload UI", function() ReloadUI() end, "Same as /rl" },
  }, 16, -232, FULL, 6, 134)
  Section(wp, "PROFESSION TRAINERS  (cloud build)", "Click one and the trainer appears next to you for 3 minutes. Pick the profession in its list to learn it, then train ranks and recipes.", {
    { "All professions", function() Say(".trainer all") end, "Master of Trades (every profession) trainer appears next to you for 3 minutes", accent = true },
    { "Alchemy", function() Say(".trainer alchemy") end, "Alchemy trainer appears next to you for 3 minutes" },
    { "Blacksmithing", function() Say(".trainer blacksmithing") end, "Blacksmithing trainer appears next to you for 3 minutes" },
    { "Enchanting", function() Say(".trainer enchanting") end, "Enchanting trainer appears next to you for 3 minutes" },
    { "Engineering", function() Say(".trainer engineering") end, "Engineering trainer appears next to you for 3 minutes" },
    { "Herbalism", function() Say(".trainer herbalism") end, "Herbalism trainer appears next to you for 3 minutes" },
    { "Jewelcrafting", function() Say(".trainer jewelcrafting") end, "Jewelcrafting trainer appears next to you for 3 minutes" },
    { "Leatherworking", function() Say(".trainer leatherworking") end, "Leatherworking trainer appears next to you for 3 minutes" },
    { "Mining", function() Say(".trainer mining") end, "Mining trainer appears next to you for 3 minutes" },
    { "Skinning", function() Say(".trainer skinning") end, "Skinning trainer appears next to you for 3 minutes" },
    { "Tailoring", function() Say(".trainer tailoring") end, "Tailoring trainer appears next to you for 3 minutes" },
    { "Cooking", function() Say(".trainer cooking") end, "Cooking trainer appears next to you for 3 minutes" },
    { "First Aid", function() Say(".trainer firstaid") end, "First Aid trainer appears next to you for 3 minutes" },
    { "Fishing", function() Say(".trainer fishing") end, "Fishing trainer appears next to you for 3 minutes" },
  }, 16, -302, FULL, 6, 134)

  GearFinderDB = GearFinderDB or {}
  ShowTab(GearFinderDB.tab or "gear")
end

local function Build()
  f = CreateFrame("Frame", "GearFinderFrame", UIParent)
  f:SetWidth(W) f:SetHeight(H)
  f:SetPoint("CENTER")
  Paint(f, C.bg)
  f:SetMovable(true) f:EnableMouse(true)
  f:SetClampedToScreen(true)
  f:SetFrameStrata("HIGH")
  f:Hide()
  f:SetScript("OnHide", function() CloseMenus() end)
  table.insert(UISpecialFrames, "GearFinderFrame")

  -- Title bar
  local bar = CreateFrame("Frame", nil, f)
  bar:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
  bar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
  bar:SetHeight(38)
  local barBg = bar:CreateTexture(nil, "BACKGROUND")
  barBg:SetAllPoints(bar)
  barBg:SetTexture(C.header[1], C.header[2], C.header[3], 1)
  local accentLine = bar:CreateTexture(nil, "ARTWORK")
  accentLine:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
  accentLine:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
  accentLine:SetHeight(2)
  accentLine:SetTexture(C.accent[1], C.accent[2], C.accent[3], 0.85)
  bar:EnableMouse(true)
  bar:RegisterForDrag("LeftButton")
  bar:SetScript("OnDragStart", function() f:StartMoving() end)
  bar:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
  local title = Text(bar, "GameFontNormalLarge")
  title:SetPoint("LEFT", bar, "LEFT", 16, 0)
  title:SetText("Toolkit")
  title:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
  local subtitle = Text(bar, "GameFontDisableSmall")
  subtitle:SetPoint("LEFT", title, "RIGHT", 12, -1)
  subtitle:SetText("Gear  |  Character  |  Buffs  |  Bots  |  Group  |  World")
  local close = FlatButton(bar, "X", 26, 22)
  close:SetPoint("RIGHT", bar, "RIGHT", -8, 0)
  close:SetScript("OnClick", function() f:Hide() end)

  -- Tabs
  BuildTabs(f)
  local gp = pages.gear
  -- Search row
  searchBox = FlatEditBox(gp, 330, "Search items or stats  (e.g. shadowfang, agi, dps)")
  searchBox:SetPoint("TOPLEFT", gp, "TOPLEFT", 16, -52)
  searchBox:SetScript("OnTextChanged", function() searchBox.UpdatePlaceholder() RefreshSoon() end)
  searchBox:SetScript("OnEnterPressed", function() searchBox:ClearFocus() Refresh() end)

  local lvlLabel = Text(gp, "GameFontDisableSmall")
  lvlLabel:SetPoint("LEFT", searchBox, "RIGHT", 18, 0)
  lvlLabel:SetText("Req. level")
  minBox = FlatEditBox(gp, 38, "", true)
  minBox:SetPoint("LEFT", lvlLabel, "RIGHT", 8, 0)
  local dash = Text(gp, "GameFontDisableSmall")
  dash:SetPoint("LEFT", minBox, "RIGHT", 6, 0)
  dash:SetText("to")
  maxBox = FlatEditBox(gp, 38, "", true)
  maxBox:SetPoint("LEFT", dash, "RIGHT", 6, 0)
  for _, e in ipairs({ minBox, maxBox }) do
    e:SetScript("OnTextChanged", RefreshSoon)
    e:SetScript("OnEnterPressed", function() e:ClearFocus() Refresh() end)
  end

  usableBtn = FlatButton(gp, "", 210, 24)
  usableBtn:SetPoint("LEFT", maxBox, "RIGHT", 18, 0)
  local function usableLabel()
    if state.usable then
      usableBtn.label:SetText("|cffffd100[x]|r  Only gear I can use")
    else
      usableBtn.label:SetText("|cff808080[  ]|r  Only gear I can use")
    end
  end
  usableLabel()
  usableBtn:SetScript("OnClick", function() state.usable = not state.usable usableLabel() Refresh() end)

  -- Filter row
  local fl = Text(gp, "GameFontDisableSmall")
  fl:SetPoint("TOPLEFT", gp, "TOPLEFT", 18, -92)
  fl:SetText("FILTERS")
  local d1 = MakeDropdown(gp, SLOT_FILTERS, "slot", 160)
  d1:SetPoint("TOPLEFT", gp, "TOPLEFT", 76, -86)
  local d2 = MakeDropdown(gp, TYPE_FILTERS, "type", 160)
  d2:SetPoint("LEFT", d1, "RIGHT", 8, 0)
  local d3 = MakeDropdown(gp, QUALITY_FILTERS, "quality", 130)
  d3:SetPoint("LEFT", d2, "RIGHT", 8, 0)
  local reset = FlatButton(gp, "Clear filters", 100, 24)
  reset:SetPoint("LEFT", d3, "RIGHT", 8, 0)
  local d4 = MakeDropdown(gp, STAT_SORT, "stat", 190)
  d4:SetPoint("LEFT", reset, "RIGHT", 8, 0)
  reset:SetScript("OnClick", function()
    state.slot, state.type, state.quality, state.stat = 1, 1, 1, 1
    searchBox:SetText("")
    minBox:SetText("") maxBox:SetText("")
    CloseMenus()
    for _, d in ipairs(dropdowns) do d.relabel() end
    Refresh()
  end)

  -- Table
  local tbl = CreateFrame("Frame", nil, gp)
  tbl:SetPoint("TOPLEFT", gp, "TOPLEFT", 16, -122)
  tbl:SetWidth(W - 32)
  tbl:SetHeight(28 + ROWS * ROW_H + 2)
  Paint(tbl, C.panel)

  local head = CreateFrame("Frame", nil, tbl)
  head:SetPoint("TOPLEFT", tbl, "TOPLEFT", 1, -1)
  head:SetPoint("TOPRIGHT", tbl, "TOPRIGHT", -1, -1)
  head:SetHeight(28)
  local headBg = head:CreateTexture(nil, "BACKGROUND")
  headBg:SetAllPoints(head)
  headBg:SetTexture(C.header[1], C.header[2], C.header[3], 1)

  -- Column layout: x offset, width
  local COLS = { name={44, 270}, req={320, 44}, ilvl={368, 44}, slot={416, 90}, kind={510, 86}, stats={600, 136} }
  local HEADERS = { { "Name", "name", "name" }, { "Req", "req", "req" }, { "iLvl", "ilvl", "ilvl" },
    { "Slot", "slot" }, { "Type", "kind" }, { "Stats", "stats" } }
  for _, hd in ipairs(HEADERS) do
    local col = COLS[hd[2]]
    local hb = CreateFrame("Button", nil, head)
    hb:SetPoint("LEFT", head, "LEFT", col[1], 0)
    hb:SetWidth(col[2]) hb:SetHeight(28)
    hb.label = Text(hb, "GameFontNormalSmall")
    hb.label:SetPoint("LEFT", hb, "LEFT", 0, 0)
    hb.title = hd[1]
    hb.label:SetText(hd[1])
    hb.label:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
    if hd[3] then
      hb.key = hd[3]
      table.insert(headers, hb)
      hb:SetScript("OnClick", function()
        if state.sortKey == hb.key then state.desc = not state.desc
        else state.sortKey = hb.key state.desc = (hb.key ~= "name") end
        state.stat = 1
        for _, d in ipairs(dropdowns) do if d.key == "stat" then d.relabel() end end
        Refresh()
      end)
    end
  end

  rows = {}
  for i = 1, ROWS do
    local row = CreateFrame("Button", nil, tbl)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -(i - 1) * ROW_H)
    row:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT", -12, -(i - 1) * ROW_H)
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(row)
    local stripe = (i % 2 == 0) and C.rowB or C.rowA
    bg:SetTexture(stripe[1], stripe[2], stripe[3], 1)
    row.bg = bg

    row.iconBorder = row:CreateTexture(nil, "BORDER")
    row.iconBorder:SetWidth(22) row.iconBorder:SetHeight(22)
    row.iconBorder:SetPoint("LEFT", row, "LEFT", 12, 0)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetWidth(20) row.icon:SetHeight(20)
    row.icon:SetPoint("CENTER", row.iconBorder, "CENTER", 0, 0)
    row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    local function cell(key, font)
      local s = Text(row, font or "GameFontHighlightSmall")
      s:SetPoint("LEFT", row, "LEFT", COLS[key][1], 0)
      s:SetWidth(COLS[key][2] - 4)
      s:SetJustifyH("LEFT")
      return s
    end
    row.name = cell("name", "GameFontNormal")
    row.name:ClearAllPoints()
    row.name:SetPoint("TOPLEFT", row, "TOPLEFT", COLS.name[1], -3)
    row.name:SetHeight(13)
    row.sub = Text(row, "GameFontDisableSmall")
    row.sub:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, 0)
    row.sub:SetText("")
    row.req = cell("req") row.ilvl = cell("ilvl")
    row.slot = cell("slot") row.kind = cell("kind")
    row.stats = cell("stats")
    row.stats:SetTextColor(0.55, 0.85, 0.55)

    row.addBtn = FlatButton(row, "Add", 44, 18, true)
    row.addBtn:SetPoint("RIGHT", row, "RIGHT", -52, 0)
    row.addBtn.tip = { "Add item", "Adds one copy (rolls its random bonus).", "Goes to your target if a player or bot is selected." }
    row.addBtn:SetScript("OnClick", function() if row.item then Say(".additem "..row.item.id) end end)
    row.setBtn = FlatButton(row, "Set", 40, 18)
    row.setBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    row.setBtn.tip = { "Add full set", "Adds every piece of this item's set." }
    row.setBtn:SetScript("OnClick", function()
      if row.item and row.item.set > 0 then Say(".additemset "..row.item.set) end
    end)

    row:SetScript("OnEnter", function()
      if not row.item then return end
      row.bg:SetTexture(C.hover[1], C.hover[2], C.hover[3], 1)
      GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
      GameTooltip:SetHyperlink("item:"..row.item.id..":0:0:0:0:0:0:0")
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine("Item ID "..row.item.id..(row.item.set > 0 and ("   |   Set ID "..row.item.set) or ""), 0.55, 0.55, 0.55)
      GameTooltip:AddLine("Shift-click to link   |   Ctrl-click to preview", 0.55, 0.55, 0.55)
      GameTooltip:Show()
      UpdateRows()
    end)
    row:SetScript("OnLeave", function()
      row.bg:SetTexture(stripe[1], stripe[2], stripe[3], 1)
      GameTooltip:Hide()
    end)
    row:SetScript("OnClick", function()
      if not row.item then return end
      local link = ItemLink(row.item)
      if IsShiftKeyDown() and ChatFrameEditBox and ChatFrameEditBox:IsVisible() then
        ChatFrameEditBox:Insert(link)
      elseif IsControlKeyDown() and DressUpItemLink then
        DressUpItemLink(link)
      end
    end)
    rows[i] = row
  end

  -- Slim scrollbar + mouse wheel
  slider = CreateFrame("Slider", nil, tbl)
  slider:SetOrientation("VERTICAL")
  slider:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT", -3, -2)
  slider:SetWidth(6)
  slider:SetHeight(ROWS * ROW_H - 4)
  local track = slider:CreateTexture(nil, "BACKGROUND")
  track:SetAllPoints(slider)
  track:SetTexture(0.16, 0.16, 0.18, 1)
  local thumb = slider:CreateTexture(nil, "OVERLAY")
  thumb:SetTexture(0.45, 0.45, 0.5, 1)
  thumb:SetWidth(6) thumb:SetHeight(36)
  slider:SetThumbTexture(thumb)
  slider:SetValueStep(1)
  slider:SetScript("OnValueChanged", function(self, value)
    if slider.updating then return end
    value = value or arg1
    state.offset = math.floor(value + 0.5)
    UpdateRows()
  end)
  tbl:EnableMouseWheel(true)
  tbl:SetScript("OnMouseWheel", function(self, delta)
    delta = delta or arg1
    local maxOff = math.max(0, #results - ROWS)
    state.offset = math.max(0, math.min(maxOff, state.offset - delta * 3))
    UpdateRows()
  end)

  countText = Text(gp, "GameFontDisableSmall")
  countText:SetPoint("TOPLEFT", tbl, "BOTTOMLEFT", 2, -6)
  local hint = Text(gp, "GameFontDisableSmall")
  hint:SetPoint("TOPRIGHT", tbl, "BOTTOMRIGHT", -2, -6)
  hint:SetText("Click a column header to sort   |   Scroll with the mouse wheel")

  BuildPages()

  f:SetScript("OnUpdate", function(self, elapsed)
    local dt = elapsed or arg1 or 0
    if equipTimer then
      equipTimer = equipTimer - dt
      if equipTimer <= 0 then equipTimer = nil EquipNewBags() end
    end
    if pending then
      pending = pending - dt
      if pending <= 0 then pending = nil Refresh() end
    end
  end)
  f:SetScript("OnShow", function()
    local lvl = UnitLevel("player") or 70
    if (maxBox:GetText() or "") == "" then maxBox:SetText(lvl) end
    if (minBox:GetText() or "") == "" then minBox:SetText(math.max(1, lvl - 10)) end
    searchBox.UpdatePlaceholder()
    Refresh()
  end)
end

local function Toggle()
  if not f then Build() end
  local _, token = UnitClass("player")
  playerClassId = CLASS_ID[token] or 0
  if f:IsShown() then f:Hide() else f:Show() end
end

SLASH_GEARFINDER1 = "/gf"
SLASH_GEARFINDER2 = "/gearfinder"
SlashCmdList["GEARFINDER"] = Toggle

-- /rl reloads the interface (the 2.4.3 client has no built-in /reload)
SLASH_GEARFINDERRL1 = "/rl"
SlashCmdList["GEARFINDERRL"] = function() ReloadUI() end
