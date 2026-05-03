local TARGET_PLACE_ID = 137813779739566
local SCRIPT_URL = "https://raw.githubusercontent.com/marcoscarneiroaj/Batata/main/formiga/formiga.lua"
local LOAD_TIMEOUT = 60
local CHECK_INTERVAL = 1

local function waitForTargetGame()
    local deadline = tick() + LOAD_TIMEOUT

    if not game:IsLoaded() then
        pcall(function()
            game.Loaded:Wait()
        end)
    end

    while tick() < deadline do
        if game.PlaceId == TARGET_PLACE_ID then
            return true
        end
        task.wait(CHECK_INTERVAL)
    end

    return game.PlaceId == TARGET_PLACE_ID
end

if not waitForTargetGame() then
    warn("[FormigaWebLoader] jogo alvo nao detectado")
    return
end

local okRequest, source = pcall(function()
    return game:HttpGet(SCRIPT_URL, true)
end)

if not okRequest then
    warn("[FormigaWebLoader] falha no HttpGet: " .. tostring(source))
    return
end

local chunk, loadErr = loadstring(source, "@formiga/web_loader.lua")
if not chunk then
    warn("[FormigaWebLoader] falha no loadstring: " .. tostring(loadErr))
    return
end

local okRun, runErr = pcall(chunk)
if not okRun then
    warn("[FormigaWebLoader] erro ao executar: " .. tostring(runErr))
end
