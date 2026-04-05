import re

path = 'c:/Users/grayson/AppData/Local/Potassium/workspace/Phantom/games/35136865.lua'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()
    lines   = content.splitlines(keepends=True)

results = []

def apply(label, old, new):
    global content
    if old in content:
        content = content.replace(old, new, 1)
        results.append(f'OK: {label}')
    else:
        results.append(f'MISSING: {label}')

# ══════════════════════════════════════════════════════════════════════════════
# 1.  REMOVE TRAJECTORIES BLOCK
# ══════════════════════════════════════════════════════════════════════════════
# Find Trajectories block boundaries: blank line before the comment through end)
traj_start = content.find('\n-- ============================================================\n-- Trajectories\n')
traj_end   = content.find('\nend)\n', traj_start) + len('\nend)\n')
if traj_start > 0:
    content = content[:traj_start] + content[traj_end:]
    results.append('OK: Remove Trajectories')
else:
    results.append('MISSING: Trajectories block')

# ══════════════════════════════════════════════════════════════════════════════
# 2.  ADD "Auto" TO PHANTOM_COLORS + PHANTOM_COL_LIST + pcol()
# ══════════════════════════════════════════════════════════════════════════════
apply('PHANTOM_COLORS Auto entry',
    '    TeamColor = function() return lplr.Team and lplr.Team.TeamColor.Color or Color3.fromRGB(255,255,255) end,\n}',
    '    TeamColor = function() return lplr.Team and lplr.Team.TeamColor.Color or Color3.fromRGB(255,255,255) end,\n    Auto      = function() return lplr.Team and lplr.Team.TeamColor.Color or Color3.fromRGB(255,255,255) end,\n}')

apply('PHANTOM_COL_LIST add Auto',
    'local PHANTOM_COL_LIST = {"Theme","Red","Orange","Yellow","Green","Cyan","Blue","Purple","White","Pink","Team Color"}',
    'local PHANTOM_COL_LIST = {"Auto","Theme","Red","Orange","Yellow","Green","Cyan","Blue","Purple","White","Pink","Team Color"}')

apply('pcol Auto key',
    '    local key = k == "Team Color" and "TeamColor" or k\n    return (PHANTOM_COLORS[key] or PHANTOM_COLORS.Theme)()',
    '    local key = k == "Team Color" and "TeamColor" or (k == "Auto" and "Auto" or k)\n    return (PHANTOM_COLORS[key] or PHANTOM_COLORS.Theme)()')

# ══════════════════════════════════════════════════════════════════════════════
# 3.  FIX BLOCK RANGE SLIDER  (uses `v` instead of `callback`)
# ══════════════════════════════════════════════════════════════════════════════
apply('BlockRange slider bug',
    '            rangeVal.Value = callback\n            if BlockRange.Enabled and not infRange then bedfight.modules.BlocksData.Default.Range = v end',
    '            rangeVal.Value = callback\n            if BlockRange.Enabled and not infRange then bedfight.modules.BlocksData.Default.Range = callback end')

# ══════════════════════════════════════════════════════════════════════════════
# 4.  KILLAURA: hook death/respawn to reload animations + only play on swords
# ══════════════════════════════════════════════════════════════════════════════
# Add CharacterAdded hook inside the killaura enable branch, right after setting origSwordNew
apply('Killaura CharacterAdded + sword-only anim',
    '                -- hook ViewModelHandler so we can suppress the default anim',
    '''                -- re-hook anims on respawn so VM joint cache reloads
                local _kaCharConn = lplr.CharacterAdded:Connect(function()
                    vmJointCache = nil; vmOrigC0Cache = nil
                    task.delay(0.3, function()
                        if Killaura.Enabled then hookAnims() end
                    end)
                end)
                funcs:onExit("KA_CharConn", function()
                    if _kaCharConn then _kaCharConn:Disconnect() end
                end)

                -- hook ViewModelHandler so we can suppress the default anim''')

# Also fix playVMAnim to only fire when a sword is in hand
apply('playVMAnim sword check',
    '    local function playVMAnim()\n        if not VMAnimToggle.Enabled or vmAnimPlaying then return end',
    '    local function playVMAnim()\n        if not VMAnimToggle.Enabled or vmAnimPlaying then return end\n        if not getsword() then return end  -- only animate when sword is equipped')

# Clean up KA_CharConn on disable
apply('Killaura cleanup KA_CharConn',
    '                if shieldConn then shieldConn:Disconnect(); shieldConn = nil end\n                shieldActive = false',
    '                if shieldConn then shieldConn:Disconnect(); shieldConn = nil end\n                funcs:offExit("KA_CharConn")\n                shieldActive = false')

# ══════════════════════════════════════════════════════════════════════════════
# 5.  REWRITE ESP (Drawing.new Square approach, fix health bar, name, hurt)
# ══════════════════════════════════════════════════════════════════════════════
# Find the entire ESP runcode block
esp_start = content.find('\nruncode(function()\n    -- Drawing-based ESP')
esp_end   = content.find('\nend)\n\n\nruncode(function()\n    local fpConn')
if esp_start < 0 or esp_end < 0:
    results.append('MISSING: ESP block boundaries')
else:
    NEW_ESP = r"""
runcode(function()
    -- ── shared state ────────────────────────────────────────────────────────
    local espRef  = {}   -- [char] = {sq/lines, hpBG, hp, name, dist, aimLines}
    local espHLs  = {}   -- [char] = Highlight
    local espHurt = {}   -- [char] = tick() of last hit
    local espAimLines = {}

    local ESPMode, ESPOutC, ESPFillC, ESPOutOp, ESPFillOp
    local ESPThick, ESPHurt, ESPHurtC, ESPHealth, ESPName
    local ESPDist, ESPWalls, ESPLQMode, ESPAimBox, ESPSelf, ESPTeam

    -- viewport projection
    local function w2v(pos)
        local p, vis = Camera:WorldToViewportPoint(pos)
        return Vector2.new(p.X, p.Y), vis, p.Z
    end

    local function getHH(char)
        local h = char:FindFirstChildOfClass("Humanoid")
        return h and (h.HipHeight + 1) or 2.8
    end

    -- Returns left, top, w, h (all positive pixels), visible
    local function bounds2D(hrp, hh)
        local pos     = hrp.Position
        local lv      = Camera.CFrame.LookVector
        local rS, rVis, rZ = w2v(pos)
        if not rVis or rZ <= 0 then return nil end
        local tS = w2v((CFrame.lookAlong(pos,lv)*CFrame.new( 2,  hh,    0)).Position)
        local bS = w2v((CFrame.lookAlong(pos,lv)*CFrame.new(-2, -hh-1,  0)).Position)
        local sw  = math.abs(tS.X - bS.X)
        local sh  = math.abs(tS.Y - bS.Y)
        local top = math.min(tS.Y, bS.Y)
        local left= rS.X - sw/2
        return left, top, sw, sh
    end

    -- 3D wireframe corners
    local function pts3D(hrp, hh)
        local p = hrp.Position
        return {
            w2v(p+Vector3.new( 1.5, hh, 1.5)),  w2v(p+Vector3.new( 1.5,-hh, 1.5)),
            w2v(p+Vector3.new(-1.5, hh, 1.5)),  w2v(p+Vector3.new(-1.5,-hh, 1.5)),
            w2v(p+Vector3.new( 1.5, hh,-1.5)),  w2v(p+Vector3.new( 1.5,-hh,-1.5)),
            w2v(p+Vector3.new(-1.5, hh,-1.5)),  w2v(p+Vector3.new(-1.5,-hh,-1.5)),
        }
    end

    local function mkLine(c, thick)
        local d = Drawing.new("Line"); d.Thickness = thick or 1
        d.Color = c; d.Visible = false; d.ZIndex = 2; return d
    end
    local function mkSquare(c, thick, filled)
        local d = Drawing.new("Square"); d.Thickness = thick or 1
        d.Color = c; d.Filled = filled or false; d.Visible = false; d.ZIndex = 2; return d
    end
    local function mkText(c, sz)
        local d = Drawing.new("Text"); d.Color = c; d.Size = sz or 14
        d.Visible = false; d.Center = true; d.Outline = true
        d.OutlineColor = Color3.new(0,0,0); d.ZIndex = 3
        d.Font = Drawing.Fonts.UI; return d
    end

    local function newEntry(mode, c, thick)
        local e = {mode=mode, objs={}}
        if mode == "Highlight" then
            -- no drawing objects needed
        elseif mode == "2D Box" then
            e.box   = mkSquare(c, thick)
            e.boxBd = mkSquare(Color3.new(0,0,0), thick+1)  -- black border
        elseif mode == "Corner Box" then
            for i=1,8 do e.objs[i] = mkLine(c, thick) end
        elseif mode == "3D Box" then
            for i=1,12 do e.objs[i] = mkLine(c, thick) end
        end
        e.hpBG = mkLine(Color3.fromRGB(25,25,25), 4)
        e.hp   = mkLine(Color3.fromRGB(85,255,85), 2)
        e.name = mkText(c, 14)
        e.dist = mkText(c, 12)
        return e
    end

    local function destroyEntry(e)
        if not e then return end
        if e.box   then pcall(function() e.box:Remove()   end) end
        if e.boxBd then pcall(function() e.boxBd:Remove() end) end
        for _, d in ipairs(e.objs) do pcall(function() d:Remove() end) end
        for _, k in ipairs({"hpBG","hp","name","dist"}) do
            if e[k] then pcall(function() e[k]:Remove() end) end
        end
    end

    local function hideEntry(e)
        if not e then return end
        if e.box   then e.box.Visible   = false end
        if e.boxBd then e.boxBd.Visible = false end
        for _, d in ipairs(e.objs) do d.Visible = false end
        e.hpBG.Visible = false; e.hp.Visible = false
        e.name.Visible = false; e.dist.Visible = false
    end

    local function destroyHL(char)
        local h = espHLs[char]; if h and h.Parent then h:Destroy() end; espHLs[char]=nil
    end
    local function removeChar(char)
        destroyEntry(espRef[char]); espRef[char]=nil; destroyHL(char)
    end

    local function draw2D(e, left, top, sw, sh, c, thick)
        if not e.box then return end
        -- outer black border
        e.boxBd.Color = Color3.new(0,0,0); e.boxBd.Thickness = thick+1
        e.boxBd.Position = Vector2.new(left-1, top-1)
        e.boxBd.Size     = Vector2.new(sw+2, sh+2); e.boxBd.Visible = true
        -- main box
        e.box.Color = c; e.box.Thickness = thick
        e.box.Position = Vector2.new(left, top)
        e.box.Size     = Vector2.new(sw, sh); e.box.Visible = true
    end

    local function drawCorner(objs, left, top, sw, sh, c, thick)
        local cw, ch = sw*0.25, sh*0.25
        local r, b   = left+sw, top+sh
        local segs = {
            {Vector2.new(left,    top),    Vector2.new(left+cw, top)},
            {Vector2.new(left,    top),    Vector2.new(left,    top+ch)},
            {Vector2.new(r-cw,   top),    Vector2.new(r,       top)},
            {Vector2.new(r,       top),    Vector2.new(r,       top+ch)},
            {Vector2.new(left,    b-ch),   Vector2.new(left,    b)},
            {Vector2.new(left,    b),      Vector2.new(left+cw, b)},
            {Vector2.new(r,       b-ch),   Vector2.new(r,       b)},
            {Vector2.new(r-cw,   b),      Vector2.new(r,       b)},
        }
        for i,s in ipairs(segs) do
            objs[i].Color=c; objs[i].Thickness=thick
            objs[i].From=s[1]; objs[i].To=s[2]; objs[i].Visible=true
        end
    end

    local function draw3D(objs, pts, c, thick)
        local edges={{1,2},{3,4},{5,6},{7,8},{1,3},{1,5},{5,7},{7,3},{2,4},{2,6},{6,8},{8,4}}
        for i,e in ipairs(edges) do
            objs[i].Color=c; objs[i].Thickness=thick
            objs[i].From=pts[e[1]]; objs[i].To=pts[e[2]]; objs[i].Visible=true
        end
    end

    local function updateOverlays(e, char, v, c, left, top, sw, sh, showHB, showN, showD)
        local hum   = char:FindFirstChildOfClass("Humanoid")
        local hp    = hum and hum.Health    or 0
        local maxhp = hum and hum.MaxHealth or 100
        local ratio = math.clamp(hp/math.max(maxhp,1), 0, 1)
        local bx    = left - 6

        -- health bar: fills from bottom upward
        e.hpBG.Visible = showHB
        e.hp.Visible   = showHB and hp > 0
        if showHB then
            e.hpBG.From = Vector2.new(bx, top);       e.hpBG.To = Vector2.new(bx, top+sh)
            e.hp.Color  = Color3.fromHSV(ratio/3, 0.9, 0.85)
            e.hp.From   = Vector2.new(bx, top + sh*(1-ratio))
            e.hp.To     = Vector2.new(bx, top+sh)
        end

        -- name: just above the box
        local myRoot = lplr.Character and lplr.Character:FindFirstChild("HumanoidRootPart")
        local hrp    = char:FindFirstChild("HumanoidRootPart")
        e.name.Visible = showN
        if showN then
            local nameStr = v.DisplayName ~= "" and v.DisplayName or v.Name
            e.name.Text     = nameStr
            e.name.Color    = c
            e.name.Position = Vector2.new(left+sw/2, top-16)
        end

        e.dist.Visible = showD
        if showD and myRoot and hrp then
            local d = math.floor((myRoot.Position-hrp.Position).Magnitude)
            e.dist.Text     = d.."m"
            e.dist.Color    = c
            e.dist.Position = Vector2.new(left+sw/2, top+sh+3)
        end
    end

    local ESP = GuiLibrary.Registry.renderPanel.API.CreateOptionsButton({
        Name = "ESP",
        Function = function(on)
            if on then
                -- hurt tracking
                local function hookHurt(p)
                    local char = p.Character; if not char then return end
                    local hum  = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
                    local conn = hum.HealthChanged:Connect(function(hp)
                        if hp < hum.MaxHealth then espHurt[char] = tick() end
                    end)
                    funcs:onExit("ESPHT_"..p.UserId, conn)
                end
                for _, p in ipairs(Players:GetPlayers()) do hookHurt(p) end
                local paConn = Players.PlayerAdded:Connect(function(p)
                    p.CharacterAdded:Connect(function() task.wait(0.15); hookHurt(p) end)
                end)
                funcs:onExit("ESP_PA", paConn)

                local lqN = 0
                RunLoops:BindToHeartbeat("ESP", function()
                    lqN += 1
                    if ESPLQMode and ESPLQMode.Enabled and lqN%3~=0 then return end

                    local mode   = ESPMode   and ESPMode.Value   or "Highlight"
                    local doHL   = mode == "Highlight"
                    local outA   = ESPOutOp  and ESPOutOp.Value  or 0
                    local fillA  = ESPFillOp and ESPFillOp.Value or 0.5
                    local thick  = ESPThick  and ESPThick.Value  or 1
                    local useT   = ESPTeam   and ESPTeam.Enabled
                    local showHB = ESPHealth and ESPHealth.Enabled
                    local showN  = ESPName   and ESPName.Enabled
                    local showD  = ESPDist   and ESPDist.Enabled
                    local walls  = ESPWalls  and ESPWalls.Enabled
                    local hurtOn = ESPHurt   and ESPHurt.Enabled

                    local seen = {}
                    local bestDot, bestChar = -1, nil

                    for _, v in ipairs(Players:GetPlayers()) do
                        local isSelf = v == lplr
                        if isSelf and not (ESPSelf and ESPSelf.Enabled) then continue end
                        local char = v.Character; if not char then continue end
                        local hrp  = char:FindFirstChild("HumanoidRootPart"); if not hrp then continue end
                        local hum  = char:FindFirstChildOfClass("Humanoid")
                        if hum and hum.Health <= 0 then removeChar(char); continue end
                        seen[char] = true

                        -- color
                        local hurt = hurtOn and espHurt[char] and (tick()-espHurt[char] < 0.4)
                        local oc
                        if hurt        then oc = pcol(ESPHurtC)
                        elseif useT and v.Team then oc = v.Team.TeamColor.Color
                        else oc = pcol(ESPOutC) end

                        if doHL then
                            destroyEntry(espRef[char]); espRef[char]=nil
                            local h = espHLs[char]
                            if not h then
                                h = Instance.new("Highlight"); h.Name="PhantomESP"
                                h.Adornee=char
                                h.DepthMode = walls and Enum.HighlightDepthMode.AlwaysOnTop
                                             or Enum.HighlightDepthMode.Occluded
                                h.Parent=char; espHLs[char]=h
                            end
                            h.OutlineColor=oc; h.OutlineTransparency=outA
                            h.FillColor=pcol(ESPFillC); h.FillTransparency=fillA
                        else
                            destroyHL(char)
                            local hh    = getHH(char)
                            local left, top, sw, sh = bounds2D(hrp, hh)
                            local entry = espRef[char]

                            if not left then
                                if entry then hideEntry(entry) end; continue
                            end

                            if not entry or entry.mode ~= mode then
                                if entry then destroyEntry(entry) end
                                entry = newEntry(mode, oc, thick)
                                espRef[char] = entry
                            end

                            if mode == "2D Box" then
                                draw2D(entry, left, top, sw, sh, oc, thick)
                            elseif mode == "Corner Box" then
                                drawCorner(entry.objs, left, top, sw, sh, oc, thick)
                            elseif mode == "3D Box" then
                                draw3D(entry.objs, pts3D(hrp,hh), oc, thick)
                            end
                            updateOverlays(entry, char, v, oc, left, top, sw, sh, showHB, showN, showD)
                        end

                        if not isSelf and ESPAimBox and ESPAimBox.Enabled then
                            local dv = Camera.CFrame:vectorToObjectSpace(
                                (hrp.Position-Camera.CFrame.Position).Unit)
                            local dot = dv.Z < 0 and -dv.Z or 0
                            if dot > bestDot then bestDot=dot; bestChar=char end
                        end
                    end

                    for char in pairs(espRef) do if not seen[char] then removeChar(char) end end
                    for char in pairs(espHLs)  do if not seen[char] then destroyHL(char)  end end

                    if ESPAimBox and ESPAimBox.Enabled and bestChar then
                        local hrp = bestChar:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            local hh = getHH(bestChar)
                            local left, top, sw, sh = bounds2D(hrp, hh)
                            if left then
                                if #espAimLines == 0 then
                                    for i=1,8 do espAimLines[i]=mkLine(Color3.fromRGB(255,60,60),2) end
                                end
                                drawCorner(espAimLines, left, top, sw, sh, Color3.fromRGB(255,60,60), 2)
                            end
                        end
                    else
                        for _, d in ipairs(espAimLines) do d.Visible=false end
                    end
                end)
            else
                RunLoops:UnbindFromHeartbeat("ESP")
                for char in pairs(espRef) do removeChar(char) end
                for char in pairs(espHLs) do destroyHL(char)  end
                for _, d in ipairs(espAimLines) do pcall(function() d:Remove() end) end
                espAimLines = {}
                for _, p in ipairs(Players:GetPlayers()) do funcs:offExit("ESPHT_"..p.UserId) end
                funcs:offExit("ESP_PA")
                espHurt = {}
            end
        end
    })
    ESPMode   = ESP.CreateDropdown({Name="Mode",          List={"Highlight","2D Box","Corner Box","3D Box"}, Default="Highlight", Function=function()end})
    ESPOutC   = ESP.CreateDropdown({Name="Outline Color", List=PHANTOM_COL_LIST, Default="Theme", Function=function()end})
    ESPFillC  = ESP.CreateDropdown({Name="Fill Color",    List=PHANTOM_COL_LIST, Default="Theme", Function=function()end})
    ESPOutOp  = ESP.CreateSlider({Name="Outline Opacity", Min=0, Max=1, Default=0})
    ESPFillOp = ESP.CreateSlider({Name="Fill Opacity",    Min=0, Max=1, Default=0.5})
    ESPThick  = ESP.CreateSlider({Name="Line Thickness",  Min=1, Max=4, Default=1, Round=1})
    ESPHurt   = ESP.CreateToggle({Name="Hurt Indicator",  Default=true,  Function=function()end})
    ESPHurtC  = ESP.CreateDropdown({Name="Hurt Color",    List={"Red","Orange","Yellow","White","Pink","Cyan"}, Default="Red", Function=function()end})
    ESPHealth = ESP.CreateToggle({Name="Health Bar",      Default=true,  Function=function()end})
    ESPName   = ESP.CreateToggle({Name="Name Label",      Default=true,  Function=function()end})
    ESPDist   = ESP.CreateToggle({Name="Distance",        Default=false, Function=function()end})
    ESPWalls  = ESP.CreateToggle({Name="Through Walls",   Default=true,  Function=function()end})
    ESPLQMode = ESP.CreateToggle({Name="LQ Mode",         Default=false, Function=function()end})
    ESPAimBox = ESP.CreateToggle({Name="AimAssist Box",   Default=false, Function=function()end})
    ESPSelf   = ESP.CreateToggle({Name="Self Render",     Default=false, Function=function()end})
    ESPTeam   = ESP.CreateToggle({Name="Team Color",      Default=false, Function=function()end})
    ESPMode:ShowWhen("2D Box",     ESPThick)
    ESPMode:ShowWhen("Corner Box", ESPThick)
    ESPMode:ShowWhen("3D Box",     ESPThick)
    ESPMode:AddDependent(ESPThick)
    ESPMode:ShowWhen("Highlight",  ESPFillC)
    ESPMode:ShowWhen("2D Box",     ESPFillC)
    ESPMode:AddDependent(ESPFillC)
    ESPMode:ShowWhen("Highlight",  ESPFillOp)
    ESPMode:ShowWhen("2D Box",     ESPFillOp)
    ESPMode:AddDependent(ESPFillOp)
    ESPHurt:ShowWhen(ESPHurtC)
    ESPHurt:AddDependent(ESPHurtC)
end)"""
    content = content[:esp_start] + NEW_ESP + content[esp_end:]
    results.append('OK: ESP rewrite')

# ══════════════════════════════════════════════════════════════════════════════
# 6.  REWRITE FREECAM (Vape-style, extract actual pitch/yaw, force Scriptable)
# ══════════════════════════════════════════════════════════════════════════════
OLD_FREECAM_INNER = '''    FCBtn = GuiLibrary.Registry.renderPanel.API.CreateOptionsButton({
        Name = "Freecam",
        Function = function(on)
            if on then
                fcActive = true
                Camera.CameraType = Enum.CameraType.Scriptable
                local camCF = Camera.CFrame
                local pitch, yaw = 0, 0
                UIS.MouseBehavior = Enum.MouseBehavior.LockCenter

                fcConn = RunService.RenderStepped:Connect(function(dt)
                    if not fcActive then return end
                    local speed = FCSpeed and FCSpeed.Value or 30
                    local fast  = UIS:IsKeyDown(Enum.KeyCode.LeftShift) and 3 or 1
                    local move  = Vector3.zero
                    if UIS:IsKeyDown(Enum.KeyCode.W) then move = move + Vector3.new(0,0,-1) end
                    if UIS:IsKeyDown(Enum.KeyCode.S) then move = move + Vector3.new(0,0, 1) end
                    if UIS:IsKeyDown(Enum.KeyCode.A) then move = move + Vector3.new(-1,0,0) end
                    if UIS:IsKeyDown(Enum.KeyCode.D) then move = move + Vector3.new( 1,0,0) end
                    if UIS:IsKeyDown(Enum.KeyCode.E) then move = move + Vector3.new(0, 1,0) end
                    if UIS:IsKeyDown(Enum.KeyCode.Q) then move = move + Vector3.new(0,-1,0) end

                    local mDelta = UIS:GetMouseDelta()
                    yaw   = yaw   - mDelta.X * 0.3
                    pitch = math.clamp(pitch - mDelta.Y * 0.3, -89, 89)
                    local rot = CFrame.Angles(0, math.rad(yaw), 0) * CFrame.Angles(math.rad(pitch), 0, 0)

                    if move.Magnitude > 0 then
                        camCF = CFrame.new(camCF.Position + rot:VectorToWorldSpace(move.Unit) * speed * fast * dt) * rot
                    else
                        camCF = CFrame.new(camCF.Position) * rot
                    end
                    Camera.CFrame = camCF
                    if FCFOV then Camera.FieldOfView = FCFOV.Value end
                end)
            else
                fcActive = false
                if fcConn then fcConn:Disconnect(); fcConn = nil end
                Camera.CameraType = Enum.CameraType.Custom
                UIS.MouseBehavior = Enum.MouseBehavior.Default
                Camera.FieldOfView = 70
            end
        end
    })
    FCSpeed = FCBtn.CreateSlider({Name="Speed",    Min=5, Max=200, Default=30, Round=1})
    FCFOV   = FCBtn.CreateSlider({Name="FOV",      Min=20, Max=120, Default=70, Round=1})'''

NEW_FREECAM_INNER = '''    FCBtn = GuiLibrary.Registry.renderPanel.API.CreateOptionsButton({
        Name = "Freecam",
        Function = function(on)
            if on then
                fcActive = true
                -- Extract actual pitch/yaw from current camera to avoid snap
                local lv    = Camera.CFrame.LookVector
                local pitch = math.asin(math.clamp(lv.Y, -1, 1))
                local yaw   = math.atan2(-lv.X, -lv.Z)
                local camPos= Camera.CFrame.Position

                UIS.MouseBehavior = Enum.MouseBehavior.LockCenter

                fcConn = RunService.RenderStepped:Connect(function(dt)
                    if not fcActive then return end
                    -- Force Scriptable every frame so game camera can't fight it
                    if Camera.CameraType ~= Enum.CameraType.Scriptable then
                        Camera.CameraType = Enum.CameraType.Scriptable
                    end

                    local speed = FCSpeed and FCSpeed.Value or 30
                    local fast  = UIS:IsKeyDown(Enum.KeyCode.LeftShift) and 3 or 1
                    local move  = Vector3.zero
                    if UIS:IsKeyDown(Enum.KeyCode.W) then move += Vector3.new(0,0,-1) end
                    if UIS:IsKeyDown(Enum.KeyCode.S) then move += Vector3.new(0,0, 1) end
                    if UIS:IsKeyDown(Enum.KeyCode.A) then move += Vector3.new(-1,0,0) end
                    if UIS:IsKeyDown(Enum.KeyCode.D) then move += Vector3.new( 1,0,0) end
                    if UIS:IsKeyDown(Enum.KeyCode.E) then move += Vector3.new(0, 1,0) end
                    if UIS:IsKeyDown(Enum.KeyCode.Q) then move += Vector3.new(0,-1,0) end

                    local md = UIS:GetMouseDelta()
                    yaw   = yaw   - md.X * 0.003
                    pitch = math.clamp(pitch - md.Y * 0.003, -math.pi/2+0.01, math.pi/2-0.01)

                    local rot = CFrame.fromEulerAnglesYXZ(pitch, yaw, 0)
                    if move.Magnitude > 0 then
                        camPos = camPos + rot:VectorToWorldSpace(move.Unit) * speed * fast * dt
                    end
                    Camera.CFrame = CFrame.new(camPos) * rot
                    if FCFOV then Camera.FieldOfView = FCFOV.Value end
                end)
            else
                fcActive = false
                if fcConn then fcConn:Disconnect(); fcConn = nil end
                Camera.CameraType = Enum.CameraType.Custom
                UIS.MouseBehavior = Enum.MouseBehavior.Default
                Camera.FieldOfView = 70
            end
        end
    })
    FCSpeed = FCBtn.CreateSlider({Name="Speed",    Min=5, Max=200, Default=30, Round=1})
    FCFOV   = FCBtn.CreateSlider({Name="FOV",      Min=20, Max=120, Default=70, Round=1})'''

apply('Freecam rewrite', OLD_FREECAM_INNER, NEW_FREECAM_INNER)

# ══════════════════════════════════════════════════════════════════════════════
# 7.  BEDESP LAG — throttle to every 12 frames + fix background auto-size
# ══════════════════════════════════════════════════════════════════════════════
apply('BedESP throttle',
    '                RunLoops:BindToHeartbeat("BedESP", function()',
    '                local bedN = 0\n                RunLoops:BindToHeartbeat("BedESP", function()\n                    bedN += 1; if bedN % 10 ~= 0 then return end')

# Fix BedESP background auto-size: update BillboardGui size based on text
apply('BedESP bg auto-size',
    '''                        entry.lbl.Text = table.concat(parts, "  ")
                    end
                end
                    for bed, entry in pairs(bedEntries) do''',
    '''                        local txt = table.concat(parts, "  ")
                        entry.lbl.Text = txt
                        -- Auto-size BillboardGui to fit text
                        local ts = entry.lbl.TextSize or 12
                        local approxW = math.max(60, #txt * ts * 0.55 + 14)
                        entry.bb.Size = UDim2.fromOffset(approxW, ts + 8)
                    end
                end
                    for bed, entry in pairs(bedEntries) do''')

# ══════════════════════════════════════════════════════════════════════════════
# 8.  TNT DETECTOR — add countdown timer using spawn-time tracking
# ══════════════════════════════════════════════════════════════════════════════
apply('TNT spawnTimes table',
    '    local tntEntries = {}\n    local TNTBtn, TNTColor, TNTMaxDist, TNTShowName, TNTShowDist, TNTBg, TNTCorner',
    '    local tntEntries = {}\n    local tntSpawn  = {}   -- [obj] = tick() when first seen\n    local TNTBtn, TNTColor, TNTMaxDist, TNTShowName, TNTShowDist, TNTBg, TNTCorner\n    local TNT_FUSE  = 4.0   -- approximate fuse duration in seconds')

apply('TNT record spawn time',
    '                            seen[obj] = true\n                            if not tntEntries[obj] then',
    '                            seen[obj] = true\n                            if not tntSpawn[obj] then tntSpawn[obj] = tick() end\n                            if not tntEntries[obj] then')

# Update TNT label to show countdown
apply('TNT countdown label',
    '''                            if showN or showD then
                                local dist = myRoot and math.floor((myRoot.Position - pos).Magnitude) or 0
                                local parts = {}
                                if showN then parts[#parts+1] = obj.Name end
                                if showD then parts[#parts+1] = dist.."m" end
                                entry.lbl.Text = table.concat(parts, "  ")
                            end''',
    '''                            if showN or showD then
                                local dist = myRoot and math.floor((myRoot.Position - pos).Magnitude) or 0
                                local elapsed  = tick() - (tntSpawn[obj] or tick())
                                local remaining= math.max(0, TNT_FUSE - elapsed)
                                local parts = {}
                                if showN then parts[#parts+1] = obj.Name end
                                parts[#parts+1] = string.format("%.1fs", remaining)
                                if showD then parts[#parts+1] = dist.."m" end
                                entry.lbl.Text = table.concat(parts, "  ")
                            end''')

# Clean up tntSpawn on object removal
apply('TNT cleanup spawnTimes',
    '''                    for obj, entry in pairs(tntEntries) do
                        if not seen[obj] or not obj.Parent then
                            if entry.h  and entry.h.Parent  then entry.h:Destroy()  end
                            if entry.bb and entry.bb.Parent then entry.bb:Destroy() end
                            tntEntries[obj] = nil
                        end
                    end''',
    '''                    for obj, entry in pairs(tntEntries) do
                        if not seen[obj] or not obj.Parent then
                            if entry.h  and entry.h.Parent  then entry.h:Destroy()  end
                            if entry.bb and entry.bb.Parent then entry.bb:Destroy() end
                            tntEntries[obj] = nil; tntSpawn[obj] = nil
                        end
                    end''')

apply('TNT disable cleanup spawnTimes',
    '''                for _, e in pairs(tntEntries) do
                    if e.h  and e.h.Parent  then e.h:Destroy()  end
                    if e.bb and e.bb.Parent then e.bb:Destroy() end
                end
                tntEntries = {}''',
    '''                for _, e in pairs(tntEntries) do
                    if e.h  and e.h.Parent  then e.h:Destroy()  end
                    if e.bb and e.bb.Parent then e.bb:Destroy() end
                end
                tntEntries = {}; tntSpawn = {}''')

# ══════════════════════════════════════════════════════════════════════════════
# 9.  CHESTESP — add dropped-item icons above generators (like NameTags armor)
# ══════════════════════════════════════════════════════════════════════════════
apply('ChestESP show dropped item icons',
    '''                            local dist = myRoot and math.floor((myRoot.Position - cf.Position).Magnitude) or 0
                                local parts = {}
                                if showT then parts[#parts+1] = genType(child.Name) end
                                parts[#parts+1] = dist.."m"
                                entry.lbl.Text = table.concat(parts, "  "); entry.lbl.TextColor3 = c
                            end''',
    '''                            local dist = myRoot and math.floor((myRoot.Position - cf.Position).Magnitude) or 0
                                local parts = {}
                                if showT then parts[#parts+1] = genType(child.Name) end
                                parts[#parts+1] = dist.."m"
                                local txt = table.concat(parts, "  ")
                                entry.lbl.Text = txt; entry.lbl.TextColor3 = c
                                -- Auto-size bb to fit
                                local ts = 12
                                local approxW = math.max(70, #txt * ts * 0.55 + 14)
                                entry.bb.Size = UDim2.fromOffset(approxW, ts + 8)
                            end
                            -- Show nearby dropped items as icons above generator
                            local droppedCont = workspace:FindFirstChild("DroppedItemsContainer")
                            local itemsNear = {}
                            if droppedCont and cf then
                                for _, m in ipairs(droppedCont:GetChildren()) do
                                    if not m:IsA("Model") then continue end
                                    local hb = m:FindFirstChild("Hitbox") or m:FindFirstChildOfClass("BasePart")
                                    if hb and (cf.Position - hb.Position).Magnitude <= 8 then
                                        local idata = bedfight.modules.ItemsData[m.Name]
                                        if idata and idata.Image then
                                            itemsNear[#itemsNear+1] = {name=m.Name, image=idata.Image, count=1}
                                        end
                                    end
                                end
                            end
                            -- Build/update icon row in a second BillboardGui
                            if not entry.iconBB then
                                local ibb = Instance.new("BillboardGui")
                                ibb.Name = "PhantomChestIcons"; ibb.AlwaysOnTop = true
                                ibb.Size = UDim2.fromOffset(120, 24); ibb.StudsOffset = Vector3.new(0,6,0)
                                ibb.Parent = child
                                entry.iconBB = ibb; entry.iconSig = ""
                            end
                            local sig = ""
                            for _,it in ipairs(itemsNear) do sig = sig..it.name.."," end
                            if sig ~= entry.iconSig then
                                entry.iconSig = sig
                                entry.iconBB:ClearAllChildren()
                                if #itemsNear > 0 then
                                    local sz = 18; local pad = 2
                                    local totalW = #itemsNear*sz + math.max(0,#itemsNear-1)*pad
                                    local bgF = Instance.new("Frame", entry.iconBB)
                                    bgF.Size = UDim2.fromOffset(totalW+6, sz+4)
                                    bgF.Position = UDim2.new(0.5,-(totalW+6)/2, 0.5,-(sz+4)/2)
                                    bgF.BackgroundColor3 = Color3.fromRGB(12,12,12)
                                    bgF.BackgroundTransparency = 0.3; bgF.BorderSizePixel = 0
                                    local cr2 = Instance.new("UICorner",bgF); cr2.CornerRadius=UDim.new(0,4)
                                    entry.iconBB.Size = UDim2.fromOffset(math.max(120,totalW+10), 26)
                                    for i, it in ipairs(itemsNear) do
                                        local img = Instance.new("ImageLabel", bgF)
                                        img.Size = UDim2.fromOffset(sz,sz)
                                        img.Position = UDim2.fromOffset(3+(i-1)*(sz+pad), 2)
                                        img.BackgroundTransparency=1; img.BorderSizePixel=0
                                        img.Image = it.image; img.ScaleType=Enum.ScaleType.Fit
                                    end
                                end
                            end
                            entry.iconBB.Enabled = #itemsNear > 0''')

# Also destroy iconBB on cleanup
apply('ChestESP iconBB destroy',
    '''                    for model, entry in pairs(genBoxes) do
                        if not seen[model] or not model.Parent then
                            if entry.box and entry.box.Parent then entry.box:Destroy() end
                            if entry.bb  and entry.bb.Parent  then entry.bb:Destroy()  end
                            genBoxes[model] = nil
                        end
                    end''',
    '''                    for model, entry in pairs(genBoxes) do
                        if not seen[model] or not model.Parent then
                            if entry.box    and entry.box.Parent    then entry.box:Destroy()    end
                            if entry.bb     and entry.bb.Parent     then entry.bb:Destroy()     end
                            if entry.iconBB and entry.iconBB.Parent then entry.iconBB:Destroy() end
                            genBoxes[model] = nil
                        end
                    end''')

apply('ChestESP iconBB disable cleanup',
    '''            else
                RunLoops:UnbindFromHeartbeat("ChestESP")
                for _, entry in pairs(genBoxes) do
                    if entry.box and entry.box.Parent then entry.box:Destroy() end
                    if entry.bb  and entry.bb.Parent  then entry.bb:Destroy()  end
                end
                genBoxes = {}
            end''',
    '''            else
                RunLoops:UnbindFromHeartbeat("ChestESP")
                for _, entry in pairs(genBoxes) do
                    if entry.box    and entry.box.Parent    then entry.box:Destroy()    end
                    if entry.bb     and entry.bb.Parent     then entry.bb:Destroy()     end
                    if entry.iconBB and entry.iconBB.Parent then entry.iconBB:Destroy() end
                end
                genBoxes = {}
            end''')

# ══════════════════════════════════════════════════════════════════════════════
# 10. ARMOR HUD — hide when no armor, auto-update on slot change
# ══════════════════════════════════════════════════════════════════════════════
apply('ArmorHUD hide when no armor',
    '''                    if sig ~= lastSig then
                        lastSig = sig
                        rebuildIcons(slots, sz, pad, bgOn, cStyle)
                    end''',
    '''                    local hasAny = next(slots) ~= nil
                    hudFrame.Visible = bgOn and hasAny
                    -- also show icons even without bg frame
                    for _, lbl2 in ipairs(iconLabels) do
                        lbl2.Visible = hasAny
                    end
                    if sig ~= lastSig then
                        lastSig = sig
                        rebuildIcons(slots, sz, pad, bgOn, cStyle)
                    end''')

# ══════════════════════════════════════════════════════════════════════════════
# 11. ITEMesp background auto-size using approx text width
# ══════════════════════════════════════════════════════════════════════════════
apply('ItemESP bg auto-size',
    '''                        if lbl then
                            lbl.TextColor3 = itemColor(model.Name)
                            lbl.TextSize   = math.clamp(sz / 9, 9, 16)
                            local parts = {}
                            if showN then parts[#parts+1] = model.Name end
                            if showD then parts[#parts+1] = math.floor(dist).."m" end
                            lbl.Text = table.concat(parts, "  ")
                        end''',
    '''                        if lbl then
                            lbl.TextColor3 = itemColor(model.Name)
                            local ts = math.clamp(math.floor(sz / 9), 9, 16)
                            lbl.TextSize   = ts
                            local parts = {}
                            if showN then parts[#parts+1] = model.Name end
                            if showD then parts[#parts+1] = math.floor(dist).."m" end
                            local txt = table.concat(parts, "  ")
                            lbl.Text = txt
                            -- Auto-resize billboard to match text
                            local approxW = math.max(60, #txt * ts * 0.55 + 14)
                            local bbItem = type(itemBBs[model]) == "table" and itemBBs[model].bb or nil
                            if bbItem then bbItem.Size = UDim2.fromOffset(approxW, ts + 8) end
                        end''')

# ══════════════════════════════════════════════════════════════════════════════
# 12. NAMETAG ICONS — fix centering: center icons relative to board width
# ══════════════════════════════════════════════════════════════════════════════
# The current code uses baseTagW for centering but the board may be wider
# Fix: center based on actual board width (cBoardW)
apply('NameTag icon centering fix',
    '                                        local totalIconW = #items * iconPx + math.max(0, #items - 1) * 2\n                                        local startX = math.floor((math.max(baseTagW, 1) - totalIconW) / 2)',
    '                                        local totalIconW = #items * iconPx + math.max(0, #items - 1) * 2\n                                        local boardW = entry.cBoardW or baseTagW\n                                        local startX = math.floor((math.max(boardW, 1) - totalIconW) / 2)')

# ══════════════════════════════════════════════════════════════════════════════
# 13. PROJ AURA — fix switchitem not reverting (projSwitching unused)
# ══════════════════════════════════════════════════════════════════════════════
apply('ProjAura remove projSwitching reset',
    '''                RunLoops:UnbindFromHeartbeat("Projectile")
                projSwitching  = false
                targetTrackers = {}
                local sw = getsword()
                if sw then switchitem(sw) else revertitem() end''',
    '''                RunLoops:UnbindFromHeartbeat("Projectile")
                targetTrackers = {}
                task.defer(function()
                    local sw = getsword()
                    if sw then switchitem(sw) else revertitem() end
                end)''')

# ══════════════════════════════════════════════════════════════════════════════
# 14. FONTS — standardize all Gotham* to GothamSemibold, Drawing to Fonts.UI
# ══════════════════════════════════════════════════════════════════════════════
# Replace all instances in BillboardGui text labels we wrote (esp_new style)
content = content.replace('Enum.Font.GothamBold',  'Enum.Font.GothamSemibold')
results.append('OK: Font GothamBold -> GothamSemibold')

# ══════════════════════════════════════════════════════════════════════════════
# Write output
# ══════════════════════════════════════════════════════════════════════════════
with open(path, 'w', encoding='utf-8', newline='\n') as f:
    f.write(content)

with open(path, 'r', encoding='utf-8') as f:
    vc = f.read()
vlines = vc.splitlines()
print(f"Final line count: {len(vlines)}")
for r in results:
    print(r)

# Spot checks
checks = [
    ('Trajectories removed', 'Name = "Trajectories"'),
    ('ESP rewrite DrawSquare', 'Drawing.new("Square")'),
    ('ESP bounds2D positive', 'local sw  = math.abs(tS.X - bS.X)'),
    ('ESP health bar fix',    'top + sh*(1-ratio)'),
    ('Freecam fromEuler',     'CFrame.fromEulerAnglesYXZ'),
    ('Freecam force Scriptable', 'Camera.CameraType ~= Enum.CameraType.Scriptable'),
    ('BlockRange fix',        'bedfight.modules.BlocksData.Default.Range = callback'),
    ('Killaura CharAdded',    'KA_CharConn'),
    ('Killaura sword check',  'only animate when sword is equipped'),
    ('TNT countdown',         'TNT_FUSE'),
    ('TNT timer label',       'string.format("%.1fs"'),
    ('ChestESP icons',        'PhantomChestIcons'),
    ('ArmorHUD hide empty',   'next(slots) ~= nil'),
    ('BedESP throttle',       'bedN % 10'),
    ('ItemESP auto-size',     'approxW = math.max(60'),
    ('Auto in COL_LIST',      '"Auto","Theme"'),
    ('Font standardized',     'Enum.Font.GothamSemibold'),
    ('NTag icon center fix',  'boardW = entry.cBoardW'),
    ('ProjAura defer revert', 'task.defer(function()'),
]
print('\nSpot checks:')
for label, needle in checks:
    found = needle in vc
    print(f"  {'OK' if found else 'MISSING'}: {label}")
