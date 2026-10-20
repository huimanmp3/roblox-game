--!strict
-- Кому из игроков пора отправить свежее состояние наград (задания, сезон, достижения...).
-- Модули наград отмечают игрока, а RewardsService раз в полсекунды отправляет ему всё разом.

local RewardsState = {}

local dirty: { [Player]: boolean } = {}

function RewardsState.markDirty(player: Player)
	dirty[player] = true
end

-- Забрать список отмеченных игроков (отметки снимаются)
function RewardsState.takeDirty(): { Player }
	local players = {}
	for player in dirty do
		table.insert(players, player)
	end
	table.clear(dirty)
	return players
end

return RewardsState
