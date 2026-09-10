import "recipes"

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

    recipe = Recipes,

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
            "E", "M", "B", "A", "S",
        },
        ingredientNames = {
            P = "PATTY",
            O = "ONION",
            T = "TOMATO",
            L = "LETTUCE",
            K = "PICKLE",
            E = "EGG",
            M = "MUSHROOM",
            B = "BACON",
            A = "A. CHEESE",
            S = "S. CHEESE",
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
