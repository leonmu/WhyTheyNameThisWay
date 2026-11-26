-- WhyTheyNameThisWay: translation layer for non-English game languages (e.g. Chinese).
-- The dictionary only knows English names, so on a non-English client we first turn
-- the game ID (NPC, item, zone) into its English name, then explain that as usual.
-- On an English client every function here returns nil and nothing changes.
local ADDON, ns = ...
local T = {}
ns.T = T

local locale = (GetLocale and GetLocale()) or "enUS"
T.locale = locale
T.active = not locale:find("^en")

local EN_NPC = ns.EN_NPC or {}
local EN_ITEM = ns.EN_ITEM or {}
local EN_AREA = ns.EN_AREA or {}

local function Usable(v)
    if issecretvalue and issecretvalue(v) then return false end
    return type(v) == "string" and v ~= ""
end

-- NPC: GUID "Creature-0-<server>-<instance>-<zone>-<npcID>-<spawn>" -> English name.
-- Returns englishName, how ("npc 1234" or "chinese name"), or nil.
function T.Unit(unit, shown)
    if not T.active then return end
    if unit then
        local ok, guid = pcall(UnitGUID, unit)
        if ok and Usable(guid) then
            local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)")
            if (kind == "Creature" or kind == "Vehicle") and id then
                local en = EN_NPC[tonumber(id)]
                if en then return en, "npc " .. id end
            end
        end
    end
    -- The game may hide the GUID (combat, instances): try the shown name instead.
    if ns.ZH_NPC and Usable(shown) then
        local id = ns.ZH_NPC[shown]
        if id and EN_NPC[id] then return EN_NPC[id], "chinese name" end
    end
end

-- Item: item ID (or an item link) -> English name.
function T.Item(id, link)
    if not T.active then return end
    id = tonumber(id)
    if not id and Usable(link) then id = tonumber(link:match("item:(%d+)")) end
    if id and EN_ITEM[id] then return EN_ITEM[id], "item " .. id end
end

-- Zones: the game gives zone names as text only, so build (once) a table from the
-- game's own localized area names to our English names: C_Map.GetAreaInfo(areaID).
local zoneMap
local function BuildZoneMap()
    zoneMap = {}
    if not (C_Map and C_Map.GetAreaInfo) then return end
    for areaID, en in pairs(EN_AREA) do
        local ok, name = pcall(C_Map.GetAreaInfo, areaID)
        if ok and Usable(name) and zoneMap[name] == nil then zoneMap[name] = en end
    end
end

function T.Zone(shown)
    if not T.active or not Usable(shown) then return end
    if not zoneMap then BuildZoneMap() end
    local en = zoneMap[shown]
    if en then return en, "zone" end
end

-- Wrap a shown name as { english, shown } when a translation exists, for Core's Gather().
function T.Pair(en, shown)
    if en and en ~= shown then return { en, shown } end
    return shown
end
