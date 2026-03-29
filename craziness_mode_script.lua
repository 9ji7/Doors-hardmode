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
    DG_KillRange = 30,
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

    -- XV-35
    XV_Name      = "XV-35",
    XV_Face      = "rbxthumb://type=Asset&id=87880354500320&w=420&h=420",
    XV_Sound     = "rbxassetid://9125351660",
    XV_Speed     = 150,
    XV_Chance    = 20,
    XV_KillRange = 120,
    XV_Color     = Color3.fromRGB(0, 210, 220),
    XV_Hint      = "XV-35 несётся сквозь коридоры. Стены — единственное что тебя спасёт!",

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
local KillDebounce = false

-- Получаем Game Seed от Doors для синхронизации мультиплеера
local GameSeed = 0
task.spawn(function()
    local ok, data = pcall(function()
        return ReplicatedStorage:WaitForChild("GameData", 10)
    end)
    if ok and data then
        local seedVal = data:FindFirstChild("GameSeed")
        if seedVal then
            GameSeed = seedVal.Value
        end
    end
end)

-- Функция которая даёт одинаковый результат у всех игроков
-- на одной и той же комнате с одним и тем же seed
local function SyncedRandom(roomVal, entityOffset)
    return Random.new(GameSeed + roomVal * 100 + entityOffset):NextInteger(1, 100)
end

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

-- Показывает подсказку только ОДИН РАЗ за всю игру
local HintShown = {}
local function TryShowHint(name, text, color)
    if HintShown[name] then return end
    HintShown[name] = true
    ShowHint(text, color)
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
-- ent — основной Part, двигается и содержит все эффекты
-- тряска через BillboardGui.StudsOffsetWorldSpace
-- sp возвращается как ent для совместимости
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
    bgui.Size               = UDim2.new(size * 2, 0, size * 2, 0)
    bgui.AlwaysOnTop        = false
    bgui.StudsOffsetWorldSpace = Vector3.new(0, 0, 0)

    local img = Instance.new("ImageLabel", bgui)
    img.Size                   = UDim2.new(1, 0, 1, 0)
    img.Image                  = face
    img.BackgroundTransparency = 1

    -- sp = ent для совместимости со всем кодом ниже
    return ent, bgui, img, ent
end

-- Функция тряски энтити через StudsOffsetWorldSpace
local function ShakeEntity(bgui, strengthX, strengthY, interval)
    task.spawn(function()
        local parent = bgui.Parent
        while parent and parent.Parent do
            local ox = (math.random()-0.5) * 2 * strengthX
            local oy = (math.random()-0.5) * 2 * strengthY
            -- Плавно интерполируем к новой позиции
            local steps = math.max(1, math.floor(interval / 0.016))
            local curX = bgui.StudsOffsetWorldSpace.X
            local curY = bgui.StudsOffsetWorldSpace.Y
            for i = 1, steps do
                if not parent.Parent then break end
                local t = i / steps
                bgui.StudsOffsetWorldSpace = Vector3.new(
                    curX + (ox - curX) * t,
                    curY + (oy - curY) * t,
                    0
                )
                task.wait(0.016)
            end
        end
        if bgui and bgui.Parent then
            bgui.StudsOffsetWorldSpace = Vector3.new(0, 0, 0)
        end
    end)
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
    if not rf then
        warn("CRAZINESS MOD: CurrentRooms не найден в workspace!")
        return {}
    end
    local r = rf:GetChildren()
    if #r == 0 then
        warn("CRAZINESS MOD: CurrentRooms пустой!")
        return {}
    end
    table.sort(r, function(a, b)
        return (tonumber(a.Name) or 0) < (tonumber(b.Name) or 0)
    end)
    print("CRAZINESS MOD: Найдено комнат: " .. #r .. " | Первая: " .. r[1].Name .. " | Последняя: " .. r[#r].Name)
    return r
end

local function GetRoomNode(room)
    local node = room:FindFirstChild("Door") or room:FindFirstChild("Nodes")
    if not node then
        warn("CRAZINESS MOD: У комнаты " .. room.Name .. " нет Door/Nodes")
        -- Ищем любой BasePart внутри комнаты
        for _, v in ipairs(room:GetDescendants()) do
            if v:IsA("BasePart") then
                return v.Position
            end
        end
        return Vector3.new()
    end
    if node:IsA("Model") then
        if node.PrimaryPart then
            return node.PrimaryPart.Position
        else
            warn("CRAZINESS MOD: " .. room.Name .. "/" .. node.Name .. " Model без PrimaryPart")
            for _, v in ipairs(node:GetDescendants()) do
                if v:IsA("BasePart") then return v.Position end
            end
            return Vector3.new()
        end
    end
    if node:IsA("BasePart") then
        return node.Position
    end
    -- Folder или что-то другое — ищем первый BasePart внутри
    for _, v in ipairs(node:GetDescendants()) do
        if v:IsA("BasePart") then return v.Position end
    end
    warn("CRAZINESS MOD: Не удалось найти позицию для " .. room.Name)
    return Vector3.new()
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
    TryShowHint(Config.CS_Name, Config.CS_Hint, Config.CS_Color)

    local startPos = GetRoomNode(path[1]) + Vector3.new(0, 2, 0)
    local ent, bgui, img, sp = CreateEntity(Config.CS_Name, Config.CS_Face, 5, startPos)
    bgui.Size = UDim2.new(12, 0, 12, 0)
    bgui.AlwaysOnTop = false

    local smokes = {}
    local smokeSettings = {
        {Size = 25, Opacity = 0.8, RiseVelocity = 0},
        {Size = 20, Opacity = 0.7, RiseVelocity = 1},
        {Size = 18, Opacity = 0.8, RiseVelocity = -1},
        {Size = 22, Opacity = 0.7, RiseVelocity = 2},
    }
    for _, s in ipairs(smokeSettings) do
        local smoke = Instance.new("Smoke", sp)
        smoke.Color        = Color3.new(0, 0, 0)
        smoke.Size         = s.Size
        smoke.Opacity      = s.Opacity
        smoke.RiseVelocity = s.RiseVelocity
        smokes[#smokes + 1] = smoke
    end

    AddParticles(sp, Config.CS_Color, 20)
    local loop = PlaySound(Config.CS_Fly, 8, sp, true)

    task.spawn(function()
        task.wait(3)
        for _ = 1, reboundCount do
            MoveAlongPath(ent, path, Config.CS_Speed, false, 2)
            if not ent.Parent then break end
        end
        loop:Stop()
        for _, sm in ipairs(smokes) do
            TweenService:Create(sm, TweenInfo.new(1), { Opacity = 0 }):Play()
        end
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
    TryShowHint(Config.RS_Name, Config.RS_Hint, Config.RS_Color)

    local startPos = GetRoomNode(path[1]) + Vector3.new(0, 5, 0)
    local ent, bgui, img, sp = CreateEntity(Config.RS_Name, Config.RS_Face, 6, startPos)

    local light = Instance.new("PointLight", sp)
    light.Color      = Config.RS_Color
    light.Range      = 60
    light.Brightness = 12

    AddParticles(sp, Config.RS_Color, 30)
    ShakeEntity(bgui, 1.2, 0.8, 0.06) -- RS влево-вправо сильная

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
        task.wait(3)
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
        TryShowHint(Config.IR_Name, Config.IR_Hint, Config.IR_Color)
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

    local ent, bgui, img, sp = CreateEntity(Config.IR_Name, Config.IR_Face, 5, startPos)

    AddParticles(sp, Config.IR_Color, 35)
    ShakeEntity(bgui, 1.8, 1.5, 0.05) -- IR все стороны агрессивная

    task.spawn(function()
        while ent.Parent do
            TweenService:Create(bgui, TweenInfo.new(0.5, Enum.EasingStyle.Sine), { Size = UDim2.new(14, 0, 14, 0) }):Play()
            task.wait(0.5)
            TweenService:Create(bgui, TweenInfo.new(0.5, Enum.EasingStyle.Sine), { Size = UDim2.new(10, 0, 10, 0) }):Play()
            task.wait(0.5)
        end
    end)

    local loop = PlaySound(Config.IR_Move, 10, sp, true, 1.2)
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
    TryShowHint(Config.DG_Name, Config.DG_Hint, Config.DG_Color)
    TweenService:Create(ambSound, TweenInfo.new(4), { Volume = 6 }):Play()

    local ent, bgui, img, sp = CreateEntity(Config.DG_Name, Config.DG_Face, 3, startPos)
    bgui.Size = UDim2.new(5, 0, 7, 0)

    local smoke = Instance.new("Smoke", sp)
    smoke.Color        = Color3.fromRGB(60, 120, 60)
    smoke.Size         = 15
    smoke.Opacity      = 0.5
    smoke.RiseVelocity = 1.5

    AddParticles(sp, Config.DG_Color, 15)

    local light = Instance.new("PointLight", sp)
    light.Color      = Color3.fromRGB(100, 200, 100)
    light.Range      = 40
    light.Brightness = 5

    -- Afterimage: каждые 0.3с спавним полупрозрачный клон который исчезает
    task.spawn(function()
        while ent and ent.Parent do
            task.wait(0.3)
            if not ent.Parent then break end
            local ghost = Instance.new("Part", EntityFolder)
            ghost.Name             = "DG_Ghost"
            ghost.Size             = ent.Size
            ghost.Anchored         = true
            ghost.CanCollide       = false
            ghost.CastShadow       = false
            ghost.Transparency     = 0.5
            ghost.Color            = Color3.fromRGB(80, 160, 80)
            ghost.Material         = Enum.Material.Neon
            ghost.CFrame           = ent.CFrame
            local gb = Instance.new("BillboardGui", ghost)
            gb.Size = bgui.Size
            local gi = Instance.new("ImageLabel", gb)
            gi.Size = UDim2.new(1,0,1,0)
            gi.Image = Config.DG_Face
            gi.BackgroundTransparency = 1
            gi.ImageTransparency = 0.6
            -- Затухает и исчезает
            TweenService:Create(ghost, TweenInfo.new(0.5), { Transparency = 1 }):Play()
            TweenService:Create(gi,    TweenInfo.new(0.5), { ImageTransparency = 1 }):Play()
            Debris:AddItem(ghost, 0.6)
        end
    end)

    -- Пульсация размера billboard — дышит как живой
    task.spawn(function()
        while ent and ent.Parent do
            TweenService:Create(bgui, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                Size = UDim2.new(6, 0, 8.5, 0)
            }):Play()
            task.wait(1.2)
            TweenService:Create(bgui, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                Size = UDim2.new(4.5, 0, 6.5, 0)
            }):Play()
            task.wait(1.2)
        end
    end)

    -- Footsteps
    task.spawn(function()
        while ent and ent.Parent do
            PlaySound(Config.DG_Footstep, 4, sp, false, 0.2)
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

    PlaySound(Config.PM_Warn, 6, workspace)
    TryShowHint(Config.PM_Name, Config.PM_Hint, Config.PM_Color)

    local startPos = GetRoomNode(path[1]) + Vector3.new(0, 5, 0)
    local ent, bgui, img, sp = CreateEntity(Config.PM_Name, Config.PM_Face, 6, startPos)

    -- Blue point light
    local light = Instance.new("PointLight", sp)
    light.Color      = Config.PM_Color
    light.Range      = 70
    light.Brightness = 15

    -- Blue particles
    AddParticles(sp, Config.PM_Color, 40)
    ShakeEntity(bgui, 3.0, 2.5, 0.02) -- PM жёсткая

    -- Pulsing light
    task.spawn(function()
        while ent.Parent do
            TweenService:Create(light, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Brightness = 25 }):Play()
            task.wait(0.2)
            TweenService:Create(light, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Brightness = 8 }):Play()
            task.wait(0.2)
        end
    end)

    local farSound = PlaySound(Config.PM_Far, 5, workspace, true)
    local nearSound = PlaySound(Config.PM_Near, 0, sp, true)

    task.spawn(function()
        task.wait(3)
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
                -- Экран трясётся жёстко с 100 студов
                if dist < 100 then
                    local str = math.clamp((100 - dist) / 100 * 2.5, 0, 2.5)
                    shakeMag = math.max(shakeMag, str)
                end
            end
            task.wait(0.1)
        end
    end)
end

-- ============================================================
-- JUMPSCARE: XV-35
-- ============================================================
local function XV35Jumpscare()
    local sg = Instance.new("ScreenGui", LocalPlayer.PlayerGui)
    sg.Name           = "XV35Jumpscare"
    sg.ResetOnSpawn   = false
    sg.DisplayOrder   = 999
    sg.IgnoreGuiInset = true

    -- Фон фиксированный на весь экран
    local bg = Instance.new("Frame", sg)
    bg.Size              = UDim2.new(1, 0, 1, 0)
    bg.Position          = UDim2.new(0, 0, 0, 0)
    bg.BorderSizePixel   = 0
    bg.BackgroundColor3  = Color3.fromRGB(120, 0, 200)

    -- Картинка поверх фона
    local img = Instance.new("ImageLabel", bg)
    img.Size                   = UDim2.new(1, 0, 1, 0)
    img.Position               = UDim2.new(0, 0, 0, 0)
    img.BackgroundTransparency = 1
    img.Image                  = Config.XV_Face
    img.ScaleType              = Enum.ScaleType.Fit

    local colors = {
        Color3.fromRGB(120, 0, 200),
        Color3.fromRGB(220, 0, 0),
        Color3.fromRGB(0, 210, 220),
        Color3.fromRGB(200, 0, 150),
        Color3.fromRGB(0, 180, 255),
    }
    local running = true
    task.spawn(function()
        while running do
            -- Картинка рандомно крутится и меняет размер (быстро)
            img.Size     = UDim2.new(0.7 + math.random() * 0.6, 0, 0.7 + math.random() * 0.6, 0)
            img.Position = UDim2.new(
                0.5 - img.Size.X.Scale/2 + (math.random()-0.5)*0.1, 0,
                0.5 - img.Size.Y.Scale/2 + (math.random()-0.5)*0.1, 0
            )
            img.Rotation         = (math.random()-0.5) * 60
            bg.BackgroundColor3  = colors[math.random(1, #colors)]
            task.wait(0.02)
        end
    end)
    task.wait(1)
    running = false
    sg:Destroy()
end

-- ============================================================
-- SPAWN: XV-35
-- ============================================================
local function SpawnXV35()
    local path = GetRooms()
    if #path == 0 then return end

    TryShowHint(Config.XV_Name, Config.XV_Hint, Config.XV_Color)

    local startPos = GetRoomNode(path[1]) + Vector3.new(0, 5, 0)
    local ent, bgui, img, sp = CreateEntity(Config.XV_Name, Config.XV_Face, 5, startPos)

    -- RushNew — основной контролируемый Part внутри энтити
    local RushNew = Instance.new("Part", ent)
    RushNew.Name         = "RushNew"
    RushNew.Size         = Vector3.new(5, 5, 5)
    RushNew.Transparency = 1
    RushNew.Anchored     = false
    RushNew.CanCollide   = false
    RushNew.CastShadow   = false
    RushNew.Massless     = true
    local rushWeld = Instance.new("WeldConstraint", ent)
    rushWeld.Part0 = ent
    rushWeld.Part1 = RushNew

    -- Свет на основном Part (работает надёжно)
    local light = Instance.new("PointLight", ent)
    light.Color      = Config.XV_Color
    light.Range      = 60
    light.Brightness = 12

    -- Тряска billboard через StudsOffsetWorldSpace
    ShakeEntity(bgui, 2.0, 1.6, 0.05) -- XV сильная

    -- Пульсация света
    task.spawn(function()
        while ent.Parent do
            TweenService:Create(light, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Brightness = 22 }):Play()
            task.wait(0.3)
            TweenService:Create(light, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Brightness = 8 }):Play()
            task.wait(0.3)
        end
    end)

    -- Рандомный ротейт RushNew
    task.spawn(function()
        while ent and ent.Parent do
            RushNew.CFrame = ent.CFrame * CFrame.Angles(
                math.rad(math.random(0, 360)),
                math.rad(math.random(0, 360)),
                math.rad(math.random(0, 360))
            )
            task.wait(0.1)
        end
    end)

    -- Тряска камеры
    task.spawn(function()
        while ent and ent.Parent do
            local char = LocalPlayer.Character
            local hrp  = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local dist = (ent.Position - hrp.Position).Magnitude
                if dist < 120 then
                    local str = math.clamp((120 - dist) / 120 * 1.8, 0, 1.8)
                    shakeMag = math.max(shakeMag, str)
                end
            end
            task.wait(0.05)
        end
    end)

    -- Кольцо через ParticleEmitter — спавнится внутри, расширяется и исчезает
    local attach = Instance.new("Attachment", ent)
    local ringEmitter = Instance.new("ParticleEmitter", attach)
    ringEmitter.Texture        = "rbxassetid://2763450508"
    ringEmitter.Color          = ColorSequence.new(Config.XV_Color)
    ringEmitter.LightEmission  = 1
    ringEmitter.LightInfluence = 0
    ringEmitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.5, 8),
        NumberSequenceKeypoint.new(1, 16),
    })
    ringEmitter.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(0.6, 0.3),
        NumberSequenceKeypoint.new(1, 1),
    })
    ringEmitter.Lifetime    = NumberRange.new(1.2, 1.2)
    ringEmitter.Rate        = 2
    ringEmitter.Speed       = NumberRange.new(0, 0)
    ringEmitter.SpreadAngle = Vector2.new(0, 0)
    ringEmitter.Rotation    = NumberRange.new(0, 0)
    ringEmitter.RotSpeed    = NumberRange.new(0, 0)
    -- Пульсация света
    task.spawn(function()
        while ent.Parent do
            TweenService:Create(light, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Brightness = 22 }):Play()
            task.wait(0.3)
            TweenService:Create(light, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Brightness = 8 }):Play()
            task.wait(0.3)
        end
    end)

    -- Звук
    local snd = Instance.new("Sound", sp)
    snd.SoundId       = Config.XV_Sound
    snd.Volume        = 6
    snd.PlaybackSpeed = 3
    snd.Looped        = true
    local distEff = Instance.new("DistortionSoundEffect", snd)
    distEff.Level = 0.99
    local eq = Instance.new("EqualizerSoundEffect", snd)
    eq.HighGain = 10
    eq.MidGain  = -9.8
    eq.LowGain  = -11.6
    snd:Play()

    -- 2 ребаунда → фейк деспавн → 10 сек → 3 ребаунда
    task.spawn(function()
        task.wait(3)
        -- 1 ребаунд = вперёд + назад
        MoveAlongPath(ent, path, Config.XV_Speed, false)
        if not ent.Parent then return end
        MoveAlongPath(ent, path, Config.XV_Speed, true)
        if not ent.Parent then return end
        MoveAlongPath(ent, path, Config.XV_Speed, false)
        if not ent.Parent then return end
        MoveAlongPath(ent, path, Config.XV_Speed, true)
        if not ent.Parent then return end

        -- Фейк деспавн
        snd:Stop()
        ent.Parent = nil
        sp.Parent  = nil

        task.wait(10)

        -- Возвращаем
        local newPath = GetRooms()
        if #newPath == 0 then return end
        local newPos = GetRoomNode(newPath[1]) + Vector3.new(0, 5, 0)
        ent.CFrame = CFrame.new(newPos)
        sp.CFrame  = CFrame.new(newPos)
        ent.Parent = EntityFolder
        sp.Parent  = EntityFolder
        snd:Play()
        task.wait(3)

        MoveAlongPath(ent, newPath, Config.XV_Speed, false)
        if not ent.Parent then return end
        MoveAlongPath(ent, newPath, Config.XV_Speed, true)
        if not ent.Parent then return end
        MoveAlongPath(ent, newPath, Config.XV_Speed, false)
        if not ent.Parent then return end
        MoveAlongPath(ent, newPath, Config.XV_Speed, true)
        if not ent.Parent then return end
        MoveAlongPath(ent, newPath, Config.XV_Speed, false)
        if not ent.Parent then return end
        MoveAlongPath(ent, newPath, Config.XV_Speed, true)
        if not ent.Parent then return end

        snd:Stop()
        if ent.Parent then ent:Destroy() end
        if sp.Parent  then sp:Destroy()  end
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

            -- Camera shake — разный радиус и сила для каждого энтити
            local shakeRadius, shakeStrMax
            if e.Name == Config.PM_Name then
                shakeRadius = 100; shakeStrMax = 2.5
            elseif e.Name == Config.RS_Name then
                shakeRadius = 80;  shakeStrMax = 0.6
            elseif e.Name == Config.IR_Name then
                shakeRadius = 80;  shakeStrMax = 0.5
            elseif e.Name == Config.CS_Name then
                shakeRadius = 70;  shakeStrMax = 0.3
            elseif e.Name == Config.DG_Name then
                shakeRadius = 70;  shakeStrMax = 0.4
            else
                shakeRadius = 60;  shakeStrMax = 0.35
            end
            if dist < shakeRadius then
                local shakeStr = math.clamp((shakeRadius - dist) / shakeRadius * shakeStrMax, 0, shakeStrMax)
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
            elseif e.Name == Config.XV_Name then
                if dist < Config.XV_KillRange and not isHiding and CanSeePlayer(e, char) then
                    if not KillDebounce then
                        KillDebounce = true
                        killed = true
                        task.spawn(XV35Jumpscare)
                        task.delay(0.5, function()
                            hum:SetAttribute("DeathCause", e.Name)
                            hum.Health = 0
                        end)
                        task.delay(3, function() KillDebounce = false end)
                    end
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

        -- На ранних комнатах шансы вдвое меньше
        local earlyMult = (val < 15) and 0.5 or 1

        -- Inverted Rebound
        if not IR_Active then
            if SyncedRandom(val, 1) <= Config.IR_Chance * earlyMult then
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
        if not DG_Active and SyncedRandom(val, 2) <= Config.DG_Chance * earlyMult then
            task.spawn(function() task.wait(2) SpawnDeerGod() end)
        end

        -- Common Sense
        task.spawn(function()
            if val == 50 then
                SpawnCommonSense(150, val)
            elseif SyncedRandom(val, 3) <= Config.CS_Chance * earlyMult then
                SpawnCommonSense(5, val)
            end
        end)

        -- POR-252-M
        if SyncedRandom(val, 4) <= Config.PM_Chance * earlyMult then
            task.spawn(function() task.wait(1.5) SpawnPOR252M(Config.PM_Rebounds) end)
        end

        -- Red Smile
        task.spawn(function()
            if SyncedRandom(val, 5) <= Config.RS_Chance * earlyMult then
                task.wait(1)
                SpawnRedSmile(Config.RS_Rebounds, val)
            end
        end)

        -- XV-35
        if SyncedRandom(val, 6) <= Config.XV_Chance * earlyMult then
            task.spawn(function() SpawnXV35() end)
        end
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
    HintShown    = {}
end)

print("Craziness Mod v2.2 LOADED! 🌑🔴🌀🦌💙🩵")
