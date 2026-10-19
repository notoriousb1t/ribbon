-- WoW Forever (1-60) - generated from the route definitions by `build`; do not edit.
-- GEN_HORDEV1_0_MULGORE: 1-11 Mulgore (Tauren) (Levels 1-11)

if not (Ribbon and Ribbon.Guide) then return end

local R = Ribbon.Guide("forever-hordev1", { title = "WoW Forever (1-60)", schema = 1 })

local MAP = {
  MULGORE = 1412,   -- Mulgore
  THE_BARRENS = 1413,   -- The Barrens
  THUNDER_BLUFF = 1456,   -- Thunder Bluff
}

local NPC = {
  GRULL_HAWKWIND = 2980,   -- Grull Hawkwind
  CHIEF_HAWKWIND = 2981,   -- Chief Hawkwind
  GREATMOTHER_HAWKWIND = 2991,   -- Greatmother Hawkwind
  HARUTT_THUNDERHORN = 3059,   -- Harutt Thunderhorn
  SEER_GRAYTONGUE = 2982,   -- Seer Graytongue
  LANKA_FARSHOT = 3061,   -- Lanka Farshot
  MEELA_DAWNSTRIDER = 3062,   -- Meela Dawnstrider
  GART_MISTRUNNER = 3060,   -- Gart Mistrunner
  KRANG_STONEHOOF = 3063,   -- Krang Stonehoof
  MULL_THUNDERHORN = 2948,   -- Mull Thunderhorn
  GENNIA_RUNETOTEM = 3064,   -- Gennia Runetotem
  HARKEN_WINDTOTEM = 2947,   -- Harken Windtotem
  YAW_SHARPMANE = 3065,   -- Yaw Sharpmane
  MORIN_CLOUDSTALKER = 2988,   -- Morin Cloudstalker
  RUUL_EAGLETALON = 2985,   -- Ruul Eagletalon
  BAINE_BLOODHOOF = 2993,   -- Baine Bloodhoof
  MAUR_RAINCALLER = 3055,   -- Maur Raincaller
  NARM_SKYCHASER = 3066,   -- Narm Skychaser
  LOREKEEPER_RAINTOTEM = 3233,   -- Lorekeeper Raintotem
  KIRGE_STERNHORN = 3418,   -- Kirge Sternhorn
  UZZEK = 5810,   -- Uzzek
  KRANAL_FISS = 5907,   -- Kranal Fiss
  THORK = 3429,   -- Thork
  ANSEKHWA = 11869,   -- Ansekhwa
}

local CREATURE = {
  PLAINSTRIDER = 2955,   -- Plainstrider
  MOUNTAIN_COUGAR = 2961,   -- Mountain Cougar
  BRISTLEBACK_QUILBOAR = 2952,   -- Bristleback Quilboar
  BRISTLEBACK_SHAMAN = 2953,   -- Bristleback Shaman
  BRISTLEBACK_BATTLEBOAR = 2954,   -- Bristleback Battleboar
  BATTLEBOAR = 2966,   -- Battleboar
  CHAKUYAK = 268558,   -- Chakuyak
  PRAIRIE_WOLF = 2958,   -- Prairie Wolf
  PRAIRIE_STALKER = 2959,   -- Prairie Stalker
  PRAIRIE_WOLF_ALPHA = 2960,   -- Prairie Wolf Alpha
  ADULT_PLAINSTRIDER = 2956,   -- Adult Plainstrider
  ELDER_PLAINSTRIDER = 2957,   -- Elder Plainstrider
  MAZZRANACHE = 3068,   -- Mazzranache
  GREATER_PLAINSTRIDER = 3244,   -- Greater Plainstrider
  ORNERY_PLAINSTRIDER = 3245,   -- Ornery Plainstrider
  FLEETING_PLAINSTRIDER = 3246,   -- Fleeting Plainstrider
  WINDFURY_HARPY = 2962,   -- Windfury Harpy
  WINDFURY_WIND_WITCH = 2963,   -- Windfury Wind Witch
  FLATLAND_COUGAR = 3035,   -- Flatland Cougar
  WIRY_SWOOP = 2969,   -- Wiry Swoop
  SWOOP = 2970,   -- Swoop
  TALONED_SWOOP = 2971,   -- Taloned Swoop
  PALEMANE_TANNER = 2949,   -- Palemane Tanner
  PALEMANE_SKINNER = 2950,   -- Palemane Skinner
  PALEMANE_POACHER = 2951,   -- Palemane Poacher
  BRISTLEBACK_INTERLOPER = 3232,   -- Bristleback Interloper
  WINDFURY_SORCERESS = 2964,   -- Windfury Sorceress
  WINDFURY_MATRIARCH = 2965,   -- Windfury Matriarch
  VENTURE_CO_WORKER = 2978,   -- Venture Co. Worker
  VENTURE_CO_SUPERVISOR = 2979,   -- Venture Co. Supervisor
  SUPERVISOR_FIZSPROCKET = 3051,   -- Supervisor Fizsprocket
  SAVANNAH_HUNTRESS = 3415,   -- Savannah Huntress
  SUNSCALE_LASHTAIL = 3254,   -- Sunscale Lashtail
  BURNING_BLADE_ACOLYTE = 3380,   -- Burning Blade Acolyte
  RAZORMANE_THORNWEAVER = 3268,   -- Razormane Thornweaver
}

local OBJECT = {
  WATER_PITCHER = 337,   -- Water Pitcher
  WATER_PITCHER_2907 = 2907,   -- Water Pitcher
  SHREDDER_OPERATION_INSTRUCTIONS = 673494,   -- Shredder Operation Instructions
  BARRENS_OPERATIONS_BEST_PRACTICES = 673496,   -- Barrens Operations Best Practices
  ONE_GERENZO_OF_STONETALON = 673497,   -- One "Gerenzo", of Stonetalon
}

local ITEM = {
  PLAINSTRIDER_MEAT = 4739,   -- Plainstrider Meat
  PLAINSTRIDER_FEATHER = 4740,   -- Plainstrider Feather
  WATER_PITCHER = 4755,   -- Water Pitcher
  MOUNTAIN_COUGAR_PELT = 4742,   -- Mountain Cougar Pelt
  POUCH_OF_SMOLDERING_INCENSE = 277199,   -- Pouch of Smoldering Incense
  DIRT_STAINED_MAP = 4851,   -- Dirt-stained Map
  BRISTLEBACK_BELT = 4770,   -- Bristleback Belt
  BATTLEBOAR_SNOUT = 4848,   -- Battleboar Snout
  BATTLEBOAR_FLANK = 4849,   -- Battleboar Flank
  CHAKUYAKS_PELT = 270302,   -- Chakuyak's Pelt
  PRAIRIE_WOLF_PAW = 4758,   -- Prairie Wolf Paw
  PLAINSTRIDER_TALON = 4759,   -- Plainstrider Talon
  BROKEN_TOOLS = 4703,   -- Broken Tools
  WINDFURY_TALON = 4751,   -- Windfury Talon
  STALKER_CLAWS = 4801,   -- Stalker Claws
  COUGAR_CLAWS = 4802,   -- Cougar Claws
  TROPHY_SWOOP_QUILL = 4769,   -- Trophy Swoop Quill
  PRAIRIE_WOLF_HEART = 4804,   -- Prairie Wolf Heart
  FLATLAND_COUGAR_FEMUR = 4805,   -- Flatland Cougar Femur
  PLAINSTRIDER_SCALE = 4806,   -- Plainstrider Scale
  SWOOP_GIZZARD = 4807,   -- Swoop Gizzard
  PRAIRIE_ALPHA_TOOTH = 4803,   -- Prairie Alpha Tooth
  MULGORE_EXPANSION_PLANS = 281031,   -- Mulgore Expansion Plans
  SHREDDER_OPERATION_INSTRUCTIONS = 281035,   -- Shredder Operation Instructions
  BARRENS_OPERATIONS_BEST_PRACTICES = 281036,   -- Barrens Operations Best Practices
  ONE_GERENZO_OF_STONETALON = 281037,   -- One "Gerenzo", of Stonetalon
}

local QUEST = {
  THE_HUNT_BEGINS = 747,   -- The Hunt Begins
  A_HUMBLE_TASK = 752,   -- A Humble Task
  A_HUMBLE_TASK_753 = 753,   -- A Humble Task
  SIMPLE_NOTE = 3091,   -- Simple Note
  ETCHED_NOTE = 3092,   -- Etched Note
  RUNE_INSCRIBED_NOTE = 3093,   -- Rune-Inscribed Note
  VERDANT_NOTE = 3094,   -- Verdant Note
  THE_HUNT_CONTINUES = 750,   -- The Hunt Continues
  RITES_OF_THE_EARTHMOTHER = 755,   -- Rites of the Earthmother
  RITE_OF_STRENGTH = 757,   -- Rite of Strength
  GRACE_OF_ANSHE_AND_MUSHA = 95805,   -- Grace of An'she and Mu'sha
  THE_BATTLEBOARS = 780,   -- The Battleboars
  ATTACK_ON_CAMP_NARACHE = 781,   -- Attack on Camp Narache
  RITES_OF_THE_EARTHMOTHER_763 = 763,   -- Rites of the Earthmother
  SPARRING_MATCH = 99108,   -- Sparring Match
  POISON_WATER = 748,   -- Poison Water
  SWOOP_HUNTING = 761,   -- Swoop Hunting
  CHAKUYAK = 96130,   -- Chakuyak
  THE_RAVAGED_CARAVAN = 749,   -- The Ravaged Caravan
  THE_RAVAGED_CARAVAN_751 = 751,   -- The Ravaged Caravan
  WINTERHOOF_CLEANSING = 754,   -- Winterhoof Cleansing
  THUNDERHORN_TOTEM = 756,   -- Thunderhorn Totem
  DANGERS_OF_THE_WINDFURY = 743,   -- Dangers of the Windfury
  SHARING_THE_LAND = 745,   -- Sharing the Land
  DWARVEN_DIGGING = 746,   -- Dwarven Digging
  MAZZRANACHE = 766,   -- Mazzranache
  THUNDERHORN_CLEANSING = 758,   -- Thunderhorn Cleansing
  WILDMANE_TOTEM = 759,   -- Wildmane Totem
  WILDMANE_CLEANSING = 760,   -- Wildmane Cleansing
  A_SACRED_BURIAL = 833,   -- A Sacred Burial
  THE_VENTURE_CO = 764,   -- The Venture Co.
  FIZSPROCKETS_NOTES = 98424,   -- Fizsprocket's Notes
  VETERAN_UZZEK = 1505,   -- Veteran Uzzek
  TAMING_THE_BEAST = 6061,   -- Taming the Beast
  TAMING_THE_BEAST_6087 = 6087,   -- Taming the Beast
  TAMING_THE_BEAST_6088 = 6088,   -- Taming the Beast
  CALL_OF_FIRE = 2984,   -- Call of Fire
  JOURNEY_TO_THE_CROSSROADS = 854,   -- Journey to the Crossroads
}

local NODE = {
  CAMP_TAURAJO = "Camp Taurajo",   -- Camp Taurajo
  CROSSROADS = "Crossroads",   -- Crossroads
}

local SPAWNS = {
  -- Plainstrider Meat Mulgore
  PLAINSTRIDER_MEAT_MULGORE = {
    { 42.20, 77.70 }, { 42.30, 81.10 }, { 42.80, 77.10 }, { 43.20, 76.20 }, { 43.30, 84.20 }, { 43.80, 79.80 },
    { 43.80, 84.10 }, { 43.90, 83.20 }, { 43.90, 86.40 }, { 44.30, 83.10 }, { 44.80, 81.60 }, { 44.80, 84.60 },
    { 44.90, 79.20 }, { 45.20, 80.20 }, { 45.30, 74.30 }, { 45.40, 84.30 }, { 45.50, 82.80 }, { 45.80, 74.70 },
    { 45.90, 81.80 }, { 45.90, 84.30 }, { 46.00, 80.80 }, { 46.00, 84.10 }, { 46.30, 76.30 }, { 46.40, 85.30 },
    { 46.70, 79.20 }, { 46.90, 83.40 }, { 47.00, 77.80 }, { 47.00, 85.50 }, { 47.10, 77.50 }, { 47.20, 81.50 },
    { 47.50, 76.80 }, { 47.60, 86.40 }, { 47.70, 82.40 }, { 48.10, 76.30 }, { 48.20, 80.30 }, { 48.40, 78.20 },
    { 48.40, 84.90 }, { 48.50, 78.80 }, { 48.70, 82.80 }, { 48.80, 85.80 }, { 49.20, 84.80 }, { 49.30, 77.50 },
    { 49.30, 79.20 }, { 49.40, 85.80 }, { 49.50, 83.10 }, { 49.60, 76.70 }, { 49.80, 76.80 }, { 50.00, 75.70 },
    { 50.00, 84.70 }, { 50.30, 79.80 }, { 50.30, 82.50 }, { 50.40, 77.60 }, { 50.60, 75.60 }, { 50.60, 81.10 },
    { 50.90, 86.20 }, { 51.10, 82.20 }, { 51.40, 81.60 }, { 51.60, 83.40 }, { 52.00, 82.30 }, { 52.00, 85.70 },
  },
  -- Water Pitcher Mulgore
  WATER_PITCHER_MULGORE = {
    { 48.90, 81.10 }, { 48.90, 81.20 }, { 49.00, 81.10 }, { 49.00, 81.30 },
  },
  -- Mountain Cougar Pelt Mulgore
  MOUNTAIN_COUGAR_PELT_MULGORE = {
    { 40.50, 82.70 }, { 41.10, 81.70 }, { 41.10, 87.40 }, { 41.70, 83.50 }, { 41.70, 87.20 }, { 41.80, 86.10 },
    { 42.10, 86.60 }, { 42.10, 87.30 }, { 42.20, 84.10 }, { 42.40, 84.90 }, { 42.70, 86.30 }, { 43.10, 89.40 },
    { 43.20, 87.10 }, { 43.20, 88.20 }, { 43.40, 88.30 }, { 43.50, 90.10 }, { 43.90, 92.00 }, { 44.40, 86.90 },
    { 44.40, 89.60 }, { 44.40, 90.70 }, { 44.60, 91.80 }, { 44.70, 89.90 }, { 44.90, 87.30 }, { 45.20, 88.00 },
    { 45.40, 88.20 }, { 46.10, 90.00 }, { 46.50, 88.20 }, { 46.60, 90.60 }, { 47.00, 88.80 }, { 47.00, 89.80 },
    { 47.50, 90.10 }, { 47.60, 89.50 }, { 47.70, 87.50 }, { 48.00, 88.40 }, { 48.10, 89.60 }, { 48.60, 86.40 },
    { 48.70, 88.70 }, { 49.20, 88.20 }, { 49.60, 87.40 }, { 49.70, 89.30 }, { 50.40, 90.30 }, { 50.60, 89.00 },
    { 50.90, 87.70 }, { 51.40, 89.30 }, { 51.40, 90.40 }, { 51.60, 87.80 }, { 51.80, 89.10 }, { 51.90, 88.20 },
    { 52.00, 87.60 }, { 52.00, 88.90 }, { 52.80, 87.70 }, { 53.00, 88.70 }, { 53.60, 89.80 }, { 53.60, 91.70 },
    { 53.70, 88.60 }, { 54.10, 90.60 }, { 54.10, 91.50 }, { 54.20, 89.20 }, { 55.10, 88.90 }, { 55.20, 91.50 },
  },
  -- Bristleback Belt Mulgore
  BRISTLEBACK_BELT_MULGORE = {
    { 55.30, 81.40 }, { 55.80, 78.60 }, { 55.80, 81.40 }, { 55.90, 79.80 }, { 56.10, 78.40 }, { 56.40, 83.90 },
    { 56.50, 78.50 }, { 56.50, 78.70 }, { 56.50, 83.30 }, { 56.60, 78.30 }, { 56.70, 76.10 }, { 56.70, 79.50 },
    { 56.80, 77.40 }, { 56.90, 79.30 }, { 56.90, 81.70 }, { 57.10, 76.00 }, { 57.10, 80.00 }, { 57.20, 76.60 },
    { 57.20, 78.40 }, { 57.20, 81.90 }, { 57.30, 80.70 }, { 57.40, 82.40 }, { 57.50, 83.50 }, { 57.70, 75.60 },
    { 57.70, 76.00 }, { 57.70, 77.30 }, { 57.80, 84.00 }, { 57.90, 81.60 }, { 58.40, 76.70 }, { 58.40, 77.50 },
    { 58.40, 78.90 }, { 58.40, 80.90 }, { 58.60, 76.50 }, { 58.60, 81.10 }, { 58.70, 83.00 }, { 58.90, 81.70 },
    { 59.00, 79.70 }, { 59.00, 81.20 }, { 59.60, 77.70 }, { 59.70, 78.50 }, { 59.80, 82.30 }, { 60.10, 76.80 },
    { 60.20, 77.40 }, { 60.30, 77.20 }, { 60.30, 79.70 }, { 60.30, 79.80 }, { 60.30, 80.90 }, { 60.40, 78.50 },
    { 60.50, 77.70 }, { 60.60, 78.10 }, { 60.70, 78.50 }, { 60.70, 79.20 }, { 60.80, 78.00 }, { 61.10, 78.20 },
    { 61.10, 79.50 }, { 61.30, 78.80 }, { 61.40, 78.20 }, { 61.90, 78.20 }, { 61.90, 78.50 }, { 62.10, 77.50 },
  },
  -- Battleboar Snout Mulgore
  BATTLEBOAR_SNOUT_MULGORE = {
    { 50.30, 77.60 }, { 50.70, 75.80 }, { 50.90, 79.30 }, { 50.90, 80.10 }, { 51.30, 78.00 }, { 51.40, 76.80 },
    { 51.50, 79.40 }, { 51.90, 81.60 }, { 52.10, 77.40 }, { 52.30, 81.50 }, { 52.40, 76.90 }, { 52.60, 80.00 },
    { 52.60, 83.30 }, { 52.90, 77.60 }, { 52.90, 80.70 }, { 52.90, 81.50 }, { 53.00, 76.00 }, { 53.00, 79.40 },
    { 53.00, 84.70 }, { 53.00, 85.60 }, { 53.10, 78.30 }, { 53.30, 81.70 }, { 53.50, 80.10 }, { 53.50, 85.10 },
    { 53.60, 76.70 }, { 53.60, 86.60 }, { 53.80, 81.60 }, { 53.90, 83.50 }, { 54.00, 84.30 }, { 54.10, 83.30 },
    { 54.10, 84.90 }, { 54.20, 81.60 }, { 54.20, 86.20 }, { 54.50, 86.70 }, { 54.50, 87.40 }, { 54.50, 88.40 },
    { 54.60, 84.10 }, { 55.10, 85.60 }, { 55.10, 88.40 }, { 55.60, 86.70 }, { 55.70, 87.30 }, { 56.00, 88.40 },
    { 56.30, 77.60 }, { 56.60, 87.10 }, { 56.60, 88.80 }, { 56.70, 88.70 }, { 56.90, 78.60 }, { 57.30, 87.30 },
    { 57.90, 85.40 }, { 58.00, 80.50 }, { 58.00, 84.30 }, { 58.30, 76.40 }, { 59.00, 79.30 }, { 59.50, 76.70 },
    { 60.10, 79.20 }, { 60.20, 78.60 }, { 60.20, 81.40 }, { 60.40, 77.90 }, { 60.70, 78.80 }, { 61.80, 78.20 },
  },
  -- Chakuyak's Pelt Mulgore
  CHAKUYAKS_PELT_MULGORE = {
    { 39.40, 62.40 }, { 39.40, 63.00 }, { 39.40, 64.40 }, { 39.40, 65.40 }, { 39.40, 66.00 }, { 39.40, 67.20 },
    { 39.60, 63.00 }, { 39.60, 64.40 }, { 39.60, 65.80 }, { 39.60, 66.80 }, { 39.80, 65.20 },
  },
  -- Prairie Wolf Paw Mulgore
  PRAIRIE_WOLF_PAW_MULGORE = {
    { 34.00, 29.90 }, { 35.60, 39.10 }, { 36.20, 57.10 }, { 36.30, 78.20 }, { 36.80, 43.50 }, { 37.10, 61.30 },
    { 37.30, 71.90 }, { 37.50, 72.90 }, { 38.00, 26.10 }, { 38.40, 58.90 }, { 38.80, 56.70 }, { 38.90, 68.00 },
    { 39.50, 66.80 }, { 39.80, 70.30 }, { 40.10, 59.60 }, { 40.50, 54.60 }, { 41.00, 56.40 }, { 41.10, 68.40 },
    { 41.60, 54.20 }, { 41.70, 67.90 }, { 42.00, 74.70 }, { 42.20, 51.60 }, { 42.70, 52.60 }, { 43.10, 53.10 },
    { 43.80, 47.50 }, { 44.60, 54.10 }, { 44.90, 37.50 }, { 45.30, 36.50 }, { 45.90, 53.20 }, { 46.50, 54.90 },
    { 47.10, 37.00 }, { 47.70, 39.10 }, { 48.10, 23.40 }, { 48.30, 46.50 }, { 48.90, 43.90 }, { 49.30, 24.00 },
    { 49.70, 25.00 }, { 49.90, 53.20 }, { 50.40, 29.80 }, { 50.90, 50.20 }, { 51.60, 71.40 }, { 52.00, 61.30 },
    { 52.50, 50.10 }, { 53.10, 55.10 }, { 53.70, 50.90 }, { 54.10, 62.90 }, { 54.50, 62.10 }, { 54.80, 37.10 },
    { 55.00, 56.30 }, { 55.30, 70.10 }, { 55.90, 65.40 }, { 56.30, 69.30 }, { 57.40, 64.70 }, { 57.90, 68.60 },
    { 58.60, 71.00 }, { 59.50, 63.00 }, { 60.00, 60.10 }, { 61.00, 64.10 }, { 61.80, 61.00 }, { 62.70, 62.20 },
  },
  -- Plainstrider Talon Mulgore
  PLAINSTRIDER_TALON_MULGORE = {
    { 34.80, 35.30 }, { 35.70, 41.60 }, { 36.30, 68.60 }, { 36.80, 72.80 }, { 37.40, 58.20 }, { 37.80, 68.10 },
    { 38.00, 49.10 }, { 38.50, 75.90 }, { 38.90, 66.10 }, { 39.70, 68.80 }, { 40.00, 64.80 }, { 40.80, 56.00 },
    { 41.10, 74.30 }, { 42.00, 68.60 }, { 42.20, 77.70 }, { 42.70, 69.50 }, { 43.20, 81.40 }, { 43.50, 21.70 },
    { 43.80, 84.10 }, { 44.00, 74.90 }, { 44.50, 47.20 }, { 44.80, 84.60 }, { 45.20, 80.20 }, { 45.40, 72.60 },
    { 45.50, 82.80 }, { 45.80, 75.80 }, { 46.00, 80.80 }, { 46.30, 76.30 }, { 46.50, 28.70 }, { 46.80, 34.20 },
    { 47.00, 77.00 }, { 47.20, 21.50 }, { 47.60, 26.60 }, { 47.80, 77.40 }, { 48.10, 37.90 }, { 48.40, 78.20 },
    { 48.60, 37.60 }, { 48.80, 85.80 }, { 49.20, 87.20 }, { 49.30, 81.00 }, { 49.60, 76.70 }, { 49.80, 28.70 },
    { 50.00, 75.70 }, { 50.30, 82.50 }, { 50.40, 81.50 }, { 50.80, 41.90 }, { 50.90, 40.30 }, { 51.30, 87.30 },
    { 51.80, 29.60 }, { 52.00, 64.60 }, { 52.30, 32.30 }, { 52.60, 70.40 }, { 53.50, 34.50 }, { 53.70, 60.30 },
    { 54.40, 50.50 }, { 55.20, 58.20 }, { 55.50, 68.80 }, { 56.70, 60.80 }, { 57.90, 67.10 }, { 59.30, 58.90 },
  },
  -- Broken Tools Mulgore
  BROKEN_TOOLS_MULGORE = {
    { 33.10, 54.80 }, { 58.10, 52.50 },
  },
  -- Windfury Talon Mulgore
  WINDFURY_TALON_MULGORE = {
    { 32.90, 47.50 }, { 33.00, 48.40 }, { 33.50, 46.80 }, { 33.50, 48.40 }, { 33.60, 47.70 }, { 33.60, 49.10 },
    { 34.00, 48.30 }, { 34.00, 49.10 }, { 34.10, 47.50 }, { 34.60, 48.40 }, { 34.60, 49.10 }, { 35.10, 47.50 },
    { 35.10, 48.20 }, { 35.10, 49.20 }, { 35.20, 46.80 }, { 35.60, 48.30 }, { 35.60, 49.20 }, { 35.70, 47.60 },
    { 35.70, 49.90 }, { 58.50, 72.80 }, { 58.50, 73.60 }, { 59.10, 72.70 }, { 59.20, 72.80 }, { 59.60, 72.00 },
    { 60.10, 72.00 }, { 60.10, 72.70 }, { 60.20, 73.60 }, { 60.60, 71.90 }, { 61.10, 71.10 }, { 61.20, 72.40 },
    { 61.60, 70.80 }, { 61.70, 72.00 }, { 61.80, 70.30 }, { 62.20, 70.20 }, { 62.20, 71.80 }, { 62.30, 71.20 },
    { 62.70, 70.30 }, { 62.80, 71.30 }, { 62.80, 71.80 }, { 62.90, 72.50 }, { 63.30, 72.00 }, { 63.40, 71.20 },
    { 63.40, 72.80 }, { 63.40, 73.50 }, { 63.80, 71.20 }, { 63.80, 72.60 },
  },
  -- Stalker Claws Mulgore
  STALKER_CLAWS_MULGORE = {
    { 35.20, 37.10 }, { 35.70, 36.30 }, { 36.20, 49.10 }, { 36.60, 54.90 }, { 37.00, 41.00 }, { 37.90, 41.80 },
    { 38.30, 42.70 }, { 39.50, 46.20 }, { 40.50, 54.60 }, { 41.30, 49.90 }, { 41.60, 50.90 }, { 41.80, 46.70 },
    { 41.90, 55.70 }, { 42.20, 48.00 }, { 42.20, 51.60 }, { 42.80, 55.20 }, { 43.10, 53.10 }, { 43.30, 48.30 },
    { 44.40, 45.20 }, { 44.60, 54.10 }, { 44.90, 40.90 }, { 45.00, 41.70 }, { 45.90, 54.00 }, { 46.00, 50.80 },
    { 46.20, 44.80 }, { 46.90, 52.30 }, { 47.10, 45.90 }, { 47.60, 44.70 }, { 47.90, 49.20 }, { 48.20, 52.50 },
    { 48.70, 49.20 }, { 48.90, 43.90 }, { 49.60, 52.10 }, { 49.80, 41.60 }, { 50.00, 45.60 }, { 50.30, 49.20 },
    { 50.90, 49.20 }, { 51.70, 50.70 }, { 51.90, 50.80 }, { 52.50, 44.30 }, { 53.00, 50.20 }, { 53.30, 53.40 },
    { 53.60, 61.50 }, { 54.10, 62.90 }, { 54.50, 62.10 }, { 54.70, 50.30 }, { 54.80, 67.90 }, { 55.00, 56.30 },
    { 55.10, 52.60 }, { 55.20, 72.00 }, { 55.40, 50.40 }, { 55.60, 55.50 }, { 56.10, 56.70 }, { 56.20, 67.10 },
    { 56.40, 72.50 }, { 56.80, 68.20 }, { 57.30, 62.70 }, { 57.60, 63.80 }, { 57.90, 60.00 }, { 58.00, 69.70 },
  },
  -- Cougar Claws Mulgore
  COUGAR_CLAWS_MULGORE = {
    { 35.10, 34.50 }, { 35.50, 35.20 }, { 35.80, 40.50 }, { 36.20, 56.50 }, { 36.30, 41.10 }, { 37.40, 53.80 },
    { 37.60, 49.00 }, { 37.80, 53.80 }, { 38.30, 46.00 }, { 39.00, 51.30 }, { 39.40, 46.00 }, { 39.60, 47.60 },
    { 40.10, 51.60 }, { 42.00, 54.90 }, { 42.20, 44.30 }, { 43.20, 51.00 }, { 43.70, 56.70 }, { 44.30, 39.50 },
    { 44.70, 52.70 }, { 45.10, 45.00 }, { 45.40, 38.70 }, { 46.00, 43.60 }, { 46.50, 42.40 }, { 46.50, 46.80 },
    { 47.10, 40.20 }, { 47.20, 42.60 }, { 47.60, 47.70 }, { 48.10, 50.90 }, { 48.20, 44.50 }, { 48.60, 47.50 },
    { 49.10, 41.60 }, { 49.10, 49.30 }, { 49.30, 47.10 }, { 49.30, 48.20 }, { 50.10, 47.80 }, { 50.50, 40.80 },
    { 50.50, 44.30 }, { 51.10, 44.30 }, { 51.40, 42.30 }, { 51.40, 46.70 }, { 52.00, 43.20 }, { 52.10, 45.10 },
    { 52.50, 42.70 }, { 52.50, 52.40 }, { 52.90, 51.50 }, { 53.10, 45.20 }, { 53.50, 42.90 }, { 53.60, 44.20 },
    { 53.80, 48.20 }, { 53.90, 44.90 }, { 54.20, 53.40 }, { 54.40, 43.50 }, { 54.70, 65.60 }, { 54.80, 54.10 },
    { 55.10, 54.40 }, { 55.20, 73.20 }, { 56.30, 61.60 }, { 56.60, 57.80 }, { 56.80, 58.70 }, { 56.90, 67.20 },
  },
  -- Trophy Swoop Quill Mulgore
  TROPHY_SWOOP_QUILL_MULGORE = {
    { 35.50, 78.50 }, { 36.10, 48.90 }, { 36.30, 68.70 }, { 36.40, 54.50 }, { 37.20, 50.70 }, { 37.80, 71.90 },
    { 38.40, 27.60 }, { 38.40, 47.50 }, { 38.40, 65.40 }, { 38.70, 68.60 }, { 39.50, 58.00 }, { 39.50, 61.50 },
    { 40.90, 58.50 }, { 41.00, 66.10 }, { 41.10, 62.20 }, { 41.20, 68.50 }, { 41.70, 53.70 }, { 42.20, 21.50 },
    { 42.70, 46.40 }, { 42.70, 50.90 }, { 42.80, 56.50 }, { 43.20, 54.20 }, { 44.30, 42.30 }, { 44.30, 72.00 },
    { 45.90, 24.40 }, { 46.00, 21.60 }, { 46.00, 42.20 }, { 46.60, 43.70 }, { 47.60, 50.00 }, { 47.80, 20.80 },
    { 48.10, 45.20 }, { 48.40, 47.10 }, { 48.60, 50.20 }, { 48.70, 70.40 }, { 49.40, 37.30 }, { 50.20, 29.90 },
    { 50.20, 46.80 }, { 50.30, 26.90 }, { 50.50, 44.20 }, { 50.50, 50.00 }, { 50.60, 38.40 }, { 50.90, 24.70 },
    { 51.50, 28.90 }, { 51.90, 39.90 }, { 51.90, 47.20 }, { 51.90, 50.80 }, { 52.00, 35.30 }, { 52.00, 62.10 },
    { 53.10, 71.90 }, { 53.20, 48.50 }, { 53.40, 40.20 }, { 54.40, 51.60 }, { 55.00, 53.80 }, { 55.20, 31.90 },
    { 55.40, 37.20 }, { 55.70, 56.50 }, { 56.20, 67.00 }, { 56.90, 63.00 }, { 57.30, 59.00 }, { 61.20, 62.90 },
  },
  -- Palemane Tanner Mulgore
  PALEMANE_TANNER_MULGORE = {
    { 33.40, 63.60 }, { 33.80, 63.10 }, { 34.30, 64.10 }, { 34.40, 64.80 }, { 34.60, 64.20 }, { 34.60, 65.10 },
    { 34.90, 64.20 }, { 36.20, 65.50 }, { 36.60, 65.00 }, { 36.60, 65.20 }, { 36.70, 65.30 }, { 36.80, 64.60 },
    { 36.80, 66.10 }, { 46.50, 72.80 }, { 47.40, 73.10 }, { 47.40, 73.60 }, { 47.70, 72.60 }, { 48.10, 72.80 },
    { 48.20, 73.40 }, { 50.90, 73.40 }, { 51.60, 74.60 }, { 51.80, 75.00 }, { 51.90, 73.60 }, { 52.50, 74.40 },
    { 52.90, 73.30 },
  },
  -- Palemane Skinner Mulgore
  PALEMANE_SKINNER_MULGORE = {
    { 31.70, 63.50 }, { 32.20, 63.80 }, { 32.30, 63.00 }, { 32.50, 63.70 }, { 32.60, 64.10 }, { 33.40, 63.30 },
    { 33.50, 63.80 }, { 33.90, 63.70 }, { 34.10, 64.20 }, { 34.60, 64.60 }, { 36.30, 64.70 }, { 36.30, 66.10 },
    { 46.50, 73.50 }, { 47.10, 72.60 }, { 47.10, 74.30 }, { 47.30, 73.30 }, { 47.60, 73.10 }, { 47.70, 74.40 },
    { 50.90, 74.20 }, { 51.40, 75.10 }, { 51.50, 74.10 }, { 52.50, 73.00 }, { 53.50, 73.10 },
  },
  -- Palemane Poacher Mulgore
  PALEMANE_POACHER_MULGORE = {
    { 32.20, 63.70 }, { 32.20, 64.50 }, { 32.30, 64.20 }, { 32.40, 64.80 }, { 32.70, 63.60 }, { 32.70, 63.70 },
    { 32.70, 65.30 }, { 32.80, 64.50 }, { 32.90, 63.60 }, { 33.00, 64.20 }, { 33.10, 65.10 }, { 33.20, 64.70 },
    { 51.20, 74.50 }, { 51.40, 73.70 }, { 51.80, 73.60 }, { 52.10, 73.10 }, { 52.40, 73.20 }, { 52.90, 74.10 },
    { 53.10, 74.20 },
  },
  -- Prairie Alpha Tooth Mulgore
  PRAIRIE_ALPHA_TOOTH_MULGORE = {
    { 34.00, 29.90 }, { 37.30, 26.40 }, { 39.50, 28.00 }, { 41.00, 28.70 }, { 41.10, 22.40 }, { 42.70, 21.60 },
    { 43.20, 20.70 }, { 43.80, 38.40 }, { 44.80, 26.40 }, { 44.90, 28.00 }, { 44.90, 37.50 }, { 45.00, 35.90 },
    { 45.60, 35.40 }, { 47.10, 37.00 }, { 47.80, 32.90 }, { 48.00, 38.80 }, { 48.10, 23.40 }, { 48.10, 24.90 },
    { 48.70, 23.00 }, { 49.10, 37.90 }, { 49.20, 40.10 }, { 49.30, 24.00 }, { 49.50, 31.50 }, { 49.80, 20.70 },
    { 50.40, 29.80 }, { 50.70, 25.90 }, { 51.00, 30.40 }, { 51.30, 24.00 }, { 51.50, 37.70 }, { 52.20, 41.50 },
    { 53.80, 39.30 }, { 54.00, 30.60 }, { 54.40, 36.90 }, { 54.70, 34.50 }, { 54.80, 37.10 }, { 55.00, 39.30 },
    { 55.60, 36.50 }, { 56.30, 37.40 }, { 58.30, 61.30 }, { 58.40, 69.70 }, { 58.80, 60.10 }, { 59.00, 61.30 },
    { 59.00, 67.90 }, { 59.50, 63.00 }, { 59.50, 64.70 }, { 59.50, 70.00 }, { 60.00, 60.10 }, { 60.00, 70.90 },
    { 60.40, 63.00 }, { 60.90, 62.50 }, { 61.00, 69.80 }, { 61.10, 69.20 }, { 61.50, 65.90 }, { 61.80, 61.00 },
    { 62.00, 63.00 }, { 62.20, 68.10 }, { 62.30, 62.30 }, { 62.70, 62.20 }, { 62.80, 61.70 }, { 62.80, 66.20 },
  },
  -- Windfury Wind Witch Mulgore
  WINDFURY_WIND_WITCH_MULGORE = {
    { 33.60, 47.70 }, { 33.60, 49.10 }, { 34.60, 48.40 }, { 34.60, 49.10 }, { 35.10, 48.20 }, { 35.20, 46.80 },
    { 35.60, 49.20 }, { 35.70, 47.60 }, { 35.70, 49.90 }, { 58.50, 73.60 }, { 60.10, 72.70 }, { 61.60, 70.80 },
    { 61.70, 72.00 }, { 62.20, 70.20 }, { 62.80, 71.30 }, { 63.30, 72.00 }, { 63.40, 72.80 }, { 63.80, 71.20 },
    { 63.80, 72.60 },
  },
  -- Bristleback Interloper Mulgore
  BRISTLEBACK_INTERLOPER_MULGORE = {
    { 57.20, 29.90 }, { 57.20, 30.60 }, { 57.30, 31.20 }, { 57.40, 30.20 }, { 57.40, 31.50 }, { 57.50, 29.40 },
    { 57.80, 29.90 }, { 57.80, 30.80 }, { 57.80, 31.90 }, { 57.90, 29.50 }, { 57.90, 30.60 }, { 58.00, 30.90 },
    { 58.10, 32.20 }, { 58.20, 30.30 }, { 58.20, 30.50 }, { 58.20, 31.40 }, { 58.30, 32.20 }, { 58.50, 29.40 },
    { 58.50, 31.00 }, { 58.50, 31.20 }, { 58.60, 30.00 }, { 58.60, 31.60 }, { 58.60, 32.00 }, { 58.80, 32.00 },
    { 58.90, 30.30 }, { 59.00, 31.10 }, { 59.00, 31.60 }, { 59.10, 30.70 },
  },
  -- Windfury Sorceress Mulgore
  WINDFURY_SORCERESS_MULGORE = {
    { 30.70, 31.00 }, { 31.40, 30.70 }, { 31.40, 32.20 }, { 31.40, 34.60 }, { 31.80, 31.20 }, { 31.80, 33.80 },
    { 31.80, 35.20 }, { 31.80, 36.10 }, { 31.90, 33.00 }, { 32.40, 32.20 }, { 32.40, 34.70 }, { 32.50, 30.50 },
    { 32.50, 35.30 }, { 32.90, 31.20 }, { 32.90, 34.40 }, { 32.90, 36.80 }, { 33.00, 29.60 }, { 33.00, 32.90 },
    { 33.40, 32.20 }, { 33.50, 30.60 }, { 33.50, 32.90 }, { 34.10, 33.80 }, { 36.20, 24.60 }, { 36.90, 23.10 },
    { 37.30, 21.40 }, { 37.80, 22.30 }, { 37.80, 23.20 }, { 38.70, 19.90 }, { 38.90, 18.10 }, { 38.90, 20.70 },
    { 39.40, 20.70 }, { 40.00, 18.30 }, { 40.00, 19.80 }, { 40.50, 17.60 }, { 40.50, 19.10 }, { 49.70, 19.10 },
    { 50.20, 19.20 }, { 50.30, 17.60 }, { 51.60, 18.20 }, { 52.40, 22.10 }, { 52.50, 23.30 }, { 53.00, 26.60 },
    { 53.10, 22.90 }, { 53.60, 27.40 }, { 54.10, 24.60 }, { 54.10, 25.70 }, { 54.10, 26.30 },
  },
  -- Windfury Matriarch Mulgore
  WINDFURY_MATRIARCH_MULGORE = {
    { 31.20, 31.30 }, { 31.80, 29.50 }, { 31.80, 34.60 }, { 31.90, 32.00 }, { 32.00, 30.50 }, { 32.30, 29.60 },
    { 32.30, 31.30 }, { 32.30, 36.20 }, { 32.40, 32.90 }, { 32.50, 33.80 }, { 32.80, 33.60 }, { 32.90, 36.30 },
    { 33.00, 32.20 }, { 33.00, 35.30 }, { 33.40, 35.40 }, { 33.40, 36.80 }, { 33.50, 31.30 }, { 33.60, 33.70 },
    { 34.10, 32.90 }, { 34.10, 34.40 }, { 34.10, 36.20 }, { 34.60, 33.80 }, { 36.40, 23.90 }, { 37.30, 22.30 },
    { 37.30, 23.10 }, { 37.70, 20.90 }, { 38.40, 21.60 }, { 38.70, 19.00 }, { 38.90, 19.80 }, { 39.40, 17.80 },
    { 39.90, 17.40 }, { 39.90, 19.10 }, { 40.50, 20.00 }, { 40.60, 18.40 }, { 41.10, 17.50 }, { 49.30, 17.50 },
    { 49.70, 17.60 }, { 49.80, 18.20 }, { 50.40, 18.20 }, { 51.00, 17.80 }, { 53.00, 20.90 }, { 53.00, 22.40 },
    { 53.10, 21.40 }, { 53.50, 23.40 }, { 53.60, 26.50 }, { 54.00, 23.90 },
  },
  -- Venture Co. Worker Mulgore
  VENTURE_CO_WORKER_MULGORE = {
    { 40.00, 25.70 }, { 40.50, 25.50 }, { 40.60, 27.30 }, { 41.20, 27.20 }, { 42.50, 25.20 }, { 42.80, 25.00 },
    { 43.00, 25.20 }, { 56.80, 53.60 }, { 57.10, 49.00 }, { 57.10, 53.70 }, { 57.20, 54.20 }, { 57.30, 53.80 },
    { 57.50, 54.20 }, { 57.60, 53.80 }, { 57.90, 44.50 }, { 58.00, 46.40 }, { 58.00, 48.80 }, { 58.10, 42.70 },
    { 58.10, 46.40 }, { 58.30, 44.00 }, { 58.40, 48.80 }, { 58.50, 42.90 }, { 58.70, 48.20 }, { 58.70, 51.90 },
    { 58.80, 42.90 }, { 58.80, 51.20 }, { 58.90, 51.60 }, { 59.00, 47.30 }, { 59.00, 49.90 }, { 59.10, 45.60 },
    { 59.20, 46.40 }, { 59.20, 50.30 }, { 59.40, 44.30 }, { 59.40, 45.00 }, { 59.40, 51.50 }, { 59.50, 46.30 },
    { 59.50, 49.90 }, { 59.60, 47.30 }, { 59.60, 49.50 }, { 59.70, 48.80 }, { 59.80, 48.50 }, { 59.90, 46.70 },
    { 59.90, 48.00 }, { 60.60, 46.60 }, { 60.60, 48.80 }, { 60.80, 48.70 }, { 60.90, 48.90 }, { 61.20, 45.60 },
    { 61.30, 49.10 }, { 61.40, 44.60 }, { 61.40, 49.40 }, { 61.50, 45.20 }, { 61.60, 47.60 }, { 61.70, 49.40 },
    { 61.80, 47.10 }, { 61.90, 45.70 }, { 61.90, 49.40 }, { 62.20, 45.90 }, { 62.50, 45.80 }, { 62.80, 46.00 },
  },
  -- Venture Co. Supervisor Mulgore
  VENTURE_CO_SUPERVISOR_MULGORE = {
    { 40.40, 26.20 }, { 40.80, 26.80 }, { 42.60, 25.00 }, { 42.80, 24.70 }, { 56.20, 42.40 }, { 56.30, 42.40 },
    { 56.30, 42.50 }, { 56.30, 43.80 }, { 56.40, 43.20 }, { 57.20, 41.70 }, { 57.30, 53.50 }, { 57.40, 53.70 },
    { 57.50, 43.70 }, { 57.50, 48.50 }, { 57.70, 42.20 }, { 57.70, 43.70 }, { 57.70, 44.00 }, { 57.70, 45.10 },
    { 57.80, 44.90 }, { 57.80, 46.00 }, { 57.80, 48.20 }, { 57.80, 48.70 }, { 57.90, 43.90 }, { 57.90, 44.20 },
    { 58.00, 44.90 }, { 58.00, 47.50 }, { 58.10, 48.30 }, { 58.20, 47.70 }, { 58.30, 47.20 }, { 58.30, 52.80 },
    { 58.40, 52.30 }, { 58.50, 47.40 }, { 58.50, 52.20 }, { 58.60, 51.60 }, { 58.70, 47.60 }, { 58.90, 45.30 },
    { 58.90, 46.20 }, { 58.90, 48.30 }, { 59.00, 51.50 }, { 59.10, 44.90 }, { 59.10, 51.30 }, { 59.30, 47.10 },
    { 59.40, 48.30 }, { 59.60, 46.10 }, { 59.70, 45.20 }, { 59.80, 50.60 }, { 59.80, 50.70 }, { 60.00, 46.80 },
    { 60.00, 47.30 }, { 60.20, 45.70 }, { 60.40, 45.80 }, { 60.80, 45.80 }, { 60.90, 50.30 }, { 61.10, 49.70 },
    { 61.10, 50.00 }, { 61.20, 46.20 }, { 61.40, 45.70 }, { 61.50, 46.30 }, { 61.70, 45.60 }, { 61.80, 46.50 },
  },
  -- Shredder Operation Instructions Mulgore
  SHREDDER_OPERATION_INSTRUCTIONS_MULGORE = {
    { 58.60, 47.40 },
  },
  -- Barrens Operations Best Practices Mulgore
  BARRENS_OPERATIONS_BEST_PRACTICES_MULGORE = {
    { 61.70, 47.30 },
  },
  -- One "Gerenzo", of Stonetalon Mulgore
  ONE_GERENZO_OF_STONETALON_MULGORE = {
    { 59.00, 46.40 }, { 59.00, 46.50 },
  },
  -- Mulgore Expansion Plans Mulgore
  MULGORE_EXPANSION_PLANS_MULGORE = {
    { 61.20, 49.30 },
  },
  -- Greater Plainstrider The Barrens
  GREATER_PLAINSTRIDER_THE_BARRENS = {
    { 47.30, 14.10 }, { 47.30, 14.90 }, { 47.80, 14.60 }, { 47.80, 25.60 }, { 48.00, 14.30 }, { 48.10, 15.30 },
    { 48.20, 28.60 }, { 48.50, 23.50 }, { 48.60, 13.80 }, { 48.60, 26.50 }, { 48.70, 23.00 }, { 48.70, 25.00 },
    { 48.80, 23.60 }, { 49.10, 22.80 }, { 49.10, 29.50 }, { 49.30, 14.30 }, { 49.30, 22.80 }, { 49.40, 29.80 },
    { 49.60, 30.30 }, { 50.30, 31.00 }, { 50.40, 30.60 }, { 50.40, 33.40 }, { 50.70, 15.30 }, { 50.70, 27.80 },
    { 50.90, 19.50 }, { 51.00, 15.60 }, { 51.00, 27.60 }, { 51.00, 31.80 }, { 51.20, 16.90 }, { 51.20, 17.30 },
    { 51.30, 18.10 }, { 51.40, 19.40 }, { 51.40, 22.10 }, { 51.60, 21.60 }, { 51.70, 18.70 }, { 51.70, 27.60 },
    { 51.80, 19.70 }, { 52.00, 27.10 }, { 52.10, 20.30 }, { 52.40, 21.80 }, { 52.70, 25.60 }, { 52.70, 26.10 },
    { 52.80, 28.20 }, { 52.90, 22.70 }, { 53.00, 23.70 }, { 53.00, 26.60 }, { 53.10, 30.40 }, { 53.10, 31.50 },
    { 53.30, 22.20 }, { 53.30, 29.10 }, { 53.40, 32.40 }, { 53.60, 29.50 }, { 53.60, 30.50 }, { 53.90, 28.50 },
    { 53.90, 29.00 }, { 54.00, 23.60 }, { 54.00, 28.00 }, { 54.60, 32.10 }, { 54.70, 23.40 }, { 55.50, 25.10 },
  },
  -- Savannah Huntress The Barrens
  SAVANNAH_HUNTRESS_THE_BARRENS = {
    { 49.10, 27.60 }, { 49.40, 26.90 }, { 49.50, 27.60 }, { 49.60, 15.60 }, { 49.70, 15.10 }, { 49.80, 15.30 },
    { 50.00, 15.40 }, { 50.00, 23.50 }, { 50.00, 31.80 }, { 50.20, 16.30 }, { 50.20, 23.00 }, { 50.20, 23.40 },
    { 50.40, 15.20 }, { 50.40, 15.60 }, { 50.40, 23.50 }, { 50.70, 31.50 }, { 50.80, 23.20 }, { 51.00, 20.40 },
    { 51.10, 21.30 }, { 51.20, 20.80 }, { 51.20, 21.10 }, { 51.20, 24.00 }, { 51.30, 27.10 }, { 51.40, 26.20 },
    { 51.50, 20.20 }, { 51.60, 20.70 }, { 51.70, 25.70 }, { 51.80, 26.00 }, { 52.00, 26.10 }, { 53.40, 27.20 },
    { 53.60, 27.50 }, { 53.90, 31.10 }, { 54.30, 29.40 }, { 54.30, 30.00 }, { 54.30, 31.40 }, { 54.50, 30.40 },
    { 54.70, 30.80 }, { 54.80, 30.00 }, { 54.80, 30.50 }, { 54.90, 29.60 }, { 54.90, 31.10 }, { 55.00, 29.00 },
    { 55.00, 30.10 }, { 55.20, 30.80 }, { 55.60, 30.50 }, { 55.80, 16.60 }, { 56.00, 16.70 },
  },
  -- Sunscale Lashtail The Barrens
  SUNSCALE_LASHTAIL_THE_BARRENS = {
    { 47.70, 14.50 }, { 47.90, 26.00 }, { 48.40, 25.10 }, { 48.90, 23.80 }, { 51.30, 22.60 }, { 51.80, 18.70 },
    { 52.90, 33.00 }, { 54.60, 23.20 }, { 54.70, 23.10 },
  },
  -- Burning Blade Acolyte The Barrens
  BURNING_BLADE_ACOLYTE_THE_BARRENS = {
    { 46.50, 18.10 }, { 46.90, 15.80 }, { 47.20, 18.30 }, { 47.30, 19.30 }, { 47.50, 19.00 }, { 47.50, 19.50 },
    { 47.60, 15.40 }, { 47.60, 18.80 }, { 47.70, 18.00 }, { 47.70, 19.50 }, { 47.80, 18.10 }, { 47.90, 15.40 },
    { 47.90, 17.90 }, { 48.00, 19.00 }, { 48.10, 19.20 }, { 48.10, 19.30 }, { 48.30, 15.50 }, { 48.40, 18.70 },
    { 48.50, 19.00 },
  },
  -- Razormane Thornweaver The Barrens
  RAZORMANE_THORNWEAVER_THE_BARRENS = {
    { 54.10, 25.50 }, { 54.20, 25.10 }, { 54.40, 24.60 }, { 54.60, 25.20 }, { 54.70, 25.60 }, { 54.70, 27.10 },
    { 55.00, 25.30 }, { 55.10, 26.60 }, { 55.40, 26.90 }, { 55.60, 26.20 }, { 55.70, 26.60 }, { 55.80, 26.90 },
    { 55.90, 26.30 },
  },
}

R:Chapter("1-11 Mulgore (Tauren)", { levels = { 1, 11 }, race = "TAUREN", faction = "HORDE", next = "1-11 Tirisfal Glades (Undead)" })
  :Step()
    :Goto(MAP.MULGORE, 44.50, 77.50)
    :Travel()
  :Step()
    :Goto(MAP.MULGORE, 44.50, 77.50)
    :Accept(QUEST.THE_HUNT_BEGINS):At(NPC.GRULL_HAWKWIND)   -- The Hunt Begins
    :Goto(MAP.MULGORE, 43.90, 76.70)
    :Accept(QUEST.A_HUMBLE_TASK):At(NPC.CHIEF_HAWKWIND)   -- A Humble Task
  :Step()
    :Goto(MAP.MULGORE, 47.00, 77.80)
    :Loot(ITEM.PLAINSTRIDER_MEAT, 7, { quest = QUEST.THE_HUNT_BEGINS, index = 1, from = { CREATURE.PLAINSTRIDER } })   -- The Hunt Begins
    :Spawns(MAP.MULGORE, SPAWNS.PLAINSTRIDER_MEAT_MULGORE)
    :Loot(ITEM.PLAINSTRIDER_FEATHER, 7, { quest = QUEST.THE_HUNT_BEGINS, index = 2, from = { CREATURE.PLAINSTRIDER } })
    :Spawns(MAP.MULGORE, SPAWNS.PLAINSTRIDER_MEAT_MULGORE)
    :Goto(MAP.MULGORE, 48.80, 80.90)
    :Explore(QUEST.A_HUMBLE_TASK, { index = 1, npc = NPC.GREATMOTHER_HAWKWIND })   -- A Humble Task
  :Step()
    :Goto(MAP.MULGORE, 48.80, 80.90)
    :Turnin(QUEST.A_HUMBLE_TASK):At(NPC.GREATMOTHER_HAWKWIND)   -- A Humble Task
    :Accept(QUEST.A_HUMBLE_TASK_753):At(NPC.GREATMOTHER_HAWKWIND)   -- A Humble Task
  :Step()
    :Goto(MAP.MULGORE, 48.90, 81.20)
    :Loot(ITEM.WATER_PITCHER, 1, { quest = QUEST.A_HUMBLE_TASK_753, index = 1, objects = { OBJECT.WATER_PITCHER, OBJECT.WATER_PITCHER_2907 } })   -- A Humble Task
    :Spawns(MAP.MULGORE, SPAWNS.WATER_PITCHER_MULGORE)
  :Step()
    :Goto(MAP.MULGORE, 44.50, 77.50)
    :Turnin(QUEST.THE_HUNT_BEGINS):At(NPC.GRULL_HAWKWIND)   -- The Hunt Begins
  :Step()
    :Only{ class = "WARRIOR", race = "TAUREN" }
    :Goto(MAP.MULGORE, 44.50, 77.50)
    :Accept(QUEST.SIMPLE_NOTE):At(NPC.GRULL_HAWKWIND)   -- Simple Note
  :Step()
    :Only{ class = "HUNTER", race = "TAUREN" }
    :Goto(MAP.MULGORE, 44.50, 77.50)
    :Accept(QUEST.ETCHED_NOTE):At(NPC.GRULL_HAWKWIND)   -- Etched Note
  :Step()
    :Only{ class = "SHAMAN", race = "TAUREN" }
    :Goto(MAP.MULGORE, 44.50, 77.50)
    :Accept(QUEST.RUNE_INSCRIBED_NOTE):At(NPC.GRULL_HAWKWIND)   -- Rune-Inscribed Note
  :Step()
    :Only{ class = "DRUID", race = "TAUREN" }
    :Goto(MAP.MULGORE, 44.50, 77.50)
    :Accept(QUEST.VERDANT_NOTE):At(NPC.GRULL_HAWKWIND)   -- Verdant Note
  :Step()
    :Goto(MAP.MULGORE, 44.50, 77.50)
    :Accept(QUEST.THE_HUNT_CONTINUES):At(NPC.GRULL_HAWKWIND)   -- The Hunt Continues
    :Goto(MAP.MULGORE, 43.90, 76.70)
    :Turnin(QUEST.A_HUMBLE_TASK_753):At(NPC.CHIEF_HAWKWIND)   -- A Humble Task
    :Accept(QUEST.RITES_OF_THE_EARTHMOTHER):At(NPC.CHIEF_HAWKWIND)   -- Rites of the Earthmother
  :Step()
    :Only{ class = "WARRIOR", race = "TAUREN" }
    :Goto(MAP.MULGORE, 43.80, 76.70)
    :Turnin(QUEST.SIMPLE_NOTE):At(NPC.HARUTT_THUNDERHORN)   -- Simple Note
  :Step()
    :Goto(MAP.MULGORE, 42.10, 86.60)
    :Loot(ITEM.MOUNTAIN_COUGAR_PELT, 10, { quest = QUEST.THE_HUNT_CONTINUES, index = 1, from = { CREATURE.MOUNTAIN_COUGAR } })   -- The Hunt Continues
    :Spawns(MAP.MULGORE, SPAWNS.MOUNTAIN_COUGAR_PELT_MULGORE)
    :Goto(MAP.MULGORE, 42.50, 90.10)
    :Explore(QUEST.RITES_OF_THE_EARTHMOTHER, { index = 1, npc = NPC.SEER_GRAYTONGUE })   -- Rites of the Earthmother
  :Step()
    :Goto(MAP.MULGORE, 42.50, 90.10)
    :Turnin(QUEST.RITES_OF_THE_EARTHMOTHER):At(NPC.SEER_GRAYTONGUE)   -- Rites of the Earthmother
    :Accept(QUEST.RITE_OF_STRENGTH):At(NPC.SEER_GRAYTONGUE)   -- Rite of Strength
    :Accept(QUEST.GRACE_OF_ANSHE_AND_MUSHA):At(NPC.SEER_GRAYTONGUE)   -- Grace of An'she and Mu'sha
    :Goto(MAP.MULGORE, 44.50, 77.50)
    :Turnin(QUEST.THE_HUNT_CONTINUES):At(NPC.GRULL_HAWKWIND)   -- The Hunt Continues
    :Accept(QUEST.THE_BATTLEBOARS):At(NPC.GRULL_HAWKWIND)   -- The Battleboars
  :Step()
    :Loot(ITEM.POUCH_OF_SMOLDERING_INCENSE, 1, { quest = QUEST.GRACE_OF_ANSHE_AND_MUSHA, index = 1 })   -- Grace of An'she and Mu'sha
  :Step()
    :Goto(MAP.MULGORE, 56.60, 88.70)
    :Turnin(QUEST.GRACE_OF_ANSHE_AND_MUSHA)   -- Grace of An'she and Mu'sha
    :Goto(MAP.MULGORE, 59.80, 82.20)
    :Collect(ITEM.DIRT_STAINED_MAP, 1, { quest = QUEST.ATTACK_ON_CAMP_NARACHE })   -- Attack on Camp Narache
    :Use(ITEM.DIRT_STAINED_MAP)
    :Accept(QUEST.ATTACK_ON_CAMP_NARACHE)
  :Step()
    :Goto(MAP.MULGORE, 57.40, 82.40)
    :Loot(ITEM.BRISTLEBACK_BELT, 12, { quest = QUEST.RITE_OF_STRENGTH, index = 1, from = { CREATURE.BRISTLEBACK_QUILBOAR, CREATURE.BRISTLEBACK_SHAMAN } })   -- Rite of Strength
    :Spawns(MAP.MULGORE, SPAWNS.BRISTLEBACK_BELT_MULGORE)
    :Goto(MAP.MULGORE, 53.10, 78.30)
    :Loot(ITEM.BATTLEBOAR_SNOUT, 8, { quest = QUEST.THE_BATTLEBOARS, index = 1, from = { CREATURE.BRISTLEBACK_BATTLEBOAR, CREATURE.BATTLEBOAR } })   -- The Battleboars
    :Spawns(MAP.MULGORE, SPAWNS.BATTLEBOAR_SNOUT_MULGORE)
    :Loot(ITEM.BATTLEBOAR_FLANK, 8, { quest = QUEST.THE_BATTLEBOARS, index = 2, from = { CREATURE.BRISTLEBACK_BATTLEBOAR, CREATURE.BATTLEBOAR } })
    :Spawns(MAP.MULGORE, SPAWNS.BATTLEBOAR_SNOUT_MULGORE)
  :Step()
    :Goto(MAP.MULGORE, 44.50, 77.50)
    :Turnin(QUEST.THE_BATTLEBOARS):At(NPC.GRULL_HAWKWIND)   -- The Battleboars
  :Step()
    :Goto(MAP.MULGORE, 43.90, 76.70)
    :Explore(QUEST.ATTACK_ON_CAMP_NARACHE, { index = 1, npc = NPC.CHIEF_HAWKWIND })   -- Attack on Camp Narache
  :Step()
    :Goto(MAP.MULGORE, 43.90, 76.70)
    :Turnin(QUEST.ATTACK_ON_CAMP_NARACHE):At(NPC.CHIEF_HAWKWIND)   -- Attack on Camp Narache
    :Turnin(QUEST.RITE_OF_STRENGTH):At(NPC.CHIEF_HAWKWIND)   -- Rite of Strength
    :Accept(QUEST.RITES_OF_THE_EARTHMOTHER_763):At(NPC.CHIEF_HAWKWIND)   -- Rites of the Earthmother
  :Step()
    :Only{ class = "HUNTER", race = "TAUREN" }
    :Goto(MAP.MULGORE, 44.00, 76.40)
    :Turnin(QUEST.ETCHED_NOTE):At(NPC.LANKA_FARSHOT)   -- Etched Note
  :Step()
    :Only{ class = "SHAMAN", race = "TAUREN" }
    :Goto(MAP.MULGORE, 44.60, 76.60)
    :Turnin(QUEST.RUNE_INSCRIBED_NOTE):At(NPC.MEELA_DAWNSTRIDER)   -- Rune-Inscribed Note
  :Step()
    :Only{ class = "DRUID", race = "TAUREN" }
    :Goto(MAP.MULGORE, 44.70, 76.60)
    :Turnin(QUEST.VERDANT_NOTE):At(NPC.GART_MISTRUNNER)   -- Verdant Note
  :Step()
    :Only{ class = "WARRIOR" }
    :Goto(MAP.MULGORE, 48.40, 63.70)
    :Train(NPC.KRANG_STONEHOOF, { "Charge (Rank 1)", "Rend (Rank 1)" })
  :Step()
    :Goto(MAP.MULGORE, 48.40, 63.70)
    :Accept(QUEST.SPARRING_MATCH):At(NPC.KRANG_STONEHOOF)   -- Sparring Match
  :Step()
    :Goto(MAP.MULGORE, 48.40, 63.70)
    :Explore(QUEST.SPARRING_MATCH, { index = 1, npc = NPC.KRANG_STONEHOOF })   -- Sparring Match
  :Step()
    :Goto(MAP.MULGORE, 48.40, 63.70)
    :Turnin(QUEST.SPARRING_MATCH):At(NPC.KRANG_STONEHOOF)   -- Sparring Match
    :Goto(MAP.MULGORE, 47.50, 63.60)
    :Accept(QUEST.POISON_WATER):At(NPC.MULL_THUNDERHORN)   -- Poison Water
  :Step()
    :Only{ class = "DRUID" }
    :Goto(MAP.MULGORE, 47.50, 63.00)
    :Train(NPC.GENNIA_RUNETOTEM, { "Moonfire (Rank 1)", "Rejuvenation (Rank 2)" })
  :Step()
    :Goto(MAP.MULGORE, 47.70, 62.70)
    :Accept(QUEST.SWOOP_HUNTING):At(NPC.HARKEN_WINDTOTEM)   -- Swoop Hunting
  :Step()
    :Only{ class = "HUNTER" }
    :Goto(MAP.MULGORE, 46.90, 59.70)
    :Train(NPC.YAW_SHARPMANE, { "Serpent Sting (Rank 1)", "Aspect of the Monkey" })
  :Step()
    :Goto(MAP.MULGORE, 46.90, 59.70)
    :Accept(QUEST.CHAKUYAK):At(NPC.YAW_SHARPMANE)   -- Chakuyak
  :Step()
    :Goto(MAP.MULGORE, 39.60, 64.40)
    :Loot(ITEM.CHAKUYAKS_PELT, 1, { quest = QUEST.CHAKUYAK, index = 1, from = { CREATURE.CHAKUYAK } })   -- Chakuyak
    :Spawns(MAP.MULGORE, SPAWNS.CHAKUYAKS_PELT_MULGORE)
    :Goto(MAP.MULGORE, 40.00, 64.80)
    :Loot(ITEM.PRAIRIE_WOLF_PAW, 6, { quest = QUEST.POISON_WATER, index = 1, from = { CREATURE.PRAIRIE_WOLF, CREATURE.PRAIRIE_STALKER, CREATURE.PRAIRIE_WOLF_ALPHA } })   -- Poison Water
    :Spawns(MAP.MULGORE, SPAWNS.PRAIRIE_WOLF_PAW_MULGORE)
    :Loot(ITEM.PLAINSTRIDER_TALON, 4, { quest = QUEST.POISON_WATER, index = 2, from = { CREATURE.PLAINSTRIDER, CREATURE.ADULT_PLAINSTRIDER, CREATURE.ELDER_PLAINSTRIDER, CREATURE.MAZZRANACHE, CREATURE.GREATER_PLAINSTRIDER, CREATURE.ORNERY_PLAINSTRIDER, CREATURE.FLEETING_PLAINSTRIDER } })
    :Spawns(MAP.MULGORE, SPAWNS.PLAINSTRIDER_TALON_MULGORE)
  :Step()
    :Goto(MAP.MULGORE, 54.80, 64.30)
    :Accept(QUEST.THE_RAVAGED_CARAVAN):At(NPC.MORIN_CLOUDSTALKER)   -- The Ravaged Caravan
  :Step()
    :Goto(MAP.MULGORE, 51.90, 53.40)
    :Explore(QUEST.THE_RAVAGED_CARAVAN, { index = 1 })   -- The Ravaged Caravan
  :Step()
    :Goto(MAP.MULGORE, 51.90, 53.40)
    :Turnin(QUEST.THE_RAVAGED_CARAVAN)   -- The Ravaged Caravan
    :Accept(QUEST.THE_RAVAGED_CARAVAN_751)   -- The Ravaged Caravan
  :Step()
    :Goto(MAP.MULGORE, 54.80, 64.30)
    :Explore(QUEST.THE_RAVAGED_CARAVAN_751, { index = 1, npc = NPC.MORIN_CLOUDSTALKER })   -- The Ravaged Caravan
  :Step()
    :Goto(MAP.MULGORE, 54.80, 64.30)
    :Turnin(QUEST.THE_RAVAGED_CARAVAN_751):At(NPC.MORIN_CLOUDSTALKER)   -- The Ravaged Caravan
    :Goto(MAP.MULGORE, 47.50, 63.60)
    :Turnin(QUEST.POISON_WATER):At(NPC.MULL_THUNDERHORN)   -- Poison Water
    :Accept(QUEST.WINTERHOOF_CLEANSING):At(NPC.MULL_THUNDERHORN)   -- Winterhoof Cleansing
  :Step()
    :Goto(MAP.MULGORE, 47.50, 63.60)
    :Explore(QUEST.WINTERHOOF_CLEANSING, { index = 1, npc = NPC.MULL_THUNDERHORN })   -- Winterhoof Cleansing
  :Step()
    :Goto(MAP.MULGORE, 47.50, 63.60)
    :Turnin(QUEST.WINTERHOOF_CLEANSING):At(NPC.MULL_THUNDERHORN)   -- Winterhoof Cleansing
    :Accept(QUEST.THUNDERHORN_TOTEM):At(NPC.MULL_THUNDERHORN)   -- Thunderhorn Totem
    :Goto(MAP.MULGORE, 46.50, 64.90)
    :Accept(QUEST.DANGERS_OF_THE_WINDFURY):At(NPC.RUUL_EAGLETALON)   -- Dangers of the Windfury
    :Goto(MAP.MULGORE, 46.70, 63.40)
    :Accept(QUEST.SHARING_THE_LAND):At(NPC.BAINE_BLOODHOOF)   -- Sharing the Land
    :Accept(QUEST.DWARVEN_DIGGING):At(NPC.BAINE_BLOODHOOF)   -- Dwarven Digging
  :Step()
    :Goto(MAP.MULGORE, 46.70, 63.40)
    :Explore(QUEST.RITES_OF_THE_EARTHMOTHER_763, { index = 1, npc = NPC.BAINE_BLOODHOOF })   -- Rites of the Earthmother
  :Step()
    :Goto(MAP.MULGORE, 46.70, 63.40)
    :Turnin(QUEST.RITES_OF_THE_EARTHMOTHER_763):At(NPC.BAINE_BLOODHOOF)   -- Rites of the Earthmother
    :Goto(MAP.MULGORE, 46.20, 60.80)
    :Accept(QUEST.MAZZRANACHE):At(NPC.MAUR_RAINCALLER)   -- Mazzranache
  :Step()
    :Goto(MAP.MULGORE, 58.10, 52.50)
    :Loot(ITEM.BROKEN_TOOLS, 5, { quest = QUEST.DWARVEN_DIGGING, index = 1 })   -- Dwarven Digging
    :Spawns(MAP.MULGORE, SPAWNS.BROKEN_TOOLS_MULGORE)
    :Goto(MAP.MULGORE, 59.60, 72.00)
    :Loot(ITEM.WINDFURY_TALON, 8, { quest = QUEST.DANGERS_OF_THE_WINDFURY, index = 1, from = { CREATURE.WINDFURY_HARPY, CREATURE.WINDFURY_WIND_WITCH } })   -- Dangers of the Windfury
    :Spawns(MAP.MULGORE, SPAWNS.WINDFURY_TALON_MULGORE)
    :Goto(MAP.MULGORE, 56.80, 68.20)
    :Loot(ITEM.STALKER_CLAWS, 6, { quest = QUEST.THUNDERHORN_TOTEM, index = 1, from = { CREATURE.PRAIRIE_STALKER } })   -- Thunderhorn Totem
    :Spawns(MAP.MULGORE, SPAWNS.STALKER_CLAWS_MULGORE)
    :Loot(ITEM.COUGAR_CLAWS, 6, { quest = QUEST.THUNDERHORN_TOTEM, index = 2, from = { CREATURE.FLATLAND_COUGAR } })
    :Spawns(MAP.MULGORE, SPAWNS.COUGAR_CLAWS_MULGORE)
    :Goto(MAP.MULGORE, 41.00, 66.10)
    :Loot(ITEM.TROPHY_SWOOP_QUILL, 8, { quest = QUEST.SWOOP_HUNTING, index = 1, from = { CREATURE.WIRY_SWOOP, CREATURE.SWOOP, CREATURE.TALONED_SWOOP } })   -- Swoop Hunting
    :Spawns(MAP.MULGORE, SPAWNS.TROPHY_SWOOP_QUILL_MULGORE)
    :Goto(MAP.MULGORE, 47.40, 73.10)
    :Kill(CREATURE.PALEMANE_TANNER, 10, { quest = QUEST.SHARING_THE_LAND, index = 1 })   -- Sharing the Land
    :Spawns(MAP.MULGORE, SPAWNS.PALEMANE_TANNER_MULGORE)
    :Kill(CREATURE.PALEMANE_SKINNER, 8, { quest = QUEST.SHARING_THE_LAND, index = 2 })
    :Spawns(MAP.MULGORE, SPAWNS.PALEMANE_SKINNER_MULGORE)
    :Kill(CREATURE.PALEMANE_POACHER, 5, { quest = QUEST.SHARING_THE_LAND, index = 3 })
    :Spawns(MAP.MULGORE, SPAWNS.PALEMANE_POACHER_MULGORE)
    :Goto(MAP.MULGORE, 40.30, 57.10)
    :Loot(ITEM.PRAIRIE_WOLF_HEART, 1, { quest = QUEST.MAZZRANACHE, index = 1, from = { CREATURE.PRAIRIE_WOLF, CREATURE.PRAIRIE_STALKER, CREATURE.PRAIRIE_WOLF_ALPHA } })   -- Mazzranache
    :Spawns(MAP.MULGORE, SPAWNS.PRAIRIE_WOLF_PAW_MULGORE)
    :Loot(ITEM.FLATLAND_COUGAR_FEMUR, 1, { quest = QUEST.MAZZRANACHE, index = 2, from = { CREATURE.FLATLAND_COUGAR } })
    :Spawns(MAP.MULGORE, SPAWNS.COUGAR_CLAWS_MULGORE)
    :Loot(ITEM.PLAINSTRIDER_SCALE, 1, { quest = QUEST.MAZZRANACHE, index = 3, from = { CREATURE.PLAINSTRIDER, CREATURE.ADULT_PLAINSTRIDER, CREATURE.ELDER_PLAINSTRIDER, CREATURE.MAZZRANACHE, CREATURE.GREATER_PLAINSTRIDER, CREATURE.ORNERY_PLAINSTRIDER, CREATURE.FLEETING_PLAINSTRIDER } })
    :Spawns(MAP.MULGORE, SPAWNS.PLAINSTRIDER_TALON_MULGORE)
    :Loot(ITEM.SWOOP_GIZZARD, 1, { quest = QUEST.MAZZRANACHE, index = 4, from = { CREATURE.WIRY_SWOOP, CREATURE.SWOOP, CREATURE.TALONED_SWOOP } })
    :Spawns(MAP.MULGORE, SPAWNS.TROPHY_SWOOP_QUILL_MULGORE)
  :Step()
    :Only{ class = "HUNTER" }
    :Goto(MAP.MULGORE, 46.90, 59.70)
    :Train(NPC.YAW_SHARPMANE, { "Hunter's Mark (Rank 1)", "Arcane Shot (Rank 1)" })
  :Step()
    :Goto(MAP.MULGORE, 46.90, 59.70)
    :Turnin(QUEST.CHAKUYAK):At(NPC.YAW_SHARPMANE)   -- Chakuyak
    :Goto(MAP.MULGORE, 46.20, 60.80)
    :Turnin(QUEST.MAZZRANACHE):At(NPC.MAUR_RAINCALLER)   -- Mazzranache
    :Goto(MAP.MULGORE, 46.70, 63.40)
    :Turnin(QUEST.SHARING_THE_LAND):At(NPC.BAINE_BLOODHOOF)   -- Sharing the Land
    :Turnin(QUEST.DWARVEN_DIGGING):At(NPC.BAINE_BLOODHOOF)   -- Dwarven Digging
    :Goto(MAP.MULGORE, 46.50, 64.90)
    :Turnin(QUEST.DANGERS_OF_THE_WINDFURY):At(NPC.RUUL_EAGLETALON)   -- Dangers of the Windfury
  :Step()
    :Ding(12)
  :Step()
    :Goto(MAP.MULGORE, 47.50, 63.60)
    :Turnin(QUEST.THUNDERHORN_TOTEM):At(NPC.MULL_THUNDERHORN)   -- Thunderhorn Totem
    :Accept(QUEST.THUNDERHORN_CLEANSING):At(NPC.MULL_THUNDERHORN)   -- Thunderhorn Cleansing
  :Step()
    :Goto(MAP.MULGORE, 47.50, 63.60)
    :Explore(QUEST.THUNDERHORN_CLEANSING, { index = 1, npc = NPC.MULL_THUNDERHORN })   -- Thunderhorn Cleansing
  :Step()
    :Goto(MAP.MULGORE, 47.50, 63.60)
    :Turnin(QUEST.THUNDERHORN_CLEANSING):At(NPC.MULL_THUNDERHORN)   -- Thunderhorn Cleansing
    :Accept(QUEST.WILDMANE_TOTEM):At(NPC.MULL_THUNDERHORN)   -- Wildmane Totem
  :Step()
    :Only{ class = "WARRIOR" }
    :Goto(MAP.MULGORE, 48.40, 63.70)
    :Train(NPC.KRANG_STONEHOOF, { "Thunder Clap (Rank 1)", "Battle Shout (Rank 2)" })
  :Step()
    :Goto(MAP.MULGORE, 60.40, 63.00)
    :Loot(ITEM.PRAIRIE_ALPHA_TOOTH, 8, { quest = QUEST.WILDMANE_TOTEM, index = 1, from = { CREATURE.PRAIRIE_WOLF_ALPHA } })   -- Wildmane Totem
    :Spawns(MAP.MULGORE, SPAWNS.PRAIRIE_ALPHA_TOOTH_MULGORE)
  :Step()
    :Goto(MAP.MULGORE, 62.10, 71.90)
    :Grind(MAP.MULGORE, 62.10, 71.90, 40, { npc = { CREATURE.WINDFURY_WIND_WITCH }, count = 9 })
    :Spawns(MAP.MULGORE, SPAWNS.WINDFURY_WIND_WITCH_MULGORE)
  :Step()
    :Goto(MAP.MULGORE, 47.50, 63.60)
    :Turnin(QUEST.WILDMANE_TOTEM):At(NPC.MULL_THUNDERHORN)   -- Wildmane Totem
    :Accept(QUEST.WILDMANE_CLEANSING):At(NPC.MULL_THUNDERHORN)   -- Wildmane Cleansing
  :Step()
    :Goto(MAP.MULGORE, 47.50, 63.60)
    :Explore(QUEST.WILDMANE_CLEANSING, { index = 1, npc = NPC.MULL_THUNDERHORN })   -- Wildmane Cleansing
  :Step()
    :Goto(MAP.MULGORE, 47.50, 63.60)
    :Turnin(QUEST.WILDMANE_CLEANSING):At(NPC.MULL_THUNDERHORN)   -- Wildmane Cleansing
  :Step()
    :Only{ class = "SHAMAN" }
    :Goto(MAP.MULGORE, 47.40, 62.50)
    :Train(NPC.NARM_SKYCHASER, { "Lightning Bolt (Rank 2)", "Earth Shock (Rank 2)" })
  :Step()
    :Only{ class = "DRUID" }
    :Goto(MAP.MULGORE, 47.50, 63.00)
    :Train(NPC.GENNIA_RUNETOTEM, { "Thorns (Rank 1)" })
  :Step()
    :Goto(MAP.MULGORE, 47.70, 62.70)
    :Turnin(QUEST.SWOOP_HUNTING):At(NPC.HARKEN_WINDTOTEM)   -- Swoop Hunting
    :Goto(MAP.MULGORE, 57.00, 34.60)
    :Accept(QUEST.A_SACRED_BURIAL):At(NPC.LOREKEEPER_RAINTOTEM)   -- A Sacred Burial
  :Step()
    :Goto(MAP.MULGORE, 57.80, 30.80)
    :Kill(CREATURE.BRISTLEBACK_INTERLOPER, 8, { quest = QUEST.A_SACRED_BURIAL, index = 1 })   -- A Sacred Burial
    :Spawns(MAP.MULGORE, SPAWNS.BRISTLEBACK_INTERLOPER_MULGORE)
  :Step()
    :Goto(MAP.MULGORE, 57.00, 34.60)
    :Turnin(QUEST.A_SACRED_BURIAL):At(NPC.LOREKEEPER_RAINTOTEM)   -- A Sacred Burial
  :Step()
    :Goto(MAP.MULGORE, 52.20, 21.90)
    :Grind(MAP.MULGORE, 52.20, 21.90, 40, { npc = { CREATURE.WINDFURY_SORCERESS }, count = 9 })
    :Spawns(MAP.MULGORE, SPAWNS.WINDFURY_SORCERESS_MULGORE)
    :Goto(MAP.MULGORE, 51.70, 20.10)
    :Grind(MAP.MULGORE, 51.70, 20.10, 40, { npc = { CREATURE.WINDFURY_MATRIARCH }, count = 8 })
    :Spawns(MAP.MULGORE, SPAWNS.WINDFURY_MATRIARCH_MULGORE)
    :Goto(MAP.MULGORE, 38.90, 20.10)
    :Grind(MAP.MULGORE, 38.90, 20.10, 40, { npc = { CREATURE.WINDFURY_MATRIARCH }, count = 8 })
    :Spawns(MAP.MULGORE, SPAWNS.WINDFURY_MATRIARCH_MULGORE)
    :Goto(MAP.MULGORE, 38.70, 20.70)
    :Grind(MAP.MULGORE, 38.70, 20.70, 40, { npc = { CREATURE.WINDFURY_SORCERESS }, count = 9 })
    :Spawns(MAP.MULGORE, SPAWNS.WINDFURY_SORCERESS_MULGORE)
    :Goto(MAP.MULGORE, 32.90, 33.30)
    :Grind(MAP.MULGORE, 32.90, 33.30, 40, { npc = { CREATURE.WINDFURY_MATRIARCH }, count = 8 })
    :Spawns(MAP.MULGORE, SPAWNS.WINDFURY_MATRIARCH_MULGORE)
    :Goto(MAP.MULGORE, 32.40, 32.90)
    :Grind(MAP.MULGORE, 32.40, 32.90, 40, { npc = { CREATURE.WINDFURY_SORCERESS }, count = 9 })
    :Spawns(MAP.MULGORE, SPAWNS.WINDFURY_SORCERESS_MULGORE)
  :Step()
    :Only{ class = "HUNTER" }
    :Goto(MAP.MULGORE, 46.90, 59.70)
    :Train(NPC.YAW_SHARPMANE, { "Concussive Shot", "Serpent Sting (Rank 2)" })
  :Step()
    :Goto(MAP.MULGORE, 45.80, 59.50)
    :Deathwarp()
  :Step()
    :Goto(MAP.MULGORE, 54.80, 64.30)
    :Accept(QUEST.THE_VENTURE_CO):At(NPC.MORIN_CLOUDSTALKER)   -- The Venture Co.
  :Step()
    :Goto(MAP.MULGORE, 57.50, 53.60)
    :Kill(CREATURE.VENTURE_CO_WORKER, 14, { quest = QUEST.THE_VENTURE_CO, index = 1 })   -- The Venture Co.
    :Spawns(MAP.MULGORE, SPAWNS.VENTURE_CO_WORKER_MULGORE)
    :Kill(CREATURE.VENTURE_CO_SUPERVISOR, 6, { quest = QUEST.THE_VENTURE_CO, index = 2 })
    :Spawns(MAP.MULGORE, SPAWNS.VENTURE_CO_SUPERVISOR_MULGORE)
  :Step()
    :Goto(MAP.MULGORE, 61.20, 49.30)
    :Collect(ITEM.MULGORE_EXPANSION_PLANS, 1, { quest = QUEST.FIZSPROCKETS_NOTES })   -- Fizsprocket's Notes
    :Use(ITEM.MULGORE_EXPANSION_PLANS)
    :Accept(QUEST.FIZSPROCKETS_NOTES)
  :Step()
    :Goto(MAP.MULGORE, 58.60, 47.40)
    :Loot(ITEM.SHREDDER_OPERATION_INSTRUCTIONS, 1, { quest = QUEST.FIZSPROCKETS_NOTES, index = 1, objects = { OBJECT.SHREDDER_OPERATION_INSTRUCTIONS } })   -- Fizsprocket's Notes
    :Spawns(MAP.MULGORE, SPAWNS.SHREDDER_OPERATION_INSTRUCTIONS_MULGORE)
    :Loot(ITEM.BARRENS_OPERATIONS_BEST_PRACTICES, 1, { quest = QUEST.FIZSPROCKETS_NOTES, index = 2, objects = { OBJECT.BARRENS_OPERATIONS_BEST_PRACTICES } })
    :Spawns(MAP.MULGORE, SPAWNS.BARRENS_OPERATIONS_BEST_PRACTICES_MULGORE)
    :Loot(ITEM.ONE_GERENZO_OF_STONETALON, 1, { quest = QUEST.FIZSPROCKETS_NOTES, index = 3, objects = { OBJECT.ONE_GERENZO_OF_STONETALON } })
    :Spawns(MAP.MULGORE, SPAWNS.ONE_GERENZO_OF_STONETALON_MULGORE)
    :Loot(ITEM.MULGORE_EXPANSION_PLANS, 1, { quest = QUEST.FIZSPROCKETS_NOTES, index = 4, from = { CREATURE.SUPERVISOR_FIZSPROCKET } })
    :Spawns(MAP.MULGORE, SPAWNS.MULGORE_EXPANSION_PLANS_MULGORE)
  :Step()
    :Only{ class = "WARRIOR" }
    :Goto(MAP.MULGORE, 48.40, 63.70)
    :Accept(QUEST.VETERAN_UZZEK):At(NPC.KRANG_STONEHOOF)   -- Veteran Uzzek
  :Step()
    :Only{ class = "HUNTER", race = "TAUREN" }
    :Goto(MAP.MULGORE, 46.90, 59.70)
    :Accept(QUEST.TAMING_THE_BEAST):At(NPC.YAW_SHARPMANE)   -- Taming the Beast
  :Step()
    :Only{ class = "HUNTER", race = "TAUREN" }
    :Goto(MAP.MULGORE, 42.90, 59.10)
    :Explore(QUEST.TAMING_THE_BEAST, { index = 1 })   -- Taming the Beast
  :Step()
    :Only{ class = "HUNTER", race = "TAUREN" }
    :Goto(MAP.MULGORE, 46.90, 59.70)
    :Turnin(QUEST.TAMING_THE_BEAST):At(NPC.YAW_SHARPMANE)   -- Taming the Beast
    :Accept(QUEST.TAMING_THE_BEAST_6087):At(NPC.YAW_SHARPMANE)   -- Taming the Beast
  :Step()
    :Only{ class = "HUNTER", race = "TAUREN" }
    :Goto(MAP.MULGORE, 42.80, 57.40)
    :Explore(QUEST.TAMING_THE_BEAST_6087, { index = 1 })   -- Taming the Beast
  :Step()
    :Only{ class = "HUNTER", race = "TAUREN" }
    :Goto(MAP.MULGORE, 46.90, 59.70)
    :Turnin(QUEST.TAMING_THE_BEAST_6087):At(NPC.YAW_SHARPMANE)   -- Taming the Beast
    :Accept(QUEST.TAMING_THE_BEAST_6088):At(NPC.YAW_SHARPMANE)   -- Taming the Beast
  :Step()
    :Only{ class = "HUNTER", race = "TAUREN" }
    :Goto(MAP.MULGORE, 50.00, 62.90)
    :Explore(QUEST.TAMING_THE_BEAST_6088, { index = 1 })   -- Taming the Beast
  :Step()
    :Only{ class = "HUNTER", race = "TAUREN" }
    :Goto(MAP.MULGORE, 46.90, 59.70)
    :Turnin(QUEST.TAMING_THE_BEAST_6088):At(NPC.YAW_SHARPMANE)   -- Taming the Beast
  :Step()
    :Only{ class = "SHAMAN" }
    :Goto(MAP.MULGORE, 47.40, 62.50)
    :Accept(QUEST.CALL_OF_FIRE):At(NPC.NARM_SKYCHASER)   -- Call of Fire
  :Step()
    :Goto(MAP.MULGORE, 54.80, 64.30)
    :Turnin(QUEST.THE_VENTURE_CO):At(NPC.MORIN_CLOUDSTALKER)   -- The Venture Co.
    :Turnin(QUEST.FIZSPROCKETS_NOTES):At(NPC.MORIN_CLOUDSTALKER)   -- Fizsprocket's Notes
  :Step()
    :Goto(MAP.THE_BARRENS, 44.50, 59.20)
    :Fp(NODE.CAMP_TAURAJO)   -- Camp Taurajo
  :Step()
    :Goto(MAP.THE_BARRENS, 44.90, 58.60)
    :Accept(QUEST.JOURNEY_TO_THE_CROSSROADS):At(NPC.KIRGE_STERNHORN)   -- Journey to the Crossroads
  :Step()
    :Goto(MAP.THE_BARRENS, 51.40, 26.40)
    :Grind(MAP.THE_BARRENS, 51.40, 26.40, 40, { npc = { CREATURE.GREATER_PLAINSTRIDER }, count = 7 })
    :Spawns(MAP.THE_BARRENS, SPAWNS.GREATER_PLAINSTRIDER_THE_BARRENS)
    :Goto(MAP.THE_BARRENS, 51.80, 25.80)
    :Grind(MAP.THE_BARRENS, 51.80, 25.80, 40, { npc = { CREATURE.SAVANNAH_HUNTRESS }, count = 7 })
    :Spawns(MAP.THE_BARRENS, SPAWNS.SAVANNAH_HUNTRESS_THE_BARRENS)
    :Goto(MAP.THE_BARRENS, 51.00, 24.00)
    :Grind(MAP.THE_BARRENS, 51.00, 24.00, 40, { npc = { CREATURE.SUNSCALE_LASHTAIL }, count = 8 })
    :Spawns(MAP.THE_BARRENS, SPAWNS.SUNSCALE_LASHTAIL_THE_BARRENS)
    :Goto(MAP.THE_BARRENS, 47.70, 18.10)
    :Grind(MAP.THE_BARRENS, 47.70, 18.10, 40, { npc = { CREATURE.BURNING_BLADE_ACOLYTE }, count = 8 })
    :Spawns(MAP.THE_BARRENS, SPAWNS.BURNING_BLADE_ACOLYTE_THE_BARRENS)
    :Goto(MAP.THE_BARRENS, 50.30, 16.90)
    :Grind(MAP.THE_BARRENS, 50.30, 16.90, 40, { npc = { CREATURE.GREATER_PLAINSTRIDER }, count = 7 })
    :Spawns(MAP.THE_BARRENS, SPAWNS.GREATER_PLAINSTRIDER_THE_BARRENS)
  :Step()
    :Only{ class = "WARRIOR" }
    :Goto(MAP.THE_BARRENS, 61.40, 21.10)
    :Turnin(QUEST.VETERAN_UZZEK):At(NPC.UZZEK)   -- Veteran Uzzek
  :Step()
    :Only{ class = "SHAMAN" }
    :Goto(MAP.THE_BARRENS, 56.00, 19.90)
    :Turnin(QUEST.CALL_OF_FIRE):At(NPC.KRANAL_FISS)   -- Call of Fire
  :Step()
    :Goto(MAP.THE_BARRENS, 55.00, 26.00)
    :Grind(MAP.THE_BARRENS, 55.00, 26.00, 40, { npc = { CREATURE.RAZORMANE_THORNWEAVER }, count = 8 })
    :Spawns(MAP.THE_BARRENS, SPAWNS.RAZORMANE_THORNWEAVER_THE_BARRENS)
    :Goto(MAP.THE_BARRENS, 52.60, 32.90)
    :Grind(MAP.THE_BARRENS, 52.60, 32.90, 40, { npc = { CREATURE.GREATER_PLAINSTRIDER }, count = 7 })
    :Spawns(MAP.THE_BARRENS, SPAWNS.GREATER_PLAINSTRIDER_THE_BARRENS)
  :Step()
    :Goto(MAP.THE_BARRENS, 51.50, 30.90)
    :Explore(QUEST.JOURNEY_TO_THE_CROSSROADS, { index = 1, npc = NPC.THORK })   -- Journey to the Crossroads
  :Step()
    :Goto(MAP.THE_BARRENS, 51.50, 30.90)
    :Turnin(QUEST.JOURNEY_TO_THE_CROSSROADS):At(NPC.THORK)   -- Journey to the Crossroads
  :Step()
    :Goto(MAP.THE_BARRENS, 51.50, 30.30)
    :Fp(NODE.CROSSROADS)   -- Crossroads
  :Step()
    :Only{ class = "WARRIOR" }
    :Goto(MAP.THUNDER_BLUFF, 40.90, 62.70)
    :Train(NPC.ANSEKHWA, { "Two-Handed Axes", "Two-Handed Maces" })
  :Done()
