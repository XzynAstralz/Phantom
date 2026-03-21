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
local LongFly = {}
local PlayerUtility = loadstring(readfile("Phantom/lib/Utility.lua"))()
local DrawLibrary = loadstring(game:HttpGet("https://raw.githubusercontent.com/XzynAstralz/Phantom/refs/heads/main/lib/fly.lua"))()

local loopTable = {}
local data = {
    hooked = {},
    Attacking = false,
    attackingEntity = nil,
    gamemode = {
        value = nil,
        current = nil,
        connection = nil
    }
}
PlayerUtility.teams = {
    Spectroctor = true
}

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

for _, v in ipairs({"Antideath", "Gravity", "ESP", "AntiFall", "TriggerBot", "AimAssist", "BreadCrumbs", "Speed", "Fly", "AntiAFK", "AntiFall", "Antideath"}) do
    UI.kit:deregister(v .. "Module")
end

local Fly = {}
local Speed = {}
local infFlyVel = false

local bodyVel
local createBodyVel = function()
    if PlayerUtility.IsAlive(lplr) and ((bodyVel and not bodyVel.Parent.Parent) or not bodyVel) then
        bodyVel = Instance.new("BodyVelocity", lplr.Character.HumanoidRootPart)
        bodyVel.P = math.huge
        bodyVel.MaxForce = Vector3.new(bodyVel.P, bodyVel.P, bodyVel.P)
        bodyVel.Velocity = Vector3.zero

        funcs:onExit("bodyVelHook", function()
            if bodyVel then
                bodyVel:Destroy()
            end
        end)
    end
end

local speedBoost
local speedTimer = tick()

local SpeedMultiplier = function()
    local baseMultiplier = 0
    if tick() <= speedTimer then
        baseMultiplier = baseMultiplier + speedBoost
    end
    return baseMultiplier
end

local function hookValue(plr, v)
    if not data.hooked[plr] then return end
    table.insert(data.hooked[plr].items, v)
end

local function unhookValue(plr, v)
    if not data.hooked[plr] then return end
    local t = data.hooked[plr].items
    local i = table.find(t, v)
    if i then
        table.remove(t, i)
    end
end

local hookinv = function(plr)
    plr = plr or lplr
    local inv = plr.Inventory

    data.hooked[plr] = {
        inv = inv,
        items = {}
    }

    for _, v in ipairs(inv:GetChildren()) do
        if v:IsA("NumberValue") then
            hookValue(plr, v)
        end
    end

    GuiLibrary.kit.track(inv.ChildAdded:Connect(function(v)
        if v:IsA("NumberValue") then
            hookValue(plr, v)
        end
    end))

    GuiLibrary.kit.track(inv.ChildRemoved:Connect(function(v)
        if v:IsA("NumberValue") then
            unhookValue(plr, v)
        end
    end))
end

local hookmode = function()
    local gameMode = game:GetService("ReplicatedStorage"):WaitForChild("GameInfo"):WaitForChild("GameMode")

    data.gamemode.current = gameMode.Value

    if data.gamemode.connection then
        data.gamemode.connection:Disconnect()
    end

    data.gamemode.connection = gameMode:GetPropertyChangedSignal("Value"):Connect(function()
        local newValue = gameMode.Value

        if newValue ~= data.gamemode.current then
            data.gamemode.current = newValue
        end
    end)

    GuiLibrary.kit.track(data.gamemode.connection)
end

local getitem = function(name, plr)
    plr = plr or lplr
    if not data.hooked[plr] then return nil end

    for _, v in ipairs(data.hooked[plr].items) do
        if v.Name:find(name) then
            return v
        end
    end
end

local getTeams = function()
    local teams = {}
    for _, team in ipairs(Teams:GetChildren()) do
        if team:IsA("Team") then
            table.insert(teams, team.Name)
        end
    end
    return teams
end

local getsword
local itmEqu

do
    hookinv(lplr)
    hookmode()
    getsword = function()
        local item = getitem("Sword")
        return item and item.Name or nil
    end
    itmEqu = function(name, plr)
        plr = plr or lplr
        local char = plr.Character
        if not char then return false end

        for _, v in ipairs(char:GetChildren()) do
            if tostring(v.Name):find(tostring(name)) then
                return true, v
            end
        end

        return false
    end
end

local Distance = {Value = 21}
runcode(function()
    local adornments = {}
    local Killaura = {}
    local LegitAura = {}
    local FacePlayer = {}
    local Swing = {}
    local ShowTarget = {}
    local swordtype = nil

    local function attack(entity)
        if entity and swordtype then
            local args = {swordtype, entity}
            ReplicatedStorage.Remotes.ItemsRemotes.SwordHit:FireServer(unpack(args))
        end
    end

    local lastDamage = {}
    local lastAttack = {}
    local lastHealth = {}
    local currentTarget

    local swordsModule = require(ReplicatedStorage.Modules.DataModules.SwordsData)

    Killaura = GuiLibrary.Registry.combatPanel.API.CreateOptionsButton({
        Name = "Killaura",
        Beta = true,
        Function = function(callback)
            if callback then
                RunLoops:BindToHeartbeat("Killaura", function()
                    local nearest = PlayerUtility.GetNearestEntities(Distance.Value, false, false)
                    if #nearest == 0 then
                        data.Attacking, data.attackingEntity, currentTarget = false, nil, nil
                        return
                    end

                    local char = nearest[1].character
                    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
                    local root = char and char:FindFirstChild("HumanoidRootPart")

                    swordtype = getsword()
                    if not (humanoid and root and swordtype and itmEqu(swordtype)) then return end

                    local swordData = swordsModule[swordtype]

                    local serverTime = workspace:GetServerTimeNow()
                    local ping = lplr:GetNetworkPing() * 2

                    local animCooldown = swordData.AnimationCooldown or 0.1
                    local damageCooldown = swordData.DamageCooldown or 0.3
                    local delay = math.max(animCooldown, ping * 0.5)

                    if currentTarget ~= humanoid then
                        currentTarget = humanoid
                        lastDamage[humanoid] = 0
                        lastAttack[humanoid] = 0
                        lastHealth[humanoid] = humanoid.Health
                    end

                    local hp = humanoid.Health
                    if lastHealth[humanoid] and hp < lastHealth[humanoid] then
                        lastDamage[humanoid] = serverTime
                    end
                    lastHealth[humanoid] = hp

                    if FacePlayer.Enabled and not LongFly.Enabled then
                        lplr.Character.PrimaryPart.CFrame = CFrame.lookAt(lplr.Character.HumanoidRootPart.Position, Vector3.new(root.Position.X, lplr.Character.HumanoidRootPart.Position.Y, root.Position.Z))
                    end
                    if ((lastDamage[humanoid] == 0 or (serverTime - lastDamage[humanoid]) >= damageCooldown) and ((serverTime - lastAttack[humanoid]) >= delay)) then 
                        lastAttack[humanoid] = serverTime
                        if Swing.Enabled then
                                local anim = Instance.new("Animation")
                                anim.AnimationId = "rbxassetid://123800159244236"
                                lplr.Character.Humanoid.Animator:LoadAnimation(anim):Play()
                            end
                        attack(char)
                    end
                end)
            else
                RunLoops:UnbindFromHeartbeat("Killaura")
            end
        end
    })
    Distance = Killaura.CreateSlider({
        Name = "Distance",
        Min = 0,
        Max = 17,
        Default = 17,
        Round = 1,
        Function = function() end
    })
    Swing = Killaura.CreateToggle({
        Name = "Swing",
        Function = function() end
    })
    FacePlayer = Killaura.CreateToggle({
        Name = "FacePlayer",
        Function = function() end
    })
end)

local SpeedSlider ={}
runcode(function()
    local AutoJump = {}
    local DamageBoost = {}
    local SlowdownAnim = {}
    local Direction = {}

    local damageBoost = {
        [0] = {
            speedBoost = 20,
            speedTimer = .35
        },
        [5] = {
            speedBoost = 20,
            speedTimer = .5
        },
    }

    Speed = GuiLibrary.Registry.blatantPanel.API.CreateOptionsButton({
        Name = "Speed",
        ExtraText = "CFrame",
        Function = function(callback)
            if callback then
                
                RunLoops:BindToHeartbeat("Speed", function(dt)
                    if PlayerUtility.IsAlive(lplr) and lplr.Character.Humanoid.MoveDirection.Magnitude > 0 then
                        local moveDirection = lplr.Character.Humanoid.MoveDirection

                        local newCFrame
                        if Direction.Enabled and moveDirection ~= Vector3.zero and not data.Attacking then
                            newCFrame = CFrame.new(lplr.Character.HumanoidRootPart.Position, lplr.Character.HumanoidRootPart.Position + Vector3.new(lplr.Character.Humanoid.MoveDirection.X, 0, lplr.Character.Humanoid.MoveDirection.Z))
                        else
                            newCFrame = lplr.Character.HumanoidRootPart.CFrame
                        end

                        if not Fly.Enabled then
                            local speedVelocity = moveDirection * (SpeedSlider.Value)
                            speedVelocity /= (1 / dt)
                            newCFrame = newCFrame + speedVelocity

                            createBodyVel()
                            if not infFlyVel then
                                bodyVel.MaxForce = Vector3.new(bodyVel.P, 0, bodyVel.P)
                            end
                        end
                        lplr.Character.HumanoidRootPart.CFrame = newCFrame

                        if not Fly.Enabled and AutoJump.Enabled and data.Attacking and lplr.Character.Humanoid.FloorMaterial ~= Enum.Material.Air then
                            lplr.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                        end
                    end
                end)
            else
                lplr.Character.Humanoid.AutoRotate = true
                if bodyVel then
                    bodyVel:Destroy()
                    bodyVel = nil
                end
                RunLoops:UnbindFromHeartbeat("Speed")
            end
        end
    })
    SpeedSlider = Speed.CreateSlider({
        Name = "value",
        Min = 0,
        Max = 23,
        Default = 23,
        Round = 1,
    })
    AutoJump = Speed.CreateToggle({
        Name = "AutoJump",
        Default = true,
    })
    Direction = Speed.CreateToggle({
        Name = "Direction",
        Default = true,
        Function = function(callback)
            repeat
                task.wait()
            until Speed.Enabled
            lplr.Character.Humanoid.AutoRotate = Speed.Enabled and not callback or true
        end,
    }) 
end)

local InfiniteFly = {}
local height = lplr.Character.HumanoidRootPart.Size.Y * 1.5

runcode(function()
	local ScreenGui = DrawLibrary.CreateBar(game.CoreGui)

	local FlyValue = {}
	local FlyVerticalValue = {}
	local ProgressBar = {}
	local extendedFly = {}
	local lastExtendTime = 0  
	local damageBoost = {}
	local bypass = {}

	local TweenFrame = ScreenGui.Bar
	local SecondLeft = ScreenGui.SecondLeft

	local function UpdateSecondLeft(seconds)
		SecondLeft.Text = seconds .. "s"
	end
    

	Fly = GuiLibrary.Registry.blatantPanel.API.CreateOptionsButton({
		Name = "Fly",
		Function = function(callback)

			local lastTick = os.clock()
			local airTimer = 0
			local i = 0
			local verticalVelocity = 0

			local descendState = false
			local ascendState = false
			local targetY = 0
			local originalY = 0

			local char = lplr.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local humanoid = char and char:FindFirstChildOfClass("Humanoid")

			local groundParams = RaycastParams.new()
			groundParams.FilterType = Enum.RaycastFilterType.Blacklist
			groundParams.FilterDescendantsInstances = { char }
			groundParams.IgnoreWater = true

			local isOverVoid = false
			local voidCheckTimer = 0
			local voidGrace = 0
			local VOID_GRACE_TIME = 0.4
			local MAX_AIR_TIME = 0.9

			if callback then
				TweenFrame.Size = UDim2.new(0, 0, 1, 0)
				TweenFrame.Position = UDim2.new(0, 0, 0, 0)
				ScreenGui.ScreenGui.Enabled = true

				RunLoops:BindToHeartbeat("Fly", function(dt)

					local currentTick = os.clock()
					local deltaTime = math.min(currentTick - lastTick, 0.1)
					lastTick = currentTick

					if not root or not root.Parent then
                        char = lplr.Character
                        root = char and char:FindFirstChild("HumanoidRootPart")
                        humanoid = char and char:FindFirstChildOfClass("Humanoid")
                        if char then
                            groundParams.FilterDescendantsInstances = { char }
                        end
						return
					end

					if bypass.Enabled then
						airTimer = math.huge
					else
						airTimer += deltaTime
					end

					local remainingTime = math.max(MAX_AIR_TIME - airTimer, 0)
					remainingTime = math.round(remainingTime * 10) / 10
					if bypass.Enabled then remainingTime = math.huge end

					voidCheckTimer += deltaTime
					if voidCheckTimer >= 0.1 then
						voidCheckTimer = 0
						local voidRay = workspace:Raycast(root.Position, Vector3.new(0, -1000, 0), groundParams)
						if voidRay then
							isOverVoid = false
							voidGrace = VOID_GRACE_TIME
						else
							voidGrace -= deltaTime
							if voidGrace <= 0 then
								isOverVoid = true
							end
						end
					end

					local moveDirection = (humanoid and humanoid.MoveDirection) or Vector3.zero
					local dir = moveDirection.Magnitude > 0.1 and moveDirection.Unit or root.CFrame.LookVector

					if ProgressBar.Enabled then
						ScreenGui.ScreenGui.Enabled = true
						TweenFrame.Visible = true
					else
						ScreenGui.ScreenGui.Enabled = false
						TweenFrame.Visible = false
					end

					UpdateSecondLeft(remainingTime)

					if ScreenGui.ScreenGui.Enabled then
						TweenFrame:TweenSize(UDim2.new(1 - (airTimer / MAX_AIR_TIME), 0, 1, 0), Enum.EasingDirection.InOut, Enum.EasingStyle.Linear, 0.1, true)
					end

					root.CFrame += moveDirection * (FlyValue.Value + SpeedMultiplier()) / (1 / dt)

					i += deltaTime
					local bounceVelocity = math.sin(i * math.pi) * 0.01

					if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
						verticalVelocity = FlyVerticalValue.Value
					elseif UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
						verticalVelocity = -FlyVerticalValue.Value
					else
						verticalVelocity = bounceVelocity
					end

					createBodyVel()
					bodyVel.MaxForce = Vector3.new(bodyVel.P, bodyVel.P, bodyVel.P)

					local ray = workspace:Raycast(root.Position, Vector3.new(0, -math.clamp(1000 + math.abs(root.AssemblyLinearVelocity.Y) * 8, 1000, 2500), 0), groundParams)

					if ray and ray.Distance <= height + 0.3 then
						airTimer = 0
						isOverVoid = false
					end

					if descendState then
						local check = workspace:Raycast(root.Position, Vector3.new(0, -100, 0), groundParams)
						if not check then
							descendState = false
							return
						end
						bodyVel.Velocity = Vector3.new(0, -math.clamp((root.Position.Y - targetY) * 3, 75, 200), 0)
						if humanoid.FloorMaterial ~= Enum.Material.Air then
							airTimer = 0
							descendState = false
							ascendState = true
						end

					elseif ascendState then
						bodyVel.Velocity = Vector3.new(0, math.clamp((originalY - root.Position.Y) * 2, 15, 60), 0)
						if originalY - root.Position.Y <= 0.3 then
							ascendState = false
							airTimer = 0
						end
					else
						bodyVel.Velocity = Vector3.new(0, verticalVelocity, 0)
					end

					if extendedFly.Enabled and not bypass.Enabled and not descendState and not ascendState and not isOverVoid then

						local vel = root.AssemblyLinearVelocity
						local horizontalSpeed = math.max(Vector3.new(vel.X, 0, vel.Z).Magnitude, FlyValue.Value + SpeedMultiplier())
						local scanStep = math.clamp(horizontalSpeed * 0.25, 4, 10)
						local maxScan = math.clamp(horizontalSpeed * 10, 60, 150)

						local closestBlock = nil
						local closestDist = math.huge

						for dist = 2, maxScan, scanStep do
							local origin = root.Position + dir * dist + Vector3.new(0, 6, 0)
							local forwardRay = workspace:Raycast(origin, Vector3.new(0, -60, 0), groundParams)
							if forwardRay then
								local hDist = (Vector3.new(forwardRay.Position.X, 0, forwardRay.Position.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude
								if math.abs(forwardRay.Position.Y - root.Position.Y) < 50 then
									if hDist < closestDist then
										closestDist = hDist
										closestBlock = forwardRay.Position
									end
								end
							end
						end

						if closestBlock and not isOverVoid then
							local horizontalDist = (Vector3.new(closestBlock.X, 0, closestBlock.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude
							if horizontalDist <= 35 then
								local safetyRay = workspace:Raycast(Vector3.new(closestBlock.X, closestBlock.Y + 5, closestBlock.Z), Vector3.new(0, -100, 0), groundParams)
								if safetyRay then
									local landingY = closestBlock.Y + height
									local dropHeight = root.Position.Y - landingY
									local descentSpeed = math.clamp(dropHeight * 3, 75, 200)
									local timeToDescend = dropHeight / descentSpeed
									local timeToReach = closestDist / math.max(horizontalSpeed, FlyValue.Value)

									if remainingTime <= timeToReach + timeToDescend and airTimer > 0.25 then
										if landingY < root.Position.Y then
											local landingCheck = workspace:Raycast(Vector3.new(closestBlock.X, closestBlock.Y + 5, closestBlock.Z), Vector3.new(0, -500, 0), groundParams)
											if landingCheck and (os.clock() - lastExtendTime) > 0.7 then
												lastExtendTime = os.clock()
												airTimer = 0
												originalY = root.Position.Y
												targetY = landingY
												descendState = true
												createNotification("Fly", "Extended time by " .. remainingTime .. "s", 4)
											end
										end
									end
								end
							end
						end
					end
				end)
			else
				if bodyVel then
					bodyVel.MaxForce = Vector3.new(0, 0, 0)
				end
				TweenFrame:TweenSize(UDim2.new(0, 0, 1, 0), Enum.EasingDirection.InOut, Enum.EasingStyle.Linear, 0.1, true)
				ScreenGui.ScreenGui.Enabled = false
				RunLoops:UnbindFromHeartbeat("Fly")
			end
		end
	})
	FlyValue = Fly.CreateSlider({
		Name = "value",
		Min = 0,
		Max = 23,
		Default = 23,
		Round = 1
	})
	FlyVerticalValue = Fly.CreateSlider({
		Name = "vertical value",
		Min = 0,
		Max = 100,
		Default = 50,
		Round = 1
	})
	ProgressBar = Fly.CreateToggle({
		Name = "ProgressBar",
		Default = true
	})
	extendedFly = Fly.CreateToggle({
		Name = "ExtendedFly",
		Default = true
	})
	bypass = Fly.CreateToggle({
		Name = "bypassTimer",
		Default = false
	})
end)

runcode(function()
    local LongFlyValue, LongFlyDuration, LongFlySlopeAngle = {}, {}, {}
    local smartFly = {}
    local overheadCheck = false
    local phase, noBlockTimer = "0", 0
    local lastActivated, cooldown = 0, 0
    local GRACE_PERIOD = 0.03

    local function stopLongFly(root, reason)
        if bodyVel then
            bodyVel.Velocity = Vector3.zero
            bodyVel.MaxForce = Vector3.zero
            bodyVel:Destroy(); bodyVel = nil
        end
        if root then root.AssemblyLinearVelocity = Vector3.zero end
        phase, noBlockTimer = "0", 0
        RunLoops:UnbindFromHeartbeat("LongFly")
        if LongFly.Enabled then LongFly.Toggle() end
        createNotification("LongFly", reason, 2)
    end

    LongFly = GuiLibrary.Registry.blatantPanel.API.CreateOptionsButton({
        Name = "LongFly",
        New = true,
        Function = function(callback)
            if callback then
                if os.clock() - lastActivated < cooldown then
                    createNotification("LongFly", "On cooldown", 2)
                    if LongFly.Enabled then LongFly.Toggle() end
                    return
                end
                lastActivated = os.clock()

                if Fly and Fly.Enabled then
                    createNotification("LongFly", "Disable Fly first", 3)
                    if LongFly.Enabled then LongFly.Toggle() end
                    return
                end

                local char = lplr.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                local humanoid = char and char:FindFirstChildOfClass("Humanoid")
                if not root or not humanoid then
                    if LongFly.Enabled then LongFly.Toggle() end
                    return
                end

                if Speed.Enabled then
                    RunLoops:UnbindFromHeartbeat("Speed")
                    if bodyVel then bodyVel.MaxForce = Vector3.zero end
                end

                root.Anchored = true
                root.AssemblyLinearVelocity = Vector3.zero
                task.wait(0.5)
                root.Anchored = false

                if Speed.Enabled then Speed.Function(true) end

                local camLook = workspace.CurrentCamera.CFrame.LookVector
                local lockedDir = Vector3.new(camLook.X, 0, camLook.Z)
                local horizontalMag = lockedDir.Magnitude
                local lockedDirUnit = horizontalMag > 0.01 and lockedDir.Unit or Vector3.new(0, 0, 0)
                local slopeRad = horizontalMag > 0.01 and math.rad(LongFlySlopeAngle.Value) or 0
                local flyDir = Vector3.new(lockedDirUnit.X * math.cos(slopeRad), math.sin(slopeRad) * (horizontalMag > 0.01 and 1 or 0), lockedDirUnit.Z * math.cos(slopeRad))
                local startTime, lastTick = os.clock(), os.clock()
                local startPos = root.Position
                local timeUnderBlock, totalTime = 0, 0
                local wasUnderBlock, smartStopArmed = false, false

                phase, noBlockTimer = overheadCheck.Enabled and "1" or "0", 0
                createBodyVel()
                bodyVel.MaxForce = Vector3.new(1e5, 1e5, 1e5)
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)

                RunLoops:BindToHeartbeat("LongFly", function()
                    local now = os.clock()
                    local dt = math.min(now - lastTick, 0.01)
                    lastTick = now

                    root = lplr.Character and lplr.Character:FindFirstChild("HumanoidRootPart")
                    humanoid = lplr.Character and lplr.Character:FindFirstChildOfClass("Humanoid")
                    if not root then return end

                    totalTime += dt

                    local rayParams = RaycastParams.new()
                    rayParams.FilterDescendantsInstances = { lplr.Character }
                    rayParams.FilterType = Enum.RaycastFilterType.Exclude

                    local currentlyUnderBlock = workspace:Raycast(root.Position, Vector3.new(0, -100, 0), rayParams) ~= nil
                    if currentlyUnderBlock then timeUnderBlock += dt; wasUnderBlock = true end

                    if smartFly.Enabled and wasUnderBlock and currentlyUnderBlock then
                        local blockCoverage = timeUnderBlock / math.max(totalTime, 0.001)
                        local flightProgress = (now - startTime) / LongFlyDuration.Value
                        if blockCoverage >= 0.25 and flightProgress >= 0.4 and not smartStopArmed then
                            smartStopArmed = true
                        end
                        if smartStopArmed then
                            local flatDir = Vector3.new(flyDir.X, 0, flyDir.Z).Unit
                            local missingCount = 0
                            for i = 1, 5 do
                                local checkPos = root.Position + flatDir * (20 + i * 12)
                                if not workspace:Raycast(Vector3.new(checkPos.X, root.Position.Y + 5, checkPos.Z), Vector3.new(0, -150, 0), rayParams) then
                                    missingCount += 1
                                end
                            end
                            if missingCount >= 4 then
                                local dist = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(startPos.X, 0, startPos.Z)).Magnitude
                                cooldown = math.clamp((dist / 50) ^ 2.6, 1, 4)
                                stopLongFly(root, "SmartFly: void ahead")
                                return
                            end
                        end
                    end

                    if now - startTime >= LongFlyDuration.Value then
                        local dist = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(startPos.X, 0, startPos.Z)).Magnitude
                        cooldown = math.clamp((dist / 50) ^ 2.5, 1, 3)
                        stopLongFly(root, "Ended")
                        return
                    end

                    if overheadCheck.Enabled then
                        if phase == "1" then
                            if currentlyUnderBlock then phase, noBlockTimer = "3", 0 end
                        elseif phase == "3" then
                            if currentlyUnderBlock then noBlockTimer = 0
                            else
                                noBlockTimer += dt
                                if noBlockTimer >= GRACE_PERIOD then phase, noBlockTimer = "2", 0 end
                            end
                        elseif phase == "2" then
                            if currentlyUnderBlock then
                                local dist = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(startPos.X, 0, startPos.Z)).Magnitude
                                cooldown = math.clamp((dist / 50) ^ 2.5, 1, 3)
                                stopLongFly(root, "Entered block coverage")
                                return
                            end
                        end
                    end

                    if humanoid then
                        local s = humanoid:GetState()
                        if s == Enum.HumanoidStateType.Running or s == Enum.HumanoidStateType.RunningNoPhysics or s == Enum.HumanoidStateType.Landed then
                            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                        end
                    end

                    local speed = LongFlyValue.Value + SpeedMultiplier()
                    root.CFrame += flyDir * speed * dt
                    if bodyVel then bodyVel.Velocity = flyDir * speed end
                end)
            else
                local root = lplr.Character and lplr.Character:FindFirstChild("HumanoidRootPart")
                stopLongFly(root, "Disabled")
            end
        end
    })
    LongFlyValue = LongFly.CreateSlider({
        Name = "speed",
        Min = 0,
        Max = 300,
        Default = 300,
        Round = 1
    })
    LongFlyDuration = LongFly.CreateSlider({
        Name = "duration",
        Min = 0.1,
        Max = 2,
        Default = 0.24,
        Round = 1
    })
    LongFlySlopeAngle = LongFly.CreateSlider({
        Name = "slope angle",
        Min = 0,
        Max = 60,
        Default = 15,
        Round = 1
    })
    overheadCheck = LongFly.CreateToggle({
        Name = "Stop Under Block",
        Default = false,
        Function = function()
            phase, noBlockTimer = "0", 0
        end
    })
    smartFly = LongFly.CreateToggle({
        Name = "SmartFly",
        Default = false,
        Function = function() end
    })
end)

runcode(function()
    local ProjectileAura = {}
    local last = 0
    local tracer

    local function createTracer()
        if tracer then tracer:Destroy() end

        tracer = Instance.new("Part")
        tracer.Anchored = true
        tracer.CanCollide = false
        tracer.Material = Enum.Material.Neon
        tracer.Size = Vector3.new(0.1, 0.1, 1)
        tracer.Parent = workspace
    end

    local function updateTracer(from, to)
        if not tracer then return end
        local dist = (to - from).Magnitude
        tracer.Size = Vector3.new(0.1, 0.1, dist)
        tracer.CFrame = CFrame.new(from, to) * CFrame.new(0, 0, -dist/2)
    end

    local function removeTracer()
        if tracer then
            tracer:Destroy()
            tracer = nil
        end
    end

    ProjectileAura = GuiLibrary.Registry.blatantPanel.API.CreateOptionsButton({
        Name = "ProjectileAura",
        Beta = true,
        Function = function(state)
            if state then
                createTracer()

                RunLoops:BindToHeartbeat("ProjectileAura", function()
                    local t = PlayerUtility.GetNearestEntities(100, false, false)[1]
                    local m = lplr.Character and lplr.Character:FindFirstChild("HumanoidRootPart")

                    if not t or not m then
                        removeTracer()
                        return
                    end

                    local r = t.character and t.character:FindFirstChild("HumanoidRootPart")
                    if not r then
                        removeTracer()
                        return
                    end

                    local pos = r.Position
                    local vel = r.Velocity

                    local speed = 300
                    local time = (pos - m.Position).Magnitude / speed

                    local pred = pos + vel * time + Vector3.new(0,30,0) * time^2 * 0.5

                    local dir = (pred - m.Position).Unit
                    local velocity = dir * speed

                    updateTracer(m.Position, pred)

                    if tick() - last >= 0.3 then
                        local id = tick()

                        game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("ItemsRemotes"):WaitForChild("ShootProjectile"):FireServer(
                            id,
                            "Bow", -- or CrossBow
                            dir,
                            velocity,
                            CFrame.lookAt(m.Position, pred)
                        )

                        removeTracer()
                        createTracer()

                        last = tick()
                    end
                end)
            else
                RunLoops:UnbindFromHeartbeat("ProjectileAura")
                removeTracer()
            end
        end
    })
end)

runcode(function()
    local old
    local playerHook
    local hookedConnection

    local blacklistedStates = {
        Enum.HumanoidStateType.FallingDown,
        Enum.HumanoidStateType.Physics,
        Enum.HumanoidStateType.Ragdoll,
        Enum.HumanoidStateType.PlatformStanding
    }

    local function disableStates(hum)
        for _, v in next, blacklistedStates do
            hum:SetStateEnabled(v, false)
        end
    end

    local Strength = {}
    local Velocity = {}; Velocity = GuiLibrary.Registry.combatPanel.API.CreateOptionsButton({
        Name = "Velocity",
        Function = function(callback)
            if callback then
                local connection = getconnections(ReplicatedStorage.Remotes.Knockback.OnClientEvent)[1]
                if not connection or not connection.Function then return end

                old = old or connection.Function

                hookfunction(connection.Function, function(...)
                    return nil
                end)

                hookedConnection = connection

                if lplr.Character and lplr.Character:FindFirstChild("Humanoid") then
                    disableStates(lplr.Character.Humanoid)
                end

                playerHook = lplr.CharacterAdded:Connect(function(chr)
                    disableStates(chr:WaitForChild("Humanoid"))
                end)

            else
                if hookedConnection and old then
                    hookfunction(hookedConnection.Function, old)
                end

                old = nil
                hookedConnection = nil

                if playerHook then
                    playerHook:Disconnect()
                    playerHook = nil
                end
            end
        end
    })

    Strength = Velocity.CreateSlider({
        Name = "Strength",
        Min = 0,
        Max = 100,
        Default = 0
    })
end)

runcode(function()
    local saved, saving = {}, false
    local rConn, hConn, lastHp = nil, nil, 0
    local lowestY = math.huge
    local inv = require(ReplicatedStorage.Modules.InventoryHandler)
    local items = require(ReplicatedStorage.Modules.DataModules.ItemsData)
    local KeepInv

    for _, v in pairs(workspace:GetDescendants()) do
        if v:IsA("BasePart") and v.CanCollide and v.Transparency < 1 then
            local y = v.Position.Y - v.Size.Y / 2
            if y < lowestY then lowestY = y end
        end
    end

    local chestfuncs = {}

    chestfuncs.Loop = function(loop, cycle, index, teams)
        if not PlayerUtility.IsAlive(lplr) then return end

        if lplr.Team == "Spectators" or teams == nil or #teams == 0 then
            teams, index, cycle = getTeams(), 1, 1
            return
        end

        local t = teams[index]
        local chest = ReplicatedStorage.TeamChestsStorage:FindFirstChild(t)
        if chest and t ~= "Spectators" then
            local slot = chest:FindFirstChild(tostring(cycle))
            local name = slot and slot:GetAttribute("Name")
            if name and name ~= "" then
                ReplicatedStorage.Remotes.TakeItemFromChest:FireServer(t, cycle, tostring(cycle))
            end
        end

        index += 1
        if index > #teams then
            index, cycle, teams = 1, cycle % 3 + 1, getTeams()
        end

        return cycle, index, teams
    end

    chestfuncs.Save = function(team)
        if saving then return end
        saving, saved = true, {}
        RunLoops:UnbindFromHeartbeat("ChestManagerLoop")
        RunLoops:BindToHeartbeat("ChestManagerSave", function()
            if not PlayerUtility.IsAlive(lplr) then return end
            for _, invy in pairs(inv.Inventories) do
                for i, slot in pairs(invy.Items) do
                    if slot.Name ~= "" then
                        local data = items[slot.Name]
                        if data and data.CanStoreInChest then
                            local key = slot.Name .. "_" .. i
                            if not saved[key] then
                                saved[key] = true
                                ReplicatedStorage.Remotes.PutItemInChest:FireServer(slot.Name, team, i + 3)
                            end
                        end
                    end
                end
            end
        end)
    end

    chestfuncs.Restore = function(loop)
        RunLoops:UnbindFromHeartbeat("ChestManagerSave")
        local team = lplr.Team and lplr.Team.Name
        if not team or team == "Spectators" or not next(saved) then
            saved, saving = {}, false
            return
        end
        local slots = {}
        for key in pairs(saved) do
            local s = key:match("_(%d+)")
            if s then table.insert(slots, tonumber(s)) end
        end
        saved, saving = {}, false
        task.spawn(function()
            for _, s in ipairs(slots) do
                task.wait(0.35)
                ReplicatedStorage.Remotes.TakeItemFromChest:FireServer(team, s + 3, tostring(s + 3))
            end
            RunLoops:BindToHeartbeat("ChestManagerLoop", loop)
        end)
    end

    chestfuncs.Cleanup = function()
        RunLoops:UnbindFromHeartbeat("ChestManagerSave")
        RunLoops:UnbindFromHeartbeat("ChestManagerVoid")
        if hConn then hConn:Disconnect() hConn = nil end
    end

    chestfuncs.Hook = function(loop)
        chestfuncs.Cleanup()
        local char = lplr.Character
        if not char then return end
        local hum = char:WaitForChild("Humanoid")
        local hrp = char:WaitForChild("HumanoidRootPart")
        lastHp = hum.Health

        RunLoops:BindToHeartbeat("ChestManagerVoid", function()
            if not KeepInv.Enabled or saving then return end
            if hrp and hrp.Parent and hrp.Position.Y <= lowestY - 15 then
                local team = lplr.Team and lplr.Team.Name
                if team and team ~= "Spectators" then chestfuncs.Save(team) end
            end
        end)

        hConn = hum.HealthChanged:Connect(function(h)
            if not KeepInv.Enabled then return end
            local dmg = lastHp - h
            lastHp = h
            if saving or dmg <= 0 then return end
            local team = lplr.Team and lplr.Team.Name
            if not team or team == "Spectators" then return end
            if h <= 0 or h <= dmg then
                chestfuncs.Save(team)
            else
                chestfuncs.Restore(loop)
            end
        end)
    end

    local CM = GuiLibrary.Registry.utillityPanel.API.CreateOptionsButton({
        Name = "ChestManager",
        New = true,
        Function = function(cb)
            if data.gamemode.current ~= "Ranked 1v1" and data.gamemode.current ~= "Ranked 4v4" then
                print("worked")
                local cycle, index, teams = 1, 1, {}

                local function loop()
                    cycle, index, teams = chestfuncs.Loop(loop, cycle, index, teams)
                end

                if cb then
                    teams = getTeams()
                    if rConn then rConn:Disconnect() end
                    rConn = lplr.CharacterAdded:Connect(function()
                        task.wait()
                        chestfuncs.Restore(loop)
                        chestfuncs.Hook(loop)
                    end)
                    chestfuncs.Hook(loop)
                    RunLoops:BindToHeartbeat("ChestManagerLoop", loop)
                else
                    RunLoops:UnbindFromHeartbeat("ChestManagerLoop")
                    chestfuncs.Cleanup()
                    if rConn then rConn:Disconnect() rConn = nil end
                    saved, saving = {}, false
                end
            end
        end
    })

    KeepInv = CM.CreateToggle({
        Name = "KeepInv",
        Function = function() end
    })
end)

runcode(function()
    local ThemeDropdown = {}
    local GameThemes = {}

    local cleanupSnow = function()
        local existing = workspace:FindFirstChild('Snowfall_Client')
        if existing then existing:Destroy() end
    end

    local themes = {
        Default = function()
            cleanupSnow()
            loadstring([[
                local L=game:GetService('Lighting');L:ClearAllChildren();task.wait(0.3)
                L.Ambient=Color3.new(0.576471,0.67451,0.784314);L.Brightness=3;L.ColorShift_Bottom=Color3.new(0.294118,0.235294,0.192157);L.ColorShift_Top=Color3.new(0,0,0);L.OutdoorAmbient=Color3.new(0.576471,0.67451,0.784314);L.FogColor=Color3.new(0.752941,0.752941,0.752941);L.FogEnd=100000;L.FogStart=0;L.GlobalShadows=true;L.GeographicLatitude=45;L.ExposureCompensation=0;L.EnvironmentDiffuseScale=1;L.EnvironmentSpecularScale=1;L.ClockTime=14.5;L.TimeOfDay='14:30:00';L.ShadowSoftness=0.1;L.Technology=Enum.Technology.ShadowMap
                local blo=Instance.new('BloomEffect',L);blo.Name='Bloom';blo.Enabled=true;blo.Intensity=1;blo.Size=10;blo.Threshold=2
                local col=Instance.new('ColorCorrectionEffect',L);col.Name='DeathBarrierEffect';col.Enabled=false;col.Brightness=0;col.Contrast=0;col.Saturation=0;col.TintColor=Color3.new(0.858824,0.627451,1)
                local col2=Instance.new('ColorCorrectionEffect',L);col2.Name='ColorCorrection';col2.Enabled=true;col2.Brightness=0;col2.Contrast=0.05;col2.Saturation=0.05;col2.TintColor=Color3.new(1,1,1)
                local sky=Instance.new('Sky',L);sky.Name='Sky';sky.CelestialBodiesShown=true;sky.SunAngularSize=21;sky.MoonAngularSize=11;sky.SkyboxBk='rbxassetid://93968881652239';sky.SkyboxDn='rbxassetid://102254730940508';sky.SkyboxFt='rbxassetid://93968881652239';sky.SkyboxLf='rbxassetid://93968881652239';sky.SkyboxRt='rbxassetid://93968881652239';sky.SkyboxUp='rbxassetid://112261788034018';sky.StarCount=3000;sky.SunTextureId='';sky.MoonTextureId=''
                local col3=Instance.new('ColorCorrectionEffect',L);col3.Name='SmokeColorCorrection';col3.Enabled=false;col3.Brightness=0;col3.Contrast=0;col3.Saturation=-0.5;col3.TintColor=Color3.new(0.588235,0.588235,0.588235)
            ]])()
        end,

        Winter = function()
            cleanupSnow()
            loadstring([[
                local L=game:GetService('Lighting');L:ClearAllChildren();task.wait(0.3)
                L.Ambient=Color3.new(0,0,0);L.Brightness=1;L.ColorShift_Bottom=Color3.new(0,0,0);L.ColorShift_Top=Color3.new(0,0,0);L.OutdoorAmbient=Color3.new(0.576471,0.6,0.760784);L.FogColor=Color3.new(0.576471,0.6,0.760784);L.FogEnd=300;L.FogStart=15;L.GlobalShadows=true;L.GeographicLatitude=23.5;L.ExposureCompensation=0;L.EnvironmentDiffuseScale=0.4;L.EnvironmentSpecularScale=0.6;L.ClockTime=12;L.TimeOfDay='12:00:00';L.ShadowSoftness=0.07;L.Technology=Enum.Technology.Future
                local sky=Instance.new('Sky',L);sky.CelestialBodiesShown=false;sky.SkyboxBk='http://www.roblox.com/asset/?id=4514139911';sky.SkyboxDn='http://www.roblox.com/asset/?id=4514139911';sky.SkyboxFt='http://www.roblox.com/asset/?id=4514139911';sky.SkyboxLf='http://www.roblox.com/asset/?id=4514139911';sky.SkyboxRt='http://www.roblox.com/asset/?id=4514139911';sky.SkyboxUp='http://www.roblox.com/asset/?id=4514139911';sky.StarCount=3000
                local atm=Instance.new('Atmosphere',L);atm.Name='Blizzard_Atmosphere';atm.Density=0.531;atm.Offset=0.281;atm.Color=Color3.new(0.686275,0.733333,0.780392);atm.Decay=Color3.new(0.619608,0.666667,0.784314);atm.Glare=2.69;atm.Haze=10
            ]])()

            local lp = game:GetService('Players').LocalPlayer
            local rs = game:GetService('RunService')
            local folder = Instance.new('Folder', workspace); folder.Name = 'Snowfall_Client'

            local GRID_COLS, GRID_ROWS = 10, 8
            local PLANE_W, PLANE_H = 100, 80
            local ABOVE_OFFSET, Z_OFFSET, RAY_LEN, UPDATE_RATE = 40, 50, 90, 0.5
            local cellW, cellH = PLANE_W / GRID_COLS, PLANE_H / GRID_ROWS

            local rayParams = RaycastParams.new()
            rayParams.FilterType = Enum.RaycastFilterType.Exclude

            local function makeEmitter(parent)
                local e = Instance.new('ParticleEmitter', parent); e.Name='Particle';e.Texture='rbxassetid://127302768524882'
                e.Rate=0;e.Lifetime=NumberRange.new(6,8);e.Speed=NumberRange.new(20,50);e.Drag=0
                e.Rotation=NumberRange.new(-15,15);e.RotSpeed=NumberRange.new(-90,90);e.VelocitySpread=5
                e.SpreadAngle=Vector2.new(5,5);e.LightInfluence=1;e.LightEmission=0;e.ZOffset=0
                e.Acceleration=Vector3.new(0,-0.4,0);e.EmissionDirection=Enum.NormalId.Front
                e.Orientation=Enum.ParticleOrientation.FacingCamera;e.Shape=Enum.ParticleEmitterShape.Box
                e.ShapeStyle=Enum.ParticleEmitterShapeStyle.Volume;e.ShapeInOut=Enum.ParticleEmitterShapeInOut.Outward
                e.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,1,1)),ColorSequenceKeypoint.new(1,Color3.new(1,1,1))})
                e.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,1.875),NumberSequenceKeypoint.new(0.374999,1.25),NumberSequenceKeypoint.new(1,0)})
                e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(0.501247,0.4375),NumberSequenceKeypoint.new(1,0)})
                e.Enabled=false; return e
            end

            local cells = {}
            for row = 1, GRID_ROWS do
                cells[row] = {}
                for col = 1, GRID_COLS do
                    local p = Instance.new('Part', folder); p.Anchored=true;p.CanCollide=false;p.Transparency=1
                    p.Size=Vector3.new(cellW,cellH,1);p.CFrame=CFrame.new(0,-9999,0)
                    cells[row][col] = { part=p, emitter=makeEmitter(p) }
                end
            end

            local lastUpdate = 0
            local conn = rs.Heartbeat:Connect(function()
                local char = lp.Character
                local hrp = char and char:FindFirstChild('HumanoidRootPart')
                if not hrp then return end

                local charParts = {}
                for _, v in ipairs(char:GetDescendants()) do if v:IsA('BasePart') then table.insert(charParts, v) end end
                rayParams.FilterDescendantsInstances = charParts

                local now = tick()
                if (now - lastUpdate) < UPDATE_RATE then return end
                lastUpdate = now

                local origin = hrp.Position + Vector3.new(0, ABOVE_OFFSET, 0)
                local look, right, up = hrp.CFrame.LookVector, hrp.CFrame.RightVector, hrp.CFrame.UpVector
                local planeCenter = origin + look * Z_OFFSET
                local yaw = CFrame.Angles(0, math.atan2(look.X, look.Z), 0)

                for row = 1, GRID_ROWS do for col = 1, GRID_COLS do
                    local cell = cells[row][col]
                    local cellCenter = planeCenter + right * ((col-0.5)*cellW - PLANE_W*0.5) + up * ((row-0.5)*cellH - PLANE_H*0.5)
                    local result = workspace:Raycast(cellCenter, Vector3.new(0,-RAY_LEN,0), rayParams)
                    if result then
                        cell.part.CFrame = CFrame.new(cellCenter.X, result.Position.Y + 1, cellCenter.Z) * yaw
                        cell.part.Size = Vector3.new(cellW, 1, 1); cell.emitter.Rate=10
                    else
                        cell.part.CFrame = CFrame.new(cellCenter) * yaw
                        cell.part.Size = Vector3.new(cellW, cellH, 1); cell.emitter.Rate=60
                    end
                    cell.emitter.Enabled = true
                end end
            end)

            folder.AncestryChanged:Connect(function() if not folder.Parent then conn:Disconnect() end end)
        end,

        BloodMoon = function()
            cleanupSnow()
            loadstring([[
                local L=game:GetService('Lighting');L:ClearAllChildren();task.wait(0.3)
                L.Ambient=Color3.new(0.0784314,0.0784314,0.0784314);L.Brightness=0.5;L.ColorShift_Bottom=Color3.new(0,0,0);L.ColorShift_Top=Color3.new(0,0,0);L.OutdoorAmbient=Color3.new(0.423529,0.160784,0.164706);L.FogColor=Color3.new(0,0,0);L.FogEnd=300;L.FogStart=15;L.GlobalShadows=true;L.GeographicLatitude=23.5;L.ExposureCompensation=0;L.EnvironmentDiffuseScale=0.4;L.EnvironmentSpecularScale=0.6;L.ClockTime=0;L.TimeOfDay='00:00:00';L.ShadowSoftness=0.07;L.Technology=Enum.Technology.Future
                local blu=Instance.new('BlurEffect',L);blu.Name='Blur';blu.Enabled=true;blu.Size=1
                local blu2=Instance.new('BlurEffect',L);blu2.Name='Death_Blur';blu2.Enabled=false;blu2.Size=24
                local blo=Instance.new('BloomEffect',L);blo.Name='DefaultBloom';blo.Enabled=true;blo.Intensity=0.2;blo.Size=100;blo.Threshold=0.8
                local dep=Instance.new('DepthOfFieldEffect',L);dep.Name='FogDof';dep.Enabled=false;dep.FarIntensity=0.2;dep.FocusDistance=0;dep.InFocusRadius=30;dep.NearIntensity=0
                local col=Instance.new('ColorCorrectionEffect',L);col.Name='LowHealth_CC';col.Enabled=false;col.Brightness=0;col.Contrast=0;col.Saturation=-1;col.TintColor=Color3.new(1,1,1)
                local dep2=Instance.new('DepthOfFieldEffect',L);dep2.Name='LowHealth_Dof';dep2.Enabled=false;dep2.FarIntensity=0.5;dep2.FocusDistance=0;dep2.InFocusRadius=5;dep2.NearIntensity=0
                local col2=Instance.new('ColorCorrectionEffect',L);col2.Name='Saturation';col2.Enabled=true;col2.Brightness=0;col2.Contrast=0;col2.Saturation=0.4;col2.TintColor=Color3.new(1,1,1)
                local dep3=Instance.new('DepthOfFieldEffect',L);dep3.Name='ZoomDOF';dep3.Enabled=false;dep3.FarIntensity=0;dep3.FocusDistance=200;dep3.InFocusRadius=200;dep3.NearIntensity=0
                local col3=Instance.new('ColorCorrectionEffect',L);col3.Name='HitSaturation';col3.Enabled=true;col3.Brightness=0;col3.Contrast=0;col3.Saturation=0;col3.TintColor=Color3.new(1,1,1)
                local col4=Instance.new('ColorCorrectionEffect',L);col4.Name='PoisonEffect';col4.Enabled=true;col4.Brightness=0;col4.Contrast=0;col4.Saturation=0;col4.TintColor=Color3.new(1,1,1)
                local col5=Instance.new('ColorCorrectionEffect',L);col5.Name='Bear5ColorCorrection';col5.Enabled=true;col5.Brightness=0;col5.Contrast=0;col5.Saturation=0;col5.TintColor=Color3.new(1,1,1)
                local col6=Instance.new('ColorCorrectionEffect',L);col6.Name='HubCC';col6.Enabled=false;col6.Brightness=0;col6.Contrast=0;col6.Saturation=0;col6.TintColor=Color3.new(0.184314,0.603922,1)
                local blu3=Instance.new('BlurEffect',L);blu3.Name='HubBlur';blu3.Enabled=false;blu3.Size=24
                local sky=Instance.new('Sky',L);sky.Name='Sky';sky.CelestialBodiesShown=false;sky.SunAngularSize=0;sky.MoonAngularSize=0;sky.SkyboxBk='http://www.roblox.com/asset/?id=4514139911';sky.SkyboxDn='http://www.roblox.com/asset/?id=4514139911';sky.SkyboxFt='http://www.roblox.com/asset/?id=4514139911';sky.SkyboxLf='http://www.roblox.com/asset/?id=4514139911';sky.SkyboxRt='http://www.roblox.com/asset/?id=4514139911';sky.SkyboxUp='http://www.roblox.com/asset/?id=4514139911';sky.StarCount=3000;sky.SunTextureId='';sky.MoonTextureId=''
                local atm=Instance.new('Atmosphere',L);atm.Name='BloodNight_Atmosphere';atm.Density=0.58;atm.Offset=0;atm.Color=Color3.new(0.254902,0.14902,0.152941);atm.Decay=Color3.new(0.27451,0.0431373,0.0509804);atm.Glare=0;atm.Haze=4.47
            ]])()
        end,

        Nighttime = function()
            cleanupSnow()
            loadstring([[
                local L=game:GetService('Lighting');L:ClearAllChildren();task.wait(0.3)
                L.Ambient=Color3.new(0.137255,0.137255,0.137255);L.Brightness=0.66;L.ColorShift_Bottom=Color3.new(0,0,0);L.ColorShift_Top=Color3.new(0,0,0);L.OutdoorAmbient=Color3.new(0.231373,0.231373,0.231373);L.FogColor=Color3.new(0.0235294,0.0235294,0.0235294);L.FogEnd=300;L.FogStart=15;L.GlobalShadows=true;L.GeographicLatitude=23.5;L.ExposureCompensation=0;L.EnvironmentDiffuseScale=0.4;L.EnvironmentSpecularScale=0.6;L.ClockTime=0;L.TimeOfDay='00:00:00';L.ShadowSoftness=0.07;L.Technology=Enum.Technology.Future
                local blu=Instance.new('BlurEffect',L);blu.Name='Blur';blu.Enabled=true;blu.Size=1
                local blo=Instance.new('BloomEffect',L);blo.Name='DefaultBloom';blo.Enabled=true;blo.Intensity=0.2;blo.Size=100;blo.Threshold=0.8
                local col2=Instance.new('ColorCorrectionEffect',L);col2.Name='Saturation';col2.Enabled=true;col2.Brightness=0;col2.Contrast=0;col2.Saturation=0.4;col2.TintColor=Color3.new(1,1,1)
                local sky=Instance.new('Sky',L);sky.Name='Sky';sky.CelestialBodiesShown=false;sky.SkyboxBk='http://www.roblox.com/asset/?id=4514139911';sky.SkyboxDn='http://www.roblox.com/asset/?id=4514139911';sky.SkyboxFt='http://www.roblox.com/asset/?id=4514139911';sky.SkyboxLf='http://www.roblox.com/asset/?id=4514139911';sky.SkyboxRt='http://www.roblox.com/asset/?id=4514139911';sky.SkyboxUp='http://www.roblox.com/asset/?id=4514139911';sky.StarCount=3000;sky.SunTextureId='';sky.MoonTextureId=''
            ]])()
        end,

        Foggy = function()
            cleanupSnow()
            loadstring([[
                local L=game:GetService('Lighting');L:ClearAllChildren();task.wait(0.3)
                L.Ambient=Color3.new(0,0,0);L.Brightness=1;L.ColorShift_Bottom=Color3.new(0,0,0);L.ColorShift_Top=Color3.new(0,0,0);L.OutdoorAmbient=Color3.new(0.431373,0.431373,0.431373);L.FogColor=Color3.new(0.521569,0.521569,0.521569);L.FogEnd=300;L.FogStart=15;L.GlobalShadows=true;L.GeographicLatitude=23.5;L.ExposureCompensation=0;L.EnvironmentDiffuseScale=0.4;L.EnvironmentSpecularScale=0.6;L.ClockTime=12;L.TimeOfDay='12:00:00';L.ShadowSoftness=0.07;L.Technology=Enum.Technology.Future
                local blu=Instance.new('BlurEffect',L);blu.Name='Blur';blu.Enabled=true;blu.Size=1
                local blo=Instance.new('BloomEffect',L);blo.Name='DefaultBloom';blo.Enabled=true;blo.Intensity=0.2;blo.Size=100;blo.Threshold=0.8
                local col2=Instance.new('ColorCorrectionEffect',L);col2.Name='Saturation';col2.Enabled=true;col2.Brightness=0;col2.Contrast=0;col2.Saturation=0.4;col2.TintColor=Color3.new(1,1,1)
                local sky=Instance.new('Sky',L);sky.Name='Sky';sky.CelestialBodiesShown=false;sky.SkyboxBk='http://www.roblox.com/asset/?id=4514139911';sky.SkyboxDn='http://www.roblox.com/asset/?id=4514139911';sky.SkyboxFt='http://www.roblox.com/asset/?id=4514139911';sky.SkyboxLf='http://www.roblox.com/asset/?id=4514139911';sky.SkyboxRt='http://www.roblox.com/asset/?id=4514139911';sky.SkyboxUp='http://www.roblox.com/asset/?id=4514139911';sky.StarCount=3000;sky.SunTextureId='';sky.MoonTextureId=''
                local atm=Instance.new('Atmosphere',L);atm.Name='FoggyDay_Atmosphere';atm.Density=0.675;atm.Offset=0;atm.Color=Color3.new(0.780392,0.780392,0.780392);atm.Decay=Color3.new(0.454902,0.454902,0.454902);atm.Glare=4.95;atm.Haze=2.62
            ]])()
        end,
    }

    GameThemes = GuiLibrary.Registry.utillityPanel.API.CreateOptionsButton({
        Name = "GameThemes",
        Function = function(callback)
            if callback then
                themes[ThemeDropdown.Value]()
            else
                cleanupSnow()
            end
        end
    })
    ThemeDropdown = GameThemes.CreateDropdown({
        Name = "theme",
        List = {"Default", "Winter", "BloodMoon", "Nighttime", "Foggy"},
        Default = "Default",
        Function = function(selected)
            if GameThemes.Enabled and themes[selected] then
                themes[selected]()
            end
        end
    })
end)