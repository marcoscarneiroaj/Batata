local ROOT = getgenv and getgenv() or _G
ROOT.Batata = ROOT.Batata or {}
_G.Batata = ROOT.Batata

local Batata = ROOT.Batata
Batata.DB = Batata.DB or {}

if Batata.DB.ItemDB then
    return Batata.DB.ItemDB
end

local Items = {
    potion_drop_chance = { Id = "potion_drop_chance", Type = "Potion", Rarity = "consumable" },
    potion_production = { Id = "potion_production", Type = "Potion", Rarity = "consumable" },
    potion_luck = { Id = "potion_luck", Type = "Potion", Rarity = "consumable" },
    potion_golden = { Id = "potion_golden", Type = "Potion", Rarity = "consumable" },
    potion_click = { Id = "potion_click", Type = "Potion", Rarity = "consumable" },

    red_potato = { Id = "red_potato", Type = "Potato", Rarity = "common" },
    fingerling = { Id = "fingerling", Type = "Potato", Rarity = "common" },
    yukon_gold = { Id = "yukon_gold", Type = "Potato", Rarity = "common" },
    russet = { Id = "russet", Type = "Potato", Rarity = "common" },
    white_potato = { Id = "white_potato", Type = "Potato", Rarity = "common" },

    purple_majesty = { Id = "purple_majesty", Type = "Potato", Rarity = "uncommon" },
    dirt_potato = { Id = "dirt_potato", Type = "Potato", Rarity = "uncommon" },
    french_fry = { Id = "french_fry", Type = "Potato", Rarity = "uncommon" },
    sweet_potato = { Id = "sweet_potato", Type = "Potato", Rarity = "uncommon" },
    smiling_potato = { Id = "smiling_potato", Type = "Potato", Rarity = "uncommon" },
    baby_potato = { Id = "baby_potato", Type = "Potato", Rarity = "uncommon" },
    sprouting_potato = { Id = "sprouting_potato", Type = "Potato", Rarity = "uncommon" },
    blue_potato = { Id = "blue_potato", Type = "Potato", Rarity = "uncommon" },

    soil_potato = { Id = "soil_potato", Type = "Potato", Rarity = "rare" },
    thumbs_up_potato = { Id = "thumbs_up_potato", Type = "Potato", Rarity = "rare" },
    stone_potato = { Id = "stone_potato", Type = "Potato", Rarity = "rare" },
    storm_potato = { Id = "storm_potato", Type = "Potato", Rarity = "rare" },
    rainbow_potato = { Id = "rainbow_potato", Type = "Potato", Rarity = "rare" },
    crystal_potato = { Id = "crystal_potato", Type = "Potato", Rarity = "rare" },
    frozen_potato = { Id = "frozen_potato", Type = "Potato", Rarity = "rare" },
    neon_potato = { Id = "neon_potato", Type = "Potato", Rarity = "rare" },
    volcanic_potato = { Id = "volcanic_potato", Type = "Potato", Rarity = "rare" },
    shy_potato = { Id = "shy_potato", Type = "Potato", Rarity = "rare" },
    code_potato = { Id = "code_potato", Type = "Potato", Rarity = "rare" },
    tears_of_joy_potato = { Id = "tears_of_joy_potato", Type = "Potato", Rarity = "rare" },
    tongue_out_potato = { Id = "tongue_out_potato", Type = "Potato", Rarity = "rare" },
    grilled_potato = { Id = "grilled_potato", Type = "Potato", Rarity = "rare" },
    wood_potato = { Id = "wood_potato", Type = "Potato", Rarity = "rare" },
    ancient_potato = { Id = "ancient_potato", Type = "Potato", Rarity = "rare" },
    snake_potato = { Id = "snake_potato", Type = "Potato", Rarity = "rare" },

    blight_potato = { Id = "blight_potato", Type = "Potato", Rarity = "epic" },
    loading_potato = { Id = "loading_potato", Type = "Potato", Rarity = "epic" },
    camouflage_potato = { Id = "camouflage_potato", Type = "Potato", Rarity = "epic" },
    ghostly_potato = { Id = "ghostly_potato", Type = "Potato", Rarity = "epic" },
    metal_potato = { Id = "metal_potato", Type = "Potato", Rarity = "epic" },
    shrug_potato = { Id = "shrug_potato", Type = "Potato", Rarity = "epic" },
    cutie_potato = { Id = "cutie_potato", Type = "Potato", Rarity = "epic" },
    obsidian_potato = { Id = "obsidian_potato", Type = "Potato", Rarity = "epic" },
    painted_potato = { Id = "painted_potato", Type = "Potato", Rarity = "epic" },
    handsome_potato = { Id = "handsome_potato", Type = "Potato", Rarity = "epic" },
    blaze_potato = { Id = "blaze_potato", Type = "Potato", Rarity = "epic" },
    confused_potato = { Id = "confused_potato", Type = "Potato", Rarity = "epic" },
    heart_eyes_potato = { Id = "heart_eyes_potato", Type = "Potato", Rarity = "epic" },
    puppy_potato = { Id = "puppy_potato", Type = "Potato", Rarity = "epic" },
    vomiting_potato = { Id = "vomiting_potato", Type = "Potato", Rarity = "epic" },
    bug_finder_potato = { Id = "bug_finder_potato", Type = "Potato", Rarity = "epic" },
    soccer_potato = { Id = "soccer_potato", Type = "Potato", Rarity = "epic" },
    basketball_potato = { Id = "basketball_potato", Type = "Potato", Rarity = "epic" },
    helpful_potato = { Id = "helpful_potato", Type = "Potato", Rarity = "epic" },
    flat_potato = { Id = "flat_potato", Type = "Potato", Rarity = "epic" },
    rope_potato = { Id = "rope_potato", Type = "Potato", Rarity = "epic" },
    glass_potato = { Id = "glass_potato", Type = "Potato", Rarity = "epic" },
    aquatic_potato = { Id = "aquatic_potato", Type = "Potato", Rarity = "epic" },
    goth_potato = { Id = "goth_potato", Type = "Potato", Rarity = "epic" },
    thinking_potato = { Id = "thinking_potato", Type = "Potato", Rarity = "epic" },
    worm_potato = { Id = "worm_potato", Type = "Potato", Rarity = "epic" },
    enchanted_potato = { Id = "enchanted_potato", Type = "Potato", Rarity = "epic" },
    zebra_potato = { Id = "zebra_potato", Type = "Potato", Rarity = "epic" },
    marble_potato = { Id = "marble_potato", Type = "Potato", Rarity = "epic" },
    kiwi_potato = { Id = "kiwi_potato", Type = "Potato", Rarity = "epic" },
    crayon_potato = { Id = "crayon_potato", Type = "Potato", Rarity = "epic" },
    pixel_potato = { Id = "pixel_potato", Type = "Potato", Rarity = "epic" },
    diamond_potato = { Id = "diamond_potato", Type = "Potato", Rarity = "epic" },
    knit_potato = { Id = "knit_potato", Type = "Potato", Rarity = "epic" },
    crying_potato = { Id = "crying_potato", Type = "Potato", Rarity = "epic" },
    cloud_potato = { Id = "cloud_potato", Type = "Potato", Rarity = "epic" },
    slime_potato = { Id = "slime_potato", Type = "Potato", Rarity = "epic" },
    mechanical_potato = { Id = "mechanical_potato", Type = "Potato", Rarity = "epic" },
    clown_potato = { Id = "clown_potato", Type = "Potato", Rarity = "epic" },
    mud_potato = { Id = "mud_potato", Type = "Potato", Rarity = "epic" },
    quantum_potato = { Id = "quantum_potato", Type = "Potato", Rarity = "epic" },
    celestial_potato = { Id = "celestial_potato", Type = "Potato", Rarity = "epic" },
    void_potato = { Id = "void_potato", Type = "Potato", Rarity = "epic" },
    bubble_potato = { Id = "bubble_potato", Type = "Potato", Rarity = "epic" },
    glacial_potato = { Id = "glacial_potato", Type = "Potato", Rarity = "epic" },
    couch_potato = { Id = "couch_potato", Type = "Potato", Rarity = "epic" },
    fairy_potato = { Id = "fairy_potato", Type = "Potato", Rarity = "epic" },
    leopard_potato = { Id = "leopard_potato", Type = "Potato", Rarity = "epic" },
    kitty_potato = { Id = "kitty_potato", Type = "Potato", Rarity = "epic" },
    bitten_potato = { Id = "bitten_potato", Type = "Potato", Rarity = "epic" },
    shocked_potato = { Id = "shocked_potato", Type = "Potato", Rarity = "epic" },
    honeycomb_potato = { Id = "honeycomb_potato", Type = "Potato", Rarity = "epic" },
    man_potato = { Id = "man_potato", Type = "Potato", Rarity = "epic" },
    boost_potato = { Id = "boost_potato", Type = "Potato", Rarity = "epic" },
    sleepy_potato = { Id = "sleepy_potato", Type = "Potato", Rarity = "epic" },
    bombastic_potato = { Id = "bombastic_potato", Type = "Potato", Rarity = "epic" },
    matcha_potato = { Id = "matcha_potato", Type = "Potato", Rarity = "epic" },
    pota_toe = { Id = "pota_toe", Type = "Potato", Rarity = "epic" },
    salute_potato = { Id = "salute_potato", Type = "Potato", Rarity = "epic" },
    sushi_potato = { Id = "sushi_potato", Type = "Potato", Rarity = "epic" },
    glitter_potato = { Id = "glitter_potato", Type = "Potato", Rarity = "epic" },
    phoenix_potato = { Id = "phoenix_potato", Type = "Potato", Rarity = "epic" },
    deal_with_it_potato = { Id = "deal_with_it_potato", Type = "Potato", Rarity = "epic" },
    watermelon_potato = { Id = "watermelon_potato", Type = "Potato", Rarity = "epic" },
    potato_chip = { Id = "potato_chip", Type = "Potato", Rarity = "epic" },
    expert_bug_finder_potato = { Id = "expert_bug_finder_potato", Type = "Potato", Rarity = "epic" },
    butter_potato = { Id = "butter_potato", Type = "Potato", Rarity = "epic" },
    angry_potato = { Id = "angry_potato", Type = "Potato", Rarity = "epic" },
    emerald_potato = { Id = "emerald_potato", Type = "Potato", Rarity = "epic" },
    king_potato = { Id = "king_potato", Type = "Potato", Rarity = "epic" },
    gigachad_potato = { Id = "gigachad_potato", Type = "Potato", Rarity = "epic" },
    gopher_potato = { Id = "gopher_potato", Type = "Potato", Rarity = "epic" },

    half_a_potato = { Id = "half_a_potato", Type = "Potato", Rarity = "legendary" },
    singularity_potato = { Id = "singularity_potato", Type = "Potato", Rarity = "legendary" },
    ruby_potato = { Id = "ruby_potato", Type = "Potato", Rarity = "legendary" },
    ultimate_bug_finder_potato = { Id = "ultimate_bug_finder_potato", Type = "Potato", Rarity = "legendary" },
    aurora_potato = { Id = "aurora_potato", Type = "Potato", Rarity = "legendary" },
    chalk_potato = { Id = "chalk_potato", Type = "Potato", Rarity = "legendary" },
    mister_potato = { Id = "mister_potato", Type = "Potato", Rarity = "legendary" },
    nerd_potato = { Id = "nerd_potato", Type = "Potato", Rarity = "legendary" },
    pearl_potato = { Id = "pearl_potato", Type = "Potato", Rarity = "legendary" },
    divine_potato = { Id = "divine_potato", Type = "Potato", Rarity = "legendary" },
    my_little_potato = { Id = "my_little_potato", Type = "Potato", Rarity = "legendary" },
    eternal_potato = { Id = "eternal_potato", Type = "Potato", Rarity = "legendary" },
    peeled_potato = { Id = "peeled_potato", Type = "Potato", Rarity = "legendary" },
    solar_flare_potato = { Id = "solar_flare_potato", Type = "Potato", Rarity = "legendary" },
    sixty_seven_potato = { Id = "sixty_seven_potato", Type = "Potato", Rarity = "legendary" },
    plasma_potato = { Id = "plasma_potato", Type = "Potato", Rarity = "legendary" },
    galaxy_potato = { Id = "galaxy_potato", Type = "Potato", Rarity = "legendary" },

    the_first_potato = { Id = "the_first_potato", Type = "Potato", Rarity = "secret" },
    tomato = { Id = "tomato", Type = "Potato", Rarity = "secret" },
    yuzu_potato = { Id = "yuzu_potato", Type = "Potato", Rarity = "secret" },
    shrimp = { Id = "shrimp", Type = "Potato", Rarity = "secret" },
    real_potato = { Id = "real_potato", Type = "Potato", Rarity = "secret" },
    null_potato = { Id = "null_potato", Type = "Potato", Rarity = "secret" },
    really_big_potato = { Id = "really_big_potato", Type = "Potato", Rarity = "secret" },
    upside_down_potato = { Id = "upside_down_potato", Type = "Potato", Rarity = "secret" },
    mushroom_potato = { Id = "mushroom_potato", Type = "Potato", Rarity = "secret" },
    dragon_potato = { Id = "dragon_potato", Type = "Potato", Rarity = "secret" },
    jelly_bean_potato = { Id = "jelly_bean_potato", Type = "Potato", Rarity = "secret" },
}

local ByType = {}
local ByRarity = {}

for id, data in pairs(Items) do
    local itemType = data.Type or "Unknown"
    local rarity = data.Rarity or "unknown"

    ByType[itemType] = ByType[itemType] or {}
    ByType[itemType][id] = data

    ByRarity[rarity] = ByRarity[rarity] or {}
    ByRarity[rarity][id] = data
end

local DB = {
    Items = Items,
    ByType = ByType,
    ByRarity = ByRarity,
}

function DB.Get(itemId)
    return DB.Items[itemId]
end

function DB.GetType(itemId)
    local item = DB.Items[itemId]
    return item and item.Type or nil
end

function DB.GetRarity(itemId)
    local item = DB.Items[itemId]
    return item and item.Rarity or nil
end

function DB.IsPotato(itemId)
    return DB.GetType(itemId) == "Potato"
end

function DB.IsPotion(itemId)
    return DB.GetType(itemId) == "Potion"
end

Batata.DB.ItemDB = DB

return DB
