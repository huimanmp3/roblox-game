--!strict
-- Учёт работы игрока: модули игры сообщают, что произошло (Progress.record), а отсюда
-- обновляются счётчики, задания дня, опыт сезона и достижения.
-- Показатели: pick, cart, pallet, cardboard, earn (₽), putaway, order, tuggerCart.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Achievements = require(script.Parent.Achievements)
local Config = require(ReplicatedStorage.Shared.Config)
local PlayerData = require(script.Parent.PlayerData)
local Quests = require(script.Parent.Quests)
local RewardsState = require(script.Parent.RewardsState)
local Season = require(script.Parent.Season)

local Progress = {}

function Progress.record(player: Player, stat: string, amount: number?)
	local stats = PlayerData.section(player, "stats")
	if not stats then
		return
	end
	local value = amount or 1
	stats[stat] = (tonumber(stats[stat]) or 0) + value

	Quests.onStat(player, stat, value)
	local xp = (Config.Season.Xp :: any)[stat]
	if typeof(xp) == "number" then
		Season.addXp(player, xp * value)
	end
	Achievements.check(player)
	RewardsState.markDirty(player)
end

return Progress
