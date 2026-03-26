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
local sharedUrl = normalizedBaseUrl .. "shared.lua"
local guiUrl = normalizedBaseUrl .. "gui.lua"

local sharedSource = fetch(sharedUrl)
local Batata = loadstring(sharedSource, "@" .. sharedUrl)()
Batata.SourceBaseUrl = normalizedBaseUrl

local guiSource = fetch(guiUrl)
return loadstring(guiSource, "@" .. guiUrl)()
