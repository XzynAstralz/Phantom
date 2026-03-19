

--[[
    --------------------------------------------------------------
    -------------------------------------------------------------
    https://www.roblox.com/games/71480482338212/BedFight
    -------------------------------------------------------------
    -------------------------------------------------------------
--]]


repeat task.wait() until game:IsLoaded()

local getcustomasset = getsynasset or getcustomasset
local request = syn and syn.request or http and http.request or http_request or request or function() end
local queueteleport = queue_for_teleport or queue_on_teleport or queueonteleport

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Teams = game:GetService("Teams")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

local lplr = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local UI, ops = phantom.UI, phantom.ops
local GuiLibrary, funcs = UI, ops
local createNotification = GuiLibrary.toast

local RunLoops = {RenderStepTable = {}, StepTable = {}, HeartTable = {}}
local PlayerUtility = loadstring(game:HttpGet("https://raw.githubusercontent.com/XzynAstralz/Phantom/refs/heads/main/lib/Utility.lua"))()

local function BindToLoop(loopTable, loopEvent, name, func)
    if loopTable[name] then
        loopTable[name]:Disconnect()
    end
    loopTable[name] = loopEvent:Connect(func)
    return loopTable[name]
end

local function UnbindFromLoop(loopTable, name)
    if loopTable[name] then
        loopTable[name]:Disconnect()
        loopTable[name] = nil
    end
end

local loopTable = {}

function RunLoops:BindToRenderStep(name, func)
    BindToLoop(loopTable, RunService.PreSimulation, name, func)
end

function RunLoops:UnbindFromRenderStep(name)
    UnbindFromLoop(loopTable, name)
end

function RunLoops:BindToStepped(name, func)
    BindToLoop(loopTable, RunService.PreSimulation, name, func)
end

function RunLoops:UnbindFromStepped(name)
    UnbindFromLoop(loopTable, name)
end

function RunLoops:BindToHeartbeat(name, func)
    return BindToLoop(loopTable, RunService.PreSimulation, name, func)
end

function RunLoops:UnbindFromHeartbeat(name)
    UnbindFromLoop(loopTable, name)
end

local runcode = function(func)
    return func()
end

for _, v in ipairs({"Antideath", "Gravity", "ESP", "AntiFall", "TriggerBot", "AimAssist", "BreadCrumbs"}) do
    UI.kit:deregister(v .. "Module")
end

local foundSwords = {}

local function findClosestMatch(name)
    for _, item in ipairs(lplr.Character:GetChildren()) do
        if item.Name:find(name) then return item end
    end
    for _, item in ipairs(lplr.Backpack:GetChildren()) do
        if item.Name:find(name) then return item end
    end
end

local function GetSword()
    if not foundSwords.Sword then
        local m = findClosestMatch("Sword")
        if m then foundSwords.Sword = m.Name end
    end
    return foundSwords.Sword
end

local Distance = {Value = 21}

runcode(function()
    local adornments, Killaura, LegitAura, ShowTarget, swordtype = {}, {}, {}, {}, nil
    local data = {Attacking = false, attackingEntity = nil}
    local lastClick = 0

    local function clear()
        for _, v in ipairs(adornments) do v.Adornee = nil end
    end

    local function attack(entity)
        if entity and swordtype then
            ReplicatedStorage.Remotes.ItemsRemotes.SwordHit:FireServer(unpack({swordtype, entity}))
        end
    end

    local function reset()
        data.Attacking = false
        data.attackingEntity = nil
        clear()
    end

    Killaura = GuiLibrary.Registry.combatPanel.API.CreateOptionsButton({
        Name = "Killaura",
        Beta = true,
        Function = function(callback)
            if not callback then clear() return RunLoops:UnbindFromHeartbeat("Killaura") end
            RunLoops:BindToHeartbeat("Killaura", function()
                if not PlayerUtility.IsAlive() then return reset() end

                local nearest = PlayerUtility.GetNearestEntities(Distance.Value, true, false)
                if #nearest == 0 then return reset() end

                local entity = nearest[1].character
                local root = entity and entity:FindFirstChild("HumanoidRootPart")
                local hum = entity and entity:FindFirstChildOfClass("Humanoid")
                if not root or not hum or hum.Health <= 0 then return reset() end

                swordtype = GetSword()
                print(swordtype)
                data.Attacking = true
                data.attackingEntity = entity
                print("attacking")
                attack(entity)

                for i, v in ipairs(adornments) do
                    local e = nearest[i]
                    local ec = e and e.character
                    local er = ec and ec:FindFirstChild("HumanoidRootPart")
                    local eh = ec and ec:FindFirstChildOfClass("Humanoid")
                    v.Adornee = (ShowTarget.Enabled and eh and eh.Health > 0 and er) or nil
                end
            end, 0.1)
        end
    })
    Distance = Killaura.CreateSlider({
        Name = "value",
        Min = 0,
        Max = 23,
        Default = 23,
        Round = 1,
        Function = function() end
    })
    ShowTarget = Killaura.CreateToggle({
        Name = "Show Target",
        Default = true,
        Function = function(callback)
            if callback then
                GuiLibrary.ColorUpdate:Connect(function()
                    local newColor = GuiLibrary.kit:activeColor()
                    for _, adornment in ipairs(adornments) do
                        adornment.Color3 = newColor
                    end
                end)
                for i = 1, 10 do
                    local boxHandleAdornment = Instance.new("BoxHandleAdornment")
                    boxHandleAdornment.Size = Vector3.new(4, 6, 4)
                    boxHandleAdornment.Color3 = Color3.new(1, 0, 0)
                    boxHandleAdornment.Transparency = 0.6
                    boxHandleAdornment.AlwaysOnTop = true
                    boxHandleAdornment.ZIndex = 10
                    boxHandleAdornment.Parent = workspace
                    adornments[i] = boxHandleAdornment
                end
            end
        end,
    })
end)
