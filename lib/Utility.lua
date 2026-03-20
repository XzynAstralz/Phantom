local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local Camera = Workspace.CurrentCamera
local lplr = Players.LocalPlayer

local Utility = {}

function Utility.GetCharacter(plr)
    plr = plr or lplr
    return plr.Character
end

function Utility.IsAlive(plr)
    local char = Utility.GetCharacter(plr)
    if not char then return false end

    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")

    return hum and hum.Health > 0 and root
end


function Utility.IsEnemy(plr, teamCheck)
    if not plr or not lplr then
        return false
    end

    if teamCheck == false then
        return true
    end

    if Utility.FreeForAllMode then
        return true
    end

    if not plr.Team or not lplr.Team then
        return true
    end

    if plr.Team ~= lplr.Team then
        return true
    end

    if Utility.teams[plr.Team.Name] then
        return true
    end

    return false
end

function Utility.IsVisible(startPos, endPos)
    local ray = Workspace:Raycast(startPos, endPos - startPos)
    return ray == nil
end

function Utility.GetNearestEntities(maxDist, teamCheck, wallCheck)
    local results = {}

    local myChar = Utility.GetCharacter()
    if not Utility.IsAlive() then return results end

    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return results end

    for _, plr in Players:GetPlayers() do
        if plr ~= lplr and Utility.IsAlive(plr) then
            if Utility.IsEnemy(plr, teamCheck) then
                local char = plr.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")

                if root then
                    local dist = (root.Position - myRoot.Position).Magnitude

                    if dist <= maxDist then
                        if not wallCheck or Utility.IsVisible(myRoot.Position, root.Position) then
                            table.insert(results, {
                                player = plr,
                                character = char,
                                distance = dist,
                                health = char:FindFirstChildOfClass("Humanoid").Health
                            })
                        end
                    end
                end
            end
        end
    end

    table.sort(results, function(a, b)
        return a.distance < b.distance
    end)

    return results
end

function Utility.GetNearestEntity(maxDist, teamCheck, wallCheck)
    local list = Utility.GetNearestEntities(maxDist, teamCheck, wallCheck)
    return list[1]
end

function Utility.GetEntityNearMouse(fov, teamCheck)
    local mousePos = UserInputService:GetMouseLocation()

    local closest = nil
    local closestDist = fov

    for _, plr in Players:GetPlayers() do
        if plr ~= lplr and Utility.IsAlive(plr) then
            if Utility.IsEnemy(plr, teamCheck) then
                local char = plr.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")

                if root then
                    local screenPos, visible = Camera:WorldToViewportPoint(root.Position)

                    if visible then
                        local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude

                        if dist < closestDist then
                            closestDist = dist
                            closest = plr
                        end
                    end
                end
            end
        end
    end

    return closest
end

return Utility
