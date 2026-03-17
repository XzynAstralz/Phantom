local getcustomasset = getsynasset or getcustomasset
local request = syn and syn.request or http and http.request or http_request or request or function() end
local queueteleport = queue_for_teleport or queue_on_teleport or queueonteleport

-- repeat
--     task.wait()
-- until game:IsLoaded()

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

--local PlayerUtility = loadstring(readfile("Phantom/lib/Utility.lua"))() no worky for this game
--local WhitelistModule = loadstring(game:HttpGet("https://raw.githubusercontent.com/XzynAstralz/Aristois/main/Librarys/Whitelist.lua"))()
local DrawLibrary = loadstring(readfile("Phantom/lib/fly.lua"))()

local entity, UI, ops = phantom.entity, phantom.UI, phantom.ops

local GuiLibrary, funcs = UI, ops  -- compat aliases
local createNotification = GuiLibrary.toast
--shared.WhitelistFile = WhitelistModule
getgenv().SecureMode = true

local newData = {
    charStats = {},
    connections = {}
}

local RunLoops = {RenderStepTable = {}, StepTable = {}, HeartTable = {}}


local function BindToLoop(loopTable, loopEvent, name, func)
    if loopTable[name] then
        loopTable[name]:Disconnect()
    end
    loopTable[name] = loopEvent:Connect(func)
end

local function UnbindFromLoop(loopTable, name)
    if loopTable[name] then
        loopTable[name]:Disconnect()
        loopTable[name] = nil
    end
end

local loopTable = {}
-- local function BindToLoop(loopTable, loopEvent, name, func)
--     loopTable[name] = func
-- end

-- local function UnbindFromLoop(loopTable, name)
--     loopTable[name] = nil
-- end

function RunLoops:BindToRenderStep(name, func)
    BindToLoop(loopTable, RunService.PreRender, name, func)
end

function RunLoops:UnbindFromRenderStep(name)
    UnbindFromLoop(loopTable, name)
end

function RunLoops:BindToStepped(name, func)
    BindToLoop(loopTable, RunService.PreRender, name, func)
end

function RunLoops:UnbindFromStepped(name)
    UnbindFromLoop(loopTable, name)
end

function RunLoops:BindToHeartbeat(name, func)
    BindToLoop(loopTable, RunService.PreRender, name, func)
end

function RunLoops:UnbindFromHeartbeat(name)
    UnbindFromLoop(loopTable, name)
end

local runcode = function(func) -- stays like this because stuff needs to load properly
    return func()
end

local force = --[[ setmetatable({
    funny = "require.table",
    remotes = {
        PickupRemote = "path",
    },
})--]]


-- remove or add them 
-- GuiLibrary.utils:removeObject("flyOptionsButton")
-- GuiLibrary.utils:removeObject("EspOptionsButton")
-- GuiLibrary.utils:removeObject("TracersOptionsButton")
-- GuiLibrary.utils:removeObject("FullbrightOptionsButton")
-- GuiLibrary.utils:removeObject("speedOptionsButton")
-- GuiLibrary.utils:removeObject("phaseOptionsButton")
-- GuiLibrary.utils:removeObject("blinkOptionsButton")
GuiLibrary.utils:removeObject("nametagsOptionsButton")
-- GuiLibrary.utils:removeObject("autorejoinOptionsButton")
-- GuiLibrary.utils:removeObject("spinbotOptionsButton")
-- GuiLibrary.utils:removeObject("highjumpOptionsButton")
-- GuiLibrary.utils:removeObject("FovchangerOptionsButton")

runcode(function()
    local Damage = {}
    local DamageBooster = {}
    local originalNamecall = nil
    DamageBooster = GuiLibrary.Registry.combatPanel.API.CreateOptionsButton({
        Name = "DamageBooster",
        Function = function(callback)
            if callback then
                originalNamecall = hookmetamethod(game, "__namecall", function(self, ...)
                    if not checkcaller() then
                        if getnamecallmethod() == "FireServer" then
                            if self.Name == "CombatRemoteEvent" then
                                local args = {...}
                                if args[1] == "HitHumans" or args[2] == "HitHumans" then
                                    for i=1, Damage.Value do
                                        originalNamecall(self, ...)
                                    end
                                end
                            end;
                        end;
                    end;
                    return originalNamecall(self, ...)
                end);
            else
                if originalNamecall then
                    hookmetamethod(game, "__namecall", originalNamecall)
                end
            end
        end
    })
    Damage = DamageBooster.CreateSlider({
        Name = "Damage",
        Min = 1,
        Max = 4,
        Default = 1,
        Round = 0
    })
end)

runcode(function()
    local ReachSlider = {}
    local Reach = {}
    local originalAttackFunction = nil
    local toggleConnection = nil
    local Reach = GuiLibrary.Registry.combatPanel.API.CreateOptionsButton({
        Name = "Reach",
        Function = function(callback)
            if callback then
                local function overrideAttack(healthComponent)
                    local localCombat = healthComponent:WaitForChild("LocalCombat")
                    local scriptEnv = getsenv(localCombat)
                    local originalAttack = scriptEnv.Attack
                    scriptEnv.Attack = function(...)
                        local args = { ... }
                        args[2] = Vector3.new(ReachSlider.Value, ReachSlider.Value, ReachSlider.Value)
                        return originalAttack(unpack(args))
                    end
                end
                local player = game.Players.LocalPlayer
                local character = player.Character or player.CharacterAdded:Wait()
                overrideAttack(character:WaitForChild("Health"))
                toggleConnection = player.CharacterAdded:Connect(function(newCharacter)
                    task.wait(1)
                    overrideAttack(newCharacter:WaitForChild("Health"))
                end)
            else
                if toggleConnection then
                    toggleConnection:Disconnect()
                    toggleConnection = nil
                end
            end
        end
    })
    ReachSlider = Reach.CreateSlider({
        Name = "Reach",
        Min = 8,
        Max = 30,
        Default = 12,
        Round = 0
    })
end)

do
    local function formatNametag(ent) 
        if not entity.isAlive then 
            return ("[0] " .. ent.Player.DisplayName .. "| %sHP"):format(math.round(ent.Humanoid.Health))
        end
        return string.format("[%s] %s | %sHP", 
        entity.character.HumanoidRootPart and tostring(math.round((ent.RootPart.Position - entity.character.HumanoidRootPart.Position).Magnitude)) or "N/A",
        ent.Player.DisplayName, 
        tostring(math.round(ent.Humanoid.Health)))
    end
    
    local NametagsColorMode, NametagsScale, NametagsRemoveHumanoidTag = {}, {}, {}
    local Nametags = {}
    local drawings = {}
    local done = {}
    Nametags = GuiLibrary.Registry.renderPanel.API.CreateOptionsButton({
        Name = "nametags",
        Function = function(callback) 
            if callback then 
                funcs:bindToRenderStepped("Nametags", function(dt) 
                    for _, v in next, drawings do 
                        if v.Text then 
                            v.Text.Visible = false
                        end
                        if v.BG then 
                            v.BG.Visible = false
                        end
                    end

                    for _, v in next, entity.entityList do 

                        if not funcs:isAlive(v.Player, true) then 
                            continue 
                        end

                        local Name = v.Player.DisplayName
                        local NametagBG, NametagText
                        if done[Name] then
                            NametagText = drawings[Name].Text
                            NametagBG = drawings[Name].BG
                        else
                            done[Name] = true
                            drawings[Name] = drawings[Name] or {}
                            NametagText = Drawing.new("Text")
                            NametagBG = Drawing.new("Square")
                            drawings[Name].Text = NametagText
                            drawings[Name].BG = NametagBG
                        end

                        if not NametagBG or not NametagText then 
                            continue 
                        end

                        local Position, Visible = workspace.CurrentCamera:WorldToViewportPoint(v.Head.Position + Vector3.new(0, 1.75, 0))
                        if Visible then 
                            local XOffset, YOffset = 10, 2

                            NametagText.Text = formatNametag(v)
                            NametagText.Font = 3
                            NametagText.Size = 16 * NametagsScale.Value
                            NametagText.ZIndex = 2
                            NametagText.Visible = true
                            NametagText.Position = Vector2.new(
                                Position.X - (NametagText.TextBounds.X * 0.5),
                                Position.Y - NametagText.TextBounds.Y
                            )
                            NametagText.Color = funcs:activeColorFromEntity(v, NametagsColorMode.Value == 'team', NametagsColorMode.Value == 'color theme')
                            NametagBG.Filled = true
                            NametagBG.Color = Color3.new(0, 0, 0)
                            NametagBG.ZIndex = 1
                            NametagBG.Transparency = 0.5
                            NametagBG.Visible = true
                            NametagBG.Position = Vector2.new(
                                ((Position.X - (NametagText.TextBounds.X + XOffset) * 0.5)),
                                (Position.Y - NametagText.TextBounds.Y)
                            )
                            NametagBG.Size = NametagText.TextBounds + Vector2.new(XOffset, YOffset)
                        end

                        if NametagsRemoveHumanoidTag.Enabled then 
                            --pcall(function() 
                                v.Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
                            --end)
                        end
                    end
                end)
            else
                funcs:unbindFromRenderStepped("Nametags")
                for i,v in next, drawings do 
                    if v.Text then 
                        v.Text:Remove()
                    end
                    if v.BG then 
                        v.BG:Remove()
                    end
                    drawings[i] = nil
                end
                done = {}
            end
        end,
    })
    NametagsColorMode = Nametags.CreateDropdown({
        Name = "color mode",
        Default = 'team',
        List = {"none", "team", "color theme"},
        Function = function() end
    })
    NametagsScale = Nametags.CreateSlider({
        Name = "scale",
        Min = 1,
        Max = 10,
        Default = 1,
        Round = 1,
        Function = function() end
    })
    NametagsRemoveHumanoidTag = Nametags.CreateToggle({
        Name = "anti humanoid tag",
        Function = function() end
    })
end

runcode(function()
    local FreezeAll = {}
    FreezeAll = GuiLibrary.Registry.blatantPanel.API.CreateOptionsButton({
        Name = "FreezeAll (Ravenger)",
        Function = function(callback)
            if callback then
                local combatRemote = workspace:WaitForChild(game.Players.LocalPlayer.Name):WaitForChild("CombatRemoteEvent")
                local frozenPlayers = {}
                local allSameTeam = true
                for _, p in pairs(game.Players:GetPlayers()) do
                    if p.Team ~= lplr.Team then
                        allSameTeam = false
                        break
                    end
                end
                for _, p in pairs(game.Players:GetPlayers()) do
                    local char = p.Character
                    if p ~= lplr and char and char:FindFirstChild("HumanoidRootPart") then
                        if not allSameTeam and p.Team ~= lplr.Team then
                            combatRemote:FireServer("HitHumans", char.Humanoid, "Skill2B", 10000, "kHIG", true)
                            table.insert(frozenPlayers, p)
                        elseif allSameTeam then
                            combatRemote:FireServer("HitHumans", char.Humanoid, "Skill2B", 10000, "kHIG", true)
                            table.insert(frozenPlayers, p)
                        end
                    end
                end
                if #frozenPlayers > 0 then
                    game:GetService("TeleportService"):Teleport(game.PlaceId, lplr)
                end
                FreezeAll.Toggle(false)
            end
        end
    })
end)

runcode(function()
    local AutoBoss = {}
    AutoBoss = GuiLibrary.Registry.blatantPanel.API.CreateOptionsButton({
        Name = "AutoBoss",
        Function = function(callback)
            if callback then
                local function monitorUnusualBills()
                    for _, folder in pairs(workspace.Current:GetChildren()) do
                        if folder:IsA("Folder") then
                            for _, bill in pairs(folder:GetChildren()) do
                                if bill.Name == "UnusualBill" then
                                    bill:GetPropertyChangedSignal("Transparency"):Connect(function()
                                        if bill.Transparency ~= 1 then
                                            lplr.Character:SetPrimaryPartCFrame(CFrame.new(bill.Position))
                                        end
                                    end)
                                end
                            end
                        end
                    end
                end
                monitorUnusualBills()
            end
        end
    })
end)