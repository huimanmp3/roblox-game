--!strict
-- Всплывающие сообщения от сервера: «+10 ₽», «Руки заняты!» и т. п.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local notifyEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify") :: RemoteEvent

local SHOW_TIME = 2.5
local FADE_TIME = 0.5
local MAX_VISIBLE = 4

local TEXT_COLORS: { [string]: Color3 } = {
	success = Color3.fromRGB(46, 204, 113),
	error = Color3.fromRGB(231, 76, 60),
	info = Color3.fromRGB(255, 255, 255),
}

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "Notifications"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local container = Instance.new("Frame")
container.AnchorPoint = Vector2.new(0.5, 0)
container.Position = UDim2.new(0.5, 0, 0, 60)
container.Size = UDim2.fromScale(0.9, 0.5)
container.BackgroundTransparency = 1
container.Parent = screenGui

local sizeLimit = Instance.new("UISizeConstraint")
sizeLimit.MaxSize = Vector2.new(460, math.huge)
sizeLimit.Parent = container

local layout = Instance.new("UIListLayout")
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 6)
layout.Parent = container

local visible: { TextLabel } = {}
local counter = 0

local function show(text: string, kind: string)
	counter += 1

	local label = Instance.new("TextLabel")
	label.LayoutOrder = counter
	label.Size = UDim2.fromScale(1, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.BackgroundColor3 = Color3.fromRGB(25, 20, 35)
	label.BackgroundTransparency = 0.25
	label.Font = Enum.Font.GothamBold
	label.TextSize = 22
	label.TextWrapped = true
	label.TextColor3 = TEXT_COLORS[kind] or TEXT_COLORS.info
	label.Text = text

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = label

	label.Parent = container
	table.insert(visible, label)

	-- Слишком много сообщений сразу: убираем самое старое
	if #visible > MAX_VISIBLE then
		local oldest = table.remove(visible, 1)
		if oldest then
			oldest:Destroy()
		end
	end

	task.delay(SHOW_TIME, function()
		if not label.Parent then
			return
		end
		TweenService:Create(label, TweenInfo.new(FADE_TIME), {
			TextTransparency = 1,
			BackgroundTransparency = 1,
		}):Play()
		task.wait(FADE_TIME)

		local index = table.find(visible, label)
		if index then
			table.remove(visible, index)
		end
		label:Destroy()
	end)
end

notifyEvent.OnClientEvent:Connect(show)

show(
	"Бери коробки на приёмке и раскладывай по ячейкам с той же буквой",
	"info"
)
