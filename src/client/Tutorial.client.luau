--!strict
-- Обучение для новичка: несколько карточек о том, как устроена игра. Показывается один раз,
-- когда у игрока атрибут TutorialDone = false (его ставит сервер после загрузки данных).
-- После обучения открывается меню выбора операции.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local rewardsEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Rewards") :: RemoteEvent

local SLIDES = {
	{
		Title = "Добро пожаловать на склад!",
		Text = "Ты новый сотрудник. Работай, получай оплату за каждое действие и расти в должности: от стажёра до начальника смены.",
	},
	{
		Title = "Выбери операцию",
		Text = `Приёмка доступна сразу. Раскладка и сборка на мезонине — с рейтинга {Config.Rating.K2Access}, карщик на тягаче — с {Config.Tugger.RatingRequired}. Сменить операцию можно клавишей M.`,
	},
	{
		Title = "Следуй заданию",
		Text = "Справа всегда написано, что делать дальше, а фиолетовая стрелка показывает, куда идти. Начни с раздевалки: подойди к шкафчику и переоденься в форму.",
	},
	{
		Title = "Награды каждый день",
		Text = "Забирай ежедневный бонус, выполняй задания дня и повышай уровень сезона — кнопка «Награды» слева. По выходным «Чёрная пятница»: ×2 оплата!",
	},
}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "Tutorial"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 8
screenGui.Enabled = false
screenGui.Parent = playerGui

local shade = Instance.new("Frame")
shade.Size = UDim2.fromScale(1, 1)
shade.BackgroundColor3 = Color3.new(0, 0, 0)
shade.BackgroundTransparency = 0.45
shade.Parent = screenGui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromScale(0.9, 0)
panel.AutomaticSize = Enum.AutomaticSize.Y
panel.BackgroundColor3 = Color3.fromRGB(25, 20, 35)
panel.Parent = screenGui
local limit = Instance.new("UISizeConstraint")
limit.MaxSize = Vector2.new(560, math.huge)
limit.Parent = panel
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 14)
corner.Parent = panel
local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 20)
padding.PaddingBottom = UDim.new(0, 20)
padding.PaddingLeft = UDim.new(0, 22)
padding.PaddingRight = UDim.new(0, 22)
padding.Parent = panel
local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 12)
layout.Parent = panel

local function label(order: number, size: number, color: Color3): TextLabel
	local result = Instance.new("TextLabel")
	result.LayoutOrder = order
	result.Size = UDim2.fromScale(1, 0)
	result.AutomaticSize = Enum.AutomaticSize.Y
	result.BackgroundTransparency = 1
	result.Font = Enum.Font.BuilderSansBold
	result.TextSize = size
	result.TextWrapped = true
	result.TextXAlignment = Enum.TextXAlignment.Left
	result.TextColor3 = color
	result.Parent = panel
	return result
end

local step = label(1, 14, Color3.fromRGB(241, 196, 15))
local title = label(2, 26, Color3.new(1, 1, 1))
local body = label(3, 18, Color3.fromRGB(215, 210, 230))
body.Font = Enum.Font.BuilderSans

local nextButton = Instance.new("TextButton")
nextButton.LayoutOrder = 4
nextButton.Size = UDim2.fromOffset(200, 44)
nextButton.BackgroundColor3 = Color3.fromRGB(112, 36, 186)
nextButton.Font = Enum.Font.BuilderSansBold
nextButton.TextSize = 18
nextButton.TextColor3 = Color3.new(1, 1, 1)
nextButton.Parent = panel
local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(0, 10)
buttonCorner.Parent = nextButton

local index = 1

local function show()
	local slide = SLIDES[index]
	step.Text = `ОБУЧЕНИЕ · {index} из {#SLIDES}`
	title.Text = slide.Title
	body.Text = slide.Text
	nextButton.Text = if index < #SLIDES then "Далее" else "Начать работу"
end

nextButton.Activated:Connect(function()
	if index < #SLIDES then
		index += 1
		show()
		return
	end
	screenGui.Enabled = false
	rewardsEvent:FireServer("tutorialDone")
end)

local function check()
	if player:GetAttribute("TutorialDone") == false and not screenGui.Enabled then
		index = 1
		show()
		screenGui.Enabled = true
	end
end

player:GetAttributeChangedSignal("TutorialDone"):Connect(check)
check()
