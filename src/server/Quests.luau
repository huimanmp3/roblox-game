--!strict
-- Задания дня (Config.Quests): каждый день игроку выпадает несколько заданий из списка —
-- только те, что ему доступны по рейтингу. Выполнил — забери рубли и опыт сезона.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Events = require(script.Parent.Events)
local PlayerData = require(script.Parent.PlayerData)
local RewardsState = require(script.Parent.RewardsState)
local Season = require(script.Parent.Season)
local notify = require(script.Parent.Notify)

type Definition = {
	Id: string,
	Text: string,
	Stat: string,
	Target: number,
	Reward: number,
	RatingRequired: number,
}
export type Entry = { id: string, progress: number, claimed: boolean }

local Quests = {}

function Quests.definition(id: unknown): Definition?
	for _, quest in Config.Quests.Pool do
		if quest.Id == id then
			return quest
		end
	end
	return nil
end

function Quests.text(definition: Definition): string
	return string.format(definition.Text, definition.Target)
end

-- Задания на сегодня (если день сменился — выпадают новые)
function Quests.list(player: Player): { Entry }
	local data = PlayerData.section(player, "quests")
	local profile = PlayerData.get(player)
	if not data or not profile then
		return {}
	end
	local today = Events.today()
	if data.day ~= today or typeof(data.list) ~= "table" then
		local available = {}
		for _, quest in Config.Quests.Pool do
			if profile.rating >= quest.RatingRequired then
				table.insert(available, quest)
			end
		end
		local list = {}
		while #list < Config.Quests.PerDay and #available > 0 do
			local quest = table.remove(available, math.random(#available)) :: Definition
			table.insert(list, { id = quest.Id, progress = 0, claimed = false })
		end
		data.day = today
		data.list = list
	end
	return data.list
end

-- Что-то произошло (stat, amount): продвигаем подходящие задания
function Quests.onStat(player: Player, stat: string, amount: number)
	for _, entry in Quests.list(player) do
		local definition = Quests.definition(entry.id)
		if definition and definition.Stat == stat and not entry.claimed and entry.progress < definition.Target then
			entry.progress = math.min(definition.Target, entry.progress + amount)
			if entry.progress >= definition.Target then
				notify(
					player,
					`Задание выполнено: {Quests.text(definition)}. Забери награду в «Наградах»`,
					"success"
				)
			end
			RewardsState.markDirty(player)
		end
	end
end

-- Забрать награду за выполненное задание (index — номер в списке на сегодня)
function Quests.claim(player: Player, index: unknown)
	local list = Quests.list(player)
	local entry = if typeof(index) == "number" then list[index] else nil
	local definition = if entry then Quests.definition(entry.id) else nil
	if not entry or not definition or entry.claimed or entry.progress < definition.Target then
		return
	end
	entry.claimed = true
	PlayerData.addKopecks(player, definition.Reward * 100)
	Season.addXp(player, Config.Quests.Xp)
	notify(player, `+{definition.Reward} ₽ и {Config.Quests.Xp} опыта сезона`, "success")
	RewardsState.markDirty(player)
end

return Quests
