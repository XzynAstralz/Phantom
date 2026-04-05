local e = getfenv and getfenv() or _G
local g = e.getgenv
local rv = type(g) == "function" and select(2, pcall(g)) or nil
if type(rv) ~= "table" then
    rv = type(e) == "table" and e or {}
end

local PV = "weao-v1"

if rv.__phantomPatcherDone == true
    and type(rv.phantomExecutorInfo) == "table"
    and rv.phantomExecutorInfo.patcherVersion == PV
then
    return rv.phantomExecutorInfo
end

local n = {"gethiddenproperty", "getrawmetatable", "hookfunction", "hookmetamethod", "require", "setreadonly"}
local hs = game:GetService("HttpService")

local function badReq(msg)
    return msg:find("cannot find executable", 1, true)
        or msg:find("function is nil", 1, true)
        or msg:find("attempt to call a nil value", 1, true)
        or msg:find("not implemented", 1, true)
end

local function rq()
    local s, h, f = rv.syn or e.syn, rv.http or e.http, rv.fluxus or e.fluxus
    return rv.request
        or rv.http_request
        or e.request
        or e.http_request
        or (s and s.request)
        or (h and h.request)
        or (f and f.request)
        or (_G and _G.request)
        or (_G and _G.http_request)
end

local function getJson(url)
    local r = rq()
    if type(r) ~= "function" then
        return nil, "request function unavailable"
    end

    local ok, res = pcall(r, {
        Url = url,
        Method = "GET",
        Headers = {
            ["User-Agent"] = "WEAO-3PService",
        },
    })
    if not ok or type(res) ~= "table" then
        return nil, "request failed"
    end

    local sc = tonumber(res.StatusCode or res.statusCode or res.status_code) or 0
    if sc ~= 200 then
        return nil, "status " .. tostring(sc)
    end

    local body = res.Body or res.body or ""
    local jd, data = pcall(function()
        return hs:JSONDecode(body)
    end)
    if not jd then
        return nil, "invalid json"
    end

    return data
end

local function norm(s)
    return string.lower(tostring(s or "")):gsub("[^%w]", "")
end

local function findExploit(list, name)
    if type(list) ~= "table" then
        return nil
    end

    local en = norm(name)
    local best, bestScore

    for _, it in ipairs(list) do
        if type(it) == "table" and type(it.title) == "string" and type(it.sunc) == "table" then
            local tn = norm(it.title)
            local score = 0

            if tn ~= "" then
                if en == tn then
                    score = 5
                elseif en:find(tn, 1, true) then
                    score = 4
                elseif tn:find(en, 1, true) then
                    score = 3
                elseif en:find(tn:sub(1, math.min(#tn, 4)), 1, true) then
                    score = 2
                end
            end

            if score > (bestScore or 0) then
                best = it
                bestScore = score
            end
        end
    end

    return best
end

local function parseRemoteTests(data)
    if type(data) ~= "table" or type(data.tests) ~= "table" then
        return nil, nil, "invalid remote payload"
    end

    local rp, rf = {}, {}

    for _, t in ipairs(type(data.tests.passed) == "table" and data.tests.passed or {}) do
        if type(t) == "table" and type(t.name) == "string" then
            rp[t.name] = true
        end
    end

    for _, t in ipairs(type(data.tests.failed) == "table" and data.tests.failed or {}) do
        if type(t) == "table" and type(t.name) == "string" then
            rf[t.name] = tostring(t.reason or "Failed")
        end
    end

    return rp, rf, nil
end

local function pullRemote(executorName)
    local list, e1 = getJson("https://whatexpsare.online/api/status/exploits")
    if not list then
        return nil, nil, nil, "exploit status: " .. tostring(e1)
    end

    local exData = findExploit(list, executorName)
    if not exData or type(exData.sunc) ~= "table" then
        return nil, nil, nil, "sunc keys missing for " .. tostring(executorName)
    end

    local scrap = exData.sunc.suncScrap
    local key = exData.sunc.suncKey
    if type(scrap) ~= "string" or scrap == "" or type(key) ~= "string" or key == "" then
        return nil, nil, nil, "invalid sunc keys"
    end

    local data, e2 = getJson("https://whatexpsare.online/api/sunc?scrap=" .. scrap .. "&key=" .. key)
    if not data then
        return nil, nil, nil, "sunc fetch: " .. tostring(e2)
    end

    local rp, rf, e3 = parseRemoteTests(data)
    if not rp then
        return nil, nil, nil, e3
    end

    return rp, rf, data, nil
end

local function ex(x)
    if type(x) ~= "table" then
        return nil
    end
    local d = {x.executorName, x.ExecutorName, x.executor, x.Executor, x.name, x.Name}
    for _, v in ipairs(d) do
        if type(v) == "string" and v ~= "" then
            return v
        end
    end
    local y = x.executor or x.Executor or x.client or x.Client
    return type(y) == "table" and ex(y) or nil
end

local function gx(d)
    local x = ex(d)
    if x then
        return x
    end
    local l = {
        rv.identifyexecutor,
        rv.getexecutorname,
        e.identifyexecutor,
        e.getexecutorname,
        (_G and _G.identifyexecutor),
        (_G and _G.getexecutorname),
    }
    for _, fn in ipairs(l) do
        if type(fn) == "function" then
            local ok, a, b = pcall(fn)
            if ok and type(a) == "string" and a ~= "" then
                return (type(b) == "string" and b ~= "") and (a .. " " .. b) or a
            end
        end
    end
    return "Unknown"
end

local function has(k)
    if k == "require" then
        if type(require) ~= "function" then
            return false, "Missing"
        end

        local ok, rOk, rErr = pcall(function()
            local m = Instance.new("ModuleScript")
            m.Name = "__phantom_require_test"
            local rOk, rErr = pcall(require, m)
            m:Destroy()
            return rOk, rErr
        end)

        if not ok then
            return false, tostring(rOk)
        end

        if rOk then
            -- keep checking real modules below; dummy success alone is not enough.
        end

        local msg = string.lower(tostring(rErr))
        if badReq(msg) then
            return false, tostring(rErr)
        end

        local rs = game:GetService("ReplicatedStorage")
        local mods, seen = {}, {}
        local function add(m)
            if not seen[m] then
                seen[m] = true
                mods[#mods + 1] = m
            end
        end
        local function scan(root, prefer)
            if #mods >= 24 then
                return
            end
            for _, d in ipairs(root:GetDescendants()) do
                if d:IsA("ModuleScript") then
                    local nm = string.lower(d.Name)
                    local isData = nm:find("data", 1, true)
                        or nm:find("config", 1, true)
                        or nm:find("const", 1, true)
                        or nm:find("setting", 1, true)
                    if (prefer and isData) or (not prefer) then
                        add(d)
                        if #mods >= 24 then
                            break
                        end
                    end
                end
            end
        end

        local rf = rs:FindFirstChild("Modules")
        if rf then
            scan(rf, true)
            if #mods < 8 then
                scan(rf, false)
            end
        end
        if #mods < 8 then
            scan(rs, true)
        end
        if #mods < 12 then
            scan(rs, false)
        end

        if #mods == 0 then
            return false, "No module probe"
        end

        local lastErr = "No working module"
        for _, m in ipairs(mods) do
            local ok2, out = pcall(require, m)
            if ok2 then
                return true, nil
            end
            local em = tostring(out)
            if badReq(string.lower(em)) then
                return false, em
            end
            lastErr = em
        end

        return false, lastErr
    end

    local v = rv[k] or e[k]
    if type(v) == "function" then
        return true, nil
    end

    local alias = rv[string.lower(k)] or e[string.lower(k)]
    if type(alias) == "function" then
        return true, nil
    end

    return false, "Missing"
end

local function mk(src, why, rp, rf)
    local p, f, m, ml = {}, {}, {}, {}
    local t, c = 0, 0
    for _, k in ipairs(n) do
        t = t + 1
        local hasRemote = type(rp) == "table" and (rp[k] ~= nil or (type(rf) == "table" and rf[k] ~= nil))
        local ok, rs

        if hasRemote then
            ok = rp[k] == true
            rs = (type(rf) == "table" and rf[k]) or "Failed"
        else
            ok, rs = has(k)
        end

        rs = rs or "Missing"
        if ok then
            p[k] = true
            c = c + 1
        else
            rs = tostring(rs)
            f[k], ml[k] = rs, true
            m[#m + 1] = {name = k, reason = rs}
        end
    end
    table.sort(m, function(a, b)
        return a.name < b.name
    end)
    return {
        passed = p,
        failed = f,
        missingMain = m,
        missingMainLookup = ml,
        mainScore = c .. "/" .. t,
        executorLevel = c >= 5 and "HIGH" or (c >= 3 and "MEDIUM" or "LOW"),
        source = src,
        reason = why,
        checkedAt = os.time and os.time() or 0,
    }
end

local function done(o, d)
    o.executorName = gx(d)
    o.runOnce = true
    o.patcherVersion = PV
    rv.phantomExecutorInfo = o
    rv.phantomMissingMainFunctions = o.missingMainLookup or {}
    rv.phantomIsBadExecutor = o.executorLevel ~= "HIGH"
    rv.phantomExecutor = type(rv.phantomExecutor) == "table" and rv.phantomExecutor or {}
    rv.phantomExecutor.info = o
    rv.phantomExecutor.missingMainLookup = rv.phantomMissingMainFunctions
    rv.phantomExecutor.isBad = rv.phantomIsBadExecutor
    rv.phantomExecutor.lastCheckedAt = o.checkedAt
    rv.phantomExecutor.executorName = o.executorName
    rv.__phantomPatcherDone = true

    local p = "[phantom patcher]"
    print(p .. " executor: " .. tostring(o.executorName))
    print(p .. " score: " .. tostring(o.mainScore) .. " level: " .. tostring(o.executorLevel) .. " source: " .. tostring(o.source))
    if o.reason then
        print(p .. " reason: " .. tostring(o.reason))
    end
    for _, k in ipairs(n) do
        if o.passed[k] then
            print(string.format("%s test %s: PASS", p, k))
        else
            print(string.format("%s test %s: FAIL (%s)", p, k, tostring(o.failed[k] or "Not passed")))
        end
    end
    return o
end

local exName = gx(nil)
local rp, rf, rd, rErr = pullRemote(exName)

if rp then
    return done(mk("weao-remote", nil, rp, rf), rd)
end

return done(mk("local-fallback", rErr), rd)