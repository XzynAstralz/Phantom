local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local Camera = Workspace.CurrentCamera
local lplr = Players.LocalPlayer

local Utility = { lplrIsAlive = false }

local function bindHumanoid(hum)
    if not hum then return end

    Utility.lplrIsAlive = hum.Health > 0

    hum.HealthChanged:Connect(function(h)
        Utility.lplrIsAlive = h > 0
    end)

    hum.Died:Connect(function()
        Utility.lplrIsAlive = false
    end)
end

local function track(char)
    bindHumanoid(char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5))
end

if lplr.Character then
    track(lplr.Character)
end

lplr.CharacterAdded:Connect(function(char)
    Utility.lplrIsAlive = false
    track(char)
end)

function Utility.GetCharacter(plr)
    return (plr or lplr).Character
end

function Utility.IsAlive(plr)
    plr = plr or lplr
    if plr == lplr then
        return Utility.lplrIsAlive
    end
    local char = plr.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    return hum and hum.Health > 0 and root
end

function Utility.IsEnemy(plr, teamCheck)
    if not plr or plr == lplr then return false end
    if teamCheck == false or Utility.FreeForAllMode then return true end
    local t1, t2 = plr.Team, lplr.Team
    if not t1 or not t2 then return true end
    return t1.TeamColor ~= t2.TeamColor
end

function Utility.IsVisible(a, b)
    return Workspace:Raycast(a, b - a) == nil
end

function Utility.GetNearestEntities(maxDist, teamCheck, wallCheck)
    local results = {}
    local myChar = Utility.GetCharacter()
    if not Utility.IsAlive() or not myChar then return results end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return results end
    for _, plr in Players:GetPlayers() do
        if plr ~= lplr and Utility.IsAlive(plr) and Utility.IsEnemy(plr, teamCheck) then
            local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
            if root then
                local dist = (root.Position - myRoot.Position).Magnitude
                if dist <= maxDist and (not wallCheck or Utility.IsVisible(myRoot.Position, root.Position)) then
                    table.insert(results, {player = plr,character = plr.Character,distance = dist,health = plr.Character:FindFirstChildOfClass("Humanoid").Health})
                end
            end
        end
    end
    table.sort(results, function(a,b) return a.distance < b.distance end)
    return results
end

function Utility.GetNearestEntity(maxDist, teamCheck, wallCheck)
    return Utility.GetNearestEntities(maxDist, teamCheck, wallCheck)[1]
end

function Utility.GetEntityNearMouse(fov, teamCheck)
    local mouse = UserInputService:GetMouseLocation()
    local closest, dist = nil, fov

    for _, plr in Players:GetPlayers() do
        if plr ~= lplr and Utility.IsAlive(plr) and Utility.IsEnemy(plr, teamCheck) then
            local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
            if root then
                local pos, vis = Camera:WorldToViewportPoint(root.Position)
                if vis then
                    local m = (Vector2.new(pos.X, pos.Y) - mouse).Magnitude
                    if m < dist then
                        dist = m
                        closest = plr
                    end
                end
            end
        end
    end

    return closest
end


return Utility