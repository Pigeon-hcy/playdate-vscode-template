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
        ingredientSprites = {
            P = "Patty",
            O = "Onion",
            T = "Tomato",
            L = "Lettuce",
            K = "Pickle",
            E = "Egg",
            M = "Mushroom",
            B = "Bacon",
            A = "American",
            S = "English",
        },
        breadSprites = {
            bottom = "Bread1",
            top = "TopBread",
        },
        -- Pixels to seat each sprite down by, so art with a wispy or draped
        -- bottom edge (lettuce tips, melted cheese) rests on the layer below
        -- instead of floating above it. 0 means the sprite's bottom edge is
        -- already its resting plane. Tune by eye; these are pixels, so they
        -- need rescaling if the art is rebuilt at a different width.
        spriteBaselines = {
            P = 0, O = 0, T = 2, L = 6, K = 3,
            E = 1, M = 1, B = 3, A = 4, S = 3,
        },
        breadBaselines = {
            bottom = 0,
            top = 0,
        },
        -- How much vertical room each ingredient adds to the stack: how far
        -- it lifts whatever is placed on top of it. A uniform step would
        -- leave a gap above thin items (pickle, cheese) and bury thick ones,
        -- so the burger only packs tight when these match the art.
        spriteThickness = {
            P = 12, O = 5, T = 7, L = 10, K = 5,
            E = 7, M = 10, B = 6, A = 5, S = 5,
        },
        breadThickness = {
            bottom = 13,
        },
        -- Repeated ingredients cycle through these so a double or triple
        -- stack does not read as one thick slab. A flip is free and stays
        -- pixel-crisp; rotation resamples the dither and costs a rotated
        -- blit, so it is kept small and left to the third copy onward.
        repeatVariants = {
            { flip = false, rotation = 0 },
            { flip = true, rotation = 0 },
            { flip = false, rotation = 5 },
            { flip = true, rotation = -5 },
        },
        crankTicksPerTurn = 12,
        selectedIngredientIndex = 1,
        wheelIsAnimating = false,
        wheelAnimationFrame = 0,
        wheelAnimationDurationFrames = 7,
        wheelDirection = 0,
        currentRecipeIndex = 1,
        layers = {},
        layerRepeats = {},
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
