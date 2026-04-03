--!nocheck

repeat task.wait() until game:IsLoaded()

local environment = getfenv and getfenv() or {}

local executorGetEnv = environment.getgenv
local executorCloneRef = environment.cloneref or function(value)
	return value
end
local executorIsFile = environment.isfile
local executorReadFile = environment.readfile
local executorGetCustomAsset = environment.getcustomasset
local _genv = (executorGetEnv and executorGetEnv()) or {}
local executorQueueForTeleport = environment.queue_for_teleport or _genv.queue_for_teleport
local executorQueueOnTeleport = environment.queue_on_teleport or _genv.queue_on_teleport
local executorQueueOnTeleportLegacy = environment.queueonteleport or _genv.queueonteleport

if not executorGetEnv or not executorIsFile or not executorReadFile then
	return warn("[phantom] unsupported executor.")
end

local ROOT = "Phantom"

local function service(name)
	local instance = game:GetService(name)
	if executorCloneRef then
		local ok, cloned = pcall(executorCloneRef, instance)
		if ok and cloned then
			return cloned
		end
	end
	return instance
end

local function runtimePath(path)
	return ROOT .. "/" .. path
end

local function readRuntimeFile(path)
	local fullPath = runtimePath(path)
	if not executorIsFile(fullPath) then
		error("[phantom] missing runtime file: " .. fullPath)
	end
	return executorReadFile(fullPath), fullPath
end

local function loadRuntimeModule(path)
	local source, fullPath = readRuntimeFile(path)
	local chunk, err = loadstring(source, "@" .. fullPath)
	if not chunk then
		error("[phantom] failed to compile " .. path .. ": " .. tostring(err))
	end

	local ok, result = pcall(chunk)
	if not ok then
		error("[phantom] failed to execute " .. path .. ": " .. tostring(result))
	end

	return result
end

local env = executorGetEnv()
env.phantomInstances = type(env.phantomInstances) == "table" and env.phantomInstances or {}

do
	local shutdownQueue = {}
	local seen = {}

	if type(env.phantom) == "table" then
		shutdownQueue[#shutdownQueue + 1] = env.phantom
	end

	for _, instance in ipairs(env.phantomInstances) do
		shutdownQueue[#shutdownQueue + 1] = instance
	end

	for _, instance in ipairs(shutdownQueue) do
		if type(instance) == "table" and not seen[instance] then
			seen[instance] = true
			if type(instance.Shutdown) == "function" then
				pcall(instance.Shutdown, "hot-reload")
			end
		end
	end
end

local Logger = loadRuntimeModule("lib/core/Logger.lua")
local File = loadRuntimeModule("lib/core/File.lua")
local Http = loadRuntimeModule("lib/core/Http.lua")
local Manager = loadRuntimeModule("lib/core/Manager.lua")
local Runtime = loadRuntimeModule("lib/core/Runtime.lua")
local Config = loadRuntimeModule("lib/core/Config.lua")
local Module = loadRuntimeModule("lib/core/Module.lua")
local Version = loadRuntimeModule("lib/core/Version.lua")
local Updater = loadRuntimeModule("lib/core/Updater.lua")

local bootstrapLogger = Logger.new("[phantom]", false)
local fileApi = File.new(ROOT, bootstrapLogger)
fileApi:EnsureRuntimeFolders()

local http = Http.new(bootstrapLogger)
local config = Config.new(fileApi, bootstrapLogger)
local updater = Updater.new({
	file = fileApi,
	http = http,
	config = config,
	logger = bootstrapLogger,
	repo = {
		owner = "XzynAstralz",
		name = "Phantom",
	},
})
local settings = updater:GetSettings()

local logger = Logger.new("[phantom]", settings.debugLogs or settings.developerMode)
fileApi.logger = logger
http.logger = logger
config.logger = logger
updater.logger = logger

local versionData = Version.Read(fileApi)
local rootManager = Manager.new("phantom")
local runtime = Runtime.new(logger)
local moduleLoader = Module.new(fileApi, logger)
moduleLoader:SetDeveloperMode(settings.developerMode)

local Services = {
	Players = service("Players"),
	UserInputService = service("UserInputService"),
	TeleportService = service("TeleportService"),
	RunService = service("RunService"),
	Lighting = service("Lighting"),
	HttpService = service("HttpService"),
}
local LocalPlayer = Services.Players.LocalPlayer
local queueTeleport = executorQueueForTeleport or executorQueueOnTeleport or executorQueueOnTeleportLegacy
local placeId = tostring(game.PlaceId)
local creatorId = tonumber(game.CreatorId) and tostring(game.CreatorId) or ""
local profileSlot = "default"
local overlayStatePath = "config/overlay.cfg.json"
local overlayState = fileApi:ReadJson(overlayStatePath, {})
local hudEditor
local configBar
local arrayListWidget
local watermarkWindow
local sessionInfoWindow

local function readOverlayToggleState(key, defaultValue)
	if type(overlayState) ~= "table" then
		return defaultValue == true
	end

	local value = overlayState[key]
	if type(value) == "boolean" then
		return value
	end

	return defaultValue == true
end

local function creatorScriptPath()
	if creatorId == "" or creatorId == "0" then
		return nil
	end
	return "games/" .. creatorId .. ".lua"
end

local function creatorScriptExists()
	local path = creatorScriptPath()
	return path ~= nil and fileApi:IsFile(path)
end

local function activeGameKey()
	if creatorScriptExists() then
		return creatorId
	end
	return placeId
end

if type(overlayState) == "table" and overlayState.__preload == true then
	local preloadSlot = overlayState.__preloadCfg
	if type(preloadSlot) == "string" and preloadSlot ~= "" then
		profileSlot = preloadSlot
	end
end

local function getIcon(name)
	local path = "assets/icons/" .. tostring(name) .. ".png"
	local fullPath = fileApi:Resolve(path)
	if not executorIsFile(fullPath) or not executorGetCustomAsset then
		return nil
	end

	local ok, asset = pcall(executorGetCustomAsset, fullPath)
	if ok then
		return asset
	end
	return nil
end

local uiExport = loadRuntimeModule("GuiLibrary.lua")
local UI = type(uiExport) == "function" and uiExport() or uiExport
if not UI then
	error("[phantom] failed to initialize GuiLibrary")
end

local function readGuiTheme()
	local defaults = {
		H = 0.60,
		S = 0.79,
		V = 0.91,
		RainbowMode = false,
		RainbowSpeed = 1750,
	}

	if UI.GetThemeState then
		local state = UI.GetThemeState() or {}
		local palette = state.Palette or {}
		return {
			H = palette.H or defaults.H,
			S = palette.S or defaults.S,
			V = palette.V or defaults.V,
			RainbowMode = state.RainbowMode == true,
			RainbowSpeed = state.RainbowSpeed or defaults.RainbowSpeed,
		}
	end

	return defaults
end

local function setGuiPalette(palette)
	if UI.SetPalette then
		UI.SetPalette(palette)
	elseif UI.kit and UI.kit.writePalette then
		UI.kit:writePalette(palette)
	end
end

local function updateGuiPalette(key, value)
	local theme = readGuiTheme()
	theme[key] = value
	setGuiPalette({
		H = theme.H,
		S = theme.S,
		V = theme.V,
	})
	end

local function setGuiRainbowMode(enabled)
	if UI.SetRainbowMode then
		UI.SetRainbowMode(enabled)
		return
	end

	UI.RainbowMode = enabled == true
	if UI.PaletteSync then
		UI.PaletteSync:Emit()
	end
end

local function setGuiRainbowSpeed(speed)
	local value = math.max(250, math.floor(tonumber(speed) or 1750))
	if UI.SetRainbowSpeed then
		UI.SetRainbowSpeed(value)
		return
	end

	UI.RainbowSpeed = value
	if UI.PaletteSync then
		UI.PaletteSync:Emit()
	end
end

local function bindGuiTheme(callback)
	callback()
	if UI.PaletteSync then
		rootManager:AddConnection(UI.PaletteSync:Bind(callback))
	end
end

local tabs = UI.CreateDefaultTabs({
	ShowIcons = true,
	IconResolver = function(name)
		return getIcon(name)
	end,
})

if UI.CreateArrayListWidget then
	arrayListWidget = UI.CreateArrayListWidget({
		Name = "array list",
	})
	if arrayListWidget.SetVisible then
		arrayListWidget.SetVisible(readOverlayToggleState("show arraylist", false))
	end
end

if UI.CreateHudConfig then
	hudEditor = UI.CreateHudConfig({
		Name = "settings hub",
		StateFile = fileApi:Resolve(overlayStatePath),
	})
	if hudEditor.SetDir then
		hudEditor.SetDir(fileApi:Resolve("configs/" .. placeId))
	end
	if hudEditor.AddSectionHeader then
		hudEditor.AddSectionHeader("Gui Colors")
	end
	if hudEditor.AddToggleRow then
		hudEditor.AddToggleRow("rainbow gui", false, function(on)
			setGuiRainbowMode(on)
		end)
	end
	if hudEditor.AddSliderRow then
		hudEditor.AddSliderRow("rainbow speed", 250, 4000, 1750, 0, function(value)
			setGuiRainbowSpeed(value)
		end)
		hudEditor.AddSliderRow("gui hue", 0, 360, 216, 0, function(value)
			updateGuiPalette("H", math.clamp(value / 360, 0, 1))
		end)
		hudEditor.AddSliderRow("gui saturation", 0, 100, 79, 0, function(value)
			updateGuiPalette("S", math.clamp(value / 100, 0, 1))
		end)
		hudEditor.AddSliderRow("gui brightness", 0, 100, 91, 0, function(value)
			updateGuiPalette("V", math.clamp(value / 100, 0, 1))
		end)
	end
	if hudEditor.AddSectionHeader then
		hudEditor.AddSectionHeader("Visibility")
	end
	if hudEditor.AddSectionHeader then
		hudEditor.AddSectionHeader("HUD")
	end
	if arrayListWidget and hudEditor.AddToggleRow then
		hudEditor.AddToggleRow("show arraylist", false, function(on)
			if arrayListWidget.SetVisible then
				arrayListWidget.SetVisible(on)
			end
		end)
	end
	if arrayListWidget and arrayListWidget.SetScale and hudEditor.AddSliderRow then
		hudEditor.AddSliderRow("arraylist scale", 0.5, 2, 1, 1, function(value)
			arrayListWidget.SetScale(value)
		end)
	end
end

if UI.CreateConfigBar and hudEditor then
	configBar = UI.CreateConfigBar(hudEditor)
	if configBar and configBar.SetVisible then
		configBar.SetVisible(readOverlayToggleState("show preset bar", false))
	elseif configBar and configBar.Instance then
		configBar.Instance.Visible = readOverlayToggleState("show preset bar", false)
	end
	if hudEditor.AddToggleRow and configBar and configBar.Instance then
		hudEditor.AddToggleRow("show preset bar", false, function(on)
			if configBar.SetVisible then
				configBar.SetVisible(on)
			else
				configBar.Instance.Visible = on
			end
		end)
	end
end

if UI.CreateCustomWindow then
	watermarkWindow = UI.CreateCustomWindow({ Name = "watermark" })
	sessionInfoWindow = UI.CreateCustomWindow({ Name = "session info" })
	watermarkWindow.SetVisible(readOverlayToggleState("watermark", false))
	sessionInfoWindow.SetVisible(readOverlayToggleState("session info", false))

	task.defer(function()
		local cam = workspace.CurrentCamera
		local vp  = cam and cam.ViewportSize or Vector2.new(1920, 1080)
		local padX = math.max(10, math.floor(vp.X * 0.012))
		local padY = math.max(8,  math.floor(vp.Y * 0.012))
		local gap  = math.max(20, math.floor(vp.Y * 0.1))
		if watermarkWindow.Instance then
			watermarkWindow.Instance.AnchorPoint = Vector2.new(0, 0)
			watermarkWindow.Instance.Position    = UDim2.new(0, padX, 0, padY)
		end
		if sessionInfoWindow.Instance then
			sessionInfoWindow.Instance.AnchorPoint = Vector2.new(0, 0)
			sessionInfoWindow.Instance.Position    = UDim2.new(0, padX, 0, padY + gap)
		end
	end)

	do
		local frame = watermarkWindow.new("Frame")
		frame.BackgroundColor3 = Color3.fromRGB(17, 17, 19)
		frame.BorderSizePixel = 0
		frame.Size = UDim2.new(0, 168, 0, 24)
		frame.ZIndex = 10

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = frame

		local stroke = Instance.new("UIStroke")
		stroke.Transparency = 0.55
		stroke.Thickness = 1
		stroke.Parent = frame

		local accent = Instance.new("Frame")
		accent.Parent = frame
		accent.BackgroundColor3 = UI.kit:activeColor()
		accent.BorderSizePixel = 0
		accent.Position = UDim2.new(0, 8, 0.5, -6)
		accent.Size = UDim2.new(0, 3, 0, 12)
		local accentCorner = Instance.new("UICorner")
		accentCorner.CornerRadius = UDim.new(1, 0)
		accentCorner.Parent = accent

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Parent = frame
		nameLabel.BackgroundTransparency = 1
		nameLabel.Position = UDim2.new(0, 18, 0.5, -7)
		nameLabel.Size = UDim2.new(0, 62, 0, 14)
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.Text = tostring(versionData.name or "Phantom")
		nameLabel.TextColor3 = Color3.fromRGB(190, 190, 205)
		nameLabel.TextSize = 11
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left

		local versionLabel = Instance.new("TextLabel")
		versionLabel.Parent = frame
		versionLabel.BackgroundTransparency = 1
		versionLabel.Position = UDim2.new(0, 76, 0.5, -7)
		versionLabel.Size = UDim2.new(0, 38, 0, 14)
		versionLabel.Font = Enum.Font.Gotham
		versionLabel.Text = tostring(versionData.base)
		versionLabel.TextColor3 = Color3.fromRGB(95, 95, 140)
		versionLabel.TextSize = 11
		versionLabel.TextXAlignment = Enum.TextXAlignment.Left

		local badge = Instance.new("Frame")
		badge.Parent = frame
		badge.BackgroundColor3 = UI.kit:activeColor()
		badge.BackgroundTransparency = 0.85
		badge.BorderSizePixel = 0
		badge.Position = UDim2.new(0, 116, 0.5, -7)
		badge.Size = UDim2.new(0, 44, 0, 14)
		badge.ZIndex = 11

		local badgeCorner = Instance.new("UICorner")
		badgeCorner.CornerRadius = UDim.new(0, 3)
		badgeCorner.Parent = badge

		local badgeStroke = Instance.new("UIStroke")
		badgeStroke.Transparency = 0.7
		badgeStroke.Thickness = 1
		badgeStroke.Parent = badge

		local releaseLabel = Instance.new("TextLabel")
		releaseLabel.Parent = badge
		releaseLabel.BackgroundTransparency = 1
		releaseLabel.Size = UDim2.new(1, 0, 1, 0)
		releaseLabel.Font = Enum.Font.Gotham
		releaseLabel.Text = tostring(versionData.releaseTag or "local")
		releaseLabel.TextColor3 = Color3.fromRGB(170, 150, 255)
		releaseLabel.TextSize = 9
		releaseLabel.ZIndex = 12

		bindGuiTheme(function()
			local color = UI.kit:activeColor()
			stroke.Color = color
			badgeStroke.Color = color
			accent.BackgroundColor3 = color
			badge.BackgroundColor3 = color
		end)
	end

	do
		local frame = sessionInfoWindow.new("Frame")
		frame.BackgroundColor3 = Color3.fromRGB(17, 17, 19)
		frame.BorderSizePixel = 0
		frame.Size = UDim2.new(0, 180, 0, 92)

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = frame

		local stroke = Instance.new("UIStroke")
		stroke.Transparency = 0.55
		stroke.Thickness = 1
		stroke.Parent = frame

		local title = Instance.new("TextLabel")
		title.Parent = frame
		title.BackgroundTransparency = 1
		title.Position = UDim2.new(0, 10, 0, 6)
		title.Size = UDim2.new(1, -20, 0, 14)
		title.Font = Enum.Font.GothamBold
		title.Text = "Session Info"
		title.TextColor3 = Color3.fromRGB(200, 200, 215)
		title.TextSize = 11
		title.TextXAlignment = Enum.TextXAlignment.Left

		local divider = Instance.new("Frame")
		divider.Parent = frame
		divider.BackgroundColor3 = Color3.fromRGB(40, 42, 58)
		divider.BorderSizePixel = 0
		divider.Position = UDim2.new(0, 10, 0, 24)
		divider.Size = UDim2.new(1, -20, 0, 1)

		local function makeRow(index, name)
			local label = Instance.new("TextLabel")
			label.Parent = frame
			label.BackgroundTransparency = 1
			label.Position = UDim2.new(0, 10, 0, 28 + ((index - 1) * 15))
			label.Size = UDim2.new(0, 70, 0, 14)
			label.Font = Enum.Font.GothamSemibold
			label.Text = name
			label.TextColor3 = Color3.fromRGB(132, 136, 154)
			label.TextSize = 10
			label.TextXAlignment = Enum.TextXAlignment.Left

			local value = Instance.new("TextLabel")
			value.Parent = frame
			value.BackgroundTransparency = 1
			value.Position = UDim2.new(0, 82, 0, 28 + ((index - 1) * 15))
			value.Size = UDim2.new(1, -92, 0, 14)
			value.Font = Enum.Font.Gotham
			value.Text = "-"
			value.TextColor3 = Color3.fromRGB(205, 208, 220)
			value.TextSize = 10
			value.TextXAlignment = Enum.TextXAlignment.Right
			return value
		end

		local uptimeValue = makeRow(1, "Session")
		local pingValue = makeRow(2, "Ping")
		local fpsValue = makeRow(3, "FPS")
		local moduleValue = makeRow(4, "Module")

		bindGuiTheme(function()
			local color = UI.kit:activeColor()
			stroke.Color = color
			divider.BackgroundColor3 = color:Lerp(Color3.fromRGB(17, 17, 19), 0.7)
			moduleValue.TextColor3 = color:Lerp(Color3.fromRGB(255, 255, 255), 0.2)
		end)

		local sessionStarted = os.clock()
		local fpsEstimate = 60
		local fpsSamples = 0
		local elapsed = 0

		local function formatDuration(totalSeconds)
			totalSeconds = math.max(0, math.floor(totalSeconds))
			local hours = math.floor(totalSeconds / 3600)
			local minutes = math.floor((totalSeconds % 3600) / 60)
			local seconds = totalSeconds % 60
			return string.format("%02d:%02d:%02d", hours, minutes, seconds)
		end

		rootManager:AddConnection(Services.RunService.RenderStepped:Connect(function(dt)
			if dt > 0 then
				local instant = 1 / dt
				fpsSamples = math.min(fpsSamples + 1, 30)
				fpsEstimate = fpsEstimate + ((instant - fpsEstimate) / fpsSamples)
			end
		end))

		rootManager:AddConnection(Services.RunService.Heartbeat:Connect(function(dt)
			elapsed = elapsed + dt
			if elapsed < 0.25 then
				return
			end
			elapsed = 0

			local ping = 0
			pcall(function()
				ping = math.floor((LocalPlayer:GetNetworkPing() * 1000) + 0.5)
			end)

			uptimeValue.Text = formatDuration(os.clock() - sessionStarted)
			pingValue.Text = tostring(ping) .. " ms"
			fpsValue.Text = tostring(math.floor(fpsEstimate + 0.5))
			moduleValue.Text = creatorScriptExists() and ("creator " .. creatorId) or ("place " .. placeId)
		end))
	end

	if hudEditor and hudEditor.AddToggleRow then
		hudEditor.AddToggleRow("watermark", false, function(on)
			watermarkWindow.SetVisible(on)
		end)
		hudEditor.AddToggleRow("session info", false, function(on)
			sessionInfoWindow.SetVisible(on)
		end)
	end
end

local entity = {
	player = LocalPlayer,
	character = LocalPlayer.Character,
}

rootManager:AddConnection(LocalPlayer.CharacterAdded:Connect(function(character)
	entity.character = character
end))

rootManager:AddConnection(LocalPlayer.CharacterRemoving:Connect(function(character)
	if entity.character == character then
		entity.character = nil
	end
end))

local render = {}

function render:Toggle(forceState)
	if not UI or not UI.Root then
		return false
	end
	if forceState == nil then
		UI.toggle()
	else
		UI.Root.Visible = forceState == true
	end
	return UI.Root.Visible
end

function render:Toast(options)
	options = options or {}
	if UI and UI.toast then
		return UI.toast(options.title, options.text, options.duration, options.highlight)
	end
end

function render:Add(definition)
	definition = definition or {}
	local panel = tabs[definition.panel or "other"] or tabs.other
	if not panel or not panel.AddNew then
		error("[phantom] invalid render panel: " .. tostring(definition.panel))
	end

	if definition.type == "toggle" then
		local module = panel.AddNew({
			Name = definition.name,
			Beta = definition.beta,
			New = definition.new,
			Bind = definition.bind,
			Function = definition.callback,
		})
		if definition.default and module.SetEnabled then
			module.SetEnabled(true, true, true)
		end
		return module
	end

	if definition.type == "button" then
		local action
		action = panel.AddNew({
			Name = definition.name,
			Beta = definition.beta,
			New = definition.new,
			Bind = definition.bind,
			Function = function(enabled)
				if not enabled then
					return
				end
				if type(definition.callback) == "function" then
					definition.callback()
				end
				if action and action.SetEnabled then
					action.SetEnabled(false, true, true)
				end
			end,
		})
		return action
	end

	if definition.parent and definition.type == "slider" and definition.parent.CreateSlider then
		return definition.parent.CreateSlider({
			Name = definition.name,
			Min = definition.min,
			Max = definition.max,
			Default = definition.default,
			Round = definition.round,
			Function = definition.callback,
		})
	end

	if definition.parent and definition.type == "dropdown" and definition.parent.CreateDropdown then
		return definition.parent.CreateDropdown({
			Name = definition.name,
			List = definition.list,
			Default = definition.default,
			Function = definition.callback,
		})
	end

	error("[phantom] legacy render facade requires a parent for " .. tostring(definition.type))
end

function render:Destroy()
	if UI and UI.Screen then
		UI.Screen:Destroy()
	end
end

local phantom = {
	version = versionData,
	services = Services,
	logger = logger,
	file = fileApi,
	manager = rootManager,
	module = moduleLoader,
	config = config,
	updater = updater,
	render = render,
	runtime = runtime.runtime,
	UI = UI,
	developerMode = settings.developerMode == true,
	entity = entity,
	loader = {
		ReadScript = function(_, path)
			return fileApi:Read(path)
		end,
		GetIcon = function(_, name)
			return getIcon(name)
		end,
	},
}

local ops = { runtime = runtime.runtime }

function ops:placeKey()
	return activeGameKey()
end

function ops:exec(code)
	return runtime:Run(code)
end

function ops:placeScript()
	local creatorPath = creatorScriptPath()
	if creatorPath and fileApi:IsFile(creatorPath) then
		return fileApi:Read(creatorPath, "") or ""
	end
	return fileApi:Read("games/" .. placeId .. ".lua", "") or ""
end

function ops:creatorScript()
	local creatorPath = creatorScriptPath()
	if not creatorPath then
		return ""
	end
	return fileApi:Read(creatorPath, "") or ""
end

function ops:universalScript()
	return fileApi:Read("games/universal.lua", "") or ""
end

function ops:onExit(id, callback)
	runtime:OnExit(id, callback)
end

function ops:offExit(id)
	runtime:OffExit(id)
end

function ops:track(value)
	return rootManager:Add(value)
end

function ops:lookup(name, prop, value)
	for key, object in next, UI.Registry do
		if key == name and object[prop] == value then
			return object
		end
	end
end

local function copyWithoutRuntimeValues(value)
	if type(value) ~= "table" then
		return value
	end

	local clone = {}
	for key, child in pairs(value) do
		local childType = typeof(child)
		if childType ~= "Instance" and childType ~= "RBXScriptConnection" then
			clone[key] = copyWithoutRuntimeValues(child)
		end
	end
	return clone
end

local function statePath(slot)
	return string.format("configs/%s/%s.json", placeId, slot or "default")
end

local function setProfileSlot(slot)
	profileSlot = tostring(slot or "default")
	if configBar and configBar.SetName then
		configBar.SetName(profileSlot)
	end
	return profileSlot
end

local function shouldPersistObject(object)
	return not (object and object.args and object.args.NoSave == true)
end

local function saveProfile(slot)
	slot = setProfileSlot(slot or profileSlot)
	local data = {}

	for name, object in next, UI.Registry do
		if shouldPersistObject(object) and object.Type == "OptionsButton" then
			data[name] = {
				Enabled = object.API.Enabled,
				Bind = object.API.Bind,
				Type = object.Type,
				Window = object.Window,
			}
		elseif shouldPersistObject(object) and object.Type == "Toggle" then
			data[name] = {
				Enabled = object.API.Enabled,
				Type = object.Type,
				OptionsButton = object.OptionsButton,
				CustomWindow = object.CustomWindow,
			}
		elseif shouldPersistObject(object) and object.Type == "Slider" then
			data[name] = {
				Value = object.API.Value,
				Type = object.Type,
				OptionsButton = object.OptionsButton,
				CustomWindow = object.CustomWindow,
			}
		elseif shouldPersistObject(object) and object.Type == "Dropdown" then
			data[name] = {
				Value = object.API.Value,
				Type = object.Type,
				OptionsButton = object.OptionsButton,
				CustomWindow = object.CustomWindow,
			}
		elseif shouldPersistObject(object) and object.Type == "Textbox" then
			data[name] = {
				Value = object.API.Value,
				Type = object.Type,
				OptionsButton = object.OptionsButton,
				CustomWindow = object.CustomWindow,
			}
		elseif shouldPersistObject(object) and object.Type == "MultiDropdown" then
			data[name] = {
				Values = copyWithoutRuntimeValues(object.API.Values),
				Type = object.Type,
				OptionsButton = object.OptionsButton,
				CustomWindow = object.CustomWindow,
			}
		elseif shouldPersistObject(object) and object.Type == "Textlist" then
			data[name] = {
				Values = copyWithoutRuntimeValues(object.API.Values),
				Type = object.Type,
				OptionsButton = object.OptionsButton,
				CustomWindow = object.CustomWindow,
			}
		elseif shouldPersistObject(object) and object.Type == "CustomWindow" and object.Instance then
			local position = object.Instance.Position
			data[name] = {
				Type = object.Type,
				Position = {
					X = { Scale = position.X.Scale, Offset = position.X.Offset },
					Y = { Scale = position.Y.Scale, Offset = position.Y.Offset },
				},
			}
		end
	end

	if UI.saveTabPositions then
		UI.saveTabPositions()
	end

	local ok, err = fileApi:WriteJson(statePath(slot), data, { force = true })
	if not ok then
		logger:Warn("failed to save profile", slot, err)
	end
	return data
end

local function loadProfile(slot, silent)
	if not env.phantom then
		return {}
	end

	slot = setProfileSlot(slot or profileSlot)
	env.configloaded = false
	local data = fileApi:ReadJson(statePath(slot), nil)
	if type(data) ~= "table" then
		env.configloaded = true
		return {}
	end

	local staleKeys = {}

	for name, state in next, data do
		local prop = state.Type == "OptionsButton" and "Window" or (state.CustomWindow and "CustomWindow" or "OptionsButton")
		local object = ops:lookup(name, prop, state[prop])
		if object and not shouldPersistObject(object) then
			staleKeys[#staleKeys + 1] = name
		elseif object and shouldPersistObject(object) then
			if state.Type == "OptionsButton" then
				if state.Bind and state.Bind ~= "" and object.API.SetBind then
					object.API.SetBind(state.Bind)
				end
				if state.Enabled ~= object.API.Enabled then
					object.API.Toggle()
				end
			elseif state.Type == "Toggle" then
				if state.Enabled ~= object.API.Enabled then
					object.API.Toggle(true)
				end
			elseif state.Type == "Slider" then
				object.API.Set(state.Value, true)
			elseif state.Type == "Dropdown" then
				object.API.SetValue(state.Value)
			elseif state.Type == "Textbox" then
				object.API.Set(state.Value)
			elseif state.Type == "MultiDropdown" then
				for _, valueState in next, state.Values or {} do
					if valueState.Enabled then
						object.API.ToggleValue(valueState.Value)
					end
				end
			elseif state.Type == "Textlist" then
				for _, value in next, state.Values or {} do
					object.API.Add(value)
				end
			elseif state.Type == "CustomWindow" and state.Position then
				object.Instance.Position = UDim2.new(
					state.Position.X.Scale,
					state.Position.X.Offset,
					state.Position.Y.Scale,
					state.Position.Y.Offset
				)
				if object.API and object.API.NormalizePosition then
					object.API.NormalizePosition()
				end
			end
		end
	end

	if #staleKeys > 0 then
		for _, key in ipairs(staleKeys) do
			data[key] = nil
		end
		local ok, err = fileApi:WriteJson(statePath(slot), data, { force = true })
		if not ok then
			logger:Warn("failed to clean profile", slot, err)
		end
	end

	env.configloaded = true
	if not silent then
		render:Toast({
			title = "Profile",
			text = "Loaded " .. slot .. ".json for " .. placeId,
			duration = 3,
		})
	end
	return data
end

function ops:saveConfig(slot)
	return saveProfile(slot)
end

function ops:loadConfig(slot)
	return loadProfile(slot)
end

phantom.ops = ops
phantom.funcs = ops
env.phantom = phantom
env.phantomInstances = env.phantomInstances or {}
table.insert(env.phantomInstances, phantom)
env.configloaded = false

fileApi:Write("cache/lastPlace", placeId, { force = true })
if queueTeleport and not env.phantomTeleportQueued then
	env.phantomTeleportQueued = true
	pcall(queueTeleport, 'loadstring(readfile("Phantom/loader.lua"))()')
end

rootManager:AddConnection(Services.Players.PlayerRemoving:Connect(function(player)
	if player == LocalPlayer then
		pcall(saveProfile, profileSlot)
	end
end))

moduleLoader:RegisterPath("utility", "lib/Utility.lua", { cache = true })
moduleLoader:RegisterPath("prediction", "lib/Prediction.lua", { cache = true })
moduleLoader:RegisterPath("fly", "lib/fly.lua", { cache = true })
moduleLoader:RegisterPath("patcher", "lib/patcher.lua", { cache = false, hotReload = true })
moduleLoader:RegisterPath("game.universal", "games/universal.lua", { cache = false, hotReload = true })
if creatorScriptPath() then
	moduleLoader:RegisterPath("game.creator", creatorScriptPath(), { cache = false, hotReload = true })
end
moduleLoader:RegisterPath("game.place", "games/" .. placeId .. ".lua", { cache = false, hotReload = true })

pcall(function()
	moduleLoader:Load("patcher")
end)

local shuttingDown = false
local hotReloadQueued = false
local relaunchNonce = 0

local function shutdown(reason, options)
	options = options or {}
	if options.preserveRelaunch ~= true then
		relaunchNonce = relaunchNonce + 1
	end

	if shuttingDown then
		return
	end
	shuttingDown = true

	pcall(saveProfile, profileSlot)
	pcall(function()
		runtime:Cleanup()
	end)
	pcall(function()
		for _, object in next, UI.Registry do
			if (object.Type == "OptionsButton" or object.Type == "Toggle") and object.API.Enabled and object.API.Function then
				object.API.Enabled = false
				object.API.Value = false
				task.spawn(object.API.Function)
			end
		end
	end)
	pcall(function()
		for _, tracked in pairs(UI.Tracked or UI.Connections or {}) do
			local disconnect = tracked and (tracked.Disconnect or tracked.Unbind)
			if disconnect then
				disconnect(tracked)
			end
		end
	end)
	pcall(function()
		if UI.Screen then
			UI.Screen:Destroy()
		end
	end)
	pcall(function()
		rootManager:Cleanup()
	end)

	local isCurrentInstance = env.phantom == phantom
	local instances = env.phantomInstances
	if type(instances) == "table" then
		for index = #instances, 1, -1 do
			if instances[index] == phantom then
				table.remove(instances, index)
			end
		end
		if #instances == 0 then
			env.phantomInstances = nil
		end
	end

	logger:Info("shutdown", reason or "manual")
	if isCurrentInstance then
		env.phantom = nil
		env.configloaded = nil
	end
end

phantom.Shutdown = shutdown

local function relaunchMain()
	local source = fileApi:Read("Main.lua")
	if not source or source == "" then
		warn("[phantom] Main.lua missing for reload.")
		return false
	end

	local chunk, err = loadstring(source, "@Phantom/Main.lua")
	if not chunk then
		warn("[phantom] failed to compile Main.lua: " .. tostring(err))
		return false
	end

	local ok, runtimeError = pcall(chunk)
	if not ok then
		warn("[phantom] runtime error: " .. tostring(runtimeError))
		return false
	end

	return true
end

phantom.HotReload = function()
	if shuttingDown or hotReloadQueued then
		return false
	end
	hotReloadQueued = true
	relaunchNonce = relaunchNonce + 1
	local expectedRelaunchNonce = relaunchNonce
	shutdown("hot-reload", { preserveRelaunch = true })
	task.defer(function()
		if relaunchNonce ~= expectedRelaunchNonce then
			return
		end
		relaunchMain()
	end)
	return true
end

local function formatUpdateResult(result)
	if not result then
		return "Unknown updater result."
	end
	if result.status == "up-to-date" then
		return "Already running " .. tostring(result.manifest and result.manifest.version or versionData.full) .. "."
	end
	if result.status == "outdated" then
		return string.format("%d file(s) need refresh.", #(result.plan and result.plan.toDownload or {}))
	end
	if result.status == "updated" then
		return string.format("Updated %d file(s). Reload to apply.", #(result.updated or {}))
	end
	if result.status == "partial" then
		return string.format("Updated %d file(s), %d failed.", #(result.updated or {}), #(result.failures or {}))
	end
	if result.status == "disabled" then
		return "Auto updater is disabled."
	end
	if result.status == "offline-local" then
		return "GitHub unavailable. Using local runtime."
	end
	return tostring(result.error or result.status)
end

do
	local function fixMouse()
		if Services.UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
			Services.UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
	end

	rootManager:AddConnection(Services.UserInputService:GetPropertyChangedSignal("MouseBehavior"):Connect(function()
		if UI.Root.Visible then
			fixMouse()
		end
	end))

	tabs.other.AddNew({
		Name = "gui",
		NoSave = true,
		NoMobileButton = true,
		Bind = "RightShift",
		Function = function()
			if not UI.Root.Visible then
				fixMouse()
			end
			UI.toggle()
		end,
	})

	UI.Root.Visible = false
end

local loaderSettings = tabs.other.AddNew({
	Name = "Loader Settings",
	NoSave = true,
	Function = function() end,
})

loaderSettings.CreateToggle({
	Name = "Auto Update",
	Default = settings.autoUpdate,
	Function = function(on)
		settings.autoUpdate = on
		updater:SetSetting("autoUpdate", on)
	end,
})

loaderSettings.CreateToggle({
	Name = "Developer Mode",
	Default = settings.developerMode,
	Function = function(on)
		settings.developerMode = on
		phantom.developerMode = on
		moduleLoader:SetDeveloperMode(on)
		updater:SetSetting("developerMode", on)
		logger:SetDebug(settings.debugLogs or on)
	end,
})

loaderSettings.CreateToggle({
	Name = "Debug Logs",
	Default = settings.debugLogs,
	Function = function(on)
		settings.debugLogs = on
		updater:SetSetting("debugLogs", on)
		logger:SetDebug(on or settings.developerMode)
	end,
})

local function createAction(name, callback)
	local action
	action = tabs.other.AddNew({
		Name = name,
		NoSave = true,
		Function = function(enabled)
			if not enabled then
				return
			end
			local ok, err = pcall(callback)
			if not ok then
				logger:Warn(name, err)
				render:Toast({
					title = name,
					text = tostring(err),
					duration = 3,
				})
			end
			if action and action.SetEnabled and env.phantom then
				action.SetEnabled(false, true, true)
			end
		end,
	})
	return action
end

if hudEditor then
	createAction("Settings Hub", function()
		hudEditor.Toggle()
	end)
	rootManager:AddConnection(Services.RunService.Heartbeat:Connect(function()
		local saveRequest = hudEditor.SaveRequest
		if saveRequest then
			hudEditor.SaveRequest = nil
			saveProfile(saveRequest)
			if hudEditor.RefreshConfigs then
				hudEditor.RefreshConfigs()
			end
		end

		local loadRequest = hudEditor.LoadRequest
		if loadRequest then
			hudEditor.LoadRequest = nil
			loadProfile(loadRequest, false)
		end

		local deleteRequest = hudEditor.DeleteRequest
		if deleteRequest then
			hudEditor.DeleteRequest = nil
			local targetSlot = tostring(deleteRequest)
			local ok, err = fileApi:Delete(statePath(targetSlot))
			if not ok then
				logger:Warn("failed to delete profile", targetSlot, err)
				render:Toast({
					title = "Profile",
					text = "Failed to delete " .. targetSlot,
					duration = 3,
				})
			else
				if targetSlot == profileSlot then
					setProfileSlot("default")
					loadProfile(profileSlot, true)
				end
				if hudEditor.RefreshConfigs then
					hudEditor.RefreshConfigs()
				end
			end
		end
	end))
end

createAction("Check Updates", function()
	local result = updater:Check()
	render:Toast({
		title = "Updater",
		text = formatUpdateResult(result),
		duration = 3,
	})
end)

createAction("Apply Update", function()
	local result = updater:Apply(nil)
	render:Toast({
		title = "Updater",
		text = formatUpdateResult(result),
		duration = 4,
	})
end)

createAction("Save Profile", function()
	saveProfile(profileSlot)
	render:Toast({
		title = "Profile",
		text = "Saved " .. profileSlot .. ".json for " .. placeId,
		duration = 3,
	})
end)

createAction("Load Profile", function()
	loadProfile(profileSlot, false)
end)

local hotReloadAction
hotReloadAction = tabs.other.AddNew({
	Name = "Hot Reload",
	NoSave = true,
	Function = function(enabled)
		if not enabled then
			return
		end
		if hotReloadAction and hotReloadAction.SetEnabled then
			hotReloadAction.SetEnabled(false, true, true)
		end
		phantom.HotReload()
	end,
})

tabs.other.AddNew({
	Name = "Unload",
	NoSave = true,
	Function = function(enabled)
		if not enabled then
			return
		end
		shutdown("user")
	end,
})

local function loadGameScript(name, path)
	if not fileApi:IsFile(path) then
		return true
	end
	local _, err = moduleLoader:Reload(name)
	if err then
		logger:Warn("failed to load", path, err)
		return false
	end
	return true
end

local universalLoaded = loadGameScript("game.universal", "games/universal.lua")
local creatorLoaded = true
if creatorScriptPath() and creatorScriptPath() ~= ("games/" .. placeId .. ".lua") then
	creatorLoaded = loadGameScript("game.creator", creatorScriptPath())
end
local placeLoaded = loadGameScript("game.place", "games/" .. placeId .. ".lua")

setProfileSlot(profileSlot)
loadProfile(profileSlot, true)

if not universalLoaded or not creatorLoaded or not placeLoaded then
	render:Toast({
		title = "Runtime",
		text = "One or more game scripts failed to load. Check warnings for details.",
		duration = 4,
	})
end

render:Toast({
	title = "Phantom",
	text = string.format("Loaded %s for %s. Press RightShift to toggle the UI.", versionData.full, placeId),
	duration = 3,
})

phantom.ready = true
return phantom
