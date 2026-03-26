local ReplicatedStorage = game:GetService("ReplicatedStorage")

_G.Batata = _G.Batata or {}

local Batata = _G.Batata
Batata.Remotes = Batata.Remotes or {}

if Batata.Remotes._initialized == true then
    return Batata.Remotes
end

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")

local REMOTE_DEFINITIONS = {
    DataUpdated = true,
    PerformClick = true,
    PurchaseClickUpgrade = false,
    UsePotion = false,
    PotionBuffUpdated = false,
    EquipPotato = false,
    GeneticsRollSlot = false,
    GeneticsResult = false,
    SellPotatoes = false,
    SellGoldenPotatoes = false,
    PerformPrestige = true,
    PurchasePrestigeUpgrade = false,
    PerformAscension = true,
    FusePotatoes = false,
    FusionResult = false,
    ShopRotationUpdated = false,
    PurchaseShopPotato = false,
    PurchaseGenerator = false,
    DeleteGenerator = false,
    Error = false,
    DigSquare = false,
    DigStaminaUpdate = false,
    DigRoundInfo = false,
    DigResult = false,
}

local function getRemote(name, shouldWait)
    if shouldWait == true then
        return remotesFolder:WaitForChild(name)
    end

    return remotesFolder:FindFirstChild(name)
end

local function cacheRemote(name)
    local shouldWait = REMOTE_DEFINITIONS[name]
    if shouldWait == nil then
        return nil
    end

    local remote = getRemote(name, shouldWait)
    Batata.Remotes[name] = remote
    return remote
end

Batata.Remotes.Folder = remotesFolder
Batata.Remotes.Definitions = REMOTE_DEFINITIONS

for remoteName in pairs(REMOTE_DEFINITIONS) do
    cacheRemote(remoteName)
end

Batata.Remotes._initialized = true

function Batata.Remotes:Refresh(name)
    if type(name) == "string" and self.Definitions[name] ~= nil then
        return cacheRemote(name)
    end

    for remoteName in pairs(self.Definitions) do
        cacheRemote(remoteName)
    end

    return self
end

function Batata.Remotes:Get(name)
    if type(name) ~= "string" then
        return nil
    end

    if self.Definitions[name] == nil then
        return self[name]
    end

    local cached = self[name]
    if cached ~= nil then
        return cached
    end

    return self:Refresh(name)
end

return Batata.Remotes
