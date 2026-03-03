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
    -- Common Sense (🌑)
    CS_Name     = "Common Sense",
    CS_Face     = "rbxthumb://type=Asset&id=17831829233&w=420&h=420",
    CS_Warn     = "rbxassetid://108716595659503",
    CS_Fly      = "rbxassetid://140617516722342",
    CS_Speed    = 75,
    CS_Chance   = 30,
    CS_Color    = Color3.fromRGB(10, 10, 10),
    CS_Hint     = "Он не терпит спешки. Когда слышишь его гул — ищи убежище немедленно!",

    -- Red Smile (🔴)
    RS_Name      = "Red Smile",
    RS_Face      = "rbxthumb://type=Asset&id=12806964203&w=420&h=420",
    RS_Far       = "rbxassetid://9125351660",
    RS_Near      = "rbxassetid://133672210406470",
    RS_Jumpscare = "rbxassetid://130452258247912",
    RS_Speed     = 125,
    RS_Chance    = 35,
    RS_Rebounds  = 3,
    RS_KillRange = 45,
    RS_Color     = Color3.fromRGB(220, 30, 0),
    RS_Hint      = "Красная Улыбка видит тебя издалека, но стены — твоя защита!",

    -- Inverted Rebound (🌀)
    IR_Name    = "Inverted Rebound",
    IR_Face    = "rbxthumb://type=Asset&id=123816386090783&w=420&h=420",
    IR_Arrival = "rbxassetid://136836151370178",
    IR_Move    = "rbxassetid://103078219556352",
    IR_Chance  = 35,
    IR_Speed   = 125,
    IR_Color   = Color3.fromRGB(100, 0, 200),
    IR_Hint    = "Инверсия не терпит шкафов! Оставайся снаружи, пока реальность искажена.",

    KillRange       = 15,
    ShakeThreshold  = 60,  -- дистанция начала тряски камеры
    HintThreshold   = 80,  -- дистанция показа подсказки
    DamageTickRate  = 0.05,
}

-- ============================================================
-- STATE
-- ============================================================
local IR_Counter   = 0
local IR_Active    = false
local RNG          = Random.new()
local KillDebounce = false

-- ============================================================
-- SCREEN EFFECTS
-- ============================================================
local ScreenEffects = {}

-- Создаём эффекты один раз и управляем ими
local function SetupScreenEffects()
    local lighting = game:GetService("Lighting")
    ScreenEffects.Blur        = Instance.new("BlurEffect",        lighting)
    ScreenEffects.ColorCorr   = Instance.new("ColorCorrectionEffect", lighting)
    ScreenEffects.Bloom       = Instance.new("BloomEffect",       lighting)
    ScreenEffects.Blur.Size   = 0
    ScreenEffects.ColorCorr.Saturation = 0
    ScreenEffects.ColorCorr.Brightness = 0
    ScreenEffects.ColorCorr.Contrast   = 0
    ScreenEffects.Bloom.Intensity      = 0
end
SetupScreenEffects()

-- Обновление эффектов на основе ближайшей сущности
local function UpdateScreenEffects(closestDist, closestName)
    local t = math.clamp(1 - closestDist / Config.ShakeThreshold, 0, 1)
    TweenService:Create(ScreenEffects.Blur,      TweenInfo.new(0.3), { Size = t * 8 }):Play()
    TweenService:Create(ScreenEffects.ColorCorr, TweenInfo.new(0.3), {
        Saturation = -t * 0.7,
        Brightness = -t * 0.15,
        Contrast   = t * 0.4,
    }):Play()

    if closestName == Config.RS_Name then
        TweenService:Create(ScreenEffects.ColorCorr, TweenInfo.new(0.3), {
            TintColor = Color3.fromRGB(255, 180 - t*180, 180 - t*180)
        }):Play()
    elseif closestName == Config.IR_Name then
        TweenService:Create(ScreenEffects.ColorCorr, TweenInfo.new(0.3), {
            TintColor = Color3.fromRGB(220, 180, 255)
        }):Play()
    else
        TweenService:Create(ScreenEffects.ColorCorr, TweenInfo.new(0.3), {
            TintColor = Color3.new(1,1,1)
        }):Play()
    end
end

local function ClearScreenEffects()
    TweenService:Create(ScreenEffects.Blur,      TweenInfo.new(1), { Size = 0 }):Play()
    TweenService:Create(ScreenEffects.ColorCorr, TweenInfo.new(1), {
        Saturation = 0, Brightness = 0, Contrast = 0, TintColor = Color3.new(1,1,1)
    }):Play()
end

-- Jumpscare — белая вспышка
local function FlashScreen()
    local sg = Instance.new("ScreenGui", LocalPlayer.PlayerGui)
    sg.Name = "JumpscareFlash"
    sg.IgnoreGuiInset = true
    sg.ResetOnSpawn = false
    local f = Instance.new("Frame", sg)
    f.Size = UDim2.new(1,0,1,0)
    f.BackgroundColor3 = Color3.new(1,1,1)
    f.BorderSizePixel  = 0
    f.BackgroundTransparency = 0

    TweenService:Create(f, TweenInfo.new(0.08), { BackgroundTransparency = 0 }):Play()
    task.wait(0.12)
    TweenService:Create(f, TweenInfo.new(0.4),  { BackgroundTransparency = 1 }):Play()
    task.delay(0.5, function() sg:Destroy() end)
end

-- Тряска камеры
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

local function ShowHint(text, color)
    if HintGui then HintGui:Destroy() end
    HintGui = Instance.new("ScreenGui", LocalPlayer.PlayerGui)
    HintGui.Name = "EntityHint"
    HintGui.ResetOnSpawn = false

    local frame = Instance.new("Frame", HintGui)
    frame.Size = UDim2.new(0.5, 0, 0, 70)
    frame.Position = UDim2.new(0.25, 0, 0.82, 0)
    frame.BackgroundColor3 = Color3.new(0, 0, 0)
    frame.BackgroundTransparency = 0.35
    frame.BorderSizePixel = 0
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

    local accent = Instance.new("Frame", frame)
    accent.Size = UDim2.new(0.005, 0, 1, 0)
    accent.BackgroundColor3 = color
    accent.BorderSizePixel = 0

    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(0.99, -8, 1, 0)
    label.Position = UDim2.new(0.005, 8, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextWrapped = true
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left

    -- Fade in
    frame.BackgroundTransparency = 1
    label.TextTransparency = 1
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

local HintCooldown = {}
local function TryShowHint(name, text, color)
    if HintCooldown[name] then return end
    HintCooldown[name] = true
    ShowHint(text, color)
    task.delay(20, function() HintCooldown[name] = nil end)
end

-- ============================================================
-- ЗВУКИ С РАССТОЯНИЕМ
-- ============================================================
local function PlaySound(id, volume, parent, looped, speed)
    local s = Instance.new("Sound", parent or workspace)
    s.SoundId  = id
    s.Volume   = volume or 5
    s.Looped   = looped or false
    s.PlaybackSpeed = speed or 1
    s:Play()
    if not looped then Debris:AddItem(s, 10) end
    return s
end

-- ============================================================
-- ЧАСТИЦЫ
-- ============================================================
local function AddParticles(parent, color, texture, rate)
    local emitter = Instance.new("ParticleEmitter", parent)
    emitter.Color            = ColorSequence.new(color, Color3.new(0,0,0))
    emitter.LightEmission    = 0.5
    emitter.LightInfluence   = 0.2
    emitter.Size             = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 2.5),
        NumberSequenceKeypoint.new(1, 0),
    })
    emitter.Transparency     = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.1),
        NumberSequenceKeypoint.new(1, 1),
    })
    emitter.Texture          = texture or "rbxasset://textures/particles/smoke_main.dds"
    emitter.Rate             = rate or 25
    emitter.Speed            = NumberRange.new(3, 8)
    emitter.SpreadAngle      = Vector2.new(35, 35)
    emitter.Lifetime         = NumberRange.new(1.5, 3)
    emitter.RotSpeed         = NumberRange.new(-45, 45)
    return emitter
end

-- ============================================================
-- ОБЩАЯ ФУНКЦИЯ СОЗДАНИЯ СУЩНОСТИ
-- ============================================================
local function CreateEntity(name, face, color, size, startPos)
    local ent = Instance.new("Part", EntityFolder)
    ent.Name         = name
    ent.Size         = Vector3.new(size or 5, size or 5, size or 5)
    ent.Transparency = 1
    ent.Anchored     = true
    ent.CanCollide   = false
    ent.CastShadow   = false
    ent.CFrame       = CFrame.new(startPos)

    -- Billboard лицо
    local bgui = Instance.new("BillboardGui", ent)
    bgui.Size = UDim2.new((size or 5) * 2, 0, (size or 5) * 2, 0)
    bgui.AlwaysOnTop = false
    local img = Instance.new("ImageLabel", bgui)
    img.Size = UDim2.new(1,0,1,0)
    img.Image = face
    img.BackgroundTransparency = 1

    return ent, bgui, img
end

-- ============================================================
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
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
    if not node then return room.PrimaryPart and room.PrimaryPart.Position or Vector3.new() end
    return (node:IsA("Model") and node.PrimaryPart.Position or node.Position)
end

-- Движение сущности по пути (возвращает промис-образный корутин)
local function MoveAlongPath(ent, path, speed, reversed)
    local indices = {}
    if reversed then
        for i = #path, 1, -1 do indices[#indices+1] = i end
    else
        for i = 1, #path do indices[#indices+1] = i end
    end

    for _, i in ipairs(indices) do
        if not ent or not ent.Parent then return end
        local target = GetRoomNode(path[i]) + Vector3.new(0, 5, 0)
        local dist   = (ent.Position - target).Magnitude
        if dist < 1 then continue end
        local t      = dist / speed
        TweenService:Create(ent, TweenInfo.new(t, Enum.EasingStyle.Linear), {
            CFrame = CFrame.new(target)
        }):Play()
        task.wait(t)
    end
end

-- ============================================================
-- SPAWN: COMMON SENSE 🌑
-- ============================================================
local function SpawnCommonSense(reboundCount, roomNum)
    local path = GetRooms()
    if #path == 0 then return end

    PlaySound(Config.CS_Warn, 5, workspace)
    task.wait(2.5)

    local startPos = GetRoomNode(path[1]) + Vector3.new(0, 5, 0)
    local ent, bgui, img = CreateEntity(Config.CS_Name, Config.CS_Face, Config.CS_Color, 5, startPos)

    -- Дымовой эффект
    local smoke = Instance.new("Smoke", ent)
    smoke.Color     = Color3.new(0, 0, 0)
    smoke.Size      = 30
    smoke.Opacity   = 0.7
    smoke.RiseVelocity = 3

    -- Частицы
    AddParticles(ent, Config.CS_Color, nil, 20)

    -- Точечный свет (тёмный эффект — уменьшаем освещённость вокруг)
    local light = Instance.new("PointLight", ent)
    light.Color      = Color3.fromRGB(20, 20, 30)
    light.Range      = 50
    light.Brightness = 0

    local loop = PlaySound(Config.CS_Fly, 8, ent, true)

    task.spawn(function()
        for _ = 1, reboundCount do
            MoveAlongPath(ent, path, Config.CS_Speed, false)
            if not ent.Parent then break end
        end
        loop:Stop()
        -- Исчезание
        TweenService:Create(smoke, TweenInfo.new(1), { Opacity = 0 }):Play()
        task.wait(1)
        ent:Destroy()
    end)
end

-- ============================================================
-- SPAWN: RED SMILE 🔴
-- ============================================================
local function SpawnRedSmile(reboundCount, roomNum)
    local path = GetRooms()
    if #path == 0 then return end

    PlaySound(Config.RS_Far, 4, workspace)
    task.wait(1.5)

    local startPos = GetRoomNode(path[1]) + Vector3.new(0, 5, 0)
    local ent, bgui, img = CreateEntity(Config.RS_Name, Config.RS_Face, Config.RS_Color, 6, startPos)

    -- Пульсирующий красный свет
    local light = Instance.new("PointLight", ent)
    light.Color      = Config.RS_Color
    light.Range      = 60
    light.Brightness = 12

    -- Огненные частицы
    AddParticles(ent, Config.RS_Color, "rbxasset://textures/particles/fire_main.dds", 30)

    -- Пульсация света
    task.spawn(function()
        while ent.Parent do
            TweenService:Create(light, TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Brightness = 20}):Play()
            task.wait(0.4)
            TweenService:Create(light, TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Brightness = 8}):Play()
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
        -- Растворение
        for i = 0, 10 do
            if not ent.Parent then break end
            light.Brightness = (10 - i) * 1.5
            task.wait(0.05)
        end
        ent:Destroy()
    end)
end

-- ============================================================
-- SPAWN: INVERTED REBOUND 🌀
-- ============================================================
local function SpawnInvertedRebound(isFirst)
    local path = GetRooms()
    if #path < 2 then return end

    local lastRoom  = path[#path]
    local startPos  = GetRoomNode(lastRoom) + Vector3.new(0, 5, 0)

    if isFirst then
        PlaySound(Config.IR_Arrival, 7, workspace)
        task.wait(5)
    else
        -- Призрак-предвестник
        local ghost = Instance.new("Part", EntityFolder)
        ghost.Transparency = 1
        ghost.Anchored     = true
        ghost.CanCollide   = false
        ghost.CFrame       = CFrame.new(startPos)
        ghost.Size         = Vector3.new(1,1,1)
        local gs = PlaySound(Config.IR_Move, 9, ghost, false)
        Debris:AddItem(ghost, 3)
        task.wait(2)
    end

    local ent, bgui, img = CreateEntity(Config.IR_Name, Config.IR_Face, Config.IR_Color, 5, startPos)

    -- Фиолетовые частицы
    AddParticles(ent, Config.IR_Color, nil, 35)

    -- SelectionBox — "искажение реальности"
    local selBox = Instance.new("SelectionBox", ent)
    selBox.Adornee        = ent
    selBox.Color3         = Config.IR_Color
    selBox.LineThickness  = 0.04
    selBox.SurfaceTransparency = 0.8
    selBox.SurfaceColor3  = Config.IR_Color

    -- Пульсация размера иллюзии
    task.spawn(function()
        while ent.Parent do
            TweenService:Create(bgui, TweenInfo.new(0.5, Enum.EasingStyle.Sine), {
                Size = UDim2.new(14, 0, 14, 0)
            }):Play()
            task.wait(0.5)
            TweenService:Create(bgui, TweenInfo.new(0.5, Enum.EasingStyle.Sine), {
                Size = UDim2.new(10, 0, 10, 0)
            }):Play()
            task.wait(0.5)
        end
    end)

    local loop = PlaySound(Config.IR_Move, 10, ent, true, 1.2)
    local echo = Instance.new("EchoSoundEffect", loop)
    echo.Delay      = 0.12
    echo.Feedback   = 0.25
    echo.DryLevel   = 0
    echo.WetLevel   = -1

    task.spawn(function()
        MoveAlongPath(ent, path, Config.IR_Speed, true)
        loop:Stop()
        ent:Destroy()
    end)
end

-- ============================================================
-- ЦИКЛ УРОНА + ЭФФЕКТЫ
-- ============================================================
task.spawn(function()
    while task.wait(Config.DamageTickRate) do
        local char = LocalPlayer.Character
        if not char then continue end
        local hum = char:FindFirstChild("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp or hum.Health <= 0 then continue end

        local isHiding   = char:GetAttribute("Hiding") == true
        local entities   = EntityFolder:GetChildren()
        local closestDist = math.huge
        local closestName = nil
        local killed = false

        for _, e in ipairs(entities) do
            if not e:IsA("Part") then continue end
            local dist = (e.Position - hrp.Position).Magnitude

            -- Отслеживаем ближайшую сущность для эффектов
            if dist < closestDist then
                closestDist = dist
                closestName = e.Name
            end

            -- Подсказки
            if dist < Config.HintThreshold then
                if e.Name == Config.CS_Name then
                    TryShowHint(e.Name, Config.CS_Hint, Config.CS_Color)
                elseif e.Name == Config.RS_Name then
                    TryShowHint(e.Name, Config.RS_Hint, Config.RS_Color)
                elseif e.Name == Config.IR_Name then
                    TryShowHint(e.Name, Config.IR_Hint, Config.IR_Color)
                end
            end

            -- Тряска при приближении
            if dist < Config.ShakeThreshold then
                local shakeStr = math.clamp((Config.ShakeThreshold - dist) / Config.ShakeThreshold * 0.35, 0, 0.35)
                ShakeCamera(shakeStr)
            end

            if killed then continue end

            -- Логика урона
            if e.Name == Config.IR_Name then
                if isHiding and dist < 55 then
                    killed = true
                    hum:SetAttribute("DeathCause", e.Name)
                    hum.Health = 0
                end
            else
                local range = (e.Name == Config.RS_Name) and Config.RS_KillRange or Config.KillRange
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

        -- Экранные эффекты на основе близости
        if closestDist < Config.ShakeThreshold then
            UpdateScreenEffects(closestDist, closestName)
        else
            ClearScreenEffects()
        end
    end
end)

-- ============================================================
-- КОНТРОЛЛЕР СПАВНА
-- ============================================================
task.spawn(function()
    local gameData  = ReplicatedStorage:WaitForChild("GameData", 15)
    if not gameData then warn("[Craziness] GameData not found!") return end
    local latestRoom = gameData:WaitForChild("LatestRoom", 10)
    if not latestRoom then warn("[Craziness] LatestRoom not found!") return end

    latestRoom.Changed:Connect(function(val)
        if val <= 5 then return end

        -- 🌀 Inverted Rebound
        if not IR_Active then
            if RNG:NextInteger(1, 100) <= Config.IR_Chance then
                IR_Active  = true
                IR_Counter = 0
            end
        end

        if IR_Active then
            IR_Counter = IR_Counter + 1
            task.spawn(function()
                SpawnInvertedRebound(IR_Counter == 1)
            end)
            if IR_Counter >= 2 then
                IR_Active  = false
                IR_Counter = 0
            end
        end

        -- 🌑 Common Sense (независимый шанс)
        if RNG:NextInteger(1, 100) <= Config.CS_Chance then
            task.spawn(function()
                SpawnCommonSense(5, val)
            end)
        end

        -- 🔴 Red Smile (независимый шанс, задержка чтобы не наслаиваться)
        if RNG:NextInteger(1, 100) <= Config.RS_Chance then
            task.spawn(function()
                task.wait(1)
                SpawnRedSmile(Config.RS_Rebounds, val)
            end)
        end
    end)
end)

-- Очистка при смерти
LocalPlayer.CharacterAdded:Connect(function()
    KillDebounce = false
    ClearScreenEffects()
    if HintGui then HintGui:Destroy(); HintGui = nil end
    for _, e in ipairs(EntityFolder:GetChildren()) do e:Destroy() end
    IR_Counter = 0
    IR_Active  = false
    HintCooldown = {}
end)

print("✅ Craziness Mod v2.0 loaded — Enhanced Effects Active! 🌑🔴🌀")
