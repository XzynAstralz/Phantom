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
    Tool = nil,
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
    Lookup = {},
}
local GeneratorSolverPayloads = {
    {Wires = true, Switches = true, Lever = true},
    {Wires = true, Switches = true, Levers = true},
    {Wire = true, Switch = true, Lever = true},
    {Action = "Wires"},
    {Action = "Switches"},
    {Action = "Lever"},
}

local PlayerUtility = phantom.module:Load("utility") or loadstring(readfile("Phantom/lib/Utility.lua"))()

local modulesFolder = ReplicatedStorage:FindFirstChild("Modules")

local toLower = function(v) return string.lower(tostring(v or "")) end

local notify = function(text) pcall(notification, text) end

local getDesc = function(instance)
    if not instance then return {} end
    local ok, r = pcall(function() return instance:GetDescendants() end)
    return ok and r or {}
end

local disconnect = function(key)
    local c = Connections[key]
    if c then c:Disconnect(); Connections[key] = nil end
end

local setAttr = function(instance, attr, value)
    if not instance then return false end
    return pcall(function() instance:SetAttribute(attr, value) end)
end

local getAttr = function(instance, attr, fallback)
    if not instance then return fallback end
    local ok, r = pcall(function() return instance:GetAttribute(attr) end)
    return (ok and r ~= nil) and r or fallback
end

local hasTag = function(instance, tagName)
    if not instance then return false end
    local ok, r = pcall(function() return instance:HasTag(tagName) end)
    if ok then return r end
    local ok2, r2 = pcall(function() return CollectionService:HasTag(instance, tagName) end)
    return ok2 and r2 or false
end

local removeTag = function(instance, tagName)
    if not instance then return end
    if not pcall(function() instance:RemoveTag(tagName) end) then
        pcall(function() CollectionService:RemoveTag(instance, tagName) end)
    end
end

local getPart
getPart = function(instance)
    if not instance then return nil end

    if instance:IsA("ProximityPrompt") then
        return getPart(instance.Parent)
    end

    if instance:IsA("BasePart") or instance:IsA("MeshPart") then
        return instance
    end

    if instance:IsA("Attachment") then
        return (instance.Parent and instance.Parent:IsA("BasePart")) and instance.Parent or nil
    end

    if instance:IsA("Model") then
        return instance.PrimaryPart or  instance:FindFirstChild("Root") or instance:FindFirstChild("HumanoidRootPart") or instance:FindFirstChildWhichIsA("BasePart", true)
    end

    return nil
end

local createEntryState = function()
    return {
        Entries = {},
        Lookup = {},
    }
end

local clearEntryState = function(state)
    table.clear(state.Entries)
    table.clear(state.Lookup)
end

local addEntry = function(state, instance)
    if not instance then return false end
    local count = state.Lookup[instance] or 0
    state.Lookup[instance] = count + 1
    if count == 0 then
        state.Entries[#state.Entries + 1] = instance
        return true
    end
    return false
end

local removeEntry = function(state, instance)
    local count = state.Lookup[instance]
    if not count then return false end
    if count > 1 then
        state.Lookup[instance] = count - 1
        return false
    end
    state.Lookup[instance] = nil
    for i = #state.Entries, 1, -1 do
        if state.Entries[i] == instance then
            table.remove(state.Entries, i)
            break
        end
    end
    return true
end

local disconnectConnections = function(connectionTable)
    for key, connection in pairs(connectionTable) do
        if connection then
            connection:Disconnect()
        end
        connectionTable[key] = nil
    end
end

local compactLower = function(value)
    return (toLower(value):gsub("%s+", ""))
end

local nameHasKeyword = function(name, keywords)
    for _, keyword in ipairs(keywords or {}) do
        if name:find(keyword, 1, true) then
            return true
        end
    end
    return false
end

local matchesClasses = function(instance, classNames)
    if not classNames then return true end
    for _, className in ipairs(classNames) do
        if instance:IsA(className) then
            return true
        end
    end
    return false
end

local createContainerMatcher = function(tokens, exactMatch, classNames)
    local compactTokens = {}
    for _, token in ipairs(tokens or {}) do
        compactTokens[#compactTokens + 1] = compactLower(token)
    end
    return function(instance)
        if not matchesClasses(instance, classNames or {"Folder", "Model"}) then
            return false
        end
        local name = compactLower(instance.Name)
        for _, token in ipairs(compactTokens) do
            if exactMatch then
                if name == token then
                    return true
                end
            elseif name:find(token, 1, true) then
                return true
            end
        end
        return false
    end
end

local createFallbackMatcher = function(keywords, classNames, validator)
    return function(instance)
        if not matchesClasses(instance, classNames or {"Model", "BasePart", "Folder"}) then
            return false
        end
        local name = toLower(instance.Name)
        if not nameHasKeyword(name, keywords) then
            return false
        end
        return not validator or validator(instance, name)
    end
end

local createTrackedGroup = function(containerMatcher, fallbackMatcher)
    return {
        ContainerMatcher = containerMatcher,
        FallbackMatcher = fallbackMatcher,
        Containers = {},
        Primary = createEntryState(),
        Fallback = createEntryState(),
    }
end

local CharacterPartCache = createEntryState()
local CharacterConnections = {}
local PlayerFolderCache = {
    Root = nil,
    RootConnections = {},
    Survivor = createEntryState(),
    Killer = createEntryState(),
    RefreshQueued = false,
}
PlayerFolderCache.Survivor.Folder = nil
PlayerFolderCache.Survivor.Connections = {}
PlayerFolderCache.Killer.Folder = nil
PlayerFolderCache.Killer.Connections = {}

local MapCache = {
    Root = nil,
    MapsFolder = nil,
    Connections = {},
    RootConnections = {},
    RefreshQueued = false,
    Groups = {
        Generators = createTrackedGroup(
            createContainerMatcher({"Generators"})
        ),
        FuseBoxes = createTrackedGroup(
            createContainerMatcher({"FuseBoxes", "Fuse Boxes"})
        ),
        Batteries = createTrackedGroup(
            createContainerMatcher({"Batteries"})
        ),
        Exits = createTrackedGroup(
            createContainerMatcher({"Escapes"})
        ),
        Objectives = createTrackedGroup(
            createContainerMatcher({"Points", "GenPoints", "FusePoints", "AnnouncementPoints"}, true, {"Folder"}),
            nil
        ),
        Beartrap = createTrackedGroup(
            nil,
            createFallbackMatcher({"beartrap", "bear trap"}, {"Model", "BasePart"}, function(_, name)
                return not name:find("spring", 1, true)
            end)
        ),
        Springtrap = createTrackedGroup(
            nil,
            createFallbackMatcher({"springtrap", "spring trap"}, {"Model", "BasePart"}, function(instance)
                return getPart(instance) ~= nil
            end)
        ),
        EnnardMinion = createTrackedGroup(
            nil,
            createFallbackMatcher({"minion", "ennard"}, {"Model"}, function(instance, name)
                return name:find("minion", 1, true) or (name:find("ennard", 1, true) and not instance:FindFirstChildOfClass("Humanoid"))
            end)
        ),
    },
}

local IgnoreCache = {
    Root = nil,
    RootConnections = {},
    TrapFolder = nil,
    TrapConnections = {},
    Beartraps = createEntryState(),
    Springtraps = createEntryState(),
    Minions = createEntryState(),
    RefreshQueued = false,
}

local InfiniteStaminaState = {
    Enabled = false,
    Character = nil,
    Map = nil,
    LastMax = 100,
}

local refreshPlayerFolderCache
local refreshMapTracker
local refreshIgnoreTracker
local queuePlayerFolderRefresh
local queueMapRefresh
local queueIgnoreRefresh
local bindRuntimeCharacter

local bindTrackedFolder = function(state, folder)
    if state.Folder == folder then return end
    disconnectConnections(state.Connections)
    state.Folder = folder
    clearEntryState(state)
    if not folder then return end
    for _, child in ipairs(folder:GetChildren()) do
        addEntry(state, child)
    end
    state.Connections.ChildAdded = folder.ChildAdded:Connect(function(child)
        addEntry(state, child)
    end)
    state.Connections.ChildRemoved = folder.ChildRemoved:Connect(function(child)
        removeEntry(state, child)
    end)
    state.Connections.AncestryChanged = folder.AncestryChanged:Connect(function(_, parent)
        if not parent or folder.Parent ~= PlayerFolderCache.Root then
            queuePlayerFolderRefresh()
        end
    end)
end

queuePlayerFolderRefresh = function()
    if PlayerFolderCache.RefreshQueued then return end
    PlayerFolderCache.RefreshQueued = true
    task.defer(function()
        PlayerFolderCache.RefreshQueued = false
        refreshPlayerFolderCache(true)
    end)
end

refreshPlayerFolderCache = function(force)
    local root = Workspace:FindFirstChild("PLAYERS")
    if force or PlayerFolderCache.Root ~= root then
        disconnectConnections(PlayerFolderCache.RootConnections)
        PlayerFolderCache.Root = root
        if root then
            PlayerFolderCache.RootConnections.ChildAdded = root.ChildAdded:Connect(function(child)
                if child.Name == "ALIVE" or child.Name == "KILLER" then
                    queuePlayerFolderRefresh()
                end
            end)
            PlayerFolderCache.RootConnections.ChildRemoved = root.ChildRemoved:Connect(function(child)
                if child.Name == "ALIVE" or child.Name == "KILLER" then
                    queuePlayerFolderRefresh()
                end
            end)
            PlayerFolderCache.RootConnections.AncestryChanged = root.AncestryChanged:Connect(function(_, parent)
                if not parent then
                    queuePlayerFolderRefresh()
                end
            end)
        end
    end
    bindTrackedFolder(PlayerFolderCache.Survivor, root and root:FindFirstChild("ALIVE") or nil)
    bindTrackedFolder(PlayerFolderCache.Killer, root and root:FindFirstChild("KILLER") or nil)
    return root
end

local resolveMapRoot = function()
    local mapsFolder = Workspace:FindFirstChild("MAPS")
    if mapsFolder then
        local gameMap = mapsFolder:FindFirstChild("GAME MAP")
        if gameMap then
            return gameMap, mapsFolder
        end
    end
    for _, child in ipairs(Workspace:GetChildren()) do
        if child:IsA("Model") and (child.Name:find("MAP", 1, true) or child.Name:find("Game", 1, true)) then
            return child, mapsFolder
        end
    end
    return nil, mapsFolder
end

local detachGroupContainer
local attachGroupContainer

local clearTrackedGroup = function(group)
    local containers = {}
    for container in pairs(group.Containers) do
        containers[#containers + 1] = container
    end
    for _, container in ipairs(containers) do
        detachGroupContainer(group, container)
    end
    clearEntryState(group.Primary)
    clearEntryState(group.Fallback)
end

detachGroupContainer = function(group, container)
    local state = group.Containers[container]
    if not state then return end
    group.Containers[container] = nil
    disconnectConnections(state.Connections)
    for child in pairs(state.Children) do
        removeEntry(group.Primary, child)
        state.Children[child] = nil
    end
end

attachGroupContainer = function(group, container)
    if group.Containers[container] then return end
    local state = {
        Connections = {},
        Children = {},
    }
    group.Containers[container] = state

    local trackChild = function(child)
        if state.Children[child] then return end
        state.Children[child] = true
        addEntry(group.Primary, child)
    end

    local untrackChild = function(child)
        if not state.Children[child] then return end
        state.Children[child] = nil
        removeEntry(group.Primary, child)
    end

    for _, child in ipairs(container:GetChildren()) do
        trackChild(child)
    end

    state.Connections.ChildAdded = container.ChildAdded:Connect(trackChild)
    state.Connections.ChildRemoved = container.ChildRemoved:Connect(untrackChild)
    state.Connections.AncestryChanged = container.AncestryChanged:Connect(function(_, parent)
        if not parent then
            detachGroupContainer(group, container)
        end
    end)
end

local handleMapDescendantAdded = function(descendant)
    if descendant:IsA("ProximityPrompt") then
        addEntry(PromptCache, descendant)
    end
    for _, group in pairs(MapCache.Groups) do
        local isContainer = group.ContainerMatcher and group.ContainerMatcher(descendant) or false
        if isContainer then
            attachGroupContainer(group, descendant)
        elseif group.FallbackMatcher and group.FallbackMatcher(descendant) then
            addEntry(group.Fallback, descendant)
        end
    end
end

local handleMapDescendantRemoving = function(descendant)
    if descendant:IsA("ProximityPrompt") then
        removeEntry(PromptCache, descendant)
    end
    for _, group in pairs(MapCache.Groups) do
        if group.Containers[descendant] then
            detachGroupContainer(group, descendant)
        elseif group.Fallback.Lookup[descendant] then
            removeEntry(group.Fallback, descendant)
        end
    end
end

local bindMapsFolderTracker = function(folder)
    if MapCache.MapsFolder == folder then return end
    disconnectConnections(MapCache.RootConnections)
    MapCache.MapsFolder = folder
    if not folder then return end
    MapCache.RootConnections.ChildAdded = folder.ChildAdded:Connect(function()
        queueMapRefresh()
    end)
    MapCache.RootConnections.ChildRemoved = folder.ChildRemoved:Connect(function()
        queueMapRefresh()
    end)
    MapCache.RootConnections.AncestryChanged = folder.AncestryChanged:Connect(function(_, parent)
        if not parent then
            queueMapRefresh()
        end
    end)
end

queueMapRefresh = function()
    if MapCache.RefreshQueued then return end
    MapCache.RefreshQueued = true
    task.defer(function()
        MapCache.RefreshQueued = false
        refreshMapTracker(true)
    end)
end

refreshMapTracker = function(force)
    local map, mapsFolder = resolveMapRoot()
    bindMapsFolderTracker(mapsFolder)
    if force or MapCache.Root ~= map then
        disconnectConnections(MapCache.Connections)
        MapCache.Root = map
        PromptCache.Map = map
        clearEntryState(PromptCache)
        for _, group in pairs(MapCache.Groups) do
            clearTrackedGroup(group)
        end
        if map then
            for _, descendant in ipairs(map:GetDescendants()) do
                handleMapDescendantAdded(descendant)
            end
            MapCache.Connections.DescendantAdded = map.DescendantAdded:Connect(handleMapDescendantAdded)
            MapCache.Connections.DescendantRemoving = map.DescendantRemoving:Connect(handleMapDescendantRemoving)
            MapCache.Connections.AncestryChanged = map.AncestryChanged:Connect(function(_, parent)
                if not parent then
                    queueMapRefresh()
                end
            end)
        end
    end
    return map
end

local isBeartrapName = function(name)
    return name:find("bear", 1, true) and not name:find("spring", 1, true)
end

local isSpringtrapName = function(name)
    return name:find("spring", 1, true) ~= nil
end

local bindTrapFolder = function(folder)
    if IgnoreCache.TrapFolder == folder then return end
    disconnectConnections(IgnoreCache.TrapConnections)
    IgnoreCache.TrapFolder = folder
    clearEntryState(IgnoreCache.Beartraps)
    clearEntryState(IgnoreCache.Springtraps)
    if not folder then return end

    local classifyTrap = function(instance, present)
        local name = toLower(instance.Name)
        if isBeartrapName(name) then
            if present then addEntry(IgnoreCache.Beartraps, instance) else removeEntry(IgnoreCache.Beartraps, instance) end
        end
        if isSpringtrapName(name) then
            if present then addEntry(IgnoreCache.Springtraps, instance) else removeEntry(IgnoreCache.Springtraps, instance) end
        end
    end

    for _, child in ipairs(folder:GetChildren()) do
        classifyTrap(child, true)
    end

    IgnoreCache.TrapConnections.ChildAdded = folder.ChildAdded:Connect(function(child)
        classifyTrap(child, true)
    end)
    IgnoreCache.TrapConnections.ChildRemoved = folder.ChildRemoved:Connect(function(child)
        classifyTrap(child, false)
    end)
    IgnoreCache.TrapConnections.AncestryChanged = folder.AncestryChanged:Connect(function(_, parent)
        if not parent or folder.Parent ~= IgnoreCache.Root then
            queueIgnoreRefresh()
        end
    end)
end

queueIgnoreRefresh = function()
    if IgnoreCache.RefreshQueued then return end
    IgnoreCache.RefreshQueued = true
    task.defer(function()
        IgnoreCache.RefreshQueued = false
        refreshIgnoreTracker(true)
    end)
end

refreshIgnoreTracker = function(force)
    local root = Workspace:FindFirstChild("IGNORE")
    if force or IgnoreCache.Root ~= root then
        disconnectConnections(IgnoreCache.RootConnections)
        IgnoreCache.Root = root
        clearEntryState(IgnoreCache.Minions)
        if root then
            for _, descendant in ipairs(root:GetDescendants()) do
                if descendant:IsA("Model") then
                    local name = toLower(descendant.Name)
                    if name:find("minion", 1, true) or (name:find("ennard", 1, true) and not descendant:FindFirstChildOfClass("Humanoid")) then
                        addEntry(IgnoreCache.Minions, descendant)
                    end
                end
            end
            IgnoreCache.RootConnections.ChildAdded = root.ChildAdded:Connect(function(child)
                if child.Name == "Trap" then
                    bindTrapFolder(root:FindFirstChild("Trap"))
                end
            end)
            IgnoreCache.RootConnections.ChildRemoved = root.ChildRemoved:Connect(function(child)
                if child.Name == "Trap" then
                    bindTrapFolder(root:FindFirstChild("Trap"))
                end
            end)
            IgnoreCache.RootConnections.DescendantAdded = root.DescendantAdded:Connect(function(descendant)
                if descendant:IsA("Model") then
                    local name = toLower(descendant.Name)
                    if name:find("minion", 1, true) or (name:find("ennard", 1, true) and not descendant:FindFirstChildOfClass("Humanoid")) then
                        addEntry(IgnoreCache.Minions, descendant)
                    end
                end
            end)
            IgnoreCache.RootConnections.DescendantRemoving = root.DescendantRemoving:Connect(function(descendant)
                if descendant:IsA("Model") then
                    removeEntry(IgnoreCache.Minions, descendant)
                end
            end)
            IgnoreCache.RootConnections.AncestryChanged = root.AncestryChanged:Connect(function(_, parent)
                if not parent then
                    queueIgnoreRefresh()
                end
            end)
        end
    end
    bindTrapFolder(root and root:FindFirstChild("Trap") or nil)
    return root
end

bindRuntimeCharacter = function(character, useFallback)
    disconnectConnections(CharacterConnections)
    clearEntryState(CharacterPartCache)

    RuntimeState.Character = character
    if not RuntimeState.Character and useFallback ~= false then
        RuntimeState.Character = lplr.Character or PlayerUtility.lplrCharacter
    end

    RuntimeState.Humanoid = nil
    RuntimeState.RootPart = nil
    RuntimeState.Tool = nil

    local activeCharacter = RuntimeState.Character
    if not activeCharacter then return end

    RuntimeState.Humanoid = activeCharacter:FindFirstChildOfClass("Humanoid") or PlayerUtility.lplrHumanoid
    RuntimeState.RootPart = activeCharacter:FindFirstChild("HumanoidRootPart") or activeCharacter:FindFirstChild("Root") or activeCharacter:FindFirstChildWhichIsA("BasePart", true) or PlayerUtility.lplrRoot
    RuntimeState.Tool = activeCharacter:FindFirstChildOfClass("Tool")

    for _, descendant in ipairs(activeCharacter:GetDescendants()) do
        if descendant:IsA("BasePart") then
            addEntry(CharacterPartCache, descendant)
        end
    end

    CharacterConnections.ChildAdded = activeCharacter.ChildAdded:Connect(function(child)
        if child:IsA("Humanoid") then
            RuntimeState.Humanoid = child
        elseif child:IsA("Tool") then
            RuntimeState.Tool = child
        end
    end)
    CharacterConnections.ChildRemoved = activeCharacter.ChildRemoved:Connect(function(child)
        if child == RuntimeState.Humanoid then
            RuntimeState.Humanoid = activeCharacter:FindFirstChildOfClass("Humanoid") or PlayerUtility.lplrHumanoid
        elseif child == RuntimeState.Tool then
            RuntimeState.Tool = activeCharacter:FindFirstChildOfClass("Tool")
        end
    end)
    CharacterConnections.DescendantAdded = activeCharacter.DescendantAdded:Connect(function(descendant)
        if descendant:IsA("BasePart") then
            addEntry(CharacterPartCache, descendant)
            if descendant.Name == "HumanoidRootPart" or descendant.Name == "Root" or not RuntimeState.RootPart then
                RuntimeState.RootPart = descendant
            end
        end
    end)
    CharacterConnections.DescendantRemoving = activeCharacter.DescendantRemoving:Connect(function(descendant)
        if descendant:IsA("BasePart") then
            removeEntry(CharacterPartCache, descendant)
            if descendant == RuntimeState.RootPart then
                RuntimeState.RootPart = activeCharacter:FindFirstChild("HumanoidRootPart") or activeCharacter:FindFirstChild("Root") or activeCharacter:FindFirstChildWhichIsA("BasePart", true) or PlayerUtility.lplrRoot
            end
        end
    end)
    CharacterConnections.AncestryChanged = activeCharacter.AncestryChanged:Connect(function(_, parent)
        if not parent then
            bindRuntimeCharacter(nil, false)
        end
    end)
end

Connections.WorkspaceChildAdded = Workspace.ChildAdded:Connect(function(child)
    if child.Name == "PLAYERS" then
        queuePlayerFolderRefresh()
    elseif child.Name == "MAPS" or (child:IsA("Model") and (child.Name:find("MAP", 1, true) or child.Name:find("Game", 1, true))) then
        queueMapRefresh()
    elseif child.Name == "IGNORE" then
        queueIgnoreRefresh()
    end
end)

Connections.WorkspaceChildRemoved = Workspace.ChildRemoved:Connect(function(child)
    if child.Name == "PLAYERS" then
        queuePlayerFolderRefresh()
    elseif child.Name == "MAPS" or (child:IsA("Model") and (child.Name:find("MAP", 1, true) or child.Name:find("Game", 1, true))) then
        queueMapRefresh()
    elseif child.Name == "IGNORE" then
        queueIgnoreRefresh()
    end
end)

Connections.CharacterAdded = lplr.CharacterAdded:Connect(function(character)
    bindRuntimeCharacter(character)
end)
Connections.CharacterRemoving = lplr.CharacterRemoving:Connect(function(character)
    if RuntimeState.Character == character then
        bindRuntimeCharacter(nil, false)
    end
end)

bindRuntimeCharacter(lplr.Character or PlayerUtility.lplrCharacter)
refreshPlayerFolderCache(true)
refreshMapTracker(true)
refreshIgnoreTracker(true)

local distTo = function(instance)
    local root = RuntimeState.RootPart or PlayerUtility.lplrRoot
    local target = getPart(instance)
    if not (root and target) then return math.huge end
    return (root.Position - target.Position).Magnitude
end

local getMap = function()
    return MapCache.Root or refreshMapTracker()
end

local getTaskList = function(folderName, keywords)
    local group = MapCache.Groups[folderName]
    if group then
        if #group.Primary.Entries > 0 then
            return group.Primary.Entries
        end
        return group.Fallback.Entries
    end

    local map = getMap()
    if not map then return {} end
    local results, seen = {}, {}
    local addIfNew = function(obj)
        if obj and not seen[obj] then seen[obj] = true; results[#results + 1] = obj end
    end
    local folder = map:FindFirstChild(folderName)
    if folder then
        for _, child in ipairs(folder:GetChildren()) do addIfNew(child) end
        if #results > 0 then return results end
    end
    for _, desc in ipairs(map:GetDescendants()) do
        if (desc:IsA("Folder") or desc:IsA("Model")) and
           string.find(string.lower(desc.Name), string.lower(folderName), 1, true) then
            for _, child in ipairs(desc:GetChildren()) do addIfNew(child) end
        end
    end
    if #results > 0 then return results end
    if keywords then
        for _, desc in ipairs(map:GetDescendants()) do
            if desc:IsA("Model") or desc:IsA("BasePart") or desc:IsA("Folder") then
                local n = string.lower(desc.Name)
                for _, kw in ipairs(keywords) do
                    if string.find(n, kw, 1, true) then addIfNew(desc); break end
                end
            end
        end
    end
    return results
end

local getMapPrompts = function()
    local map = getMap()
    if not map then
        PromptCache.Map = nil
        clearEntryState(PromptCache)
        return {}
    end
    if PromptCache.Map ~= map then
        refreshMapTracker(true)
    end
    return PromptCache.Entries
end

local getDoors = function()
    local source = getTaskList("Doors", {"door"})

    local results, seen = {}, {}
    
    local addDoor = function(obj)
        if not obj or seen[obj] then return end
        local n = string.lower(obj.Name)
        if n:find("locked") or n == "lockeddoors" then return end
        seen[obj] = true
        results[#results + 1] = obj
    end

    for _, door in ipairs(source) do
        addDoor(door)
    end

    local map = getMap()
    if map and map.Doors then
        local doorsFolder = map.Doors
        for i, door in ipairs(doorsFolder:GetChildren()) do
            addDoor(door)
        end
        local doubleDoorsFolder = doorsFolder:FindFirstChild("Double Doors")
        if doubleDoorsFolder then
            for _, doubleDoor in ipairs(doubleDoorsFolder:GetChildren()) do
                addDoor(doubleDoor)
            end
        end
    end

    local ignoreFolder = workspace:FindFirstChild("IGNORE")
    if ignoreFolder then
        for _, door in ipairs(ignoreFolder:GetChildren()) do
            local doorName = string.lower(door.Name)
            if doorName:match("^door%d*$") then
                addDoor(door)
            end
        end
    end

    local gameMapFolder = getMap()
    if gameMapFolder then
        local doubleDoors = gameMapFolder:FindFirstChild("Double Doors")
        if doubleDoors then
            for _, doubleDoor in ipairs(doubleDoors:GetChildren()) do
                local typesFolder = doubleDoor:FindFirstChild("Types")
                if typesFolder then
                    local subfolder1 = typesFolder:FindFirstChild("1")
                    if subfolder1 then
                        local door1 = subfolder1:FindFirstChild("Door1")
                        if door1 then
                            addDoor(door1)
                        end
                        local door2 = subfolder1:FindFirstChild("Door2")
                        if door2 then
                            addDoor(door2)
                        end
                    end
                end
            end
        end
    end

    return results
end

local getGenerators = function() return getTaskList("Generators", {"generator", "gen"}) end
local getFuseBoxes = function() return getTaskList("FuseBoxes",  {"fuse", "fusebox"}) end
local getBatteries = function() return getTaskList("Batteries",  {"battery"}) end

local mapObjects = function(keywords, validator)
    local map = getMap()
    if not map then return {} end
    local results, seen = {}, {}
    for _, d in ipairs(map:GetDescendants()) do
        if d:IsA("Model") or d:IsA("BasePart") then
            local target = d:IsA("BasePart") and (d.Parent:IsA("Model") and d.Parent or d) or d
            if not seen[target] then
                local n = string.lower(target.Name)
                for _, kw in ipairs(keywords) do
                    if n:find(kw, 1, true) then
                        if not validator or validator(target) then
                            seen[target] = true; results[#results + 1] = target
                        end
                        break
                    end
                end
            end
        end
    end
    return results
end

local mergeLists = function(...)
    local merged, seen = {}, {}
    for _, list in ipairs({...}) do
        for _, entry in ipairs(list) do
            if entry and not seen[entry] then seen[entry] = true; merged[#merged + 1] = entry end
        end
    end
    return merged
end

local getObjectives = function()
    if not getMap() then return {} end
    return MapCache.Groups.Objectives.Primary.Entries
end

local getExits = function()
    return getTaskList("Exits", {"exit", "escape"})
end

local getBeartraps = function()
    if #IgnoreCache.Beartraps.Entries > 0 then
        return IgnoreCache.Beartraps.Entries
    end
    return MapCache.Groups.Beartrap.Fallback.Entries
end

local getSpringtrapTraps = function()
    if #IgnoreCache.Springtraps.Entries > 0 then
        return IgnoreCache.Springtraps.Entries
    end
    return MapCache.Groups.Springtrap.Fallback.Entries
end

local getEnnardMinions = function()
    if #IgnoreCache.Minions.Entries > 0 then
        return IgnoreCache.Minions.Entries
    end
    return MapCache.Groups.EnnardMinion.Fallback.Entries
end

local getPlayerFolders = function()
    if not PlayerFolderCache.Root and Workspace:FindFirstChild("PLAYERS") then
        refreshPlayerFolderCache(true)
    end
    return PlayerFolderCache.Survivor.Folder, PlayerFolderCache.Killer.Folder
end

local getSurvivorCharacters = function()
    local aliveFolder = getPlayerFolders()
    local out = {}
    if not aliveFolder then return out end
    for _, c in ipairs(PlayerFolderCache.Survivor.Entries) do
        if c ~= RuntimeState.Character and c.Parent == aliveFolder and PlayerUtility.IsAlive(Players:GetPlayerFromCharacter(c)) then
            out[#out + 1] = c
        end
    end
    return out
end

local getKillerCharacters = function()
    local _, killerFolder = getPlayerFolders()
    local out = {}
    if not killerFolder then return out end
    for _, c in ipairs(PlayerFolderCache.Killer.Entries) do
        if c ~= RuntimeState.Character and c.Parent == killerFolder and PlayerUtility.IsAlive(Players:GetPlayerFromCharacter(c)) then
            out[#out + 1] = c
        end
    end
    return out
end

local lkillr = function()
    local _, kf = getPlayerFolders()
    return RuntimeState.Character ~= nil and kf ~= nil and RuntimeState.Character.Parent == kf
end

local closestChar = function(characters, maxDistance, ignoreUndetectable)
    local best, bestDist = nil, maxDistance or math.huge
    for _, c in ipairs(characters) do
        local root = getPart(c)
        if root then
            local ok = not ignoreUndetectable or (not hasTag(c, "UNDETECTABLE") and not hasTag(c, "Imitation"))
            if ok then
                local d = distTo(root)
                if d < bestDist then best = c; bestDist = d end
            end
        end
    end
    return best, bestDist
end

local closestTarget = function(maxDist)
    local targets = lkillr() and getSurvivorCharacters() or getKillerCharacters()
    return closestChar(targets, maxDist, true)
end

local closestKiller = function(maxDist)
    return closestChar(getKillerCharacters(), maxDist, true)
end

local closestIn = function(list, maxDist, validator)
    local best, bestDist = nil, maxDist or math.huge
    for _, item in ipairs(list) do
        local part = getPart(item)
        if part and (not validator or validator(item)) then
            local d = distTo(part)
            if d < bestDist then best = item; bestDist = d end
        end
    end
    return best, bestDist
end

local promptOk = function(prompt, keywords)
    if not prompt or not prompt:IsA("ProximityPrompt") or not prompt.Enabled then return false end
    if not keywords or #keywords == 0 then return true end
    local blob = toLower(prompt.Name .. " " .. prompt.ActionText .. " " .. prompt.ObjectText)
    for _, kw in ipairs(keywords) do
        if blob:find(kw, 1, true) then return true end
    end
    return false
end

local findPrompt
findPrompt = function(instance, keywords)
    if not instance then return nil end
    if instance:IsA("ProximityPrompt") and promptOk(instance, keywords) then return instance end
    for _, d in ipairs(instance:GetDescendants()) do
        if d:IsA("ProximityPrompt") and promptOk(d, keywords) then return d end
    end
    return nil
end

local findMapPrompt = function(keywords, maxDist)
    local bestPrompt, bestDist = nil, maxDist or math.huge
    for _, d in ipairs(getMapPrompts()) do
        if d:IsA("ProximityPrompt") and promptOk(d, keywords) then
            local dist = distTo(d.Parent)
            if dist < bestDist then bestPrompt = d; bestDist = dist end
        end
    end
    return bestPrompt, bestDist
end

local firePrompt = function(prompt)
    if not prompt or not prompt.Enabled then return false end
    local holdDuration = math.max(prompt.HoldDuration or 0, 0.02)
    if fireproximityprompt then
        if pcall(function() fireproximityprompt(prompt, holdDuration + 0.02) end) then return true end
    end
    return pcall(function()
        prompt:InputHoldBegin()
        task.wait(holdDuration)
        prompt:InputHoldEnd()
    end)
end

local moveTo = function(instance, yOffset)
    local root = RuntimeState.RootPart or PlayerUtility.lplrRoot
    if not (root and instance) then return false end
    local part = getPart(instance)
    if not part then return false end
    root.CFrame = CFrame.lookAt(part.Position + Vector3.new(0, yOffset or 2.5, 0), part.Position)
    return true
end

local throttle = function(key, delay)
    local now = tick()
    local prev = RuntimeState.LastAction[key] or 0
    if now - prev >= delay then RuntimeState.LastAction[key] = now; return true end
    return false
end

local getTool = function()
    if RuntimeState.Tool and RuntimeState.Tool.Parent == RuntimeState.Character then
        return RuntimeState.Tool
    end
    if RuntimeState.Character then
        RuntimeState.Tool = RuntimeState.Character:FindFirstChildOfClass("Tool")
    end
    return RuntimeState.Tool
end

local fireChannels = function(root, keywords, ...)
    if not root then return false end
    local args = table.pack(...)
    for _, d in ipairs(root:GetDescendants()) do
        local n = toLower(d.Name)
        local match = false
        for _, kw in ipairs(keywords) do if n:find(kw, 1, true) then match = true; break end end
        if match then
            local ok = false
            if     d:IsA("RemoteEvent")      then ok = pcall(d.FireServer,   d, table.unpack(args, 1, args.n))
            elseif d:IsA("BindableEvent")    then ok = pcall(d.Fire,         d, table.unpack(args, 1, args.n))
            elseif d:IsA("RemoteFunction")   then ok = pcall(d.InvokeServer, d, table.unpack(args, 1, args.n))
            elseif d:IsA("BindableFunction") then ok = pcall(d.Invoke,       d, table.unpack(args, 1, args.n))
            end
            if ok then return true end
        end
    end
    return false
end

local setBlock = function(holding)
    if RuntimeState.Blocking == holding then return end
    RuntimeState.Blocking = holding
    local tool = getTool()
    if tool then fireChannels(tool, {"block", "guard", "parry"}, holding) end
    if holding then
        if mouse2press   then pcall(mouse2press)   end
    else
        if mouse2release then pcall(mouse2release) end
    end
end

local swing = function()
    local tool = getTool()
    if tool then
        pcall(function() tool:Activate() end)
        fireChannels(tool, {"swing", "attack", "slash", "hit"})
    end
    if mouse1click then
        pcall(mouse1click)
    elseif mouse1press and mouse1release then
        pcall(mouse1press)
        task.delay(0.03, function() pcall(mouse1release) end)
    end
end

local isDone = function(instance)
    for _, flag in ipairs({"Done","Completed","Fixed","Repaired","Powered","Opened","Open","Finished"}) do
        if getAttr(instance, flag, nil) == true then return true end
    end
    local p = getAttr(instance, "Progress", nil)
        or getAttr(instance, "Completion", nil)
        or getAttr(instance, "Percent", nil)
    return type(p) == "number" and p >= 100
end

local closestInteract = function(instances, keywords, maxDist)
    local best, bestDist = nil, maxDist or math.huge
    for _, instance in ipairs(instances or {}) do
        if instance and instance.Parent and not isDone(instance) then
            local prompt = findPrompt(instance, keywords) or findPrompt(instance)
            if prompt and prompt.Enabled then
                local dist = distTo(instance)
                if dist < bestDist then best = instance; bestDist = dist end
            end
        end
    end
    return best, bestDist
end

local interact = function(target, keywords)
    local prompt = findPrompt(target, keywords) or findPrompt(target)
    if not prompt or isDone(target) then return false end
    local maxActivationDistance = math.max((prompt.MaxActivationDistance or 0) + 1.5, 8)
    if distTo(target) > maxActivationDistance then
        moveTo(target, 2.5)
        task.delay(0.05, function() firePrompt(prompt) end)
        return true
    end
    return firePrompt(prompt)
end

local isPostEffect = function(i)
    return i:IsA("BlurEffect") or i:IsA("ColorCorrectionEffect") or i:IsA("BloomEffect")
        or i:IsA("SunRaysEffect") or i:IsA("DepthOfFieldEffect")
end

local shouldHideGuiEffect = function(i)
    local n = toLower(i.Name)
    return n:find("static",1,true) or n:find("vignette",1,true) or n:find("blur",1,true)
        or n:find("blood",1,true) or n:find("noise",1,true) or n:find("flash",1,true)
end

local applyFB = function()
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

local restoreFB = function()
    if not SavedStates.Fullbright then return end
    local fb = SavedStates.Fullbright
    Lighting.Brightness     = fb.Brightness
    Lighting.Ambient        = fb.Ambient
    Lighting.OutdoorAmbient = fb.OutdoorAmbient
    Lighting.ClockTime      = fb.ClockTime
    Lighting.FogEnd         = fb.FogEnd
    Lighting.GlobalShadows  = fb.GlobalShadows
    SavedStates.Fullbright  = nil
end

local restoreCollision = function()
    for part, prev in pairs(SavedStates.CharacterCollision) do
        if typeof(part) == "Instance" and part.Parent and part:IsA("BasePart") then
            part.CanCollide = prev
        end
    end
    table.clear(SavedStates.CharacterCollision)
end

local noCollide = function(character)
    for _, d in ipairs(CharacterPartCache.Entries) do
        if d:IsA("BasePart") then
            if SavedStates.CharacterCollision[d] == nil then
                SavedStates.CharacterCollision[d] = d.CanCollide
            end
            d.CanCollide = false
        end
    end
end

local restoreTraps = function()
    for part, state in pairs(SavedStates.TrapParts) do
        if typeof(part) == "Instance" and part.Parent and part:IsA("BasePart") then
            part.CanCollide   = state.CanCollide
            part.Transparency = state.Transparency
            pcall(function() part.CanTouch = state.CanTouch end)
        end
    end
    table.clear(SavedStates.TrapParts)
end

local defusePart = function(part)
    if not part or not part:IsA("BasePart") then return end
    if SavedStates.TrapParts[part] == nil then
        SavedStates.TrapParts[part] = {
            CanCollide   = part.CanCollide,
            CanTouch     = part.CanTouch,
            Transparency = part.Transparency,
        }
    end
    part.CanCollide   = false
    part.Transparency = math.max(part.Transparency, 0.55)
    pcall(function() part.CanTouch = false end)
end

local getHud = function()
    if RuntimeState.HudLabel and RuntimeState.HudLabel.Parent then return RuntimeState.HudLabel end
    local label = Instance.new("TextLabel")
    label.Name                   = "KillerDistanceHUD"
    label.AnchorPoint            = Vector2.new(0.5, 0)
    label.Position               = UDim2.new(0.5, 0, 0, 20)
    label.Size                   = UDim2.new(0, 280, 0, 38)
    label.BackgroundColor3       = Color3.fromRGB(15, 15, 15)
    label.BackgroundTransparency = 0.25
    label.BorderSizePixel        = 0
    label.Font                   = Enum.Font.GothamBold
    label.TextColor3             = Color3.fromRGB(255, 255, 255)
    label.TextSize               = 16
    label.TextStrokeTransparency = 0
    label.Text                   = "Killer Distance: waiting..."
    label.Parent                 = OverlayGui
    RuntimeState.HudLabel        = label
    return label
end

local removeHud = function()
    if RuntimeState.HudLabel then
        RuntimeState.HudLabel:Destroy()
        RuntimeState.HudLabel = nil
    end
end

local removeESP = function(entry)
    if entry.Highlight then entry.Highlight:Destroy() end
    if entry.Billboard then entry.Billboard:Destroy() end
end

local clearESP = function(name)
    for inst, entry in pairs(ESPCache[name]) do
        removeESP(entry)
        ESPCache[name][inst] = nil
    end
end

local clearAllESP = function()
    for name in pairs(ESPCache) do clearESP(name) end
end

local upsertESP = function(bucketName, instance, text, color)
    local part = getPart(instance)
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
local function updateESP(name, instances, textFn, color)
    ESPCache[name] = ESPCache[name] or {}
    local cache = ESPCache[name]

    local seen = {}

    for _, inst in ipairs(instances or {}) do
        if inst and inst.Parent then
            local part = getPart(inst)
            if part then
                if not MAX_DISTANCE or distTo(inst) <= MAX_DISTANCE then
                    local success, text = pcall(textFn, inst)
                    if success and text and text ~= "" then
                        seen[inst] = true
                        upsertESP(name, inst, text, color)
                    end
                end
            end
        end
    end

    for inst, entry in pairs(cache) do
        if not seen[inst] or not (inst and inst.Parent) then
            removeESP(entry)
            cache[inst] = nil
        end
    end
end

local function formatDist(instance)
    local d = distTo(instance)
    return d == math.huge and "?" or tostring(math.floor(d))
end

local function worldESP(prefix, instance)
    local progress = getAttr(instance, "Progress") or getAttr(instance, "Completion") or getAttr(instance, "Percent")

    local status = ""
    if type(progress) == "number" then
        status = string.format(" (%d%%)", math.floor(progress))
    elseif isDone(instance) then
        status = " [DONE]"
    end

    return string.format(
        "%s%s\n[%s studs]",
        prefix,
        status,
        formatDist(instance)
    )
end

local function playerESP(character, showRole, role, showHealth, showStamina)
    local plr      = Players:GetPlayerFromCharacter(character)
    local dispName = plr and plr.DisplayName or character.Name
    local lines    = {}
    table.insert(lines, showRole and (role .. ": " .. dispName) or dispName)
    if showHealth then
        local hum = character:FindFirstChildOfClass("Humanoid")
        table.insert(lines, "HP: " .. tostring(math.floor(hum and hum.Health or 0)))
    end
    if showStamina then
        table.insert(lines, "STA: " .. tostring(math.floor(getAttr(character, "Stamina", 0) or 0)))
    end
    return table.concat(lines, "\n")
end

local function clickGui(keywords)
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

local function guiVisible(instance)
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

local function clickGuiIn(root, keywords)
    if not root then return false end
    for _, d in ipairs(getDesc(root)) do
        if d:IsA("GuiButton") and guiVisible(d) then
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

local function fireChannel(channel, ...)
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
    if generatorMain and guiVisible(generatorMain) then
        if clickGuiIn(generatorMain, {"wire", "switch", "lever", "repair"}) then
            return true
        end
    end

    if event then
        for _, payload in ipairs(GeneratorSolverPayloads) do
            if fireChannel(event, payload) then
                return true
            end
        end
    end

    return false
end

local function getStaminaMax(character, fallback)
    return getAttr(character, "MaxStamina", nil)
        or getAttr(character, "StaminaMax", nil)
        or getAttr(character, "MaxSprint", nil)
        or fallback
        or 100
end

local function refillStamina(character, fallback)
    if not character then return nil end
    local max = getStaminaMax(character, fallback)
    if getAttr(character, "Stamina") ~= max then
        setAttr(character, "Stamina", max)
    end
    if getAttr(character, "Sprint") ~= max then
        setAttr(character, "Sprint", max)
    end
    if getAttr(character, "Sprinting", false) then
        setAttr(character, "Sprinting", false)
    end
    return max
end

local function resetInfiniteStaminaState()
    InfiniteStaminaState.Character = nil
    InfiniteStaminaState.Map = nil
    InfiniteStaminaState.LastMax = 100
end

local function applyInfiniteStamina()
    local character = RuntimeState.Character
    if not character or not PlayerUtility.lplrIsAlive then
        resetInfiniteStaminaState()
        return
    end

    local map = getMap()
    if InfiniteStaminaState.Character ~= character or InfiniteStaminaState.Map ~= map then
        InfiniteStaminaState.Character = character
        InfiniteStaminaState.Map = map
        InfiniteStaminaState.LastMax = 100
    end

    local max = refillStamina(character, InfiniteStaminaState.LastMax)
    InfiniteStaminaState.LastMax = max or InfiniteStaminaState.LastMax
end

local function closestInteract(instances, keywords, maxDist)
    local best, bestDist = nil, maxDist or math.huge
    for _, instance in ipairs(instances or {}) do
        if instance and instance.Parent and not isDone(instance) then
            local prompt = findPrompt(instance, keywords) or findPrompt(instance)
            if prompt and prompt.Enabled then
                local dist = distTo(instance)
                if dist < bestDist then
                    best = instance
                    bestDist = dist
                end
            end
        end
    end
    return best, bestDist
end

local function randEmote()
    local humanoid = RuntimeState.Humanoid or PlayerUtility.lplrHumanoid
    if not humanoid then return false end
    local emote = EMOTES[math.random(1, #EMOTES)]
    if pcall(function() humanoid:PlayEmote(emote) end) then return true end
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

    setBlock(false)
    restoreCollision()
    restoreTraps()
    restoreFB()
    clearAllESP()
    removeHud()

    if ScreenEffectConnections then
        for _, connection in ipairs(ScreenEffectConnections) do
            connection:Disconnect()
        end
        ScreenEffectConnections = nil
    end

    setAttr(lplr, "ShowHitboxes", SavedStates.PlayerAttributes.ShowHitboxes ~= nil and SavedStates.PlayerAttributes.ShowHitboxes or false)
    if SavedStates.PlayerAttributes.CameraShake ~= nil then
        setAttr(lplr, "CameraShake", SavedStates.PlayerAttributes.CameraShake)
    end

    disconnect("StunAlert")
    disconnect("WorkspaceChildAdded")
    disconnect("WorkspaceChildRemoved")
    disconnect("CharacterAdded")
    disconnect("CharacterRemoving")

    InfiniteStaminaState.Enabled = false
    resetInfiniteStaminaState()

    disconnectConnections(CharacterConnections)
    clearEntryState(CharacterPartCache)
    disconnectConnections(PlayerFolderCache.RootConnections)
    disconnectConnections(PlayerFolderCache.Survivor.Connections)
    disconnectConnections(PlayerFolderCache.Killer.Connections)
    disconnectConnections(MapCache.Connections)
    disconnectConnections(MapCache.RootConnections)
    disconnectConnections(IgnoreCache.RootConnections)
    disconnectConnections(IgnoreCache.TrapConnections)
    for _, group in pairs(MapCache.Groups) do
        clearTrackedGroup(group)
    end

    if PlayerUtility.lplrHumanoid then
        pcall(function()
            PlayerUtility.lplrHumanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll,     true)
            PlayerUtility.lplrHumanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
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
                    if not PlayerUtility.lplrIsAlive or not RuntimeState.RootPart then setBlock(false); return end
                    local target, distance = closestTarget(18)
                    local targetRoot = getPart(target)
                    if targetRoot then
                        local dir = (RuntimeState.RootPart.Position - targetRoot.Position)
                        local dot = dir.Magnitude > 0 and targetRoot.CFrame.LookVector:Dot(dir.Unit) or -1
                        setBlock(distance <= 9 or dot > 0.1)
                    else
                        setBlock(false)
                    end
                end)
            else
                RunLoops:UnbindFromHeartbeat("AutoBlock")
                setBlock(false)
            end
        end
    })

    CombatPanel.CreateOptionsButton({
        Name = "Auto Swing",
        Function = function(callback)
            if callback then
                RunLoops:BindToHeartbeat("AutoSwing", function()
                    if not PlayerUtility.lplrIsAlive then return end
                    local target, distance = closestTarget(11)
                    if target and distance <= 11 and throttle("AutoSwing", 0.18) then
                        swing()
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
                    if not PlayerUtility.lplrIsAlive then return end
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
                    if not PlayerUtility.lplrIsAlive or not RuntimeState.Character or not RuntimeState.Humanoid then return end
                    setAttr(RuntimeState.Character, "Stun", false)
                    removeTag(RuntimeState.Character, "CantMove")
                    removeTag(RuntimeState.Character, "StopAnim")
                    removeTag(RuntimeState.Character, "KillAnims")
                    RuntimeState.Humanoid.PlatformStand = false
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
                disconnect("StunAlert")
                RuntimeState.StunState = false
                if lplr.Character then
                    Connections.StunAlert = lplr.Character:GetAttributeChangedSignal("Stun"):Connect(function()
                            local stunned = lplr.Character and getAttr(lplr.Character, "Stun", false) or false
                            if stunned and not RuntimeState.StunState then
                            notify("Stun Alert: you are stunned")
                        end
                        RuntimeState.StunState = not not stunned
                    end)
                end
            else
                disconnect("StunAlert")
                RuntimeState.StunState = false
            end
        end
    })

    CombatPanel.CreateOptionsButton({
        Name = "Anti Ragdoll",
        Function = function(callback)
            if callback then
                RunLoops:BindToHeartbeat("AntiRagdoll", function()
                    if not PlayerUtility.lplrIsAlive or not RuntimeState.Character or not RuntimeState.Humanoid then return end
                    setAttr(RuntimeState.Character, "Ragdoll", false)
                    removeTag(RuntimeState.Character, "Ragdoll")
                    pcall(function()
                        RuntimeState.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll,     false)
                        RuntimeState.Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
                    end)
                    RuntimeState.Humanoid.PlatformStand = false
                    local state = RuntimeState.Humanoid:GetState()
                    if state == Enum.HumanoidStateType.Ragdoll or state == Enum.HumanoidStateType.FallingDown or state == Enum.HumanoidStateType.PlatformStanding then
                        RuntimeState.Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
                    end
                end)
            else
                RunLoops:UnbindFromHeartbeat("AntiRagdoll")
                if RuntimeState.Humanoid then
                    pcall(function()
                        RuntimeState.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
                        RuntimeState.Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
                    end)
                elseif PlayerUtility.lplrHumanoid then
                    pcall(function()
                        PlayerUtility.lplrHumanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
                        PlayerUtility.lplrHumanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
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
                    if not PlayerUtility.lplrIsAlive then return end
                    for _, track in ipairs(PlayerUtility.lplrHumanoid:GetPlayingAnimationTracks()) do
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
                    setAttr(lplr, "CameraShake", false)
                end)
            else
                RunLoops:UnbindFromHeartbeat("BlockCameraShake")
                if SavedStates.PlayerAttributes.CameraShake ~= nil then
                    setAttr(lplr, "CameraShake", SavedStates.PlayerAttributes.CameraShake)
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
                    if not PlayerUtility.lplrIsAlive or lkillr() then return end
                    if not throttle("AutoBarricade", 0.5) then return end
                    local door = closestIn(getDoors(), 60, function(instance)
                        return not getAttr(instance, "HOLD", false)
                    end)
                    if door then interact(door, {"barricade"}) end
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
                    if not PlayerUtility.lplrIsAlive or lkillr() then return end
                    if not throttle("AutoEscape", 0.45) then return end
                    local exitTarget = closestIn(getExits(), 250)
                    if exitTarget then
                        interact(exitTarget, {"escape", "exit", "open", "leave"})
                    else
                        local exitPrompt = findMapPrompt({"escape", "exit", "leave"}, 250)
                        if exitPrompt then
                            interact(exitPrompt, {"escape", "exit", "leave"})
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
                InfiniteStaminaState.Enabled = true
                resetInfiniteStaminaState()
                applyInfiniteStamina()
                RunLoops:BindToHeartbeat("InfiniteStamina", function()
                    if InfiniteStaminaState.Enabled then
                        applyInfiniteStamina()
                    end
                end)
            else
                InfiniteStaminaState.Enabled = false
                resetInfiniteStaminaState()
                RunLoops:UnbindFromHeartbeat("InfiniteStamina")
            end
        end
    })

    MovementPanel.CreateOptionsButton({
        Name = "NoClip",
        Function = function(callback)
            if callback then
                RunLoops:BindToHeartbeat("NoClip", function()
                    if not PlayerUtility.lplrIsAlive or not RuntimeState.Character then return end
                    noCollide(RuntimeState.Character)
                end)
            else
                RunLoops:UnbindFromHeartbeat("NoClip")
                restoreCollision()
            end
        end
    })

    MovementPanel.CreateOptionsButton({
        Name = "Anti Slide After Stop",
        Function = function(callback)
            if callback then
                RunLoops:BindToHeartbeat("AntiSlide", function()
                    if not PlayerUtility.lplrIsAlive or not RuntimeState.Character or not RuntimeState.Humanoid or not RuntimeState.RootPart then return end
                    removeTag(RuntimeState.Character, "SlowStop")
                    if RuntimeState.Humanoid.MoveDirection.Magnitude <= 0.05 then
                        RuntimeState.RootPart.AssemblyLinearVelocity = Vector3.new(0, RuntimeState.RootPart.AssemblyLinearVelocity.Y, 0)
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
                    applyFB()
                end)
            else
                RunLoops:UnbindFromHeartbeat("Fullbright")
                restoreFB()
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
                    if not throttle("SurvivorESPTick", 0.15) then return end
                    pcall(function()
                        updateESP("Survivor", getSurvivorCharacters(), function(character)
                            return playerESP(character, true, "Survivor", HealthESP, StaminaESP)
                        end, ESPColors.Survivor)
                    end)
                end)
            else
                RunLoops:UnbindFromHeartbeat("SurvivorESP")
                clearESP("Survivor")
            end
        end
    })

    RenderPanel.CreateOptionsButton({
        Name = "Killer ESP",
        Function = function(callback)
            if callback then
                RunLoops:BindToHeartbeat("KillerESP", function()
                    if not throttle("KillerESPTick", 0.15) then return end
                    pcall(function()
                        updateESP("Killer", getKillerCharacters(), function(character)
                            return playerESP(character, true, "Killer", HealthESP, StaminaESP)
                        end, ESPColors.Killer)
                    end)
                end)
            else
                RunLoops:UnbindFromHeartbeat("KillerESP")
                clearESP("Killer")
            end
        end
    })

    RenderPanel.CreateOptionsButton({
        Name = "Generator ESP",
        Function = function(callback)
            if callback then
                RunLoops:BindToHeartbeat("GeneratorESP", function()
                    if not throttle("GeneratorESPTick", 0.15) then return end
                    pcall(function()
                        updateESP("Generator", getGenerators(), function(instance)
                            return worldESP("Generator", instance)
                        end, ESPColors.Generator)
                    end)
                end)
            else
                RunLoops:UnbindFromHeartbeat("GeneratorESP")
                clearESP("Generator")
            end
        end
    })

    RenderPanel.CreateOptionsButton({
        Name = "FuseBox ESP",
        Function = function(callback)
            if callback then
                RunLoops:BindToHeartbeat("FuseBoxESP", function()
                    if not throttle("FuseBoxESPTick", 0.15) then return end
                    pcall(function()
                        updateESP("FuseBox", getFuseBoxes(), function(instance)
                            return worldESP("FuseBox", instance)
                        end, ESPColors.FuseBox)
                    end)
                end)
            else
                RunLoops:UnbindFromHeartbeat("FuseBoxESP")
                clearESP("FuseBox")
            end
        end
    })

    RenderPanel.CreateOptionsButton({
        Name = "Battery ESP",
        Function = function(callback)
            if callback then
                RunLoops:BindToHeartbeat("BatteryESP", function()
                    if not throttle("BatteryESPTick", 0.15) then return end
                    pcall(function()
                        updateESP("Battery", getBatteries(), function(instance)
                            return worldESP("Battery", instance)
                        end, ESPColors.Battery)
                    end)
                end)
            else
                RunLoops:UnbindFromHeartbeat("BatteryESP")
                clearESP("Battery")
            end
        end
    })

    RenderPanel.CreateOptionsButton({
        Name = "Door ESP",
        Function = function(callback)
            if callback then
                RunLoops:BindToHeartbeat("DoorESP", function()
                    if not throttle("DoorESPTick", 0.15) then return end
                    pcall(function()
                        updateESP("Door", getDoors(), function(instance)
                            return worldESP("Door", instance)
                        end, ESPColors.Door)
                    end)
                end)
            else
                RunLoops:UnbindFromHeartbeat("DoorESP")
                clearESP("Door")
            end
        end
    })

    RenderPanel.CreateOptionsButton({
        Name = "Exit ESP",
        Function = function(callback)
            if callback then
                RunLoops:BindToHeartbeat("ExitESP", function()
                    if not throttle("ExitESPTick", 0.15) then return end
                    pcall(function()
                        updateESP("Exit", getExits(), function(instance)
                            return worldESP("Exit", instance)
                        end, ESPColors.Exit)
                    end)
                end)
            else
                RunLoops:UnbindFromHeartbeat("ExitESP")
                clearESP("Exit")
            end
        end
    })

    RenderPanel.CreateOptionsButton({
        Name = "Beartrap ESP",
        Function = function(callback)
            if callback then
                RunLoops:BindToHeartbeat("BeartrapESP", function()
                    if not throttle("BeartrapESPTick", 0.15) then return end
                    pcall(function()
                        updateESP("Beartrap", getBeartraps(), function(instance)
                            return worldESP("Beartrap", instance)
                        end, ESPColors.Beartrap)
                    end)
                end)
            else
                RunLoops:UnbindFromHeartbeat("BeartrapESP")
                clearESP("Beartrap")
            end
        end
    })

    RenderPanel.CreateOptionsButton({
        Name = "Ennard Minions ESP",
        Function = function(callback)
            if callback then
                RunLoops:BindToHeartbeat("EnnardMinionsESP", function()
                    if not throttle("EnnardESPTick", 0.15) then return end
                    pcall(function()
                        updateESP("EnnardMinion", getEnnardMinions(), function(instance)
                            return worldESP("Ennard Minion", instance)
                        end, ESPColors.EnnardMinion)
                    end)
                end)
            else
                RunLoops:UnbindFromHeartbeat("EnnardMinionsESP")
                clearESP("EnnardMinion")
            end
        end
    })

    RenderPanel.CreateOptionsButton({
        Name = "Objective ESP",
        Function = function(callback)
            if callback then
                RunLoops:BindToHeartbeat("ObjectiveESP", function()
                    if not throttle("ObjectiveESPTick", 0.15) then return end
                    pcall(function()
                        updateESP("Objective", getObjectives(), function(instance)
                            return worldESP("Objective", instance)
                        end, ESPColors.Objective)
                    end)
                end)
            else
                RunLoops:UnbindFromHeartbeat("ObjectiveESP")
                clearESP("Objective")
            end
        end
    })

    RenderPanel.CreateOptionsButton({
        Name = "Hitbox Viewer",
        Function = function(callback)
            setAttr(lplr, "ShowHitboxes", callback and true or (SavedStates.PlayerAttributes.ShowHitboxes ~= nil and SavedStates.PlayerAttributes.ShowHitboxes or false))
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
                    if not PlayerUtility.lplrIsAlive then return end
                    if not throttle("AutoShake", 0.08) then return end
                    if not clickGui({"shake", "wiggle", "struggle"}) then
                        local prompt = findMapPrompt({"shake", "wiggle", "struggle"}, 20)
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
                    if not PlayerUtility.lplrIsAlive or lkillr() then return end
                    if not throttle("FastItemPickup", 0.12) then return end

                    local target = closestInteract(getBatteries(), {"pickup", "take", "grab", "collect", "battery", "fuse"}, 16)
                    if target then
                        interact(target, {"pickup", "take", "grab", "collect", "battery", "fuse"})
                        return
                    end

                    local prompt, promptDistance = findMapPrompt({"pickup", "take", "grab", "collect", "battery", "fuse"}, 14)
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
                    if not PlayerUtility.lplrIsAlive or lkillr() then return end

                    local _, generatorMain, event = getGeneratorPanel()
                    if not (generatorMain and guiVisible(generatorMain)) then
                        return
                    end

                    if not throttle("AutoRepairGeneratorsSolve", 0.05) then return end

                    if event then
                        event:FireServer({
                            Wires = true,
                            Switches = true,
                            Lever = true
                        })
                    end

                    refillStamina(RuntimeState.Character)
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
                    if not PlayerUtility.lplrIsAlive or lkillr() then return end
                    if not throttle("AntiSpringtrapTraps", 0.1) then return end
                    local closestTrap, closestDist = closestIn(getSpringtrapTraps(), 20)
                    if closestTrap then
                        for _, d in ipairs(closestTrap:GetDescendants()) do
                            if d:IsA("BasePart") then defusePart(d) end
                        end
                        if closestDist <= 6 and RuntimeState.RootPart then
                            RuntimeState.RootPart.CFrame = RuntimeState.RootPart.CFrame + Vector3.new(0, 4, 0)
                        end
                    end
                end)
            else
                RunLoops:UnbindFromHeartbeat("AntiSpringtrapTraps")
                restoreTraps()
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
                        local label = getHud()
                        if not label then return end
                        
                        local killer, distance = closestKiller(250)
                        
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
                pcall(removeHud)
            end
        end
    })

    MiscPanel.CreateOptionsButton({
        Name = "Auto Emote Player",
        Function = function(callback)
            if callback then
                RunLoops:BindToHeartbeat("AutoEmotePlayer", function()
                    pcall(function()
                        if not throttle("AutoEmotePlayer", 10) then return end
                        if PlayerUtility.lplrIsAlive and RuntimeState.RootPart and RuntimeState.RootPart.AssemblyLinearVelocity and RuntimeState.RootPart.AssemblyLinearVelocity.Magnitude <= 2 and not getAttr(RuntimeState.Character, "Stun", false) then
                            randEmote()
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
                notify("Made by xzyn")
                task.defer(function()
                    if CreditsButton and CreditsButton.Enabled then
                        CreditsButton.Toggle()
                    end
                end)
            end
        end
    })
end)
