local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local Settings = {
    Enabled = false,
    PullSpeed = 40,
    MovingMultiplier = 0.35,
    GlideSpeed = 30,
    FOV = 40,
    MinDistance = 5,
    ToggleBlockDistance = 1,
    TeamCheck = true,
    WallCheck = true,
    HeadBias = 0.6,
    Prediction = true,
    PredictionTime = 0.08,
}

-- sa mobile walang right click, kaya aim kapag naka-ON
local MobileMode = UIS.TouchEnabled and not UIS.MouseEnabled

local TorsoNames = {"UpperTorso", "Torso", "HumanoidRootPart"}

print("[Aimbot] Loaded. T or GUI = toggle" .. (MobileMode and "" or ", hold right click = aim"))

local aimPoint = nil

local function getMyPos(cam)
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    return root and root.Position or cam.CFrame.Position
end

local function isTeammate(p)
    return Settings.TeamCheck and p.Team ~= nil and p.Team == LocalPlayer.Team
end

local function someoneTooClose()
    local myPos = getMyPos(workspace.CurrentCamera)
    for _, p in ipairs(Players:GetPlayers()) do
        local char = p.Character
        if p ~= LocalPlayer and char and not isTeammate(p) then
            local hum = char:FindFirstChildOfClass("Humanoid")
            local root = char:FindFirstChild("HumanoidRootPart")
            if hum and hum.Health > 0 and root
                and (root.Position - myPos).Magnitude <= Settings.ToggleBlockDistance then
                return true
            end
        end
    end
    return false
end

-- [ GUI ]
local gui = Instance.new("ScreenGui")
gui.Name = "AimToggleGui"
gui.ResetOnSpawn = false
local okGui = pcall(function() gui.Parent = game:GetService("CoreGui") end)
if not okGui then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

-- ang mismong square ang ON/OFF button
local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0, 56, 0, 40)
toggleBtn.Position = UDim2.new(0, 10, 0.5, -20)
toggleBtn.BackgroundColor3 = Color3.new(0, 0, 0)
toggleBtn.BackgroundTransparency = 0.1
toggleBtn.BorderSizePixel = 2
toggleBtn.BorderColor3 = Color3.fromRGB(255, 80, 80)
toggleBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
toggleBtn.Font = Enum.Font.SourceSansBold
toggleBtn.TextSize = 16
toggleBtn.Text = "OFF"
toggleBtn.Parent = gui

local hideBtn = Instance.new("TextButton")
hideBtn.Size = UDim2.new(0, 18, 0, 18)
hideBtn.Position = UDim2.new(0, 68, 0.5, -20)
hideBtn.BackgroundColor3 = Color3.new(0, 0, 0)
hideBtn.BackgroundTransparency = 0.1
hideBtn.BorderSizePixel = 0
hideBtn.TextColor3 = Color3.new(1, 1, 1)
hideBtn.Font = Enum.Font.SourceSansBold
hideBtn.TextSize = 16
hideBtn.Text = "-"
hideBtn.Parent = gui

local showBtn = Instance.new("TextButton")
showBtn.Size = UDim2.new(0, 22, 0, 22)
showBtn.Position = UDim2.new(0, 10, 0.5, -11)
showBtn.BackgroundColor3 = Color3.new(0, 0, 0)
showBtn.BackgroundTransparency = 0.1
showBtn.BorderSizePixel = 0
showBtn.TextColor3 = Color3.new(1, 1, 1)
showBtn.Font = Enum.Font.SourceSansBold
showBtn.TextSize = 16
showBtn.Text = "+"
showBtn.Visible = false
showBtn.Parent = gui

local function refreshGui()
    local color = Settings.Enabled and Color3.fromRGB(80, 255, 80) or Color3.fromRGB(255, 80, 80)
    toggleBtn.Text = Settings.Enabled and "ON" or "OFF"
    toggleBtn.TextColor3 = color
    toggleBtn.BorderColor3 = color
end

local function setEnabled()
    if someoneTooClose() then
        print("[Aimbot] Toggle blocked: player too close")
        return
    end
    Settings.Enabled = not Settings.Enabled
    aimPoint = nil
    refreshGui()
    print("[Aimbot] Enabled:", Settings.Enabled)
end

toggleBtn.Activated:Connect(setEnabled)

hideBtn.Activated:Connect(function()
    toggleBtn.Visible = false
    hideBtn.Visible = false
    showBtn.Visible = true
end)

showBtn.Activated:Connect(function()
    toggleBtn.Visible = true
    hideBtn.Visible = true
    showBtn.Visible = false
end)

UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.T then
        setEnabled()
    end
end)

UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        aimPoint = nil
    end
end)

local function getTorso(char)
    for _, n in ipairs(TorsoNames) do
        local part = char:FindFirstChild(n)
        if part then return part end
    end
end

local function predicted(part, root)
    if not Settings.Prediction then
        return part.Position
    end
    local t = Settings.PredictionTime
    local ok, ping = pcall(function() return LocalPlayer:GetNetworkPing() end)
    if ok and ping then t = t + ping end
    return part.Position + root.AssemblyLinearVelocity * t
end

local function visible(cam, pos, char)
    if not Settings.WallCheck then return true end
    local ignore = {LocalPlayer.Character}
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    for _ = 1, 8 do
        params.FilterDescendantsInstances = ignore
        local hit = workspace:Raycast(cam.CFrame.Position, pos - cam.CFrame.Position, params)
        if not hit then return true end
        if hit.Instance:IsDescendantOf(char) then return true end
        if hit.Instance.Transparency >= 0.9 or not hit.Instance.CanCollide then
            table.insert(ignore, hit.Instance)
        else
            return false
        end
    end
    return false
end

local function screenDist(cam, pos, center)
    local v, on = cam:WorldToViewportPoint(pos)
    if not on then return nil end
    return (Vector2.new(v.X, v.Y) - center).Magnitude
end

local function evaluate(cam, p, center, myPos, fov)
    local char = p.Character
    if not char or p == LocalPlayer or isTeammate(p) then return nil end

    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not (hum and hum.Health > 0 and root) then return nil end
    if (root.Position - myPos).Magnitude <= Settings.MinDistance then return nil end

    local head = char:FindFirstChild("Head")
    local torso = getTorso(char)

    local hp = head and predicted(head, root)
    local tp = torso and predicted(torso, root)
    local dh = hp and screenDist(cam, hp, center)
    local dt = tp and screenDist(cam, tp, center)

    local pos, d
    if dh and dt then
        if dt < dh * Settings.HeadBias then
            pos, d = tp, dt
        else
            pos, d = hp, dh
        end
    elseif dh then
        pos, d = hp, dh
    elseif dt then
        pos, d = tp, dt
    end

    if pos and d and d < fov and visible(cam, pos, char) then
        return pos, d
    end
    return nil
end

local function getTarget(cam)
    local center = cam.ViewportSize / 2
    local myPos = getMyPos(cam)
    local best, bestDist = nil, Settings.FOV

    for _, p in ipairs(Players:GetPlayers()) do
        local pos, d = evaluate(cam, p, center, myPos, bestDist)
        if pos then
            best, bestDist = pos, d
        end
    end
    return best
end

RunService:BindToRenderStep("AimbotLoop", Enum.RenderPriority.Last.Value + 1, function(dt)
    if not Settings.Enabled then return end
    if not MobileMode and not UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end

    local cam = workspace.CurrentCamera
    local target = getTarget(cam)
    if not target then
        aimPoint = nil
        return
    end

    if not aimPoint then
        aimPoint = target
    else
        aimPoint = aimPoint:Lerp(target, 1 - math.exp(-Settings.GlideSpeed * dt))
    end

    local speed = Settings.PullSpeed
    if UIS:GetMouseDelta().Magnitude > 1 then
        speed = speed * Settings.MovingMultiplier
    end

    local alpha = 1 - math.exp(-speed * dt)
    cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(cam.CFrame.Position, aimPoint), alpha)
end)
