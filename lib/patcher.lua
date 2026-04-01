if not identifyexecutor then game:Shutdown() end

local ogRequire = require
local globalFixes = {
    require = function(path)
        if not path then return end

        local ok, result = pcall(ogRequire, path)
        if not ok then
            warn("failed to load module", path:GetFullName() .. ", passing empty table")
            return {}
        end
        return result or {}
    end,
    isnetworkowner = function(obj)
        return (obj.ReceiveAge == 0)
    end
}

local patches
patches = {
    ["nova"] = {
        func = function()
            getconnections = nil
        end,
        badExec = true
    },
    ["argon"] = {
        func = function()
            isnetworkowner = globalFixes.isnetworkowner
            require = globalFixes.require
        end,
        badExec = true
    },
    ["solara"] = {
        func = function()
            require = nil
        end,
        badExec = true
    },
    ["lxzp"] = {
        func = function()
            patches["argon"].func()
            hookmetamethod = nil
        end,
        badExec = true
    },
    ["velocity"] = {
        func = function()
            isnetworkowner = globalFixes.isnetworkowner
            -- patches["argon"].func()
            getcustomasset = function()
                return "rbxassetid://0"
            end
        end,
        badExec = true
    }
}
patches["sonar"] = patches["velocity"]

local identity = string.lower(identifyexecutor())
for i, v in patches do
    if string.match(identity, i) then
        execName = i
        isBad = v.badExec
        v.func()
    end
end
