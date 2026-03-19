local getcustomasset = getsynasset or getcustomasset
local request = syn and syn.request or http and http.request or http_request or request or function() end
local queueteleport = queue_for_teleport or queue_on_teleport or queueonteleport
local services = {}
local PlayerUtility = {}
local RunLoops = {RenderStepTable = {}, StepTable = {}, HeartTable = {}}

local runcode = function(func)
    return func()
end

for _, v in pairs(game:GetChildren()) do
    local success, service = pcall(function()
        return game:GetService(v.ClassName)
    end)

    if success then
        services[v.ClassName] = service
    end
end

local Players = cloneref(services.Players)
local RunService = cloneref(services.RunService)
local ReplicatedStorage = cloneref(services.ReplicatedStorage)
local Lighting = cloneref(services.Lighting)
local inputservice = cloneref(services.UserInputService)
local lplr = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local mouse = lplr:GetMouse()

local lib = phantom.UI
local funcs = phantom.ops

local notification = lib.toast

local gameData = {
    blockRaycast = RaycastParams.new()
}
PlayerUtility.lplrIsAlive = true
gameData.blockRaycast.FilterType = Enum.RaycastFilterType.Include

gameData.blockRaycast.FilterDescendantsInstances = services.Workspace:GetDescendants()

services.Workspace.ChildAdded:Connect(function(child)
    table.insert(gameData.blockRaycast.FilterDescendantsInstances, child)
end)

local infFlyVel = false
local Fly = {}
local SpeedSlider = {}
local Speed = {}

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

repeat
    task.wait()
until lplr.Character

local mouseoverPlr = function(enemy)
    if not (enemy and enemy.Character) then
        return false
    end

    local rootPart = enemy.Character:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        return false
    end

    local rayCheck = RaycastParams.new()
    rayCheck.FilterDescendantsInstances = {lplr.Character, Camera}

    local ray = workspace:Raycast(Camera.CFrame.Position, Camera.CFrame.LookVector * 1000, rayCheck)

    if not ray then
        return false
    end

    if ray.Instance and ray.Instance:IsDescendantOf(enemy.Character) then
        return true
    end

    return false
end

PlayerUtility.EnemyToMouse = function(wallcheck, MouseOverEnemy)
    local closestEnemy = nil
    local closestDistance = math.huge
    local mousePosition = inputservice:GetMouseLocation()

    for _, v in pairs(Players:GetPlayers()) do
        if v ~= lplr and v.Character then
            local character = v.Character
            local rootPart = character:FindFirstChild("HumanoidRootPart")
            local teamcheck = lplr.Team ~= v.Team
            if rootPart then
                local screenPoint = Camera:WorldToViewportPoint(rootPart.Position)
                local distanceFromMouse = (Vector2.new(screenPoint.X, screenPoint.Y) - mousePosition).Magnitude

                local isObstructed = false
                if wallcheck then
                    local rayParams = RaycastParams.new()
                    rayParams.FilterDescendantsInstances = {lplr.Character, character}

                    local rayOrigin = Camera.CFrame.Position
                    local rayDirection = (rootPart.Position - rayOrigin)
                    local ray = workspace:Raycast(rayOrigin, rayDirection, rayParams)

                    isObstructed = ray and ray.Instance
                end

                local isMouseOver = not MouseOverEnemy or mouseoverPlr(v)

                if (game.Teams and #game.Teams:GetChildren() > 0 or teamcheck) and not isObstructed and isMouseOver then
                    closestDistance = distanceFromMouse
                    closestEnemy = v
                end
            end
        end
    end

    return closestEnemy
end

local bodyVel
local createBodyVel = function()
    if PlayerUtility.lplrIsAlive then
        if not bodyVel or not bodyVel.Parent or not bodyVel.Parent.Parent then
            if bodyVel then
                bodyVel:Destroy()
            end
            
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
end

lplr.Character:WaitForChild("Humanoid").Died:Connect(function()
    PlayerUtility.lplrIsAlive = false
    if bodyVel then
        bodyVel:Destroy()
        bodyVel = nil
    end
end)

lplr.CharacterAdded:Connect(function()
    PlayerUtility.lplrIsAlive = true
end)

local function getTools()
    local tools = {}
    if PlayerUtility.lplrIsAlive then
        for _, v in ipairs(lplr.Character:GetChildren()) do
            if v:IsA("Tool") then
                table.insert(tools, v)
            end
        end
    end
    return tools
end

runcode(function()
    local AutoClicker = {}
    local CPSSlider = {}
    AutoClicker = lib.Registry.combatPanel.API.CreateOptionsButton({
        Name = "AutoClicker",
        Function = function(callback)
            if callback then
                local lastClickTime = tick()
                RunLoops:BindToHeartbeat("AutoClicker", function()
                    local tools = getTools() 
                    for _, tool in ipairs(tools) do
                        if inputservice:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
                            if tick() - lastClickTime >= 0.1 / CPSSlider.Value then
                                lastClickTime = tick()
                                tool:Activate()
                            end
                        end
                    end
                end)
            end
        end
    })
    CPSSlider = AutoClicker.CreateSlider({
        Name = "CPSS",
        Min = 0,
        Max = 20,
        Default = 1,
        Round = 1,
    })
end)

runcode(function()
    local slider = {}
    local aimAssist = {}
    local hitPart = {}

    aimAssist = lib.Registry.combatPanel.API.CreateOptionsButton({
        Name = "AimAssist",
        Function = function(callback)
            if callback then
                RunLoops:BindToHeartbeat("AimAssist", function()
                    local target = PlayerUtility.EnemyToMouse(true, false)
                                    
                    if target and target.Character and target.Character:FindFirstChild(hitPart.Value) then
                        local targetPart = target.Character[hitPart.Value]
                        local targetPos, onScreen = workspace.CurrentCamera:WorldToScreenPoint(targetPart.Position)
                        local mousePos = Vector2.new(mouse.X, mouse.Y)
                
                        local distance = (Vector2.new(targetPos.X, targetPos.Y) - mousePos).Magnitude
                
                        if onScreen and distance < 50 then
                            local direction = (targetPart.Position - workspace.CurrentCamera.CFrame.Position).unit
                            local targetCFrame = CFrame.new(workspace.CurrentCamera.CFrame.Position, workspace.CurrentCamera.CFrame.Position + direction)
                            
                            workspace.CurrentCamera.CFrame = workspace.CurrentCamera.CFrame:Lerp(targetCFrame, slider["Value"] * (1 - distance / 50))
                        end
                    end
                end)
                
            else
                RunLoops:UnbindFromHeartbeat("AimAssist")
            end
        end
    })
    slider = aimAssist.CreateSlider({
        Name = "smoothness",
        Min = 0.1,
        Max = 1,
        Default = 0.1,
        Round = 1,
    })
    hitPart = aimAssist.CreateDropdown({
        Name = "HitPart",
        Default = "HumanoidRootPart",
        List = {"HumanoidRootPart", "Head"},
    })
end)


runcode(function()
    local TriggerBot = {}
    local shootDelay = {}
    local shootTime = 0
    local Clicked = false

    TriggerBot = lib.Registry.combatPanel.API.CreateOptionsButton({
        Name = "TriggerBot",
        Function = function(callback)
            if callback then
                RunLoops:BindToHeartbeat("TriggerBot", function()
                    local currentTime = tick()
                    if (isrbxactive or iswindowactive)() and currentTime - shootTime >= shootDelay.Value then
                        local closestEnemy = PlayerUtility.EnemyToMouse(false, true, 100)
                        
                        if closestEnemy and not Clicked then
                            mouse1press()
                            Clicked = true
                        elseif not closestEnemy and Clicked then
                            mouse1release()
                            Clicked = false
                        end
                        shootTime = currentTime
                    end
                end)
            else
                RunLoops:UnbindFromHeartbeat("TriggerBot")
            end
        end
    })
    shootDelay = TriggerBot.CreateSlider({
        Name = "value",
        Min = 0,
        Max = 1,
        Default = 0,
        Round = 1,
    })
end)

runcode(function()
    local AutoJump = {}
    --local SlowdownAnim = {}
    local slowdownAnims = {
        "WalkAnim",
        "RunAnim"
    }

    Speed = lib.Registry.blatantPanel.API.CreateOptionsButton({
        Name = "Speed",
        ExtraText = "CFrame",
        Function = function(callback)
            if callback then
                RunLoops:BindToHeartbeat("Speed", function(dt)
                    if PlayerUtility.lplrIsAlive and lplr.Character.Humanoid.MoveDirection.Magnitude > 0 then
                        local moveDirection = lplr.Character.Humanoid.MoveDirection

                       --[[ if SlowdownAnim.Enabled then
                            for _, anim in lplr.Character.Humanoid:GetPlayingAnimationTracks() do
                                if table.find(slowdownAnims, anim.Name) then
                                    anim:AdjustSpeed(lplr.Character.Humanoid.WalkSpeed / 16)
                                end
                            end
                        end--]]

                        local newCFrame = lplr.Character.HumanoidRootPart.CFrame

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

                        if AutoJump.Enabled and lplr.Character.Humanoid.FloorMaterial ~= Enum.Material.Air then
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
        Max = 150,
        Default = 1,
        Round = 1,
    })
    AutoJump = Speed.CreateToggle({
        Name = "AutoJump",
        Default = false,
    })
    --SlowdownAnim = Speed.CreateToggle({
       -- Name = "SmoothAnimation",
       -- Default = false,
    --})
end)

local height = lplr.Character.HumanoidRootPart.Size.Y * 1.5
runcode(function()
    local FlyValue = {}
    local FlyVertical = {}
    local FlyVerticalValue = {}

    Fly = lib.Registry.blatantPanel.API.CreateOptionsButton({
        Name = "Fly",
        Function = function(callback)
            local i = 0
            local verticalVelocity = 0
            if callback then
                RunLoops:BindToHeartbeat("Fly", function(dt)
                    local moveDirection = lplr.Character.Humanoid.MoveDirection

                    local flyVelocity = moveDirection * (FlyValue.Value)
                    flyVelocity /= (1 / dt)
                    
                    local bounceVelocity = math.sin(i * math.pi) * 0.01
    
                    local flyUp = inputservice:IsKeyDown(Enum.KeyCode.Space)
                    local flyDown = inputservice:IsKeyDown(Enum.KeyCode.LeftShift)
    
                    if flyUp then
                        verticalVelocity = FlyVerticalValue.Value
                    elseif flyDown then
                        verticalVelocity = -FlyVerticalValue.Value
                    else
                        verticalVelocity = bounceVelocity
                    end

                    createBodyVel()
                    lplr.Character.HumanoidRootPart.CFrame = lplr.Character.HumanoidRootPart.CFrame + flyVelocity
                    if not infFlyVel then
                        bodyVel.MaxForce = Vector3.new(bodyVel.P, bodyVel.P, bodyVel.P)
                    end
                    bodyVel.Velocity = Vector3.new(0, verticalVelocity, 0)
                end)              
            else
                if bodyVel then
                    bodyVel.MaxForce = Vector3.new((Speed.Enabled and bodyVel.P) or 0, 0, (Speed.Enabled and bodyVel.P) or 0)
                end
                RunLoops:UnbindFromHeartbeat("Fly")
            end
        end
    })
    FlyValue = Fly.CreateSlider({
        Name = "value",
        Min = 0,
        Max = 150,
        Default = 1,
        Round = 1
    })
    FlyVerticalValue = Fly.CreateSlider({
        Name = "vertical value",
        Min = 0,
        Max = 100,
        Default = 60,
        Round = 1
    })
end)

runcode(function()
    local Gravity = {}
    local originalGravity
    local gravity = {Value = 192.2}
    
    Gravity = lib.Registry.blatantPanel.API.CreateOptionsButton({
        Name = "Gravity",
        Function = function(callback)
            if callback then
                originalGravity = workspace.Gravity
                RunLoops:BindToHeartbeat("GravityLoop", function()
                    workspace.Gravity = gravity.Value
                end)
            else
                RunLoops:UnbindFromHeartbeat("GravityLoop")
                workspace.Gravity = originalGravity or workspace.Gravity
            end
        end
    })
    gravity = Gravity.CreateSlider({
        Name = "Gravity Slider",
		Min = 0,
		Max = 196.2,
		Default = 196.2,
		Round = 1,
    })
end)

runcode(function()
    local AnimationPlayer = {}
    local Speed = {}
    local Anim = {Value = "floss"}
    local anim = nil
    local characteradded
    local restart = false
    local Played = false

    local Anims = {
        floss = 10714340543,
    }

    local PlayAnimation = function(Id, speed)
        if AnimationPlayer.Enabled then
            repeat
                task.wait()
            until PlayerUtility.lplrIsAlive 
            if PlayerUtility.lplrIsAlive then
                task.wait(2)
                local Animation = Instance.new("Animation")
                Animation.AnimationId = "rbxassetid://" .. Id
                local animTrack = lplr.Character.Humanoid:LoadAnimation(Animation)
                animTrack.Priority = Enum.AnimationPriority.Action2
                animTrack:Play()
                animTrack.Looped = true
                animTrack:AdjustSpeed(speed)
                return animTrack
            end
        end
    end
    
    local StopAnimation = function(animTrack)
        if animTrack then
            animTrack:Stop()
            animTrack:Destroy()
        end
    end

    local animations = {}
    for v, _ in pairs(Anims) do
        table.insert(animations, v)
    end

    AnimationPlayer = lib.Registry.renderPanel.API.CreateOptionsButton({
        Name = "AnimationPlayer",
        Function = function(callback)
            if callback then
                if not characteradded then
                    characteradded = lplr.CharacterAdded:Connect(function()
                        restart = true
                    end)
                end

                local animationId
                local animationSpeed
                RunLoops:BindToHeartbeat("AnimationPlayer", function()
                    animationId = Anims[Anim.Value]
                    animationSpeed = Speed.Value
                    if not Played then
                        Played = true
                        anim = PlayAnimation(animationId, animationSpeed)
                    end
                    if restart then
                        Played = false
                        restart = false
                    end
                end)
            else
                if characteradded then
                    characteradded:Disconnect()
                    characteradded = nil
                end
                RunLoops:UnbindFromHeartbeat("AnimationPlayer")
                if anim then
                    StopAnimation(anim)
                    anim = nil
                end
                Played = false
            end
        end
    })
    anim = AnimationPlayer.CreateDropdown({
        Name = "Anim",
        Default = "floss",
        List = animations,
    })
    Speed = AnimationPlayer.CreateSlider({
        Name = "Speed",
        Min = 1,
        Max = 10,
        Default = 1,
        Round = 1,
    })
end)

runcode(function()
    local FovChanger, FOVValue, OldFOV, FOVConnection = {Enabled = false}, {Value = 90}, nil, nil
    FovChanger = lib.Registry.renderPanel.API.CreateOptionsButton({
        Name = "FovChanger",
        Function = function(callback)
            if callback then
                OldFOV = OldFOV or Camera.FieldOfView
                if FovChanger.Enabled then
                    Camera.FieldOfView = FOVValue.Value
                end
                FOVConnection = Camera:GetPropertyChangedSignal("FieldOfView"):Connect(function() 
                    if Camera.FieldOfView ~= FOVValue.Value then 
                        Camera.FieldOfView = FOVValue.Value
                    end
                end)
            else
                if FOVConnection then FOVConnection:Disconnect() end
                if OldFOV then
                    Camera.FieldOfView = OldFOV
                    OldFOV = nil
                end
            end
        end
    })
    FOVValue = FovChanger.CreateSlider({
        Name = "Field of view",
        Min = 10,
        Max = 120,
        Round = 0,
        Default = 90,
        Function = function()
            if FovChanger.Enabled then
                Camera.FieldOfView = FOVValue.Value
            end
        end
    })
end)

runcode(function()
    local BreadCrumbs = {}
    local ColorDropdown = {}
    local Lifetime = {}
    local breadcrumbTrail, breadcrumbAttachmentTop, breadcrumbAttachmentBottom
    local connection

    local function createTrail(character)
        local root = PlayerUtility.lplrIsAlive and lplr.Character.HumanoidRootPart

        breadcrumbAttachmentTop = Instance.new("Attachment")
        breadcrumbAttachmentTop.Position = Vector3.new(0, 0.07 - 2.7, 0)
        breadcrumbAttachmentTop.Parent = root

        breadcrumbAttachmentBottom = Instance.new("Attachment")
        breadcrumbAttachmentBottom.Position = Vector3.new(0, -0.07 - 2.7, 0)
        breadcrumbAttachmentBottom.Parent = root

        if not breadcrumbTrail and root then
            breadcrumbTrail = Instance.new("Trail")
            breadcrumbTrail.Attachment0 = breadcrumbAttachmentTop
            breadcrumbTrail.Attachment1 = breadcrumbAttachmentBottom
            breadcrumbTrail.FaceCamera = true
            breadcrumbTrail.Lifetime = 1
            breadcrumbTrail.LightEmission = 1
            breadcrumbTrail.Transparency = NumberSequence.new(0, 0.5)
            breadcrumbTrail.Enabled = false
            breadcrumbTrail.Parent = root
        end
    end

    local colors = {
        color1 = Color3.new(253 / 255, 195 / 255, 47 / 255),
        color2 = Color3.new(252 / 255, 67 / 255, 229 / 255)
    }

    BreadCrumbs = lib.Registry.renderPanel.API.CreateOptionsButton({
        Name = "BreadCrumbs",
        Function = function(callback)
            if callback then
                createTrail(lplr.Character)
                breadcrumbTrail.Enabled = true

                RunLoops:BindToHeartbeat("BreadCrumbs", function()
                    if not breadcrumbTrail then return end

                    if ColorDropdown.Value == "custom" then
                        breadcrumbTrail.Color = ColorSequence.new(colors.color1:Lerp(colors.color2, tick() % 5 / 5),colors.color1:Lerp(colors.color2, tick() % 5 / 5))
                    elseif ColorDropdown.Value == "lib" then
                        breadcrumbTrail.Color = ColorSequence.new(lib.kit:activeColor(), lib.kit:activeColor())
                    end
                    
                    breadcrumbTrail.Lifetime = Lifetime.Value
                end)

                connection = lplr.CharacterAdded:Connect(function(character)
                    if breadcrumbTrail then
                        breadcrumbTrail.Enabled = false
                        breadcrumbTrail:Destroy()
                        breadcrumbTrail = nil
                    end
                
                    task.wait(1)
                
                    if PlayerUtility.lplrIsAlive and character then
                        createTrail(character)
                        breadcrumbTrail.Enabled = true
                    end
                end)
            else
                breadcrumbTrail.Enabled = false
                RunLoops:UnbindFromHeartbeat("BreadCrumbs")
                if connection then
                    connection:Disconnect()
                    connection = nil
                end
            end
        end
    })
    Lifetime = BreadCrumbs.CreateSlider({
        Name = "Lifetime",
        Min = 1,
        Max = 10,
        Default = 1,
        Round = 1
    })
    ColorDropdown = BreadCrumbs.CreateDropdown({
        Name = "Color",
        Default = "custom",
        List = {"lib", "custom"},
    })
end)


runcode(function()
    local ESP = {}
    ESP = lib.Registry.blatantPanel.API.CreateOptionsButton({
        Name = "ESP",
        Function = function(callback)
            if callback then
                
            end
        end
    })
end)

runcode(function()
    local AntiAFK = {}
    local afk
    
    AntiAFK = lib.Registry.blatantPanel.API.CreateOptionsButton({
        Name = "AntiAFK",
        Function = function(callback)
            if callback then
                afk = lplr.Idled:Connect(function()
                    services.VirtualUserService:CaptureController()
                    services.VirtualUserService:ClickButton2(Vector2.new())
                end)
            else
                if afk then
                    afk:Disconnect()
                    afk = nil
                end
            end
        end
    })    
end)

runcode(function()
    local Antideath = {}
    local connection
    local tped = false
    local lastDamageTime
    local lastHealth
    
    Antideath = lib.Registry.utillityPanel.API.CreateOptionsButton({
        Name = "Antideath",
        Function = function(callback)
            if callback then
                lastDamageTime = 0
                lastHealth = 0
                connection = lplr.Character.Humanoid.HealthChanged:Connect(function(newHealth)
                    local currentTime = tick()
                    local dmg = lastHealth - newHealth
                    if PlayerUtility.lplrIsAlive and (currentTime - lastDamageTime) > 0.5 and not tped then
                        if dmg > 0 and math.ceil(newHealth / math.max(dmg, 1)) <= 1 then
                            lplr.Character.HumanoidRootPart.CFrame = lplr.Character.HumanoidRootPart.CFrame + Vector3.new(0, 200, 0)
                            tped = true
                            lastDamageTime = currentTime

                            task.delay(1, function()
                                tped = false
                            end)
                        end
                        lastDamageTime = currentTime
                    end
                    lastHealth = newHealth
                end)
                funcs:onExit("Antideath", function()
                    if connection then
                        connection:Disconnect()
                        connection = nil
                    end
                end)
            else
                if connection then
                    connection:Disconnect()
                    connection = nil
                end
                tped = false
            end
        end
    })
end)

runcode(function()
    local AntiFall = {}
    local addTp = {}
    local YOffset = {}
    local lowestBlock
    local lastGround
    local cooldown = 0

    AntiFall = lib.Registry.worldPanel.API.CreateOptionsButton({
        Name = "AntiFall",
        Function = function(callback)
            if callback then
                repeat
                    task.wait()
                until PlayerUtility.lplrIsAlive

                if not lowestBlock then
                    local lowestY = 9e9
                    for _, v in services.Workspace:GetDescendants() do
                        if v:IsA("BasePart") and lowestY > v.Position.Y then
                            lowestY = v.Position.Y
                            lowestBlock = v
                        end
                    end
                end

               repeat
                    if not PlayerUtility.lplrIsAlive then return end

                    local ray = workspace:Raycast(lplr.Character.HumanoidRootPart.Position, Vector3.new(0, -1000), gameData.blockRaycast)
                    lastGround = ray and ray.Position or lastGround

                    if not ray and lplr.Character.HumanoidRootPart.Position.Y < (lowestBlock.Position.Y - YOffset.Value) then
                        if addTp.Enabled and lastGround then
                            local isSafe = workspace:Raycast(Vector3.new(lplr.Character.HumanoidRootPart.Position.X, lastGround.Y, lplr.Character.HumanoidRootPart.Position.Z), Vector3.zero, gameData.blockRaycast)
                            local args = {lplr.Character.HumanoidRootPart.CFrame:GetComponents()}
                            args[2] = (not isSafe and lastGround and lastGround.Y) + height or args[2]
    
                            lplr.Character.HumanoidRootPart.CFrame = CFrame.new(unpack(args))
                        elseif cooldown >= tick() then
                            return
                        end
                        cooldown = tick() + .1
                        lplr.Character.HumanoidRootPart.Velocity = Vector3.new(lplr.Character.HumanoidRootPart.Velocity.X, -lplr.Character.HumanoidRootPart.Velocity.Y, lplr.Character.HumanoidRootPart.Velocity.Z)
                    end
                    task.wait(.01)
                until not AntiFall.Enabled
            else
                RunLoops:UnbindFromHeartbeat("AntiVoid")
            end
        end
    })
    addTp = AntiFall.CreateToggle({
        Name = "addTp",
        Default = true
    })
    YOffset = AntiFall.CreateSlider({
        Name = "Y Offset",
        Min = 0,
        Max = 100,
        Default = 0
    })
end)
