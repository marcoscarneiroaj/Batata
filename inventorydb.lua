_G.Batata = _G.Batata or {}

local Batata = _G.Batata
Batata.DB = Batata.DB or {}

local InventoryDB = {
    Potatoes = {
        "ancient_potato",
        "aquatic_potato",
        "baby_potato",
        "basketball_potato",
        "baby_potato",
        "blaze_potato",
        "blight_potato",
        "blue_potato",
        "bubble_potato",
        "camouflage_potato",
        "celestial_potato",
        "clown_potato",
        "cloud_potato",
        "confused_potato",
        "cosmic_potato",
        "couch_potato",
        "crayon_potato",
        "crying_potato",
        "crystal_potato",
        "cutie_potato",
        "deal_with_it_potato",
        "diamond_potato",
        "dirt_potato",
        "divine_potato",
        "enchanted_potato",
        "eternal_potato",
        "fairy_potato",
        "fingerling",
        "flat_potato",
        "french_fry",
        "frozen_potato",
        "ghostly_potato",
        "gigachad_potato",
        "glacial_potato",
        "glass_potato",
        "glitter_potato",
        "goth_potato",
        "grilled_potato",
        "handsome_potato",
        "heart_eyes_potato",
        "honeycomb_potato",
        "king_potato",
        "kitty_potato",
        "kiwi_potato",
        "leopard_potato",
        "marble_potato",
        "mechanical_potato",
        "metal_potato",
        "mister_potato",
        "mud_potato",
        "neon_potato",
        "obsidian_potato",
        "phoenix_potato",
        "pixel_potato",
        "purple_majesty",
        "puppy_potato",
        "quantum_potato",
        "rainbow_potato",
        "red_potato",
        "rope_potato",
        "russet",
        "shocked_potato",
        "shrug_potato",
        "shy_potato",
        "singularity_potato",
        "sixseven_potato",
        "slime_potato",
        "smiling_potato",
        "snake_potato",
        "soil_potato",
        "sprouting_potato",
        "stone_potato",
        "storm_potato",
        "sweet_potato",
        "tears_of_joy_potato",
        "the_first_potato",
        "thinking_potato",
        "thumbs_up_potato",
        "tongue_out_potato",
        "void_potato",
        "volcanic_potato",
        "vomiting_potato",
        "watermelon_potato",
        "white_potato",
        "wood_potato",
        "worm_potato",
        "yukon_gold",
    },
    Items = {
        "emoji_mystery_potato",
        "mystery_potato",
        "potion_click",
        "potion_drop_chance",
        "potion_golden",
        "potion_luck",
        "potion_production",
        "potato_eyes",
        "rock",
        "starch_dust",
    },
    Backgrounds = {
        "farm_field",
        "fine_dining",
        "floating_in_space",
        "market_square",
        "potato_factory",
        "shopkeepers_stash",
    },
    Relics = {
        "ancient_book_piece_1",
        "ancient_book_piece_2",
        "ancient_book_piece_3",
        "ancient_book_piece_4",
        "ancient_book_piece_5",
        "ancient_book_piece_6",
        "ancient_sack_piece_1",
        "ancient_sack_piece_2",
        "ancient_sack_piece_3",
        "ancient_sack_piece_4",
        "ancient_sack_piece_5",
        "ancient_sack_piece_6",
    },
}

local function buildLookup(db)
    local lookup = {}

    for category, entries in pairs(db) do
        if type(entries) == "table" then
            for _, id in ipairs(entries) do
                lookup[id] = category
            end
        end
    end

    return lookup
end

InventoryDB.Lookup = buildLookup(InventoryDB)

function InventoryDB:GetCategory(itemId)
    return self.Lookup[itemId]
end

function InventoryDB:Has(itemId)
    return self.Lookup[itemId] ~= nil
end

Batata.DB.Inventory = InventoryDB

return InventoryDB
