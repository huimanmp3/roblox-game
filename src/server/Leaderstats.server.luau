--!strict
-- Создаёт таблицу лидеров (leaderstats) с монетами для каждого игрока.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local function onPlayerAdded(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = Config.StartingCoins
	coins.Parent = leaderstats

	leaderstats.Parent = player
end

Players.PlayerAdded:Connect(onPlayerAdded)

-- Игроки, зашедшие до запуска скрипта (бывает при тесте в Studio)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
