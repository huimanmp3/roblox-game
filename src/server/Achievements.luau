--!strict
-- Достижения (Config.Achievements): выполняются один раз, дают рубли и, если задан BadgeId, значок Roblox.

local BadgeService = game:GetService("BadgeService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerData = require(script.Parent.PlayerData)
local RewardsState = require(script.Parent.RewardsState)
local notify = require(script.Parent.Notify)

local Achievements = {}

-- Текущее значение показателя для достижения
function Achievements.value(player: Player, stat: string): number
	local profile = PlayerData.get(player)
	if not profile then
		return 0
	end
	if stat == "rating" then
		return profile.rating
	elseif stat == "streak" then
		local daily = PlayerData.section(player, "daily")
		return if daily then tonumber(daily.best) or 0 else 0
	elseif stat == "seasonTier" then
		local season = PlayerData.section(player, "season")
		local xp = if season and season.id == Config.Season.Id then tonumber(season.xp) or 0 else 0
		return math.floor(xp / Config.Season.TierXp)
	end
	local stats = PlayerData.section(player, "stats")
	return if stats then tonumber(stats[stat]) or 0 else 0
end

function Achievements.isDone(player: Player, id: string): boolean
	local done = PlayerData.section(player, "achievements")
	return done ~= nil and done[id] == true
end

local function award(player: Player, badgeId: number)
	if badgeId == 0 then
		return
	end
	task.spawn(function()
		local ok, err = pcall(function()
			BadgeService:AwardBadgeAsync(player.UserId, badgeId)
		end)
		if not ok then
			warn(`Не удалось выдать значок {badgeId}: {err}`)
		end
	end)
end

-- Проверить все достижения игрока и выдать выполненные
function Achievements.check(player: Player)
	local done = PlayerData.section(player, "achievements")
	if not done then
		return
	end
	for _, achievement in Config.Achievements do
		if not done[achievement.Id] and Achievements.value(player, achievement.Stat) >= achievement.Target then
			done[achievement.Id] = true
			PlayerData.addKopecks(player, achievement.Reward * 100)
			award(player, achievement.BadgeId)
			notify(player, `Достижение «{achievement.Name}»! +{achievement.Reward} ₽`, "success")
			RewardsState.markDirty(player)
		end
	end
end

function Achievements.start()
	-- Достижения за рейтинг: проверяем при любом изменении данных игрока
	PlayerData.onChanged(Achievements.check)
	PlayerData.onLoaded(Achievements.check)
end

return Achievements
