-- Blueprint / crafting recipe definitions.
-- blueprintId format: "BP_<Element>_T<Tier>" or "BP_Event_<Name>"
local RecipeData = {}

-- Source categories for how blueprints are obtained
RecipeData.Source = {
    Starting  = "starting",
    ForgeMilestone = "forge_milestone",
    Challenge = "challenge",
    RareDrop  = "rare_drop",
    SeasonalEvent = "seasonal_event",
    Trade     = "trade",
}

-- All blueprint definitions
RecipeData.Blueprints = {

    -- ── Tier 1 — all five elements, given at start ─────────────────────────
    BP_Ember_T1 = {
        id = "BP_Ember_T1", element = "Ember", tier = 1,
        source = RecipeData.Source.Starting,
        materialsRequired = {
            { id = "BasicOre", qty = 10 },
            { id = "Coal",     qty = 5  },
        },
    },
    BP_Stone_T1 = {
        id = "BP_Stone_T1", element = "Stone", tier = 1,
        source = RecipeData.Source.Starting,
        materialsRequired = {
            { id = "BasicOre", qty = 10 },
            { id = "Coal",     qty = 5  },
        },
    },
    BP_Frost_T1 = {
        id = "BP_Frost_T1", element = "Frost", tier = 1,
        source = RecipeData.Source.Starting,
        materialsRequired = {
            { id = "BasicOre", qty = 10 },
            { id = "Coal",     qty = 5  },
        },
    },
    BP_Storm_T1 = {
        id = "BP_Storm_T1", element = "Storm", tier = 1,
        source = RecipeData.Source.Starting,
        materialsRequired = {
            { id = "BasicOre", qty = 10 },
            { id = "Coal",     qty = 5  },
        },
    },
    BP_Void_T1 = {
        id = "BP_Void_T1", element = "Void", tier = 1,
        source = RecipeData.Source.Starting,
        -- Void Tier 1 still requires a Tier 2+ golem to have been crafted first
        unlockGate = "craft_first_tier2",
        materialsRequired = {
            { id = "BasicOre",   qty = 10 },
            { id = "ShadowDust", qty = 5  },
        },
    },

    -- ── Tier 2 ─────────────────────────────────────────────────────────────
    BP_Ember_T2 = {
        id = "BP_Ember_T2", element = "Ember", tier = 2,
        source = RecipeData.Source.ForgeMilestone,
        forgeLevelRequired = 3,
        materialsRequired = {
            { id = "RefinedOre", qty = 30 },
            { id = "EmberDust",  qty = 15 },
        },
    },
    BP_Stone_T2 = {
        id = "BP_Stone_T2", element = "Stone", tier = 2,
        source = RecipeData.Source.ForgeMilestone,
        forgeLevelRequired = 3,
        materialsRequired = {
            { id = "RefinedOre",   qty = 30 },
            { id = "ElementalIngot", qty = 10 },
        },
    },
    BP_Frost_T2 = {
        id = "BP_Frost_T2", element = "Frost", tier = 2,
        source = RecipeData.Source.Challenge,
        materialsRequired = {
            { id = "RefinedOre",    qty = 30 },
            { id = "CrystalFragment", qty = 15 },
        },
    },
    BP_Storm_T2 = {
        id = "BP_Storm_T2", element = "Storm", tier = 2,
        source = RecipeData.Source.Challenge,
        materialsRequired = {
            { id = "RefinedOre",   qty = 30 },
            { id = "ElementalIngot", qty = 15 },
        },
    },
    BP_Void_T2 = {
        id = "BP_Void_T2", element = "Void", tier = 2,
        source = RecipeData.Source.RareDrop,
        materialsRequired = {
            { id = "RefinedOre",  qty = 30 },
            { id = "ShadowDust",  qty = 30 },
            { id = "EmberDust",   qty = 10 },
        },
    },

    -- ── Tier 3 ─────────────────────────────────────────────────────────────
    BP_Ember_T3 = {
        id = "BP_Ember_T3", element = "Ember", tier = 3,
        source = RecipeData.Source.ForgeMilestone,
        forgeLevelRequired = 5,
        materialsRequired = {
            { id = "ElementalIngot", qty = 80 },
            { id = "EssenceShard",   qty = 30 },
            { id = "MoltenCore",     qty = 5  },
        },
    },
    BP_Stone_T3 = {
        id = "BP_Stone_T3", element = "Stone", tier = 3,
        source = RecipeData.Source.RareDrop,
        materialsRequired = {
            { id = "ElementalIngot",  qty = 80 },
            { id = "CrystalFragment", qty = 40 },
        },
    },
    BP_Frost_T3 = {
        id = "BP_Frost_T3", element = "Frost", tier = 3,
        source = RecipeData.Source.RareDrop,
        materialsRequired = {
            { id = "ElementalIngot",  qty = 80 },
            { id = "CrystalFragment", qty = 40 },
            { id = "EternalIce",      qty = 5  },
        },
    },
    BP_Storm_T3 = {
        id = "BP_Storm_T3", element = "Storm", tier = 3,
        source = RecipeData.Source.Challenge,
        materialsRequired = {
            { id = "ElementalIngot", qty = 80 },
            { id = "ThunderShard",   qty = 20 },
        },
    },
    BP_Void_T3 = {
        id = "BP_Void_T3", element = "Void", tier = 3,
        source = RecipeData.Source.RareDrop,
        materialsRequired = {
            { id = "ElementalIngot", qty = 80 },
            { id = "VoidEssence",    qty = 10 },
        },
    },

    -- ── Tier 4 ─────────────────────────────────────────────────────────────
    BP_Ember_T4 = {
        id = "BP_Ember_T4", element = "Ember", tier = 4,
        source = RecipeData.Source.RareDrop,
        forgeLevelRequired = 8,
        materialsRequired = {
            { id = "PureIngot",    qty = 200 },
            { id = "EssenceShard", qty = 100 },
            { id = "MoltenCore",   qty = 20  },
        },
    },
    BP_Stone_T4 = {
        id = "BP_Stone_T4", element = "Stone", tier = 4,
        source = RecipeData.Source.RareDrop,
        forgeLevelRequired = 8,
        materialsRequired = {
            { id = "PureIngot",     qty = 200 },
            { id = "EssenceShard",  qty = 100 },
            { id = "AncientBedrock", qty = 15 },
        },
    },

    -- ── Tier 4 (continued) ────────────────────────────────────────────────────
    BP_Frost_T4 = {
        id = "BP_Frost_T4", element = "Frost", tier = 4,
        source = RecipeData.Source.RareDrop,
        forgeLevelRequired = 8,
        materialsRequired = {
            { id = "PureIngot",      qty = 200 },
            { id = "EssenceShard",   qty = 100 },
            { id = "EternalIce",     qty = 20  },
        },
    },
    BP_Storm_T4 = {
        id = "BP_Storm_T4", element = "Storm", tier = 4,
        source = RecipeData.Source.Challenge,
        forgeLevelRequired = 8,
        materialsRequired = {
            { id = "PureIngot",      qty = 200 },
            { id = "EssenceShard",   qty = 100 },
            { id = "ThunderShard",   qty = 30  },
        },
    },
    BP_Void_T4 = {
        id = "BP_Void_T4", element = "Void", tier = 4,
        source = RecipeData.Source.Challenge,
        forgeLevelRequired = 8,
        materialsRequired = {
            { id = "PureIngot",      qty = 200 },
            { id = "EssenceShard",   qty = 100 },
            { id = "VoidEssence",    qty = 25  },
        },
    },

    -- ── Tier 5 (seasonal exclusives) ───────────────────────────────────────
    BP_Season1_MagmaTitan = {
        id = "BP_Season1_MagmaTitan", element = "Ember", tier = 3,
        isEventGolem = true, seasonId = "Season1",
        source = RecipeData.Source.SeasonalEvent,
        materialsRequired = {
            { id = "ElementalIngot", qty = 80  },
            { id = "MoltenCore",     qty = 15  },
            { id = "EventCatalyst",  qty = 1   },
        },
    },
    BP_Season2_CrystalWraith = {
        id = "BP_Season2_CrystalWraith", element = "Frost", tier = 3,
        isEventGolem = true, seasonId = "Season2",
        source = RecipeData.Source.SeasonalEvent,
        materialsRequired = {
            { id = "CrystalFragment", qty = 60 },
            { id = "EternalIce",      qty = 10 },
            { id = "EventCatalyst",   qty = 1  },
        },
    },
    BP_Season3_ThunderColossus = {
        id = "BP_Season3_ThunderColossus", element = "Storm", tier = 4,
        isEventGolem = true, seasonId = "Season3",
        source = RecipeData.Source.SeasonalEvent,
        materialsRequired = {
            { id = "PureIngot",      qty = 100 },
            { id = "ThunderShard",   qty = 30  },
            { id = "EventCatalyst",  qty = 1   },
        },
    },
    BP_Season4_VoidWalker = {
        id = "BP_Season4_VoidWalker", element = "Void", tier = 4,
        isEventGolem = true, seasonId = "Season4",
        source = RecipeData.Source.SeasonalEvent,
        materialsRequired = {
            { id = "PureIngot",    qty = 100 },
            { id = "VoidEssence",  qty = 20  },
            { id = "EventCatalyst", qty = 1  },
        },
    },
    BP_Season5_PrimordialGolem = {
        id = "BP_Season5_PrimordialGolem", element = "All", tier = 5,
        isEventGolem = true, seasonId = "Season5",
        source = RecipeData.Source.SeasonalEvent,
        materialsRequired = {
            { id = "PrimordialIngot", qty = 10 },
            { id = "EssenceShard",    qty = 50 },
            { id = "VoidEssence",     qty = 10 },
            { id = "EventCatalyst",   qty = 3  },
        },
    },
}

-- Blueprints available to all players at game start
RecipeData.StartingBlueprintIds = {
    "BP_Ember_T1", "BP_Stone_T1", "BP_Frost_T1", "BP_Storm_T1", "BP_Void_T1",
}

function RecipeData.Get(id)
    return RecipeData.Blueprints[id]
end

function RecipeData.GetForElement(element, tier)
    for _, bp in pairs(RecipeData.Blueprints) do
        if bp.element == element and bp.tier == tier and not bp.isEventGolem then
            return bp
        end
    end
    return nil
end

return RecipeData
