--!strict
-- Команды для теста, пишутся в чат. Работают в Studio и у владельца игры, у остальных игроков — нет.
--   !rating 5000 — поставить себе рейтинг (например, чтобы сразу открыть мезонин и тягач)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PlayerData = require(script.Parent.PlayerData)
local Rating = require(script.Parent.Rating)
local notify = require(script.Parent.Notify)

local DevCommands = {}

local function allowed(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	return game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId
end

local function onChatted(player: Player, message: string)
	local command, value = string.match(message, "^!(%a+)%s+(%d+)$")
	local amount = tonumber(value)
	if command ~= "rating" or not amount or not allowed(player) then
		return
	end

	local profile = PlayerData.get(player)
	if not profile then
		notify(
			player,
			"Данные игрока ещё загружаются, попробуй через пару секунд",
			"error"
		)
		return
	end
	Rating.addPoints(player, amount - profile.rating)
	notify(player, `Рейтинг: {profile.rating}`, "info")
end

function DevCommands.start()
	local function watch(player: Player)
		player.Chatted:Connect(function(message)
			onChatted(player, message)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return DevCommands
