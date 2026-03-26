-- Batata Web Loader
-- 1. Suba esta pasta para um repositorio GitHub
-- 2. Troque BASE_URL pela URL raw da pasta
-- 3. Rode: loadstring(game:HttpGet("URL_DO_web_loader.lua", true))()

local BASE_URL = "https://raw.githubusercontent.com/marcoscarneiroaj/Batata/main/"

local function fetch(url)
    local ok, body = pcall(function()
        return game:HttpGet(url, true)
    end)

    if not ok or type(body) ~= "string" or body == "" then
        error("falha ao baixar: " .. tostring(url))
    end

    return body
end

local function warnBoot(message)
    warn("[BatataWebLoader] " .. tostring(message))
end

local function normalizeBaseUrl(url)
    local text = tostring(url or "")
    text = string.gsub(text, "\\", "/")

    if text == "" then
        error("BASE_URL nao configurada")
    end

    if string.sub(text, -1) ~= "/" then
        text = text .. "/"
    end

    return text
end

local normalizedBaseUrl = normalizeBaseUrl(BASE_URL)
local Batata = nil

local function normalizePath(path)
    local text = string.gsub(tostring(path or ""), "\\", "/")
    text = string.gsub(text, "^%./", "")
    return text
end

local function fetchSource(fileName)
    local normalizedPath = normalizePath(fileName)
    local url = normalizedBaseUrl .. normalizedPath
    return fetch(url), normalizedPath, url
end

local function loadRemoteModule(fileName)
    local source, normalizedPath, url = fetchSource(fileName)

    if type(Batata) == "table" then
        Batata.RemoteSourceCache = Batata.RemoteSourceCache or {}
        Batata.LoadedFileCache = Batata.LoadedFileCache or {}
        Batata.LoadedFileUrls = Batata.LoadedFileUrls or {}

        Batata.RemoteSourceCache[normalizedPath] = source
        if Batata.LoadedFileCache[normalizedPath] ~= nil then
            return Batata.LoadedFileCache[normalizedPath]
        end
    end

    local result = loadstring(source, "@" .. url)()
    if type(Batata) == "table" then
        Batata.LoadedFileCache[normalizedPath] = result
        Batata.LoadedFileUrls[normalizedPath] = url
    end

    return result
end

local function cacheRemoteSource(fileName)
    local source, normalizedPath, url = fetchSource(fileName)

    if type(Batata) == "table" then
        Batata.RemoteSourceCache = Batata.RemoteSourceCache or {}
        Batata.LoadedFileUrls = Batata.LoadedFileUrls or {}
        Batata.RemoteSourceCache[normalizedPath] = source
        Batata.LoadedFileUrls[normalizedPath] = url
    end
end

local function bootStep(name, callback)
    local ok, result = pcall(callback)
    local entry = {
        Stage = tostring(name),
        Ok = ok == true,
        Message = ok and "ok" or tostring(result),
        Timestamp = os.clock(),
    }

    if type(Batata) == "table" then
        Batata.BootLog = Batata.BootLog or {}
        Batata.BootErrors = Batata.BootErrors or {}
        table.insert(Batata.BootLog, entry)
        if not ok then
            Batata.BootErrors[name] = entry.Message
        else
            Batata.BootErrors[name] = nil
        end
    end

    if not ok then
        warnBoot(name .. " falhou: " .. tostring(result))
        return false, result
    end

    warnBoot(name .. " ok")
    return true, result
end

Batata = loadRemoteModule("shared.lua")
local ROOT = getgenv and getgenv() or _G
ROOT.Batata = Batata
_G.Batata = Batata
Batata.SourceBaseUrl = normalizedBaseUrl
Batata.BootStatus = Batata.BootStatus or {}
Batata.BootLog = Batata.BootLog or {}
Batata.BootErrors = Batata.BootErrors or {}

bootStep("precache.lua", function()
    local seen = {}
    for _, path in pairs(Batata.Paths or {}) do
        if type(path) == "string" and seen[path] ~= true then
            seen[path] = true
            cacheRemoteSource(path)
        end
    end
end)

bootStep("remotes.lua", function()
    Batata.BootStatus.Remotes = loadRemoteModule("remotes.lua")
end)

bootStep("inventorydb.lua", function()
    Batata.BootStatus.InventoryDb = loadRemoteModule("inventorydb.lua")
end)

bootStep("data.lua", function()
    Batata.BootStatus.Data = loadRemoteModule("data.lua")
end)

local guiOk, guiResult = bootStep("gui.lua", function()
    return loadRemoteModule("gui.lua")
end)

if not guiOk then
    error(guiResult)
end

return guiResult
