local LegacyUI = {}
LegacyUI.__index = LegacyUI

local PANEL_DEFINITIONS = {
	{ registry = "combatPanel", id = "combat", title = "Combat", order = 1 },
	{ registry = "blatantPanel", id = "blatant", title = "Blatant", order = 2 },
	{ registry = "renderPanel", id = "render", title = "Render", order = 3 },
	{ registry = "worldPanel", id = "world", title = "World", order = 4 },
	{ registry = "miscPanel", id = "misc", title = "Misc", order = 5 },
	{ registry = "utillityPanel", id = "utility", title = "Utility", order = 6 },
	{ registry = "inventoryPanel", id = "inventory", title = "Inventory", order = 7 },
	{ registry = "otherPanel", id = "other", title = "System", order = 8 },
	{ registry = "other", id = "other", title = "System", order = 8 },
}

local function buildPanelMap()
	local map = {}
	for _, item in ipairs(PANEL_DEFINITIONS) do
		map[item.registry] = item
	end
	return map
end

local PANEL_MAP = buildPanelMap()

function LegacyUI.new(options)
	local self = setmetatable({
		render = options.render,
		logger = options.logger,
		onChanged = options.onChanged,
		_applying = false,
		_modules = {},
		_aliases = {},
		controls = {},
	}, LegacyUI)

	self.ColorUpdate = self.render.AccentChanged
	self.ButtonUpdate = self.render.RegistryChanged
	self.toast = function(title, message, duration)
		return self.render:Toast({
			title = title,
			text = message,
			duration = duration,
		})
	end

	self.kit = {
		activeColor = function()
			return self.render:GetAccentColor()
		end,
		deregister = function(_, name)
			self:Deregister(name)
		end,
	}

	self.Registry = {}
	for _, panel in ipairs(PANEL_DEFINITIONS) do
		self.render:CreatePanel(panel.id, panel.title, panel.order)
		self.Registry[panel.registry] = {
			API = {
				CreateOptionsButton = function(configuration)
					return self:CreateOptionsButton(panel, configuration)
				end,
			},
		}
	end

	return self
end

function LegacyUI:_markChanged()
	if self._applying or type(self.onChanged) ~= "function" then
		return
	end
	self.onChanged(self:Serialize())
end

function LegacyUI:_trackModule(moduleHandle)
	self._modules[moduleHandle.Key] = moduleHandle
	self._aliases[moduleHandle.Name .. "Module"] = moduleHandle
	self._aliases[moduleHandle.Name] = moduleHandle
	return moduleHandle
end

function LegacyUI:_trackControl(moduleHandle, controlHandle)
	moduleHandle._controlsByName[controlHandle.Name] = controlHandle
	moduleHandle._controls[#moduleHandle._controls + 1] = controlHandle
	self.controls[controlHandle.Key] = controlHandle
	return controlHandle
end

function LegacyUI:_removeModule(moduleHandle)
	if not moduleHandle then
		return
	end

	for _, control in ipairs(moduleHandle._controls or {}) do
		self.controls[control.Key] = nil
	end

	self._modules[moduleHandle.Key] = nil
	self._aliases[moduleHandle.Name] = nil
	self._aliases[moduleHandle.Name .. "Module"] = nil
	self.render:Remove(moduleHandle.Key)
end

function LegacyUI:Deregister(name)
	local moduleHandle = self._aliases[name] or self._modules[name]
	if not moduleHandle and type(name) == "string" and name:sub(-6) == "Module" then
		moduleHandle = self._aliases[name:sub(1, -7)]
	end
	if moduleHandle then
		self:_removeModule(moduleHandle)
	end
end

function LegacyUI:ClearModules()
	local keys = {}
	for key in pairs(self._modules) do
		keys[#keys + 1] = key
	end
	table.sort(keys)
	for _, key in ipairs(keys) do
		self:_removeModule(self._modules[key])
	end
end

function LegacyUI:CreateOptionsButton(panel, configuration)
	configuration = configuration or {}
	local moduleKey = panel.id .. "/" .. tostring(configuration.Name)
	if self._modules[moduleKey] then
		return self._modules[moduleKey]
	end

	local handle
	local renderModule = self.render:CreateModule({
		panel = panel.id,
		panelTitle = panel.title,
		order = panel.order,
		name = configuration.Name,
		key = moduleKey,
		default = configuration.Default == true,
		beta = configuration.Beta == true,
		tooltip = configuration.Tooltip or configuration.HoverText,
		callback = function(enabled)
			handle.Enabled = enabled
			if type(configuration.Function) == "function" then
				configuration.Function(enabled)
			end
			self:_markChanged()
		end,
	})

	handle = {
		Type = "OptionsButton",
		Name = tostring(configuration.Name),
		Key = moduleKey,
		Panel = panel.id,
		Enabled = renderModule.Enabled,
		Bind = configuration.Bind,
		_renderHandle = renderModule,
		_controls = {},
		_controlsByName = {},
	}

	handle.Toggle = function(value, silent)
		local result = renderModule.Toggle(value, silent)
		handle.Enabled = result
		return result
	end
	handle.SetEnabled = handle.Toggle
	handle.SetBind = function(bind)
		handle.Bind = bind
		return bind
	end
	handle.CreateToggle = function(childConfiguration)
		return self:_createToggle(handle, childConfiguration)
	end
	handle.CreateSlider = function(childConfiguration)
		return self:_createSlider(handle, childConfiguration)
	end
	handle.CreateDropdown = function(childConfiguration)
		return self:_createDropdown(handle, childConfiguration)
	end
	handle.CreateButton = function(childConfiguration)
		return self:_createButton(handle, childConfiguration)
	end
	handle.Destroy = function()
		self:_removeModule(handle)
	end

	return self:_trackModule(handle)
end

function LegacyUI:_createToggle(moduleHandle, configuration)
	configuration = configuration or {}
	local controlKey = moduleHandle.Key .. "/toggle/" .. tostring(configuration.Name)
	local handle
	local renderHandle = self.render:Add({
		type = "toggle",
		name = configuration.Name,
		key = controlKey,
		parent = moduleHandle._renderHandle.Content,
		scopeKey = moduleHandle.Key,
		default = configuration.Default == true,
		tooltip = configuration.Tooltip or configuration.HoverText,
		callback = function(enabled)
			handle.Enabled = enabled
			if type(configuration.Function) == "function" then
				configuration.Function(enabled)
			end
			self:_markChanged()
		end,
	})

	handle = {
		Type = "Toggle",
		Name = tostring(configuration.Name),
		Key = controlKey,
		Enabled = renderHandle.Enabled,
		_renderHandle = renderHandle,
	}

	handle.Toggle = function(value, silent)
		local result = renderHandle.Toggle(value, silent)
		handle.Enabled = result
		return result
	end
	handle.SetEnabled = handle.Toggle
	handle.Destroy = function()
		self.render:Remove(controlKey)
		self.controls[controlKey] = nil
		moduleHandle._controlsByName[handle.Name] = nil
	end

	return self:_trackControl(moduleHandle, handle)
end

function LegacyUI:_createSlider(moduleHandle, configuration)
	configuration = configuration or {}
	local controlKey = moduleHandle.Key .. "/slider/" .. tostring(configuration.Name)
	local handle
	local renderHandle = self.render:Add({
		type = "slider",
		name = configuration.Name,
		key = controlKey,
		parent = moduleHandle._renderHandle.Content,
		scopeKey = moduleHandle.Key,
		min = configuration.Min,
		max = configuration.Max,
		round = configuration.Round,
		default = configuration.Default,
		tooltip = configuration.Tooltip or configuration.HoverText,
		callback = function(value)
			handle.Value = value
			if type(configuration.Function) == "function" then
				configuration.Function(value)
			end
			self:_markChanged()
		end,
	})

	handle = {
		Type = "Slider",
		Name = tostring(configuration.Name),
		Key = controlKey,
		Value = renderHandle.Value,
		_renderHandle = renderHandle,
	}

	handle.Set = function(value, silent)
		local result = renderHandle.Set(value, silent)
		handle.Value = result
		return result
	end
	handle.SetValue = handle.Set
	handle.Destroy = function()
		self.render:Remove(controlKey)
		self.controls[controlKey] = nil
		moduleHandle._controlsByName[handle.Name] = nil
	end

	return self:_trackControl(moduleHandle, handle)
end

function LegacyUI:_createDropdown(moduleHandle, configuration)
	configuration = configuration or {}
	local controlKey = moduleHandle.Key .. "/dropdown/" .. tostring(configuration.Name)
	local handle
	local renderHandle = self.render:Add({
		type = "dropdown",
		name = configuration.Name,
		key = controlKey,
		parent = moduleHandle._renderHandle.Content,
		scopeKey = moduleHandle.Key,
		list = configuration.List,
		default = configuration.Default,
		tooltip = configuration.Tooltip or configuration.HoverText,
		callback = function(value)
			handle.Value = value
			if type(configuration.Function) == "function" then
				configuration.Function(value)
			end
			self:_markChanged()
		end,
	})

	handle = {
		Type = "Dropdown",
		Name = tostring(configuration.Name),
		Key = controlKey,
		Value = renderHandle.Value,
		List = configuration.List or {},
		_renderHandle = renderHandle,
	}

	handle.SetValue = function(value, silent)
		local result = renderHandle.SetValue(value, silent)
		handle.Value = result
		return result
	end
	handle.Refresh = function(newList, selectedValue)
		handle.List = renderHandle.Refresh(newList, selectedValue)
		handle.Value = renderHandle.Value
		return handle.List
	end
	handle.Destroy = function()
		self.render:Remove(controlKey)
		self.controls[controlKey] = nil
		moduleHandle._controlsByName[handle.Name] = nil
	end

	return self:_trackControl(moduleHandle, handle)
end

function LegacyUI:_createButton(moduleHandle, configuration)
	configuration = configuration or {}
	local controlKey = moduleHandle.Key .. "/button/" .. tostring(configuration.Name)
	local renderHandle = self.render:Add({
		type = "button",
		name = configuration.Name,
		key = controlKey,
		parent = moduleHandle._renderHandle.Content,
		scopeKey = moduleHandle.Key,
		tooltip = configuration.Tooltip or configuration.HoverText,
		callback = function()
			if type(configuration.Function) == "function" then
				configuration.Function(true)
			end
			self:_markChanged()
		end,
	})

	local handle = {
		Type = "Button",
		Name = tostring(configuration.Name),
		Key = controlKey,
		_renderHandle = renderHandle,
	}

	handle.Press = function()
		renderHandle.Press()
	end
	handle.Destroy = function()
		self.render:Remove(controlKey)
		self.controls[controlKey] = nil
		moduleHandle._controlsByName[handle.Name] = nil
	end

	return self:_trackControl(moduleHandle, handle)
end

function LegacyUI:Serialize()
	local snapshot = {}
	for key, moduleHandle in pairs(self._modules) do
		local controls = {}
		for controlName, controlHandle in pairs(moduleHandle._controlsByName) do
			if controlHandle.Type == "Toggle" then
				controls[controlName] = { type = "toggle", value = controlHandle.Enabled }
			elseif controlHandle.Type == "Slider" then
				controls[controlName] = { type = "slider", value = controlHandle.Value }
			elseif controlHandle.Type == "Dropdown" then
				controls[controlName] = { type = "dropdown", value = controlHandle.Value }
			end
		end

		snapshot[key] = {
			name = moduleHandle.Name,
			panel = moduleHandle.Panel,
			enabled = moduleHandle.Enabled,
			controls = controls,
		}
	end
	return snapshot
end

function LegacyUI:ApplyProfile(snapshot)
	self._applying = true

	for key, moduleState in pairs(snapshot or {}) do
		local moduleHandle = self._modules[key] or self._aliases[moduleState.name .. "Module"]
		if moduleHandle then
			if moduleState.enabled ~= nil then
				moduleHandle.Toggle(moduleState.enabled, false)
			end

			for controlName, controlState in pairs(moduleState.controls or {}) do
				local controlHandle = moduleHandle._controlsByName[controlName]
				if controlHandle then
					if controlHandle.Type == "Toggle" then
						controlHandle.Toggle(controlState.value, false)
					elseif controlHandle.Type == "Slider" then
						controlHandle.Set(controlState.value, false)
					elseif controlHandle.Type == "Dropdown" then
						controlHandle.SetValue(controlState.value, false)
					end
				end
			end
		end
	end

	self._applying = false
end

function LegacyUI:GetPanel(registryName)
	local panel = PANEL_MAP[registryName]
	if not panel then
		return nil
	end
	return self.Registry[registryName]
end

return LegacyUI