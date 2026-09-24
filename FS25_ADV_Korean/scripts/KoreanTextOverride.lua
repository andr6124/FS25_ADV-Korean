-- KoreanTextOverride.lua
-- Replaces base-game Korean texts with improved translations.
-- Stage 1 (script load, before map data): override the global I18N text table.
-- Stage 2 (loadMap): refresh GUI elements that resolved their texts at game start.

KoreanTextOverride = {}
KoreanTextOverride.TAG = "[KoreanTranslationImproved]"
KoreanTextOverride.LANGUAGE_SUFFIX = "_kr"
KoreanTextOverride.EN_SOURCE = "dataS/l10n/l10n_en.xml"
KoreanTextOverride.IMPROVED_FILE = "translations/l10n_kr_improved.xml"
KoreanTextOverride.modDirectory = g_currentModDirectory
KoreanTextOverride.remap = {}

function KoreanTextOverride.log(fmt, ...)
    print(KoreanTextOverride.TAG .. " " .. string.format(fmt, ...))
end

-- Mirrors pipeline/l10n_io.py text_hash.
function KoreanTextOverride.textHash(text)
    local h = 7
    for i = 1, #text do
        h = (h * 131 + string.byte(text, i)) % 2147483647
    end
    return string.format("%08x", h)
end

function KoreanTextOverride.normalize(text)
    return (text:gsub("\r\n", "\n"))
end

function KoreanTextOverride.decode(text)
    return (KoreanTextOverride.normalize(text):gsub("{{NL}}", "\n"))
end

-- Mods receive a per-mod proxy of g_i18n; the object that really holds the base-game
-- texts is the last table in the __index chain that owns a raw `texts` table.
function KoreanTextOverride.getGlobalI18n(i18n)
    local found = nil
    local current = i18n
    for _ = 1, 8 do
        if type(current) ~= "table" then
            break
        end
        if type(rawget(current, "texts")) == "table" then
            found = current
        end
        local mt = getmetatable(current)
        if mt == nil or type(mt.__index) ~= "table" then
            break
        end
        current = mt.__index
    end
    return found
end

local function iterateEntries(xmlFile, rootPath, fn)
    local i = 0
    while true do
        local key = string.format("%s.e(%d)", rootPath, i)
        if not hasXMLProperty(xmlFile, key) then
            return i
        end
        fn(key)
        i = i + 1
    end
end

function KoreanTextOverride.loadImproved(path)
    local xmlFile = loadXMLFile("koreanTextImproved", path)
    if xmlFile == nil or xmlFile == 0 then
        return nil
    end
    local entries = {}
    iterateEntries(xmlFile, "l10nImproved", function(key)
        local k = getXMLString(xmlFile, key .. "#k")
        local v = getXMLString(xmlFile, key .. "#v")
        local h = getXMLString(xmlFile, key .. "#h")
        if k ~= nil and v ~= nil and h ~= nil then
            table.insert(entries, {k = k, v = KoreanTextOverride.decode(v), h = h})
        end
    end)
    delete(xmlFile)
    return entries
end

function KoreanTextOverride.loadEnglishHashes(path, wanted)
    local xmlFile = loadXMLFile("koreanTextEnSource", path)
    if xmlFile == nil or xmlFile == 0 then
        return nil
    end
    local hashes = {}
    iterateEntries(xmlFile, "l10n.elements", function(key)
        local k = getXMLString(xmlFile, key .. "#k")
        if k ~= nil and wanted[k] then
            local v = getXMLString(xmlFile, key .. "#v") or ""
            hashes[k] = KoreanTextOverride.textHash(KoreanTextOverride.normalize(v))
        end
    end)
    delete(xmlFile)
    return hashes
end

-- An old text is "specific" enough to safely remap on GUI elements: after stripping
-- printf-style tokens (%s, %d, %.1f, %1$s, %%) it must contain a letter (incl. Hangul)
-- and be at least 2 bytes long. Generic values like "1".."12", "%s", ".", "," or "$" are
-- unique-but-meaningless base-game texts (month numbers, separators, placeholders) shared
-- by unrelated GUI elements, so remapping them would relabel elements that were never
-- meant to change.
function KoreanTextOverride.isSpecificText(text)
    if type(text) ~= "string" then
        return false
    end
    local stripped = text:gsub("%%[-+ #0]*[%d%.%$]*[%a%%]", "")
    if not stripped:find("[%a\128-\255]") then
        return false
    end
    return #stripped >= 2
end

-- Overrides texts in place. The returned remap (old text -> new text) only holds old texts
-- whose every user ends up with the same new text and that are "specific" (see
-- isSpecificText), so a GUI refresh can never mislabel an unrelated element.
function KoreanTextOverride.applyEntries(texts, entries, enHashes)
    local stats = {applied = 0, missing = 0, stale = 0, ambiguous = 0}
    local usage = {}
    for _, value in pairs(texts) do
        if type(value) == "string" then
            usage[value] = (usage[value] or 0) + 1
        end
    end
    local candidates = {}
    local newTexts = {}
    for _, entry in ipairs(entries) do
        local current = texts[entry.k]
        if current == nil then
            stats.missing = stats.missing + 1
        elseif enHashes[entry.k] ~= entry.h then
            stats.stale = stats.stale + 1
        else
            if current ~= entry.v then
                local candidate = candidates[current]
                if candidate == nil then
                    candidates[current] = {new = entry.v, count = 1, conflict = false}
                else
                    candidate.count = candidate.count + 1
                    candidate.conflict = candidate.conflict or candidate.new ~= entry.v
                end
            end
            newTexts[entry.v] = true
            texts[entry.k] = entry.v
            stats.applied = stats.applied + 1
        end
    end
    local remap = {}
    for old, candidate in pairs(candidates) do
        if candidate.conflict or candidate.count ~= usage[old] or not KoreanTextOverride.isSpecificText(old)
            or newTexts[old] then
            stats.ambiguous = stats.ambiguous + 1
        else
            remap[old] = candidate.new
        end
    end
    -- Every l10n value seen before or after the override, for buildRefreshMap.
    local known = {}
    for value in pairs(usage) do
        known[value] = true
    end
    for value in pairs(newTexts) do
        known[value] = true
    end
    return stats, remap, known
end

-- Extends the remap with `old .. ":"` -> `new .. ":"` ($l10n_key: in GUI XML resolves to the
-- text plus a colon), unless `old .. ":"` is itself an l10n value (it would then be ambiguous).
function KoreanTextOverride.buildRefreshMap(remap, known)
    local map = {}
    for old, new in pairs(remap) do
        map[old] = new
    end
    for old, new in pairs(remap) do
        local colonOld = old .. ":"
        if not known[colonOld] and map[colonOld] == nil then
            map[colonOld] = new .. ":"
        end
    end
    return map
end

function KoreanTextOverride.apply()
    if g_languageSuffix ~= KoreanTextOverride.LANGUAGE_SUFFIX then
        KoreanTextOverride.log("game language suffix is %s, not %s; nothing to do",
            tostring(g_languageSuffix), KoreanTextOverride.LANGUAGE_SUFFIX)
        return
    end
    KoreanTextOverride.applyTexts()
    KoreanTextOverride.installProductionHook()
    KoreanTextOverride.installKeyNameHook()
end

function KoreanTextOverride.applyTexts()
    local i18n = KoreanTextOverride.getGlobalI18n(g_i18n)
    if i18n == nil then
        KoreanTextOverride.log("ERROR: global I18N not found; original texts kept")
        return
    end
    local entries = KoreanTextOverride.loadImproved(KoreanTextOverride.modDirectory .. KoreanTextOverride.IMPROVED_FILE)
    if entries == nil then
        KoreanTextOverride.log("ERROR: cannot read %s; original texts kept", KoreanTextOverride.IMPROVED_FILE)
        return
    end
    local wanted = {}
    for _, entry in ipairs(entries) do
        wanted[entry.k] = true
    end
    local enHashes = KoreanTextOverride.loadEnglishHashes(KoreanTextOverride.EN_SOURCE, wanted)
    if enHashes == nil then
        KoreanTextOverride.log("ERROR: cannot read %s; original texts kept", KoreanTextOverride.EN_SOURCE)
        return
    end
    local stats, remap, known = KoreanTextOverride.applyEntries(i18n.texts, entries, enHashes)
    KoreanTextOverride.remap = KoreanTextOverride.buildRefreshMap(remap, known)
    KoreanTextOverride.log("%d texts applied, %d missing, %d stale (English source changed), %d ambiguous for GUI refresh",
        stats.applied, stats.missing, stats.stale, stats.ambiguous)
    KoreanTextOverride.log("hash self-test: %s", KoreanTextOverride.textHash("농기계 test\n"))
end

-- Tables reached from a scan root are followed at most this many table levels deep (root = 0).
KoreanTextOverride.MAX_SCAN_DEPTH = 6

-- Fields that lead from GUI screens into mission-scale game state (or back up the element
-- tree, or into arbitrary callback/target objects), which are reached from the roots anyway
-- or must never be wandered into; the scan never follows them.
KoreanTextOverride.SKIP_FIELDS = {
    currentMission = true, mission = true, hud = true, inGameMap = true, missionInfo = true,
    missionDynamicInfo = true, environment = true, player = true, playerFarm = true, vehicle = true,
    storeItem = true, client = true, server = true, parent = true,
    targetObject = true, callbackTarget = true, target = true, callback = true, owner = true,
    farm = true, farms = true, savegame = true, savegames = true, savegameController = true,
}

-- Metatable hops followed when looking up methods or classes.
local MAX_CLASS_HOPS = 10

-- The table that lookups on x continue in, without invoking any metamethod. GIANTS Class()
-- sets __metatable = members, so getmetatable(instance) returns the class table itself (whose
-- raw __index is nil, or the class itself); a missing __index therefore means "look in the
-- table getmetatable returned". Returns nil when there is none or when __index is not a table
-- (a function __index is never called).
local function classIndex(x)
    local mt = getmetatable(x)
    if type(mt) ~= "table" then
        return nil
    end
    local index = rawget(mt, "__index")
    if index == nil then
        index = mt
    end
    if type(index) ~= "table" then
        return nil
    end
    return index
end

-- Reads t[k] without ever invoking a metamethod: rawget(t, k) if present, otherwise follows
-- classIndex up to MAX_CLASS_HOPS tables, returning the first rawget(index, k) found. A found
-- method may still be called by the caller (e.g. setText).
local function safeGet(t, k)
    local v = rawget(t, k)
    if v ~= nil then
        return v
    end
    local current = t
    for _ = 1, MAX_CLASS_HOPS do
        local index = classIndex(current)
        if index == nil then
            return nil
        end
        v = rawget(index, k)
        if v ~= nil then
            return v
        end
        current = index
    end
    return nil
end
KoreanTextOverride.safeGet = safeGet

-- True if class (compared by identity) is in t's class chain, as followed by classIndex.
local function inClassChain(t, class)
    local current = t
    for _ = 1, MAX_CLASS_HOPS do
        local index = classIndex(current)
        if index == nil then
            return false
        end
        if index == class then
            return true
        end
        current = index
    end
    return false
end

-- Only real GUI text elements get setText called. With the game's TextElement class present,
-- t must be an instance of it (or of a subclass such as ButtonElement); without it (tests),
-- t must have a setText function and a raw string sourceText, as every TextElement has.
local function isTextElement(t, textElementClass)
    if type(safeGet(t, "setText")) ~= "function" then
        return false
    end
    if textElementClass ~= nil then
        return inClassChain(t, textElementClass)
    end
    return type(rawget(t, "sourceText")) == "string"
end

local function hasNonAscii(text)
    return text:find("[\128-\255]") ~= nil
end

function KoreanTextOverride.collectGuiRoots(gui)
    local roots = {}
    for _, field in ipairs({"guis", "screenControllers", "frames", "dialogs"}) do
        local group = gui[field]
        if type(group) == "table" then
            for _, root in pairs(group) do
                table.insert(roots, root)
                if field == "frames" and type(root) == "table" and type(root.target) == "table" then
                    table.insert(roots, root.target)
                end
            end
        end
    end
    return roots
end

-- Resolved strings cached by engine-side singletons rather than GUI screens.
function KoreanTextOverride.collectCacheRoots()
    local roots = {}
    if type(g_settingsModel) == "table" then
        table.insert(roots, g_settingsModel)
    end
    if type(g_inputBinding) == "table" then
        if type(g_inputBinding.actions) == "table" then
            table.insert(roots, g_inputBinding.actions)
        end
        if type(g_inputBinding.events) == "table" then
            table.insert(roots, g_inputBinding.events)
        end
    end
    return roots
end

-- Global singletons the scan must never enter (g_inputBinding is scanned only through the
-- roots from collectCacheRoots).
function KoreanTextOverride.collectSkipTables()
    local skip = {}
    local function add(t)
        if type(t) == "table" then
            skip[t] = true
        end
    end
    add(g_currentMission)
    add(g_i18n)
    add(g_gui)
    add(g_messageCenter)
    add(g_client)
    add(g_server)
    add(g_storeManager)
    add(g_farmManager)
    add(g_inputBinding)
    add(_G)
    local globalsMeta = getmetatable(_G)
    if type(globalsMeta) == "table" then
        add(globalsMeta.__index)
    end
    local i18n = KoreanTextOverride.getGlobalI18n(g_i18n)
    if i18n ~= nil then
        add(i18n)
        add(rawget(i18n, "texts"))
    end
    if type(g_i18n) == "table" then
        add(rawget(g_i18n, "texts"))
    end
    return skip
end

-- Refreshes translated strings resolved before the override. Every element of the linked GUI
-- trees under `roots` (followed through `elements`, as the engine links them) and every table in
-- `cacheRoots` is a scan root; from each root, tables are followed through their values up to
-- MAX_SCAN_DEPTH levels, which reaches unlinked templates, button infos, page titles and option
-- texts. Strings are only ever replaced by exact match against `remap`, and only as values of
-- raw fields (read with rawget/pairs, written with rawset). setText is only called on real
-- TextElements (see isTextElement). Pure-ASCII old texts are only used for linked elements'
-- setText/toolTipText refreshes, never in the value scan, where they could match unrelated
-- identifiers. Returns the number of TextElement/tooltip refreshes, the number of other cached
-- strings, and the number of table walks (a table re-walked from a smaller depth counts again).
function KoreanTextOverride.refreshElements(roots, remap, cacheRoots)
    local skip = KoreanTextOverride.collectSkipTables()
    local skipFields = KoreanTextOverride.SKIP_FIELDS
    local maxDepth = KoreanTextOverride.MAX_SCAN_DEPTH
    local textElementClass = TextElement
    if type(textElementClass) ~= "table" then
        textElementClass = nil
    end
    local deepRemap = {}
    for old, new in pairs(remap) do
        if hasNonAscii(old) then
            deepRemap[old] = new
        end
    end
    local linked = {}
    local changed = 0
    local cached = 0
    local scanned = 0

    local function refreshTable(t)
        local elementRemap = linked[t] and remap or deepRemap
        local textLike = isTextElement(t, textElementClass)
        if textLike and safeGet(t, "locaKey") == nil then
            local current = rawget(t, "sourceText")
            if type(current) ~= "string" then
                current = rawget(t, "text")
            end
            local replacement = type(current) == "string" and elementRemap[current] or nil
            if type(replacement) == "string" then
                safeGet(t, "setText")(t, replacement)
                changed = changed + 1
            end
        end
        local toolTipText = rawget(t, "toolTipText")
        if type(toolTipText) == "string" and type(elementRemap[toolTipText]) == "string" then
            rawset(t, "toolTipText", elementRemap[toolTipText])
            changed = changed + 1
        end
        -- Collect first, assign after: never modify a table while pairs() walks it.
        local hits = {}
        for k, v in pairs(t) do
            if type(v) == "string" and type(deepRemap[v]) == "string" and k ~= "locaKey" and k ~= "toolTipText"
                and not (textLike and (k == "text" or k == "sourceText")) then
                table.insert(hits, {key = k, value = deepRemap[v]})
            end
        end
        for _, hit in ipairs(hits) do
            rawset(t, hit.key, hit.value)
            cached = cached + 1
        end
    end

    -- A table is refreshed once, on first reach; it is walked again only when reached at a
    -- smaller depth, so coverage does not depend on pairs() order. Linked elements are scan
    -- roots (depth 0) of their own and are never descended into from another table.
    local depthOf = {}
    local function visit(t, depth)
        if skip[t] then
            return
        end
        local seenDepth = depthOf[t]
        if seenDepth ~= nil and seenDepth <= depth then
            return
        end
        depthOf[t] = depth
        scanned = scanned + 1
        if seenDepth == nil then
            refreshTable(t)
        end
        if depth >= maxDepth then
            return
        end
        local children = {}
        for k, v in pairs(t) do
            if type(v) == "table" and not skipFields[k] and not linked[v] then
                table.insert(children, v)
            end
        end
        for _, child in ipairs(children) do
            visit(child, depth + 1)
        end
    end

    local scanRoots = {}
    local function collectLinked(element)
        if type(element) ~= "table" or linked[element] or skip[element] then
            return
        end
        linked[element] = true
        table.insert(scanRoots, element)
        local elements = safeGet(element, "elements")
        if type(elements) == "table" then
            for _, child in ipairs(elements) do
                collectLinked(child)
            end
        end
    end
    for _, root in ipairs(roots) do
        collectLinked(root)
    end
    for _, root in ipairs(cacheRoots or {}) do
        if type(root) == "table" then
            table.insert(scanRoots, root)
        end
    end
    for _, root in ipairs(scanRoots) do
        visit(root, 0)
    end
    return changed, cached, scanned
end

-- Production recipe names. The game builds a production's name as
-- string.format(#name, convertText(param)...) with #params from the placeable XML; recipes
-- declared as name="%s %s" (grain mill, sugar mill, spinnery) come out in English word order
-- ("귀리 밀가루"). ProductionPoint:load is hooked so every production point loaded afterwards
-- (placed on the map or bought later) gets Korean names: flour recipes by id, every other
-- "%s %s" recipe as the game's own "%s (%s)" pattern, "<output> (<input>)".
KoreanTextOverride.FLOUR_RECIPE_NAMES = {
    flourWheat = "밀가루", flourBarley = "보리가루", flourOat = "귀리가루", flourSorghum = "수숫가루",
}
-- Which of the two params is the output, for when the XML outputs cannot be matched.
KoreanTextOverride.RECIPE_OUTPUT_PARAM = {
    sugarbeet_sugar = 2, sugarbeetCut_sugar = 2, sugarcane_sugar = 2, fabric_wool = 1, fabric_cotton = 1,
}
KoreanTextOverride.recipeNamesFixed = 0

local function convertText(text, customEnvironment)
    local convert = type(g_i18n) == "table" and safeGet(g_i18n, "convertText") or nil
    if type(convert) ~= "function" then
        return nil
    end
    local converted = convert(g_i18n, text, customEnvironment)
    if type(converted) ~= "string" then
        return nil
    end
    return converted
end

local function fillTypeTitle(fillTypeName)
    if type(fillTypeName) ~= "string" or type(g_fillTypeManager) ~= "table" then
        return nil
    end
    local getByName = safeGet(g_fillTypeManager, "getFillTypeByName")
    if type(getByName) ~= "function" then
        return nil
    end
    local fillType = getByName(g_fillTypeManager, fillTypeName)
    if type(fillType) ~= "table" then
        return nil
    end
    local title = rawget(fillType, "title")
    if type(title) ~= "string" then
        return nil
    end
    return title
end

-- Reads the "%s %s" recipes of a production point's XML: production id -> {a, b, outputs}, where
-- a and b are the resolved params and outputs holds the titles of the recipe's output fill types.
function KoreanTextOverride.readTwoWordRecipes(xmlFile, key, customEnvironment)
    local recipes = {}
    if type(xmlFile) ~= "table" or type(key) ~= "string" then
        return recipes
    end
    local getString = safeGet(xmlFile, "getString")
    local iterate = safeGet(xmlFile, "iterate")
    if type(getString) ~= "function" or type(iterate) ~= "function" then
        return recipes
    end
    iterate(xmlFile, key .. ".productions.production", function(_, productionKey)
        local id = getString(xmlFile, productionKey .. "#id")
        local params = getString(xmlFile, productionKey .. "#params")
        if type(id) ~= "string" or getString(xmlFile, productionKey .. "#name") ~= "%s %s" or type(params) ~= "string" then
            return
        end
        local rawA, rawB = params:match("^([^|]+)|([^|]+)$")
        if rawA == nil then
            return
        end
        local a = convertText(rawA, customEnvironment)
        local b = convertText(rawB, customEnvironment)
        if a == nil or b == nil then
            return
        end
        local outputs = {}
        iterate(xmlFile, productionKey .. ".outputs.output", function(_, outputKey)
            local title = fillTypeTitle(getString(xmlFile, outputKey .. "#fillType"))
            if title ~= nil then
                outputs[title] = true
            end
        end)
        recipes[id] = {a = a, b = b, outputs = outputs}
    end)
    return recipes
end

-- The Korean name for a "%s %s" recipe, or nil when its output cannot be told.
function KoreanTextOverride.koreanRecipeName(id, recipe)
    local flour = KoreanTextOverride.FLOUR_RECIPE_NAMES[id]
    if flour ~= nil then
        return flour
    end
    local outputParam = nil
    if recipe.outputs[recipe.a] and not recipe.outputs[recipe.b] then
        outputParam = 1
    elseif recipe.outputs[recipe.b] and not recipe.outputs[recipe.a] then
        outputParam = 2
    else
        outputParam = KoreanTextOverride.RECIPE_OUTPUT_PARAM[id]
    end
    if outputParam == 1 then
        return string.format("%s (%s)", recipe.a, recipe.b)
    elseif outputParam == 2 then
        return string.format("%s (%s)", recipe.b, recipe.a)
    end
    return nil
end

-- Renames productions whose name still equals the "%s %s" composition of their params.
-- Returns the number of renamed productions.
function KoreanTextOverride.fixRecipeNames(productions, recipes)
    local renamed = 0
    for _, production in ipairs(productions) do
        if type(production) == "table" then
            local id = rawget(production, "id")
            local name = rawget(production, "name")
            local recipe = type(id) == "string" and recipes[id] or nil
            if recipe ~= nil and type(name) == "string" and name == string.format("%s %s", recipe.a, recipe.b) then
                local newName = KoreanTextOverride.koreanRecipeName(id, recipe)
                if newName ~= nil and newName ~= name then
                    rawset(production, "name", newName)
                    renamed = renamed + 1
                end
            end
        end
    end
    return renamed
end

-- Replacement for ProductionPoint:load (installed with Utils.overwrittenFunction).
function KoreanTextOverride.productionPointLoad(self, superFunc, components, xmlFile, key, customEnvironment, ...)
    local success = superFunc(self, components, xmlFile, key, customEnvironment, ...)
    if success and type(self) == "table" then
        local productions = rawget(self, "productions")
        if type(productions) == "table" then
            local recipes = KoreanTextOverride.readTwoWordRecipes(xmlFile, key, customEnvironment)
            local renamed = KoreanTextOverride.fixRecipeNames(productions, recipes)
            if renamed > 0 then
                KoreanTextOverride.recipeNamesFixed = KoreanTextOverride.recipeNamesFixed + renamed
                KoreanTextOverride.log("%d production recipe names fixed", renamed)
            end
        end
    end
    return success
end

function KoreanTextOverride.installProductionHook()
    if type(ProductionPoint) ~= "table" or type(rawget(ProductionPoint, "load")) ~= "function"
        or type(Utils) ~= "table" or type(Utils.overwrittenFunction) ~= "function" then
        KoreanTextOverride.log("ProductionPoint:load not found; production recipe names unchanged")
        return false
    end
    ProductionPoint.load = Utils.overwrittenFunction(ProductionPoint.load, KoreanTextOverride.productionPointLoad)
    KoreanTextOverride.log("production recipe names hooked")
    return true
end

-- Key names. Keys without a keyGlyph_* text are named by the engine's built-in table, whose
-- Korean names for Shift and Win are mistranslated ("이동" = move, "획득" = win as in "gain").
-- KeyboardHelper.getDisplayKeyName is wrapped so the input help shows the corrected names.
KoreanTextOverride.KEY_NAME_FIXES = {
    ["왼쪽 이동"] = "왼쪽 Shift", ["오른쪽 이동"] = "오른쪽 Shift",
    ["왼쪽 획득"] = "왼쪽 Win", ["오른쪽 획득"] = "오른쪽 Win",
}

function KoreanTextOverride.fixKeyName(name)
    return KoreanTextOverride.KEY_NAME_FIXES[name] or name
end

function KoreanTextOverride.installKeyNameHook()
    if type(KeyboardHelper) ~= "table" or type(rawget(KeyboardHelper, "getDisplayKeyName")) ~= "function" then
        KoreanTextOverride.log("KeyboardHelper.getDisplayKeyName not found; key names unchanged")
        return false
    end
    local getDisplayKeyName = KeyboardHelper.getDisplayKeyName
    KeyboardHelper.getDisplayKeyName = function(...)
        return KoreanTextOverride.fixKeyName(getDisplayKeyName(...))
    end
    -- Key names cached before this mod loaded are replaced by the loadMap scan.
    for old, new in pairs(KoreanTextOverride.KEY_NAME_FIXES) do
        KoreanTextOverride.remap[old] = new
    end
    KoreanTextOverride.log("key names hooked")
    return true
end

function KoreanTextOverride:loadMap(name)
    if next(KoreanTextOverride.remap) == nil then
        return
    end
    local guiRoots = {}
    if g_gui ~= nil then
        guiRoots = KoreanTextOverride.collectGuiRoots(g_gui)
    end
    local changed, cached, scanned = KoreanTextOverride.refreshElements(
        guiRoots, KoreanTextOverride.remap, KoreanTextOverride.collectCacheRoots())
    KoreanTextOverride.log("%d GUI texts refreshed", changed)
    KoreanTextOverride.log("%d cached texts refreshed", cached)
    KoreanTextOverride.log("%d tables scanned", scanned)
    KoreanTextOverride.remap = {}
end

KoreanTextOverride.apply()
addModEventListener(KoreanTextOverride)
