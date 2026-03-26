local Batata = _G.Batata or loadstring(readfile("batata\\shared.lua"), "@batata\\shared.lua")()

if Batata.Modules.AutoShop then
    return Batata.Modules.AutoShop
end

local remotes = Batata.Util.EnsureRemotes()
local rotationRemote = remotes:Get("ShopRotationUpdated")

local BUY_DELAY = 0.2
local SKIP_ITEMS = {
    rock = true,
}

local Module = {
    Running = true,
    Enabled = false,
    BuyDelay = BUY_DELAY,
    LastRotation = nil,
    LastRotationTimestamp = 0,
    LastProcessedTimestamp = 0,
    LastStatus = "Aguardando rotacao",
}

local connection

local function getPurchasedLookup(rotationData)
    if type(rotationData) ~= "table" or type(rotationData.PurchasedThisRotation) ~= "table" then
        return {}
    end

    return rotationData.PurchasedThisRotation
end

local function normalizeOffers(rotationData)
    local offers = {}

    if type(rotationData) ~= "table" or type(rotationData.Rotation) ~= "table" then
        return offers
    end

    local purchased = getPurchasedLookup(rotationData)

    for index, entry in ipairs(rotationData.Rotation) do
        if type(entry) == "table" then
            local itemId = entry.ItemId or entry.PotatoId
            if type(itemId) == "string" and itemId ~= "" then
                table.insert(offers, {
                    Index = index,
                    ItemId = itemId,
                    ItemType = entry.ItemType,
                    Price = tonumber(entry.Price) or 0,
                    CurrencyType = entry.CurrencyType,
                    PrestigeRequirement = tonumber(entry.PrestigeRequirement) or 0,
                    Purchased = purchased[itemId] == true or purchased[index] == true,
                })
            end
        end
    end

    return offers
end

local function shouldBuyOffer(offer)
    if type(offer) ~= "table" then
        return false
    end

    if offer.Purchased == true then
        return false
    end

    if SKIP_ITEMS[offer.ItemId] == true then
        return false
    end

    return true
end

local function getBuyList(rotationData)
    local buyList = {}

    for _, offer in ipairs(normalizeOffers(rotationData)) do
        if shouldBuyOffer(offer) then
            table.insert(buyList, offer)
        end
    end

    return buyList
end

local function processRotation(rotationData)
    if Module.Enabled ~= true or Module.Running ~= true then
        return
    end

    local purchaseRemote = remotes:Get("PurchaseShopPotato")
    if not purchaseRemote then
        Module.LastStatus = "Remote ausente"
        return
    end

    local buyList = getBuyList(rotationData)
    if #buyList == 0 then
        Module.LastStatus = "Sem itens validos"
        return
    end

    local snapshot = Batata.Util.PauseAutomationModules({
        AutoShop = true,
    })

    Module.LastStatus = "Comprando"
    local boughtAny = false

    local ok, err = pcall(function()
        for _, offer in ipairs(buyList) do
            if Module.Running ~= true or Module.Enabled ~= true then
                break
            end

            local purchaseOk = pcall(function()
                purchaseRemote:FireServer(offer.ItemId)
            end)

            if purchaseOk then
                boughtAny = true
            end

            task.wait(Module.BuyDelay)
        end
    end)

    Batata.Util.ResumeAutomationModules(snapshot)

    if not ok then
        Module.LastStatus = "Falha na compra"
        warn("[BatataShop] erro ao comprar itens da rotacao: " .. tostring(err))
        return
    end

    if boughtAny then
        Module.LastStatus = "Rotacao processada"
    else
        Module.LastStatus = "Sem saldo suficiente"
    end
end

local function handleRotation(rotationData)
    if type(rotationData) ~= "table" then
        return
    end

    Module.LastRotation = rotationData
    Module.LastRotationTimestamp = tonumber(rotationData.Timestamp) or os.time()

    if Module.Enabled ~= true then
        Module.LastStatus = "Rotacao recebida"
        return
    end

    if Module.LastRotationTimestamp <= Module.LastProcessedTimestamp then
        Module.LastStatus = "Rotacao ja tratada"
        return
    end

    Module.LastProcessedTimestamp = Module.LastRotationTimestamp
    task.spawn(function()
        processRotation(rotationData)
    end)
end

function Module:SetEnabled(enabled)
    self.Enabled = enabled == true

    if self.Enabled and self.LastRotation and self.LastRotationTimestamp > self.LastProcessedTimestamp then
        self.LastProcessedTimestamp = self.LastRotationTimestamp
        task.spawn(function()
            processRotation(self.LastRotation)
        end)
    elseif not self.Enabled then
        self.LastStatus = "Desligado"
    end
end

function Module:Toggle()
    self:SetEnabled(not self.Enabled)
    return self.Enabled
end

function Module:SetBuyDelay(value)
    local numberValue = tonumber(value)
    if numberValue and numberValue >= 0.05 then
        self.BuyDelay = numberValue
    end
end

function Module:ApplyDelayProfile(profile, profileName)
    if type(profile) ~= "table" then
        return
    end

    self.DelayProfile = profileName
    self:SetBuyDelay(profile.ShopBuyDelay)
end

function Module:GetState()
    return {
        Enabled = self.Enabled == true,
        Running = self.Running == true,
        BuyDelay = self.BuyDelay,
        LastRotationTimestamp = self.LastRotationTimestamp,
        LastProcessedTimestamp = self.LastProcessedTimestamp,
        LastStatus = self.LastStatus,
        OfferCount = self.LastRotation and #normalizeOffers(self.LastRotation) or 0,
    }
end

function Module:Stop()
    self.Running = false
    self.Enabled = false

    if connection and connection.Disconnect then
        connection:Disconnect()
        connection = nil
    end

    if Batata.Modules.AutoShop == self then
        Batata.Modules.AutoShop = nil
    end
end

if rotationRemote and rotationRemote.OnClientEvent then
    connection = rotationRemote.OnClientEvent:Connect(function(rotationData)
        local ok, err = pcall(handleRotation, rotationData)
        if not ok then
            Module.LastStatus = "Erro no shop"
            warn("[BatataShop] erro ao processar rotacao: " .. tostring(err))
        end
    end)
    Module.LastStatus = "Escutando loja"
else
    Module.LastStatus = "Remote ausente"
end

Batata.Util.ApplyCurrentDelayProfileToModule(Module)

Batata.Modules.AutoShop = Module

return Module
