-- ==============================================================
-- Configuration
-- ==============================================================
-- Replace this link with the raw URL of this exact script so it can re-execute upon hopping
local SCRIPT_URL = "https://raw.githubusercontent.com/YourUsername/YourRepo/main/farming_script.lua"

-- Executor built-in functions
local queue_on_tp = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

-- ==============================================================
-- STEP 1: Initial Wait
-- ==============================================================
task.wait(5)

-- Wait for workspace elements to load to prevent errors
local Zones = workspace:WaitForChild("Zones", 10)
local Zone10 = Zones and Zones:WaitForChild("Zone10", 10)
local Map = workspace:WaitForChild("Map", 10)

-- ==============================================================
-- STEP 2: Define the "Farming Sequence"
-- ==============================================================
local function FarmingSequence(targetObject)
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local rootPart = character:WaitForChild("HumanoidRootPart")

    -- Teleport to the child object
    -- GetPivot() safely gets the CFrame whether the object is a BasePart or a Model
    if targetObject:IsA("PVInstance") then
        rootPart.CFrame = targetObject:GetPivot()
    end
    
    task.wait(0.5) -- Short delay to allow physics/proximity prompts to register

    -- Find and fire the ProximityPrompt
    local prompt = targetObject:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt then
        if fireproximityprompt then
            fireproximityprompt(prompt, 1, true)
        else
            -- Fallback in case fireproximityprompt isn't supported
            prompt.InputHoldBegin:Fire()
            task.wait(prompt.HoldDuration)
            prompt.InputHoldEnd:Fire()
        end
    end
    
    task.wait(1) -- Short delay to ensure the collection registers

    -- Teleport back to coordinates
    rootPart.CFrame = CFrame.new(34, 24, -1)

    -- Wait 2 seconds
    task.wait(2)
end

-- Helper function to perform the 2-time maximum sequence check
local function PerformFarmingPhase()
    for i = 1, 2 do
        local children = Zone10:GetChildren()
        if #children > 0 then
            -- Grab the first object found inside Zone10
            FarmingSequence(children[1])
        else
            -- If no object is found, break out of the loop early
            break
        end
    end
end

-- ==============================================================
-- STEP 3: Phase 1 - Initial Check
-- ==============================================================
if Zone10 then
    PerformFarmingPhase()
end

-- ==============================================================
-- STEP 4: Phase 2 - Timer Check
-- ==============================================================
local rarityLabel = Map.Walls.guiEternal.SurfaceGui:WaitForChild("Rarity", 5)

if rarityLabel and rarityLabel:IsA("TextLabel") then
    local text = rarityLabel.Text
    -- Parse the text for "Eternal in (MM:SS)" using string pattern matching
    local mins, secs = string.match(text, "Eternal in (%d+):(%d+)")
    
    if mins and secs then
        local totalSeconds = (tonumber(mins) * 60) + tonumber(secs)
        
        -- If time is 03:00 (180 seconds) or less
        if totalSeconds <= 180 then
            -- Wait/Yield until an object exists in Zone10
            if #Zone10:GetChildren() == 0 then
                Zone10.ChildAdded:Wait() 
            end
            
            -- Once an object is there, execute the sequence (Max 2 times)
            PerformFarmingPhase()
        end
    end
end
-- If time > 03:00 or after the steps finish, code naturally proceeds to Step 5.

-- ==============================================================
-- STEP 5: Server Hop & Infinite Loop
-- ==============================================================
local function ServerHop()
    local placeId = game.PlaceId
    local jobId = game.JobId
    
    -- Setup script re-execution upon teleporting to the new server
    if queue_on_tp then
        queue_on_tp('loadstring(game:HttpGet("' .. SCRIPT_URL .. '"))()')
    else
        warn("queue_on_teleport is not supported by your executor. Put this script in autoexec.")
    end

    -- URL to fetch a list of active public servers
    local serversApi = "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100"

    -- Function to attempt a server hop
    local function AttemptHop()
        local success, result = pcall(function()
            return HttpService:JSONDecode(game:HttpGet(serversApi))
        end)

        if success and result and result.data then
            for _, server in ipairs(result.data) do
                -- Find a server that isn't full and isn't our current server
                if server.playing < server.maxPlayers and server.id ~= jobId then
                    pcall(function()
                        TeleportService:TeleportToPlaceInstance(placeId, server.id, LocalPlayer)
                    end)
                    task.wait(2) -- Wait for teleport to process before trying another server
                end
            end
        end
    end

    -- Infinite loop: Retry continuously every 3 seconds if the hop fails
    while true do
        AttemptHop()
        task.wait(3)
    end
end

-- Initiate Server Hop
ServerHop()
