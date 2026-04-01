local HttpService = game:GetService("HttpService")

local Http = {}
Http.__index = Http

local function getRequestFunction()
	return request
		or http_request
		or (syn and syn.request)
		or (http and http.request)
		or (fluxus and fluxus.request)
end

function Http.new(logger)
	return setmetatable({
		logger = logger,
	}, Http)
end

function Http:Request(options)
	local requestFunction = getRequestFunction()
	if requestFunction then
		local ok, response = pcall(requestFunction, {
			Url = options.url,
			Method = options.method or "GET",
			Headers = options.headers or {},
			Body = options.body,
		})

		if ok and response and tonumber(response.StatusCode) and response.StatusCode >= 200 and response.StatusCode < 300 then
			return true, response.Body, response
		end

		return false, response and response.Body or response, response
	end

	if (options.method or "GET") ~= "GET" then
		return false, "custom request function unavailable"
	end

	local ok, body = pcall(function()
		if game.HttpGet then
			return game:HttpGet(options.url, true)
		end
		return HttpService:GetAsync(options.url, true)
	end)

	if ok then
		return true, body, { StatusCode = 200, Body = body }
	end

	return false, body, { StatusCode = 0, Body = body }
end

function Http:Get(url, headers)
	return self:Request({
		url = url,
		method = "GET",
		headers = headers,
	})
end

function Http:GetJson(url, headers)
	local ok, body, response = self:Get(url, headers)
	if not ok then
		return false, body, response
	end

	local success, decoded = pcall(function()
		return HttpService:JSONDecode(body)
	end)

	if not success then
		if self.logger then
			self.logger:Warn("failed to decode http json", url, decoded)
		end
		return false, decoded, response
	end

	return true, decoded, response
end

return Http