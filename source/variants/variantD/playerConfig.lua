import "variants/variantD/recipes"

PlayerConfig = {
    screenWidth = 400,
    screenHeight = 240,
    refreshRate = 30,

    activeWorkstation = 1,
    workstationCount = 3,
    workstationSwitchDuration = 0.5, -- Seconds.

    -- Shared inventory, available to every workstation.
    mincedMeat = 0,
    patties = 0,
    score = 0,

    recipe = Recipes,

    -- See source/scoring.lua for how these combine.
    scoring = {
        base = 200,
        perKind = 5,  -- Distinct ingredients in the burger.
        perCount = 3, -- Total ingredients in the burger.
        ingredientMultiplier = 20,
        perRemainingSecond = 10, -- Whole seconds left on the served order.
        rushMultiplier = 1.5,
        wrongPenalty = 500,
        missedPenalty = 800, -- An order that expires unserved.
        -- A rush issues far more orders than anyone can serve, so each miss
        -- during one costs only this fraction of the normal penalty.
        rushMissedScale = 0.25,
    },

    orders = {
        capacity = 6,
        lifetime = 60,
        minArrivalDelay = 10,
        maxArrivalDelay = 30,
        emptyArrivalDelay = 5,
        initialCount = 1,
        ticketEntryDuration = 0.20,
        ticketReturnDuration = 0.25,
        -- Tickets with this much time left flash so they read as urgent.
        urgentSeconds = 10,
        blinkHz = 2,
        -- First rush after 90-120s; subsequent cooldowns last 105-135s.
        -- Each rush lasts 60-90 seconds and issues an order every 2 seconds.
        rush = {
            firstDelayMin = 90,
            firstDelayMax = 120,
            durationMin = 60,
            durationMax = 90,
            cooldownMin = 105,
            cooldownMax = 135,
            lifetimeScale = 0.5,
            minArrivalDelay = 2,
            maxArrivalDelay = 2,
        },
    },

    -- Per-station controls card; see source/helpCard.lua.
    helpCard = {
        width = 320,
        padding = 10,
        headerHeight = 36,
        sectionGap = 8,
        rowHeight = 18,
        keyColumnWidth = 44,
        keyGap = 10,
        footerHeight = 24,
        cornerRadius = 6,
        borderWidth = 3,
        shadow = 4,
        dimAlpha = 0.6,
        enterDuration = 0.22,
        exitDuration = 0.14,
    },

    -- Failed-consumption prompt; seconds after the most recent failed press.
    supplyWarning = { lifetime = 1.5 },

    -- Comic starburst panel for sudden events; see source/burstDialog.lua.
    burstDialog = {
        spikes = 12,
        burstScale = 1.85, -- Outer radius against the content box's half size.
        innerScale = 0.74, -- Spike valleys, as a share of the outer radius.
        spikeJitter = 0.16,
        lineWidth = 2,
        enterDuration = 0.16,
        exitDuration = 0.16,
        exitPopShare = 0.35, -- Of the exit spent swelling before collapsing.
        exitPopScale = 1.18,
        joltDuration = 0.12,
        joltScale = 0.10,
    },

    -- Score change pill at the bottom of the screen; see source/scorePopup.lua.
    scorePopup = {
        fontPath = "/System/Fonts/Roobert-24-Medium",
        riseDuration = 0.22,
        holdDuration = 1.2,
        exitDuration = 0.18,
        bottomMargin = 4,
        paddingX = 14,
        paddingY = 2,
        cornerRadius = 6,
        borderWidth = 2,
    },

    -- Full-screen rush announcements; see source/rushBanner.lua.
    rushBanner = {
        fontPath = "/System/Fonts/Roobert-24-Medium",
        maxScale = 4,
        -- Tight margins: three lines of Roobert 24 only reach double size,
        -- and two lines triple size, when the block may nearly fill the screen.
        margin = 4,
        lineGap = 4,
        fadeInDuration = 0.10,
        fadeOutDuration = 0.35,
        holdDuration = 1.5, -- After the last word lands or is typed.
        -- Start: each word slams down from three times its size.
        slamDuration = 0.20,
        slamStartScale = 3,
        wordGap = 0.12,
        squashDuration = 0.14,
        squashAmount = 0.16,
        shakeDuration = 0.22,
        shakeAmplitude = 5,
        flashDuration = 0.07, -- Two frames of inverted screen per impact.
        -- Over: typed out one character at a time.
        typeInterval = 0.08,
        cursorHz = 4,
    },

    grinder = {
        possibleYields = { 60, 70, 80, 90, 100 },
        meatPerCrankTurn = 15,
        hasMeat = false,
        totalYield = 0,
        producedYield = 0,
        processedDegrees = 0,
        crankAngle = 0,
        outputParticles = {},
        maxOutputParticles = 48,
        particleLifeFrames = 42,
        fullForceCrankDegrees = 18, -- Per frame at 30 FPS (1.5 turns/second).
        particleMinSpeed = 2.8,
        particleMaxSpeed = 7.5,
        particleDrag = 0.97,
        particleGravity = 0.18,
        particleTrailFrames = 4,
        grindShakeDuration = 0.12,
        hopperParticleEvery = 3, -- Redirect one in three crumbs to the inlet.
        hopperParticleLifeFrames = 24,
        hopperParticleGravity = 0.28,

        -- Meat jam: see the event section of source/grinderWorkstation.lua.
        jam = {
            minMeatCount = 1,
            maxMeatCount = 3,
            triggerProgress = 0.5, -- Jam halfway through the selected piece.
            cooldown = 20, -- Seconds after clearing; pieces started here do not count.
            minPresses = 3,
            maxPresses = 6,
            startShakeDuration = 0.5,
            startShakeAmplitude = 4,
            pressShakeDuration = 0.28,
            pressShakeAmplitude = 7,
            pressRecoil = 0.9,
            pressParticles = 6,
            dialogCenterX = 200,
            dialogCenterY = 128,
        },
    },

    frying = {
        slotCount = 1,
        pattyCost = 50, -- An average 80-mince load makes 1.6 patties.
        degreesForFullBar = 360,
        readyMin = 60,
        burnAbove = 80,
        riseAnimationDurationFrames = 4, -- About 0.13 seconds at 30 FPS.
        riseDistance = 15,
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
            S = "E. CHEESE",
        },
        ingredientCards = {
            width = 92,
            height = 48,
            spacing = 53,
            initialsY = 213,
            initialsHeight = 24,
            abbreviations = {
                P = "P", O = "O", T = "T", L = "L", K = "PK",
                E = "E", M = "M", B = "B", A = "A.C.", S = "E.C.",
            },
            names = {
                P = "PATTY", O = "ONION", T = "TOMATO", L = "LETTUCE",
                K = "PICKLE", E = "EGG", M = "MUSHROOM", B = "BACON",
                A = "AMERICAN CHEESE", S = "ENGLISH CHEESE",
            },
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
        -- Assembly-only footprint: fit the filling within the bottom bun's
        -- pale top surface, with a little rim visible at both sides. Heights
        -- correct the deeper perspective of the flatter ingredient artwork.
        spriteFootprintWidth = 126,
        -- Cheese drips and lettuce frills intentionally cross the bun rim.
        -- Preserve their original shape instead of fitting them inside it.
        spriteNaturalOverhang = { A = true, L = true, S = true },
        spriteMaxHeights = {
            P = 60, O = 43, T = 50, L = 66, K = 40,
            E = 49, M = 49, B = 44, A = 64, S = 60,
        },
        -- Contact offsets in the normalized assembly sprites, not the source
        -- canvas. A thick patty and a draped cheese have different contact
        -- points; their lowest painted pixel is not the next layer's surface.
        spriteBaselines = {
            -- A/L/S retain their original seats (4/6/3), plus 10px to offset
            -- the raised bun support plane and keep the intentional drape.
            P = 6, O = 0, T = 1, L = 16, K = 1,
            E = 1, M = 0, B = 1, A = 14, S = 13,
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
            P = 12, O = 5, T = 6, L = 10, K = 4,
            E = 7, M = 8, B = 5, A = 5, S = 5,
        },
        breadThickness = {
            bottom = 23, -- Keep the first layer on the pale surface, above the crust.
        },
        -- Mirroring varies repeated layers without tilting their contact
        -- planes into the bun or lifting their corners off the layer below.
        repeatVariants = {
            { flip = false, rotation = 0 },
            { flip = true, rotation = 0 },
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
        serveOutDuration = 0.18,
        breadInDuration = 0.16,
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
