repeat task.wait() until game:IsLoaded()

local GITHUB_RAW = "https://raw.githubusercontent.com/XzynAstralz/Phantom/main"

do
    local required = {"cache", "configs", "config", "assets/icons"}
    for _, v in listfiles("Phantom") do
        local name = string.reverse(string.split(string.reverse(v), "\\")[1])
        local idx  = table.find(required, name)
        if idx then table.remove(required, idx) end
    end
    for _, v in required do makefolder("Phantom/" .. v) end
end

local Loader = {}
function Loader.fetch(path)
	local ok, result = pcall(function()
		return game:HttpGet(GITHUB_RAW .. "/" .. path)
	end)
	if ok and result and result ~= "" then
		return result
	end
	warn("[phantom] fetch failed: " .. path)
	return nil
end

function Loader.loadScript(path)
	if getgenv().developerMode then
		if isfile(path) then
			return readfile(path)
		end
		warn("[phantom] local file missing: " .. path)
		return nil
	else
		Loader.fetch(path)
	end

	return src
end

function Loader.exec(path)
	local src = Loader.loadScript(path)
	if not src or src == "" then
		warn("[phantom] nothing to exec: " .. path)
		return
	end
	local fn, err = loadstring(src)
	if type(fn) ~= "function" then
		warn("[phantom] compile error in " .. path .. ": " .. tostring(err))
		return
	end
	return fn()
end

function Loader.fetchIcon(name)
    local path = "Phantom/assets/icons/" .. name .. ".png"

    if getgenv().developerMode then
		 if isfile(path) then
            return getcustomasset(path)
        end
	else
        local data = Loader.fetch("assets/icons/" .. name .. ".png")
        if data then
            writefile(path, data)
            return getcustomasset(path)
        end
    end

    return nil
end

local patcherSrc = Loader.loadScript("Phantom/lib/patcher.lua")
if patcherSrc and patcherSrc ~= "" then
	local fn, err = loadstring(patcherSrc)
	if type(fn) == "function" then fn() else warn("[phantom] patcher error: " .. tostring(err)) end
end

local bootTick = tick()
local queueteleport = queue_for_teleport or queue_on_teleport or queueonteleport
local UIS = game:GetService("UserInputService")
local ts = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local Players = game:GetService("Players")
local lplr = Players.LocalPlayer

local exitHooks = {}
local entity, UI
local gameReady = false

local ops = {}

function ops:placeKey()
	return tostring(game.CreatorId or game.PlaceId)
end

function ops:placeScript()
	local localPath = "Phantom/games/" .. ops:placeKey() .. ".lua"
	return Loader.loadScript(localPath) or ""
end

function ops:universalScript()
	return Loader.loadScript("Phantom/games/universal.lua") or ""
end

function ops:exec(code)
	if not code or code == "" then return end
	local fn, err = loadstring(code)
	if type(fn) ~= "function" then return warn("[phantom] failed: " .. tostring(err)) end
	return fn()
end

function ops:wlfind(tab, obj)
	for _, v in next, tab do
		if v == obj or (type(v) == "table" and v.hash == obj) then return v end
	end
end

function ops:track(...) return UI.kit:track(...) end

function ops:lookup(name, prop, val)
	for i, v in next, UI.Registry do
		if i == name and v[prop] == val then return v end
	end
end

local loops = {RenderStepped = {}, Heartbeat = {}, Stepped = {}}

function ops:onStepped(id, cb)
	if loops.Stepped[id] then return warn("[phantom] already bound: " .. id) end
	loops.Stepped[id] = RunService.PreSimulation:Connect(cb)
end
function ops:offStepped(id)
	if loops.Stepped[id] then loops.Stepped[id]:Disconnect(); loops.Stepped[id] = nil end
end
function ops:onRender(id, cb)
	if loops.RenderStepped[id] then return warn("[phantom] already bound: " .. id) end
	loops.RenderStepped[id] = RunService.PreSimulation:Connect(cb)
end
function ops:offRender(id)
	if loops.RenderStepped[id] then loops.RenderStepped[id]:Disconnect(); loops.RenderStepped[id] = nil end
end
function ops:onHeartbeat(id, cb)
	if loops.Heartbeat[id] then return warn("[phantom] already bound: " .. id) end
	loops.Heartbeat[id] = RunService.PreSimulation:Connect(cb)
end
function ops:offHeartbeat(id)
	if loops.Heartbeat[id] then loops.Heartbeat[id]:Disconnect(); loops.Heartbeat[id] = nil end
end
function ops:onExit(id, cb)  exitHooks[id] = cb  end
function ops:offExit(id)     exitHooks[id] = nil end

function ops:enemyColor(isEnemy)
	return isEnemy and Color3.new(1, 0.427450, 0.427450) or Color3.new(0.470588, 1, 0.470588)
end
function ops:entityColor(ent, useTeamColor, useColorTheme)
	if ent.Team and ent.Team.TeamColor.Color and useTeamColor then return ent.Team.TeamColor.Color end
	if useColorTheme then return UI.kit:activeColor() end
	return ops:enemyColor(ent.Targetable)
end

function ops:newCleanup()
	local bag, tasks = {}, {}
	bag.tasks = tasks
	function bag:add(x) table.insert(tasks, x) end
	function bag:flush()
		for i, v in next, tasks do
			local t = typeof(v)
			if t == "Instance" then v:Destroy()
			elseif t == "table" and v.__OBJECT and v.__OBJECT_EXISTS then v:Remove()
			elseif t == "RBXScriptConnection" and v.Connected then v:Disconnect()
			elseif t == "function" then v() end
			tasks[i] = nil
		end
	end
	return bag
end

local function stateDir()
	return "Phantom/configs/" .. ops:placeKey() .. "/"
end

function ops:pushState(slot)
	if not gameReady then warn("[phantom]: game script not loaded"); return end
	if not phantom then return end
	slot = slot or "default"
	local path = stateDir() .. slot .. ".json"
	local config = {}
	for i, v in next, UI.Registry do
		if v.Type == "OptionsButton" then
			config[i] = {Enabled = v.API.Enabled, Bind = v.API.Bind, Type = v.Type, Window = v.Window}
		elseif v.Type == "Toggle" then
			config[i] = {Enabled = v.API.Enabled, Type = v.Type, OptionsButton = v.OptionsButton, CustomWindow = v.CustomWindow}
		elseif v.Type == "Slider" then
			config[i] = {Value = v.API.Value, Type = v.Type, OptionsButton = v.OptionsButton, CustomWindow = v.CustomWindow}
		elseif v.Type == "Dropdown" then
			config[i] = {Value = v.API.Value, Type = v.Type, OptionsButton = v.OptionsButton, CustomWindow = v.CustomWindow}
		elseif v.Type == "Textbox" then
			config[i] = {Value = v.API.Value, Type = v.Type, OptionsButton = v.OptionsButton, CustomWindow = v.CustomWindow}
		elseif v.Type == "MultiDropdown" then
			local vals = v.API.Values
			for _, vv in next, vals do vv.Instance = nil; vv.SelectedInstance = nil end
			config[i] = {Values = vals, Type = v.Type, OptionsButton = v.OptionsButton, CustomWindow = v.CustomWindow}
		elseif v.Type == "Textlist" then
			config[i] = {Values = v.API.Values, Type = v.Type, OptionsButton = v.OptionsButton, CustomWindow = v.CustomWindow}
		elseif v.Type == "CustomWindow" then
			local p = v.Instance.Position
			config[i] = {Type = v.Type, Position = {
				X = {Scale = p.X.Scale, Offset = p.X.Offset},
				Y = {Scale = p.Y.Scale, Offset = p.Y.Offset},
			}}
		end
	end
	UI.saveTabPositions()
	makefolder(stateDir())
	if isfile(path) then delfile(path) end
	local ok, encoded = pcall(function() return HttpService:JSONEncode(config) end)
	if ok then
		writefile(path, encoded)
		repeat task.wait() until isfile(path)
	else
		warn("[phantom] failed to save config: " .. encoded)
	end
end

function ops:pullState(slot)
	if not phantom then return end
	slot = slot or "default"
	getgenv().configloaded = false
	local path = stateDir() .. slot .. ".json"
	if not isfile(path) then getgenv().configloaded = true; return end

	local returned
	task.spawn(function()
		returned = HttpService:JSONDecode(readfile(path))
	end)
	repeat task.wait() until returned

	for i, v in next, returned do
		local prop
		if v.Type == "OptionsButton" then
			prop = "Window"
		elseif v.CustomWindow then
			prop = "CustomWindow"
		else
			prop = "OptionsButton"
		end
		local object = ops:lookup(i, prop, v[prop])
		if object then
			if v.Type == "OptionsButton" then
				if v.Bind and v.Bind ~= "" then object.API.SetBind(v.Bind) end
				if v.Enabled then object.API.Toggle() end
			elseif v.Type == "Toggle" then
				if v.Enabled ~= object.API.Enabled then object.API.Toggle() end
			elseif v.Type == "Slider" then
				object.API.Set(v.Value, true)
			elseif v.Type == "Dropdown" then
				object.API.SetValue(v.Value)
			elseif v.Type == "Textbox" then
				object.API.Set(v.Value)
			elseif v.Type == "MultiDropdown" then
				for _, vv in next, v.Values do
					if vv.Enabled then object.API.ToggleValue(vv.Value) end
				end
			elseif v.Type == "Textlist" then
				for _, vv in next, v.Values do object.API.Add(vv) end
			elseif v.Type == "CustomWindow" then
				object.Instance.Position = UDim2.new(
					v.Position.X.Scale, v.Position.X.Offset,
					v.Position.Y.Scale, v.Position.Y.Offset
				)
			end
		end
	end
	getgenv().configloaded = true
end

ops.saveConfig = function(self) ops:pushState() end
ops.loadConfig = function(self) ops:pullState() end

if not getgenv then return warn("[phantom] unsupported executor.") end
if phantom      then return warn("[phantom] already loaded.") end

local guiLibSrc = Loader.loadScript("Phantom/GuiLibrary.lua")
if not guiLibSrc or guiLibSrc == "" then
	if not getgenv().developerMode then
		guiLibSrc = Loader.fetch("GuiLibrary.lua")
	end
	if not guiLibSrc or guiLibSrc == "" then
		return warn("[phantom] failed to load GuiLibrary")
	end
end

UI = loadstring(guiLibSrc)()

getgenv().phantom = {}
local ShutdownEvent = Instance.new("BindableEvent")
phantom.UI = UI
phantom.ops = ops
phantom.funcs = ops
phantom.loader = Loader

local tabs = {
	combat    = UI.window({Name = "combat",    Icon = Loader.fetchIcon("combat")}),
	blatant   = UI.window({Name = "blatant",   Icon = Loader.fetchIcon("blatant")}),
	render    = UI.window({Name = "render",    Icon = Loader.fetchIcon("render")}),
	utillity  = UI.window({Name = "utillity",  Icon = Loader.fetchIcon("utillity")}),
	world     = UI.window({Name = "world",     Icon = Loader.fetchIcon("world")}),
	misc      = UI.window({Name = "misc",      Icon = Loader.fetchIcon("misc")}),
	inventory = UI.window({Name = "inventory", Icon = Loader.fetchIcon("inventory")}),
	other     = UI.window({Name = "other",     Icon = Loader.fetchIcon("other")}),
}
local windows = tabs

local UninjectButton = {}
UninjectButton = tabs.other.CreateOptionsButton({
	Name = "uninject",
	Function = function(callback)
		if callback then UninjectButton.Toggle(); ShutdownEvent:Fire() end
	end,
})

local ReinjectButton = {}
ReinjectButton = tabs.other.CreateOptionsButton({
	Name = "reinject",
	Function = function(callback)
		if callback then
			ReinjectButton.Toggle()
			ShutdownEvent:Fire()
			repeat task.wait() until not getgenv().phantom
			local src = Loader.loadScript("Phantom/Main.lua")
			if src and src ~= "" then
				loadstring(src)()
			else
				warn("[phantom] failed to reinject")
			end
		end
	end,
})

do
	local con
	local hook = function()
		if UIS.MouseBehavior ~= Enum.MouseBehavior.Default then
			UIS.MouseBehavior = Enum.MouseBehavior.Default
		end
	end
	con = UIS:GetPropertyChangedSignal("MouseBehavior"):Connect(function()
		if UI.Root.Visible then hook() end
	end)
	ops:onExit("mouseLockFix", function() con:Disconnect() end)

	tabs.other.CreateOptionsButton({
		Name = "gui",
		Function = function()
			if not UI.Root.Visible then hook() end
			UI.toggle()
		end,
		Bind = "RightShift",
	})
	UI.Root.Visible = false
end

local panicButton = {}
panicButton = tabs.other.CreateOptionsButton({
	Name = "panic",
	Function = function(callback)
		if callback then
			panicButton.Toggle()
			for _, v in UI.Registry do
				if (v.Type == "OptionsButton" or v.Type == "Toggle") and v.API.Enabled then
					v.API.Toggle()
				end
			end
		end
	end,
})

local featureListWindow = UI.CreateCustomWindow({Name = "array list"})
local keyDisplayWindow = UI.CreateCustomWindow({Name = "keystrokes"})
local targetHudWindow = UI.CreateCustomWindow({Name = "Targethud"})
local wmWindow = UI.CreateCustomWindow({Name = "watermark"})
local serverWmWindow = UI.CreateCustomWindow({Name = "Server IP"})
featureListWindow.Instance.Size          = UDim2.new(0, 200, 0, 0)
featureListWindow.Instance.AutomaticSize = Enum.AutomaticSize.Y

local ovlEditor = UI.CreateHudConfig({})
local presetBar = UI.CreateConfigBar(ovlEditor)

ovlEditor.AddSectionHeader("Visibility")

local featureListToggle = ovlEditor.AddToggleRow("array list", false, function(on)
	featureListWindow.SetVisible(on)
end)
local keyDisplayToggle = ovlEditor.AddToggleRow("keystrokes", false, function(on)
	keyDisplayWindow.SetVisible(on)
end)
local wmToggle = ovlEditor.AddToggleRow("watermark", false, function(on) wmWindow.SetVisible(on)       end)
local serverIPToggle = ovlEditor.AddToggleRow("server IP", false, function(on) serverWmWindow.SetVisible(on) end)
local targetToggle = ovlEditor.AddToggleRow("targethud", false, function(on) targetHudWindow.SetVisible(on) end)

ovlEditor.AddSectionHeader("GUI Settings")

ovlEditor.AddToggleRow("canScale", true, function(on)
	UI.canScale = on
	UI.rescale()
end)

local hueVal, satVal, brightVal = 216, 79, 91
local rainbowApi

rainbowApi = ovlEditor.AddToggleRow("rainbow", false, function(on)
	UI.RainbowMode = on
	if not on then
		UI.kit:writePalette({H = hueVal / 360, S = satVal / 100, V = brightVal / 100})
	end
end)

ovlEditor.AddSliderRow("rainbow smooth", 10, 100, 23, 0, function(v)
	UI.RainbowSpeed = v * 75
end)
ovlEditor.AddSliderRow("hue", 0, 360, 216, 0, function(v)
	hueVal = v
	if UI.RainbowMode then return end
	local old = UI.kit:readPalette(true)
	UI.kit:writePalette({H = v / 360, S = old.S, V = old.V})
end)
ovlEditor.AddSliderRow("saturation", 0, 100, 79, 0, function(v)
	satVal = v
	local old = UI.kit:readPalette(true)
	UI.kit:writePalette({H = old.H, S = v / 100, V = old.V})
end)
ovlEditor.AddSliderRow("brightness", 0, 100, 91, 0, function(v)
	brightVal = v
	local old = UI.kit:readPalette(true)
	UI.kit:writePalette({H = old.H, S = old.S, V = v / 100})
end)

local featureList = {Line = {}}
local sortMode, LineToggle = {}, {}

do
	local ArrayList = featureListWindow.new("Frame")
	ArrayList.Name                   = "ArrayList"
	ArrayList.BackgroundTransparency = 1
	ArrayList.Position               = UDim2.new(-0.551886797, 0, 0, 0)
	ArrayList.Size                   = UDim2.new(0, 319, 0, 362)
	featureList.ArrayListInstance    = ArrayList

	local UIListLayout = Instance.new("UIListLayout")
	UIListLayout.Parent              = ArrayList
	UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	UIListLayout.SortOrder           = Enum.SortOrder.LayoutOrder

	local Watermark = Instance.new("TextLabel")
	Watermark.Name                   = "Watermark"; Watermark.Parent = ArrayList
	Watermark.BackgroundTransparency = 1
	Watermark.Position               = UDim2.new(0, 0, 0.05, 0); Watermark.Size = UDim2.new(0, 601, 0.1456832382, 0)
	Watermark.Font                   = Enum.Font.GothamSemibold; Watermark.Text = "phantom"
	Watermark.TextColor3             = UI.kit:objectColor(Watermark)
	Watermark.TextScaled             = true; Watermark.TextStrokeTransparency = 0
	Watermark.TextWrapped            = true; Watermark.TextXAlignment = Enum.TextXAlignment.Right
	UI.kit:track(UI.PaletteSync:Bind(function()
		Watermark.TextColor3 = UI.kit:objectColor(Watermark)
	end))
	featureList.Watermark = Watermark

	local WatermarkText = Instance.new("TextLabel")
	WatermarkText.Name                   = "WatermarkText"; WatermarkText.Parent = ArrayList
	WatermarkText.BackgroundTransparency = 1
	WatermarkText.Position               = UDim2.new(0, 0, 0.1, 0); WatermarkText.Size = UDim2.new(0, 601, 0.0756832382, 0)
	WatermarkText.Font                   = Enum.Font.GothamSemibold; WatermarkText.Text = "Custom Text!"
	WatermarkText.TextColor3             = UI.kit:objectColor(WatermarkText)
	WatermarkText.TextScaled             = true; WatermarkText.TextStrokeTransparency = 0
	WatermarkText.TextWrapped            = true; WatermarkText.TextXAlignment = Enum.TextXAlignment.Right
	UI.kit:track(UI.PaletteSync:Bind(function()
		WatermarkText.TextColor3 = UI.kit:objectColor(WatermarkText)
	end))
	featureList.WatermarkText = WatermarkText

	function featureList.handleEntry(name, ExtraText, enabled, wasKeyDown, windowname)
		if windowname == "renderPanel" or windowname == "otherPanel" then return end
		featureList.Objects = featureList.Objects or {}
		local lbl = featureList.Objects[name] or Instance.new("TextLabel")
		lbl.Name   = "ArrayListModule"; lbl.Parent = ArrayList
		lbl.BackgroundTransparency = 1
		lbl.Position  = UDim2.new(0, 0, 0.151490679, 0); lbl.Size = UDim2.new(0, 601, 0.0556832382, 0)
		lbl.Font      = Enum.Font.GothamSemibold; lbl.RichText = true
		lbl.Text      = name .. (ExtraText and ExtraText ~= "" and
			' <font color="rgb(200,200,200)">[' .. ExtraText .. ']</font>' or "")
		lbl.TextColor3 = UI.kit:objectColor(lbl)
		UI.kit:track(UI.PaletteSync:Bind(function()
			lbl.TextColor3 = UI.kit:objectColor(lbl)
		end))
		lbl.TextScaled            = true; lbl.TextStrokeTransparency = 0.5
		lbl.TextWrapped           = true; lbl.TextXAlignment = Enum.TextXAlignment.Right
		featureList.Objects[name] = lbl

		local line = Instance.new("Frame")
		line.Name             = "Line"; line.Parent = lbl
		line.BackgroundColor3 = UI.kit:activeColor()
		line.Size             = UDim2.new(0, 5, 1, 0); line.Position = UDim2.new(1.01, 0, 0, 0)
		line.BorderSizePixel  = 0; line.Visible = LineToggle.Enabled
		table.insert(featureList.Line, line)
		UI.kit:track(UI.PaletteSync:Bind(function()
			line.BackgroundColor3 = UI.kit:activeColor()
		end))

		if not enabled then
			lbl:Destroy(); featureList.Objects[name] = nil; return
		end

		local children = ArrayList:GetChildren()
		table.sort(children, function(a, b)
			if not a:IsA("TextLabel") then return false end
			if not b:IsA("TextLabel") then return true  end
			if sortMode.Value == "Alphabetical" then return a.Text < b.Text end
			if sortMode.Value == "Size"         then return a.TextBounds.X > b.TextBounds.X end
		end)
		for i, v in next, children do
			if v.Name:find("Watermark") then
				v.LayoutOrder = (v.Name:find("Text") and 2) or 0
			elseif v:IsA("TextLabel") then
				v.LayoutOrder = i + 2
			end
		end
	end

	function featureList.SetScale(scale)
		ArrayList.Size = UDim2.new(0, 319, 0, 362 * scale)
	end
end

UI.ModuleSync:Bind(function(name, ExtraText, enabled, wasKeyDown, windowname)
	featureList.handleEntry(name, ExtraText, enabled, wasKeyDown, windowname)
end)

featureListWindow.CreateSlider({
	Name = "scale", Min = 0.5, Max = 2, Default = 1, Round = 1,
	Function = function(v) featureList.SetScale(v) end,
})
sortMode = featureListWindow.CreateDropdown({
	Name = "mode", List = {"Alphabetical", "Size"}, Default = "Size",
})
LineToggle = featureListWindow.CreateToggle({
	Name = "Line", Default = true,
	Function = function(on)
		for _, ln in pairs(featureList.Line) do ln.Visible = on end
	end,
})
featureListWindow.CreateToggle({
	Name = "watermark", Default = true,
	Function = function(on) featureList.Watermark.Visible = on end,
})
local CustomText = featureListWindow.CreateToggle({
	Name = "custom text",
	Function = function(on)
		featureList.WatermarkText.Visible = (featureList.WatermarkText.Text ~= "") and on
	end,
})
featureListWindow.CreateTextbox({
	Name = "custom text",
	Function = function(v)
		featureList.WatermarkText.Visible = (v ~= "") and CustomText.Enabled
		featureList.WatermarkText.Text    = v
	end,
})

do
	local F = wmWindow.new("Frame")
	F.BackgroundColor3 = Color3.fromRGB(27, 27, 28); F.BorderSizePixel = 0
	F.Position = UDim2.new(0, 0, 0, 0); F.Size = UDim2.new(0, 206, 0, 32); F.ZIndex = 10
	local divider = Instance.new("Frame"); divider.Parent = F
	divider.BackgroundColor3 = Color3.fromRGB(81, 81, 82); divider.BorderSizePixel = 0
	divider.Position = UDim2.new(0.16, 0, 0.031, 0); divider.Size = UDim2.new(0, 2, 0, 31)
	local uc = Instance.new("UICorner"); uc.CornerRadius = UDim.new(0, 11); uc.Parent = F
	local lbl = Instance.new("TextLabel"); lbl.Parent = F
	lbl.BackgroundTransparency = 1; lbl.BorderSizePixel = 0
	lbl.Position = UDim2.new(0.1898, 0, 0.03125, 0); lbl.Size = UDim2.new(0, 164, 0, 31)
	lbl.Font = Enum.Font.Roboto; lbl.Text = "Phantom 2.20 (rel-188)"
	lbl.TextColor3 = Color3.fromRGB(160, 160, 161); lbl.TextSize = 17; lbl.RichText = true
	local img = Instance.new("ImageLabel"); img.Parent = F
	img.BackgroundTransparency = 1; img.BorderSizePixel = 0
	img.Position = UDim2.new(0.04, 0, 0.141, 0); img.Size = UDim2.new(0, 20, 0, 22)
	img.Image = "rbxassetid://80499963022356"
end

do
	local F = serverWmWindow.new("Frame")
	F.BackgroundColor3 = Color3.fromRGB(27, 27, 28); F.BorderSizePixel = 0
	F.Position = UDim2.new(0, 0, 0, 0); F.Size = UDim2.new(0, 177, 0, 32)
	local divider = Instance.new("Frame"); divider.Parent = F
	divider.BackgroundColor3 = Color3.fromRGB(81, 81, 82); divider.BorderSizePixel = 0
	divider.Position = UDim2.new(0.1700, 0, 0, 0); divider.Size = UDim2.new(0, 2, 0, 32)
	local uc = Instance.new("UICorner"); uc.CornerRadius = UDim.new(0, 11); uc.Parent = F
	local lbl = Instance.new("TextLabel"); lbl.Parent = F
	lbl.BackgroundTransparency = 1; lbl.BorderSizePixel = 0
	lbl.Position = UDim2.new(0.18, 0, 0, 0); lbl.Size = UDim2.new(0, 148, 0, 32)
	lbl.Font = Enum.Font.Roboto; lbl.Text = "Server: Roblox"
	lbl.TextColor3 = Color3.fromRGB(160, 160, 161); lbl.TextSize = 19; lbl.TextWrapped = true
	local img = Instance.new("ImageLabel"); img.Parent = F
	img.BackgroundTransparency = 1; img.BorderSizePixel = 0
	img.Position = UDim2.new(0.02, 0, 0.125, 0); img.Size = UDim2.new(0, 25, 0, 24)
	img.Image = "http://www.roblox.com/asset/?id=84990427093509"
end

do
	local MainFrame = targetHudWindow.new("Frame")
	MainFrame.BackgroundColor3  = Color3.fromRGB(0, 0, 0); MainFrame.BackgroundTransparency = 0.2
	MainFrame.BorderSizePixel   = 0; MainFrame.Position = UDim2.new(0, 0, 0, 0)
	MainFrame.Size              = UDim2.new(0, 245, 0, 106)

	local function label(name, x, y, w, h, text, size, font, align)
		local l = Instance.new("TextLabel"); l.Name = name; l.Parent = MainFrame
		l.BackgroundTransparency = 1; l.Position = UDim2.new(x, 0, y, 0)
		l.Size = UDim2.new(0, w, 0, h); l.Font = font or Enum.Font.Ubuntu
		l.Text = text or ""; l.TextColor3 = Color3.fromRGB(255, 255, 255)
		l.TextSize = size or 17; l.TextXAlignment = align or Enum.TextXAlignment.Left
		return l
	end
	label("TitleLabel", 0.03, 0, 122, 26, "Target", 15)
	local Div = Instance.new("Frame"); Div.Parent = MainFrame
	Div.BackgroundColor3 = Color3.fromRGB(255, 255, 255); Div.Position = UDim2.new(0, 0, 0.23, 0)
	Div.Size = UDim2.new(1, 0, 0, 2)
	local AvatarImage = Instance.new("ImageLabel"); AvatarImage.Parent = MainFrame
	AvatarImage.BackgroundTransparency = 1; AvatarImage.Position = UDim2.new(0.03, 0, 0.35, 0)
	AvatarImage.Size = UDim2.new(0, 73, 0, 53)
	local UsernameLabel = label("UsernameLabel", 0.36, 0.35, 122, 22)
	local HealthLabel   = label("HealthLabel",   0.36, 0.50, 122, 22)
	local DistanceLabel = label("DistanceLabel", 0.36, 0.64, 132, 22)

	shared.phantom = shared.phantom or {}
	shared.phantom.targethud = {
		Targets   = {},
		UpdateHUD = function()
			if #shared.phantom.targethud.Targets == 0 then
				HealthLabel.Text   = "0%"
				AvatarImage.Image  = "rbxthumb://type=AvatarHeadShot&id=1&w=180&h=180"
				UsernameLabel.Text = "Unknown"; UsernameLabel.TextSize = 17
				DistanceLabel.Text = "0 studs"; return
			end
			for _, v in ipairs(shared.phantom.targethud.Targets) do
				local player   = Players:GetPlayerFromCharacter(v)
				local username = player and player.Name or "Unknown"
				local hp       = v.Humanoid and v.Humanoid.Health or v.health or 0
				local maxhp    = v.Humanoid and v.Humanoid.MaxHealth or v.MaxHealth or 100
				HealthLabel.Text = string.format("%d%%", math.floor((hp / maxhp) * 100 + 0.5))
				local ok, img = player and pcall(function()
					return Players:GetUserThumbnailAsync(player.UserId,
						Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size180x180)
				end)
				AvatarImage.Image      = ok and img or "rbxthumb://type=AvatarHeadShot&id=1&w=180&h=180"
				UsernameLabel.TextSize = player and math.clamp(17 - math.floor((#username / 25) * 5), 12, 17) or 17
				UsernameLabel.Text     = username
				DistanceLabel.Text     = string.format("%d studs",
					math.floor((lplr.Character.HumanoidRootPart.Position - v.PrimaryPart.Position).Magnitude))
				break
			end
		end,
	}

	local targetConn
	if not targetConn then
		targetConn = RunService.PreSimulation:Connect(function()
			if targetToggle.Enabled then shared.phantom.targethud.UpdateHUD() end
		end)
		ops:onExit("UpdateTargetStuff", function()
			if targetConn then targetConn:Disconnect(); targetConn = nil end
		end)
	end
end

task.spawn(function()
	ops:exec(ops:universalScript())
	local placeScript = ops:placeScript()
	if placeScript and placeScript ~= "" then
		ops:exec(placeScript)
	end
	gameReady = true
end)

local tpQueued = false
UI.kit:track(lplr.OnTeleport:Connect(function(State)
	if State and queueteleport and not tpQueued then
		tpQueued = true
		writefile("Phantom/cache/lastPlace", tostring(game.PlaceId))
		if getgenv().developerMode then
			queueteleport([[
				ranTeleport = true
				loadstring(readfile("Phantom/Main.lua"))()
			]])
		else
			queueteleport(([[
				ranTeleport = true
				loadstring(game:HttpGet("%s/Main.lua"))()
			]]):format(GITHUB_RAW))
		end
		ops:pushState()
	end
end))

UI.kit:track(Players.PlayerRemoving:Connect(function(p)
	if p == lplr then ops:pushState() end
end))

local shutting, saved = false, false
ShutdownEvent.Event:Connect(function()
	if shutting then return end
	shutting = true
	if not saved and gameReady then saved = true; ops:pushState() end
	for _, v in exitHooks do task.spawn(v) end
	for _, v in UI.Registry do
		if (v.Type == "OptionsButton" or v.Type == "Toggle") and v.API.Enabled and v.API.Function then
			v.API.Enabled = false; task.spawn(v.API.Function)
		end
	end
	for _, v in pairs(UI.Tracked) do
		pcall(function() (v.Disconnect or v.Unbind)(v) end)
	end
	if UI.Screen then UI.Screen:Destroy() end
	getgenv().phantom      = nil
	getgenv().configloaded = nil
end)

repeat task.wait() until gameReady or not phantom
if not phantom then return end

local cfgDir = "Phantom/configs/" .. ops:placeKey() .. "/"
if not isfolder(cfgDir) then makefolder(cfgDir) end
ovlEditor.SetDir(cfgDir)

local autoPreset = nil
do
	local ok, overlayCfg = pcall(function()
		return HttpService:JSONDecode(readfile("config/overlay.cfg.json"))
	end)
	if ok and overlayCfg and overlayCfg["__preload"] and overlayCfg["__preloadCfg"] then
		local name = overlayCfg["__preloadCfg"]
		if isfile(cfgDir .. name .. ".json") then autoPreset = name end
	end
end

ops:pullState(autoPreset or "default")
presetBar.SetName(autoPreset or "default")

task.spawn(function()
	ops:onHeartbeat("ovlEditorPoll", function()
		task.wait(0.3)
		if ovlEditor.SaveRequest then
			local name = ovlEditor.SaveRequest; ovlEditor.SaveRequest = nil
			ops:pushState(name); presetBar.SetName(name); ovlEditor.SetDir(cfgDir)
		end
		if ovlEditor.LoadRequest then
			local name = ovlEditor.LoadRequest; ovlEditor.LoadRequest = nil
			local path = cfgDir .. name .. ".json"
			if isfile(path) then ops:pullState(name); presetBar.SetName(name) end
		end
		if ovlEditor.DeleteRequest then
			local name = ovlEditor.DeleteRequest; ovlEditor.DeleteRequest = nil
			local path = cfgDir .. name .. ".json"
			pcall(function() if isfile(path) then delfile(path) end end)
			ovlEditor.SetDir(cfgDir)
		end
	end)
	ops:onExit("ovlEditorPoll", function() ops:offHeartbeat("ovlEditorPoll") end)
end)
