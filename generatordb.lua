local ROOT = getgenv and getgenv() or _G
ROOT.Batata = ROOT.Batata or {}
_G.Batata = ROOT.Batata

local Batata = ROOT.Batata
Batata.DB = Batata.DB or {}

if Batata.DB.GeneratorDB then
    return Batata.DB.GeneratorDB
end

local Generators = {
    { Id = "potato_seedling", Cost = 54, Growth = 1.075 },
    { Id = "backyard_patch", Cost = 270, Growth = 1.08 },
    { Id = "potato_garden", Cost = 1100, Growth = 1.10 },
    { Id = "potato_farm", Cost = 5500, Growth = 1.10 },
    { Id = "greenhouse", Cost = 28000, Growth = 1.12 },
    { Id = "processing_plant", Cost = 123200, Growth = 1.12 },
    { Id = "agricultural_lab", Cost = 1026000, Growth = 1.14 },
    { Id = "cloning_facility", Cost = 6900000, Growth = 1.15 },
    { Id = "dimensional_mirror", Cost = 59000000, Growth = 1.18 },
    { Id = "quantum_potato_generator", Cost = 450000000, Growth = 1.20 },
    { Id = "temporal_harvester", Cost = 5500000000, Growth = 1.22 },
    { Id = "potato_galaxy", Cost = 90000000000, Growth = 1.25 },
    { Id = "superfactory_number_67", Cost = 1200000000000, Growth = 1.28 },
    { Id = "potato_nexus", Cost = 20000000000000, Growth = 1.30 },
    { Id = "omnipotato", Cost = 300000000000000, Growth = 1.35 },
    { Id = "double_omnipotato", Cost = 7000000000000000, Growth = 1.40 },
    { Id = "infinite_omnipotato", Cost = 200000000000000000, Growth = 1.50 },
    { Id = "potato_infinite_universe", Cost = 4000000000000000000, Growth = 1.60 },
    { Id = "the_spudularity", Cost = 80000000000000000000, Growth = 1.75 },
}

local ById = {}
for index, generator in ipairs(Generators) do
    generator.Index = index
    ById[generator.Id] = generator
end

local DB = {
    List = Generators,
    ById = ById,
}

function DB:Get(id)
    return self.ById[id]
end

function DB:GetCurrentCost(id, ownedCount)
    local generator = self:Get(id)
    if not generator then
        return math.huge
    end

    local count = math.max(0, math.floor(tonumber(ownedCount) or 0))
    return generator.Cost * (generator.Growth ^ count)
end

Batata.DB.GeneratorDB = DB

return DB
