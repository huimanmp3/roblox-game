--!strict
-- Данные игрока: пока только деньги в таблице лидеров.
-- Сохранение между заходами добавим на следующем этапе.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local MONEY_NAME = "Деньги"

local PlayerData = {}

local function getMoneyValue(player: Player): IntValue?
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return nil
	end

	local money = leaderstats:FindFirstChild(MONEY_NAME)
	if money and money:IsA("IntValue") then
		return money
	end
	return nil
end

function PlayerData.addMoney(player: Player, amount: number)
	local money = getMoneyValue(player)
	if money then
		money.Value += amount
	end
end

local function onPlayerAdded(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local money = Instance.new("IntValue")
	money.Name = MONEY_NAME
	money.Value = Config.StartingMoney
	money.Parent = leaderstats

	leaderstats.Parent = player
end

function PlayerData.start()
	Players.PlayerAdded:Connect(onPlayerAdded)

	-- Игроки, зашедшие до запуска скрипта (бывает при тесте в Studio)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return PlayerData
