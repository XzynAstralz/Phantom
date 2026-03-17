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

local entity, UI, ops = phantom.entity, phantom.UI, phantom.ops
local GuiLibrary, funcs = UI, ops
local createNotification = GuiLibrary.toast

local RunLoops = {RenderStepTable = {}, StepTable = {}, HeartTable = {}}

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

for _, v in ipairs({"AntiAFK", "Antideath", "Gravity", "FovChanger", "TriggerBot", "ESP", "Cape", "AimAssist", "AntiFall"}) do
    UI.kit:deregister(v .. "Module")
end

runcode(function()
    local zonesFolder = workspace:WaitForChild("Zones")
    local zoneList = {}
    local allZoneParts = {}
    local ZoneTPDropdown = {Value = ""}

    local safeZonePart = workspace:WaitForChild("MainMap"):WaitForChild("Model"):WaitForChild("Part")
    zoneList[#zoneList + 1] = "Safe Zone"
    allZoneParts["Safe Zone"] = {safeZonePart}

    for _, zone in ipairs(zonesFolder:GetChildren()) do
        if tonumber(zone.Name) then
            table.insert(zoneList, zone.Name)

            allZoneParts[zone.Name] = {}
            for _, part in ipairs(zone:GetChildren()) do
                if part:IsA("BasePart") then
                    table.insert(allZoneParts[zone.Name], part)
                end
            end
        end
    end

    local ZoneTPButton
    ZoneTPButton = GuiLibrary.Registry.miscPanel.API.CreateOptionsButton({
        Name = "ZoneTP",
        Function = function(callback)
            if callback then
                local selectedZone = ZoneTPDropdown.Value
                local parts = allZoneParts[selectedZone]
                if parts and #parts > 0 then
                    lplr.Character.HumanoidRootPart.CFrame = parts[1].CFrame
                end
                ZoneTPButton.Toggle()
            end
        end
    })

    ZoneTPButton.CreateDropdown({
        Name = "Select Zone",
        List = zoneList,
        Default = zoneList[1] or "",
        Function = function(selectedZone)
            ZoneTPDropdown.Value = selectedZone
        end
    })
end)
