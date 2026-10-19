--!strict
-- Текущее задание вверху экрана. Текст выставляет сервер в атрибут игрока Task.

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TaskHud"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local panel = Instance.new("TextLabel")
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, 56)
panel.Size = UDim2.fromScale(0.9, 0)
panel.AutomaticSize = Enum.AutomaticSize.Y
panel.BackgroundColor3 = Color3.fromRGB(112, 36, 186)
panel.BackgroundTransparency = 0.15
panel.Font = Enum.Font.GothamBold
panel.TextSize = 20
panel.TextWrapped = true
panel.TextColor3 = Color3.new(1, 1, 1)
panel.Visible = false
panel.Parent = screenGui

local sizeLimit = Instance.new("UISizeConstraint")
sizeLimit.MaxSize = Vector2.new(560, math.huge)
sizeLimit.Parent = panel

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = panel

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 8)
padding.PaddingBottom = UDim.new(0, 8)
padding.PaddingLeft = UDim.new(0, 14)
padding.PaddingRight = UDim.new(0, 14)
padding.Parent = panel

local function update()
	local text = player:GetAttribute("Task")
	if typeof(text) == "string" and text ~= "" then
		panel.Text = text
		panel.Visible = true
	else
		panel.Visible = false
	end
end

player:GetAttributeChangedSignal("Task"):Connect(update)
update()
