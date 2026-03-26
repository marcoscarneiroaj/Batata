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
local function loadRemoteModule(fileName)
    local url = normalizedBaseUrl .. tostring(fileName)
    local source = fetch(url)
    return loadstring(source, "@" .. url)()
end

local Batata = loadRemoteModule("shared.lua")
Batata.SourceBaseUrl = normalizedBaseUrl

pcall(function()
    loadRemoteModule("remotes.lua")
end)

pcall(function()
    loadRemoteModule("inventorydb.lua")
end)

pcall(function()
    loadRemoteModule("data.lua")
end)

return loadRemoteModule("gui.lua")
