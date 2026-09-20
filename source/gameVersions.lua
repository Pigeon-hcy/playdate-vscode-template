-- Stable IDs are also the namespace for any future per-version save data.
-- Only one gameplay tree is imported per launch. Switching restarts the Lua
-- runtime so module locals, inventory, effects and callbacks cannot leak.
GameVersions = {}
local entries <const> = {
    { id = "original", name = "ORIGINAL" },
    { id = "variantA", name = "ORIGINAL VARIANT A" },
    { id = "variantB", name = "SIMPLIFIED" },
    { id = "variantC", name = "ASSEMBLY QTE" },
    { id = "variantD", name = "CRANK GRILL" },
}
local selectedIndex = 1
local returnToMenu, openPicker = false, false
for _, arg in ipairs(playdate.argv or {}) do
    for index, entry in ipairs(entries) do
        if arg == "--version=" .. entry.id then selectedIndex = index end
    end
    if arg == "--version-selected" then returnToMenu = true end
    if arg == "--choose-version" then returnToMenu, openPicker = true, true end
end

function GameVersions.getEntries() return entries end
function GameVersions.getIndex() return selectedIndex end
function GameVersions.getId() return entries[selectedIndex].id end
function GameVersions.getName() return entries[selectedIndex].name end
function GameVersions.shouldSkipIntro() return returnToMenu end
function GameVersions.shouldOpenPicker() return openPicker end

function GameVersions.select(index)
    assert(entries[index], "Unknown game version")
    if index == selectedIndex then return false end
    playdate.restart("--version=" .. entries[index].id .. " --version-selected")
    return true
end

function GameVersions.showPicker()
    playdate.restart("--version=" .. GameVersions.getId() .. " --choose-version")
end

-- Use this for future datastore filenames, never a shared save filename.
function GameVersions.savePath(name)
    assert(type(name) == "string" and name:match("^[%w_-]+$"), "Invalid save name")
    return "versions/" .. GameVersions.getId() .. "/" .. name
end
