--!strict
-- Общее состояние приёмки: столы, палеты, тары и данные игроков.
-- Модули меняют его, а Tasks по нему решает, какое задание показать игроку.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

export type Category = Config.Category

export type Box = {
	part: BasePart,
	itemsLeft: number,
	column: number,
	level: number,
}

export type Pallet = {
	model: Model,
	qr: BasePart,
	category: Category,
	boxes: { Box },
	scanned: boolean,
}

export type Tote = {
	part: BasePart,
	prompt: ProximityPrompt,
	labels: { TextLabel },
	bar: Frame,
	category: Category?,
	count: number,
}

export type WorkTable = {
	number: number,
	model: Model,
	desk: BasePart,
	palletSpot: BasePart,
	toteSpot: BasePart,
	deskPrompt: ProximityPrompt,
	owner: Player?,
	occupied: boolean,
	pallet: Pallet?,
	tote: Tote?,
	palletOnTheWay: boolean,
	-- Растёт каждый раз, когда стол выдают или освобождают.
	-- По нему погрузчик понимает, что палет уже не нужен.
	delivery: number,
}

export type Session = {
	uniform: boolean,
	workTable: WorkTable?,
	carrying: Tote?,
	lastScan: number,
}

local DISTANCE_TOLERANCE = 6 -- запас на задержку сети при проверке расстояния

local State = {
	tables = {} :: { WorkTable },
	sessions = {} :: { [Player]: Session },
}

function State.session(player: Player): Session
	local existing = State.sessions[player]
	if existing then
		return existing
	end

	local session: Session = {
		uniform = false,
		workTable = nil,
		carrying = nil,
		lastScan = 0,
	}
	-- Для игрока, который уже вышел, данные не сохраняем
	if player.Parent then
		State.sessions[player] = session
	end
	return session
end

-- Корневая часть персонажа, если он есть и жив
function State.getRoot(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

function State.isNear(player: Player, part: BasePart, maxDistance: number): boolean
	local root = State.getRoot(player)
	if not root then
		return false
	end
	return (root.Position - part.Position).Magnitude <= maxDistance + DISTANCE_TOLERANCE
end

local function containsScanner(container: Instance?): boolean
	if not container then
		return false
	end
	for _, child in container:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute("Scanner") == true then
			return true
		end
	end
	return false
end

-- Сканер может быть в руке (в персонаже) или в рюкзаке
function State.hasScanner(player: Player): boolean
	return containsScanner(player.Character) or containsScanner(player:FindFirstChildOfClass("Backpack"))
end

-- Папка в Workspace для объектов, которые появляются во время игры
function State.folder(name: string): Folder
	local existing = workspace:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = workspace
	return folder
end

return State
