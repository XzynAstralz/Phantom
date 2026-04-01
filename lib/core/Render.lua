local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local Render = {}
Render.__index = Render

local function clamp(value, minimum, maximum)
	if value < minimum then
		return minimum
	end
	if value > maximum then
		return maximum
	end
	return value
end

local function roundTo(value, decimals)
	local multiplier = 10 ^ (decimals or 0)
	return math.round(value * multiplier) / multiplier
end

local function getGuiParent()
	local ok, parent = pcall(function()
		if get_hidden_gui then
			return get_hidden_gui()
		end
		if gethui then
			return gethui()
		end
		return CoreGui
	end)

	if ok and parent then
		return parent
	end

	return CoreGui
end

local function create(className, props)
	local instance = Instance.new(className)
	for key, value in pairs(props or {}) do
		instance[key] = value
	end
	return instance
end

local function addCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 8)
	corner.Parent = parent
	return corner
end

local function addStroke(parent, color, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Transparency = transparency or 0
	stroke.Thickness = 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

local function addPadding(parent, top, bottom, left, right)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, top or 0)
	padding.PaddingBottom = UDim.new(0, bottom or 0)
	padding.PaddingLeft = UDim.new(0, left or 0)
	padding.PaddingRight = UDim.new(0, right or 0)
	padding.Parent = parent
	return padding
end

local function addListLayout(parent, padding)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, padding or 8)
	layout.Parent = parent
	return layout
end

local function formatNumber(value, decimals)
	if decimals > 0 and value % 1 ~= 0 then
		return string.format("%." .. tostring(decimals) .. "f", value)
	end
	return tostring(math.floor(value + 0.5))
end

function Render.new(options)
	assert(options and options.Signal, "Render.new requires Signal")

	local self = setmetatable({
		Signal = options.Signal,
		logger = options.logger,
		manager = options.manager,
		Theme = {
			Background = Color3.fromRGB(9, 12, 18),
			Surface = Color3.fromRGB(17, 23, 33),
			SurfaceAlt = Color3.fromRGB(24, 31, 44),
			SurfaceSoft = Color3.fromRGB(31, 39, 55),
			Border = Color3.fromRGB(66, 77, 95),
			Text = Color3.fromRGB(241, 235, 226),
			TextDim = Color3.fromRGB(169, 177, 191),
			Muted = Color3.fromRGB(104, 114, 133),
			Danger = Color3.fromRGB(178, 91, 84),
		},
		Accent = options.accent or Color3.fromRGB(239, 155, 73),
		Visible = true,
		Gui = nil,
		Root = nil,
		Main = nil,
		PanelHost = nil,
		Tooltip = nil,
		TooltipLabel = nil,
		ToastHost = nil,
		VersionLabel = nil,
		Panels = {},
		Controls = {},
		Modules = {},
	}, Render)

	self.AccentChanged = options.Signal.new()
	self.RegistryChanged = options.Signal.new()
	self:_buildGui(options.versionText or "local")

	return self
end

function Render:_connect(handle, connection)
	handle.Connections = handle.Connections or {}
	handle.Connections[#handle.Connections + 1] = connection
	return connection
end

function Render:_cleanupHandleConnections(handle)
	if not handle or not handle.Connections then
		return
	end

	for index = #handle.Connections, 1, -1 do
		local connection = handle.Connections[index]
		if connection and connection.Disconnect then
			connection:Disconnect()
		end
		handle.Connections[index] = nil
	end
end

function Render:_buildGui(versionText)
	local gui = create("ScreenGui", {
		Name = "PhantomRender",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 999999,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	gui.Parent = getGuiParent()

	local root = create("Frame", {
		Name = "Root",
		Parent = gui,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	})

	local main = create("Frame", {
		Name = "Main",
		Parent = root,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.92, 0, 0.82, 0),
		BackgroundColor3 = self.Theme.Background,
		BorderSizePixel = 0,
	})
	addCorner(main, 18)
	addStroke(main, self.Theme.Border, 0.2)

	local header = create("Frame", {
		Name = "Header",
		Parent = main,
		BackgroundColor3 = self.Theme.Surface,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 54),
	})
	addCorner(header, 18)
	addStroke(header, self.Theme.Border, 0.35)
	addPadding(header, 0, 0, 18, 18)

	local headerMask = create("Frame", {
		Parent = header,
		BackgroundColor3 = self.Theme.Surface,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 1, -18),
		Size = UDim2.new(1, 0, 0, 18),
	})

	local title = create("TextLabel", {
		Parent = header,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(0.6, 0, 1, 0),
		Font = Enum.Font.GothamBold,
		Text = "Phantom",
		TextColor3 = self.Theme.Text,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	local subtitle = create("TextLabel", {
		Parent = header,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0.35, 0, 1, 0),
		Font = Enum.Font.Gotham,
		Text = "Modular runtime",
		TextColor3 = self.Theme.TextDim,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Right,
	})

	local badge = create("Frame", {
		Name = "VersionBadge",
		Parent = header,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -7),
		Size = UDim2.new(0, 170, 0, 24),
		BackgroundColor3 = self.Theme.SurfaceSoft,
		BorderSizePixel = 0,
	})
	addCorner(badge, 12)
	addStroke(badge, self.Theme.Border, 0.45)

	local badgeLabel = create("TextLabel", {
		Parent = badge,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamMedium,
		Text = versionText,
		TextColor3 = self.Theme.TextDim,
		TextSize = 11,
	})

	local panelHost = create("ScrollingFrame", {
		Name = "PanelHost",
		Parent = main,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 14, 0, 68),
		Size = UDim2.new(1, -28, 1, -84),
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 4,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		HorizontalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
	})

	local panelList = Instance.new("UIListLayout")
	panelList.FillDirection = Enum.FillDirection.Horizontal
	panelList.SortOrder = Enum.SortOrder.LayoutOrder
	panelList.Padding = UDim.new(0, 12)
	panelList.Parent = panelHost

	local toastHost = create("Frame", {
		Parent = root,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -18, 0, 18),
		Size = UDim2.new(0, 320, 1, -36),
		BackgroundTransparency = 1,
	})
	local toastLayout = addListLayout(toastHost, 10)
	toastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right

	local tooltip = create("Frame", {
		Parent = root,
		Visible = false,
		BackgroundColor3 = self.Theme.Surface,
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(0, 0, 0, 0),
		ZIndex = 50,
	})
	addCorner(tooltip, 10)
	addStroke(tooltip, self.Theme.Border, 0.2)
	addPadding(tooltip, 8, 8, 10, 10)

	local tooltipLabel = create("TextLabel", {
		Parent = tooltip,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY,
		Font = Enum.Font.Gotham,
		Text = "",
		TextColor3 = self.Theme.Text,
		TextSize = 12,
		TextWrapped = true,
		ZIndex = 51,
	})

	self.Gui = gui
	self.Root = root
	self.Main = main
	self.PanelHost = panelHost
	self.ToastHost = toastHost
	self.Tooltip = tooltip
	self.TooltipLabel = tooltipLabel
	self.VersionLabel = badgeLabel

	local tooltipConnection = UserInputService.InputChanged:Connect(function(input)
		if not self.Tooltip.Visible then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement then
			return
		end
		self.Tooltip.Position = UDim2.new(0, input.Position.X + 14, 0, input.Position.Y + 10)
	end)

	if self.manager then
		self.manager:AddInstance(gui)
		self.manager:AddConnection(tooltipConnection)
	end
end

function Render:SetVersion(text)
	if self.VersionLabel then
		self.VersionLabel.Text = tostring(text or "local")
	end
end

function Render:SetAccent(color)
	self.Accent = color
	self.AccentChanged:Fire(color)
end

function Render:GetAccentColor()
	return self.Accent
end

function Render:ShowTooltip(text)
	if not text or text == "" then
		return
	end
	self.TooltipLabel.Text = text
	self.Tooltip.Visible = true
	local mouse = UserInputService:GetMouseLocation()
	self.Tooltip.Position = UDim2.new(0, mouse.X + 14, 0, mouse.Y + 10)
end

function Render:HideTooltip()
	self.Tooltip.Visible = false
	self.TooltipLabel.Text = ""
end

function Render:_bindTooltip(handle, guiObject, text)
	if not text or text == "" then
		return
	end

	self:_connect(handle, guiObject.MouseEnter:Connect(function()
		self:ShowTooltip(text)
	end))
	self:_connect(handle, guiObject.MouseLeave:Connect(function()
		self:HideTooltip()
	end))
end

function Render:Toggle(forceState)
	if forceState == nil then
		self.Visible = not self.Visible
	else
		self.Visible = forceState == true
	end
	if self.Main then
		self.Main.Visible = self.Visible
	end
	return self.Visible
end

function Render:Toast(options)
	options = options or {}
	local toast = create("Frame", {
		Parent = self.ToastHost,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundColor3 = self.Theme.Surface,
		BorderSizePixel = 0,
	})
	addCorner(toast, 12)
	addStroke(toast, self.Theme.Border, 0.15)
	addPadding(toast, 10, 10, 12, 12)

	local list = addListLayout(toast, 4)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Left

	local title = create("TextLabel", {
		Parent = toast,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		Font = Enum.Font.GothamBold,
		Text = tostring(options.title or "Notification"),
		TextColor3 = self.Theme.Text,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
	})

	local body = create("TextLabel", {
		Parent = toast,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		Font = Enum.Font.Gotham,
		Text = tostring(options.text or ""),
		TextColor3 = self.Theme.TextDim,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
	})

	local accentBar = create("Frame", {
		Parent = toast,
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(0, 4, 1, 0),
		BackgroundColor3 = self.Accent,
		BorderSizePixel = 0,
		ZIndex = 2,
	})
	addCorner(accentBar, 12)

	local handle = { Key = tostring(math.random()) .. "toast", Frame = toast, Connections = {} }
	self:_connect(handle, self.AccentChanged:Connect(function(color)
		accentBar.BackgroundColor3 = color
	end))

	task.delay(tonumber(options.duration) or 3, function()
		self:_cleanupHandleConnections(handle)
		if toast.Parent then
			toast:Destroy()
		end
	end)

	return toast
end

function Render:CreatePanel(id, title, order)
	if self.Panels[id] then
		return self.Panels[id]
	end

	local frame = create("Frame", {
		Name = id .. "Panel",
		Parent = self.PanelHost,
		BackgroundColor3 = self.Theme.Surface,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 232, 1, 0),
		LayoutOrder = order or 0,
	})
	addCorner(frame, 14)
	addStroke(frame, self.Theme.Border, 0.25)

	local header = create("TextLabel", {
		Parent = frame,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 14, 0, 12),
		Size = UDim2.new(1, -28, 0, 18),
		Font = Enum.Font.GothamBold,
		Text = title,
		TextColor3 = self.Theme.Text,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	local divider = create("Frame", {
		Parent = frame,
		BackgroundColor3 = self.Theme.Border,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 14, 0, 38),
		Size = UDim2.new(1, -28, 0, 1),
	})

	local body = create("ScrollingFrame", {
		Parent = frame,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 12, 0, 48),
		Size = UDim2.new(1, -24, 1, -60),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3,
	})

	local list = addListLayout(body, 8)
	addPadding(body, 2, 8, 2, 6)

	local panel = {
		Id = id,
		Title = title,
		Frame = frame,
		Body = body,
		List = list,
	}

	self.Panels[id] = panel
	return panel
end

function Render:_registerHandle(handle)
	self.Controls[handle.Key] = handle
	if handle.Type == "module" then
		self.Modules[handle.Key] = handle
	end
	self.RegistryChanged:Fire(handle.Key, handle)
	return handle
end

function Render:_destroyHandle(handle)
	if not handle then
		return
	end

	if handle.Children then
		for index = #handle.Children, 1, -1 do
			local childKey = handle.Children[index]
			self:_destroyHandle(self.Controls[childKey])
			handle.Children[index] = nil
		end
	end

	self:_cleanupHandleConnections(handle)
	self.Controls[handle.Key] = nil
	self.Modules[handle.Key] = nil

	if handle.Frame and handle.Frame.Parent then
		handle.Frame:Destroy()
	end

	self.RegistryChanged:Fire(handle.Key, nil)
end

function Render:Remove(key)
	self:_destroyHandle(type(key) == "table" and key or self.Controls[key])
end

function Render:CreateModule(definition)
	local panel = self:CreatePanel(definition.panel or "system", definition.panelTitle or (definition.panel or "SYSTEM"):upper(), definition.order)
	local key = definition.key or ((definition.panel or "system") .. "/" .. tostring(definition.name))
	if self.Modules[key] then
		return self.Modules[key]
	end

	local frame = create("Frame", {
		Parent = panel.Body,
		BackgroundColor3 = self.Theme.SurfaceAlt,
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, -4, 0, 0),
	})
	addCorner(frame, 12)
	local stroke = addStroke(frame, self.Theme.Border, 0.25)
	addPadding(frame, 8, 10, 10, 10)

	local header = create("Frame", {
		Parent = frame,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 26),
	})

	local title = create("TextLabel", {
		Parent = header,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -74, 1, 0),
		Font = Enum.Font.GothamBold,
		Text = definition.beta and (tostring(definition.name) .. "  beta") or tostring(definition.name),
		TextColor3 = self.Theme.Text,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	local toggle = create("TextButton", {
		Parent = header,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 66, 1, 0),
		BackgroundColor3 = self.Theme.Surface,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		Text = "OFF",
		TextColor3 = self.Theme.Text,
	})
	addCorner(toggle, 10)

	local content = create("Frame", {
		Parent = frame,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.new(0, 0, 0, 34),
		Size = UDim2.new(1, 0, 0, 0),
	})
	local contentList = addListLayout(content, 6)

	local handle = {
		Type = "module",
		Key = key,
		Name = tostring(definition.name),
		Panel = definition.panel or "system",
		Frame = frame,
		Header = header,
		Content = content,
		Children = {},
		Connections = {},
		Enabled = definition.default == true,
	}

	local function updateVisual()
		toggle.Text = handle.Enabled and "ON" or "OFF"
		toggle.BackgroundColor3 = handle.Enabled and self.Accent or self.Theme.Surface
		stroke.Color = handle.Enabled and self.Accent or self.Theme.Border
	end

	local function setEnabled(value, silent)
		if value == nil then
			value = not handle.Enabled
		end
		handle.Enabled = value == true
		updateVisual()
		if not silent and type(definition.callback) == "function" then
			local ok, err = pcall(definition.callback, handle.Enabled)
			if not ok and self.logger then
				self.logger:Warn("module callback failed", handle.Name, err)
			end
		end
		return handle.Enabled
	end

	handle.SetEnabled = function(value, silent)
		return setEnabled(value, silent)
	end
	handle.Toggle = function(value, silent)
		if type(value) == "table" then
			value = nil
		end
		return setEnabled(value, silent)
	end
	handle.Add = function(controlDefinition)
		controlDefinition = controlDefinition or {}
		controlDefinition.parent = content
		controlDefinition.scopeKey = key
		local child = self:Add(controlDefinition)
		if child then
			handle.Children[#handle.Children + 1] = child.Key
		end
		return child
	end
	handle.Destroy = function()
		self:_destroyHandle(handle)
	end

	self:_bindTooltip(handle, header, definition.tooltip)
	self:_bindTooltip(handle, toggle, definition.tooltip)
	self:_connect(handle, toggle.MouseButton1Click:Connect(function()
		setEnabled(nil, false)
	end))
	self:_connect(handle, self.AccentChanged:Connect(function()
		updateVisual()
	end))

	updateVisual()
	return self:_registerHandle(handle)
end

function Render:_resolveParent(definition)
	if definition.parent then
		return definition.parent
	end
	local panel = self:CreatePanel(definition.panel or "system", definition.panelTitle or (definition.panel or "SYSTEM"):upper(), definition.order)
	return panel.Body
end

function Render:_attachToModule(definition, handle)
	local parentModule = definition.scopeKey and self.Modules[definition.scopeKey]
	if parentModule then
		parentModule.Children[#parentModule.Children + 1] = handle.Key
	end
end

function Render:_createToggle(definition, key)
	local parent = self:_resolveParent(definition)
	local frame = create("Frame", {
		Parent = parent,
		BackgroundColor3 = self.Theme.SurfaceAlt,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -4, 0, 32),
	})
	addCorner(frame, 10)
	addStroke(frame, self.Theme.Border, 0.35)
	addPadding(frame, 0, 0, 10, 8)

	local title = create("TextLabel", {
		Parent = frame,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -74, 1, 0),
		Font = Enum.Font.GothamMedium,
		Text = tostring(definition.name),
		TextColor3 = self.Theme.TextDim,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	local toggle = create("TextButton", {
		Parent = frame,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 0.5, 0),
		Size = UDim2.new(0, 54, 0, 22),
		BackgroundColor3 = self.Theme.Surface,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		Text = "OFF",
		TextColor3 = self.Theme.Text,
	})
	addCorner(toggle, 11)

	local handle = {
		Type = "toggle",
		Key = key,
		Name = tostring(definition.name),
		Frame = frame,
		Connections = {},
		Enabled = definition.default == true,
	}

	local function updateVisual()
		toggle.Text = handle.Enabled and "ON" or "OFF"
		toggle.BackgroundColor3 = handle.Enabled and self.Accent or self.Theme.Surface
	end

	local function setEnabled(value, silent)
		if value == nil then
			value = not handle.Enabled
		end
		handle.Enabled = value == true
		updateVisual()
		if not silent and type(definition.callback) == "function" then
			local ok, err = pcall(definition.callback, handle.Enabled)
			if not ok and self.logger then
				self.logger:Warn("toggle callback failed", handle.Name, err)
			end
		end
		return handle.Enabled
	end

	handle.SetEnabled = function(value, silent)
		return setEnabled(value, silent)
	end
	handle.Toggle = function(value, silent)
		if type(value) == "table" then
			value = nil
		end
		return setEnabled(value, silent)
	end
	handle.Destroy = function()
		self:_destroyHandle(handle)
	end

	self:_bindTooltip(handle, frame, definition.tooltip)
	self:_connect(handle, toggle.MouseButton1Click:Connect(function()
		setEnabled(nil, false)
	end))
	self:_connect(handle, self.AccentChanged:Connect(function()
		updateVisual()
	end))

	updateVisual()
	self:_attachToModule(definition, handle)
	return self:_registerHandle(handle)
end

function Render:_createButton(definition, key)
	local parent = self:_resolveParent(definition)
	local frame = create("Frame", {
		Parent = parent,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -4, 0, 36),
	})

	local button = create("TextButton", {
		Parent = frame,
		BackgroundColor3 = self.Accent,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamBold,
		Text = tostring(definition.name),
		TextColor3 = Color3.fromRGB(17, 18, 22),
		TextSize = 12,
	})
	addCorner(button, 10)

	local handle = {
		Type = "button",
		Key = key,
		Name = tostring(definition.name),
		Frame = frame,
		Connections = {},
	}

	handle.Press = function()
		if type(definition.callback) == "function" then
			local ok, err = pcall(definition.callback)
			if not ok and self.logger then
				self.logger:Warn("button callback failed", handle.Name, err)
			end
		end
	end
	handle.Destroy = function()
		self:_destroyHandle(handle)
	end

	self:_bindTooltip(handle, button, definition.tooltip)
	self:_connect(handle, button.MouseButton1Click:Connect(function()
		handle.Press()
	end))
	self:_connect(handle, self.AccentChanged:Connect(function(color)
		button.BackgroundColor3 = color
	end))

	self:_attachToModule(definition, handle)
	return self:_registerHandle(handle)
end

function Render:_createSlider(definition, key)
	local parent = self:_resolveParent(definition)
	local minimum = tonumber(definition.min) or 0
	local maximum = tonumber(definition.max) or 100
	local decimals = math.max(tonumber(definition.round) or 0, 0)
	local value = clamp(tonumber(definition.default) or minimum, minimum, maximum)

	local frame = create("Frame", {
		Parent = parent,
		BackgroundColor3 = self.Theme.SurfaceAlt,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -4, 0, 54),
	})
	addCorner(frame, 10)
	addStroke(frame, self.Theme.Border, 0.35)
	addPadding(frame, 8, 8, 10, 10)

	local title = create("TextLabel", {
		Parent = frame,
		BackgroundTransparency = 1,
		Size = UDim2.new(0.6, 0, 0, 14),
		Font = Enum.Font.GothamMedium,
		Text = tostring(definition.name),
		TextColor3 = self.Theme.TextDim,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	local valueLabel = create("TextLabel", {
		Parent = frame,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0.35, 0, 0, 14),
		Font = Enum.Font.GothamBold,
		TextColor3 = self.Theme.Text,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
	})

	local track = create("Frame", {
		Parent = frame,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 14),
		BackgroundColor3 = self.Theme.Surface,
		BorderSizePixel = 0,
	})
	addCorner(track, 7)

	local fill = create("Frame", {
		Parent = track,
		BackgroundColor3 = self.Accent,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 0, 1, 0),
	})
	addCorner(fill, 7)

	local knob = create("Frame", {
		Parent = track,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(0, 14, 0, 14),
		BackgroundColor3 = Color3.fromRGB(250, 245, 236),
		BorderSizePixel = 0,
	})
	addCorner(knob, 7)

	local handle = {
		Type = "slider",
		Key = key,
		Name = tostring(definition.name),
		Frame = frame,
		Connections = {},
		Value = value,
	}

	local dragging = false

	local function updateVisual()
		local alpha = 0
		if maximum > minimum then
			alpha = (handle.Value - minimum) / (maximum - minimum)
		end
		alpha = clamp(alpha, 0, 1)
		fill.Size = UDim2.new(alpha, 0, 1, 0)
		knob.Position = UDim2.new(alpha, 0, 0.5, 0)
		valueLabel.Text = formatNumber(handle.Value, decimals)
	end

	local function setValue(newValue, silent)
		newValue = roundTo(clamp(tonumber(newValue) or minimum, minimum, maximum), decimals)
		handle.Value = newValue
		updateVisual()
		if not silent and type(definition.callback) == "function" then
			local ok, err = pcall(definition.callback, handle.Value)
			if not ok and self.logger then
				self.logger:Warn("slider callback failed", handle.Name, err)
			end
		end
		return handle.Value
	end

	local function updateFromInput(position)
		local relative = position.X - track.AbsolutePosition.X
		local alpha = clamp(relative / math.max(track.AbsoluteSize.X, 1), 0, 1)
		setValue(minimum + ((maximum - minimum) * alpha), false)
	end

	handle.Set = function(newValue, silent)
		return setValue(newValue, silent)
	end
	handle.SetValue = handle.Set
	handle.Destroy = function()
		self:_destroyHandle(handle)
	end

	self:_bindTooltip(handle, frame, definition.tooltip)
	self:_connect(handle, track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			updateFromInput(input.Position)
		end
	end))
	self:_connect(handle, UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end))
	self:_connect(handle, UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			updateFromInput(input.Position)
		end
	end))
	self:_connect(handle, self.AccentChanged:Connect(function(color)
		fill.BackgroundColor3 = color
	end))

	updateVisual()
	self:_attachToModule(definition, handle)
	return self:_registerHandle(handle)
end

function Render:_createDropdown(definition, key)
	local parent = self:_resolveParent(definition)
	local list = type(definition.list) == "table" and definition.list or {}
	local defaultValue = definition.default
	if defaultValue == nil then
		defaultValue = list[1]
	end

	local frame = create("Frame", {
		Parent = parent,
		BackgroundColor3 = self.Theme.SurfaceAlt,
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, -4, 0, 0),
	})
	addCorner(frame, 10)
	local stroke = addStroke(frame, self.Theme.Border, 0.35)
	addPadding(frame, 8, 8, 10, 10)

	local header = create("TextButton", {
		Parent = frame,
		BackgroundColor3 = self.Theme.Surface,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 28),
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextColor3 = self.Theme.Text,
		Text = "",
	})
	addCorner(header, 8)

	local optionHolder = create("Frame", {
		Parent = frame,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.new(0, 0, 0, 34),
		Size = UDim2.new(1, 0, 0, 0),
		Visible = false,
	})
	local optionList = addListLayout(optionHolder, 4)

	local handle = {
		Type = "dropdown",
		Key = key,
		Name = tostring(definition.name),
		Frame = frame,
		Header = header,
		OptionsFrame = optionHolder,
		Connections = {},
		List = list,
		Value = defaultValue,
		Open = false,
		OptionButtons = {},
	}

	local function updateHeader()
		header.Text = string.format("%s  :  %s", tostring(definition.name), tostring(handle.Value or ""))
		stroke.Color = handle.Open and self.Accent or self.Theme.Border
	end

	local function refreshOptions()
		for _, button in ipairs(handle.OptionButtons) do
			if button and button.Parent then
				button:Destroy()
			end
		end
		handle.OptionButtons = {}

		for _, option in ipairs(handle.List) do
			local optionValue = tostring(option)
			local button = create("TextButton", {
				Parent = optionHolder,
				BackgroundColor3 = optionValue == tostring(handle.Value) and self.Accent or self.Theme.Surface,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 26),
				Font = Enum.Font.Gotham,
				Text = optionValue,
				TextColor3 = optionValue == tostring(handle.Value) and Color3.fromRGB(17, 18, 22) or self.Theme.Text,
				TextSize = 12,
			})
			addCorner(button, 8)
			handle.OptionButtons[#handle.OptionButtons + 1] = button
			self:_connect(handle, button.MouseButton1Click:Connect(function()
				handle.SetValue(option, false)
				handle.SetOpen(false)
			end))
		end
	end

	local function setOpen(isOpen)
		handle.Open = isOpen == true
		optionHolder.Visible = handle.Open
		updateHeader()
	end

	local function setValue(newValue, silent)
		handle.Value = newValue
		refreshOptions()
		updateHeader()
		if not silent and type(definition.callback) == "function" then
			local ok, err = pcall(definition.callback, handle.Value)
			if not ok and self.logger then
				self.logger:Warn("dropdown callback failed", handle.Name, err)
			end
		end
		return handle.Value
	end

	handle.SetOpen = function(isOpen)
		setOpen(isOpen)
		return handle.Open
	end
	handle.SetValue = function(newValue, silent)
		return setValue(newValue, silent)
	end
	handle.Refresh = function(newList, selectedValue)
		if type(newList) == "table" then
			handle.List = newList
		end
		if selectedValue ~= nil then
			handle.Value = selectedValue
		elseif handle.List[1] ~= nil and handle.Value == nil then
			handle.Value = handle.List[1]
		end
		refreshOptions()
		updateHeader()
		return handle.List
	end
	handle.Destroy = function()
		self:_destroyHandle(handle)
	end

	self:_bindTooltip(handle, frame, definition.tooltip)
	self:_connect(handle, header.MouseButton1Click:Connect(function()
		setOpen(not handle.Open)
	end))
	self:_connect(handle, self.AccentChanged:Connect(function()
		refreshOptions()
		updateHeader()
	end))

	refreshOptions()
	updateHeader()
	self:_attachToModule(definition, handle)
	return self:_registerHandle(handle)
end

function Render:Add(definition)
	definition = definition or {}
	local key = definition.key or ((definition.scopeKey or definition.panel or "root") .. "::" .. tostring(definition.name or definition.type or "control"))
	if self.Controls[key] then
		return self.Controls[key]
	end

	if definition.type == "toggle" then
		return self:_createToggle(definition, key)
	end
	if definition.type == "button" then
		return self:_createButton(definition, key)
	end
	if definition.type == "slider" then
		return self:_createSlider(definition, key)
	end
	if definition.type == "dropdown" then
		return self:_createDropdown(definition, key)
	end

	error("unsupported control type: " .. tostring(definition.type))
end

function Render:Destroy()
	for key in pairs(self.Controls) do
		self:_destroyHandle(self.Controls[key])
	end
	self:HideTooltip()
	if self.Gui and self.Gui.Parent then
		self.Gui:Destroy()
	end
	self.AccentChanged:Destroy()
	self.RegistryChanged:Destroy()
	self.Gui = nil
	self.Root = nil
	self.Main = nil
	self.PanelHost = nil
	self.Panels = {}
	self.Controls = {}
	self.Modules = {}
end

return Render