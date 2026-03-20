

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

local loopTable = {}
local data = {Attacking = false, attackingEntity = nil}

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

local hooked = {}

local function hookValue(plr, v)
    if not hooked[plr] then return end
    table.insert(hooked[plr].items, v)
end

local function unhookValue(plr, v)
    if not hooked[plr] then return end
    local t = hooked[plr].items
    local i = table.find(t, v)
    if i then
        table.remove(t, i)
    end
end

local hookinv = function(plr)
    plr = plr or lplr
    local inv = plr.Inventory

    hooked[plr] = {
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

local getitem = function(name, plr)
    plr = plr or lplr
    if not hooked[plr] then return nil end

    for _, v in ipairs(hooked[plr].items) do
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
                    data.Attacking, data.attackingEntity = true, char

                    local serverTime = workspace:GetServerTimeNow()

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
                    lplr.Character.PrimaryPart.CFrame = CFrame.lookAt(lplr.Character.HumanoidRootPart.Position, Vector3.new(root.Position.X, lplr.Character.HumanoidRootPart.Position.Y, root.Position.Z))

                    if (lastDamage[humanoid] == 0 and lastAttack[humanoid] == 0) or (lastDamage[humanoid] and serverTime - lastDamage[humanoid] >= 0.1) then

                        if serverTime - lastAttack[humanoid] >= 0.1 then
                            lastAttack[humanoid] = serverTime

                            if Swing.Enabled then
                                lplr.Character.Humanoid:FindFirstChild("Animator"):LoadAnimation(
                                    (function(a)
                                        a.AnimationId = "rbxassetid://123800159244236"
                                        return a
                                    end)(Instance.new("Animation"))
                                ):Play()
                            end

                            attack(char)
                            print(char)
                            print(swordtype)
                            --if FacePlayer.Enabled and not LongFly.Enabled then
                           -- end
                        end
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

			local humanoidRootPart = lplr.Character:FindFirstChild("HumanoidRootPart")
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

			local function refreshParams()
				char = lplr.Character
				root = char and char:FindFirstChild("HumanoidRootPart")
				humanoid = char and char:FindFirstChildOfClass("Humanoid")
				if char then
					groundParams.FilterDescendantsInstances = { char }
				end
			end

			local isOverVoid = false
			local voidCheckTimer = 0

			if callback then
                TweenFrame.Size = UDim2.new(0, 0, 1, 0)
                TweenFrame.Position = UDim2.new(0, 0, 0, 0)
				ScreenGui.ScreenGui.Enabled = true

				RunLoops:BindToHeartbeat("Fly", function(dt)

					local currentTick = os.clock()
					local deltaTime = math.min(currentTick - lastTick, 0.1)
					lastTick = currentTick

					if not root or not root.Parent then
						refreshParams()
						return
					end

                    if bypass.Enabled then
                        airTimer = math.huge
                    else
                        airTimer += deltaTime
                    end

					local remainingTime = math.round(math.max(0.9 - airTimer, 0) * 10) / 10
					if bypass.Enabled then remainingTime = math.huge end

					voidCheckTimer += deltaTime
					if voidCheckTimer >= 0.1 then
						voidCheckTimer = 0
						isOverVoid = workspace:Raycast(root.Position, Vector3.new(0, -500, 0), groundParams) == nil
					end

					local moveDirection = (humanoid and humanoid.MoveDirection) or Vector3.zero

                    if ProgressBar.Enabled then
                        ScreenGui.ScreenGui.Enabled = true
                        TweenFrame.Visible = true
                    else
                        ScreenGui.ScreenGui.Enabled = false
                        TweenFrame.Visible = false
                    end
    
					UpdateSecondLeft(remainingTime)
                    
                    if ScreenGui.ScreenGui.Enabled then
                        TweenFrame:TweenSize(UDim2.new(1 - (airTimer / 2.5), 0, 1, 0), Enum.EasingDirection.InOut, Enum.EasingStyle.Linear, 0.1, true) 
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

					local ray = workspace:Raycast(
						root.Position,
						Vector3.new(0, -math.clamp(1000 + math.abs(root.AssemblyLinearVelocity.Y) * 8, 1000, 2500), 0),
						groundParams
					)

					if ray and ray.Distance <= height + 0.3 then
						airTimer = 0
						isOverVoid = false
					end

                    if descendState then

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

					if moveDirection.Magnitude > 0.1 and extendedFly.Enabled and not bypass.Enabled and not descendState and not ascendState and not isOverVoid then

						local vel = root.AssemblyLinearVelocity
						local horizontalSpeed = math.max(Vector3.new(vel.X, 0, vel.Z).Magnitude, FlyValue.Value + SpeedMultiplier())
						local scanStep = math.clamp(horizontalSpeed * 0.25, 4, 10)
						local maxScan = math.clamp(horizontalSpeed * 10, 60, 150)

						local closestBlock = nil
						local closestDist = math.huge

						for dist = scanStep, maxScan, scanStep do

							local forwardRay = workspace:Raycast(
								root.Position + moveDirection.Unit * dist + Vector3.new(0, 10, 0),
								Vector3.new(0, -40, 0),
								groundParams
							)

							if forwardRay then
								local hDist = (Vector3.new(forwardRay.Position.X, 0, forwardRay.Position.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude
								if hDist < closestDist then
									closestDist = hDist
									closestBlock = forwardRay.Position
								end
							end
						end

                        if closestBlock and not isOverVoid then
                            local landingY = closestBlock.Y + height
                            local dropHeight = root.Position.Y - landingY
                            local descentSpeed = math.clamp(dropHeight * 3, 75, 200)
                            local timeToDescend = dropHeight / descentSpeed
                            local timeToReach = closestDist / horizontalSpeed

                            if remainingTime <= timeToReach + timeToDescend then
                                if landingY < root.Position.Y then
                                    local landingCheck = workspace:Raycast(
                                        Vector3.new(closestBlock.X, closestBlock.Y + 5, closestBlock.Z),
                                        Vector3.new(0, -500, 0),
                                        groundParams
                                    )
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
				end)
			else
				if bodyVel then
					bodyVel.MaxForce = Vector3.new(0, 0, 0)
				end
				TweenFrame:TweenSize(
					UDim2.new(0, 0, 1, 0),
					Enum.EasingDirection.InOut,
					Enum.EasingStyle.Linear,
					0.1,
					true
				)
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
	damageBoost = Fly.CreateToggle({
		Name = "damageBoost",
		Default = true
	})
	bypass = Fly.CreateToggle({
		Name = "bypassTimer",
		Default = false
	})
end)

runcode(function()
    local LongFlyValue, LongFlyDuration, LongFlySlopeAngle = {}, {}, {}
    local overheadCheckEnabled = false
    local phase, noBlockTimer = "0", 0
    local GRACE_PERIOD = 0.03
    local lastActivated = 0

    LongFly = GuiLibrary.Registry.blatantPanel.API.CreateOptionsButton({
        Name = "LongFly",
        Beta = true,
        Function = function(callback)
            if callback then
                if os.clock() - lastActivated < 1.3 then
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

                local camLook = workspace.CurrentCamera.CFrame.LookVector
                local lockedDir = Vector3.new(camLook.X, 0, camLook.Z).Unit
                local slopeRad = math.rad(LongFlySlopeAngle.Value)
                local flyDir = Vector3.new(lockedDir.X * math.cos(slopeRad), math.sin(slopeRad), lockedDir.Z * math.cos(slopeRad))
                local startTime, lastTick = os.clock(), os.clock()

                phase, noBlockTimer = overheadCheckEnabled and "1" or "0", 0
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

                    if now - startTime >= LongFlyDuration.Value then
                        if bodyVel then
                            bodyVel.Velocity = Vector3.new(0, bodyVel.Velocity.Y, 0)
                            bodyVel:Destroy(); bodyVel = nil
                        end
                        phase, noBlockTimer = "0", 0
                        RunLoops:UnbindFromHeartbeat("LongFly")
                        if LongFly.Enabled then LongFly.Toggle() end
                        createNotification("LongFly", "Ended", 2)
                        return
                    end

                    if overheadCheckEnabled then
                        local p = RaycastParams.new()
                        p.FilterDescendantsInstances = { lplr.Character }
                        p.FilterType = Enum.RaycastFilterType.Exclude
                        local under = workspace:Raycast(root.Position, Vector3.new(0, -100, 0), p) ~= nil

                        if phase == "1" then
                            if under then
                                phase, noBlockTimer = "3", 0
                            end
                        elseif phase == "3" then
                            if under then
                                noBlockTimer = 0
                            else
                                noBlockTimer += dt
                                if noBlockTimer >= GRACE_PERIOD then
                                    phase, noBlockTimer = "2", 0
                                end
                            end
                        elseif phase == "2" then
                            if under then
                                if bodyVel then
                                    bodyVel.Velocity = Vector3.new(0, bodyVel.Velocity.Y, 0)
                                    bodyVel:Destroy(); bodyVel = nil
                                end
                                phase, noBlockTimer = "0", 0
                                RunLoops:UnbindFromHeartbeat("LongFly")
                                if LongFly.Enabled then LongFly.Toggle() end
                                createNotification("LongFly", "Entered block coverage", 2)
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
                if bodyVel then
                    bodyVel.Velocity = Vector3.new(0, bodyVel.Velocity.Y, 0)
                    bodyVel:Destroy(); bodyVel = nil
                end
                phase, noBlockTimer = "0", 0
                RunLoops:UnbindFromHeartbeat("LongFly")
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
        Default = 0.3,
        Round = 1
    })
    LongFlySlopeAngle = LongFly.CreateSlider({
        Name = "slope angle",
        Min = 0,
        Max = 60,
        Default = 15,
        Round = 1
    })
    LongFly.CreateToggle({
        Name = "Stop Under Block",
        Default = false,
        Function = function(state)
            overheadCheckEnabled = state
            phase, noBlockTimer = "0", 0
        end
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
    local cycle, index, teams = 1, 1, {}
    StealAllChests = GuiLibrary.Registry.utillityPanel.API.CreateOptionsButton({
        Name = "StealAllChests",
        New = true,
        Function = function(cb)
            if cb then
                teams = getTeams()
                RunLoops:BindToHeartbeat("StealAllChestsLoop", function()
                    if lplr.Team == "Spectators" or #teams == 0 then
                        teams, index, cycle = getTeams(), 1, 1
                        return
                    end
                    local t = teams[index]
                    local chest = game:GetService("ReplicatedStorage").TeamChestsStorage:FindFirstChild(t)
                    if chest and t ~= "Spectators" then
                        local slot = chest:FindFirstChild(tostring(cycle))
                        local name = slot and slot:GetAttribute("Name")
                        if name and name ~= "" then
                            game:GetService("ReplicatedStorage").Remotes.TakeItemFromChest:FireServer(t, cycle, tostring(cycle))
                        end
                    end
                    index += 1
                    if index > #teams then
                        index, cycle, teams = 1, cycle % 3 + 1, getTeams()
                    end
                end)
            else
                RunLoops:UnbindFromHeartbeat("StealAllChestsLoop")
            end
        end
    })
end)