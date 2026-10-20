--!strict
-- Постоянная панель справа: должность, рейтинг, качество, баланс, операция и текущее задание.
-- Всё это сервер выставляет в атрибуты игрока (Task, Rank, Rating, Quality, PayBonus, Operation...).
-- Сверху экрана остаются только уведомления.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Operations = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Operations"))

local MONEY_NAME = "Деньги" -- как в leaderstats (PlayerData)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TaskHud"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(1, 0.5)
panel.Position = UDim2.new(1, -12, 0.45, 0)
panel.Size = UDim2.fromScale(0.3, 0)
panel.AutomaticSize = Enum.AutomaticSize.Y
panel.BackgroundColor3 = Color3.fromRGB(40, 20, 70)
panel.BackgroundTransparency = 0.25
panel.Parent = screenGui

local sizeLimit = Instance.new("UISizeConstraint")
sizeLimit.MinSize = Vector2.new(200, 0)
sizeLimit.MaxSize = Vector2.new(290, math.huge)
sizeLimit.Parent = panel

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = panel

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 10)
padding.PaddingBottom = UDim.new(0, 12)
padding.PaddingLeft = UDim.new(0, 12)
padding.PaddingRight = UDim.new(0, 12)
padding.Parent = panel

local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 4)
layout.Parent = panel

local function addLine(order: number, textSize: number, color: Color3, font: Enum.Font): TextLabel
	local label = Instance.new("TextLabel")
	label.LayoutOrder = order
	label.Size = UDim2.fromScale(1, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.BackgroundTransparency = 1
	label.Font = font
	label.TextSize = textSize
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = color
	label.Text = ""
	label.Parent = panel
	return label
end

local MUTED = Color3.fromRGB(215, 200, 245)
local rankLine = addLine(1, 18, Color3.fromRGB(230, 210, 255), Enum.Font.BuilderSansBold)
local ratingLine = addLine(2, 14, MUTED, Enum.Font.BuilderSansMedium)
local qualityLine = addLine(3, 14, MUTED, Enum.Font.BuilderSansMedium)
local moneyLine = addLine(4, 14, MUTED, Enum.Font.BuilderSansMedium)
local operationLine = addLine(5, 14, MUTED, Enum.Font.BuilderSansMedium)

local divider = Instance.new("Frame")
divider.LayoutOrder = 7
divider.Size = UDim2.new(1, 0, 0, 1)
divider.BackgroundColor3 = Color3.fromRGB(150, 120, 200)
divider.BorderSizePixel = 0
divider.Parent = panel

-- «Чёрная пятница» и буст ×2: строки видны, только пока действуют
local eventLine = addLine(6, 14, Color3.fromRGB(241, 196, 15), Enum.Font.BuilderSansBold)
eventLine.Visible = false
local boostLine = addLine(6, 14, Color3.fromRGB(46, 204, 113), Enum.Font.BuilderSansBold)
boostLine.Visible = false

local taskCaption = addLine(8, 12, Color3.fromRGB(241, 196, 15), Enum.Font.BuilderSansBold)
taskCaption.Text = "ЗАДАНИЕ"
local taskLine = addLine(9, 16, Color3.new(1, 1, 1), Enum.Font.BuilderSansBold)

local function updateStats()
	local rank = player:GetAttribute("Rank")
	rankLine.Text = if typeof(rank) == "string" then rank else "Сотрудник"

	local rating = player:GetAttribute("Rating") or 0
	local nextRank = player:GetAttribute("NextRank")
	local nextAt = player:GetAttribute("NextRankAt")
	ratingLine.Text = `Рейтинг: {rating}`
	if typeof(nextRank) == "string" and nextRank ~= "" then
		ratingLine.Text ..= ` / {nextAt} до «{nextRank}»`
	end

	local quality = player:GetAttribute("Quality") or 100
	local bonus = player:GetAttribute("PayBonus") or 0
	qualityLine.Text = `Качество: {quality}%`
	if typeof(bonus) == "number" and bonus > 0 then
		qualityLine.Text ..= ` (+{bonus}% к пику)`
	end

	local operation = Operations.byId(player:GetAttribute("Operation"))
	operationLine.Text = `Операция: {if operation then operation.Name else "не выбрана (M)"}`
end

local function updateMoney()
	local stats = player:FindFirstChild("leaderstats")
	local money = if stats then stats:FindFirstChild(MONEY_NAME) else nil
	moneyLine.Text = `Баланс: {if money and money:IsA("StringValue") then money.Value else "—"}`
end

local function updateTask()
	local text = player:GetAttribute("Task")
	taskLine.Text = if typeof(text) == "string" and text ~= "" then text else "—"
end

for _, name in { "Rank", "Rating", "NextRank", "NextRankAt", "Quality", "PayBonus", "Operation" } do
	player:GetAttributeChangedSignal(name):Connect(updateStats)
end
player:GetAttributeChangedSignal("Task"):Connect(updateTask)

-- Деньги лежат в leaderstats, который сервер создаёт после загрузки данных
local function watchMoney(stats: Instance)
	local money = stats:WaitForChild(MONEY_NAME, 30)
	if money and money:IsA("StringValue") then
		money.Changed:Connect(updateMoney)
	end
	updateMoney()
end
player.ChildAdded:Connect(function(child)
	if child.Name == "leaderstats" then
		watchMoney(child)
	end
end)
local existingStats = player:FindFirstChild("leaderstats")
if existingStats then
	task.spawn(watchMoney, existingStats)
end

local function updateBonuses()
	local event = ReplicatedStorage:GetAttribute("Event")
	eventLine.Visible = typeof(event) == "string" and event ~= ""
	eventLine.Text = `{event}: ×2 оплата и опыт сезона!`

	local boostUntil = player:GetAttribute("BoostUntil")
	local left = if typeof(boostUntil) == "number" then boostUntil - workspace:GetServerTimeNow() else 0
	boostLine.Visible = left > 0
	if left > 0 then
		boostLine.Text =
			string.format("Буст ×2 к заработку: %d:%02d", math.floor(left / 60), math.floor(left % 60))
	end
end

-- Раз в секунду: идёт отсчёт буста
task.spawn(function()
	while true do
		updateBonuses()
		task.wait(1)
	end
end)

updateStats()
updateMoney()
updateTask()
