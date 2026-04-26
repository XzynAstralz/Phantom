local cloneref = cloneref or function(value)
    return value
end

local Players = cloneref(game:GetService("Players"))
local Workspace = cloneref(game:GetService("Workspace"))
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local Lighting = cloneref(game:GetService("Lighting"))
local CollectionService = cloneref(game:GetService("CollectionService"))
local RunService = cloneref(game:GetService("RunService"))
local CoreGui  = cloneref(game:GetService("CoreGui"))

local lplr = Players.LocalPlayer
local PlayerGui = lplr:FindFirstChildOfClass("PlayerGui") or lplr:WaitForChild("PlayerGui", 10)

local lib, ops = phantom.UI, phantom.ops
local Runtime = ops.runtime
local RunLoops = Runtime.RunLoops
local runcode = Runtime.run
local notification = lib.toast

local hiddenUi = (gethui or get_hidden_gui or function() return CoreGui end)()
local overlayParent = (typeof(hiddenUi) == "Instance" and not hiddenUi:IsA("ScreenGui")) and hiddenUi or CoreGui

for _, v in ipairs({
    "AntiAFK", "Antideath", "Gravity", "FovChanger", "TriggerBot", "ESP",
    "Cape", "AimAssist", "AntiFall", "Speed", "Fly", "NoClip",
    "AutoClicker", "FastStop", "FPSBooster", "AnimationPlayer", "BreadCrumbs"
}) do
    lib.kit:deregister(v .. "Module")
end

local overlayName    = "Overlay"
local highlightName  = "Highlights"
do
    local old = CoreGui:FindFirstChild(overlayName)
    if old then old:Destroy() end
    local oldH = CoreGui:FindFirstChild(highlightName)
    if oldH then oldH:Destroy() end
end

local OverlayGui = Instance.new("ScreenGui")
OverlayGui.Name             = overlayName
OverlayGui.IgnoreGuiInset   = true
OverlayGui.ResetOnSpawn     = false
OverlayGui.ZIndexBehavior   = Enum.ZIndexBehavior.Sibling
OverlayGui.Parent           = overlayParent

local HighlightFolder = Instance.new("Folder")
HighlightFolder.Name   = highlightName
HighlightFolder.Parent = CoreGui

local RuntimeState = {
    Character = nil,
    Humanoid = nil,
    RootPart = nil,
    Blocking = false,
    StunState = false,
    LastAction = {},
    HudLabel = nil,
}

local SavedStates = {
    Fullbright = nil,
    ScreenEffects = {},
    CharacterCollision = {},
    TrapParts = {},
    PlayerAttributes = {
        CameraShake  = lplr:GetAttribute("CameraShake"),
        ShowHitboxes = lplr:GetAttribute("ShowHitboxes"),
    },
}

local ESPCache = {
    Survivor = {}, Killer = {}, Generator = {},
    FuseBox = {}, Battery = {}, Door = {},
    Exit = {}, Beartrap = {}, EnnardMinion = {}, Objective = {},
}

local ESPColors = {
    Survivor = Color3.fromRGB(120, 255, 120),
    Killer = Color3.fromRGB(255, 90,  90 ),
    Generator = Color3.fromRGB(255, 215, 90 ),
    FuseBox = Color3.fromRGB(95,  225, 255),
    Battery = Color3.fromRGB(255, 170, 70 ),
    Door = Color3.fromRGB(120, 180, 255),
    Exit = Color3.fromRGB(255, 255, 255),
    Beartrap = Color3.fromRGB(255, 120, 120),
    EnnardMinion = Color3.fromRGB(190, 140, 255),
    Objective = Color3.fromRGB(255, 235, 140),
}

local Connections = {}
local ScreenEffectConnections = nil
local EMOTES = {"wave", "dance", "cheer", "laugh", "point"}
local PromptCache = {
    Map = nil,
    Entries = {},
    Updated = 0,
}
local GeneratorSolverPayloads = {
    {Wires = true, Switches = true, Lever = true},
    {Wires = true, Switches = true, Levers = true},
    {Wire = true, Switch = true, Lever = true},
    {Action = "Wires"},
    {Action = "Switches"},
    {Action = "Lever"},
}

local function loadPlayerUtility()
    local loadedUtility = nil

    if phantom and phantom.module and phantom.module.Load then
        local ok, utility = pcall(function()
            return phantom.module:Load("utility")
        end)

        if ok and type(utility) == "table" then
            loadedUtility = utility
        end
    end

    if not loadedUtility and type(readfile) == "function" and type(loadstring) == "function" then
        local ok, utility = pcall(function()
            return loadstring(readfile("Phantom/lib/Utility.lua"))()
        end)

        if ok and type(utility) == "table" then
            loadedUtility = utility
        end
    end

    return loadedUtility
end

local PlayerUtility = loadPlayerUtility()

local function safeRequire(m)
    if not m then return nil end
    local ok, r = pcall(require, m)
    return ok and r or nil
end

local function safeUtilityCall(methodName, ...)
    local method = PlayerUtility and PlayerUtility[methodName]
    if type(method) ~= "function" then
        return nil, false
    end

    local ok, result = pcall(method, ...)
    return result, ok
end

local modulesFolder = ReplicatedStorage:FindFirstChild("Modules")
local toolKitFolder = modulesFolder and modulesFolder:FindFirstChild("ToolKit")
local TaskKit = safeRequire(toolKitFolder and toolKitFolder:FindFirstChild("Tasks"))
local DoorKit = safeRequire(toolKitFolder and toolKitFolder:FindFirstChild("Doors"))

local Warp = safeRequire(modulesFolder and modulesFolder:FindFirstChild("Warp"))
local WarpInput = nil
if Warp and Warp.Client then
    pcall(function() WarpInput = Warp.Client("Input") end)
end

local function toLower(v)
    return string.lower(tostring(v or ""))
end

local function safeNotify(text)
    pcall(function() notification(text) end)
end

local function disconnectConnection(key)
    local c = Connections[key]
    if c then c:Disconnect(); Connections[key] = nil end
end

local function refreshCharacter()
    local utilityCharacter, utilityCharacterOk = safeUtilityCall("GetCharacter", lplr)
    RuntimeState.Character = utilityCharacterOk and typeof(utilityCharacter) == "Instance" and utilityCharacter or lplr.Character
    RuntimeState.Humanoid  = PlayerUtility and PlayerUtility.lplrHumanoid or (RuntimeState.Character and RuntimeState.Character:FindFirstChildOfClass("Humanoid") or nil)
    RuntimeState.RootPart  = PlayerUtility and PlayerUtility.lplrRoot or (RuntimeState.Character and RuntimeState.Character:FindFirstChild("HumanoidRootPart") or nil)
end

local function safeSetAttribute(instance, attr, value)
    if not instance then return false end
    return pcall(function() instance:SetAttribute(attr, value) end)
end

local function safeGetAttribute(instance, attr, fallback)
    if not instance then return fallback end
    local ok, r = pcall(function() return instance:GetAttribute(attr) end)
    return (ok and r ~= nil) and r or fallback
end

local function hasTag(instance, tagName)
    if not instance then return false end
    local ok, r = pcall(function() return instance:HasTag(tagName) end)
    if ok then return r end
    local ok2, r2 = pcall(function() return CollectionService:HasTag(instance, tagName) end)
    return ok2 and r2 or false
end

local function removeTag(instance, tagName)
    if not instance then return end
    if not pcall(function() instance:RemoveTag(tagName) end) then
        pcall(function() CollectionService:RemoveTag(instance, tagName) end)
    end
end

local function isAliveCharacter(character)
    if not character then return false end
    local player = Players:GetPlayerFromCharacter(character)
    if player then
        local alive, ok = safeUtilityCall("IsAlive", player)
        if ok then
            return alive == true
        end
    end
    local hum  = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    return hum ~= nil and root ~= nil and hum.Health > 0 and hum:GetState() ~= Enum.HumanoidStateType.Dead
end

local function IsAlive()
    refreshCharacter()
    local alive, ok = safeUtilityCall("IsAlive", lplr)
    if ok then
        return alive == true
    end
    return isAliveCharacter(RuntimeState.Character)
end

local function getPrimaryPart(instance)
    if not instance then return nil end
    if instance:IsA("ProximityPrompt") then return getPrimaryPart(instance.Parent) end
    if instance:IsA("BasePart") then return instance end
    if instance:IsA("Attachment") then
        return (instance.Parent and instance.Parent:IsA("BasePart")) and instance.Parent or nil
    end
    if instance:IsA("Model") then
        return instance.PrimaryPart or instance:FindFirstChild("Root") or instance:FindFirstChild("HumanoidRootPart") or instance:FindFirstChildWhichIsA("BasePart", true)
    end
    return nil
end

local function getDisplayName(instance)
    if not instance then return "Unknown" end
    if instance:IsA("Model") then
        local lp = Players:GetPlayerFromCharacter(instance)
        if lp then return lp.Name end
    end
    return instance.Name
end

local function getDistanceTo(instance)
    refreshCharacter()
    local root = RuntimeState.RootPart
    local target = getPrimaryPart(instance)
    if not (root and target) then return math.huge end
    return (root.Position - target.Position).Magnitude
end

local function getMap()
    local mapsFolder = Workspace:FindFirstChild("MAPS")
    if mapsFolder then
        local gameMap = mapsFolder:FindFirstChild("GAME MAP")
        if gameMap then return gameMap end
    end
    
    for _, v in ipairs(Workspace:GetChildren()) do
        if v:IsA("Model") and (v.Name:find("MAP", 1, true) or v.Name:find("Game", 1, true)) then
            return v
        end
    end
    return nil
end


local function safeGetChildren(obj)
    if not obj then return {} end
    local success, result = pcall(function() return obj:GetChildren() end)
    return success and result or {}
end

local function safeGetDescendants(obj)
    if not obj then return {} end
    local success, result = pcall(function() return obj:GetDescendants() end)
    return success and result or {}
end

local function invalidatePromptCache()
    PromptCache.Map = nil
    PromptCache.Entries = {}
    PromptCache.Updated = 0
end

local function getMapPrompts(forceRefresh)
    local map = getMap()
    if not map then
        invalidatePromptCache()
        return {}
    end

    local now = tick()
    if not forceRefresh and PromptCache.Map == map and now - PromptCache.Updated <= 0.4 then
        return PromptCache.Entries
    end

    local prompts = {}
    for _, descendant in ipairs(safeGetDescendants(map)) do
        if descendant:IsA("ProximityPrompt") then
            prompts[#prompts + 1] = descendant
        end
    end

    PromptCache.Map = map
    PromptCache.Entries = prompts
    PromptCache.Updated = now
    return prompts
end

local function getFolderChildren(folderName)
    local map = getMap()
    local folder = map and map:FindFirstChild(folderName)
    return folder and safeGetChildren(folder) or {}
end

local function getTaskList(method, fallbackFolder, keywords)
    if TaskKit and TaskKit[method] then
        local ok, r = pcall(TaskKit[method], TaskKit, getMap())
        if ok and type(r) == "table" and #r > 0 then
            return r
        end
    end

    local map = getMap()
    if not map then return {} end

    local results = {}
    local seen = {}

    local function addIfNew(obj)
        if obj and not seen[obj] then
            seen[obj] = true
            table.insert(results, obj)
        end
    end

    local folder = map:FindFirstChild(fallbackFolder)
    if folder then
        for _, child in ipairs(folder:GetChildren()) do
            addIfNew(child)
        end
    end

    if #results == 0 then
        for _, desc in ipairs(map:GetDescendants()) do
            if (desc:IsA("Folder") or desc:IsA("Model")) and 
               string.find(string.lower(desc.Name), string.lower(fallbackFolder), 1, true) then
                
                for _, child in ipairs(desc:GetChildren()) do
                    addIfNew(child)
                end
            end
        end
    end

    if #results == 0 and keywords and #keywords > 0 then
        for _, desc in ipairs(map:GetDescendants()) do
            if desc:IsA("Model") or desc:IsA("BasePart") or desc:IsA("Folder") then  -- added Folder too
                local nameLower = string.lower(desc.Name)
                for _, kw in ipairs(keywords) do
                    if string.find(nameLower, string.lower(kw), 1, true) then
                        addIfNew(desc)
                        break
                    end
                end
            end
        end
    end

    if #results == 0 and fallbackFolder and fallbackFolder ~= "" then
        local searchTerm = string.lower(fallbackFolder)
        for _, desc in ipairs(map:GetDescendants()) do
            if string.find(string.lower(desc.Name), searchTerm, 1, true) then
                addIfNew(desc)
            end
        end
    end

    return results
end

local function isValidDoor(obj)
    if not obj then return false end

    local name = string.lower(obj.Name)

    if name:find("locked") then return false end
    if name == "lockeddoors" then return false end

    return true
end

local function collectDoors(folder, results)
    if not folder then return end

    for _, d in ipairs(folder:GetChildren()) do
        if isValidDoor(d) then
            table.insert(results, d)
        end
    end
end

local function getDoors()
    local map = getMap()
    if not map then return {} end

    local results = {}

    collectDoors(map:FindFirstChild("Doors"), results)
    collectDoors(map:FindFirstChild("Double Doors"), results)

    if #results > 0 then
        return results
    end

    if DoorKit and DoorKit.GetDoors then
        local ok, r = pcall(DoorKit.GetDoors, DoorKit, map)
        if ok and type(r) == "table" then
            local filtered = {}

            for _, d in ipairs(r) do
                if isValidDoor(d) then
                    table.insert(filtered, d)
                end
            end

            if #filtered > 0 then
                return filtered
            end
        end
    end

    local fallback = getTaskList(nil, "Doors", {"door"})
    local filtered = {}

    for _, d in ipairs(fallback) do
        if isValidDoor(d) then
            table.insert(filtered, d)
        end
    end

    return filtered
end

local function mergeLists(...)
    local merged, seen = {}, {}
    for _, list in ipairs({...}) do
        for _, entry in ipairs(list) do
            if entry and not seen[entry] then
                seen[entry] = true
                table.insert(merged, entry)
            end
        end
    end
    return merged
end

local function nameMatchesKeywords(instance, keywords)
    local blob = toLower(instance and instance.Name or "")
    for _, kw in ipairs(keywords or {}) do
        if blob:find(kw, 1, true) then return true end
    end
    return false
end

local function collectMapObjects(keywords, validator)
    local map = getMap()
    if not map then return {} end
    local results, seen = {}, {}
    
    for _, d in ipairs(map:GetDescendants()) do
        if (d:IsA("Model") or d:IsA("BasePart")) then
            local target = d:IsA("BasePart") and (d.Parent:IsA("Model") and d.Parent or d) or d
            if not seen[target] then
                local nameLower = string.lower(target.Name)
                local match = false
                for _, kw in ipairs(keywords) do
                    if nameLower:find(kw, 1, true) then
                        match = true
                        break
                    end
                end
                if match and (not validator or validator(target)) then
                    seen[target] = true
                    table.insert(results, target)
                end
            end
        end
    end
    return results
end

local function getGenerators()
    local map = getMap()
    if not map then return {} end

    local folder = map:FindFirstChild("Generators")
    if folder then
        return folder:GetChildren()
    end

    return getTaskList("GetGenerators", "Generators", {"generator", "gen"})
end

local function getFuseBoxes()
    local map = getMap()
    if not map then return {} end

    local folder = map:FindFirstChild("FuseBoxes") or map:FindFirstChild("Fuse")
    if folder then
        return folder:GetChildren()
    end

    return getTaskList("GetFuseBoxes", "FuseBoxes", {"fuse", "fusebox"})
end

local function getBatteries()
    local map = getMap()
    if not map then return {} end

    local folder = map:FindFirstChild("Batteries")
    if folder then
        return folder:GetChildren()
    end

    return getTaskList("GetBatteries", "Batteries", {"battery"})
end

local function getObjectives()
    return mergeLists(getFolderChildren("Points"), getFolderChildren("GenPoints"), getFolderChildren("FusePoints"), getFolderChildren("AnnouncementPoints"))
end
local function getExits()
    return mergeLists(getFolderChildren("Exits"), collectMapObjects({"exit", "escape"}, function(i) return getPrimaryPart(i) ~= nil end))
end
local function getBeartraps()
    local results = {}
    local folder = workspace:FindFirstChild("IGNORE") and workspace.IGNORE:FindFirstChild("Trap")

    if folder then
        for _, obj in ipairs(folder:GetChildren()) do
            local n = string.lower(obj.Name)
            if n:find("bear", 1, true) and not n:find("spring", 1, true) then
                table.insert(results, obj)
            end
        end
        if #results > 0 then return results end
    end

    return collectMapObjects({"beartrap", "bear trap"}, function(i)
        local n = string.lower(i.Name)
        return not n:find("spring", 1, true)
    end)
end
local function getSpringtrapTraps()
    local results = {}
    local folder = workspace:FindFirstChild("IGNORE") and workspace.IGNORE:FindFirstChild("Trap")

    if folder then
        for _, obj in ipairs(folder:GetChildren()) do
            local n = string.lower(obj.Name)
            if n:find("spring", 1, true) then
                table.insert(results, obj)
            end
        end
        if #results > 0 then return results end
    end

    return collectMapObjects({"springtrap", "spring trap"}, function(i)
        return getPrimaryPart(i) ~= nil
    end)
end
local function getEnnardMinions()
    local results = {}
    local ignore = workspace:FindFirstChild("IGNORE")

    if ignore then
        for _, obj in ipairs(ignore:GetDescendants()) do
            if obj:IsA("Model") then
                local n = string.lower(obj.Name)
                if n:find("minion", 1, true) 
                    or (n:find("ennard", 1, true) and not obj:FindFirstChildOfClass("Humanoid")) then
                    table.insert(results, obj)
                end
            end
        end
        if #results > 0 then return results end
    end

    return collectMapObjects({"minion", "ennard"}, function(i)
        local n = string.lower(i.Name)
        return n:find("minion", 1, true)
            or (n:find("ennard", 1, true) and not i:FindFirstChildOfClass("Humanoid"))
    end)
end
local function getPlayerFolders()
    local pf = Workspace:FindFirstChild("PLAYERS")
    return pf and pf:FindFirstChild("ALIVE") or nil, pf and pf:FindFirstChild("KILLER") or nil
end

local function getSurvivorCharacters()
    local aliveFolder = getPlayerFolders()
    local out = {}
    if aliveFolder then
        for _, c in ipairs(safeGetChildren(aliveFolder)) do
            if c ~= RuntimeState.Character and isAliveCharacter(c) then
                table.insert(out, c)
            end
        end
    end
    return out
end

local function getKillerCharacters()
    local _, killerFolder = getPlayerFolders()
    local out = {}
    if killerFolder then
        for _, c in ipairs(safeGetChildren(killerFolder)) do
            if c ~= RuntimeState.Character and isAliveCharacter(c) then
                table.insert(out, c)
            end
        end
    end
    return out
end

local function isLocalKiller()
    local _, kf = getPlayerFolders()
    return RuntimeState.Character ~= nil and kf ~= nil and RuntimeState.Character.Parent == kf
end

local function getClosestCharacter(characters, maxDistance, ignoreUndetectable)
    local best, bestDist = nil, maxDistance or math.huge
    for _, c in ipairs(characters) do
        local root = getPrimaryPart(c)
        if root then
            local ok = not ignoreUndetectable or (not hasTag(c, "UNDETECTABLE") and not hasTag(c, "Imitation"))
            if ok then
                local d = getDistanceTo(root)
                if d < bestDist then best = c; bestDist = d end
            end
        end
    end
    return best, bestDist
end

local function getClosestCombatTarget(maxDist)
    local targets = isLocalKiller() and getSurvivorCharacters() or getKillerCharacters()
    return getClosestCharacter(targets, maxDist, true)
end

local function getClosestKiller(maxDist)
    return getClosestCharacter(getKillerCharacters(), maxDist, true)
end

local function getClosestFromList(list, maxDist, validator)
    local best, bestDist = nil, maxDist or math.huge
    for _, item in ipairs(list) do
        local part = getPrimaryPart(item)
        if part and (not validator or validator(item)) then
            local d = getDistanceTo(part)
            if d < bestDist then best = item; bestDist = d end
        end
    end
    return best, bestDist
end

local function promptMatches(prompt, keywords)
    if not prompt or not prompt:IsA("ProximityPrompt") or not prompt.Enabled then return false end
    if not keywords or #keywords == 0 then return true end
    local blob = toLower(prompt.Name .. " " .. prompt.ActionText .. " " .. prompt.ObjectText)
    for _, kw in ipairs(keywords) do
        if blob:find(kw, 1, true) then return true end
    end
    return false
end

local function findPromptInInstance(instance, keywords)
    if not instance then return nil end
    if instance:IsA("ProximityPrompt") and promptMatches(instance, keywords) then return instance end
    for _, d in ipairs(safeGetDescendants(instance)) do
        if d:IsA("ProximityPrompt") and promptMatches(d, keywords) then return d end
    end
    return nil
end

local function findPromptInMap(keywords, maxDist)
    local bestPrompt, bestDist = nil, maxDist or math.huge
    for _, d in ipairs(getMapPrompts()) do
        if d:IsA("ProximityPrompt") and promptMatches(d, keywords) then
            local dist = getDistanceTo(d.Parent)
            if dist < bestDist then bestPrompt = d; bestDist = dist end
        end
    end
    return bestPrompt, bestDist
end

local function firePrompt(prompt)
    if not prompt or not prompt.Enabled then return false end
    local holdDuration = math.max(prompt.HoldDuration or 0, 0.02)
    if fireproximityprompt then
        if pcall(function() fireproximityprompt(prompt, holdDuration + 0.02) end) then
            return true
        end
    end
    return pcall(function()
        prompt:InputHoldBegin()
        task.wait(holdDuration)
        prompt:InputHoldEnd()
    end)
end

local function moveNearInstance(instance, yOffset)
    refreshCharacter()
    if not (RuntimeState.RootPart and instance) then return false end
    local part = getPrimaryPart(instance)
    if not part then return false end
    local pos = part.Position + Vector3.new(0, yOffset or 2.5, 0)
    RuntimeState.RootPart.CFrame = CFrame.lookAt(pos, part.Position)
    return true
end

local function readyAction(key, delay)
    local now  = tick()
    local prev = RuntimeState.LastAction[key] or 0
    if now - prev >= delay then
        RuntimeState.LastAction[key] = now
        return true
    end
    return false
end

local function getEquippedTool()
    refreshCharacter()
    if not RuntimeState.Character then return nil end
    for _, c in ipairs(RuntimeState.Character:GetChildren()) do
        if c:IsA("Tool") then return c end
    end
    return nil
end

local function fireDescendantChannels(root, keywords, ...)
    if not root then return false end
    local args = table.pack(...)
    for _, d in ipairs(root:GetDescendants()) do
        if nameMatchesKeywords(d, keywords) then
            local ok = false
            if     d:IsA("RemoteEvent")    then ok = pcall(d.FireServer,    d, table.unpack(args, 1, args.n))
            elseif d:IsA("BindableEvent")  then ok = pcall(d.Fire,          d, table.unpack(args, 1, args.n))
            elseif d:IsA("RemoteFunction") then ok = pcall(d.InvokeServer,  d, table.unpack(args, 1, args.n))
            elseif d:IsA("BindableFunction") then ok = pcall(d.Invoke,      d, table.unpack(args, 1, args.n))
            end
            if ok then return true end
        end
    end
    return false
end

local function setBlockHeld(holding)
    if RuntimeState.Blocking == holding then return end
    RuntimeState.Blocking = holding
    local tool = getEquippedTool()
    if tool then fireDescendantChannels(tool, {"block", "guard", "parry"}, holding) end
    if holding then
        if mouse2press   then pcall(mouse2press)   end
    else
        if mouse2release then pcall(mouse2release) end
    end
end

local function performSwing()
    local tool = getEquippedTool()
    if tool then
        pcall(function() tool:Activate() end)
        fireDescendantChannels(tool, {"swing", "attack", "slash", "hit"})
    end
    if mouse1click then
        pcall(mouse1click)
    elseif mouse1press and mouse1release then
        pcall(mouse1press)
        task.delay(0.03, function() pcall(mouse1release) end)
    end
end

local function isPromptTargetFinished(instance)
    for _, flag in ipairs({"Done","Completed","Fixed","Repaired","Powered","Opened","Open","Finished"}) do
        if safeGetAttribute(instance, flag, nil) == true then return true end
    end
    local p = safeGetAttribute(instance, "Progress", nil) or safeGetAttribute(instance, "Completion", nil) or safeGetAttribute(instance, "Percent",    nil)
    return type(p) == "number" and p >= 100
end

local function tryInteractWithTarget(target, keywords)
    local prompt = findPromptInInstance(target, keywords) or findPromptInInstance(target)
    if not prompt or isPromptTargetFinished(target) then return false end
    local maxActivationDistance = math.max((prompt.MaxActivationDistance or 0) + 1.5, 8)
    if getDistanceTo(target) > maxActivationDistance then
        moveNearInstance(target, 2.5)
        task.delay(0.05, function() firePrompt(prompt) end)
        return true
    end
    return firePrompt(prompt)
end

local function isPostEffect(i)
    return i:IsA("BlurEffect") or i:IsA("ColorCorrectionEffect") or i:IsA("BloomEffect") or i:IsA("SunRaysEffect") or i:IsA("DepthOfFieldEffect")
end

local function shouldHideGuiEffect(i)
    local n = toLower(i.Name)
    return n:find("static",1,true) or n:find("vignette",1,true) or n:find("blur",1,true) or n:find("blood",1,true) or n:find("noise",1,true)    or n:find("flash",1,true)
end

local function applyFullbright()
    if not SavedStates.Fullbright then
        SavedStates.Fullbright = {
            Brightness     = Lighting.Brightness,
            Ambient        = Lighting.Ambient,
            OutdoorAmbient = Lighting.OutdoorAmbient,
            ClockTime      = Lighting.ClockTime,
            FogEnd         = Lighting.FogEnd,
            GlobalShadows  = Lighting.GlobalShadows,
        }
    end
    Lighting.Brightness     = 2.5
    Lighting.Ambient        = Color3.fromRGB(175, 175, 175)
    Lighting.OutdoorAmbient = Color3.fromRGB(175, 175, 175)
    Lighting.ClockTime      = 14
    Lighting.FogEnd         = 100000
    Lighting.GlobalShadows  = false
end

local function restoreFullbright()
    if not SavedStates.Fullbright then return end
    local fb = SavedStates.Fullbright
    Lighting.Brightness = fb.Brightness
    Lighting.Ambient = fb.Ambient
    Lighting.OutdoorAmbient = fb.OutdoorAmbient
    Lighting.ClockTime = fb.ClockTime
    Lighting.FogEnd = fb.FogEnd
    Lighting.GlobalShadows = fb.GlobalShadows
    SavedStates.Fullbright = nil
end

local function restoreCharacterCollision()
    for part, prev in pairs(SavedStates.CharacterCollision) do
        if typeof(part) == "Instance" and part.Parent and part:IsA("BasePart") then
            part.CanCollide = prev
        end
    end
    table.clear(SavedStates.CharacterCollision)
end

local function protectCharacterCollision(character)
    for _, d in ipairs(character:GetDescendants()) do
        if d:IsA("BasePart") then
            if SavedStates.CharacterCollision[d] == nil then
                SavedStates.CharacterCollision[d] = d.CanCollide
            end
            d.CanCollide = false
        end
    end
end

local function restoreTrapParts()
    for part, state in pairs(SavedStates.TrapParts) do
        if typeof(part) == "Instance" and part.Parent and part:IsA("BasePart") then
            part.CanCollide   = state.CanCollide
            part.Transparency = state.Transparency
            pcall(function() part.CanTouch = state.CanTouch end)
        end
    end
    table.clear(SavedStates.TrapParts)
end

local function neutralizeTrapPart(part)
    if not part or not part:IsA("BasePart") then return end
    if SavedStates.TrapParts[part] == nil then
        SavedStates.TrapParts[part] = {
            CanCollide = part.CanCollide,
            CanTouch = part.CanTouch,
            Transparency = part.Transparency,
        }
    end
    part.CanCollide   = false
    part.Transparency = math.max(part.Transparency, 0.55)
    pcall(function() part.CanTouch = false end)
end

local function ensureHudLabel()
    if RuntimeState.HudLabel and RuntimeState.HudLabel.Parent then
        return RuntimeState.HudLabel
    end
    
    local label = Instance.new("TextLabel")
    label.Name = "KillerDistanceHUD"
    label.AnchorPoint = Vector2.new(0.5, 0)
    label.Position = UDim2.new(0.5, 0, 0, 20)
    label.Size = UDim2.new(0, 280, 0, 38)
    label.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    label.BackgroundTransparency = 0.25
    label.BorderSizePixel = 0
    label.Font = Enum.Font.GothamBold
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextSize = 16
    label.TextStrokeTransparency = 0
    label.Text = "Killer Distance: waiting..."
    label.Parent = OverlayGui
    
    RuntimeState.HudLabel = label
    return label
end

local function destroyHudLabel()
    if RuntimeState.HudLabel then
        RuntimeState.HudLabel:Destroy()
        RuntimeState.HudLabel = nil
    end
end

local function destroyESPEntry(entry)
    if entry.Highlight then entry.Highlight:Destroy() end
    if entry.Billboard then entry.Billboard:Destroy() end
end

local function clearESPBucket(name)
    for inst, entry in pairs(ESPCache[name]) do
        destroyESPEntry(entry)
        ESPCache[name][inst] = nil
    end
end

local function clearAllESP()
    for name in pairs(ESPCache) do clearESPBucket(name) end
end

local function ensureESPEntry(bucketName, instance, text, color)
    local part = getPrimaryPart(instance)
    if not part then return end

    ESPCache[bucketName] = ESPCache[bucketName] or {}
    local entry = ESPCache[bucketName][instance]

    if not entry then
        local hl = Instance.new("Highlight")
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.FillTransparency = 0.3
        hl.OutlineTransparency = 0
        hl.Parent = HighlightFolder

        local bb = Instance.new("BillboardGui")
        bb.Name = bucketName .. "_ESP"
        bb.AlwaysOnTop = true
        bb.Size = UDim2.new(0, 240, 0, 65)
        bb.StudsOffset = Vector3.new(0, 3, 0)
        bb.MaxDistance = 800
        bb.Parent = OverlayGui

        local lbl = Instance.new("TextLabel")
        lbl.BackgroundTransparency = 1
        lbl.Size = UDim2.new(1, 0, 1, 0)
        lbl.Font = Enum.Font.GothamBold
        lbl.TextStrokeTransparency = 0
        lbl.TextScaled = true
        lbl.RichText = false
        lbl.Parent = bb

        entry = { Highlight = hl, Billboard = bb, Label = lbl }
        ESPCache[bucketName][instance] = entry
    end

    local adornee = instance:IsA("Model") and instance or part
    if entry.Highlight.Adornee ~= adornee then
        entry.Highlight.Adornee = adornee
    end

    entry.Highlight.FillColor = color
    entry.Highlight.OutlineColor = color

    if entry.Billboard.Adornee ~= part then
        entry.Billboard.Adornee = part
    end

    if entry.Label.Text ~= text then
        entry.Label.Text = text
    end

    if entry.Label.TextColor3 ~= color then
        entry.Label.TextColor3 = color
    end
end

local MAX_DISTANCE = nil
local function updateESPBucket(name, instances, textFn, color)
    ESPCache[name] = ESPCache[name] or {}
    local cache = ESPCache[name]

    local seen = {}

    for _, inst in ipairs(instances or {}) do
        if inst and inst.Parent then
            local part = getPrimaryPart(inst)
            if part then
                if not MAX_DISTANCE or getDistanceTo(inst) <= MAX_DISTANCE then
                    local success, text = pcall(textFn, inst)
                    if success and text and text ~= "" then
                        seen[inst] = true
                        ensureESPEntry(name, inst, text, color)
                    end
                end
            end
        end
    end

    for inst, entry in pairs(cache) do
        if not seen[inst] or not (inst and inst.Parent) then
            destroyESPEntry(entry)
            cache[inst] = nil
        end
    end
end

local function formatDist(instance)
    local d = getDistanceTo(instance)
    return d == math.huge and "?" or tostring(math.floor(d))
end

local function buildWorldESPText(prefix, instance)
    local progress =
        safeGetAttribute(instance, "Progress")
        or safeGetAttribute(instance, "Completion")
        or safeGetAttribute(instance, "Percent")

    local status = ""
    if type(progress) == "number" then
        status = string.format(" (%d%%)", math.floor(progress))
    elseif isPromptTargetFinished(instance) then
        status = " [DONE]"
    end

    return string.format(
        "%s%s\n[%s studs]",
        prefix,
        status,
        formatDist(instance)
    )
end

local function buildPlayerESPText(character, showRole, role, showHealth, showStamina)
    local lines = {}
    table.insert(lines, showRole and (role .. ": " .. getDisplayName(character)) or getDisplayName(character))
    if showHealth then
        local hum = character:FindFirstChildOfClass("Humanoid")
        table.insert(lines, "HP: " .. tostring(math.floor(hum and hum.Health or 0)))
    end
    if showStamina then
        table.insert(lines, "STA: " .. tostring(math.floor(safeGetAttribute(character, "Stamina", 0) or 0)))
    end
    return table.concat(lines, "\n")
end

local function activateVisibleGuiButton(keywords)
    local pg = PlayerGui or lplr:FindFirstChildOfClass("PlayerGui")
    if not pg then return false end
    for _, d in ipairs(pg:GetDescendants()) do
        if d:IsA("GuiButton") then
            local cur, visible = d, true
            while cur and cur ~= pg do
                if cur:IsA("GuiObject") and not cur.Visible then visible = false; break end
                if cur:IsA("ScreenGui") and not cur.Enabled  then visible = false; break end
                cur = cur.Parent
            end
            if visible then
                local blob = toLower(d.Name) .. (d:IsA("TextButton") and (" " .. toLower(d.Text)) or "")
                for _, kw in ipairs(keywords) do
                    if blob:find(kw, 1, true) then
                        if pcall(function() d:Activate() end) then return true end
                        if firesignal then
                            if pcall(function() firesignal(d.MouseButton1Click) end) then return true end
                        end
                    end
                end
            end
        end
    end
    return false
end

local function isGuiChainVisible(instance)
    local current = instance
    while current do
        if current:IsA("GuiObject") and not current.Visible then
            return false
        end
        if current:IsA("LayerCollector") and current.Enabled == false then
            return false
        end
        current = current.Parent
    end
    return instance ~= nil and instance.Parent ~= nil
end

local function activateVisibleGuiButtonInRoot(root, keywords)
    if not root then return false end
    for _, d in ipairs(safeGetDescendants(root)) do
        if d:IsA("GuiButton") and isGuiChainVisible(d) then
            local blob = toLower(d.Name) .. (d:IsA("TextButton") and (" " .. toLower(d.Text)) or "")
            for _, kw in ipairs(keywords or {}) do
                if blob:find(kw, 1, true) then
                    if pcall(function() d:Activate() end) then return true end
                    if firesignal and pcall(function() firesignal(d.MouseButton1Click) end) then
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function safeFireChannel(channel, ...)
    if not channel then return false end
    local args = table.pack(...)
    if channel:IsA("RemoteEvent") then
        return pcall(channel.FireServer, channel, table.unpack(args, 1, args.n))
    elseif channel:IsA("BindableEvent") then
        return pcall(channel.Fire, channel, table.unpack(args, 1, args.n))
    elseif channel:IsA("RemoteFunction") then
        return pcall(channel.InvokeServer, channel, table.unpack(args, 1, args.n))
    elseif channel:IsA("BindableFunction") then
        return pcall(channel.Invoke, channel, table.unpack(args, 1, args.n))
    end
    return false
end

local function getGeneratorPanel()
    local gui = PlayerGui or lplr:FindFirstChildOfClass("PlayerGui")
    if not gui then
        return nil, nil, nil
    end

    local gen = gui:FindFirstChild("Gen")
    local generatorMain = gen and gen:FindFirstChild("GeneratorMain")
    local event = generatorMain and generatorMain:FindFirstChild("Event")
    return gen, generatorMain, event
end

local function solveGeneratorPanel(generatorMain, event)
    if generatorMain and isGuiChainVisible(generatorMain) then
        if activateVisibleGuiButtonInRoot(generatorMain, {"wire", "switch", "lever", "repair"}) then
            return true
        end
    end

    if event then
        for _, payload in ipairs(GeneratorSolverPayloads) do
            if safeFireChannel(event, payload) then
                return true
            end
        end
    end

    return false
end

local function getClosestInteractiveTarget(instances, keywords, maxDist)
    local best, bestDist = nil, maxDist or math.huge
    for _, instance in ipairs(instances or {}) do
        if instance and instance.Parent and not isPromptTargetFinished(instance) then
            local prompt = findPromptInInstance(instance, keywords) or findPromptInInstance(instance)
            if prompt and prompt.Enabled then
                local dist = getDistanceTo(instance)
                if dist < bestDist then
                    best = instance
                    bestDist = dist
                end
            end
        end
    end
    return best, bestDist
end

local function playRandomEmote()
    refreshCharacter()
    if not RuntimeState.Humanoid then return false end
    local emote = EMOTES[math.random(1, #EMOTES)]
    if pcall(function() RuntimeState.Humanoid:PlayEmote(emote) end) then return true end
    local pg = lplr:FindFirstChildOfClass("PlayerGui")
    if not pg then return false end
    for _, d in ipairs(pg:GetDescendants()) do
        if d.Name == "PlayEmote" then
            if d:IsA("BindableFunction") then
                if pcall(function() d:Invoke(emote) end) then return true end
            elseif d:IsA("BindableEvent") then
                if pcall(function() d:Fire(emote) end) then return true end
            end
        end
    end
    return false
end

refreshCharacter()

Connections.CharacterAdded = lplr.CharacterAdded:Connect(function(character)
    RuntimeState.Character = character
    RuntimeState.Humanoid  = character:WaitForChild("Humanoid", 10)
    RuntimeState.RootPart  = character:WaitForChild("HumanoidRootPart", 10)
    RuntimeState.StunState = false
    RuntimeState.Blocking  = false
end)

Connections.CharacterRemoving = lplr.CharacterRemoving:Connect(function()
    RuntimeState.Character = nil
    RuntimeState.Humanoid  = nil
    RuntimeState.RootPart  = nil
    RuntimeState.Blocking  = false
    disconnectConnection("StunAlert")
    restoreCharacterCollision()
end)

ops:onExit("70845479499574_cleanup", function()
    for _, key in ipairs({
        "AutoBlock", "AutoSwing", "AntiConfusion", "AutoUnstun", "AntiRagdoll",
        "HideBlockAnim", "BlockCameraShake", "BlockKillerInvis", "BlockScreenEffects",
        "InfiniteStamina", "NoClip", "AntiSlide", "AutoBarricade", "AutoEscape",
        "Fullbright", "AutoShake", "FastItemPickup", "AutoRepairGenerators", "AntiSpringtrapTraps",
        "KillerDistanceHUD", "AutoEmotePlayer",
        "SurvivorESP", "KillerESP", "GeneratorESP", "FuseBoxESP", "BatteryESP",
        "DoorESP", "ExitESP", "BeartrapESP", "EnnardMinionsESP", "ObjectiveESP",
    }) do
        RunLoops:UnbindFromHeartbeat(key)
    end

    setBlockHeld(false)
    restoreCharacterCollision()
    restoreTrapParts()
    restoreFullbright()
    clearAllESP()
    destroyHudLabel()
    invalidatePromptCache()

    if ScreenEffectConnections then
        for _, connection in ipairs(ScreenEffectConnections) do
            connection:Disconnect()
        end
        ScreenEffectConnections = nil
    end

    safeSetAttribute(lplr, "ShowHitboxes", SavedStates.PlayerAttributes.ShowHitboxes ~= nil and SavedStates.PlayerAttributes.ShowHitboxes or false)
    if SavedStates.PlayerAttributes.CameraShake ~= nil then
        safeSetAttribute(lplr, "CameraShake", SavedStates.PlayerAttributes.CameraShake)
    end

    disconnectConnection("CharacterAdded")
    disconnectConnection("CharacterRemoving")
    disconnectConnection("StunAlert")

    if RuntimeState.Humanoid then
        pcall(function()
            RuntimeState.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll,     true)
            RuntimeState.Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
        end)
    end

    if OverlayGui then OverlayGui:Destroy()    end
    if HighlightFolder then HighlightFolder:Destroy() end
end)

local function restoreScreenEffects()
    if not SavedStates or not SavedStates.ScreenEffects then return end

    for instance, prev in pairs(SavedStates.ScreenEffects) do
        if typeof(instance) == "Instance" and instance.Parent then
            if isPostEffect(instance) then
                instance.Enabled = prev
            elseif instance:IsA("GuiObject") then
                instance.Visible = prev
            end
        end
    end

    table.clear(SavedStates.ScreenEffects)
end

runcode(function()
    local CombatPanel = lib.Registry.combatPanel.API

    CombatPanel.CreateOptionsButton({
        Name = "Auto Block",
        Function = function(callback)
            if callback then
                RunLoops:BindToHeartbeat("AutoBlock", function()
                    if not IsAlive() then setBlockHeld(false); return end
                    local rootPart = RuntimeState.RootPart
                    local target, distance = getClosestCombatTarget(18)
                    local targetRoot = getPrimaryPart(target)
                    if targetRoot then
                        local dir = (rootPart.Position - targetRoot.Position)
                        local dot = dir.Magnitude > 0 and targetRoot.CFrame.LookVector:Dot(dir.Unit) or -1
                        setBlockHeld(distance <= 9 or dot > 0.1)
                    else
                        setBlockHeld(false)
                    end
                end)
            else
                RunLoops:UnbindFromHeartbeat("AutoBlock")
                setBlockHeld(false)
            end
        end
    })

    CombatPanel.CreateOptionsButton({
        Name = "Auto Swing",
        Function = function(callback)
            if callback then
                RunLoops:BindToHeartbeat("AutoSwing", function()
                    if not IsAlive() then return end
                    local target, distance = getClosestCombatTarget(11)
                    if target and distance <= 11 and readyAction("AutoSwing", 0.18) then
                        performSwing()
                    end
                end)
            else
                RunLoops:UnbindFromHeartbeat("AutoSwing")
            end
        end
    })

    CombatPanel.CreateOptionsButton({
        Name = "Anti Confusion",
        Function = function(callback)
            if callback then
                RunLoops:BindToHeartbeat("AntiConfusion", function()
                    if not IsAlive() then return end
                    removeTag(RuntimeState.Character, "Confusion")
                end)
            else
                RunLoops:UnbindFromHeartbeat("AntiConfusion")
            end
        end
    })

    CombatPanel.CreateOptionsButton({
        Name = "Auto Unstun",
        Function = function(callback)
            if callback then
                RunLoops:BindToHeartbeat("AutoUnstun", function()
                    if not IsAlive() then return end
                    local char = RuntimeState.Character
                    local hum  = RuntimeState.Humanoid
                    safeSetAttribute(char, "Stun", false)
                    removeTag(char, "CantMove")
                    removeTag(char, "StopAnim")
                    removeTag(char, "KillAnims")
                    hum.PlatformStand = false
                end)
            else
                RunLoops:UnbindFromHeartbeat("AutoUnstun")
            end
        end
    })

    CombatPanel.CreateOptionsButton({
        Name = "Stun Alert",
        Function = function(callback)
            if callback then
                disconnectConnection("StunAlert")
                RuntimeState.StunState = false
                if RuntimeState.Character then
                    Connections.StunAlert = RuntimeState.Character:GetAttributeChangedSignal("Stun"):Connect(function()
                            local stunned = RuntimeState.Character and safeGetAttribute(RuntimeState.Character, "Stun", false) or false
                            if stunned and not RuntimeState.StunState then
                            safeNotify("Stun Alert: you are stunned")
                        end
                        RuntimeState.StunState = not not stunned
                    end)
                end
            else
                disconnectConnection("StunAlert")
                RuntimeState.StunState = false
            end
        end
    })

    CombatPanel.CreateOptionsButton({
        Name = "Anti Ragdoll",
        Function = function(callback)
            if callback then
                RunLoops:BindToHeartbeat("AntiRagdoll", function()
                    if not IsAlive() then return end
                    local char = RuntimeState.Character
                    local hum  = RuntimeState.Humanoid
                    safeSetAttribute(char, "Ragdoll", false)
                    removeTag(char, "Ragdoll")
                    pcall(function()
                        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll,     false)
                        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
                    end)
                    hum.PlatformStand = false
                    local state = hum:GetState()
                    if state == Enum.HumanoidStateType.Ragdoll or state == Enum.HumanoidStateType.FallingDown or state == Enum.HumanoidStateType.PlatformStanding then
                        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                    end
                end)
            else
                RunLoops:UnbindFromHeartbeat("AntiRagdoll")
                if RuntimeState.Humanoid then
                    pcall(function()
                        RuntimeState.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
                        RuntimeState.Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
                    end)
                end
            end
        end
    })

    CombatPanel.CreateOptionsButton({
        Name = "Hide Block Animation",
        Function = function(callback)
            if callback then
                RunLoops:BindToHeartbeat("HideBlockAnim", function()
                    if not IsAlive() then return end
                    for _, track in ipairs(RuntimeState.Humanoid:GetPlayingAnimationTracks()) do
                        local n = toLower(track.Name .. " " .. (track.Animation and track.Animation.Name or ""))
                        if n:find("block",1,true) or n:find("guard",1,true) or n:find("parry",1,true) then
                            pcall(function() track:Stop(0) end)
                        end
                    end
                end)
            else
                RunLoops:UnbindFromHeartbeat("HideBlockAnim")
            end
        end
    })

    CombatPanel.CreateOptionsButton({
        Name = "Block Camera Shake",
        Function = function(callback)
            if callback then
                RunLoops:BindToHeartbeat("BlockCameraShake", function()
                    safeSetAttribute(lplr, "CameraShake", false)
                end)
            else
                RunLoops:UnbindFromHeartbeat("BlockCameraShake")
                if SavedStates.PlayerAttributes.CameraShake ~= nil then
                    safeSetAttribute(lplr, "CameraShake", SavedStates.PlayerAttributes.CameraShake)
                end
            end
        end
    })

    CombatPanel.CreateOptionsButton({
        Name = "Block Killer Invisibility",
        Function = function(enabled)
            if enabled then
                local cachedParts = {}

                local function cacheKiller(killer)
                    if cachedParts[killer] then return end
                    cachedParts[killer] = {}

                    for _, d in ipairs(killer:GetDescendants()) do
                        if d:IsA("BasePart") then
                            table.insert(cachedParts[killer], d)
                        end
                    end
                end

                RunLoops:BindToHeartbeat("BlockKillerInvis", function()
                    for _, killer in ipairs(getKillerCharacters()) do
                        cacheKiller(killer)

                        removeTag(killer, "UNDETECTABLE")
                        removeTag(killer, "INVIS")

                        for _, part in ipairs(cachedParts[killer]) do
                            if part then
                                local orig = part:GetAttribute("OGTransparency")
                                if orig ~= nil then
                                    part.Transparency = orig
                                end
                                part.LocalTransparencyModifier = 0

                                removeTag(part, "UNDETECTABLE")
                                removeTag(part, "INVIS")
                            end
                        end
                    end
                end)
            else
                RunLoops:UnbindFromHeartbeat("BlockKillerInvis")
            end
        end
    })

    local handleInstance = function(i)
        if isPostEffect(i) then
            if SavedStates.ScreenEffects[i] == nil then
                SavedStates.ScreenEffects[i] = i.Enabled
            end
            i.Enabled = false
        elseif i:IsA("GuiObject") and shouldHideGuiEffect(i) then
            if SavedStates.ScreenEffects[i] == nil then
                SavedStates.ScreenEffects[i] = i.Visible
            end
            i.Visible = false
        end
    end

    CombatPanel.CreateOptionsButton({
        Name = "Block Screen Effects",
        Function = function(enabled)
            if enabled then
                SavedStates.ScreenEffects = SavedStates.ScreenEffects or {}

                for _, i in ipairs(Lighting:GetChildren()) do
                    handleInstance(i)
                end

                local pg = lplr:FindFirstChildOfClass("PlayerGui")
                if pg then
                    for _, i in ipairs(pg:GetDescendants()) do
                        handleInstance(i)
                    end
                end

                ScreenEffectConnections = {}

                table.insert(ScreenEffectConnections, Lighting.ChildAdded:Connect(handleInstance))

                if pg then
                    table.insert(ScreenEffectConnections, pg.DescendantAdded:Connect(handleInstance))
                end
            else
                if ScreenEffectConnections then
                    for _, c in ipairs(ScreenEffectConnections) do
                        c:Disconnect()
                    end
                    ScreenEffectConnections = nil
                end

                restoreScreenEffects()
            end
        end
    })
end)

runcode(function()
    local MovementPanel = lib.Registry.utillityPanel.API

    MovementPanel.CreateOptionsButton({
        Name = "Auto Barricade",
        Function = function(callback)
            if callback then
                RunLoops:BindToHeartbeat("AutoBarricade", function()
                    if not IsAlive() or isLocalKiller() then return end
                    if not readyAction("AutoBarricade", 0.5) then return end
                    local door = getClosestFromList(getDoors(), 60, function(instance)
                        if DoorKit and DoorKit.IsBarricading then
                            local ok, v = pcall(DoorKit.IsBarricading, DoorKit, instance)
                            if ok and v then return false end
                        end
                        if DoorKit and DoorKit.IsDoorBarricaded then
                            local ok, v = pcall(DoorKit.IsDoorBarricaded, DoorKit, instance)
                            if ok and v then return false end
                        end
                        return not safeGetAttribute(instance, "HOLD", false)
                    end)
                    if door then tryInteractWithTarget(door, {"barricade"}) end
                end)
            else
                RunLoops:UnbindFromHeartbeat("AutoBarricade")
            end
        end
    })

    MovementPanel.CreateOptionsButton({
        Name = "Auto Escape",
        Function = function(callback)
            if callback then
                RunLoops:BindToHeartbeat("AutoEscape", function()
                    if not IsAlive() or isLocalKiller() then return end
                    if not readyAction("AutoEscape", 0.45) then return end
                    local exitTarget = getClosestFromList(getExits(), 250)
                    if exitTarget then
                        tryInteractWithTarget(exitTarget, {"escape", "exit", "open", "leave"})
                    else
                        local exitPrompt = findPromptInMap({"escape", "exit", "leave"}, 250)
                        if exitPrompt then
                            tryInteractWithTarget(exitPrompt, {"escape", "exit", "leave"})
                        end
                    end
                end)
            else
                RunLoops:UnbindFromHeartbeat("AutoEscape")
            end
        end
    })

    MovementPanel.CreateOptionsButton({
        Name = "Infinite Stamina",
        Function = function(callback)
            if callback then
                local lastMax = 100
                RunLoops:BindToHeartbeat("InfiniteStamina", function()
                    refreshCharacter()
                    if not IsAlive() then return end
                    local char = RuntimeState.Character
                    local max  = safeGetAttribute(char, "MaxStamina", nil) or safeGetAttribute(char, "StaminaMax",  nil) or safeGetAttribute(char, "MaxSprint",   nil) or 100
                    safeSetAttribute(char, "Stamina", max)
                    safeSetAttribute(char, "Sprint", max)
                    safeSetAttribute(char, "Sprinting", false)
                end)
            else
                RunLoops:UnbindFromHeartbeat("InfiniteStamina")
            end
        end
    })

    MovementPanel.CreateOptionsButton({
        Name = "NoClip",
        Function = function(callback)
            if callback then
                RunLoops:BindToHeartbeat("NoClip", function()
                    if not IsAlive() then return end
                    protectCharacterCollision(RuntimeState.Character)
                end)
            else
                RunLoops:UnbindFromHeartbeat("NoClip")
                restoreCharacterCollision()
            end
        end
    })

    MovementPanel.CreateOptionsButton({
        Name = "Anti Slide After Stop",
        Function = function(callback)
            if callback then
                RunLoops:BindToHeartbeat("AntiSlide", function()
                    if not IsAlive() then return end
                    local char = RuntimeState.Character
                    local hum  = RuntimeState.Humanoid
                    local root = RuntimeState.RootPart
                    removeTag(char, "SlowStop")
                    if hum.MoveDirection.Magnitude <= 0.05 then
                        root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
                    end
                end)
            else
                RunLoops:UnbindFromHeartbeat("AntiSlide")
            end
        end
    })

    MovementPanel.CreateOptionsButton({
        Name = "Fullbright",
        Function = function(callback)
            if callback then
                RunLoops:BindToHeartbeat("Fullbright", function()
                    applyFullbright()
                end)
            else
                RunLoops:UnbindFromHeartbeat("Fullbright")
                restoreFullbright()
            end
        end
    })
end)

runcode(function()
    local RenderPanel = lib.Registry.renderPanel.API

    local HealthESP  = false
    local StaminaESP = false

    RenderPanel.CreateOptionsButton({
        Name = "Health ESP",
        Function = function(callback)
            HealthESP = callback
        end
    })

    RenderPanel.CreateOptionsButton({
        Name = "Stamina ESP",
        Function = function(callback)
            StaminaESP = callback
        end
    })

    RenderPanel.CreateOptionsButton({
        Name = "Survivor ESP",
        Function = function(callback)
            if callback then
                RunLoops:BindToHeartbeat("SurvivorESP", function()
                    if not readyAction("SurvivorESPTick", 0.15) then return end
                    pcall(function()
                        updateESPBucket("Survivor", getSurvivorCharacters(), function(character)
                            return buildPlayerESPText(character, true, "Survivor", HealthESP, StaminaESP)
                        end, ESPColors.Survivor)
                    end)
                end)
            else
                RunLoops:UnbindFromHeartbeat("SurvivorESP")
                clearESPBucket("Survivor")
            end
        end
    })

    RenderPanel.CreateOptionsButton({
        Name = "Killer ESP",
        Function = function(callback)
            if callback then
                RunLoops:BindToHeartbeat("KillerESP", function()
                    if not readyAction("KillerESPTick", 0.15) then return end
                    pcall(function()
                        updateESPBucket("Killer", getKillerCharacters(), function(character)
                            return buildPlayerESPText(character, true, "Killer", HealthESP, StaminaESP)
                        end, ESPColors.Killer)
                    end)
                end)
            else
                RunLoops:UnbindFromHeartbeat("KillerESP")
                clearESPBucket("Killer")
            end
        end
    })

    RenderPanel.CreateOptionsButton({
        Name = "Generator ESP",
        Function = function(callback)
            if callback then
                RunLoops:BindToHeartbeat("GeneratorESP", function()
                    if not readyAction("GeneratorESPTick", 0.15) then return end
                    pcall(function()
                        updateESPBucket("Generator", getGenerators(), function(instance)
                            return buildWorldESPText("Generator", instance)
                        end, ESPColors.Generator)
                    end)
                end)
            else
                RunLoops:UnbindFromHeartbeat("GeneratorESP")
                clearESPBucket("Generator")
            end
        end
    })

    RenderPanel.CreateOptionsButton({
        Name = "FuseBox ESP",
        Function = function(callback)
            if callback then
                RunLoops:BindToHeartbeat("FuseBoxESP", function()
                    if not readyAction("FuseBoxESPTick", 0.15) then return end
                    pcall(function()
                        updateESPBucket("FuseBox", getFuseBoxes(), function(instance)
                            return buildWorldESPText("FuseBox", instance)
                        end, ESPColors.FuseBox)
                    end)
                end)
            else
                RunLoops:UnbindFromHeartbeat("FuseBoxESP")
                clearESPBucket("FuseBox")
            end
        end
    })

    RenderPanel.CreateOptionsButton({
        Name = "Battery ESP",
        Function = function(callback)
            if callback then
                RunLoops:BindToHeartbeat("BatteryESP", function()
                    if not readyAction("BatteryESPTick", 0.15) then return end
                    pcall(function()
                        updateESPBucket("Battery", getBatteries(), function(instance)
                            return buildWorldESPText("Battery", instance)
                        end, ESPColors.Battery)
                    end)
                end)
            else
                RunLoops:UnbindFromHeartbeat("BatteryESP")
                clearESPBucket("Battery")
            end
        end
    })

    RenderPanel.CreateOptionsButton({
        Name = "Door ESP",
        Function = function(callback)
            if callback then
                RunLoops:BindToHeartbeat("DoorESP", function()
                    if not readyAction("DoorESPTick", 0.15) then return end
                    pcall(function()
                        updateESPBucket("Door", getDoors(), function(instance)
                            return buildWorldESPText("Door", instance)
                        end, ESPColors.Door)
                    end)
                end)
            else
                RunLoops:UnbindFromHeartbeat("DoorESP")
                clearESPBucket("Door")
            end
        end
    })

    RenderPanel.CreateOptionsButton({
        Name = "Exit ESP",
        Function = function(callback)
            if callback then
                RunLoops:BindToHeartbeat("ExitESP", function()
                    if not readyAction("ExitESPTick", 0.15) then return end
                    pcall(function()
                        updateESPBucket("Exit", getExits(), function(instance)
                            return buildWorldESPText("Exit", instance)
                        end, ESPColors.Exit)
                    end)
                end)
            else
                RunLoops:UnbindFromHeartbeat("ExitESP")
                clearESPBucket("Exit")
            end
        end
    })

    RenderPanel.CreateOptionsButton({
        Name = "Beartrap ESP",
        Function = function(callback)
            if callback then
                RunLoops:BindToHeartbeat("BeartrapESP", function()
                    if not readyAction("BeartrapESPTick", 0.15) then return end
                    pcall(function()
                        updateESPBucket("Beartrap", getBeartraps(), function(instance)
                            return buildWorldESPText("Beartrap", instance)
                        end, ESPColors.Beartrap)
                    end)
                end)
            else
                RunLoops:UnbindFromHeartbeat("BeartrapESP")
                clearESPBucket("Beartrap")
            end
        end
    })

    RenderPanel.CreateOptionsButton({
        Name = "Ennard Minions ESP",
        Function = function(callback)
            if callback then
                RunLoops:BindToHeartbeat("EnnardMinionsESP", function()
                    if not readyAction("EnnardESPTick", 0.15) then return end
                    pcall(function()
                        updateESPBucket("EnnardMinion", getEnnardMinions(), function(instance)
                            return buildWorldESPText("Ennard Minion", instance)
                        end, ESPColors.EnnardMinion)
                    end)
                end)
            else
                RunLoops:UnbindFromHeartbeat("EnnardMinionsESP")
                clearESPBucket("EnnardMinion")
            end
        end
    })

    RenderPanel.CreateOptionsButton({
        Name = "Objective ESP",
        Function = function(callback)
            if callback then
                RunLoops:BindToHeartbeat("ObjectiveESP", function()
                    if not readyAction("ObjectiveESPTick", 0.15) then return end
                    pcall(function()
                        updateESPBucket("Objective", getObjectives(), function(instance)
                            return buildWorldESPText("Objective", instance)
                        end, ESPColors.Objective)
                    end)
                end)
            else
                RunLoops:UnbindFromHeartbeat("ObjectiveESP")
                clearESPBucket("Objective")
            end
        end
    })

    RenderPanel.CreateOptionsButton({
        Name = "Hitbox Viewer",
        Function = function(callback)
            safeSetAttribute(lplr, "ShowHitboxes", callback and true or (SavedStates.PlayerAttributes.ShowHitboxes ~= nil and SavedStates.PlayerAttributes.ShowHitboxes or false))
        end
    })
end)

runcode(function()
    local AutoPanel = lib.Registry.worldPanel.API

    AutoPanel.CreateOptionsButton({
        Name = "Auto Shake",
        Function = function(callback)
            if callback then
                RunLoops:BindToHeartbeat("AutoShake", function()
                    if not IsAlive() then return end
                    if not readyAction("AutoShake", 0.08) then return end
                    if not activateVisibleGuiButton({"shake", "wiggle", "struggle"}) then
                        local prompt = findPromptInMap({"shake", "wiggle", "struggle"}, 20)
                        if prompt then firePrompt(prompt) end
                    end
                end)
            else
                RunLoops:UnbindFromHeartbeat("AutoShake")
            end
        end
    })

    AutoPanel.CreateOptionsButton({
        Name = "Fast Item Pickup",
        Function = function(callback)
            if callback then
                RunLoops:BindToHeartbeat("FastItemPickup", function()
                    if not IsAlive() or isLocalKiller() then return end
                    if not readyAction("FastItemPickup", 0.12) then return end

                    local target = getClosestInteractiveTarget(getBatteries(), {"pickup", "take", "grab", "collect", "battery", "fuse"}, 16)
                    if target then
                        tryInteractWithTarget(target, {"pickup", "take", "grab", "collect", "battery", "fuse"})
                        return
                    end

                    local prompt, promptDistance = findPromptInMap({"pickup", "take", "grab", "collect", "battery", "fuse"}, 14)
                    if prompt and promptDistance <= 14 then
                        firePrompt(prompt)
                    end
                end)
            else
                RunLoops:UnbindFromHeartbeat("FastItemPickup")
            end
        end
    })

    AutoPanel.CreateOptionsButton({
        Name = "Auto Repair Generators",
        Function = function(enabled)
            if enabled then
                RunLoops:BindToHeartbeat("AutoRepairGenerators", function()
                    if not IsAlive() or isLocalKiller() then return end

                    local _, generatorMain, event = getGeneratorPanel()
                    if not (generatorMain and isGuiChainVisible(generatorMain)) then
                        return
                    end

                    if not readyAction("AutoRepairGeneratorsSolve", 0.05) then return end

                    if event then
                        event:FireServer({
                            Wires = true,
                            Switches = true,
                            Lever = true
                        })
                    end

                    local char = RuntimeState.Character
                    if char then
                        local max = safeGetAttribute(char, "MaxStamina") or safeGetAttribute(char, "StaminaMax") or 100

                        if safeGetAttribute(char, "Stamina") ~= max then
                            safeSetAttribute(char, "Stamina", max)
                        end
                    end
                end)
            else
                RunLoops:UnbindFromHeartbeat("AutoRepairGenerators")
            end
        end
    })

    AutoPanel.CreateOptionsButton({
        Name = "Anti Springtrap Traps",
        Function = function(callback)
            if callback then
                RunLoops:BindToHeartbeat("AntiSpringtrapTraps", function()
                    if not IsAlive() or isLocalKiller() then return end
                    if not readyAction("AntiSpringtrapTraps", 0.1) then return end
                    local closestTrap, closestDist = getClosestFromList(getSpringtrapTraps(), 20)
                    if closestTrap then
                        for _, d in ipairs(closestTrap:GetDescendants()) do
                            if d:IsA("BasePart") then neutralizeTrapPart(d) end
                        end
                        if closestDist <= 6 and RuntimeState.RootPart then
                            RuntimeState.RootPart.CFrame = RuntimeState.RootPart.CFrame + Vector3.new(0, 4, 0)
                        end
                    end
                end)
            else
                RunLoops:UnbindFromHeartbeat("AntiSpringtrapTraps")
                restoreTrapParts()
            end
        end
    })
end)

runcode(function()
    local MiscPanel = lib.Registry.miscPanel.API
    local CreditsButton

    MiscPanel.CreateOptionsButton({
        Name = "Killer Distance HUD",
        Function = function(callback)
            if callback then
                RunLoops:BindToHeartbeat("KillerDistanceHUD", function()
                    pcall(function()
                        local label = ensureHudLabel()
                        if not label then return end
                        
                        local killer, distance = getClosestKiller(250)
                        
                        if killer and distance and distance < math.huge then
                            label.Text = "Killer Distance: " .. math.floor(distance) .. " studs"
                            label.TextColor3 = distance <= 20 and Color3.fromRGB(255, 90, 90) or Color3.fromRGB(255, 255, 255)
                        else
                            label.Text = "Killer Distance: none"
                            label.TextColor3 = Color3.fromRGB(255, 255, 255)
                        end
                    end)
                end)
            else
                RunLoops:UnbindFromHeartbeat("KillerDistanceHUD")
                pcall(destroyHudLabel)
            end
        end
    })

    MiscPanel.CreateOptionsButton({
        Name = "Auto Emote Player",
        Function = function(callback)
            if callback then
                RunLoops:BindToHeartbeat("AutoEmotePlayer", function()
                    pcall(function()
                        if not readyAction("AutoEmotePlayer", 10) then return end
                        if IsAlive() and RuntimeState.RootPart  and RuntimeState.RootPart.AssemblyLinearVelocity  and RuntimeState.RootPart.AssemblyLinearVelocity.Magnitude <= 2  and not safeGetAttribute(RuntimeState.Character, "Stun", false)  then
                            playRandomEmote()
                        end
                    end)
                end)
            else
                RunLoops:UnbindFromHeartbeat("AutoEmotePlayer")
            end
        end
    })

    CreditsButton = MiscPanel.CreateOptionsButton({
        Name = "Credits",
        ExtraText = "made by xzyn",
        NoSave = true,
        Function  = function(callback)
            if callback then
                safeNotify("Made by xzyn")
                task.defer(function()
                    if CreditsButton and CreditsButton.Enabled then
                        CreditsButton.Toggle()
                    end
                end)
            end
        end
    })
end)
