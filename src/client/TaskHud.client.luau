--!strict
-- Панель вверху экрана: должность, рейтинг и качество, а под ними текущее задание.
-- Всё это сервер выставляет в атрибуты игрока (Task, Rank, Rating, Quality, PayBonus...).

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TaskHud"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, 56)
panel.Size = UDim2.fromScale(0.9, 0)
panel.AutomaticSize = Enum.AutomaticSize.Y
panel.BackgroundColor3 = Color3.fromRGB(112, 36, 186)
panel.BackgroundTransparency = 0.15
panel.Parent = screenGui

local sizeLimit = Instance.new("UISizeConstraint")
sizeLimit.MaxSize = Vector2.new(560, math.huge)
sizeLimit.Parent = panel

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = panel

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 6)
padding.PaddingBottom = UDim.new(0, 8)
padding.PaddingLeft = UDim.new(0, 14)
padding.PaddingRight = UDim.new(0, 14)
padding.Parent = panel

local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 4)
layout.Parent = panel

local function addLine(order: number, textSize: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.LayoutOrder = order
	label.Size = UDim2.fromScale(1, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = textSize
	label.TextWrapped = true
	label.TextColor3 = color
	label.Parent = panel
	return label
end

local statsLine = addLine(1, 15, Color3.fromRGB(220, 200, 255))
local taskLine = addLine(2, 20, Color3.new(1, 1, 1))

local function updateStats()
	local rank = player:GetAttribute("Rank")
	if typeof(rank) ~= "string" then
		statsLine.Visible = false
		return
	end

	local rating = player:GetAttribute("Rating") or 0
	local nextRank = player:GetAttribute("NextRank")
	local nextAt = player:GetAttribute("NextRankAt")
	local quality = player:GetAttribute("Quality") or 100
	local bonus = player:GetAttribute("PayBonus") or 0

	local ratingText = `Рейтинг {rating}`
	if typeof(nextRank) == "string" and nextRank ~= "" then
		ratingText ..= ` / {nextAt} до «{nextRank}»`
	end
	local qualityText = `Качество {quality}%`
	if typeof(bonus) == "number" and bonus > 0 then
		qualityText ..= ` (+{bonus}% к пику)`
	end

	statsLine.Text = `{rank} · {ratingText} · {qualityText}`
	statsLine.Visible = true
end

local function updateTask()
	local text = player:GetAttribute("Task")
	taskLine.Text = if typeof(text) == "string" then text else ""
	taskLine.Visible = taskLine.Text ~= ""
end

for _, name in { "Rank", "Rating", "NextRank", "NextRankAt", "Quality", "PayBonus" } do
	player:GetAttributeChangedSignal(name):Connect(updateStats)
end
player:GetAttributeChangedSignal("Task"):Connect(updateTask)
updateStats()
updateTask()
