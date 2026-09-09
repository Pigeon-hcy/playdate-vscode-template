PlayerConfig = {
    screenWidth = 400,
    screenHeight = 240,
    refreshRate = 30,

    activeWorkstation = 1,
    workstationCount = 3,

    -- Shared inventory, available to every workstation.
    mincedMeat = 0,
    patties = 0,
    score = 0,

    -- Recipe format: { name, ingredientCode, ingredientCode, ... }
    recipe = {
        { "CLASSIC", "P", "T", "L", "C" },
        { "DOUBLE", "P", "P", "C", "C", "K" },
        { "BREAKFAST", "P", "E", "S", "T" },
        { "FOREST", "P", "M", "F", "C" },
        { "TOWER", "P", "P", "P", "P", "T", "C", "C" },
    },

    grinder = {
        possibleYields = { 60, 70, 80, 90, 100 },
        meatPerCrankTurn = 15,
        hasMeat = false,
        totalYield = 0,
        producedYield = 0,
        processedDegrees = 0,
        crankAngle = 0,
        isLoadingMeat = false,
        loadAnimationFrame = 0,
        loadAnimationDurationFrames = 18,
        outputParticles = {},
        maxOutputParticles = 48,
        particleLifeFrames = 42,
    },

    frying = {
        slotCount = 8,
        pattyCost = 20,
        rawDurationFrames = 15 * 15,
        cookedDurationFrames = 20 * 20,
        dropAnimationDurationFrames = 10,
        riseAnimationDurationFrames = 12,
        slots = {},
    },

    assembly = {
        ingredientCodes = {
            "P", "O", "T", "L", "K",
            "E", "M", "F", "C", "S",
        },
        ingredientNames = {
            P = "PATTY",
            O = "ONION",
            T = "TOMATO",
            L = "LETTUCE",
            K = "PICKLE",
            E = "EGG",
            M = "MUSHROOM",
            F = "CARAMEL ONION",
            C = "CHEESE",
            S = "ENGLISH CHEESE",
        },
        crankTicksPerTurn = 12,
        selectedIngredientIndex = 1,
        wheelIsAnimating = false,
        wheelAnimationFrame = 0,
        wheelAnimationDurationFrames = 7,
        wheelDirection = 0,
        currentRecipeIndex = 1,
        layers = {},
        hasTopBread = false,
        lastResult = nil,
    },

    workstations = {
        {
            id = 1,
            name = "GRINDER",
            elapsedFrames = 0,
        },
        {
            id = 2,
            name = "STOVE",
            elapsedFrames = 0,
        },
        {
            id = 3,
            name = "ASSEMBLY",
            elapsedFrames = 0,
        },
    },
}
