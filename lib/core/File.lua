local HttpService = game:GetService("HttpService")

local File = {}
File.__index = File

local function normalizeSlashes(path)
	path = tostring(path or "")
	path = path:gsub("\\", "/")
	path = path:gsub("^%./", "")
	path = path:gsub("^/+", "")
	path = path:gsub("/+", "/")
	path = path:gsub("/$", "")
	return path
end

local function trimRoot(path, rootName)
	local normalized = normalizeSlashes(path)
	local rootLower = string.lower(rootName)
	local normalizedLower = string.lower(normalized)
	local rootPrefix = rootLower .. "/"

	if normalizedLower == rootLower then
		return ""
	end

	if normalizedLower:sub(1, #rootPrefix) == rootPrefix then
		return normalized:sub(#rootPrefix + 1)
	end

	return normalized
end

local function startsWith(value, prefix)
	return value:sub(1, #prefix) == prefix
end

function File.new(rootName, logger)
	return setmetatable({
		rootName = rootName or "Phantom",
		logger = logger,
	}, File)
end

function File:GetRoot()
	return self.rootName
end

function File:Relative(path)
	return trimRoot(path, self.rootName)
end

function File:Resolve(path)
	local relative = self:Relative(path)
	if relative == "" then
		return self.rootName
	end
	return self.rootName .. "/" .. relative
end

function File:IsProtected(path)
	local relative = self:Relative(path)
	return startsWith(relative, "config/") or startsWith(relative, "configs/")
end

function File:Exists(path)
	local fullPath = self:Resolve(path)
	return isfile(fullPath) or isfolder(fullPath)
end

function File:IsFile(path)
	return isfile(self:Resolve(path))
end

function File:IsFolder(path)
	return isfolder(self:Resolve(path))
end

function File:MakeFolder(path)
	local relative = self:Relative(path)
	local current = self.rootName

	if not isfolder(current) then
		local ok, err = pcall(makefolder, current)
		if not ok and self.logger then
			self.logger:Warn("failed to create folder", current, err)
		end
	end

	if relative == "" then
		return true
	end

	for segment in relative:gmatch("[^/]+") do
		current = current .. "/" .. segment
		if not isfolder(current) then
			local ok, err = pcall(makefolder, current)
			if not ok then
				if self.logger then
					self.logger:Warn("failed to create folder", current, err)
				end
				return false, err
			end
		end
	end

	return true
end

function File:_ensureParent(path)
	local relative = self:Relative(path)
	local parent = relative:match("^(.*)/[^/]+$")
	if parent and parent ~= "" then
		return self:MakeFolder(parent)
	end
	return self:MakeFolder("")
end

function File:Read(path, defaultValue)
	local fullPath = self:Resolve(path)
	if not isfile(fullPath) then
		return defaultValue
	end

	local ok, contents = pcall(readfile, fullPath)
	if ok then
		return contents
	end

	if self.logger then
		self.logger:Warn("failed to read file", fullPath, contents)
	end

	return defaultValue
end

function File:Write(path, data, options)
	options = options or {}
	local fullPath = self:Resolve(path)

	if self:IsProtected(path) and isfile(fullPath) and not options.force then
		return false, "protected path"
	end

	local ok, err = self:_ensureParent(path)
	if not ok then
		return false, err
	end

	ok, err = pcall(writefile, fullPath, tostring(data or ""))
	if not ok and self.logger then
		self.logger:Warn("failed to write file", fullPath, err)
	end

	return ok, err
end

function File:Append(path, data, options)
	options = options or {}
	local fullPath = self:Resolve(path)

	if self:IsProtected(path) and isfile(fullPath) and not options.force then
		return false, "protected path"
	end

	local ok, err = self:_ensureParent(path)
	if not ok then
		return false, err
	end

	if appendfile then
		ok, err = pcall(appendfile, fullPath, tostring(data or ""))
	else
		local existing = self:Read(path, "")
		ok, err = self:Write(path, existing .. tostring(data or ""), { force = true })
	end

	if not ok and self.logger then
		self.logger:Warn("failed to append file", fullPath, err)
	end

	return ok, err
end

function File:Delete(path)
	local fullPath = self:Resolve(path)
	if isfile(fullPath) and delfile then
		return pcall(delfile, fullPath)
	end
	if isfolder(fullPath) and delfolder then
		return pcall(delfolder, fullPath)
	end
	return false, "unsupported delete operation"
end

function File:ListFiles(path)
	local fullPath = self:Resolve(path)
	if not isfolder(fullPath) then
		return {}
	end

	local ok, items = pcall(listfiles, fullPath)
	if not ok or type(items) ~= "table" then
		if self.logger then
			self.logger:Warn("failed to list files", fullPath, items)
		end
		return {}
	end

	local normalized = {}
	for _, item in ipairs(items) do
		normalized[#normalized + 1] = normalizeSlashes(item)
	end

	table.sort(normalized)
	return normalized
end

function File:ReadJson(path, defaultValue)
	local contents = self:Read(path)
	if not contents or contents == "" then
		return defaultValue
	end

	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(contents)
	end)

	if ok then
		return decoded
	end

	if self.logger then
		self.logger:Warn("failed to decode json", path, decoded)
	end

	return defaultValue
end

function File:WriteJson(path, data, options)
	local ok, encoded = pcall(function()
		return HttpService:JSONEncode(data)
	end)
	if not ok then
		if self.logger then
			self.logger:Warn("failed to encode json", path, encoded)
		end
		return false, encoded
	end

	return self:Write(path, encoded, options)
end

function File:EnsureRuntimeFolders()
	self:MakeFolder("")
	self:MakeFolder("assets")
	self:MakeFolder("assets/icons")
	self:MakeFolder("cache")
	self:MakeFolder("config")
	self:MakeFolder("configs")
	self:MakeFolder("games")
	self:MakeFolder("lib")
	self:MakeFolder("lib/core")
	self:MakeFolder("scripts")
end

return File