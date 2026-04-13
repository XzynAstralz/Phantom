local services = {}
local PlayerUtility = {}

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
local Teams = services.Teams and cloneref(services.Teams) or game:FindFirstChildOfClass("Teams")
local VirtualUser = services.VirtualUser and cloneref(services.VirtualUser) or game:GetService("VirtualUser")
local lplr = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local mouse = lplr:GetMouse()

local lib = phantom.UI
local funcs = phantom.ops
local Runtime = funcs.runtime
local RunLoops = Runtime.RunLoops
local runcode = Runtime.run

local notification = lib.toast

local gameData = {
    blockRaycast = RaycastParams.new()
}
PlayerUtility.lplrIsAlive = true
gameData.blockRaycast.FilterType = Enum.RaycastFilterType.Include

gameData.blockRaycast.FilterDescendantsInstances = services.Workspace:GetDescendants()

services.Workspace.DescendantAdded:Connect(function(child)
    table.insert(gameData.blockRaycast.FilterDescendantsInstances, child)
end)

local infFlyVel = false
local Fly = {}
local SpeedSlider = {}
local Speed = {}

repeat
    task.wait()
until lplr.Character

function PlayerUtility.GetCharacter(plr)
    return (plr or lplr).Character
end

function PlayerUtility.GetHumanoid(plr)
    local character = PlayerUtility.GetCharacter(plr)
    return character and character:FindFirstChildOfClass("Humanoid") or nil
end

function PlayerUtility.GetRoot(plr)
    local character = PlayerUtility.GetCharacter(plr)
    return character and character:FindFirstChild("HumanoidRootPart") or nil
end

function PlayerUtility.IsAlive(plr)
    local humanoid = PlayerUtility.GetHumanoid(plr)
    local rootPart = PlayerUtility.GetRoot(plr)
    return humanoid ~= nil and rootPart ~= nil and humanoid.Health > 0 and humanoid:GetState() ~= Enum.HumanoidStateType.Dead
end

function PlayerUtility.IsEnemy(plr)
    if not plr or plr == lplr then
        return false
    end

    if not Teams or #Teams:GetChildren() == 0 then
        return true
    end

    local myTeam = lplr.Team
    local otherTeam = plr.Team
    if not myTeam or not otherTeam then
        return true
    end

    return myTeam.TeamColor ~= otherTeam.TeamColor
end

function PlayerUtility.GetCharacterHeight()
    local rootPart = PlayerUtility.GetRoot()
    return rootPart and (rootPart.Size.Y * 1.5) or 3
end

local mouseoverPlr = function(enemy)
    if not (enemy and PlayerUtility.IsAlive(enemy)) then
        return false
    end

    local rootPart = PlayerUtility.GetRoot(enemy)
    if not rootPart then
        return false
    end

    local rayCheck = RaycastParams.new()
    rayCheck.FilterType = Enum.RaycastFilterType.Exclude
    rayCheck.IgnoreWater = true
    rayCheck.FilterDescendantsInstances = {PlayerUtility.GetCharacter(), Camera}

    local ray = workspace:Raycast(Camera.CFrame.Position, Camera.CFrame.LookVector * 1000, rayCheck)

    if not ray then
        return false
    end

    if ray.Instance and ray.Instance:IsDescendantOf(enemy.Character) then
        return true
    end

    return false
end

PlayerUtility.EnemyToMouse = function(wallcheck, MouseOverEnemy, maxDistance)
    local closestEnemy = nil
    local closestDistance = maxDistance or math.huge
    local mousePosition = inputservice:GetMouseLocation()

    for _, v in pairs(Players:GetPlayers()) do
        if v ~= lplr and PlayerUtility.IsAlive(v) and PlayerUtility.IsEnemy(v) then
            local character = PlayerUtility.GetCharacter(v)
            local rootPart = PlayerUtility.GetRoot(v)
            if character and rootPart then
                local screenPoint, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
                if onScreen then
                    local distanceFromMouse = (Vector2.new(screenPoint.X, screenPoint.Y) - mousePosition).Magnitude

                    local isObstructed = false
                    if wallcheck then
                        local rayParams = RaycastParams.new()
                        rayParams.FilterType = Enum.RaycastFilterType.Exclude
                        rayParams.IgnoreWater = true
                        rayParams.FilterDescendantsInstances = {PlayerUtility.GetCharacter(), character}

                        local rayOrigin = Camera.CFrame.Position
                        local rayDirection = (rootPart.Position - rayOrigin)
                        local ray = workspace:Raycast(rayOrigin, rayDirection, rayParams)

                        isObstructed = ray ~= nil
                    end

                    local isMouseOver = not MouseOverEnemy or mouseoverPlr(v)

                    if distanceFromMouse < closestDistance and not isObstructed and isMouseOver then
                        closestDistance = distanceFromMouse
                        closestEnemy = v
                    end
                end
            end
        end
    end

    return closestEnemy
end

local bodyVel
local deathConnection
local function cleanupBodyVelocity()
    if bodyVel then
        bodyVel:Destroy()
        bodyVel = nil
    end
end

local createBodyVel = function()
    local rootPart = PlayerUtility.GetRoot()
    if PlayerUtility.IsAlive() and rootPart then
        if not bodyVel or not bodyVel.Parent or not bodyVel.Parent.Parent then
            cleanupBodyVelocity()
            
            bodyVel = Instance.new("BodyVelocity", rootPart)
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

local function bindCharacter(character)
    PlayerUtility.lplrIsAlive = false

    if deathConnection then
        deathConnection:Disconnect()
        deathConnection = nil
    end

    cleanupBodyVelocity()

    local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
    local rootPart = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 5)
    PlayerUtility.lplrIsAlive = humanoid ~= nil and rootPart ~= nil and humanoid.Health > 0

    if humanoid then
        deathConnection = humanoid.Died:Connect(function()
            PlayerUtility.lplrIsAlive = false
            cleanupBodyVelocity()
        end)
    end
end

bindCharacter(lplr.Character)

lplr.CharacterAdded:Connect(function(character)
    bindCharacter(character)
end)

lplr.CharacterRemoving:Connect(function()
    PlayerUtility.lplrIsAlive = false
    cleanupBodyVelocity()
end)

local function getTools()
    local tools = {}
    local character = PlayerUtility.GetCharacter()
    if PlayerUtility.IsAlive() and character then
        for _, v in ipairs(character:GetChildren()) do
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
                    if not PlayerUtility.IsAlive() then
                        return
                    end

                    local tools = getTools() 
                    local cps = math.max(CPSSlider.Value, 0.1)
                    for _, tool in ipairs(tools) do
                        if inputservice:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
                            if tick() - lastClickTime >= 0.1 / cps then
                                lastClickTime = tick()
                                tool:Activate()
                            end
                        end
                    end
                end)
            else
                RunLoops:UnbindFromHeartbeat("AutoClicker")
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
    local aimFOV = {}

    aimAssist = lib.Registry.combatPanel.API.CreateOptionsButton({
        Name = "AimAssist",
        Function = function(callback)
            if callback then
                RunLoops:BindToHeartbeat("AimAssist", function()
                    local target = PlayerUtility.EnemyToMouse(true, false, aimFOV.Value)
                                    
                    if target and target.Character and target.Character:FindFirstChild(hitPart.Value) then
                        local targetPart = target.Character[hitPart.Value]
                        local targetPos, onScreen = workspace.CurrentCamera:WorldToScreenPoint(targetPart.Position)
                        local mousePos = Vector2.new(mouse.X, mouse.Y)
                
                        local distance = (Vector2.new(targetPos.X, targetPos.Y) - mousePos).Magnitude
                
                        if onScreen and distance < aimFOV.Value then
                            local direction = (targetPart.Position - workspace.CurrentCamera.CFrame.Position).unit
                            local targetCFrame = CFrame.new(workspace.CurrentCamera.CFrame.Position, workspace.CurrentCamera.CFrame.Position + direction)
                            
                            workspace.CurrentCamera.CFrame = workspace.CurrentCamera.CFrame:Lerp(targetCFrame, slider.Value * (1 - distance / aimFOV.Value))
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
    aimFOV = aimAssist.CreateSlider({
        Name = "FOV",
        Min = 25,
        Max = 300,
        Default = 75,
        Round = 1,
    })
end)

runcode(function()
    local TriggerBot = {}
    local shootDelay = {}
    local triggerFOV = {}
    local shootTime = 0
    local Clicked = false

    TriggerBot = lib.Registry.combatPanel.API.CreateOptionsButton({
        Name = "TriggerBot",
        Function = function(callback)
            if callback then
                RunLoops:BindToHeartbeat("TriggerBot", function()
                    local currentTime = tick()
                    if (isrbxactive or iswindowactive)() and currentTime - shootTime >= shootDelay.Value then
                        local closestEnemy = PlayerUtility.EnemyToMouse(false, true, triggerFOV.Value)
                        
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
                if Clicked then
                    mouse1release()
                    Clicked = false
                end
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
    triggerFOV = TriggerBot.CreateSlider({
        Name = "FOV",
        Min = 25,
        Max = 300,
        Default = 90,
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
                    local humanoid = PlayerUtility.GetHumanoid()
                    local rootPart = PlayerUtility.GetRoot()
                    if PlayerUtility.IsAlive() and humanoid and rootPart and humanoid.MoveDirection.Magnitude > 0 then
                        local moveDirection = humanoid.MoveDirection

                       --[[ if SlowdownAnim.Enabled then
                            for _, anim in lplr.Character.Humanoid:GetPlayingAnimationTracks() do
                                if table.find(slowdownAnims, anim.Name) then
                                    anim:AdjustSpeed(lplr.Character.Humanoid.WalkSpeed / 16)
                                end
                            end
                        end--]]

                        local newCFrame = rootPart.CFrame

                        if not Fly.Enabled then
                            local speedVelocity = moveDirection * (SpeedSlider.Value)
                            speedVelocity = speedVelocity / (1 / dt)
                            newCFrame = newCFrame + speedVelocity

                            createBodyVel()
                            if not infFlyVel then
                                bodyVel.MaxForce = Vector3.new(bodyVel.P, 0, bodyVel.P)
                            end
                        end
                        rootPart.CFrame = newCFrame

                        if AutoJump.Enabled and humanoid.FloorMaterial ~= Enum.Material.Air then
                            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                        end
                    end
                end)
            else
                local humanoid = PlayerUtility.GetHumanoid()
                if humanoid then
                    humanoid.AutoRotate = true
                end
                cleanupBodyVelocity()
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

runcode(function()
    local FlyValue = {}
    local FlyVerticalValue = {}

    Fly = lib.Registry.blatantPanel.API.CreateOptionsButton({
        Name = "Fly",
        Function = function(callback)
            local i = 0
            local verticalVelocity = 0
            if callback then
                RunLoops:BindToHeartbeat("Fly", function(dt)
                    local humanoid = PlayerUtility.GetHumanoid()
                    local rootPart = PlayerUtility.GetRoot()
                    if not PlayerUtility.IsAlive() or not humanoid or not rootPart then
                        return
                    end

                    i = i + (dt * 4)
                    local moveDirection = humanoid.MoveDirection

                    local flyVelocity = moveDirection * (FlyValue.Value)
                    flyVelocity = flyVelocity / (1 / dt)
                    
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
                    rootPart.CFrame = rootPart.CFrame + flyVelocity
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
    local AnimDropdown = {}
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
                    animationId = Anims[AnimDropdown.Value]
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
    AnimDropdown = AnimationPlayer.CreateDropdown({
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
        local root = character and (character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 5))
        if not root then
            return
        end

        if breadcrumbTrail then
            breadcrumbTrail:Destroy()
            breadcrumbTrail = nil
        end

        if breadcrumbAttachmentTop then
            breadcrumbAttachmentTop:Destroy()
        end

        if breadcrumbAttachmentBottom then
            breadcrumbAttachmentBottom:Destroy()
        end

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

    local function cleanupTrail()
        if breadcrumbTrail then
            breadcrumbTrail.Enabled = false
            breadcrumbTrail:Destroy()
            breadcrumbTrail = nil
        end

        if breadcrumbAttachmentTop then
            breadcrumbAttachmentTop:Destroy()
            breadcrumbAttachmentTop = nil
        end

        if breadcrumbAttachmentBottom then
            breadcrumbAttachmentBottom:Destroy()
            breadcrumbAttachmentBottom = nil
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
                if breadcrumbTrail then
                    breadcrumbTrail.Enabled = true
                end

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
                    cleanupTrail()

                    if character then
                        createTrail(character)
                        if breadcrumbTrail then
                            breadcrumbTrail.Enabled = true
                        end
                    end
                end)
            else
                cleanupTrail()
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
    local ESPFill = {}
    local ESPOutline = {}
    local TeamCheck = {}
    local UseTeamColor = {}
    local highlights = {}
    local addedConnection
    local removingConnection

    local function removeHighlight(player)
        local highlight = highlights[player]
        if highlight then
            highlight:Destroy()
            highlights[player] = nil
        end
    end

    local function getHighlight(player)
        if player == lplr then
            return nil
        end

        if not highlights[player] then
            local highlight = Instance.new("Highlight")
            highlight.Name = "PhantomESP"
            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            highlight.Parent = workspace
            highlights[player] = highlight
        end

        return highlights[player]
    end

    local function shouldShow(player)
        if not PlayerUtility.IsAlive(player) then
            return false
        end

        return not TeamCheck.Enabled or PlayerUtility.IsEnemy(player)
    end

    ESP = lib.Registry.blatantPanel.API.CreateOptionsButton({
        Name = "ESP",
        Function = function(callback)
            if callback then
                addedConnection = Players.PlayerAdded:Connect(function(player)
                    if player ~= lplr then
                        getHighlight(player)
                    end
                end)

                removingConnection = Players.PlayerRemoving:Connect(function(player)
                    removeHighlight(player)
                end)

                RunLoops:BindToHeartbeat("ESP", function()
                    for _, player in ipairs(Players:GetPlayers()) do
                        if player ~= lplr then
                            local highlight = getHighlight(player)
                            if highlight then
                                if shouldShow(player) then
                                    local playerColor = UseTeamColor.Enabled and player.Team and player.Team.TeamColor.Color or lib.kit:activeColor()
                                    highlight.Adornee = PlayerUtility.GetCharacter(player)
                                    highlight.FillColor = playerColor
                                    highlight.OutlineColor = playerColor
                                    highlight.FillTransparency = ESPFill.Value
                                    highlight.OutlineTransparency = ESPOutline.Value
                                    highlight.Enabled = true
                                else
                                    highlight.Enabled = false
                                    highlight.Adornee = nil
                                end
                            end
                        end
                    end
                end)
            else
                RunLoops:UnbindFromHeartbeat("ESP")

                if addedConnection then
                    addedConnection:Disconnect()
                    addedConnection = nil
                end

                if removingConnection then
                    removingConnection:Disconnect()
                    removingConnection = nil
                end

                for player in pairs(highlights) do
                    removeHighlight(player)
                end
            end
        end
    })
    ESPFill = ESP.CreateSlider({
        Name = "Fill",
        Min = 0,
        Max = 1,
        Default = 0.55,
        Round = 1,
    })
    ESPOutline = ESP.CreateSlider({
        Name = "Outline",
        Min = 0,
        Max = 1,
        Default = 0,
        Round = 1,
    })
    TeamCheck = ESP.CreateToggle({
        Name = "TeamCheck",
        Default = true,
    })
    UseTeamColor = ESP.CreateToggle({
        Name = "TeamColor",
        Default = false,
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
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new())
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
    local characterConnection
    local tped = false
    local lastDamageTime
    local lastHealth

    local function disconnectHumanoid()
        if connection then
            connection:Disconnect()
            connection = nil
        end
    end

    local function bindHumanoid(character)
        disconnectHumanoid()

        local humanoid = character and (character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5))
        if not humanoid then
            return
        end

        lastHealth = humanoid.Health
        connection = humanoid.HealthChanged:Connect(function(newHealth)
            local currentTime = tick()
            local dmg = lastHealth - newHealth
            local rootPart = PlayerUtility.GetRoot()
            if PlayerUtility.IsAlive() and rootPart and (currentTime - lastDamageTime) > 0.5 and not tped then
                if dmg > 0 and math.ceil(newHealth / math.max(dmg, 1)) <= 1 then
                    rootPart.CFrame = rootPart.CFrame + Vector3.new(0, 200, 0)
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
    end
    
    Antideath = lib.Registry.utillityPanel.API.CreateOptionsButton({
        Name = "Antideath",
        Function = function(callback)
            if callback then
                lastDamageTime = 0
                tped = false
                bindHumanoid(lplr.Character)
                characterConnection = lplr.CharacterAdded:Connect(function(character)
                    bindHumanoid(character)
                end)
                funcs:onExit("Antideath", function()
                    disconnectHumanoid()
                    if characterConnection then
                        characterConnection:Disconnect()
                        characterConnection = nil
                    end
                end)
            else
                disconnectHumanoid()
                if characterConnection then
                    characterConnection:Disconnect()
                    characterConnection = nil
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
                if not lowestBlock then
                    local lowestY = 9e9
                    for _, v in services.Workspace:GetDescendants() do
                        if v:IsA("BasePart") and lowestY > v.Position.Y then
                            lowestY = v.Position.Y
                            lowestBlock = v
                        end
                    end
                end

                RunLoops:BindToHeartbeat("AntiFall", function()
                    local rootPart = PlayerUtility.GetRoot()
                    if not PlayerUtility.IsAlive() or not rootPart or not lowestBlock then
                        return
                    end

                    if not lowestBlock.Parent then
                        lowestBlock = nil
                        local lowestY = 9e9
                        for _, v in services.Workspace:GetDescendants() do
                            if v:IsA("BasePart") and lowestY > v.Position.Y then
                                lowestY = v.Position.Y
                                lowestBlock = v
                            end
                        end
                        if not lowestBlock then
                            return
                        end
                    end

                    local ray = workspace:Raycast(rootPart.Position, Vector3.new(0, -1000), gameData.blockRaycast)
                    lastGround = ray and ray.Position or lastGround

                    if not ray and rootPart.Position.Y < (lowestBlock.Position.Y - YOffset.Value) then
                        if addTp.Enabled and lastGround then
                            local args = {rootPart.CFrame:GetComponents()}
                            args[2] = lastGround.Y + PlayerUtility.GetCharacterHeight()
                            rootPart.CFrame = CFrame.new(table.unpack(args))
                        elseif cooldown < tick() then
                            cooldown = tick() + .1
                            rootPart.Velocity = Vector3.new(rootPart.Velocity.X, math.abs(rootPart.Velocity.Y), rootPart.Velocity.Z)
                        end
                    end
                end)
            else
                RunLoops:UnbindFromHeartbeat("AntiFall")
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
