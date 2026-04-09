local ROOT = getgenv and getgenv() or _G
local Batata = ROOT.Batata
if type(Batata) ~= "table" then
    error("Batata shared nao carregado")
end

if Batata.Modules.AutoShop then
    return Batata.Modules.AutoShop
end

local remotes = Batata.Util.EnsureRemotes()
local rotationRemote = remotes:Get("ShopRotationUpdated")
local premiumRemote = remotes:Get("PremiumShopUpdated")

local BUY_DELAY = 0.2
local SKIP_ITEMS = {
    rock = true,
}
local PREMIUM_CURRENCY_ITEMS = {
    starchdust = "starch_dust",
    potato_eyes = "potato_eyes",
}

local Module = {
    Running = true,
    Enabled = false,
    BuyDelay = BUY_DELAY,
    LastRotation = nil,
    LastRotationTimestamp = 0,
    LastProcessedTimestamp = 0,
    LastPremiumShop = nil,
    LastPremiumSignature = nil,
    LastProcessedPremiumSignature = nil,
    LastStatus = "Aguardando rotacao",
}

local connections = {}

local function disconnectAll()
    for _, connection in ipairs(connections) do
        if connection and connection.Disconnect then
            connection:Disconnect()
        end
    end

    table.clear(connections)
end

local function getItemInventory()
    local data = Batata.Data
    if type(data) ~= "table" then
        return {}
    end

    return type(data.ItemInventory) == "table" and data.ItemInventory or {}
end

local function getCurrencyAmount(priceType)
    local itemId = PREMIUM_CURRENCY_ITEMS[priceType]
    if not itemId then
        return 0
    end

    local inventory = getItemInventory()
    return math.max(0, tonumber(inventory[itemId]) or 0)
end

local function getPremiumCurrency(entry, priceType)
    if type(entry) ~= "table" then
        return nil, nil
    end

    if priceType == "starchdust" or priceType == "both" then
        local starchDustPrice = tonumber(entry.starchdust_price)
        if starchDustPrice ~= nil then
            return "starchdust", starchDustPrice
        end
    end

    if priceType == "potato_eyes" or priceType == "potato_eyes_robux" or priceType == "both" then
        local potatoEyesPrice = tonumber(entry.potato_eyes_price)
        if potatoEyesPrice ~= nil then
            return "potato_eyes", potatoEyesPrice
        end
    end

    return nil, nil
end

local function getPremiumSignature(premiumData)
    if type(premiumData) ~= "table" or type(premiumData.Items) ~= "table" then
        return nil
    end

    local parts = {}

    for index, entry in ipairs(premiumData.Items) do
        if type(entry) == "table" then
            table.insert(
                parts,
                table.concat({
                    tostring(index),
                    tostring(entry.id or ""),
                    tostring(entry.item_id or ""),
                    tostring(entry.price_type or ""),
                    tostring(entry.starchdust_price or ""),
                    tostring(entry.potato_eyes_price or ""),
                    tostring(entry.remaining_stock or ""),
                    tostring(entry.sort_order or ""),
                }, ":")
            )
        end
    end

    if #parts == 0 then
        return nil
    end

    table.insert(parts, "refresh:" .. tostring(premiumData.IsRefresh == true))
    return table.concat(parts, "|")
end

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

local function normalizePremiumOffers(premiumData)
    local offers = {}

    if type(premiumData) ~= "table" or type(premiumData.Items) ~= "table" then
        return offers
    end

    for index, entry in ipairs(premiumData.Items) do
        if type(entry) == "table" then
            local itemId = entry.item_id or entry.ItemId
            local entryId = tonumber(entry.id)
            local priceType = tostring(entry.price_type or "")
            local currencyType, price = getPremiumCurrency(entry, priceType)

            if type(itemId) == "string" and itemId ~= "" and entryId ~= nil then
                table.insert(offers, {
                    Index = index,
                    EntryId = entryId,
                    ItemId = itemId,
                    ItemType = entry.item_type or entry.ItemType,
                    PriceType = priceType,
                    CurrencyType = currencyType,
                    Price = tonumber(price) or 0,
                    RemainingStock = math.max(0, math.floor(tonumber(entry.remaining_stock) or 0)),
                    TotalStock = math.max(0, math.floor(tonumber(entry.total_stock) or 0)),
                    SortOrder = tonumber(entry.sort_order) or 0,
                    IsNew = entry.is_new == true,
                    HasDevProduct = tonumber(entry.dev_product_id) ~= nil,
                })
            end
        end
    end

    table.sort(offers, function(left, right)
        if left.SortOrder ~= right.SortOrder then
            return left.SortOrder < right.SortOrder
        end

        if left.Price ~= right.Price then
            return left.Price < right.Price
        end

        return left.EntryId < right.EntryId
    end)

    return offers
end

local function shouldBuyPremiumOffer(offer, balances)
    if type(offer) ~= "table" then
        return false
    end

    if offer.RemainingStock <= 0 then
        return false
    end

    if offer.Price <= 0 then
        return false
    end

    if offer.CurrencyType == nil then
        return false
    end

    local balance = balances and tonumber(balances[offer.CurrencyType]) or 0
    if balance < offer.Price then
        return false
    end

    return true
end

local function getPremiumBuyList(premiumData)
    local buyList = {}
    local balances = {
        starchdust = getCurrencyAmount("starchdust"),
        potato_eyes = getCurrencyAmount("potato_eyes"),
    }

    for _, offer in ipairs(normalizePremiumOffers(premiumData)) do
        if shouldBuyPremiumOffer(offer, balances) then
            balances[offer.CurrencyType] = math.max(0, (balances[offer.CurrencyType] or 0) - offer.Price)
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

local function processPremiumShop(premiumData)
    if Module.Enabled ~= true or Module.Running ~= true then
        return
    end

    local purchaseRemote = remotes:Get("PurchasePremiumItem")
    if not purchaseRemote then
        Module.LastStatus = "Premium remote ausente"
        return
    end

    local buyList = getPremiumBuyList(premiumData)
    if #buyList == 0 then
        Module.LastStatus = "Premium sem itens validos"
        return
    end

    local snapshot = Batata.Util.PauseAutomationModules({
        AutoShop = true,
    })

    Module.LastStatus = "Comprando premium"
    local boughtAny = false

    local ok, err = pcall(function()
        for _, offer in ipairs(buyList) do
            if Module.Running ~= true or Module.Enabled ~= true then
                break
            end

            local purchaseOk = pcall(function()
                purchaseRemote:FireServer(offer.EntryId)
            end)

            if purchaseOk then
                boughtAny = true
            end

            task.wait(Module.BuyDelay)
        end
    end)

    Batata.Util.ResumeAutomationModules(snapshot)

    if not ok then
        Module.LastStatus = "Falha no premium"
        warn("[BatataShop] erro ao comprar itens premium: " .. tostring(err))
        return
    end

    if boughtAny then
        Module.LastStatus = "Premium processada"
    else
        Module.LastStatus = "Premium sem saldo"
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

local function handlePremiumShop(premiumData)
    if type(premiumData) ~= "table" then
        return
    end

    local signature = getPremiumSignature(premiumData)
    Module.LastPremiumShop = premiumData
    Module.LastPremiumSignature = signature

    if Module.Enabled ~= true then
        Module.LastStatus = "Premium recebida"
        return
    end

    if signature ~= nil and signature == Module.LastProcessedPremiumSignature then
        Module.LastStatus = "Premium ja tratada"
        return
    end

    Module.LastProcessedPremiumSignature = signature
    task.spawn(function()
        processPremiumShop(premiumData)
    end)
end

function Module:SetEnabled(enabled)
    self.Enabled = enabled == true

    if self.Enabled then
        if self.LastRotation and self.LastRotationTimestamp > self.LastProcessedTimestamp then
            self.LastProcessedTimestamp = self.LastRotationTimestamp
            task.spawn(function()
                processRotation(self.LastRotation)
            end)
        end

        if self.LastPremiumShop and self.LastPremiumSignature ~= self.LastProcessedPremiumSignature then
            self.LastProcessedPremiumSignature = self.LastPremiumSignature
            task.spawn(function()
                processPremiumShop(self.LastPremiumShop)
            end)
        elseif self.LastPremiumShop == nil and Batata.Util and type(Batata.Util.TryInvokeRemote) == "function" then
            local ok, premiumData = Batata.Util.TryInvokeRemote("GetPremiumShop")
            if ok and type(premiumData) == "table" then
                handlePremiumShop(premiumData)
            end
        end
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
        PremiumSignature = self.LastPremiumSignature,
        LastStatus = self.LastStatus,
        OfferCount = self.LastRotation and #normalizeOffers(self.LastRotation) or 0,
        PremiumOfferCount = self.LastPremiumShop and #normalizePremiumOffers(self.LastPremiumShop) or 0,
    }
end

function Module:Stop()
    self.Running = false
    self.Enabled = false
    disconnectAll()

    if Batata.Modules.AutoShop == self then
        Batata.Modules.AutoShop = nil
    end
end

if rotationRemote and rotationRemote.OnClientEvent then
    table.insert(connections, rotationRemote.OnClientEvent:Connect(function(rotationData)
        local ok, err = pcall(handleRotation, rotationData)
        if not ok then
            Module.LastStatus = "Erro no shop"
            warn("[BatataShop] erro ao processar rotacao: " .. tostring(err))
        end
    end))
end

if premiumRemote and premiumRemote.OnClientEvent then
    table.insert(connections, premiumRemote.OnClientEvent:Connect(function(premiumData)
        local ok, err = pcall(handlePremiumShop, premiumData)
        if not ok then
            Module.LastStatus = "Erro no premium"
            warn("[BatataShop] erro ao processar premium: " .. tostring(err))
        end
    end))
end

if #connections > 0 then
    Module.LastStatus = "Escutando loja"
else
    Module.LastStatus = "Remote ausente"
end

Batata.Util.ApplyCurrentDelayProfileToModule(Module)

Batata.Modules.AutoShop = Module

return Module
