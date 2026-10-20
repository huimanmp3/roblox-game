--!strict
-- Раздевалка, пост охраны и турникет в блок К2.
-- Барьеры работают через группы столкновений: персонаж в форме попадает в группу Uniformed
-- (проходит пост охраны), а с рейтингом для К2 — в UniformedK2 (проходит и турникет К2).

local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerData = require(script.Parent.PlayerData)
local Rating = require(script.Parent.Rating)
local State = require(script.Parent.State)
local Tasks = require(script.Parent.Tasks)
local notify = require(script.Parent.Notify)

local UNIFORM_GROUP = "Uniformed"
local K2_GROUP = "UniformedK2"
local GATE_GROUP = "SecurityGate"
local K2_GATE_GROUP = "K2Gate"
local TUGGER_GROUP = "Tugger" -- корпус тягача (см. TuggerModel)
local LOCKER_DISTANCE = 8
local GATE_MESSAGE_COOLDOWN = 3

local Uniform = {}

local changing: { [Player]: boolean } = {}
local lastGateMessage: { [Player]: number } = {}
local lastAccess: { [Player]: boolean } = {}

-- В какой группе столкновений должен быть персонаж игрока
local function groupFor(player: Player): string
	if not State.session(player).uniform then
		return "Default"
	end
	return if Rating.hasK2Access(player) then K2_GROUP else UNIFORM_GROUP
end

function Uniform.refreshCollision(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local group = groupFor(player)
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = group
		end
	end
end

local function applyUniform(humanoid: Humanoid)
	local uniform = Config.Uniform
	local description = humanoid:GetAppliedDescription()
	description.GraphicTShirt = 0
	description.Shirt = uniform.ShirtId
	description.Pants = uniform.PantsId
	description.TorsoColor = uniform.TopColor
	description.LeftArmColor = uniform.TopColor
	description.RightArmColor = uniform.TopColor
	description.LeftLegColor = uniform.BottomColor
	description.RightLegColor = uniform.BottomColor

	-- 3D-одежда (куртки, футболки) закрыла бы форму. Снимаем её, а причёски и шапки оставляем.
	local kept = {}
	for _, accessory in description:GetAccessories(true) do
		if not accessory.IsLayered then
			table.insert(kept, accessory)
		end
	end
	description:SetAccessories(kept, true)

	humanoid:ApplyDescription(description)
end

-- Надеть форму (у шкафчика или из админ-панели)
function Uniform.dressUp(player: Player)
	local session = State.session(player)
	if session.uniform then
		notify(player, "Ты уже в форме. Иди через пост охраны на склад", "info")
		return
	end
	if changing[player] then
		return
	end

	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not character or not humanoid or humanoid.Health <= 0 then
		return
	end

	changing[player] = true
	local ok, err = pcall(applyUniform, humanoid)
	changing[player] = nil

	if not ok then
		warn(`Не удалось надеть форму на {player.Name}: {err}`)
		notify(player, "Не получилось переодеться, попробуй ещё раз", "error")
		return
	end
	if player.Character ~= character then
		return -- пока переодевались, персонаж сменился
	end

	session.uniform = true
	Uniform.refreshCollision(player)
	notify(
		player,
		"Форма надета! Проходи через пост охраны на склад",
		"success"
	)
	Tasks.refresh(player)
end

-- Барьер, который не пускает тех, кому туда нельзя. message возвращает текст или nil, если игроку можно.
local function setupBarrier(barrier: BasePart, group: string, message: (Player) -> string?)
	barrier.CollisionGroup = group
	barrier.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = if character then Players:GetPlayerFromCharacter(character) else nil
		local text = if player then message(player) else nil
		if not player or not text then
			return
		end

		local now = os.clock()
		if now - (lastGateMessage[player] or 0) < GATE_MESSAGE_COOLDOWN then
			return
		end
		lastGateMessage[player] = now
		notify(player, text, "error")
	end)
end

local function securityMessage(player: Player): string?
	if State.session(player).uniform then
		return nil
	end
	return "Охрана: без формы на склад нельзя! Переоденься в раздевалке"
end

local function k2Message(player: Player): string?
	if Rating.hasK2Access(player) then
		return nil
	end
	local profile = PlayerData.get(player)
	local rating = if profile then profile.rating else 0
	return `В блок К2 пускают с рейтинга {Config.Rating.K2Access}. У тебя: {rating}`
end

-- Игроки должны появляться только в раздевалке
local function setupSpawns()
	if #CollectionService:GetTagged("LockerSpawn") == 0 then
		warn("Нет SpawnLocation с тегом LockerSpawn: игроки появятся где попало")
		return
	end
	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("SpawnLocation") and not CollectionService:HasTag(descendant, "LockerSpawn") then
			descendant.Enabled = false
		end
	end
end

local function onCharacterAdded(player: Player, character: Model)
	-- После возрождения игрок снова в своей одежде
	State.session(player).uniform = false

	-- Детали, которые появятся позже (аксессуары, инструменты), получают ту же группу
	character.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") and player.Character == character then
			descendant.CollisionGroup = groupFor(player)
		end
	end)

	Tasks.refresh(player)
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	local character = player.Character
	if character then
		onCharacterAdded(player, character)
	end
end

local function registerGroups()
	for _, group in { UNIFORM_GROUP, K2_GROUP, GATE_GROUP, K2_GATE_GROUP, TUGGER_GROUP } do
		if not PhysicsService:IsCollisionGroupRegistered(group) then
			PhysicsService:RegisterCollisionGroup(group)
		end
	end
	PhysicsService:CollisionGroupSetCollidable(UNIFORM_GROUP, GATE_GROUP, false)
	PhysicsService:CollisionGroupSetCollidable(K2_GROUP, GATE_GROUP, false)
	PhysicsService:CollisionGroupSetCollidable(K2_GROUP, K2_GATE_GROUP, false)
	-- Ворота для техники пропускают тягачи
	PhysicsService:CollisionGroupSetCollidable(TUGGER_GROUP, K2_GATE_GROUP, false)
end

function Uniform.start()
	registerGroups()

	for _, gate in CollectionService:GetTagged("SecurityGate") do
		if gate:IsA("BasePart") then
			setupBarrier(gate, GATE_GROUP, securityMessage)
		end
	end
	for _, gate in CollectionService:GetTagged("K2Gate") do
		if gate:IsA("BasePart") then
			setupBarrier(gate, K2_GATE_GROUP, k2Message)
		end
	end

	for _, locker in CollectionService:GetTagged("Locker") do
		if locker:IsA("BasePart") then
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Переодеться"
			prompt.ObjectText = "Шкафчик"
			prompt.HoldDuration = 1
			prompt.MaxActivationDistance = LOCKER_DISTANCE
			prompt.RequiresLineOfSight = false
			prompt.Parent = locker
			prompt.Triggered:Connect(function(player)
				if State.isNear(player, locker, LOCKER_DISTANCE) then
					Uniform.dressUp(player)
				end
			end)
		end
	end

	setupSpawns()

	-- Рейтинг дорос до К2 или данные загрузились уже с таким рейтингом: меняем группу,
	-- чтобы турникет начал пропускать
	PlayerData.onChanged(function(player)
		local access = Rating.hasK2Access(player)
		if lastAccess[player] ~= access then
			lastAccess[player] = access
			Uniform.refreshCollision(player)
		end
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		changing[player] = nil
		lastGateMessage[player] = nil
		lastAccess[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return Uniform
