--!strict
-- Ежедневный бонус (Config.DailyBonus): заходи каждый день — награда растёт 7 дней подряд.
-- Пропустил день — серия начинается сначала.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Achievements = require(script.Parent.Achievements)
local Config = require(ReplicatedStorage.Shared.Config)
local Events = require(script.Parent.Events)
local PlayerData = require(script.Parent.PlayerData)
local Rewards = require(script.Parent.Rewards)
local RewardsState = require(script.Parent.RewardsState)
local Season = require(script.Parent.Season)
local notify = require(script.Parent.Notify)

local DailyBonus = {}

-- Можно ли забрать бонус сегодня, какой это день серии (1–7) и сколько дней подряд
function DailyBonus.status(player: Player): (boolean, number, number)
	local data = PlayerData.section(player, "daily")
	if not data then
		return false, 1, 0
	end
	local today = Events.today()
	local lastDay = tonumber(data.lastDay) or 0
	local streak = tonumber(data.streak) or 0
	local days = #Config.DailyBonus.Days
	if lastDay == today then
		return false, (streak - 1) % days + 1, streak
	end
	local nextStreak = if lastDay == today - 1 then streak + 1 else 1
	return true, (nextStreak - 1) % days + 1, nextStreak
end

function DailyBonus.claim(player: Player)
	local data = PlayerData.section(player, "daily")
	local canClaim, day, streak = DailyBonus.status(player)
	if not data or not canClaim then
		return
	end
	data.lastDay = Events.today()
	data.streak = streak
	data.best = math.max(tonumber(data.best) or 0, streak)

	local reward = Config.DailyBonus.Days[day]
	local money = reward.Money or 0
	Rewards.grant(player, { Kind = "money", Amount = money })
	local minutes = reward.BoostMinutes
	if minutes then
		Rewards.grant(player, { Kind = "boost", Minutes = minutes })
	end
	Season.addXp(player, Config.DailyBonus.Xp)
	notify(player, `Ежедневный бонус, день {day}: +{money} ₽`, "success")
	Achievements.check(player)
	RewardsState.markDirty(player)
end

return DailyBonus
