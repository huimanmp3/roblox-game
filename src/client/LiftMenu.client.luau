--!strict
-- Меню грузового подъёмника: открывается подсказкой «Выбрать этаж» у пульта.
-- Этаж выбирают кнопкой или клавишами 1, 2, 3. Меню закрывается, если отойти от подъёмника.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local liftEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Lift") :: RemoteEvent

local CLOSE_DISTANCE = 12 -- отошёл от места, где открыл меню, — меню закрывается
local KEYS: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LiftMenu"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 1)
panel.Position = UDim2.new(0.5, 0, 1, -110)
panel.Size = UDim2.fromOffset(0, 0)
panel.AutomaticSize = Enum.AutomaticSize.XY
panel.BackgroundColor3 = Color3.fromRGB(24, 26, 33)
panel.BackgroundTransparency = 0.05
panel.Visible = false
panel.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = panel

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 10)
padding.PaddingBottom = UDim.new(0, 12)
padding.PaddingLeft = UDim.new(0, 14)
padding.PaddingRight = UDim.new(0, 14)
padding.Parent = panel

local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Padding = UDim.new(0, 8)
layout.Parent = panel

local title = Instance.new("TextLabel")
title.LayoutOrder = 1
title.Size = UDim2.fromOffset(0, 22)
title.AutomaticSize = Enum.AutomaticSize.X
title.BackgroundTransparency = 1
title.Font = Enum.Font.BuilderSansBold
title.TextSize = 18
title.TextColor3 = Color3.new(1, 1, 1)
title.Text = "Грузовой подъёмник: выбери этаж"
title.Parent = panel

local row = Instance.new("Frame")
row.LayoutOrder = 2
row.Size = UDim2.fromOffset(0, 54)
row.AutomaticSize = Enum.AutomaticSize.X
row.BackgroundTransparency = 1
row.Parent = panel

local rowLayout = Instance.new("UIListLayout")
rowLayout.FillDirection = Enum.FillDirection.Horizontal
rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
rowLayout.Padding = UDim.new(0, 8)
rowLayout.Parent = row

local openedAt: Vector3? = nil
local floors: { number } = {}
local currentFloor = 0

local function close()
	panel.Visible = false
	openedAt = nil
end

local function choose(floor: number)
	if not panel.Visible or floor == currentFloor or not table.find(floors, floor) then
		return
	end
	liftEvent:FireServer(floor)
	close()
end

local function open(here: number, list: { number })
	currentFloor = here
	floors = list
	for _, child in row:GetChildren() do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end

	for index, floor in list do
		local isHere = floor == here
		local button = Instance.new("TextButton")
		button.LayoutOrder = index
		button.Size = UDim2.fromOffset(96, 54)
		button.BackgroundColor3 = if isHere then Color3.fromRGB(60, 62, 72) else Color3.fromRGB(112, 36, 186)
		button.AutoButtonColor = not isHere
		button.Font = Enum.Font.BuilderSansBold
		button.TextSize = 17
		button.TextColor3 = if isHere then Color3.fromRGB(170, 170, 180) else Color3.new(1, 1, 1)
		button.Text = if isHere then `{floor} этаж\nты здесь` else `{floor} этаж\nклавиша {floor}`
		button.Parent = row
		local buttonCorner = Instance.new("UICorner")
		buttonCorner.CornerRadius = UDim.new(0, 8)
		buttonCorner.Parent = button
		button.Activated:Connect(function()
			choose(floor)
		end)
	end

	local closeButton = Instance.new("TextButton")
	closeButton.LayoutOrder = #list + 1
	closeButton.Size = UDim2.fromOffset(54, 54)
	closeButton.BackgroundColor3 = Color3.fromRGB(60, 62, 72)
	closeButton.Font = Enum.Font.BuilderSansBold
	closeButton.TextSize = 20
	closeButton.TextColor3 = Color3.new(1, 1, 1)
	closeButton.Text = "X"
	closeButton.Parent = row
	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = closeButton
	closeButton.Activated:Connect(close)

	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	openedAt = if root and root:IsA("BasePart") then root.Position else nil
	panel.Visible = true
end

liftEvent.OnClientEvent:Connect(function(here: unknown, list: unknown)
	if typeof(here) == "number" and typeof(list) == "table" then
		open(here, list :: { number })
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not panel.Visible then
		return
	end
	local floor = KEYS[input.KeyCode]
	if floor then
		choose(floor)
	elseif input.KeyCode == Enum.KeyCode.Escape then
		close()
	end
end)

-- Отошёл от подъёмника — меню закрывается само
RunService.Heartbeat:Connect(function()
	local start = openedAt
	if not panel.Visible or not start then
		return
	end
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not root or not root:IsA("BasePart") or (root.Position - start).Magnitude > CLOSE_DISTANCE then
		close()
	end
end)
