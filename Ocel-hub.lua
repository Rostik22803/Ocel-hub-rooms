local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local LocalPlayer = Players.LocalPlayer

-- Очистка старого интерфейса
local oldGui = LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("RoomsTabletFinalGUI")
if oldGui then oldGui:Destroy() end

local Config = {
    AutoPilot = false,
    AutoHide = false,
    AutoA90 = false,
    Speed = 40 -- Твоя скорость из V30 по умолчанию (можно менять кнопками)
}

local isA90Active = false
local monsterIncoming = false

-- Лазер пути
local Attachment0 = Instance.new("Attachment")
local Attachment1 = Instance.new("Attachment")
local Beam = Instance.new("Beam")
Beam.Width0 = 0.4
Beam.Width1 = 0.4
Beam.Color = ColorSequence.new(Color3.fromRGB(255, 0, 100))
Beam.FaceCamera = true
Beam.Enabled = false

local path = PathfindingService:CreatePath({
    AgentRadius = 2.0,
    AgentHeight = 5.0,
    AgentCanJump = false
})

-- ================= ИНТЕРФЕЙС И КНОПКИ СКОРОСТИ =================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "RoomsTabletFinalGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local Frame = Instance.new("Frame")
Frame.Size = UDim2.new(0, 220, 0, 290)
Frame.Position = UDim2.new(0, 30, 0, 120)
Frame.BackgroundColor3 = Color3.fromRGB(30, 15, 20)
Frame.BorderSizePixel = 1
Frame.Active = true
Frame.Draggable = true
Frame.Parent = ScreenGui

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 35)
Title.BackgroundColor3 = Color3.fromRGB(25, 10, 15)
Title.Text = "ROOMS CFRAME V32"
Title.TextColor3 = Color3.fromRGB(255, 0, 100)
Title.Font = Enum.Font.Code
Title.TextSize = 14
Title.Parent = Frame

local function createBtn(name, yPos, configKey)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 180, 0, 35)
    btn.Position = UDim2.new(0, 20, 0, yPos)
    btn.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
    btn.Text = name .. " [OFF]"
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.SourceSans
    btn.Parent = Frame

    btn.MouseButton1Click:Connect(function()
        Config[configKey] = not Config[configKey]
        btn.BackgroundColor3 = Config[configKey] and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(150, 50, 50)
        btn.Text = name .. (Config[configKey] and " [ON]" or " [OFF]")
        if not Config.AutoPilot then Beam.Enabled = false end
    end)
end

createBtn("Врубить Автопилот", 50, "AutoPilot")
createBtn("Авто-Шкаф + Без Блура", 100, "AutoHide")
createBtn("Анти-A90 (Заморозка)", 150, "AutoA90")

-- Блок регулировки скорости
local SpeedFrame = Instance.new("Frame")
SpeedFrame.Size = UDim2.new(0, 180, 0, 60)
SpeedFrame.Position = UDim2.new(0, 20, 0, 205)
SpeedFrame.BackgroundColor3 = Color3.fromRGB(25, 10, 15)
SpeedFrame.BorderSizePixel = 0
SpeedFrame.Parent = Frame

local SpeedLabel = Instance.new("TextLabel")
SpeedLabel.Size = UDim2.new(1, 0, 0, 25)
SpeedLabel.BackgroundTransparency = 1
SpeedLabel.Text = "СКОРОСТЬ CFRAME: " .. Config.Speed
SpeedLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
SpeedLabel.Font = Enum.Font.SourceSans
SpeedLabel.TextSize = 15
SpeedLabel.Parent = SpeedFrame

local MinusBtn = Instance.new("TextButton")
MinusBtn.Size = UDim2.new(0, 45, 0, 30)
MinusBtn.Position = UDim2.new(0, 5, 0, 25)
MinusBtn.BackgroundColor3 = Color3.fromRGB(45, 20, 25)
MinusBtn.Text = "-"
MinusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinusBtn.TextSize = 20
MinusBtn.Parent = SpeedFrame

local PlusBtn = Instance.new("TextButton")
PlusBtn.Size = UDim2.new(0, 45, 0, 30)
PlusBtn.Position = UDim2.new(1, -50, 0, 25)
PlusBtn.BackgroundColor3 = Color3.fromRGB(45, 20, 25)
PlusBtn.Text = "+"
PlusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
PlusBtn.TextSize = 20
PlusBtn.Parent = SpeedFrame

MinusBtn.MouseButton1Click:Connect(function()
    Config.Speed = math.max(10, Config.Speed - 5)
    SpeedLabel.Text = "СКОРОСТЬ CFRAME: " .. Config.Speed
end)

PlusBtn.MouseButton1Click:Connect(function()
    Config.Speed = math.min(150, Config.Speed + 5)
    SpeedLabel.Text = "СКОРОСТЬ CFRAME: " .. Config.Speed
end)

-- ================= АНАЛИЗАТОР КОМНАТ =================

function getChar()
    local char = LocalPlayer.Character
    if not char then return nil, nil end
    return char:FindFirstChild("HumanoidRootPart"), char:FindFirstChild("Humanoid")
end

local function getRoomsFolder()
    return workspace:FindFirstChild("CurrentRooms") or workspace:FindFirstChild("Rooms") or workspace:FindFirstChild("GeneratedRooms")
end

local function getCurrentRoomNumber(root)
    local roomsFolder = getRoomsFolder()
    if not roomsFolder or not root then return 0 end
    
    local minDist = math.huge
    local currentNum = 0
    
    for _, room in pairs(roomsFolder:GetChildren()) do
        local floor = room:FindFirstChild("Floor") or room:FindFirstChild("floor") or room:FindFirstChildWhichIsA("BasePart")
        if floor then
            local dist = (root.Position - floor.Position).Magnitude
            if dist < minDist then
                minDist = dist
                currentNum = tonumber(room.Name:match("%d+")) or 0
            end
        end
    end
    return currentNum
end

local function getNextRoomEntrance(currentNum)
    local roomsFolder = getRoomsFolder()
    if not roomsFolder then return nil end
    
    local nextRoom = nil
    for _, room in pairs(roomsFolder:GetChildren()) do
        if tonumber(room.Name:match("%d+")) == (currentNum + 1) then
            nextRoom = room
            break
        end
    end
    
    if not nextRoom then
        local highest = -1
        for _, room in pairs(roomsFolder:GetChildren()) do
            local num = tonumber(room.Name:match("%d+"))
            if num and num > highest then
                highest = num
                nextRoom = room
            end
        end
    end
    
    if not nextRoom then return nil end
    
    local door = nextRoom:FindFirstChild("Door") or nextRoom:FindFirstChild("DoorPart") or nextRoom:FindFirstChild("Exit")
    if door and door:IsA("BasePart") then return door.Position end
    
    local floor = nextRoom:FindFirstChild("Floor") or nextRoom:FindFirstChild("floor") or nextRoom:FindFirstChildWhichIsA("BasePart")
    if floor then return floor.Position end
    
    return nil
end

-- ================= ЖЕСТКИЙ СКОРОСТНОЙ ДВИЖОК ИЗ V30 =================

local currentWaypoints = {}
local currentWaypointIndex = 1

game:GetService("RunService").Heartbeat:Connect(function(deltaTime)
    local root, hum = getChar()
    
    if Config.AutoPilot and not isA90Active and not monsterIncoming and root and hum then
        -- Вырубаем физическую скорость, блокируя падения и застревания в текстурах
        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        
        local currentNum = getCurrentRoomNumber(root)
        local destinationPos = getNextRoomEntrance(currentNum)
        
        if destinationPos then
            -- Пересчет GPS-маршрута раз в 10 кадров
            if tick() % 0.2 < 0.03 then
                pcall(function()
                    path:ComputeAsync(root.Position, destinationPos)
                    if path.Status == Enum.PathStatus.Success then
                        currentWaypoints = path:GetWaypoints()
                        currentWaypointIndex = 1
                    else
                        currentWaypoints = { { Position = destinationPos } }
                        currentWaypointIndex = 1
                    end
                end)
            end
            
            local targetWaypoint = currentWaypoints[currentWaypointIndex]
            
            -- Радиус триггера точки (динамический, зависит от скорости, чтобы не пролетать мимо углов)
            local targetRadius = math.max(4.5, Config.Speed * 0.12)
            while targetWaypoint and (root.Position - targetWaypoint.Position).Magnitude < targetRadius do
                currentWaypointIndex = currentWaypointIndex + 1
                targetWaypoint = currentWaypoints[currentWaypointIndex]
            end
            
            if targetWaypoint then
                local targetPos = Vector3.new(targetWaypoint.Position.X, root.Position.Y, targetWaypoint.Position.Z)
                
                -- Подсветка маршрута лазером
                Attachment0.Parent = root
                if not Attachment1.Parent then
                    local attHolder = Instance.new("Part")
                    attHolder.Anchored = true
                    attHolder.CanCollide = false
                    attHolder.Transparency = 1
                    attHolder.Parent = workspace
                    Attachment1.Parent = attHolder
                end
                Attachment1.Parent.Position = targetPos
                Beam.Attachment0 = Attachment0
                Beam.Attachment1 = Attachment1
                Beam.Parent = root
                Beam.Enabled = true
                
                -- Расчет направления и телепортация CFrame на частоте кадров (как в V30)
                local moveDirection = (targetPos - root.Position).Unit
                if moveDirection.Magnitude > 0 then
                    root.CFrame = CFrame.new(root.Position + (moveDirection * Config.Speed * deltaTime), targetPos)
                end
            end
        else
            Beam.Enabled = false
        end
    end
end)

-- АНТИ-A90
task.spawn(function()
    while task.wait() do
        if Config.AutoA90 then
            local root, hum = getChar()
            local a90Gui = LocalPlayer.PlayerGui:FindFirstChild("A90") or LocalPlayer.PlayerGui:FindFirstChild("ScreenGui"):FindFirstChild("A90")
            local isVisible = a90Gui and (a90Gui.Enabled or (a90Gui:FindFirstChild("Main") and a90Gui.Main.Visible))
            
            if isVisible or workspace:FindFirstChild("A90") then
                isA90Active = true
                if root then root.Anchored = true end
                repeat task.wait(0.05)
                until not workspace:FindFirstChild("A90") and not (a90Gui and a90Gui.Enabled)
                if root then root.Anchored = false end
                isA90Active = false
            end
        end
    end
end)

-- АВТО-ШКАФ
task.spawn(function()
    while task.wait(0.05) do
        if Config.AutoHide then
            local root, hum = getChar()
            if root then
                local monster = workspace:FindFirstChild("A60") or workspace:FindFirstChild("A120") or workspace:FindFirstChild("A-60") or workspace:FindFirstChild("A-120")
                if monster then
                    monsterIncoming = true
                    
                    local closestLocker = nil
                    local minDist = math.huge
                    for _, obj in pairs(workspace:GetDescendants()) do
                        if obj.Name == "Locker" or obj.Name == "Rooms_Locker" then
                            local base = obj:FindFirstChild("Base") or obj:FindFirstChildWhichIsA("BasePart")
                            if base then
                                local dist = (root.Position - base.Position).Magnitude
                                if dist < minDist then
                                    minDist = dist
                                    closestLocker = obj
                                end
                            end
                        end
                    end
                    
                    if closestLocker then
                        local base = closestLocker:FindFirstChild("Base") or closestLocker:FindFirstChildWhichIsA("BasePart")
                        root.CFrame = base.CFrame + Vector3.new(0, 1.5, 0)
                        task.wait(0.02)
                        
                        local prompt = closestLocker:FindFirstChildWhichIsA("ProximityPrompt", true)
                        if prompt and fireproximityprompt then
                            fireproximityprompt(prompt)
                        end
                    end
                else
                    if monsterIncoming then
                        monsterIncoming = false
                        task.wait(0.3)
                        
                        local prompt = workspace:FindFirstChild("HidePrompt", true)
                        if prompt and fireproximityprompt then fireproximityprompt(prompt) end
                        
                        pcall(function()
                            for _, gui in pairs(LocalPlayer.PlayerGui:GetChildren()) do
                                if gui:FindFirstChild("HideContainer") then gui.HideContainer.Visible = false end
                                if gui:FindFirstChild("MainUI") and gui.MainUI:FindFirstChild("HideContainer") then gui.MainUI.HideContainer.Visible = false end
                            end
                            local blur = game:GetService("Lighting"):FindFirstChildWhichIsA("BlurEffect")
                            if blur then blur.Enabled = false end
                        end)
                    end
                end
            end
        end
    end
end)
