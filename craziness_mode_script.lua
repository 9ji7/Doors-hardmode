-- ============================================================
-- [[ CRAZINESS MOD 2026 — ENHANCED v2.0 ]]
-- Improved effects, modular architecture, better kill logic
-- ============================================================

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local Debris            = game:GetService("Debris")
local SoundService      = game:GetService("SoundService")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

-- Папка для сущностей
local EntityFolder = workspace:FindFirstChild("craziness entities")
    or Instance.new("Folder", workspace)
EntityFolder.Name = "craziness entities"

-- ============================================================
-- CONFIG
-- ============================================================
local Config = {
    -- Common Sense
    CS_Name     = "Common Sense",
    CS_Face     = "rbxthumb://type=Asset&id=17831829233&w=420&h=420",
    CS_Warn     = "rbxassetid://108716595659503",
    CS_Fly      = "rbxassetid://140617516722342",
    CS_Speed    = 75,
    CS_Chance   = 15,
    CS_Color    = Color3.fromRGB(10, 10, 10),
    CS_Hint     = "Он не терпит спешки. Когда слышишь его гул — ищи убежище немедленно!",

    -- Red Smile
    RS_Name      = "Red Smile",
    RS_Face      = "rbxthumb://type=Asset&id=12806964203&w=420&h=420",
    RS_Far       = "rbxassetid://9125351660",
    RS_Near      = "rbxassetid://133672210406470",
    RS_Jumpscare = "rbxassetid://130452258247912",
    RS_Speed     = 125,
    RS_Chance    = 12,
    RS_Rebounds  = 3,
    RS_KillRange = 45,
    RS_Color     = Color3.fromRGB(220, 30, 0),
    RS_Hint      = "Красная Улыбка видит тебя издалека, но стены — твоя защита!",

    -- Deer God
    DG_Name      = "Deer God",
    DG_Face      = "rbxthumb://type=Asset&id=12331751916&w=420&h=420",
    DG_Jumpscare = "rbxthumb://type=Asset&id=11394027278&w=420&h=420",
    DG_Ambient   = "rbxassetid://82890415629830",
    DG_Footstep  = "rbxassetid://134645629051473",
    DG_Speed     = 22,
    DG_Chance    = 7,
    DG_KillRange = 20,
    DG_Color     = Color3.fromRGB(80, 160, 80),
    DG_Hint      = "Олений Бог движется медленно, но неотступно. Прячься и не смотри назад.",

    -- Inverted Rebound
    IR_Name    = "Inverted Rebound",
    IR_Face    = "rbxthumb://type=Asset&id=123816386090783&w=420&h=420",
    IR_Arrival = "rbxassetid://136836151370178",
    IR_Move    = "rbxassetid://103078219556352",
    IR_Chance  = 12,
    IR_Speed   = 125,
    IR_Color   = Color3.fromRGB(100, 0, 200),
    IR_Hint    = "Инверсия не терпит шкафов! Оставайся снаружи, пока реальность искажена.",

    -- POR-252-M
    PM_Name      = "POR-252-M",
    PM_Face      = "rbxthumb://type=Asset&id=103247199803614&w=420&h=420",
    PM_Warn      = "rbxassetid://139430154554631",
    PM_Far       = "rbxassetid://140440238391729",
    PM_Near      = "rbxassetid://137180766239401",
    PM_Speed     = 175,
    PM_Chance    = 5,
    PM_Rebounds  = 20,
    PM_KillRange = 45,
    PM_Color     = Color3.fromRGB(0, 120, 255),
    PM_Hint      = "POR-252-M движется с огромной скоростью. Спрячься немедленно!",

    KillRange       = 15,
    ShakeThreshold  = 60,
    HintThreshold   = 80,
    DamageTickRate  = 0.05,
}

-- ============================================================
-- STATE
-- ============================================================
local IR_Counter   = 0
local IR_Active    = false
local DG_Active    = false
local gameSeed = ReplicatedStorage:WaitForChild("GameData"):WaitForChild("Seed", 10)
local RNG = gameSeed and Random.new(gameSeed.Value) or Random.new()
local KillDebounce = false

-- ============================================================
-- SCREEN EFFECTS
-- ============================================================
local ScreenEffects = {}

local function SetupScreenEffects()
    local lighting = game:GetService("Lighting")
    ScreenEffects.Blur      = Instance.new("BlurEffect", lighting)
    ScreenEffects.ColorCorr = Instance.new("ColorCorrectionEffect", lighting)
    ScreenEffects.Bloom     = Instance.new("BloomEffect", lighting)
    ScreenEffects.Blur.Size             = 0
    ScreenEffects.ColorCorr.Saturation  = 0
    ScreenEffects.ColorCorr.Brightness  = 0
    ScreenEffects.ColorCorr.Contrast    = 0
    ScreenEffects.Bloom.Intensity       = 0
end
SetupScreenEffects()

local function UpdateScreenEffects(closestDist, closestName)
    local t = math.clamp(1 - closestDist / Config.ShakeThreshold, 0, 1)
    TweenService:Create(ScreenEffects.Blur, TweenInfo.new(0.3), { Size = t * 8 }):Play()
    TweenService:Create(ScreenEffects.ColorCorr, TweenInfo.new(0.3), {
        Saturation = -t * 0.7,
        Brightness = -t * 0.15,
        Contrast   = t * 0.4,
    }):Play()

    local tintColor = Color3.new(1, 1, 1)
    if closestName == Config.RS_Name then
        tintColor = Color3.fromRGB(255, math.floor(180 - t * 180), math.floor(180 - t * 180))
    elseif closestName == Config.IR_Name then
        tintColor = Color3.fromRGB(220, 180, 255)
    elseif closestName == Config.DG_Name then
        tintColor = Color3.fromRGB(180, 255, 180)
    elseif closestName == Config.PM_Name then
        tintColor = Color3.fromRGB(180, 200, 255)
    end
    TweenService:Create(ScreenEffects.ColorCorr, TweenInfo.new(0.3), { TintColor = tintColor }):Play()
end

local function ClearScreenEffects()
    TweenService:Create(ScreenEffects.Blur, TweenInfo.new(1), { Size = 0 }):Play()
    TweenService:Create(ScreenEffects.ColorCorr, TweenInfo.new(1), {
        Saturation = 0,
        Brightness = 0,
        Contrast   = 0,
        TintColor  = Color3.new(1, 1, 1),
    }):Play()
end

-- ============================================================
-- DEER GOD JUMPSCARE
-- ============================================================
local function DeerGodJumpscare()
    local sg = Instance.new("ScreenGui", LocalPlayer.PlayerGui)
    sg.Name           = "DeerGodJumpscare"
    sg.IgnoreGuiInset = true
    sg.ResetOnSpawn   = false
    sg.DisplayOrder   = 999

    local bg = Instance.new("Frame", sg)
    bg.Size                  = UDim2.new(1, 0, 1, 0)
    bg.BackgroundTransparency = 1
    bg.BorderSizePixel        = 0

    local im = Instance.new("ImageLabel", bg)
    im.Size                  = UDim2.new(1, 0, 1, 0)
    im.Image                 = Config.DG_Jumpscare
    im.BackgroundTransparency = 1
    im.ScaleType             = Enum.ScaleType.Fit

    local pu = Instance.new("Frame", bg)
    pu.Size                  = UDim2.new(1, 0, 1, 0)
    pu.BackgroundColor3      = Color3.fromRGB(80, 0, 120)
    pu.BorderSizePixel        = 0
    pu.BackgroundTransparency = 1

    task.spawn(function()
        local endTime = tick() + 1.1
        local show = true
        while tick() < endTime do
            if show then
                im.ImageTransparency      = 0
                pu.BackgroundTransparency = 1
            else
                im.ImageTransparency      = 1
                pu.BackgroundTransparency = 0
            end
            show = not show
            task.wait(0.1)
        end
        sg:Destroy()
    end)
end

-- ============================================================
-- WHITE FLASH (Red Smile)
-- ============================================================
local function FlashScreen()
    local sg = Instance.new("ScreenGui", LocalPlayer.PlayerGui)
    sg.Name           = "JumpscareFlash"
    sg.IgnoreGuiInset = true
    sg.ResetOnSpawn   = false
    local f = Instance.new("Frame", sg)
    f.Size                   = UDim2.new(1, 0, 1, 0)
    f.BackgroundColor3       = Color3.new(1, 1, 1)
    f.BorderSizePixel         = 0
    f.BackgroundTransparency = 0
    task.wait(0.12)
    TweenService:Create(f, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
    task.delay(0.5, function() sg:Destroy() end)
end

-- ============================================================
-- CAMERA SHAKE
-- ============================================================
local shakeMag = 0
RunService.RenderStepped:Connect(function()
    if shakeMag > 0.01 then
        local offset = Vector3.new(
            (math.random() - 0.5) * shakeMag,
            (math.random() - 0.5) * shakeMag,
            0
        )
        Camera.CFrame = Camera.CFrame * CFrame.new(offset)
        shakeMag = shakeMag * 0.85
    end
end)

local function ShakeCamera(magnitude)
    shakeMag = math.max(shakeMag, magnitude)
end

-- ============================================================
-- HINT GUI
-- ============================================================
local HintGui = nil
local HintCooldown = {}

local function ShowHint(text, color)
    if HintGui then HintGui:Destroy() end
    HintGui = Instance.new("ScreenGui", LocalPlayer.PlayerGui)
    HintGui.Name         = "EntityHint"
    HintGui.ResetOnSpawn = false

    local frame = Instance.new("Frame", HintGui)
    frame.Size                  = UDim2.new(0.5, 0, 0, 70)
    frame.Position              = UDim2.new(0.25, 0, 0.82, 0)
    frame.BackgroundColor3      = Color3.new(0, 0, 0)
    frame.BackgroundTransparency = 1
    frame.BorderSizePixel        = 0
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

    local accent = Instance.new("Frame", frame)
    accent.Size             = UDim2.new(0.005, 0, 1, 0)
    accent.BackgroundColor3 = color
    accent.BorderSizePixel  = 0

    local label = Instance.new("TextLabel", frame)
    label.Size               = UDim2.new(0.99, -8, 1, 0)
    label.Position           = UDim2.new(0.005, 8, 0, 0)
    label.BackgroundTransparency = 1
    label.Text               = text
    label.TextColor3         = Color3.new(1, 1, 1)
    label.TextWrapped        = true
    label.Font               = Enum.Font.GothamMedium
    label.TextSize           = 14
    label.TextXAlignment     = Enum.TextXAlignment.Left
    label.TextTransparency   = 1

    TweenService:Create(frame, TweenInfo.new(0.3), { BackgroundTransparency = 0.35 }):Play()
    TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()

    task.delay(6, function()
        if HintGui and HintGui.Parent then
            TweenService:Create(frame, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
            TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
            task.delay(0.6, function()
                if HintGui then HintGui:Destroy(); HintGui = nil end
            end)
        end
    end)
end

local function TryShowHint(name, text, color)
    if HintCooldown[name] then return end
    HintCooldown[name] = true
    ShowHint(text, color)
    task.delay(20, function() HintCooldown[name] = nil end)
end

-- ============================================================
-- SOUND HELPER
-- ============================================================
local function PlaySound(id, volume, parent, looped, speed)
    local s = Instance.new("Sound", parent or workspace)
    s.SoundId       = id
    s.Volume        = volume or 5
    s.Looped        = looped or false
    s.PlaybackSpeed = speed or 1
    s:Play()
    if not looped then Debris:AddItem(s, 10) end
    return s
end

-- ============================================================
-- PARTICLES HELPER
-- ============================================================
local function AddParticles(parent, color, rate)
    local emitter = Instance.new("ParticleEmitter", parent)
    emitter.Color          = ColorSequence.new(color, Color3.new(0, 0, 0))
    emitter.LightEmission  = 0.5
    emitter.LightInfluence = 0.2
    emitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 2.5),
        NumberSequenceKeypoint.new(1, 0),
    })
    emitter.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.1),
        NumberSequenceKeypoint.new(1, 1),
    })
    emitter.Texture     = "rbxasset://textures/particles/smoke_main.dds"
    emitter.Rate        = rate or 25
    emitter.Speed       = NumberRange.new(3, 8)
    emitter.SpreadAngle = Vector2.new(35, 35)
    emitter.Lifetime    = NumberRange.new(1.5, 3)
    emitter.RotSpeed    = NumberRange.new(-45, 45)
    return emitter
end

-- ============================================================
-- CREATE ENTITY HELPER
-- ============================================================
local function CreateEntity(name, face, size, startPos)
    local ent = Instance.new("Part", EntityFolder)
    ent.Name         = name
    ent.Size         = Vector3.new(size, size, size)
    ent.Transparency = 1
    ent.Anchored     = true
    ent.CanCollide   = false
    ent.CastShadow   = false
    ent.CFrame       = CFrame.new(startPos)

    local bgui = Instance.new("BillboardGui", ent)
    bgui.Size        = UDim2.new(size * 2, 0, size * 2, 0)
    bgui.AlwaysOnTop = false

    local img = Instance.new("ImageLabel", bgui)
    img.Size                  = UDim2.new(1, 0, 1, 0)
    img.Image                 = face
    img.BackgroundTransparency = 1

    return ent, bgui, img
end

-- ============================================================
-- RAYCAST VISIBILITY
-- ============================================================
local function CanSeePlayer(entityPart, playerChar)
    local hrp = playerChar:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local origin = entityPart.Position
    local target = hrp.Position
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {entityPart, playerChar, EntityFolder}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local result = workspace:Raycast(origin, target - origin, params)
    return not result
end

-- ============================================================
-- ROOMS HELPERS
-- ============================================================
local function GetRooms()
    local rf = workspace:FindFirstChild("CurrentRooms")
    if not rf then return {} end
    local r = rf:GetChildren()
    table.sort(r, function(a, b)
        return (tonumber(a.Name) or 0) < (tonumber(b.Name) or 0)
    end)
    return r
end

local function GetRoomNode(room)
    local node = room:FindFirstChild("Door") or room:FindFirstChild("Nodes")
    if not node then
        return room.PrimaryPart and room.PrimaryPart.Position or Vector3.new()
    end
    return node:IsA("Model") and node.PrimaryPart.Position or node.Position
end

-- ============================================================
-- MOVE ALONG PATH
-- ============================================================
local function MoveAlongPath(ent, path, speed, reversed, yOffset)
    yOffset = yOffset or 5
    local indices = {}
    if reversed then
        for i = #path, 1, -1 do indices[#indices + 1] = i end
    else
        for i = 1, #path do indices[#indices + 1] = i end
    end

    for _, i in ipairs(indices) do
        if not ent or not ent.Parent then return end
        local target = GetRoomNode(path[i]) + Vector3.new(0, yOffset, 0)
        local dist   = (ent.Position - target).Magnitude
        if dist < 1 then continue end
        local t = dist / speed
        TweenService:Create(ent, TweenInfo.new(t, Enum.EasingStyle.Linear), {
            CFrame = CFrame.new(target)
        }):Play()
        task.wait(t)
    end
end

-- ============================================================
-- SPAWN: COMMON SENSE
-- ============================================================
local function SpawnCommonSense(reboundCount, roomNum)
    local path = GetRooms()
    if #path == 0 then return end

    PlaySound(Config.CS_Warn, 5, workspace)
    task.wait(2.5)

    local startPos = GetRoomNode(path[1]) + Vector3.new(0, 2, 0)
    local ent, bgui, img = CreateEntity(Config.CS_Name, Config.CS_Face, 5, startPos)
    bgui.Size = UDim2.new(8, 0, 8, 0)

    local smoke = Instance.new("Smoke", ent)
    smoke.Color        = Color3.new(0, 0, 0)
    smoke.Size         = 30
    smoke.Opacity      = 0.7
    smoke.RiseVelocity = 3

    AddParticles(ent, Config.CS_Color, 20)

    local loop = PlaySound(Config.CS_Fly, 8, ent, true)

    task.spawn(function()
        for _ = 1, reboundCount do
            MoveAlongPath(ent, path, Config.CS_Speed, false, 2)
            if not ent.Parent then break end
        end
        loop:Stop()
        TweenService:Create(smoke, TweenInfo.new(1), { Opacity = 0 }):Play()
        task.wait(1)
        if ent.Parent then ent:Destroy() end
    end)
end

-- ============================================================
-- SPAWN: RED SMILE
-- ============================================================
local function SpawnRedSmile(reboundCount, roomNum)
    local path = GetRooms()
    if #path == 0 then return end

    PlaySound(Config.RS_Far, 4, workspace)
    task.wait(1.5)

    local startPos = GetRoomNode(path[1]) + Vector3.new(0, 5, 0)
    local ent, bgui, img = CreateEntity(Config.RS_Name, Config.RS_Face, 6, startPos)

    local light = Instance.new("PointLight", ent)
    light.Color      = Config.RS_Color
    light.Range      = 60
    light.Brightness = 12

    AddParticles(ent, Config.RS_Color, 30)

    task.spawn(function()
        while ent.Parent do
            TweenService:Create(light, TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Brightness = 20 }):Play()
            task.wait(0.4)
            TweenService:Create(light, TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Brightness = 8 }):Play()
            task.wait(0.4)
        end
    end)

    local loop = PlaySound(Config.RS_Near, 10, ent, true)

    task.spawn(function()
        for _ = 1, reboundCount do
            MoveAlongPath(ent, path, Config.RS_Speed, false)
            if not ent.Parent then break end
            MoveAlongPath(ent, path, Config.RS_Speed, true)
            if not ent.Parent then break end
        end
        loop:Stop()
        for i = 0, 10 do
            if not ent.Parent then break end
            light.Brightness = (10 - i) * 1.5
            task.wait(0.05)
        end
        if ent.Parent then ent:Destroy() end
    end)
end

-- ============================================================
-- SPAWN: INVERTED REBOUND
-- ============================================================
local function SpawnInvertedRebound(isFirst)
    local path = GetRooms()
    if #path < 2 then return end

    local lastRoom = path[#path]
    local startPos = GetRoomNode(lastRoom) + Vector3.new(0, 5, 0)

    if isFirst then
        PlaySound(Config.IR_Arrival, 7, workspace)
        task.wait(5)
    else
        local ghost = Instance.new("Part", EntityFolder)
        ghost.Transparency = 1
        ghost.Anchored     = true
        ghost.CanCollide   = false
        ghost.CFrame       = CFrame.new(startPos)
        ghost.Size         = Vector3.new(1, 1, 1)
        PlaySound(Config.IR_Move, 9, ghost)
        Debris:AddItem(ghost, 3)
        task.wait(2)
    end

    local ent, bgui, img = CreateEntity(Config.IR_Name, Config.IR_Face, 5, startPos)

    AddParticles(ent, Config.IR_Color, 35)

    task.spawn(function()
        while ent.Parent do
            TweenService:Create(bgui, TweenInfo.new(0.5, Enum.EasingStyle.Sine), { Size = UDim2.new(14, 0, 14, 0) }):Play()
            task.wait(0.5)
            TweenService:Create(bgui, TweenInfo.new(0.5, Enum.EasingStyle.Sine), { Size = UDim2.new(10, 0, 10, 0) }):Play()
            task.wait(0.5)
        end
    end)

    local loop = PlaySound(Config.IR_Move, 10, ent, true, 1.2)
    local echo = Instance.new("EchoSoundEffect", loop)
    echo.Delay    = 0.12
    echo.Feedback = 0.25
    echo.DryLevel = 0
    echo.WetLevel = -1

    task.spawn(function()
        MoveAlongPath(ent, path, Config.IR_Speed, true)
        loop:Stop()
        if ent.Parent then ent:Destroy() end
    end)
end

-- ============================================================
-- SPAWN: DEER GOD
-- ============================================================
local function SpawnDeerGod()
    if DG_Active then return end
    local path = GetRooms()
    if #path == 0 then return end
    DG_Active = true

    -- Спавнится с первой комнаты, стоит на полу
    local startPos = GetRoomNode(path[1]) + Vector3.new(0, 1.5, 0)

    local ambSound = PlaySound(Config.DG_Ambient, 0, workspace, true, 0.2)
    TweenService:Create(ambSound, TweenInfo.new(4), { Volume = 6 }):Play()

    local ent, bgui, img = CreateEntity(Config.DG_Name, Config.DG_Face, 3, startPos)
    bgui.Size = UDim2.new(5, 0, 7, 0) -- чуть выше чем шире

    local smoke = Instance.new("Smoke", ent)
    smoke.Color        = Color3.fromRGB(60, 120, 60)
    smoke.Size         = 15
    smoke.Opacity      = 0.5
    smoke.RiseVelocity = 1.5

    AddParticles(ent, Config.DG_Color, 15)

    local light = Instance.new("PointLight", ent)
    light.Color      = Color3.fromRGB(100, 200, 100)
    light.Range      = 40
    light.Brightness = 5

    -- Footsteps
    task.spawn(function()
        while ent and ent.Parent do
            PlaySound(Config.DG_Footstep, 4, ent, false, 0.2)
            task.wait(1.1)
        end
    end)

    -- Идёт вперёд по комнатам как обычная сущность
    task.spawn(function()
        MoveAlongPath(ent, path, Config.DG_Speed, false, 1.5)
        TweenService:Create(ambSound, TweenInfo.new(3), { Volume = 0 }):Play()
        TweenService:Create(smoke,   TweenInfo.new(2), { Opacity = 0 }):Play()
        task.wait(3)
        ambSound:Stop()
        if ent.Parent then ent:Destroy() end
        DG_Active = false
    end)
end

-- ============================================================
-- SPAWN: POR-252-M
-- ============================================================
local function SpawnPOR252M(reboundCount)
    local path = GetRooms()
    if #path == 0 then return end

    -- Warning sound
    PlaySound(Config.PM_Warn, 6, workspace)
    task.wait(2)

    local startPos = GetRoomNode(path[1]) + Vector3.new(0, 5, 0)
    local ent, bgui, img = CreateEntity(Config.PM_Name, Config.PM_Face, 6, startPos)

    -- Blue point light
    local light = Instance.new("PointLight", ent)
    light.Color      = Config.PM_Color
    light.Range      = 70
    light.Brightness = 15

    -- Blue particles
    AddParticles(ent, Config.PM_Color, 40)

    -- Pulsing light
    task.spawn(function()
        while ent.Parent do
            TweenService:Create(light, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Brightness = 25 }):Play()
            task.wait(0.2)
            TweenService:Create(light, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Brightness = 8 }):Play()
            task.wait(0.2)
        end
    end)

    -- Entity shakes while moving
    task.spawn(function()
        while ent and ent.Parent do
            local offset = Vector3.new(
                (math.random() - 0.5) * 1.5,
                (math.random() - 0.5) * 1.5,
                (math.random() - 0.5) * 1.5
            )
            ent.CFrame = ent.CFrame * CFrame.new(offset)
            task.wait(0.05)
        end
    end)

    local farSound = PlaySound(Config.PM_Far, 5, workspace, true)
    local nearSound = PlaySound(Config.PM_Near, 0, ent, true)

    task.spawn(function()
        for _ = 1, reboundCount do
            -- Forward
            MoveAlongPath(ent, path, Config.PM_Speed, false)
            if not ent.Parent then break end
            -- Backward
            MoveAlongPath(ent, path, Config.PM_Speed, true)
            if not ent.Parent then break end
        end
        farSound:Stop()
        nearSound:Stop()
        if ent.Parent then ent:Destroy() end
    end)

    -- Near sound volume scales with proximity
    task.spawn(function()
        while ent and ent.Parent do
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local dist = (ent.Position - hrp.Position).Magnitude
                local vol = math.clamp(1 - dist / 80, 0, 1) * 10
                nearSound.Volume = vol
                -- Camera shake scales with proximity too
                if dist < Config.ShakeThreshold then
                    local str = math.clamp((Config.ShakeThreshold - dist) / Config.ShakeThreshold * 1.2, 0, 1.2)
                    shakeMag = math.max(shakeMag, str)
                end
            end
            task.wait(0.1)
        end
    end)
end

-- ============================================================
-- DAMAGE LOOP + EFFECTS
-- ============================================================
task.spawn(function()
    while task.wait(Config.DamageTickRate) do
        local char = LocalPlayer.Character
        if not char then continue end
        local hum = char:FindFirstChild("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp or hum.Health <= 0 then continue end

        local isHiding    = char:GetAttribute("Hiding") == true
        local entities    = EntityFolder:GetChildren()
        local closestDist = math.huge
        local closestName = nil
        local killed      = false

        for _, e in ipairs(entities) do
            if not e:IsA("Part") then continue end
            local dist = (e.Position - hrp.Position).Magnitude

            if dist < closestDist then
                closestDist = dist
                closestName = e.Name
            end

            -- Hints
            if dist < Config.HintThreshold then
                if e.Name == Config.CS_Name then
                    TryShowHint(e.Name, Config.CS_Hint, Config.CS_Color)
                elseif e.Name == Config.RS_Name then
                    TryShowHint(e.Name, Config.RS_Hint, Config.RS_Color)
                elseif e.Name == Config.IR_Name then
                    TryShowHint(e.Name, Config.IR_Hint, Config.IR_Color)
                elseif e.Name == Config.DG_Name then
                    TryShowHint(e.Name, Config.DG_Hint, Config.DG_Color)
                elseif e.Name == Config.PM_Name then
                    TryShowHint(e.Name, Config.PM_Hint, Config.PM_Color)
                end
            end

            -- Camera shake
            if dist < Config.ShakeThreshold then
                local shakeStr = math.clamp((Config.ShakeThreshold - dist) / Config.ShakeThreshold * 0.35, 0, 0.35)
                ShakeCamera(shakeStr)
            end

            if killed then continue end

            -- Kill logic
            if e.Name == Config.IR_Name then
                if isHiding and dist < 55 then
                    killed = true
                    hum:SetAttribute("DeathCause", e.Name)
                    hum.Health = 0
                end
            elseif e.Name == Config.DG_Name then
                if dist < Config.DG_KillRange and not isHiding and CanSeePlayer(e, char) then
                    if not KillDebounce then
                        KillDebounce = true
                        killed = true
                        DeerGodJumpscare()
                        task.delay(0.5, function()
                            hum:SetAttribute("DeathCause", e.Name)
                            hum.Health = 0
                        end)
                        task.delay(3, function() KillDebounce = false end)
                    end
                end
            else
                local range = (e.Name == Config.RS_Name) and Config.RS_KillRange
                    or (e.Name == Config.PM_Name) and Config.PM_KillRange
                    or Config.KillRange
                if dist < range and not isHiding and CanSeePlayer(e, char) then
                    if not KillDebounce then
                        KillDebounce = true
                        killed = true
                        if e.Name == Config.RS_Name then
                            FlashScreen()
                            PlaySound(Config.RS_Jumpscare, 10, workspace)
                        end
                        task.delay(0.15, function()
                            hum:SetAttribute("DeathCause", e.Name)
                            hum.Health = 0
                        end)
                        task.delay(3, function() KillDebounce = false end)
                    end
                end
            end
        end

        -- Screen effects
        if closestDist < Config.ShakeThreshold then
            UpdateScreenEffects(closestDist, closestName)
        else
            ClearScreenEffects()
        end
    end
end)

-- ============================================================
-- SPAWN CONTROLLER
-- ============================================================
task.spawn(function()
    local latestRoom = ReplicatedStorage:WaitForChild("GameData"):WaitForChild("LatestRoom")
    latestRoom.Changed:Connect(function(val)
        if val <= 5 then return end

        -- Inverted Rebound
        if not IR_Active then
            if Random.new(val * 2 + 1):NextInteger(1, 100) <= Config.IR_Chance then
                IR_Active  = true
                IR_Counter = 0
            end
        end
        if IR_Active and IR_Counter < 2 then
            IR_Counter = IR_Counter + 1
            task.spawn(function() SpawnInvertedRebound(IR_Counter == 1) end)
            if IR_Counter >= 2 then IR_Active = false end
        end

        -- Deer God
        if not DG_Active and Random.new(val * 3 + 2):NextInteger(1, 100) <= Config.DG_Chance then
            task.spawn(function()
                task.wait(2)
                SpawnDeerGod()
            end)
        end

        -- Common Sense
        task.spawn(function()
            if val == 50 then
                SpawnCommonSense(150, val)
            elseif Random.new(val * 4 + 5):NextInteger(1, 100) <= Config.CS_Chance then
                SpawnCommonSense(5, val)
            end
        end)

        -- POR-252-M (синхронизация через номер комнаты)
        if Random.new(val * 7 + 3):NextInteger(1, 100) <= Config.PM_Chance then
            task.spawn(function()
                task.wait(1.5)
                SpawnPOR252M(Config.PM_Rebounds)
            end)
        end

        -- Red Smile
        task.spawn(function()
            if Random.new(val * 5 + 4):NextInteger(1, 100) <= Config.RS_Chance then
                task.wait(1)
                SpawnRedSmile(Config.RS_Rebounds, val)
            end
        end)
    end)
end)

-- ============================================================
-- CLEANUP ON RESPAWN
-- ============================================================
LocalPlayer.CharacterAdded:Connect(function()
    KillDebounce = false
    ClearScreenEffects()
    if HintGui then HintGui:Destroy(); HintGui = nil end
    for _, e in ipairs(EntityFolder:GetChildren()) do e:Destroy() end
    IR_Counter   = 0
    IR_Active    = false
    DG_Active    = false
    HintCooldown = {}
end)

print("Craziness Mod v2.2 LOADED! 🌑🔴🌀🦌💙")
