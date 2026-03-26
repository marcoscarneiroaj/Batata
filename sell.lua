local Players = game:GetService("Players")

local ROOT = getgenv and getgenv() or _G
local Batata = ROOT.Batata
if type(Batata) ~= "table" then
    error("Batata shared nao carregado")
end

if Batata.Modules.AutoSell then
    return Batata.Modules.AutoSell
end

local remotes = Batata.Util.EnsureRemotes()

local SELL_DELAY = 1
local DEFAULT_COMMON_MIN_PRICE = 0
local DEFAULT_GOLDEN_MIN_PRICE = 2
local COMMON_VALUE_NAMES = { "Potatoes", "Potato", "CommonPotatoes", "PotatoCount" }
local GOLDEN_VALUE_NAMES = { "GoldenPotatoes", "GoldenPotato", "GoldPotatoes", "GoldenPotatoCount" }

local Module = {
    Running = true,
    Enabled = false,
    Delay = SELL_DELAY,
    CommonMinPrice = DEFAULT_COMMON_MIN_PRICE,
    GoldenMinPrice = DEFAULT_GOLDEN_MIN_PRICE,
    LastStatus = "Aguardando dados",
}

local function readNumberFromValue(valueObject)
    if not valueObject then
        return nil
    end

    if valueObject:IsA("IntValue") or valueObject:IsA("NumberValue") then
        return tonumber(valueObject.Value)
    end

    if valueObject:IsA("StringValue") then
        return tonumber(valueObject.Value)
    end

    local attributeValue = valueObject:GetAttribute("Value")
    if attributeValue ~= nil then
        return tonumber(attributeValue)
    end

    return nil
end

local function getSearchRoots()
    local localPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

    return {
        localPlayer,
        localPlayer:FindFirstChild("leaderstats"),
        localPlayer:FindFirstChild("Stats"),
        localPlayer:FindFirstChild("Data"),
        localPlayer:FindFirstChild("Values"),
    }
end

local function findAmountByNames(names)
    for _, root in ipairs(getSearchRoots()) do
        if root then
            for _, name in ipairs(names) do
                local attributeValue = root:GetAttribute(name)
                if attributeValue ~= nil then
                    local amount = tonumber(attributeValue)
                    if amount ~= nil then
                        return amount
                    end
                end

                local found = root:FindFirstChild(name, true)
                local amount = readNumberFromValue(found)
                if amount ~= nil then
                    return amount
                end
            end
        end
    end

    return nil
end

local function getStats()
    local data = Batata.Data
    return type(data) == "table" and data.Stats or nil
end

local function getSellPrices()
    local data = Batata.Data
    local sellPrices = type(data) == "table" and data.SellPrices or nil

    return {
        Common = tonumber(sellPrices and sellPrices.Potato) or 0,
        Golden = tonumber(sellPrices and sellPrices.Golden) or 0,
    }
end

local function getCurrentPotatoAmounts()
    local stats = getStats()

    local commonAmount = stats and stats.Potatoes or findAmountByNames(COMMON_VALUE_NAMES)
    local goldenAmount = stats and stats.GoldenPotatoes or findAmountByNames(GOLDEN_VALUE_NAMES)

    commonAmount = math.floor(math.max(0, tonumber(commonAmount) or 0))
    goldenAmount = math.floor(math.max(0, tonumber(goldenAmount) or 0))

    return commonAmount, goldenAmount
end

function Module:SetEnabled(enabled)
    self.Enabled = enabled == true
    self.LastStatus = self.Enabled and "Rodando" or "Desligado"
end

function Module:Toggle()
    self:SetEnabled(not self.Enabled)
    return self.Enabled
end

function Module:SetDelay(value)
    local numberValue = tonumber(value)
    if numberValue and numberValue >= 0.1 then
        self.Delay = numberValue
    end
end

function Module:ApplyDelayProfile(profile, profileName)
    if type(profile) ~= "table" then
        return
    end

    self.DelayProfile = profileName
    self:SetDelay(profile.SellDelay)
end

function Module:SetCommonMinPrice(value)
    local numberValue = tonumber(value)
    if numberValue == nil then
        return
    end

    self.CommonMinPrice = math.max(0, numberValue)
end

function Module:SetGoldenMinPrice(value)
    local numberValue = tonumber(value)
    if numberValue == nil then
        return
    end

    self.GoldenMinPrice = math.max(0, numberValue)
end

function Module:GetState()
    local commonAmount, goldenAmount = getCurrentPotatoAmounts()
    local prices = getSellPrices()

    return {
        Enabled = self.Enabled == true,
        Running = self.Running == true,
        Delay = self.Delay,
        Potatoes = commonAmount,
        GoldenPotatoes = goldenAmount,
        CommonPrice = prices.Common,
        GoldenPrice = prices.Golden,
        CommonMinPrice = self.CommonMinPrice,
        GoldenMinPrice = self.GoldenMinPrice,
        LastStatus = self.LastStatus,
    }
end

function Module:Stop()
    self.Running = false
    self.Enabled = false
    self.LastStatus = "Desligado"
    if Batata.Modules.AutoSell == self then
        Batata.Modules.AutoSell = nil
    end
end

Batata.Util.ApplyCurrentDelayProfileToModule(Module)

task.spawn(function()
    while Module.Running do
        if Module.Enabled then
            local commonAmount, goldenAmount = getCurrentPotatoAmounts()
            local prices = getSellPrices()
            local sellPotatoesRemote = remotes:Get("SellPotatoes")
            local sellGoldenPotatoesRemote = remotes:Get("SellGoldenPotatoes")
            local soldAny = false

            if commonAmount > 0 and prices.Common >= Module.CommonMinPrice and sellPotatoesRemote then
                Module.LastStatus = "Vendendo comum"
                pcall(function()
                    sellPotatoesRemote:FireServer(commonAmount)
                end)
                soldAny = true
            end

            if goldenAmount > 0 and prices.Golden >= Module.GoldenMinPrice and sellGoldenPotatoesRemote then
                Module.LastStatus = "Vendendo dourada"
                pcall(function()
                    sellGoldenPotatoesRemote:FireServer(goldenAmount)
                end)
                soldAny = true
            end

            if not soldAny then
                Module.LastStatus = "Aguardando preco"
            end
        end

        task.wait(Module.Delay)
    end
end)

Batata.Modules.AutoSell = Module

return Module
