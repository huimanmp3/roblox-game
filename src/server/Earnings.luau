--!strict
-- Заработок за работу (пики, раскладка, сборка, тягач). Сюда, а не напрямую в PlayerData,
-- чтобы учесть буст ×2 из наград и «Чёрную пятницу», а также посчитать заработок
-- в задания дня, достижения и недельную таблицу лидеров. Штрафы и награды идут мимо.

local Events = require(script.Parent.Events)
local Leaderboards = require(script.Parent.Leaderboards)
local PlayerData = require(script.Parent.PlayerData)
local Progress = require(script.Parent.Progress)
local Rewards = require(script.Parent.Rewards)

local Earnings = {}

function Earnings.multiplier(player: Player): number
	local multiplier = Events.payMultiplier()
	if Rewards.boostActive(player) then
		multiplier *= 2
	end
	return multiplier
end

-- Начислить заработок (копейки). Возвращает, сколько начислено с учётом бустов.
function Earnings.add(player: Player, kopecks: number): number
	if kopecks <= 0 then
		return 0
	end
	local total = math.round(kopecks * Earnings.multiplier(player))
	PlayerData.addKopecks(player, total)
	Progress.record(player, "earn", total / 100)
	Leaderboards.addEarned(player, total)
	return total
end

return Earnings
