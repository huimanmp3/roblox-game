--!strict
-- Раздевалка и пост охраны: игрок переодевается в форму, без формы охрана не пускает на склад.
-- Барьер на посту не сталкивается только с персонажами в группе столкновений Uniformed.

local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)
local Tasks = require(script.Parent.Tasks)
local notify = require(script.Parent.Notify)

local UNIFORM_GROUP = "Uniformed"
local GATE_GROUP = "SecurityGate"
local LOCKER_DISTANCE = 8
local GATE_MESSAGE_COOLDOWN = 3

local Uniform = {}

local changing: { [Player]: boolean } = {}
local lastGateMessage: { [Player]: number } = {}

local function setCollisionGroup(character: Model, group: string)
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

local function dressUp(player: Player)
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
	setCollisionGroup(character, UNIFORM_GROUP)
	notify(
		player,
		"Форма надета! Проходи через пост охраны на склад",
		"success"
	)
	Tasks.refresh(player)
end

local function setupGate(gate: BasePart)
	gate.CollisionGroup = GATE_GROUP
	gate.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = if character then Players:GetPlayerFromCharacter(character) else nil
		if not player or State.session(player).uniform then
			return
		end

		local now = os.clock()
		if now - (lastGateMessage[player] or 0) < GATE_MESSAGE_COOLDOWN then
			return
		end
		lastGateMessage[player] = now
		notify(
			player,
			"Охрана: без формы на склад нельзя! Переоденься в раздевалке",
			"error"
		)
	end)
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

	-- Детали, которые появятся позже (аксессуары, инструменты), тоже должны проходить барьер
	character.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") and State.session(player).uniform and player.Character == character then
			descendant.CollisionGroup = UNIFORM_GROUP
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

function Uniform.start()
	for _, group in { UNIFORM_GROUP, GATE_GROUP } do
		if not PhysicsService:IsCollisionGroupRegistered(group) then
			PhysicsService:RegisterCollisionGroup(group)
		end
	end
	PhysicsService:CollisionGroupSetCollidable(UNIFORM_GROUP, GATE_GROUP, false)

	for _, gate in CollectionService:GetTagged("SecurityGate") do
		if gate:IsA("BasePart") then
			setupGate(gate)
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
					dressUp(player)
				end
			end)
		end
	end

	setupSpawns()

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		changing[player] = nil
		lastGateMessage[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return Uniform
