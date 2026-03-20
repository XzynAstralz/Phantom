local P = {
    BASE0      = Color3.fromRGB(10,  11,  16),
    BASE1      = Color3.fromRGB(17,  18,  25),
    BASE2      = Color3.fromRGB(22,  23,  31),
    BASE3      = Color3.fromRGB(26,  27,  36),
    BASE_HOV   = Color3.fromRGB(30,  32,  44),
    BASE_LIT   = Color3.fromRGB(24,  80, 188),
    HUE        = Color3.fromRGB( 48, 115, 232),
    HUE_FADE   = Color3.fromRGB( 28,  65, 148),
    EDGE       = Color3.fromRGB( 33,  35,  50),
    EDGE_HI    = Color3.fromRGB( 52,  98, 200),
    INK_HI     = Color3.fromRGB(228, 230, 240),
    INK_MID    = Color3.fromRGB(150, 153, 168),
    INK_LOW    = Color3.fromRGB( 84,  87, 108),
    INK_BETA   = Color3.fromRGB( 42, 182, 192),
    INK_NEW    = Color3.fromRGB( 189, 111, 255),
    STATE_ON   = Color3.fromRGB( 68, 192,  82),
    STATE_OFF  = Color3.fromRGB(212,  60,  65),
    CAUTION    = Color3.fromRGB(212, 168,  27),
}

local R_SM = UDim.new(0, 3)
local R_MD = UDim.new(0, 5)
local R_LG = UDim.new(0, 7)

local COL_W    = 120
local ROW_W    = 113
local SUB_W    = 106
local ROW_H    = 18
local HDR_H    = 22

local function mkCorner(p, r)
    local c = Instance.new("UICorner"); c.CornerRadius = r or R_SM; c.Parent = p; return c
end
local function mkBorder(p, col, thick, trans)
    local s = Instance.new("UIStroke")
    s.Color           = col or P.EDGE
    s.Thickness       = thick or 1
    s.Transparency    = trans or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = p; return s
end
local function mkPad(p, t, b, l, r)
    local u = Instance.new("UIPadding")
    u.PaddingTop    = UDim.new(0, t or 0)
    u.PaddingBottom = UDim.new(0, b or 0)
    u.PaddingLeft   = UDim.new(0, l or 0)
    u.PaddingRight  = UDim.new(0, r or 0)
    u.Parent = p; return u
end
local function mkChevron(parent, xPos, _, sz)
    local a = Instance.new("ImageLabel")
    a.Parent              = parent
    a.BackgroundTransparency = 1
    a.BorderSizePixel     = 0
    a.Position            = UDim2.new(0, xPos, 0.5, -math.floor(sz / 2))
    a.Size                = UDim2.new(0, sz, 0, sz)
    a.Image               = "http://www.roblox.com/asset/?id=6031094679"
    a.ImageColor3         = P.INK_LOW
    a.ScaleType           = Enum.ScaleType.Fit
    a.Rotation            = 180
    a.ZIndex              = 3; return a
end

local Hook = {}; Hook.__index = Hook

function Hook.new()
    return setmetatable({ _slots = {}, _seq = 0 }, Hook)
end

function Hook:Bind(fn)
    self._seq = self._seq + 1
    local id   = self._seq
    local slots = self._slots
    slots[id] = fn
    return {
        Active     = true,
        Unbind = function(self)
            slots[id]  = nil
            self.Active = false
        end,

        Connected  = true,
        Disconnect = function(self)
            slots[id]  = nil
            self.Active    = false
            self.Connected = false
        end,
    }
end

function Hook:Emit(...)
    for _, fn in next, self._slots do fn(...) end
end

Hook.Connect = Hook.Bind
Hook.Fire    = Hook.Emit


local UIS          = game:GetService("UserInputService")
local Tween        = game:GetService("TweenService")
local Runner       = game:GetService("RunService")


local Spectrum = {}
local kit      = {}; Spectrum.kit = kit
local Scaler   

do 
    function kit:activeColor()
        if kit:rainbowActive() then return kit:rainbowColor() end
        return P.HUE
    end

    function kit:objectColor(obj)
        if not kit:rainbowActive() then return P.HUE end
        local y = 0
        pcall(function() y = obj.AbsolutePosition.Y end)
        return kit:rainbowColor(y)
    end

    function kit:readPalette(asTable)
        local t = Spectrum.Palette or { H = 0.60, S = 0.79, V = 0.91 }
        return asTable and t or Color3.fromHSV(t.H, t.S, t.V)
    end

    function kit:writePalette(color)
        local t = typeof(color)
        Spectrum.Palette = Spectrum.Palette or {}
        if t == "table" then
            Spectrum.Palette = color
        else
            local h, s, v = color:ToHSV()
            Spectrum.Palette.H = h
            Spectrum.Palette.S = s
            Spectrum.Palette.V = v
        end
        if Spectrum.PaletteSync then Spectrum.PaletteSync:Emit() end
    end

    function kit:rainbowActive() return Spectrum.RainbowMode or false end

    function kit:rainbowColor(y)
        if not kit:rainbowActive() then return P.HUE end
        y = math.abs(y or 0)
        local pal  = kit:readPalette(true)
        local h    = pal.H + y / (Spectrum.RainbowSpeed or 1750)
        while h > 1 do h = h - 1 end
        return Color3.fromHSV(h, pal.S, pal.V)
    end

    function kit:track(conn)
        if not Spectrum.Tracked then Spectrum.Tracked = {} end
        Spectrum.Tracked[#Spectrum.Tracked + 1] = conn
    end

    function kit:register(name, obj)
        if not Spectrum.Registry then Spectrum.Registry = {} end
        Spectrum.Registry[name] = obj
    end

    function kit:deregister(name)
        local function purge(t)
            for _, v in next, t do
                local k = typeof(v)
                if k == "Instance" then
                    v:Destroy()
                elseif k == "RBXScriptConnection" then
                    if v.Connected then v:Disconnect() end
                elseif k == "table" and v.Unbind then
                    v:Unbind()
                elseif k == "table" then
                    purge(v)
                end
            end
        end
        if Spectrum.Registry and Spectrum.Registry[name] then
            purge(Spectrum.Registry[name])
            Spectrum.Registry[name] = nil
        end
    end

    function kit:nextSlot()
        Spectrum.SlotIndex = (Spectrum.SlotIndex or 0) + 1
        return Spectrum.SlotIndex
    end

    function kit:repositionPanels(scale)
        local bars = Spectrum.PanelBars
        if not bars or #bars == 0 then return end
        local s      = scale or 1
        local vp     = workspace.CurrentCamera.ViewportSize
        local totalW = #bars * COL_W + (#bars - 1) * 2
        local startX = math.floor((vp.X / s - totalW) / 2)
        for i, bar in ipairs(bars) do
            bar.Position = UDim2.new(0, startX + (i - 1) * (COL_W + 2), 0.055, 0)
        end
    end

    function kit:drag(gui, handle)
        local dragging, origin, startPos = false
        handle.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging  = true
                origin    = Vector2.new(input.Position.X, input.Position.Y)
                startPos  = gui.Position
            end
        end)
        UIS.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
        end)
        UIS.InputChanged:Connect(function(input)
            if not dragging or input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
            local s     = Scaler.Scale > 0 and Scaler.Scale or 1
            local delta = Vector2.new(input.Position.X, input.Position.Y) - origin
            gui.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X / s,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y / s)
        end)
    end

    function kit:rescale(scaler)
        local vp      = workspace.CurrentCamera.ViewportSize
        local total   = math.max(Spectrum.PanelCount or 1, 1)
        local needed  = total * (COL_W + 2)
        local natural = math.clamp(vp.X / needed, 0.25, 1.5)
        local s       = Spectrum.canScale == false and 1 or natural
        scaler.Scale  = s
        kit:repositionPanels(s)
    end
end

local PaletteSync  = Hook.new()
local ModuleSync   = Hook.new()
Spectrum.PaletteSync = PaletteSync
Spectrum.ModuleSync  = ModuleSync

Spectrum.ColorUpdate  = PaletteSync
Spectrum.ButtonUpdate = ModuleSync

local Screen  = Instance.new("ScreenGui")
local Root    = Instance.new("Frame")
Scaler  = Instance.new("UIScale")

Screen.Name            = "Spectrum"
Screen.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
Screen.IgnoreGuiInset  = true
Screen.DisplayOrder    = 9e9
Screen.OnTopOfCoreBlur = true
Screen.ResetOnSpawn    = false

Root.Name                   = "Root"
Root.Parent                 = Screen
Root.BackgroundTransparency = 1
Root.Size                   = UDim2.new(1, 0, 1, 0)
Scaler.Parent = Screen

local easing    = { Enum.EasingStyle.Circular, Enum.EasingDirection.Out }
local panelTI   = TweenInfo.new(0.45, unpack(easing))

Spectrum.toggle = function()
    Root.Position = UDim2.new()
    Root.Visible  = not Root.Visible
end

game:GetService("UserInputService").InputChanged:Connect(function(input)
    if Root.Visible and input.UserInputType == Enum.UserInputType.MouseWheel then
        Tween:Create(Root, TweenInfo.new(0.1, unpack(easing)), {
            Position = UDim2.new(0, 0, Root.Position.Y.Scale + input.Position.Z / 20),
        }):Play()
    end
end)

if gethui then
    Screen.Parent = gethui()
else
    Screen.Parent = game:GetService("CoreGui")
end
if syn and not gethui then syn.protect_gui(Screen) end

kit:rescale(Scaler)
kit:track(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
    kit:rescale(Scaler)
end))

Spectrum.rescale  = function() kit:rescale(Scaler) end
Spectrum.Scaler   = Scaler
Spectrum.Root     = Root
Spectrum.Screen   = Screen


Spectrum.UIScale   = Scaler
Spectrum.ClickGUI  = Root
Spectrum.ScreenGui = Screen
Spectrum.toggleGui = Spectrum.toggle

kit:track(PaletteSync:Bind(function()
    local col      = kit:readPalette()
    P.HUE          = col
    P.HUE_FADE     = col:Lerp(Color3.new(0, 0, 0),   0.45)
    P.EDGE_HI      = col:Lerp(Color3.new(0, 0, 0.5), 0.30)
    P.BASE_LIT     = col:Lerp(Color3.new(0, 0, 0),   0.55)

    if Spectrum.Registry then
        for _, v in next, Spectrum.Registry do
            if v.Type == "OptionsButton" and v.API.Enabled then
                v.Instance.BackgroundColor3 = P.BASE_LIT
            end
        end
    end
end))

kit:track(Runner.PreRender:Connect(function()
    if not Spectrum.RainbowMode then return end
    local old = Spectrum.Palette or {}
    local h   = (old.H or 0) + 0.001
    if h >= 1 then h = h - 1 end
    kit:writePalette({ H = h, S = old.S or 1, V = old.V or 1 })
end))

local stateColors   = { on = {68,192,82}, off = {212,60,65}, warn = {212,168,27} }
local toastQueue    = {}
local slideTime     = 0.16
local toastGap      = 0.002

Spectrum.toast = function(titleStr, bodyStr, duration, hlWord)
    if not getgenv().configloaded then return end
    coroutine.wrap(function()
        local card = Instance.new("ImageLabel")
        card.Parent               = Screen
        card.BorderSizePixel      = 0
        card.Size                 = UDim2.new(0.13, 0, 0.082, 0)
        card.Position             = UDim2.new(1, 0, 0, 0)
        card.BackgroundTransparency = 1
        card.Image               = getcustomasset("Phantom/assets/background.png")
        card.ImageColor3         = P.BASE1
        card.ScaleType           = Enum.ScaleType.Slice
        card.SliceCenter         = Rect.new(8, 8, 92, 100)
        mkCorner(card, R_MD); mkBorder(card, P.EDGE, 1)

        local progBack = Instance.new("Frame")
        progBack.Parent             = card
        progBack.BackgroundColor3   = P.BASE2
        progBack.BorderSizePixel    = 0
        progBack.Position           = UDim2.new(0, 0, 0.92, 0)
        progBack.Size               = UDim2.new(1, 0, 0.08, 0)
        mkCorner(progBack, UDim.new(0, 2))

        local progFill = Instance.new("Frame")
        progFill.Parent           = progBack
        progFill.BackgroundColor3 = P.HUE
        progFill.BackgroundTransparency = 0.15
        progFill.BorderSizePixel  = 0
        progFill.Size             = UDim2.new(1, 0, 1, 0)
        mkCorner(progFill, UDim.new(0, 2))

        local titleLbl = Instance.new("TextLabel")
        titleLbl.Parent               = card
        titleLbl.BackgroundTransparency = 1
        titleLbl.BorderSizePixel      = 0
        titleLbl.Position             = UDim2.new(0.06, 0, 0.1, 0)
        titleLbl.Size                 = UDim2.new(0.88, 0, 0.32, 0)
        titleLbl.Font                 = Enum.Font.GothamBold
        titleLbl.TextColor3           = P.INK_HI
        titleLbl.TextScaled           = true
        titleLbl.TextWrapped          = true
        titleLbl.TextXAlignment       = Enum.TextXAlignment.Left
        titleLbl.RichText             = true

        local bodyLbl = Instance.new("TextLabel")
        bodyLbl.Parent              = card
        bodyLbl.BackgroundTransparency = 1
        bodyLbl.BorderSizePixel     = 0
        bodyLbl.Position            = UDim2.new(0.06, 0, 0.46, 0)
        bodyLbl.Size                = UDim2.new(0.88, 0, 0.30, 0)
        bodyLbl.Font                = Enum.Font.GothamSemibold
        bodyLbl.TextColor3          = P.INK_MID
        bodyLbl.TextScaled          = true
        bodyLbl.TextWrapped         = true
        bodyLbl.TextXAlignment      = Enum.TextXAlignment.Left
        bodyLbl.RichText            = true

        local aspect = Instance.new("UIAspectRatioConstraint")
        aspect.Parent      = card
        aspect.AspectRatio = 3.4

        titleLbl.Text = titleStr
        if hlWord then
            local nc = stateColors.warn
            bodyLbl.Text = bodyStr:gsub(hlWord,
                ('<font color="rgb(%d,%d,%d)">%s</font>'):format(nc[1], nc[2], nc[3], hlWord))
        elseif type(bodyStr) == "boolean" then
            local nc  = bodyStr and stateColors.on or stateColors.off
            local tag = bodyStr and "Enabled!" or "Disabled!"
            bodyLbl.Text = ('%s has been <font color="rgb(%d,%d,%d)">%s</font>'):format(
                titleStr, nc[1], nc[2], nc[3], tag)
        else
            bodyLbl.Text = bodyStr or titleStr
        end

        local delay = duration or 3
        table.insert(toastQueue, { card = card, bar = progBack, duration = delay })

        for i, item in ipairs(toastQueue) do
            local tY = 0.9 - (card.Size.Y.Scale + toastGap - 0.004) * (i - 1)
            item.card.Position = UDim2.new(0.87, 0, tY, 0)
        end

        card.Position = UDim2.new(1, 0, card.Position.Y.Scale, 0)
        Tween:Create(card, TweenInfo.new(slideTime, unpack(easing)),
            { Position = UDim2.new(0.87, 0, card.Position.Y.Scale, 0) }):Play()
        Tween:Create(progFill, TweenInfo.new(delay - 0.2, unpack(easing)),
            { Size = UDim2.new(0, 0, 1, 0) }):Play()

        task.delay(delay + slideTime / 2, function()
            Tween:Create(card, TweenInfo.new(slideTime, unpack(easing)),
                { Position = UDim2.new(1, 0, card.Position.Y.Scale, 0) }):Play()
            task.delay(slideTime, function()
                for i, item in ipairs(toastQueue) do
                    if item.card == card then table.remove(toastQueue, i); break end
                end
                for i, item in ipairs(toastQueue) do
                    local tY = 0.9 - (card.Size.Y.Scale - toastGap) * (i - 1)
                    Tween:Create(item.card, TweenInfo.new(slideTime, unpack(easing)),
                        { Position = UDim2.new(0.87, 0, tY, 0) }):Play()
                end
                card:Destroy()
            end)
        end)
    end)()
end


Spectrum.createNotification = Spectrum.toast

local LAYOUT_FILE = "config/layout.json"

local function readLayout()
    local ok, data = pcall(function()
        return game:GetService("HttpService"):JSONDecode(readfile(LAYOUT_FILE))
    end)
    return (ok and type(data) == "table") and data or {}
end

local function writeLayout()
    local positions = {}
    for _, bar in ipairs(Spectrum.PanelBars or {}) do
        positions[bar.Name] = { X = bar.Position.X.Offset, Y = bar.Position.Y.Offset }
    end
    pcall(function()
        if not isfolder("config") then makefolder("config") end
        writefile(LAYOUT_FILE, game:GetService("HttpService"):JSONEncode(positions))
    end)
end

Spectrum.Layout             = readLayout()
Spectrum.saveTabPositions   = writeLayout
Spectrum.TabPositions       = Spectrum.Layout

local function makeBarDraggable(bar)
    local dragging, origin, startOff = false
    bar.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        dragging  = true
        origin    = Vector2.new(input.Position.X, input.Position.Y)
        startOff  = Vector2.new(bar.Position.X.Offset, bar.Position.Y.Offset)
        bar.BackgroundColor3 = P.BASE_HOV
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 or not dragging then return end
        dragging = false
        bar.BackgroundColor3 = P.BASE2
        writeLayout()
    end)
    UIS.InputChanged:Connect(function(input)
        if not dragging or input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        local s     = Scaler.Scale > 0 and Scaler.Scale or 1
        local delta = Vector2.new(input.Position.X, input.Position.Y) - origin
        bar.Position = UDim2.new(0, startOff.X + delta.X / s, 0, startOff.Y + delta.Y / s)
    end)
end

function Spectrum.window(cfg)
    local panel  = { Open = true }
    local panelId = cfg.Name .. "Panel"

    Spectrum.PanelCount = (Spectrum.PanelCount or 0) + 1
    Spectrum.PanelBars  = Spectrum.PanelBars or {}
    kit:nextSlot()

    local Header = Instance.new("TextButton", Root)
    Header.Name             = cfg.Name .. "Header"
    Header.BackgroundColor3 = P.BASE2
    Header.BorderSizePixel  = 0
    Header.Position         = UDim2.new(0, 0, 0.055, 0)
    Header.Size             = UDim2.new(0, COL_W, 0, HDR_H)
    Header.AutoButtonColor  = false
    Header.Font             = Enum.Font.GothamBold
    Header.Text             = ""
    Header.TextColor3       = P.INK_HI
    Header.TextSize         = 10
    Header.Modal            = true
    mkCorner(Header, R_SM); mkBorder(Header, P.EDGE, 1)

    table.insert(Spectrum.PanelBars, Header)
    local saved = Spectrum.Layout[cfg.Name .. "Header"]
    if saved then
        Header.Position = UDim2.new(0, saved.X, 0, saved.Y)
    else
        kit:rescale(Scaler)
    end
    makeBarDraggable(Header)

    local HdrIcon = Instance.new("ImageLabel")
    HdrIcon.Parent             = Header
    HdrIcon.BackgroundTransparency = 1
    HdrIcon.BorderSizePixel    = 0
    HdrIcon.Position           = UDim2.new(0, 6, 0.5, -5)
    HdrIcon.Size               = UDim2.new(0, 10, 0, 10)
    HdrIcon.Image              = cfg.Icon or "rbxassetid://3926305904"
    HdrIcon.ImageColor3        = P.INK_MID
    HdrIcon.ImageRectOffset    = cfg.IconOffset or Vector2.new(4, 4)
    HdrIcon.ImageRectSize      = cfg.IconSize   or Vector2.new(36, 36)
    HdrIcon.ScaleType          = Enum.ScaleType.Fit
    HdrIcon.ZIndex             = 2

    local HdrTitle = Instance.new("TextLabel")
    HdrTitle.Name               = "Name"; HdrTitle.Parent = Header
    HdrTitle.BackgroundTransparency = 1; HdrTitle.Position = UDim2.new(0, 22, 0, 0)
    HdrTitle.Size               = UDim2.new(1, -50, 1, 0); HdrTitle.ZIndex = 2
    HdrTitle.Font               = Enum.Font.GothamBold; HdrTitle.Text = cfg.Name
    HdrTitle.TextColor3         = P.INK_HI; HdrTitle.TextSize = 10
    HdrTitle.TextXAlignment     = Enum.TextXAlignment.Left

    local CollapseBtn = Instance.new("ImageButton")
    CollapseBtn.Name               = "Collapse"; CollapseBtn.Parent = Header
    CollapseBtn.BackgroundTransparency = 1; CollapseBtn.BorderSizePixel = 0
    CollapseBtn.Position           = UDim2.new(1, -18, 0.5, -6)
    CollapseBtn.Rotation           = 180; CollapseBtn.Size = UDim2.new(0, 12, 0, 12)
    CollapseBtn.ZIndex             = 2
    CollapseBtn.Image              = "http://www.roblox.com/asset/?id=6031094679"
    CollapseBtn.ImageColor3        = P.INK_MID; CollapseBtn.ScaleType = Enum.ScaleType.Fit

    local Body = Instance.new("Frame")
    Body.Name                   = "Body"; Body.Parent = Header
    Body.BackgroundColor3       = P.BASE1
    Body.BackgroundTransparency = 0.02
    Body.BorderSizePixel        = 0
    Body.Position               = UDim2.new(0, 0, 1, 1)
    Body.Size                   = UDim2.new(0, COL_W, 0, 300)
    mkCorner(Body, R_SM); mkBorder(Body, P.EDGE, 1)

    local EntryHolder = Instance.new("Frame")
    EntryHolder.Name                   = "EntryHolder"; EntryHolder.Parent = Body
    EntryHolder.BackgroundTransparency = 1; EntryHolder.BorderSizePixel = 0
    EntryHolder.Size                   = UDim2.new(1, 0, 1, 0)

    local Flow = Instance.new("UIListLayout")
    Flow.Padding             = UDim.new(0, 1)
    Flow.Parent              = EntryHolder
    Flow.HorizontalAlignment = Enum.HorizontalAlignment.Center
    Flow.SortOrder           = Enum.SortOrder.LayoutOrder
    mkPad(EntryHolder, 3, 3, 0, 0)

    function panel.Update()
        local sz = Flow.AbsoluteContentSize
        EntryHolder.Size = UDim2.new(0, COL_W, 0, sz.Y / Scaler.Scale)
        Body.Size        = UDim2.new(0, COL_W, 0, (sz.Y + 10.45) / Scaler.Scale)
    end
    kit:track(Flow:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(panel.Update))
    panel.Update()

    function panel.Collapse()
        if panel.Open then
            Body.Visible        = false; panel.Open = false
            CollapseBtn.Rotation    = 0;    CollapseBtn.ImageColor3 = P.INK_LOW
            EntryHolder.Visible = false
        else
            Body.Visible        = true;  panel.Open = true
            CollapseBtn.Rotation    = 180;   CollapseBtn.ImageColor3 = P.INK_MID
            EntryHolder.Visible = true
        end
        panel.Update()
    end
    CollapseBtn.MouseButton1Click:Connect(panel.Collapse)
    
    panel.Expand = panel.Collapse

    function panel.CreateOptionsButton(cfg2)
        local entry     = { Expanded = false, Enabled = false, Recording = false }
        local entryId   = cfg2.Name .. "Module"

        local Row = Instance.new("TextButton")
        Row.Name                   = entryId .. "Row"
        Row.Parent                 = EntryHolder
        Row.BackgroundColor3       = P.BASE2
        Row.BackgroundTransparency = 0
        Row.BorderSizePixel        = 0
        Row.Size                   = UDim2.new(0, ROW_W, 0, ROW_H)
        Row.Font                   = Enum.Font.GothamSemibold
        Row.Text                   = ""
        Row.TextColor3             = P.INK_MID
        Row.TextSize               = 10
        Row.AutoButtonColor        = false
        entry.Instance             = Row
        mkCorner(Row, R_SM)

        local RowArrow = mkChevron(Row, 4, nil, 8)

        local RowLabel = Instance.new("TextLabel")
        RowLabel.Name               = "Name"; RowLabel.Parent = Row
        RowLabel.BackgroundTransparency = 1; RowLabel.BorderSizePixel = 0
        RowLabel.Position           = UDim2.new(0, 16, 0, 0)
        RowLabel.Size               = UDim2.new(1, -36, 1, 0)
        RowLabel.Font               = Enum.Font.GothamSemibold; RowLabel.Text = cfg2.Name
        RowLabel.TextColor3         = P.INK_MID; RowLabel.TextSize = 10
        RowLabel.TextScaled         = false; RowLabel.TextTruncate = Enum.TextTruncate.AtEnd
        RowLabel.TextXAlignment     = Enum.TextXAlignment.Left

        if cfg2.Beta then
            local Badge = Instance.new("TextLabel")
            Badge.Name               = "Beta"; Badge.Parent = Row
            Badge.BackgroundTransparency = 1; Badge.BorderSizePixel = 0
            Badge.AnchorPoint        = Vector2.new(1, 0.5)
            Badge.Position           = UDim2.new(1, -6, 0.5, 0)
            Badge.Size               = UDim2.new(0, 28, 0, 14)
            Badge.Font               = Enum.Font.GothamBold; Badge.Text = "Beta"
            Badge.TextColor3         = P.INK_BETA; Badge.TextSize = 9
            Badge.TextXAlignment     = Enum.TextXAlignment.Right; Badge.ZIndex = 3
        end

        if cfg2.New then
            local Badge = Instance.new("TextLabel")
            Badge.Name               = "New"; Badge.Parent = Row
            Badge.BackgroundTransparency = 1; Badge.BorderSizePixel = 0
            Badge.AnchorPoint        = Vector2.new(1, 0.5)
            Badge.Position           = UDim2.new(1, -6, 0.5, 0)
            Badge.Size               = UDim2.new(0, 28, 0, 14)
            Badge.Font               = Enum.Font.GothamBold; Badge.Text = "New"
            Badge.TextColor3         = P.INK_NEW; Badge.TextSize = 9
            Badge.TextXAlignment     = Enum.TextXAlignment.Right; Badge.ZIndex = 3
        end

        local SubHolder = Instance.new("Frame")
        SubHolder.Name                   = "SubHolder"
        SubHolder.Parent                 = EntryHolder
        SubHolder.BackgroundColor3       = P.BASE3
        SubHolder.BackgroundTransparency = 0.04
        SubHolder.BorderSizePixel        = 0
        SubHolder.Size                   = UDim2.new(0, ROW_W, 0, 0)
        SubHolder.Visible                = false
        mkCorner(SubHolder, R_SM)
        mkBorder(SubHolder, P.EDGE, 1, 0.4)

        local SubFlow = Instance.new("UIListLayout")
        SubFlow.Parent             = SubHolder
        SubFlow.HorizontalAlignment = Enum.HorizontalAlignment.Center
        SubFlow.SortOrder          = Enum.SortOrder.LayoutOrder
        SubFlow.Padding            = UDim.new(0, 3)
        mkPad(SubHolder, 5, 5, 0, 0)

        
        local BindRow = Instance.new("TextButton")
        BindRow.Name                   = "BindRow"; BindRow.Parent = SubHolder
        BindRow.BackgroundColor3       = P.BASE2; BindRow.BackgroundTransparency = 0
        BindRow.BorderSizePixel        = 0; BindRow.LayoutOrder = 2
        BindRow.Size                   = UDim2.new(0, SUB_W, 0, 18)
        BindRow.Font                   = Enum.Font.GothamSemibold; BindRow.Text = ""
        BindRow.TextColor3             = P.INK_MID; BindRow.TextSize = 10
        BindRow.AutoButtonColor = false; BindRow.Visible = true
        mkCorner(BindRow, R_SM)
        local bindEdge = mkBorder(BindRow, P.EDGE, 1, 0.5)

        local BindLabel = Instance.new("TextLabel")
        BindLabel.Name               = "Name"; BindLabel.Parent = BindRow
        BindLabel.BackgroundTransparency = 1; BindLabel.BorderSizePixel = 0
        BindLabel.Position           = UDim2.new(0, 9, 0, 0); BindLabel.Size = UDim2.new(1, -11, 1, 0)
        BindLabel.Font               = Enum.Font.GothamSemibold; BindLabel.Text = "bind: none"
        BindLabel.TextColor3         = P.INK_LOW; BindLabel.TextSize = 10
        BindLabel.TextXAlignment     = Enum.TextXAlignment.Left

        kit:track(BindRow.MouseEnter:Connect(function()
            bindEdge.Transparency = 0; BindRow.BackgroundColor3 = P.BASE_HOV
        end))
        kit:track(BindRow.MouseLeave:Connect(function()
            bindEdge.Transparency = 0.5; BindRow.BackgroundColor3 = P.BASE2
        end))
        kit:track(BindRow.MouseButton1Click:Connect(function()
            if Spectrum.IsRecording then return end
            entry.Recording = not entry.Recording
            BindRow.Visible = true
            if entry.Recording then
                Spectrum.IsRecording = true
                BindLabel.Text       = "press a key…"
                BindLabel.TextColor3 = P.HUE
            end
        end))

        local OptionHolder = Instance.new("Frame")
        OptionHolder.Name                   = "OptionHolder"
        OptionHolder.Parent                 = SubHolder
        OptionHolder.BackgroundTransparency = 1
        OptionHolder.BorderSizePixel        = 0
        OptionHolder.LayoutOrder            = 1
        OptionHolder.Size                   = UDim2.new(0, ROW_W, 0, 0)

        local OptionFlow = Instance.new("UIListLayout")
        OptionFlow.Parent             = OptionHolder
        OptionFlow.HorizontalAlignment = Enum.HorizontalAlignment.Center
        OptionFlow.SortOrder          = Enum.SortOrder.LayoutOrder
        OptionFlow.Padding            = UDim.new(0, 3)

        function entry.SetBind(key)
            entry.Recording    = false
            Spectrum.IsRecording = false
            entry.Bind         = key or nil
            BindLabel.Text     = "bind: " .. (entry.Bind and entry.Bind:lower() or "none")
            BindLabel.TextColor3 = entry.Bind and P.INK_HI or P.INK_LOW
            BindRow.Visible    = true
        end
        local bk = cfg2.Bind or cfg2.DefaultBind
        if bk then entry.SetBind(bk) end

        function entry.Update()
            local s2 = SubFlow.AbsoluteContentSize
            SubHolder.Size    = UDim2.new(0, ROW_W, 0, (s2.Y + 14 * Scaler.Scale) / Scaler.Scale)
            local s3 = OptionFlow.AbsoluteContentSize
            OptionHolder.Size = UDim2.new(0, ROW_W, 0, s3.Y / Scaler.Scale)
        end
        kit:track(OptionFlow:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(entry.Update))
        kit:track(SubFlow:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(entry.Update))

        kit:track(PaletteSync:Bind(function()
            if entry.Enabled then
                RowArrow.ImageColor3 = P.HUE:Lerp(Color3.new(1, 1, 1), 0.3)
            end
        end))

        kit:track(Row.MouseEnter:Connect(function()
            if not entry.Enabled then Row.BackgroundColor3 = P.BASE_HOV end
        end))
        kit:track(Row.MouseLeave:Connect(function()
            if not entry.Enabled then Row.BackgroundColor3 = P.BASE2 end
        end))

        function entry.Toggle(fromKey)
            if entry.Enabled then
                entry.Enabled         = false
                Row.BackgroundColor3  = P.BASE2
                RowLabel.TextColor3   = P.INK_MID
                RowArrow.ImageColor3  = P.INK_LOW
            else
                entry.Enabled         = true
                Row.BackgroundColor3  = P.BASE_LIT
                RowLabel.TextColor3   = P.INK_HI
                RowArrow.ImageColor3  = P.HUE:Lerp(Color3.new(1, 1, 1), 0.3)
            end
            local extra = type(cfg2.ExtraText) == "function" and cfg2.ExtraText() or cfg2.ExtraText
            ModuleSync:Emit(cfg2.Name, extra, entry.Enabled, fromKey, panelId)
            if cfg2.Function then task.spawn(cfg2.Function, entry.Enabled, fromKey) end
            Spectrum.toast(
                string.upper(string.sub(cfg2.Name, 1, 1)) .. string.sub(cfg2.Name, 2),
                entry.Enabled, 2)
        end
        entry.Function = cfg2.Function

        function entry.Expand()
            if entry.Expanded then
                entry.Expanded       = false
                SubHolder.Visible    = false
                RowArrow.Rotation    = 180
            else
                entry.Expanded       = true
                SubHolder.Visible    = true
                RowArrow.Rotation    = 0
            end
            panel.Update()
        end

        kit:track(Row.MouseButton1Click:Connect(entry.Toggle))
        kit:track(Row.MouseButton2Click:Connect(entry.Expand))
        
        function entry.CreateToggle(cfg3)
            local sw = { Enabled = false }

            local SwitchRow = Instance.new("TextButton")
            SwitchRow.Name                   = "Switch"; SwitchRow.Parent = OptionHolder
            SwitchRow.BackgroundColor3       = P.BASE3; SwitchRow.BackgroundTransparency = 0
            SwitchRow.BorderSizePixel        = 0
            SwitchRow.Size                   = UDim2.new(0, SUB_W, 0, 18)
            SwitchRow.Text                   = ""; SwitchRow.AutoButtonColor = false
            sw.Instance                      = SwitchRow
            mkCorner(SwitchRow, R_SM)

            local SwitchLabel = Instance.new("TextLabel")
            SwitchLabel.Name               = "Name"; SwitchLabel.Parent = SwitchRow
            SwitchLabel.BackgroundTransparency = 1; SwitchLabel.BorderSizePixel = 0
            SwitchLabel.Position           = UDim2.new(0, 9, 0, 0); SwitchLabel.Size = UDim2.new(1, -38, 1, 0)
            SwitchLabel.Font               = Enum.Font.GothamSemibold; SwitchLabel.Text = cfg3.Name
            SwitchLabel.TextColor3         = P.INK_MID; SwitchLabel.TextSize = 10
            SwitchLabel.TextScaled         = false; SwitchLabel.TextTruncate = Enum.TextTruncate.AtEnd
            SwitchLabel.TextXAlignment     = Enum.TextXAlignment.Left

            local Track = Instance.new("TextButton")
            Track.Name               = "Track"; Track.Parent = SwitchRow
            Track.AnchorPoint        = Vector2.new(0, 0.5)
            Track.BackgroundColor3   = P.BASE1; Track.BackgroundTransparency = 0
            Track.BorderSizePixel    = 0
            Track.Position           = UDim2.new(1, -32, 0.5, 0)
            Track.Size               = UDim2.new(0, 22, 0, 11)
            Track.Text               = ""; Track.AutoButtonColor = false
            mkCorner(Track, UDim.new(1, 0))
            local trackEdge = mkBorder(Track, P.EDGE, 1)

            local Knob = Instance.new("TextButton")
            Knob.Name             = "Knob"; Knob.Parent = Track
            Knob.AnchorPoint      = Vector2.new(0, 0.5)
            Knob.BackgroundColor3 = P.HUE; Knob.BorderSizePixel = 0
            Knob.Position         = UDim2.fromScale(0.1, 0.5)
            Knob.Size             = UDim2.new(0, 8.7, 0, 8.7)
            Knob.Text             = ""; Knob.AutoButtonColor = false
            mkCorner(Knob, UDim.new(1, 0))

            kit:track(PaletteSync:Bind(function()
                Knob.BackgroundColor3 = P.HUE
                if sw.Enabled then
                    Track.BackgroundColor3 = P.HUE:Lerp(P.BASE1, 0.55)
                    trackEdge.Color        = P.HUE
                end
            end))

            function sw.Toggle(skipAnim)
                if sw.Enabled then
                    sw.Enabled             = false
                    Track.BackgroundColor3 = P.BASE1
                    trackEdge.Color        = P.EDGE
                    SwitchLabel.TextColor3 = P.INK_MID
                    if not skipAnim then
                        Knob:TweenPosition(UDim2.fromScale(0.1, 0.5), "Out", "Quad", 0.15, true)
                    else
                        Knob.Position = UDim2.fromScale(0.1, 0.5)
                    end
                else
                    sw.Enabled                 = true
                    Track.BackgroundColor3     = P.HUE:Lerp(P.BASE1, 0.55)
                    trackEdge.Color            = P.HUE
                    Knob.BackgroundColor3      = P.HUE
                    SwitchLabel.TextColor3     = P.INK_HI
                    if not skipAnim then
                        Knob:TweenPosition(UDim2.fromScale(0.55, 0.5), "Out", "Quad", 0.15, true)
                    else
                        Knob.Position = UDim2.fromScale(0.55, 0.5)
                    end
                end
                if cfg3.Function then task.spawn(cfg3.Function, sw.Enabled) end
            end

            kit:track(Knob.MouseButton1Click:Connect(sw.Toggle))
            kit:track(Track.MouseButton1Click:Connect(sw.Toggle))
            kit:track(SwitchRow.MouseButton1Click:Connect(sw.Toggle))
            sw.Function = cfg3.Function

            kit:track(SwitchRow.MouseEnter:Connect(function()
                SwitchRow.BackgroundColor3 = P.BASE_HOV
                trackEdge.Color = sw.Enabled and P.HUE or P.EDGE_HI
            end))
            kit:track(SwitchRow.MouseLeave:Connect(function()
                SwitchRow.BackgroundColor3 = P.BASE3
                trackEdge.Color = sw.Enabled and P.HUE or P.EDGE
            end))

            if cfg3.Default and sw.Enabled ~= cfg3.Default then sw.Toggle(true) end

            kit:register(cfg3.Name .. "Toggle_" .. entryId,
                { Name = cfg3.Name, Instance = SwitchRow, Type = "Toggle",
                  OptionsButton = entryId, API = sw, args = cfg3 })
            return sw
        end

        function entry.CreateSlider(cfg3)
            local range     = {}
            local rMin, rMax = cfg3.Min, cfg3.Max
            local rDef       = cfg3.Default or rMin
            local rnd        = cfg3.Round or 1
            local rMult      = 10 ^ rnd

            local function fmt(v)
                return math.floor(v) == v and (tostring(v) .. ".0") or tostring(v)
            end

            local RangeFrame = Instance.new("Frame")
            RangeFrame.Name                   = "Range"; RangeFrame.Parent = OptionHolder
            RangeFrame.BackgroundColor3       = P.BASE3; RangeFrame.BackgroundTransparency = 0
            RangeFrame.BorderSizePixel        = 0; RangeFrame.Size = UDim2.new(0, SUB_W, 0, 32)
            range.Instance                    = RangeFrame
            mkCorner(RangeFrame, R_SM)

            local RangeLabel = Instance.new("TextLabel")
            RangeLabel.Name               = "Name"; RangeLabel.Parent = RangeFrame
            RangeLabel.BackgroundTransparency = 1; RangeLabel.BorderSizePixel = 0
            RangeLabel.Position           = UDim2.new(0, 9, 0, 4); RangeLabel.Size = UDim2.new(1, -52, 0, 14)
            RangeLabel.Font               = Enum.Font.GothamSemibold; RangeLabel.Text = cfg3.Name
            RangeLabel.TextColor3         = P.INK_MID; RangeLabel.TextSize = 10
            RangeLabel.TextScaled         = false; RangeLabel.TextTruncate = Enum.TextTruncate.AtEnd
            RangeLabel.TextXAlignment     = Enum.TextXAlignment.Left

            local ValBox = Instance.new("TextBox")
            ValBox.Name                  = "Val"; ValBox.Parent = RangeFrame
            ValBox.AnchorPoint           = Vector2.new(1, 0)
            ValBox.BackgroundTransparency = 1; ValBox.Position = UDim2.new(1, -9, 0, 4)
            ValBox.Size                  = UDim2.new(0, 38, 0, 14)
            ValBox.Font                  = Enum.Font.GothamBold; ValBox.PlaceholderText = "val"
            ValBox.Text                  = fmt(rDef); ValBox.TextColor3 = P.HUE
            ValBox.TextSize              = 10; ValBox.TextXAlignment = Enum.TextXAlignment.Right
            ValBox.BackgroundColor3      = P.BASE3

            local ValLine = Instance.new("Frame")
            ValLine.Name             = "ValLine"; ValLine.Parent = ValBox
            ValLine.AnchorPoint      = Vector2.new(1, 0); ValLine.BackgroundColor3 = P.HUE
            ValLine.BorderSizePixel  = 0; ValLine.Position = UDim2.new(1, 0, 1, 1)
            ValLine.Size             = UDim2.new(0.9, 0, 0, 1); ValLine.Visible = false

            local Track = Instance.new("Frame")
            Track.Name             = "Track"; Track.Parent = RangeFrame
            Track.AnchorPoint      = Vector2.new(0.5, 1)
            Track.BackgroundColor3 = P.BASE1; Track.BorderSizePixel = 0
            Track.Position         = UDim2.new(0.5, 0, 1, -7)
            Track.Size             = UDim2.new(1, -18, 0, 3)
            mkCorner(Track, UDim.new(1, 0))

            local Fill = Instance.new("Frame")
            Fill.Name             = "Fill"; Fill.Parent = Track
            Fill.AnchorPoint      = Vector2.new(0, 0.5)
            Fill.BackgroundColor3 = P.HUE; Fill.BorderSizePixel = 0
            Fill.Position         = UDim2.new(0, 0, 0.5, 0)
            Fill.Size             = UDim2.new(0, 50, 1, 0)
            mkCorner(Fill, UDim.new(1, 0))

            kit:track(PaletteSync:Bind(function() Fill.BackgroundColor3 = P.HUE end))
            kit:track(RangeFrame.MouseEnter:Connect(function() RangeFrame.BackgroundColor3 = P.BASE_HOV end))
            kit:track(RangeFrame.MouseLeave:Connect(function() RangeFrame.BackgroundColor3 = P.BASE3 end))
            kit:track(ValBox.MouseEnter:Connect(function() ValLine.Visible = true end))
            kit:track(ValBox.MouseLeave:Connect(function()
                if not ValBox:IsFocused() then ValLine.Visible = false end
            end))
            kit:track(ValBox.Focused:Connect(function() ValLine.Visible = true end))
            kit:track(ValBox.FocusLost:Connect(function()
                ValLine.Visible = false
                local n = tonumber(ValBox.Text)
                if n then range.Set(n, true)
                else ValBox.Text = fmt(range.Value) end
            end))

            local function drag(input)
                local sx = math.clamp(
                    (input.Position.X - Track.AbsolutePosition.X) / Track.AbsoluteSize.X, 0, 1)
                Fill.Size     = UDim2.new(sx, 0, 1, 0)
                local v = math.round(((rMax - rMin) * sx + rMin) * rMult) / rMult
                range.Value = v; ValBox.Text = fmt(v)
                if not cfg3.OnInputEnded and cfg3.Function then task.spawn(cfg3.Function, v) end
            end

            local sliding = false
            kit:track(RangeFrame.InputBegan:Connect(function(input)
                local ut = input.UserInputType
                if ut == Enum.UserInputType.MouseButton1 or ut == Enum.UserInputType.Touch then
                    sliding = true; drag(input)
                end
            end))
            kit:track(RangeFrame.InputEnded:Connect(function(input)
                local ut = input.UserInputType
                if ut == Enum.UserInputType.MouseButton1 or ut == Enum.UserInputType.Touch then
                    if cfg3.OnInputEnded and cfg3.Function then task.spawn(cfg3.Function, range.Value) end
                    sliding = false
                end
            end))
            kit:track(UIS.InputChanged:Connect(function(input)
                if sliding and input.UserInputType == Enum.UserInputType.MouseMovement then drag(input) end
            end))

            function range.Set(val, overMax)
                local clamped = not overMax
                    and math.floor(math.clamp(val, rMin, rMax) * rMult + 0.5) / rMult
                    or  math.clamp(val, cfg3.RealMin or -math.huge, cfg3.RealMax or math.huge)
                local sVal = math.floor(math.clamp(clamped, rMin, rMax) * rMult + 0.5) / rMult
                range.Value  = clamped
                Fill.Size    = UDim2.new((sVal - rMin) / (rMax - rMin), 0, 1, 0)
                ValBox.Text  = fmt(clamped)
                if cfg3.Function then task.spawn(cfg3.Function, clamped) end
            end
            range.Set(rDef)

            kit:register(cfg3.Name .. "Slider_" .. entryId,
                { Name = cfg3.Name, Instance = RangeFrame, Type = "Slider",
                  OptionsButton = entryId, API = range, args = cfg3 })
            return range
        end

        function entry.CreateTextbox(cfg3)
            local inp = {}

            local InputWrap = Instance.new("Frame")
            InputWrap.Name                   = "Input"; InputWrap.Parent = OptionHolder
            InputWrap.BackgroundTransparency = 1; InputWrap.BorderSizePixel = 0
            InputWrap.Size                   = UDim2.new(0, SUB_W, 0, 22)
            inp.Instance                     = InputWrap

            local InputBack = Instance.new("Frame")
            InputBack.Name                   = "InputBack"; InputBack.Parent = InputWrap
            InputBack.AnchorPoint            = Vector2.new(0.5, 0.5)
            InputBack.BackgroundColor3       = P.BASE2; InputBack.BackgroundTransparency = 0
            InputBack.BorderSizePixel        = 0
            InputBack.Position               = UDim2.new(0.5, 0, 0.5, 0)
            InputBack.Size                   = UDim2.new(0, SUB_W - 8, 0, 20)
            mkCorner(InputBack, R_SM)
            local inputEdge = mkBorder(InputBack, P.EDGE, 1, 0.4)

            local InputField = Instance.new("TextBox")
            InputField.Name                  = "Field"; InputField.Parent = InputBack
            InputField.AnchorPoint           = Vector2.new(0.5, 0.5)
            InputField.BackgroundTransparency = 1; InputField.BorderSizePixel = 0
            InputField.Position              = UDim2.new(0.5, 0, 0.5, 0)
            InputField.Size                  = UDim2.new(1, -14, 1, 0)
            InputField.ClearTextOnFocus      = false
            InputField.Font                  = Enum.Font.GothamSemibold
            InputField.PlaceholderColor3     = P.INK_LOW; InputField.PlaceholderText = cfg3.Name
            InputField.Text                  = cfg3.Default or ""; InputField.TextColor3 = P.INK_HI
            InputField.TextSize              = 10; InputField.TextXAlignment = Enum.TextXAlignment.Left

            kit:track(InputBack.MouseEnter:Connect(function()
                inputEdge.Color = P.EDGE_HI; inputEdge.Transparency = 0
            end))
            kit:track(InputBack.MouseLeave:Connect(function()
                inputEdge.Color = P.EDGE; inputEdge.Transparency = 0.4
            end))

            function inp.Set(val)
                val       = val or cfg3.Default or ""
                inp.Value = val; InputField.Text = val
                if cfg3.Function then task.spawn(cfg3.Function, val) end
            end
            kit:track(InputField.FocusLost:Connect(function()
                local t = InputField.Text; if t then inp.Set(t) end
            end))

            kit:register(cfg3.Name .. "Textbox_" .. entryId,
                { Name = cfg3.Name, Instance = InputWrap, Type = "Textbox",
                  OptionsButton = entryId, API = inp, args = cfg3 })
            return inp
        end
        entry.CreateTextBox = entry.CreateTextbox
        
        function entry.CreateDropdown(cfg3)
            local sel = { Values = {}, Expanded = false }

            local SelWrap = Instance.new("Frame")
            SelWrap.Name                   = "Select"; SelWrap.Parent = OptionHolder
            SelWrap.BackgroundTransparency = 1; SelWrap.BorderSizePixel = 0
            SelWrap.Size                   = UDim2.new(0, SUB_W, 0, 22)
            sel.Instance                   = SelWrap

            local SelBack = Instance.new("Frame")
            SelBack.Name                   = "SelBack"; SelBack.Parent = SelWrap
            SelBack.AnchorPoint            = Vector2.new(0.5, 0)
            SelBack.BackgroundColor3       = P.BASE2; SelBack.BackgroundTransparency = 0
            SelBack.BorderSizePixel        = 0
            SelBack.Position               = UDim2.new(0.5, 0, 0, 4)
            SelBack.Size                   = UDim2.new(0, SUB_W - 8, 0, 20)
            mkCorner(SelBack, R_SM)
            local selEdge = mkBorder(SelBack, P.EDGE, 1, 0.4)

            local SelLabel = Instance.new("TextLabel")
            SelLabel.Name               = "Name"; SelLabel.Parent = SelBack
            SelLabel.BackgroundTransparency = 1; SelLabel.BorderSizePixel = 0
            SelLabel.Position           = UDim2.new(0, 9, 0, 0); SelLabel.Size = UDim2.new(1, -26, 1, 0)
            SelLabel.Font               = Enum.Font.GothamSemibold; SelLabel.Text = cfg3.Name
            SelLabel.TextColor3         = P.INK_MID; SelLabel.TextSize = 10
            SelLabel.TextXAlignment     = Enum.TextXAlignment.Left
            SelLabel.TextTruncate       = Enum.TextTruncate.AtEnd

            local SelChevron = Instance.new("ImageButton")
            SelChevron.Name               = "Chevron"; SelChevron.Parent = SelBack
            SelChevron.AnchorPoint        = Vector2.new(0, 0.5)
            SelChevron.BackgroundTransparency = 1; SelChevron.BorderSizePixel = 0
            SelChevron.Position           = UDim2.new(1, -18, 0.5, 0); SelChevron.Rotation = 0
            SelChevron.Size               = UDim2.new(0, 14, 0, 14); SelChevron.ZIndex = 2
            SelChevron.Image              = "http://www.roblox.com/asset/?id=6031094679"
            SelChevron.ImageColor3        = P.INK_LOW; SelChevron.ScaleType = Enum.ScaleType.Fit

            local SelList = Instance.new("Frame")
            SelList.Name                   = "SelList"; SelList.Parent = SelWrap
            SelList.AnchorPoint            = Vector2.new(0.5, 0)
            SelList.BackgroundColor3       = P.BASE1; SelList.BackgroundTransparency = 0
            SelList.BorderSizePixel        = 0
            SelList.Position               = UDim2.new(0.5, 0, 0, 28)
            SelList.Size                   = UDim2.new(0, SUB_W - 8, 0, 0)
            SelList.Visible                = false
            mkCorner(SelList, R_SM); mkBorder(SelList, P.EDGE, 1, 0.4)
            mkPad(SelList, 2, 2, 0, 0)

            local SelItemFlow = Instance.new("UIListLayout")
            SelItemFlow.Parent             = SelList
            SelItemFlow.HorizontalAlignment = Enum.HorizontalAlignment.Center
            SelItemFlow.SortOrder          = Enum.SortOrder.LayoutOrder

            kit:track(SelBack.MouseEnter:Connect(function()
                selEdge.Transparency = 0; selEdge.Color = P.EDGE_HI
                SelBack.BackgroundColor3 = P.BASE_HOV
            end))
            kit:track(SelBack.MouseLeave:Connect(function()
                selEdge.Transparency = 0.4; selEdge.Color = P.EDGE
                SelBack.BackgroundColor3 = P.BASE2
            end))

            function sel.Update()
                local sz = SelItemFlow.AbsoluteContentSize.Y
                if SelList.Visible then
                    SelWrap.Size = UDim2.new(0, SUB_W, 0, (28 * Scaler.Scale + sz + 6) / Scaler.Scale)
                    SelList.Size = UDim2.new(0, SUB_W - 8, 0, sz + 4)
                else
                    SelWrap.Size = UDim2.new(0, SUB_W, 0, 22)
                end
            end
            kit:track(SelItemFlow:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(sel.Update))

            function sel.SetValue(val)
                for _, v in next, sel.Values do
                    local match = v.Value == val
                    v.SelectedInstance.Visible = match
                    if match then
                        sel.Value     = tostring(val)
                        SelLabel.Text = cfg3.Name .. " · " .. tostring(val)
                        SelLabel.TextColor3 = P.INK_HI
                        if cfg3.Function then task.spawn(cfg3.Function, val) end
                    end
                end
            end

            local function newItem(val)
                local vi = { Value = val }
                local Btn = Instance.new("TextButton"); Btn.Parent = SelList
                Btn.BackgroundColor3 = P.BASE1; Btn.BackgroundTransparency = 0
                Btn.BorderSizePixel  = 0; Btn.Size = UDim2.new(0, SUB_W - 14, 0, 20)
                Btn.Text             = ""; Btn.AutoButtonColor = false
                mkCorner(Btn, R_SM)
                Btn.MouseButton1Click:Connect(function() sel.SetValue(val) end)
                kit:track(Btn.MouseEnter:Connect(function() Btn.BackgroundColor3 = P.BASE_HOV end))
                kit:track(Btn.MouseLeave:Connect(function() Btn.BackgroundColor3 = P.BASE1 end))
                local Lbl = Instance.new("TextLabel"); Lbl.Parent = Btn
                Lbl.BackgroundTransparency = 1; Lbl.BorderSizePixel = 0
                Lbl.Position = UDim2.new(0, 12, 0, 0); Lbl.Size = UDim2.new(1, -18, 1, 0)
                Lbl.Font = Enum.Font.GothamSemibold; Lbl.Text = tostring(val)
                Lbl.TextColor3 = P.INK_MID; Lbl.TextSize = 10
                Lbl.TextXAlignment = Enum.TextXAlignment.Left
                local Dot = Instance.new("Frame"); Dot.Parent = Btn
                Dot.AnchorPoint = Vector2.new(0, 0.5); Dot.BackgroundColor3 = P.HUE
                Dot.Visible     = false; Dot.BorderSizePixel = 0
                Dot.Position    = UDim2.new(0, 3, 0.5, 0); Dot.Size = UDim2.new(0, 2, 0.5, 0)
                mkCorner(Dot, UDim.new(1, 0))
                kit:track(PaletteSync:Bind(function() Dot.BackgroundColor3 = P.HUE end))
                vi.SelectedInstance = Dot; vi.Instance = Btn; return vi
            end

            function sel.Expand()
                if sel.Expanded then
                    sel.Expanded      = false; SelList.Visible = false
                    SelChevron.Rotation = 0;    SelChevron.ImageColor3 = P.INK_LOW
                else
                    SelChevron.Rotation = 180;  SelChevron.ImageColor3 = P.HUE
                    sel.Expanded      = true;   SelList.Visible = true
                end
                sel.Update()
            end
            kit:track(SelChevron.MouseButton1Click:Connect(sel.Expand))

            for _, v in next, cfg3.List do
                sel.Values[#sel.Values + 1] = newItem(v)
            end
            if cfg3.Default then sel.SetValue(cfg3.Default) end

            function sel.SetList(list)
                for i, v in next, sel.Values do v.Instance:Destroy(); sel.Values[i] = nil end
                sel.Values = {}
                for _, v in next, list do sel.Values[#sel.Values + 1] = newItem(v) end
            end

            kit:register(cfg3.Name .. "Dropdown_" .. entryId,
                { Name = cfg3.Name, Instance = SelWrap, Type = "Dropdown",
                  OptionsButton = entryId, API = sel, args = cfg3 })
            return sel
        end
        
        function entry.CreateMultiDropdown(cfg3)
            local ms = { Values = {}, Expanded = false }

            local MSWrap = Instance.new("Frame")
            MSWrap.Name                   = "MultiSelect"; MSWrap.Parent = OptionHolder
            MSWrap.BackgroundTransparency = 1; MSWrap.BorderSizePixel = 0
            MSWrap.Size                   = UDim2.new(0, SUB_W, 0, 22)
            ms.Instance                   = MSWrap

            local MSBack = Instance.new("Frame")
            MSBack.Name                   = "MSBack"; MSBack.Parent = MSWrap
            MSBack.AnchorPoint            = Vector2.new(0.5, 0)
            MSBack.BackgroundColor3       = P.BASE2; MSBack.BackgroundTransparency = 0
            MSBack.BorderSizePixel        = 0; MSBack.Position = UDim2.new(0.5, 0, 0, 4)
            MSBack.Size                   = UDim2.new(0, SUB_W - 8, 0, 20)
            mkCorner(MSBack, R_SM)
            local msEdge = mkBorder(MSBack, P.EDGE, 1, 0.4)

            local MSLabel = Instance.new("TextLabel")
            MSLabel.Name               = "Name"; MSLabel.Parent = MSBack
            MSLabel.BackgroundTransparency = 1; MSLabel.BorderSizePixel = 0
            MSLabel.Position           = UDim2.new(0, 9, 0, 0); MSLabel.Size = UDim2.new(1, -26, 1, 0)
            MSLabel.Font               = Enum.Font.GothamSemibold; MSLabel.Text = cfg3.Name
            MSLabel.TextColor3         = P.INK_MID; MSLabel.TextSize = 10
            MSLabel.TextXAlignment     = Enum.TextXAlignment.Left
            MSLabel.TextTruncate       = Enum.TextTruncate.AtEnd

            local MSChevron = Instance.new("ImageButton")
            MSChevron.Name               = "Chevron"; MSChevron.Parent = MSBack
            MSChevron.AnchorPoint        = Vector2.new(0, 0.5)
            MSChevron.BackgroundTransparency = 1; MSChevron.BorderSizePixel = 0
            MSChevron.Position           = UDim2.new(1, -18, 0.5, 0); MSChevron.Size = UDim2.new(0, 14, 0, 14)
            MSChevron.ZIndex             = 2
            MSChevron.Image              = "http://www.roblox.com/asset/?id=6031094679"
            MSChevron.ImageColor3        = P.INK_LOW; MSChevron.ScaleType = Enum.ScaleType.Fit

            local MSList = Instance.new("Frame")
            MSList.Name                   = "MSList"; MSList.Parent = MSWrap
            MSList.AnchorPoint            = Vector2.new(0.5, 0)
            MSList.BackgroundColor3       = P.BASE1; MSList.BackgroundTransparency = 0
            MSList.BorderSizePixel        = 0; MSList.Position = UDim2.new(0.5, 0, 0, 28)
            MSList.Size                   = UDim2.new(0, SUB_W - 8, 0, 0); MSList.Visible = false
            mkCorner(MSList, R_SM); mkBorder(MSList, P.EDGE, 1, 0.4); mkPad(MSList, 2, 2, 0, 0)

            local MSItemFlow = Instance.new("UIListLayout")
            MSItemFlow.Parent             = MSList
            MSItemFlow.HorizontalAlignment = Enum.HorizontalAlignment.Center
            MSItemFlow.SortOrder          = Enum.SortOrder.LayoutOrder

            kit:track(MSBack.MouseEnter:Connect(function()
                msEdge.Transparency = 0; msEdge.Color = P.EDGE_HI
                MSBack.BackgroundColor3 = P.BASE_HOV
            end))
            kit:track(MSBack.MouseLeave:Connect(function()
                msEdge.Transparency = 0.4; msEdge.Color = P.EDGE
                MSBack.BackgroundColor3 = P.BASE2
            end))

            function ms.Update()
                local sz = MSItemFlow.AbsoluteContentSize.Y
                if MSList.Visible then
                    MSWrap.Size = UDim2.new(0, SUB_W, 0, (28 * Scaler.Scale + sz + 6) / Scaler.Scale)
                    MSList.Size = UDim2.new(0, SUB_W - 8, 0, sz + 4)
                else
                    MSWrap.Size = UDim2.new(0, SUB_W, 0, 22)
                end
            end
            kit:track(MSItemFlow:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(ms.Update))

            function ms.ToggleValue(val)
                for _, v in next, ms.Values do
                    if v.Value == val then
                        v.Toggle()
                        local active, strs = {}, {}
                        for _, vv in next, ms.Values do
                            if vv.Enabled then active[#active+1] = vv.Value; strs[#strs+1] = tostring(vv.Value) end
                        end
                        MSLabel.Text       = cfg3.Name .. (#strs ~= 0 and (" · " .. table.concat(strs, ", ")) or "")
                        MSLabel.TextColor3 = #strs ~= 0 and P.INK_HI or P.INK_MID
                        if cfg3.Function then task.spawn(cfg3.Function, active) end
                        break
                    end
                end
            end

            local function newMSItem(val)
                local vi = { Enabled = false, Value = val }
                local Btn = Instance.new("TextButton"); Btn.Parent = MSList
                Btn.BackgroundColor3 = P.BASE1; Btn.BackgroundTransparency = 0
                Btn.BorderSizePixel  = 0; Btn.Size = UDim2.new(0, SUB_W - 14, 0, 20)
                Btn.Text             = ""; Btn.AutoButtonColor = false
                mkCorner(Btn, R_SM)
                kit:track(Btn.MouseEnter:Connect(function() Btn.BackgroundColor3 = P.BASE_HOV end))
                kit:track(Btn.MouseLeave:Connect(function() Btn.BackgroundColor3 = P.BASE1 end))
                local Lbl = Instance.new("TextLabel"); Lbl.Parent = Btn
                Lbl.BackgroundTransparency = 1; Lbl.BorderSizePixel = 0
                Lbl.Position = UDim2.new(0, 12, 0, 0); Lbl.Size = UDim2.new(1, -18, 1, 0)
                Lbl.Font = Enum.Font.GothamSemibold; Lbl.Text = tostring(val)
                Lbl.TextColor3 = P.INK_MID; Lbl.TextSize = 10
                Lbl.TextXAlignment = Enum.TextXAlignment.Left
                local Dot = Instance.new("Frame"); Dot.Parent = Btn
                Dot.AnchorPoint = Vector2.new(0, 0.5); Dot.BackgroundColor3 = P.HUE
                Dot.Visible     = false; Dot.BorderSizePixel = 0
                Dot.Position    = UDim2.new(0, 3, 0.5, 0); Dot.Size = UDim2.new(0, 2, 0.5, 0)
                mkCorner(Dot, UDim.new(1, 0))
                kit:track(PaletteSync:Bind(function() Dot.BackgroundColor3 = P.HUE end))
                function vi.Toggle()
                    vi.Enabled  = not vi.Enabled
                    Dot.Visible = vi.Enabled
                    Lbl.TextColor3 = vi.Enabled and P.INK_HI or P.INK_MID
                end
                Btn.MouseButton1Click:Connect(function() ms.ToggleValue(val) end)
                vi.SelectedInstance = Dot; vi.Instance = Btn; return vi
            end

            for _, v in next, cfg3.List do ms.Values[tostring(v)] = newMSItem(v) end
            for _, v in next, (cfg3.Default or {}) do ms.ToggleValue(v) end

            function ms.SetList(list)
                for i, v in next, ms.Values do v.Instance:Destroy(); ms.Values[i] = nil end
                ms.Values = {}
                for _, v in next, list do ms.Values[tostring(v)] = newMSItem(v) end
            end

            function ms.Expand()
                if ms.Expanded then
                    ms.Expanded = false; MSList.Visible = false
                    MSChevron.Rotation = 0; MSChevron.ImageColor3 = P.INK_LOW
                else
                    MSChevron.Rotation = 180; MSChevron.ImageColor3 = P.HUE
                    ms.Expanded = true; MSList.Visible = true
                end
                ms.Update()
            end
            ms.Update()
            kit:track(MSChevron.MouseButton1Click:Connect(ms.Expand))

            kit:register(cfg3.Name .. "MultiDropdown_" .. entryId,
                { Name = cfg3.Name, Instance = MSWrap, Type = "MultiDropdown",
                  OptionsButton = entryId, API = ms, args = cfg3 })
            return ms
        end

        function entry.CreateTextlist(cfg3)
            local tl = { Values = {} }

            local TLWrap = Instance.new("Frame")
            TLWrap.Name                   = "TagList"; TLWrap.Parent = OptionHolder
            TLWrap.BackgroundTransparency = 1; TLWrap.BorderSizePixel = 0
            TLWrap.Size                   = UDim2.new(0, SUB_W, 0, 30)
            tl.Instance                   = TLWrap

            local InputBar = Instance.new("Frame")
            InputBar.Name                   = "InputBar"; InputBar.Parent = TLWrap
            InputBar.AnchorPoint            = Vector2.new(0.5, 0)
            InputBar.BackgroundColor3       = P.BASE2; InputBar.BackgroundTransparency = 0
            InputBar.BorderSizePixel        = 0; InputBar.Position = UDim2.new(0.5, 0, 0, 4)
            InputBar.Size                   = UDim2.new(0, SUB_W - 8, 0, 20)
            mkCorner(InputBar, R_SM); local tlEdge = mkBorder(InputBar, P.EDGE, 1, 0.4)

            local InputField = Instance.new("TextBox"); InputField.Parent = InputBar
            InputField.AnchorPoint            = Vector2.new(0, 0.5)
            InputField.BackgroundTransparency = 1; InputField.BorderSizePixel = 0
            InputField.Position               = UDim2.new(0, 8, 0.5, 0); InputField.Size = UDim2.new(1, -28, 1, 0)
            InputField.ClearTextOnFocus       = false; InputField.Font = Enum.Font.GothamSemibold
            InputField.PlaceholderColor3      = P.INK_LOW; InputField.PlaceholderText = cfg3.Name
            InputField.Text                   = ""; InputField.TextColor3 = P.INK_HI
            InputField.TextSize               = 10; InputField.TextXAlignment = Enum.TextXAlignment.Left

            kit:track(InputBar.MouseEnter:Connect(function() tlEdge.Color = P.EDGE_HI; tlEdge.Transparency = 0 end))
            kit:track(InputBar.MouseLeave:Connect(function() tlEdge.Color = P.EDGE; tlEdge.Transparency = 0.4 end))

            local AddBtn = Instance.new("TextButton"); AddBtn.Parent = InputBar
            AddBtn.AnchorPoint            = Vector2.new(1, 0.5); AddBtn.BackgroundTransparency = 1
            AddBtn.BorderSizePixel        = 0; AddBtn.Position = UDim2.new(1, -5, 0.5, 0)
            AddBtn.Size                   = UDim2.new(0, 14, 0, 14); AddBtn.Font = Enum.Font.GothamBold
            AddBtn.Text                   = "+"; AddBtn.TextColor3 = P.INK_LOW; AddBtn.TextSize = 16; AddBtn.AutoButtonColor = false
            kit:track(AddBtn.MouseEnter:Connect(function() AddBtn.TextColor3 = P.HUE end))
            kit:track(AddBtn.MouseLeave:Connect(function() AddBtn.TextColor3 = P.INK_LOW end))

            local ItemList = Instance.new("Frame"); ItemList.Parent = TLWrap
            ItemList.AnchorPoint            = Vector2.new(0.5, 0); ItemList.BackgroundTransparency = 1
            ItemList.BorderSizePixel        = 0; ItemList.Position = UDim2.new(0.5, 0, 0, 28)
            ItemList.Size                   = UDim2.new(0, SUB_W - 8, 0, 0)
            local ItemFlow = Instance.new("UIListLayout"); ItemFlow.Parent = ItemList
            ItemFlow.HorizontalAlignment  = Enum.HorizontalAlignment.Center
            ItemFlow.SortOrder            = Enum.SortOrder.LayoutOrder; ItemFlow.Padding = UDim.new(0, 2)

            local function syncH()
                TLWrap.Size = UDim2.new(0, SUB_W, 0,
                    (ItemFlow.AbsoluteContentSize.Y + 36 * Scaler.Scale) / Scaler.Scale)
            end
            kit:track(ItemFlow:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(syncH))
            syncH()

            local function addItem(val)
                local vi = { value = val }
                local Chip = Instance.new("TextButton"); Chip.Parent = ItemList
                Chip.BackgroundColor3 = P.BASE2; Chip.BackgroundTransparency = 0; Chip.BorderSizePixel = 0
                Chip.Size             = UDim2.new(0, SUB_W - 8, 0, 20); Chip.Text = ""; Chip.AutoButtonColor = false
                mkCorner(Chip, R_SM)
                local ChipLbl = Instance.new("TextLabel"); ChipLbl.Parent = Chip; ChipLbl.BackgroundTransparency = 1
                ChipLbl.BorderSizePixel = 0; ChipLbl.Position = UDim2.new(0, 8, 0, 0); ChipLbl.Size = UDim2.new(1, -26, 1, 0)
                ChipLbl.Font = Enum.Font.GothamSemibold; ChipLbl.Text = val
                ChipLbl.TextColor3 = P.INK_MID; ChipLbl.TextSize = 10; ChipLbl.TextXAlignment = Enum.TextXAlignment.Left
                kit:track(Chip.MouseEnter:Connect(function() Chip.BackgroundColor3 = P.BASE_HOV end))
                kit:track(Chip.MouseLeave:Connect(function() Chip.BackgroundColor3 = P.BASE2 end))
                local RemBtn = Instance.new("TextButton"); RemBtn.Parent = Chip; RemBtn.AnchorPoint = Vector2.new(1, 0.5)
                RemBtn.BackgroundTransparency = 1; RemBtn.BorderSizePixel = 0
                RemBtn.Position = UDim2.new(1, -6, 0.5, 0); RemBtn.Size = UDim2.new(0, 12, 0, 12)
                RemBtn.Font = Enum.Font.GothamBold; RemBtn.Text = "×"; RemBtn.TextColor3 = P.INK_LOW
                RemBtn.TextSize = 14; RemBtn.AutoButtonColor = false; vi.Instance = Chip
                kit:track(RemBtn.MouseEnter:Connect(function() RemBtn.TextColor3 = P.STATE_OFF end))
                kit:track(RemBtn.MouseLeave:Connect(function() RemBtn.TextColor3 = P.INK_LOW end))
                function vi.Remove() tl.Values[vi.value] = nil; Chip:Destroy() end
                kit:track(RemBtn.MouseButton1Click:Connect(vi.Remove))
                kit:track(Chip.MouseButton1Click:Connect(vi.Remove))
                return vi
            end

            function tl.Add(val)
                if tl.Values[val] then return end
                addItem(val); tl.Values[val] = val
                if cfg3.Function then task.spawn(cfg3.Function, tl.Values) end
            end
            if cfg3.Default then for _, v in next, cfg3.Default do tl.Add(v) end end
            AddBtn.MouseButton1Click:Connect(function()
                local v = InputField.Text; if v == "" then return end
                tl.Add(v); InputField.Text = ""
            end)

            kit:register(cfg3.Name .. "Textlist_" .. entryId,
                { Name = cfg3.Name, Instance = TLWrap, Type = "Textlist",
                  OptionsButton = entryId, API = tl, args = cfg3 })
            return tl
        end

        kit:register(entryId,
            { Name = entryId, Instance = Row, Type = "OptionsButton",
              Window = panelId, API = entry, args = cfg2 })
        return entry
    end

    
    panel.module = panel.CreateOptionsButton

    kit:register(panelId,
        { Name = panelId, Instance = Body, Type = "Window", API = panel, args = cfg })
    return panel
end

Spectrum.CreateWindow = Spectrum.window

local OVERLAY_FILE = "config/overlay.cfg.json"
local _Http        = game:GetService("HttpService")

local function _readOverlayCfg()
    local ok, d = pcall(function() return _Http:JSONDecode(readfile(OVERLAY_FILE)) end)
    return (ok and type(d) == "table") and d or {}
end
local function _writeOverlayCfg(t)
    pcall(function()
        if not isfolder("config") then makefolder("config") end
        writefile(OVERLAY_FILE, _Http:JSONEncode(t))
    end)
end

function Spectrum.CreateHudConfig(cfg)
    local ovl       = {}
    local persisted = _readOverlayCfg()
    local stateCache = {}

    local function persist(key, val)
        stateCache[key] = val; _writeOverlayCfg(stateCache)
    end

    local OvlFrame = Instance.new("Frame")
    OvlFrame.Name                   = "OverlayEditor"; OvlFrame.Parent = Screen
    OvlFrame.BackgroundColor3       = P.BASE0; OvlFrame.BackgroundTransparency = 0
    OvlFrame.BorderSizePixel        = 0; OvlFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    OvlFrame.Position               = UDim2.new(0.5, 0, 0.5, 0); OvlFrame.Size = UDim2.new(0, 540, 0, 460)
    OvlFrame.Visible                = false; OvlFrame.ZIndex = 100
    mkCorner(OvlFrame, R_MD); mkBorder(OvlFrame, P.EDGE, 1)
    ovl.Instance = OvlFrame

    local OvlHeader = Instance.new("Frame")
    OvlHeader.Name             = "OvlHeader"; OvlHeader.Parent = OvlFrame
    OvlHeader.BackgroundColor3 = P.BASE2; OvlHeader.BorderSizePixel = 0
    OvlHeader.Size             = UDim2.new(1, 0, 0, HDR_H)
    mkCorner(OvlHeader, R_MD); mkBorder(OvlHeader, P.EDGE, 1)
    local OvlHeaderFix = Instance.new("Frame"); OvlHeaderFix.Parent = OvlHeader
    OvlHeaderFix.BackgroundColor3 = P.BASE2; OvlHeaderFix.BorderSizePixel = 0
    OvlHeaderFix.Position = UDim2.new(0, 0, 0.5, 0); OvlHeaderFix.Size = UDim2.new(1, 0, 0.5, 0)

    local OvlTitle = Instance.new("TextLabel"); OvlTitle.Parent = OvlHeader
    OvlTitle.BackgroundTransparency = 1; OvlTitle.BorderSizePixel = 0
    OvlTitle.Position = UDim2.new(0, 14, 0, 0); OvlTitle.Size = UDim2.new(1, -50, 1, 0)
    OvlTitle.Font = Enum.Font.GothamBold; OvlTitle.Text = "Overlay Editor"
    OvlTitle.TextColor3 = P.INK_HI; OvlTitle.TextSize = 10
    OvlTitle.TextXAlignment = Enum.TextXAlignment.Left; OvlTitle.ZIndex = 2

    local OvlClose = Instance.new("TextButton"); OvlClose.Parent = OvlHeader
    OvlClose.AnchorPoint = Vector2.new(1, 0.5); OvlClose.BackgroundTransparency = 1
    OvlClose.BorderSizePixel = 0; OvlClose.Position = UDim2.new(1, -8, 0.5, 0)
    OvlClose.Size = UDim2.new(0, 14, 0, 14); OvlClose.Font = Enum.Font.GothamBold
    OvlClose.Text = "×"; OvlClose.TextColor3 = P.INK_LOW; OvlClose.TextSize = 14
    OvlClose.AutoButtonColor = false; OvlClose.ZIndex = 3
    OvlClose.MouseEnter:Connect(function() OvlClose.TextColor3 = P.STATE_OFF end)
    OvlClose.MouseLeave:Connect(function() OvlClose.TextColor3 = P.INK_LOW end)
    OvlClose.MouseButton1Click:Connect(function() OvlFrame.Visible = false end)
    kit:drag(OvlFrame, OvlHeader)

    
    local PresetPane = Instance.new("Frame"); PresetPane.Parent = OvlFrame
    PresetPane.BackgroundColor3 = P.BASE1; PresetPane.BorderSizePixel = 0
    PresetPane.Position = UDim2.new(0, 0, 0, HDR_H); PresetPane.Size = UDim2.new(0, 200, 1, -HDR_H)
    mkBorder(PresetPane, P.EDGE, 1, 0.3)

    local PresetTitle = Instance.new("TextLabel"); PresetTitle.Parent = PresetPane
    PresetTitle.BackgroundColor3 = P.BASE2; PresetTitle.BorderSizePixel = 0
    PresetTitle.Size = UDim2.new(1, 0, 0, 20)
    PresetTitle.Font = Enum.Font.GothamBold; PresetTitle.Text = "PRESETS"
    PresetTitle.TextColor3 = P.INK_LOW; PresetTitle.TextSize = 9
    PresetTitle.TextXAlignment = Enum.TextXAlignment.Center
    mkBorder(PresetTitle, P.EDGE, 1, 0.5)

    local PresetScroll = Instance.new("ScrollingFrame"); PresetScroll.Parent = PresetPane
    PresetScroll.BackgroundTransparency = 1; PresetScroll.BorderSizePixel = 0
    PresetScroll.Position = UDim2.new(0, 0, 0, 20); PresetScroll.Size = UDim2.new(1, 0, 0, 150)
    PresetScroll.CanvasSize = UDim2.new(0, 0, 0, 0); PresetScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    PresetScroll.ScrollBarThickness = 2; PresetScroll.ScrollBarImageColor3 = P.EDGE_HI
    local PresetFlow = Instance.new("UIListLayout"); PresetFlow.Parent = PresetScroll
    PresetFlow.SortOrder = Enum.SortOrder.LayoutOrder; PresetFlow.Padding = UDim.new(0, 1)
    mkPad(PresetScroll, 3, 3, 0, 0)

    local activePreset, activeRow, presetRows = nil, nil, {}

    local function highlightRow(name, rowFrame)
        if activeRow then activeRow.BackgroundColor3 = P.BASE2 end
        activePreset = name; activeRow = rowFrame
        rowFrame.BackgroundColor3 = P.BASE_LIT
    end

    local function rebuildPresetList(dir)
        for _, r in ipairs(presetRows) do r:Destroy() end
        presetRows = {}
        local d = dir or ("Phantom/configs/" .. tostring(game.PlaceId) .. "/")
        if not isfolder(d) then makefolder(d) end
        local ok, files = pcall(listfiles, d)
        if not ok then return end
        for _, f in ipairs(files) do
            local fname = string.match(f, "([^/\\]+)$") or f
            if fname:match("%.json$") then
                local pname = fname:gsub("%.json$", "")
                local row = Instance.new("TextButton"); row.Parent = PresetScroll
                row.BackgroundColor3 = P.BASE2; row.BackgroundTransparency = 0
                row.BorderSizePixel  = 0; row.Size = UDim2.new(1, -6, 0, 22)
                row.Text             = ""; row.AutoButtonColor = false; mkCorner(row, R_SM)
                local lbl = Instance.new("TextLabel"); lbl.Parent = row
                lbl.BackgroundTransparency = 1; lbl.BorderSizePixel = 0
                lbl.Position = UDim2.new(0, 8, 0, 0); lbl.Size = UDim2.new(1, -10, 1, 0)
                lbl.Font = Enum.Font.GothamSemibold; lbl.Text = pname
                lbl.TextColor3 = P.INK_MID; lbl.TextSize = 10
                lbl.TextTruncate = Enum.TextTruncate.AtEnd
                lbl.TextXAlignment = Enum.TextXAlignment.Left
                row.MouseButton1Click:Connect(function()
                    highlightRow(pname, row); lbl.TextColor3 = P.INK_HI
                end)
                row.MouseEnter:Connect(function()
                    if activePreset ~= pname then row.BackgroundColor3 = P.BASE_HOV end
                end)
                row.MouseLeave:Connect(function()
                    if activePreset ~= pname then row.BackgroundColor3 = P.BASE2 end
                end)
                table.insert(presetRows, row)
            end
        end
    end

    local Sep1 = Instance.new("Frame"); Sep1.Parent = PresetPane
    Sep1.BackgroundColor3 = P.EDGE; Sep1.BorderSizePixel = 0
    Sep1.Position = UDim2.new(0, 6, 0, 172); Sep1.Size = UDim2.new(1, -12, 0, 1)

    local NameBox = Instance.new("Frame"); NameBox.Parent = PresetPane
    NameBox.BackgroundColor3 = P.BASE2; NameBox.BorderSizePixel = 0
    NameBox.Position = UDim2.new(0, 6, 0, 176); NameBox.Size = UDim2.new(1, -12, 0, 22)
    mkCorner(NameBox, R_SM); mkBorder(NameBox, P.EDGE, 1, 0.4)
    local NameField = Instance.new("TextBox"); NameField.Parent = NameBox
    NameField.BackgroundTransparency = 1; NameField.BorderSizePixel = 0
    NameField.Position = UDim2.new(0, 6, 0, 0); NameField.Size = UDim2.new(1, -12, 1, 0)
    NameField.Font = Enum.Font.GothamSemibold; NameField.PlaceholderText = "preset name…"
    NameField.Text = ""; NameField.TextColor3 = P.INK_HI; NameField.TextSize = 10
    NameField.PlaceholderColor3 = P.INK_LOW; NameField.ClearTextOnFocus = false

    local StatusLbl = Instance.new("TextLabel"); StatusLbl.Parent = PresetPane
    StatusLbl.BackgroundTransparency = 1; StatusLbl.BorderSizePixel = 0
    StatusLbl.Position = UDim2.new(0, 6, 0, 256); StatusLbl.Size = UDim2.new(1, -12, 0, 12)
    StatusLbl.Font = Enum.Font.GothamSemibold; StatusLbl.Text = ""
    StatusLbl.TextColor3 = P.INK_LOW; StatusLbl.TextSize = 9
    StatusLbl.TextXAlignment = Enum.TextXAlignment.Center

    local function flash(msg, col)
        StatusLbl.Text = msg; StatusLbl.TextColor3 = col or P.INK_LOW
        task.delay(3, function() if StatusLbl.Text == msg then StatusLbl.Text = "" end end)
    end

    local Sep2 = Instance.new("Frame"); Sep2.Parent = PresetPane
    Sep2.BackgroundColor3 = P.EDGE; Sep2.BorderSizePixel = 0
    Sep2.Position = UDim2.new(0, 6, 0, 270); Sep2.Size = UDim2.new(1, -12, 0, 1)

    local AutoLbl = Instance.new("TextLabel"); AutoLbl.Parent = PresetPane
    AutoLbl.BackgroundTransparency = 1; AutoLbl.BorderSizePixel = 0
    AutoLbl.Position = UDim2.new(0, 6, 0, 275); AutoLbl.Size = UDim2.new(1, -50, 0, 12)
    AutoLbl.Font = Enum.Font.GothamBold; AutoLbl.Text = "AUTO-LOAD ON JOIN"
    AutoLbl.TextColor3 = P.INK_LOW; AutoLbl.TextSize = 8
    AutoLbl.TextXAlignment = Enum.TextXAlignment.Left

    local autoEnabled = persisted["__preload"] or false
    local AutoTrack = Instance.new("Frame"); AutoTrack.Parent = PresetPane
    AutoTrack.BackgroundColor3 = P.BASE1; AutoTrack.BorderSizePixel = 0
    AutoTrack.Position = UDim2.new(1, -36, 0, 274); AutoTrack.Size = UDim2.new(0, 28, 0, 14)
    mkCorner(AutoTrack, UDim.new(1, 0)); local autoEdge = mkBorder(AutoTrack, P.EDGE, 1)
    local AutoKnob = Instance.new("Frame"); AutoKnob.Parent = AutoTrack
    AutoKnob.AnchorPoint = Vector2.new(0, 0.5); AutoKnob.BackgroundColor3 = P.HUE
    AutoKnob.BorderSizePixel = 0; AutoKnob.Size = UDim2.new(0, 10, 0, 10)
    AutoKnob.Position = autoEnabled and UDim2.fromScale(0.55, 0.5) or UDim2.fromScale(0.1, 0.5)
    mkCorner(AutoKnob, UDim.new(1, 0))
    kit:track(PaletteSync:Bind(function() AutoKnob.BackgroundColor3 = P.HUE end))

    local function setAutoLoad(on, skipAnim)
        autoEnabled              = on
        AutoTrack.BackgroundColor3 = on and P.HUE:Lerp(P.BASE1, 0.55) or P.BASE1
        autoEdge.Color           = on and P.HUE or P.EDGE
        local tgt = on and UDim2.fromScale(0.58, 0.5) or UDim2.fromScale(0.10, 0.5)
        if skipAnim then AutoKnob.Position = tgt
        else AutoKnob:TweenPosition(tgt, "Out", "Quad", 0.15, true) end
        persist("__preload", on)
    end
    if autoEnabled then setAutoLoad(true, true) end

    local AutoBtn = Instance.new("TextButton"); AutoBtn.Parent = PresetPane
    AutoBtn.BackgroundTransparency = 1; AutoBtn.BorderSizePixel = 0
    AutoBtn.Position = UDim2.new(1, -36, 0, 268); AutoBtn.Size = UDim2.new(0, 28, 0, 14)
    AutoBtn.Text = ""; AutoBtn.AutoButtonColor = false
    AutoBtn.MouseButton1Click:Connect(function() setAutoLoad(not autoEnabled) end)

    local AutoNameLbl = Instance.new("TextLabel"); AutoNameLbl.Parent = PresetPane
    AutoNameLbl.BackgroundColor3 = P.BASE2; AutoNameLbl.BackgroundTransparency = 0
    AutoNameLbl.BorderSizePixel  = 0
    AutoNameLbl.Position = UDim2.new(0, 6, 0, 292); AutoNameLbl.Size = UDim2.new(1, -12, 0, 18)
    AutoNameLbl.Font = Enum.Font.GothamSemibold
    AutoNameLbl.Text = "  " .. (persisted["__preloadCfg"] or "default")
    AutoNameLbl.TextColor3 = P.INK_MID; AutoNameLbl.TextSize = 10
    AutoNameLbl.TextXAlignment = Enum.TextXAlignment.Left
    mkCorner(AutoNameLbl, R_SM); mkBorder(AutoNameLbl, P.EDGE, 1, 0.4)

    local SetAutoBtn = Instance.new("TextButton"); SetAutoBtn.Parent = PresetPane
    SetAutoBtn.BackgroundTransparency = 1; SetAutoBtn.BorderSizePixel = 0
    SetAutoBtn.Position = UDim2.new(0, 6, 0, 292); SetAutoBtn.Size = UDim2.new(1, -12, 0, 18)
    SetAutoBtn.Text = ""; SetAutoBtn.AutoButtonColor = false
    SetAutoBtn.MouseButton1Click:Connect(function()
        if activePreset then
            persist("__preloadCfg", activePreset)
            AutoNameLbl.Text      = "  " .. activePreset
            AutoNameLbl.TextColor3 = P.INK_HI
            flash("Auto-load → " .. activePreset, P.STATE_ON)
        else
            flash("Select a preset first", P.CAUTION)
        end
    end)

    local function makeActionBtn(lbl, x, y, w, col, fn)
        local btn = Instance.new("TextButton"); btn.Parent = PresetPane
        btn.BackgroundColor3 = col or P.BASE2; btn.BorderSizePixel = 0
        btn.Position = UDim2.new(0, x, 0, y); btn.Size = UDim2.new(0, w, 0, 22)
        btn.Font = Enum.Font.GothamBold; btn.Text = lbl
        btn.TextColor3 = P.INK_HI; btn.TextSize = 10; btn.AutoButtonColor = false
        mkCorner(btn, R_SM); mkBorder(btn, P.EDGE, 1, 0.4)
        btn.MouseEnter:Connect(function() btn.BackgroundColor3 = col == P.STATE_OFF and P.STATE_OFF or P.BASE_HOV end)
        btn.MouseLeave:Connect(function() btn.BackgroundColor3 = col or P.BASE2 end)
        btn.MouseButton1Click:Connect(fn); return btn
    end

    makeActionBtn("Load", 6,   202, 42, P.BASE2, function()
        if not activePreset then flash("Select a preset first", P.CAUTION); return end
        ovl.LoadRequest = activePreset; flash("Loading " .. activePreset .. "…", P.HUE)
    end)
    makeActionBtn("Save", 52,  202, 42, P.BASE2, function()
        if not activePreset then flash("Select a preset first", P.CAUTION); return end
        ovl.SaveRequest = activePreset; flash("Saved " .. activePreset, P.STATE_ON)
    end)
    makeActionBtn("New",  98,  202, 42, P.BASE2, function()
        local n = NameField.Text:gsub("[^%w_%-]", "_")
        if n == "" then flash("Enter a name first", P.CAUTION); return end
        ovl.SaveRequest = n; NameField.Text = ""
        flash("Created " .. n, P.STATE_ON)
        rebuildPresetList(game.PlaceId)
    end)
    makeActionBtn("Del",  144, 202, 50, P.STATE_OFF, function()
        if not activePreset then flash("Select a preset first", P.CAUTION); return end
        ovl.DeleteRequest = activePreset
        activePreset = nil; activeRow = nil
        flash("Deleted", P.STATE_OFF); rebuildPresetList(game.PlaceId)
    end)

    
    local SettingsPane = Instance.new("Frame"); SettingsPane.Parent = OvlFrame
    SettingsPane.BackgroundColor3 = P.BASE1; SettingsPane.BorderSizePixel = 0
    SettingsPane.Position = UDim2.new(0, 202, 0, HDR_H); SettingsPane.Size = UDim2.new(1, -202, 1, -HDR_H)
    mkBorder(SettingsPane, P.EDGE, 1, 0.3)

    local SettingsList = Instance.new("ScrollingFrame"); SettingsList.Parent = SettingsPane
    SettingsList.BackgroundTransparency = 1; SettingsList.BorderSizePixel = 0
    SettingsList.Size = UDim2.new(1, 0, 1, 0); SettingsList.CanvasSize = UDim2.new(0, 0, 0, 0)
    SettingsList.AutomaticCanvasSize = Enum.AutomaticSize.Y
    SettingsList.ScrollBarThickness = 2; SettingsList.ScrollBarImageColor3 = P.EDGE_HI
    local SettingsFlow = Instance.new("UIListLayout"); SettingsFlow.Parent = SettingsList
    SettingsFlow.HorizontalAlignment = Enum.HorizontalAlignment.Center
    SettingsFlow.SortOrder = Enum.SortOrder.LayoutOrder; SettingsFlow.Padding = UDim.new(0, 1)
    mkPad(SettingsList, 4, 4, 0, 0)

    ovl.SettingsList    = SettingsList
    ovl._resetCbs       = {}
    ovl._dir            = nil

    ovl.SetDir = function(dir)
        ovl._dir = dir; rebuildPresetList(dir)
    end
    ovl.RefreshConfigs = function() rebuildPresetList(ovl._dir) end
    task.defer(function() rebuildPresetList(ovl._dir) end)

    function ovl.AddSectionHeader(label)
        local sec = Instance.new("Frame"); sec.Parent = SettingsList
        sec.BackgroundTransparency = 1; sec.BorderSizePixel = 0; sec.Size = UDim2.new(1, -8, 0, 18)
        local line = Instance.new("Frame"); line.Parent = sec
        line.BackgroundColor3 = P.EDGE; line.BorderSizePixel = 0
        line.Position = UDim2.new(0, 0, 0.5, 0); line.Size = UDim2.new(1, 0, 0, 1)
        local lbl = Instance.new("TextLabel"); lbl.Parent = sec
        lbl.BackgroundColor3 = P.BASE1; lbl.BackgroundTransparency = 0; lbl.BorderSizePixel = 0
        lbl.AutomaticSize = Enum.AutomaticSize.X; lbl.Size = UDim2.new(0, 0, 1, 0); lbl.Position = UDim2.new(0, 6, 0, 0)
        lbl.Font = Enum.Font.GothamBold; lbl.Text = "  " .. label .. "  "
        lbl.TextColor3 = P.INK_LOW; lbl.TextSize = 9
    end

    function ovl.AddToggleRow(label, default, cb)
        local initVal  = persisted[label] ~= nil and persisted[label] or (default or false)
        local togState = false

        local TogRow = Instance.new("TextButton"); TogRow.Parent = SettingsList
        TogRow.BackgroundColor3 = P.BASE2; TogRow.BackgroundTransparency = 0
        TogRow.BorderSizePixel  = 0; TogRow.Size = UDim2.new(1, -8, 0, 22)
        TogRow.Text             = ""; TogRow.AutoButtonColor = false; mkCorner(TogRow, R_SM)

        local lbl = Instance.new("TextLabel"); lbl.Parent = TogRow
        lbl.BackgroundTransparency = 1; lbl.BorderSizePixel = 0
        lbl.Position = UDim2.new(0, 9, 0, 0); lbl.Size = UDim2.new(1, -42, 1, 0)
        lbl.Font = Enum.Font.GothamSemibold; lbl.Text = label
        lbl.TextColor3 = P.INK_MID; lbl.TextSize = 10; lbl.TextXAlignment = Enum.TextXAlignment.Left

        local Trk = Instance.new("Frame"); Trk.Parent = TogRow
        Trk.AnchorPoint = Vector2.new(1, 0.5); Trk.BackgroundColor3 = P.BASE1; Trk.BorderSizePixel = 0
        Trk.Position = UDim2.new(1, -8, 0.5, 0); Trk.Size = UDim2.new(0, 22, 0, 11)
        mkCorner(Trk, UDim.new(1, 0)); local trkEdge = mkBorder(Trk, P.EDGE, 1)

        local Knob = Instance.new("Frame"); Knob.Parent = Trk
        Knob.AnchorPoint = Vector2.new(0, 0.5); Knob.BackgroundColor3 = P.HUE
        Knob.BorderSizePixel = 0; Knob.Position = UDim2.fromScale(-0.1, 0.5)
        Knob.Size = UDim2.new(0, 8.7, 0, 8.7); mkCorner(Knob, UDim.new(1, 0))
        kit:track(PaletteSync:Bind(function() Knob.BackgroundColor3 = P.HUE end))

        local rowApi = { Enabled = false }
        function rowApi.Set(on, skipAnim)
            togState = on; rowApi.Enabled = on
            Trk.BackgroundColor3 = on and P.HUE:Lerp(P.BASE1, 0.55) or P.BASE1
            trkEdge.Color        = on and P.HUE or P.EDGE
            lbl.TextColor3       = on and P.INK_HI or P.INK_MID
            local tgt = on and UDim2.fromScale(0.58, 0.5) or UDim2.fromScale(0.14, 0.5)
            if skipAnim then Knob.Position = tgt
            else Knob:TweenPosition(tgt, "Out", "Quad", 0.15, true) end
            persist(label, on)
            if cb then task.spawn(cb, on) end
        end
        rowApi.Set(initVal, true)

        TogRow.MouseButton1Click:Connect(function() rowApi.Set(not togState) end)
        kit:track(TogRow.MouseEnter:Connect(function() TogRow.BackgroundColor3 = P.BASE_HOV end))
        kit:track(TogRow.MouseLeave:Connect(function() TogRow.BackgroundColor3 = P.BASE2 end))
        return rowApi
    end

    function ovl.AddSliderRow(label, mn, mx, def, rnd, cb)
        local initVal = persisted[label] ~= nil and persisted[label] or (def or mn)
        local cur     = initVal
        local r       = rnd or 0
        local function fmt(v)
            return r == 0 and tostring(math.floor(v)) or string.format("%." .. r .. "f", v)
        end

        local SlRow = Instance.new("Frame"); SlRow.Parent = SettingsList
        SlRow.BackgroundColor3 = P.BASE2; SlRow.BackgroundTransparency = 0
        SlRow.BorderSizePixel  = 0; SlRow.Size = UDim2.new(1, -8, 0, 34); mkCorner(SlRow, R_SM)

        local nmLbl = Instance.new("TextLabel"); nmLbl.Parent = SlRow
        nmLbl.BackgroundTransparency = 1; nmLbl.BorderSizePixel = 0
        nmLbl.Position = UDim2.new(0, 9, 0, 3); nmLbl.Size = UDim2.new(1, -52, 0, 13)
        nmLbl.Font = Enum.Font.GothamSemibold; nmLbl.Text = label
        nmLbl.TextColor3 = P.INK_MID; nmLbl.TextSize = 10; nmLbl.TextXAlignment = Enum.TextXAlignment.Left

        local vLbl = Instance.new("TextLabel"); vLbl.Parent = SlRow
        vLbl.BackgroundTransparency = 1; vLbl.BorderSizePixel = 0
        vLbl.AnchorPoint = Vector2.new(1, 0); vLbl.Position = UDim2.new(1, -7, 0, 3)
        vLbl.Size = UDim2.new(0, 38, 0, 13); vLbl.Font = Enum.Font.GothamBold
        vLbl.Text = fmt(cur); vLbl.TextColor3 = P.HUE; vLbl.TextSize = 10
        vLbl.TextXAlignment = Enum.TextXAlignment.Right
        kit:track(PaletteSync:Bind(function() vLbl.TextColor3 = P.HUE end))

        local Trk = Instance.new("Frame"); Trk.Parent = SlRow
        Trk.AnchorPoint = Vector2.new(0.5, 1); Trk.BackgroundColor3 = P.BASE1
        Trk.BorderSizePixel = 0; Trk.Position = UDim2.new(0.5, 0, 1, -7)
        Trk.Size = UDim2.new(1, -18, 0, 3); mkCorner(Trk, UDim.new(1, 0))

        local Fill = Instance.new("Frame"); Fill.Parent = Trk
        Fill.AnchorPoint = Vector2.new(0, 0.5); Fill.BackgroundColor3 = P.HUE
        Fill.BorderSizePixel = 0; Fill.Position = UDim2.new(0, 0, 0.5, 0)
        Fill.Size = UDim2.new((cur - mn) / math.max(mx - mn, 0.001), 0, 1, 0)
        mkCorner(Fill, UDim.new(1, 0))
        kit:track(PaletteSync:Bind(function() Fill.BackgroundColor3 = P.HUE end))

        local rowApi = {}
        function rowApi.Set(v, silent)
            cur = math.clamp(v, mn, mx)
            Fill.Size = UDim2.new((cur - mn) / math.max(mx - mn, 0.001), 0, 1, 0)
            vLbl.Text = fmt(cur)
            if not silent then persist(label, cur) end
            if cb then task.spawn(cb, cur) end
        end

        local sliding = false
        kit:track(Trk.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 then sliding = true end
        end))
        kit:track(Trk.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 then sliding = false end
        end))
        kit:track(UIS.InputChanged:Connect(function(i)
            if not sliding or i.UserInputType ~= Enum.UserInputType.MouseMovement then return end
            local sx = math.clamp((i.Position.X - Trk.AbsolutePosition.X) / Trk.AbsoluteSize.X, 0, 1)
            local nv = math.floor((((mx - mn) * sx + mn) * (10 ^ r)) + 0.5) / (10 ^ r)
            rowApi.Set(nv)
        end))
        kit:track(SlRow.MouseEnter:Connect(function() SlRow.BackgroundColor3 = P.BASE_HOV end))
        kit:track(SlRow.MouseLeave:Connect(function() SlRow.BackgroundColor3 = P.BASE2 end))
        rowApi.Set(cur, true)
        table.insert(ovl._resetCbs, function() rowApi.Set(def or mn) end)
        return rowApi
    end

    function ovl.Show()   OvlFrame.Visible = true  end
    function ovl.Hide()   OvlFrame.Visible = false end
    function ovl.Toggle() OvlFrame.Visible = not OvlFrame.Visible end

    return ovl
end


function Spectrum.CreateConfigBar(editor)
    local BAR_H = 18

    local Bar = Instance.new("Frame")
    Bar.Name                   = "PresetBar"; Bar.Parent = Root
    Bar.BackgroundColor3       = P.BASE1; Bar.BackgroundTransparency = 0
    Bar.BorderSizePixel        = 0; Bar.AnchorPoint = Vector2.new(0.5, 0)
    Bar.Position               = UDim2.new(0.5, 0, 0.03, 0); Bar.Size = UDim2.new(0, 260, 0, BAR_H)
    mkCorner(Bar, R_SM); mkBorder(Bar, P.EDGE, 1, 0.3)

    local BarTitle = Instance.new("TextLabel"); BarTitle.Parent = Bar
    BarTitle.BackgroundTransparency = 1; BarTitle.BorderSizePixel = 0
    BarTitle.Position = UDim2.new(0, 8, 0, 0); BarTitle.Size = UDim2.new(1, -50, 1, 0)
    BarTitle.Font = Enum.Font.GothamBold; BarTitle.Text = "⚙  Presets"
    BarTitle.TextColor3 = P.INK_MID; BarTitle.TextSize = 9; BarTitle.TextXAlignment = Enum.TextXAlignment.Left

    local ActiveLbl = Instance.new("TextLabel"); ActiveLbl.Parent = Bar
    ActiveLbl.BackgroundTransparency = 1; ActiveLbl.BorderSizePixel = 0
    ActiveLbl.AnchorPoint = Vector2.new(1, 0.5)
    ActiveLbl.Position = UDim2.new(1, -28, 0.5, 0); ActiveLbl.Size = UDim2.new(0, 100, 1, 0)
    ActiveLbl.Font = Enum.Font.GothamSemibold; ActiveLbl.Text = "default"
    ActiveLbl.TextColor3 = P.HUE; ActiveLbl.TextSize = 9; ActiveLbl.TextXAlignment = Enum.TextXAlignment.Right
    kit:track(PaletteSync:Bind(function() ActiveLbl.TextColor3 = P.HUE end))

    local OpenBtn = Instance.new("TextButton"); OpenBtn.Parent = Bar
    OpenBtn.AnchorPoint = Vector2.new(1, 0.5); OpenBtn.BackgroundTransparency = 1
    OpenBtn.BorderSizePixel = 0; OpenBtn.Position = UDim2.new(1, -6, 0.5, 0)
    OpenBtn.Size = UDim2.new(0, 16, 0, 16); OpenBtn.Font = Enum.Font.GothamBold
    OpenBtn.Text = "≡"; OpenBtn.TextColor3 = P.INK_MID; OpenBtn.TextSize = 14; OpenBtn.AutoButtonColor = false
    OpenBtn.MouseEnter:Connect(function() OpenBtn.TextColor3 = P.INK_HI end)
    OpenBtn.MouseLeave:Connect(function() OpenBtn.TextColor3 = P.INK_MID end)
    OpenBtn.MouseButton1Click:Connect(function()
        if editor then
            editor.Toggle()
            local vis = editor.Instance.Visible
            OpenBtn.Text       = vis and "×" or "≡"
            OpenBtn.TextColor3 = vis and P.STATE_OFF or P.INK_MID
        end
    end)

    local function refit()
        local vp = workspace.CurrentCamera.ViewportSize
        local s  = Scaler.Scale > 0 and Scaler.Scale or 1
        Bar.Size = UDim2.new(0, math.min(260, vp.X / s - 20), 0, BAR_H)
    end
    kit:track(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(refit))
    refit()

    local barApi = {}
    function barApi.SetName(name) ActiveLbl.Text = tostring(name) end
    barApi.Instance = Bar; return barApi
end

function Spectrum.CreateCustomWindow(cfg)
    local fp     = {}
    local fpId   = cfg.Name .. "Floater"

    local FloatFrame = Instance.new("Frame")
    FloatFrame.Name                   = "FloatFrame"; FloatFrame.Parent = Screen
    FloatFrame.BackgroundTransparency = 1
    FloatFrame.Position               = UDim2.new(0.5, 0, 0.5, 0)
    FloatFrame.AnchorPoint            = Vector2.new(0.5, 0.5)
    FloatFrame.Size                   = UDim2.new(0, COL_W + 8, 0, 240)
    FloatFrame.Visible                = false

    local FBar = Instance.new("Frame")
    FBar.Name             = "FBar"; FBar.Parent = FloatFrame
    FBar.BackgroundColor3 = P.BASE2; FBar.BorderSizePixel = 0
    FBar.Size             = UDim2.new(1, 0, 0, HDR_H)
    mkCorner(FBar, R_MD); mkBorder(FBar, P.EDGE, 1)
    kit:drag(FloatFrame, FBar)

    local FBarAccent = Instance.new("Frame")
    FBarAccent.Name             = "FBarAccent"; FBarAccent.Parent = FBar
    FBarAccent.BackgroundColor3 = P.HUE; FBarAccent.BorderSizePixel = 0
    FBarAccent.Size             = UDim2.new(0, 2, 0.5, 0); FBarAccent.Position = UDim2.new(0, 5, 0.25, 0)
    mkCorner(FBarAccent, UDim.new(1, 0))

    local FTitle = Instance.new("TextLabel")
    FTitle.Name               = "Name"; FTitle.Parent = FBar
    FTitle.BackgroundTransparency = 1; FTitle.BorderSizePixel = 0
    FTitle.Position           = UDim2.new(0, 13, 0, 0); FTitle.Size = UDim2.new(1, -38, 1, 0)
    FTitle.Font               = Enum.Font.GothamBold; FTitle.Text = cfg.Name
    FTitle.TextColor3         = P.INK_HI; FTitle.TextSize = 10; FTitle.TextXAlignment = Enum.TextXAlignment.Left

    local FGear = Instance.new("ImageButton")
    FGear.Name               = "FGear"; FGear.Parent = FBar
    FGear.BackgroundTransparency = 1; FGear.Position = UDim2.new(1, -26, 0.5, -8)
    FGear.Size               = UDim2.new(0, 16, 0, 16); FGear.ZIndex = 2
    FGear.Image              = "rbxassetid://3926305904"; FGear.ImageColor3 = P.INK_MID
    FGear.ImageRectOffset    = Vector2.new(84, 644); FGear.ImageRectSize = Vector2.new(36, 36)

    local FChildren = Instance.new("Frame")
    FChildren.Name                   = "FChildren"; FChildren.Parent = FloatFrame
    FChildren.BackgroundTransparency = 1; FChildren.Position = UDim2.new(0, 0, 0, HDR_H + 4)
    FChildren.Size                   = UDim2.new(1, 0, 1, -(HDR_H + 4)); FChildren.LayoutOrder = 99

    local FLayout = Instance.new("UIListLayout")
    FLayout.Parent = FloatFrame; FLayout.SortOrder = Enum.SortOrder.LayoutOrder

    local FSettings = Instance.new("Frame")
    FSettings.Name                   = "FSettings"; FSettings.Parent = FloatFrame
    FSettings.BackgroundColor3       = P.BASE1; FSettings.BackgroundTransparency = 0.02
    FSettings.BorderSizePixel        = 0; FSettings.Position = UDim2.new(0, 0, 0, HDR_H + 2)
    FSettings.Size                   = UDim2.new(1, 0, 0, 0); FSettings.Visible = false
    mkCorner(FSettings, R_MD); mkBorder(FSettings, P.EDGE, 1)

    local FOptionHolder = Instance.new("Frame")
    FOptionHolder.Name                   = "FOptionHolder"; FOptionHolder.Parent = FSettings
    FOptionHolder.BackgroundTransparency = 1; FOptionHolder.BorderSizePixel = 0
    FOptionHolder.Size                   = UDim2.new(1, 0, 1, 0)
    local FOptHolder = FOptionHolder

    local FFlow = Instance.new("UIListLayout")
    FFlow.Padding            = UDim.new(0, 1); FFlow.Parent = FOptionHolder
    FFlow.HorizontalAlignment = Enum.HorizontalAlignment.Center
    FFlow.SortOrder          = Enum.SortOrder.LayoutOrder
    mkPad(FOptionHolder, 3, 3, 0, 0)

    local _floatOn = false
    FBar.Visible = Spectrum.Root.Visible and _floatOn
    kit:track(Spectrum.Root:GetPropertyChangedSignal("Visible"):Connect(function()
        FBar.Visible = Spectrum.Root.Visible and _floatOn
        if not Spectrum.Root.Visible and fp.Expanded then fp.Expand() end
    end))

    function fp.SetVisible(on)
        _floatOn               = on
        FloatFrame.Visible     = on
        FBar.Visible           = Spectrum.Root.Visible and on
    end

    function fp.Update()
        local sz = FFlow.AbsoluteContentSize
        FOptionHolder.Size = UDim2.new(1, 0, 0, sz.Y / Scaler.Scale)
        FSettings.Size     = UDim2.new(1, 0, 0, (sz.Y + 6) / Scaler.Scale)
    end
    kit:track(FFlow:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fp.Update))
    fp.Update()

    function fp.Expand()
        if fp.Expanded then
            FChildren.Visible        = true;  FSettings.Visible = false
            fp.Expanded              = false;  FOptionHolder.Visible = false
            FGear.ImageColor3        = P.INK_MID
        else
            FSettings.Visible        = true;   fp.Expanded = true
            FOptionHolder.Visible    = true;   FGear.ImageColor3 = P.HUE
        end
        fp.Update()
    end
    FGear.MouseButton1Click:Connect(fp.Expand)
    FGear.MouseButton2Click:Connect(fp.Expand)
    fp.Instance = FloatFrame

    function fp.new(class)
        local inst = Instance.new(class); inst.Parent = FChildren; return inst
    end

    function fp.CreateToggle(cfg2)
        local sw = { Enabled = false }
        local SRow = Instance.new("TextButton"); SRow.Name = "Switch"; SRow.Parent = FOptHolder
        SRow.BackgroundColor3 = P.BASE2; SRow.BackgroundTransparency = 0; SRow.BorderSizePixel = 0
        SRow.Size = UDim2.new(0, COL_W + 4, 0, 22); SRow.Text = ""; SRow.AutoButtonColor = false
        sw.Instance = SRow; mkCorner(SRow, R_SM)
        local SLbl = Instance.new("TextLabel"); SLbl.Parent = SRow; SLbl.BackgroundTransparency = 1
        SLbl.BorderSizePixel = 0; SLbl.Position = UDim2.new(0, 9, 0, 0); SLbl.Size = UDim2.new(1, -38, 1, 0)
        SLbl.Font = Enum.Font.GothamSemibold; SLbl.Text = cfg2.Name; SLbl.TextColor3 = P.INK_MID
        SLbl.TextSize = 10; SLbl.TextTruncate = Enum.TextTruncate.AtEnd; SLbl.TextXAlignment = Enum.TextXAlignment.Left
        local STrk = Instance.new("TextButton"); STrk.Parent = SRow
        STrk.AnchorPoint = Vector2.new(0, 0.5); STrk.BackgroundColor3 = P.BASE1
        STrk.BackgroundTransparency = 0; STrk.BorderSizePixel = 0
        STrk.Position = UDim2.new(1, -32, 0.5, 0); STrk.Size = UDim2.new(0, 22, 0, 11)
        STrk.Text = ""; STrk.AutoButtonColor = false; mkCorner(STrk, UDim.new(1, 0))
        local sEdge = mkBorder(STrk, P.EDGE, 1)
        local SKnob = Instance.new("TextButton"); SKnob.Parent = STrk
        SKnob.AnchorPoint = Vector2.new(0, 0.5); SKnob.BackgroundColor3 = P.HUE
        SKnob.BorderSizePixel = 0; SKnob.Position = UDim2.fromScale(-0.1, 0.5)
        SKnob.Size = UDim2.new(0, 9, 0, 9); SKnob.Text = ""; SKnob.AutoButtonColor = false
        mkCorner(SKnob, UDim.new(1, 0))
        kit:track(PaletteSync:Bind(function()
            SKnob.BackgroundColor3 = P.HUE
            if sw.Enabled then STrk.BackgroundColor3 = P.HUE:Lerp(P.BASE1, 0.55); sEdge.Color = P.HUE end
        end))
        function sw.Toggle()
            if sw.Enabled then
                sw.Enabled = false; STrk.BackgroundColor3 = P.BASE1; sEdge.Color = P.EDGE
                SLbl.TextColor3 = P.INK_MID
                SKnob:TweenPosition(UDim2.fromScale(0.1, 0.5), "Out", "Quad", 0.15, true)
            else
                sw.Enabled = true; STrk.BackgroundColor3 = P.HUE:Lerp(P.BASE1, 0.55)
                sEdge.Color = P.HUE; SKnob.BackgroundColor3 = P.HUE
                SLbl.TextColor3 = P.INK_HI
                SKnob:TweenPosition(UDim2.fromScale(0.58, 0.5), "Out", "Quad", 0.15, true)
            end
            if cfg2.Function then task.spawn(cfg2.Function, sw.Enabled) end
        end
        kit:track(SKnob.MouseButton1Click:Connect(sw.Toggle))
        kit:track(STrk.MouseButton1Click:Connect(sw.Toggle))
        kit:track(SRow.MouseButton1Click:Connect(sw.Toggle))
        kit:track(SRow.MouseEnter:Connect(function() SRow.BackgroundColor3 = P.BASE_HOV end))
        kit:track(SRow.MouseLeave:Connect(function() SRow.BackgroundColor3 = P.BASE2 end))
        if cfg2.Default == true then sw.Toggle() end
        kit:register(cfg2.Name .. "Toggle_" .. fpId,
            { Name = cfg2.Name, Instance = SRow, Type = "Toggle",
              CustomWindow = fpId, API = sw, args = cfg2 })
        return sw
    end

    function fp.CreateSlider(cfg2)
        local rng = {}
        local mn, mx = cfg2.Min, cfg2.Max
        local def    = cfg2.Default or mn
        local rnd    = cfg2.Round or 1
        local rMult  = 10 ^ rnd
        local function fmt(v) return math.floor(v) == v and (tostring(v) .. ".0") or tostring(v) end
        local SFrame = Instance.new("Frame"); SFrame.Parent = FOptHolder
        SFrame.BackgroundColor3 = P.BASE2; SFrame.BackgroundTransparency = 0; SFrame.BorderSizePixel = 0
        SFrame.Size = UDim2.new(0, COL_W + 4, 0, 38); rng.Instance = SFrame; mkCorner(SFrame, R_SM)
        local SLbl = Instance.new("TextLabel"); SLbl.Parent = SFrame; SLbl.BackgroundTransparency = 1
        SLbl.BorderSizePixel = 0; SLbl.Position = UDim2.new(0, 9, 0, 4); SLbl.Size = UDim2.new(1, -52, 0, 14)
        SLbl.Font = Enum.Font.GothamSemibold; SLbl.Text = cfg2.Name; SLbl.TextColor3 = P.INK_MID
        SLbl.TextSize = 10; SLbl.TextTruncate = Enum.TextTruncate.AtEnd; SLbl.TextXAlignment = Enum.TextXAlignment.Left
        local VBox = Instance.new("TextBox"); VBox.Parent = SFrame
        VBox.AnchorPoint = Vector2.new(1, 0); VBox.BackgroundTransparency = 1; VBox.BorderSizePixel = 0
        VBox.Position = UDim2.new(1, -9, 0, 4); VBox.Size = UDim2.new(0, 38, 0, 14)
        VBox.Font = Enum.Font.GothamBold; VBox.PlaceholderText = "val"; VBox.Text = fmt(def)
        VBox.TextColor3 = P.HUE; VBox.TextSize = 10; VBox.TextXAlignment = Enum.TextXAlignment.Right
        local VLine = Instance.new("Frame"); VLine.Parent = VBox
        VLine.AnchorPoint = Vector2.new(1, 0); VLine.BackgroundColor3 = P.HUE
        VLine.BorderSizePixel = 0; VLine.Position = UDim2.new(1, 0, 1, 1)
        VLine.Size = UDim2.new(0.9, 0, 0, 1); VLine.Visible = false
        local STrk = Instance.new("Frame"); STrk.Parent = SFrame
        STrk.AnchorPoint = Vector2.new(0.5, 1); STrk.BackgroundColor3 = P.BASE1
        STrk.BorderSizePixel = 0; STrk.Position = UDim2.new(0.5, 0, 1, -7)
        STrk.Size = UDim2.new(1, -18, 0, 3); mkCorner(STrk, UDim.new(1, 0))
        local SFill = Instance.new("Frame"); SFill.Parent = STrk
        SFill.AnchorPoint = Vector2.new(0, 0.5); SFill.BackgroundColor3 = P.HUE
        SFill.BorderSizePixel = 0; SFill.Position = UDim2.new(0, 0, 0.5, 0)
        SFill.Size = UDim2.new(0, 50, 1, 0); mkCorner(SFill, UDim.new(1, 0))
        kit:track(PaletteSync:Bind(function() SFill.BackgroundColor3 = P.HUE end))
        kit:track(SFrame.MouseEnter:Connect(function() SFrame.BackgroundColor3 = P.BASE_HOV end))
        kit:track(SFrame.MouseLeave:Connect(function() SFrame.BackgroundColor3 = P.BASE2 end))
        kit:track(VBox.MouseEnter:Connect(function() VLine.Visible = true end))
        kit:track(VBox.MouseLeave:Connect(function() if not VBox:IsFocused() then VLine.Visible = false end end))
        kit:track(VBox.Focused:Connect(function() VLine.Visible = true end))
        kit:track(VBox.FocusLost:Connect(function()
            VLine.Visible = false
            local n = tonumber(VBox.Text)
            if n then rng.Set(n, true) else VBox.Text = fmt(rng.Value) end
        end))
        local function drag(input)
            local sx = math.clamp((input.Position.X - STrk.AbsolutePosition.X) / STrk.AbsoluteSize.X, 0, 1)
            SFill.Size = UDim2.new(sx, 0, 1, 0)
            local v = math.round(((mx - mn) * sx + mn) * rMult) / rMult
            rng.Value = v; VBox.Text = fmt(v)
            if not cfg2.OnInputEnded and cfg2.Function then task.spawn(cfg2.Function, v) end
        end
        local isSliding = false
        kit:track(SFrame.InputBegan:Connect(function(i)
            local ut = i.UserInputType
            if ut == Enum.UserInputType.MouseButton1 or ut == Enum.UserInputType.Touch then isSliding = true; drag(i) end
        end))
        kit:track(SFrame.InputEnded:Connect(function(i)
            local ut = i.UserInputType
            if ut == Enum.UserInputType.MouseButton1 or ut == Enum.UserInputType.Touch then
                if cfg2.OnInputEnded and cfg2.Function then task.spawn(cfg2.Function, rng.Value) end
                isSliding = false
            end
        end))
        kit:track(UIS.InputChanged:Connect(function(i)
            if isSliding and i.UserInputType == Enum.UserInputType.MouseMovement then drag(i) end
        end))
        function rng.Set(val, overMax)
            local clamped = not overMax
                and math.floor(math.clamp(val, mn, mx) * rMult + 0.5) / rMult
                or  math.clamp(val, cfg2.RealMin or -math.huge, cfg2.RealMax or math.huge)
            local sVal = math.floor(math.clamp(clamped, mn, mx) * rMult + 0.5) / rMult
            rng.Value = clamped; SFill.Size = UDim2.new((sVal - mn) / (mx - mn), 0, 1, 0)
            VBox.Text = fmt(clamped)
            if cfg2.Function then task.spawn(cfg2.Function, clamped) end
        end
        rng.Set(def)
        kit:register(cfg2.Name .. "Slider_" .. fpId,
            { Name = cfg2.Name, Instance = SFrame, Type = "Slider",
              CustomWindow = fpId, API = rng, args = cfg2 })
        return rng
    end

    function fp.CreateTextbox(cfg2)
        local inp = {}
        local IWrap = Instance.new("Frame"); IWrap.Parent = FOptionHolder
        IWrap.BackgroundTransparency = 1; IWrap.BorderSizePixel = 0
        IWrap.Size = UDim2.new(0, COL_W + 4, 0, 28); inp.Instance = IWrap
        local IBack = Instance.new("Frame"); IBack.Parent = IWrap
        IBack.AnchorPoint = Vector2.new(0.5, 0.5); IBack.BackgroundColor3 = P.BASE2
        IBack.BackgroundTransparency = 0; IBack.BorderSizePixel = 0
        IBack.Position = UDim2.new(0.5, 0, 0.5, 0); IBack.Size = UDim2.new(0, COL_W - 6, 0, 20)
        mkCorner(IBack, R_SM); local iEdge = mkBorder(IBack, P.EDGE, 1, 0.4)
        local IField = Instance.new("TextBox"); IField.Parent = IBack
        IField.AnchorPoint = Vector2.new(0.5, 0.5); IField.BackgroundTransparency = 1
        IField.BorderSizePixel = 0; IField.Position = UDim2.new(0.5, 0, 0.5, 0)
        IField.Size = UDim2.new(1, -14, 1, 0); IField.ClearTextOnFocus = false
        IField.Font = Enum.Font.GothamSemibold; IField.PlaceholderColor3 = P.INK_LOW
        IField.PlaceholderText = cfg2.Name; IField.Text = cfg2.Default or ""
        IField.TextColor3 = P.INK_HI; IField.TextSize = 10; IField.TextXAlignment = Enum.TextXAlignment.Left
        kit:track(IBack.MouseEnter:Connect(function() iEdge.Color = P.EDGE_HI; iEdge.Transparency = 0 end))
        kit:track(IBack.MouseLeave:Connect(function() iEdge.Color = P.EDGE; iEdge.Transparency = 0.4 end))
        function inp.Set(val)
            val = val or cfg2.Default or ""; inp.Value = val; IField.Text = val
            if cfg2.Function then task.spawn(cfg2.Function, val) end
        end
        kit:track(IField.FocusLost:Connect(function()
            local t = IField.Text; if t then inp.Set(t) end
        end))
        kit:register(cfg2.Name .. "Textbox_" .. fpId,
            { Name = cfg2.Name, Instance = IWrap, Type = "Textbox",
              CustomWindow = fpId, API = inp, args = cfg2 })
        return inp
    end
    fp.CreateTextBox = fp.CreateTextbox

    function fp.CreateDropdown(cfg2)
        local sel = { Values = {}, Expanded = false }
        local DWrap = Instance.new("Frame"); DWrap.Parent = FOptHolder
        DWrap.BackgroundTransparency = 1; DWrap.BorderSizePixel = 0
        DWrap.Size = UDim2.new(0, COL_W + 4, 0, 28); sel.Instance = DWrap
        local DBack = Instance.new("Frame"); DBack.Parent = DWrap
        DBack.AnchorPoint = Vector2.new(0.5, 0); DBack.BackgroundColor3 = P.BASE2
        DBack.BorderSizePixel = 0; DBack.Position = UDim2.new(0.5, 0, 0, 4)
        DBack.Size = UDim2.new(0, COL_W - 6, 0, 20); mkCorner(DBack, R_SM)
        local dEdge = mkBorder(DBack, P.EDGE, 1, 0.4)
        local DLbl = Instance.new("TextLabel"); DLbl.Parent = DBack; DLbl.BackgroundTransparency = 1
        DLbl.BorderSizePixel = 0; DLbl.Position = UDim2.new(0, 9, 0, 0); DLbl.Size = UDim2.new(1, -26, 1, 0)
        DLbl.Font = Enum.Font.GothamSemibold; DLbl.Text = cfg2.Name; DLbl.TextColor3 = P.INK_MID
        DLbl.TextSize = 10; DLbl.TextXAlignment = Enum.TextXAlignment.Left; DLbl.TextTruncate = Enum.TextTruncate.AtEnd
        local DChev = Instance.new("ImageButton"); DChev.Parent = DBack
        DChev.AnchorPoint = Vector2.new(0, 0.5); DChev.BackgroundTransparency = 1; DChev.BorderSizePixel = 0
        DChev.Position = UDim2.new(1, -18, 0.5, 0); DChev.Size = UDim2.new(0, 14, 0, 14); DChev.ZIndex = 2
        DChev.Image = "http://www.roblox.com/asset/?id=6031094679"; DChev.ImageColor3 = P.INK_LOW
        DChev.ScaleType = Enum.ScaleType.Fit
        local DList = Instance.new("Frame"); DList.Parent = DWrap
        DList.AnchorPoint = Vector2.new(0.5, 0); DList.BackgroundColor3 = P.BASE1
        DList.BackgroundTransparency = 0; DList.BorderSizePixel = 0
        DList.Position = UDim2.new(0.5, 0, 0, 28); DList.Size = UDim2.new(0, COL_W - 6, 0, 0)
        DList.Visible = false; mkCorner(DList, R_SM)
        mkBorder(DList, P.EDGE, 1, 0.4); mkPad(DList, 2, 2, 0, 0)
        local DItemFlow = Instance.new("UIListLayout"); DItemFlow.Parent = DList
        DItemFlow.HorizontalAlignment = Enum.HorizontalAlignment.Center
        DItemFlow.SortOrder = Enum.SortOrder.LayoutOrder
        kit:track(DBack.MouseEnter:Connect(function()
            dEdge.Color = P.EDGE_HI; dEdge.Transparency = 0; DBack.BackgroundColor3 = P.BASE_HOV end))
        kit:track(DBack.MouseLeave:Connect(function()
            dEdge.Color = P.EDGE; dEdge.Transparency = 0.4; DBack.BackgroundColor3 = P.BASE2 end))
        function sel.Update()
            local sz = DItemFlow.AbsoluteContentSize.Y
            if DList.Visible then
                DWrap.Size = UDim2.new(0, COL_W + 4, 0, (28 * Scaler.Scale + sz + 6) / Scaler.Scale)
                DList.Size = UDim2.new(0, COL_W - 6, 0, sz + 4)
            else DWrap.Size = UDim2.new(0, COL_W + 4, 0, 28) end
        end
        kit:track(DItemFlow:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(sel.Update))
        function sel.SetValue(val)
            for _, v in next, sel.Values do
                local match = v.Value == val
                v.SelectedInstance.Visible = match
                if match then
                    sel.Value = val; DLbl.Text = cfg2.Name .. " · " .. tostring(val)
                    DLbl.TextColor3 = P.INK_HI
                    if cfg2.Function then task.spawn(cfg2.Function, val) end
                end
            end
        end
        local function newDItem(val)
            local vi = { Value = val }
            local Btn = Instance.new("TextButton"); Btn.Parent = DList
            Btn.BackgroundColor3 = P.BASE1; Btn.BackgroundTransparency = 0; Btn.BorderSizePixel = 0
            Btn.Size = UDim2.new(0, COL_W - 12, 0, 20); Btn.Text = ""; Btn.AutoButtonColor = false; mkCorner(Btn, R_SM)
            Btn.MouseButton1Click:Connect(function() sel.SetValue(val) end)
            kit:track(Btn.MouseEnter:Connect(function() Btn.BackgroundColor3 = P.BASE_HOV end))
            kit:track(Btn.MouseLeave:Connect(function() Btn.BackgroundColor3 = P.BASE1 end))
            local Lbl = Instance.new("TextLabel"); Lbl.Parent = Btn; Lbl.BackgroundTransparency = 1
            Lbl.BorderSizePixel = 0; Lbl.Position = UDim2.new(0, 12, 0, 0); Lbl.Size = UDim2.new(1, -18, 1, 0)
            Lbl.Font = Enum.Font.GothamSemibold; Lbl.Text = tostring(val); Lbl.TextColor3 = P.INK_MID
            Lbl.TextSize = 10; Lbl.TextXAlignment = Enum.TextXAlignment.Left
            local Dot = Instance.new("Frame"); Dot.Parent = Btn; Dot.AnchorPoint = Vector2.new(0, 0.5)
            Dot.BackgroundColor3 = P.HUE; Dot.Visible = false; Dot.BorderSizePixel = 0
            Dot.Position = UDim2.new(0, 3, 0.5, 0); Dot.Size = UDim2.new(0, 2, 0.5, 0); mkCorner(Dot, UDim.new(1, 0))
            kit:track(PaletteSync:Bind(function() Dot.BackgroundColor3 = P.HUE end))
            vi.SelectedInstance = Dot; vi.Instance = Btn; return vi
        end
        function sel.Expand()
            if sel.Expanded then
                sel.Expanded = false; DList.Visible = false; DChev.Rotation = 0; DChev.ImageColor3 = P.INK_LOW
            else DChev.Rotation = 180; DChev.ImageColor3 = P.HUE; sel.Expanded = true; DList.Visible = true end
            sel.Update()
        end
        kit:track(DChev.MouseButton1Click:Connect(sel.Expand))
        for _, v in next, cfg2.List do sel.Values[#sel.Values + 1] = newDItem(v) end
        if cfg2.Default then sel.SetValue(cfg2.Default) end
        function sel.SetList(list)
            for i, v in next, sel.Values do v.Instance:Destroy(); sel.Values[i] = nil end
            sel.Values = {}
            for _, v in next, list do sel.Values[#sel.Values + 1] = newDItem(v) end
        end
        kit:register(cfg2.Name .. "Dropdown_" .. fpId,
            { Name = cfg2.Name, Instance = DWrap, Type = "Dropdown",
              CustomWindow = fpId, API = sel, args = cfg2 })
        return sel
    end

    kit:register(cfg.Name .. "CustomWindow",
        { Name = cfg.Name, Instance = FloatFrame, Type = "CustomWindow", API = fp, args = cfg })
    return fp
end

kit:track(UIS.InputBegan:Connect(function(input)
    if UIS:GetFocusedTextBox() then return end
    if input.KeyCode == Enum.KeyCode.Unknown then return end
    local key = input.KeyCode.Name
    if key == "Backspace" or key == "Delete" or key == "Escape" then key = nil end
    if not Spectrum.Registry then return end
    for _, v in next, Spectrum.Registry do
        if Spectrum.IsRecording then
            if v.Type == "OptionsButton" and v.API.Recording then
                Spectrum.IsRecording = false; v.API.Recording = false; v.API.SetBind(key); return
            end
        else
            if v.Type == "OptionsButton" and v.API.Bind == (key or "") then
                v.API.Toggle(true)
            end
        end
    end
end))


Spectrum.Objects     = Spectrum.Registry
Spectrum.Connections = Spectrum.Tracked

if isBad then
    local wm = Instance.new("TextLabel", Spectrum.Screen)
    wm.BackgroundTransparency = 1
    wm.Size                   = UDim2.new(0, 0, 0, 18)
    wm.AutomaticSize          = Enum.AutomaticSize.X
    wm.Position               = UDim2.new(1, -8, 0, 8)
    wm.AnchorPoint            = Vector2.new(1, 0)
    wm.Font                   = Enum.Font.GothamBold
    wm.TextColor3             = P.STATE_OFF
    wm.TextScaled             = false
    wm.TextSize               = 10
    wm.Text                   = "⚠ unsupported executor"
end

return Spectrum
