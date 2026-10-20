--!strict
-- Грузовой подъёмник мезонина. У пульта на каждой остановке одна подсказка «Выбрать этаж»:
-- она открывает у игрока меню с этажами (LiftMenu.client), выбор приходит через RemoteEvent Lift.
-- Подъёмник переносит игрока вместе с тарой, которую он катит.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local State = require(script.Parent.State)

local PANEL_DISTANCE = 8
local MENU_DISTANCE = 14 -- пока меню открыто, игрок мог немного отойти от пульта

local liftEvent = ReplicatedStorage.Remotes.Lift :: RemoteEvent

local Lift = {}

local stops: { [number]: BasePart } = {}
local panels: { BasePart } = {}

local function travel(player: Player, floor: number)
	local stop = stops[floor]
	local character = player.Character
	local root = State.getRoot(player)
	if not stop or not character or not root then
		return
	end

	-- Ставим игрока в центр площадки, сохраняя, куда он смотрит.
	-- Точка опоры персонажа — HumanoidRootPart, она примерно в 3 studs над полом.
	local target = stop.Position + Vector3.new(0, stop.Size.Y / 2 + 3.2, 0)
	character:PivotTo(CFrame.new(target) * root.CFrame.Rotation)
end

local function sortedFloors(): { number }
	local floors = {}
	for floor in stops do
		table.insert(floors, floor)
	end
	table.sort(floors)
	return floors
end

-- Игрок выбрал этаж в меню: проверяем, что он у пульта подъёмника
local function onChoice(player: Player, floor: unknown)
	if typeof(floor) ~= "number" or not stops[floor] then
		return
	end
	for _, panel in panels do
		if State.isNear(player, panel, MENU_DISTANCE) then
			travel(player, floor)
			return
		end
	end
end

function Lift.start()
	for _, stop in CollectionService:GetTagged("LiftStop") do
		local floor = stop:GetAttribute("Floor")
		if stop:IsA("BasePart") and typeof(floor) == "number" then
			stops[floor] = stop
		end
	end

	for _, panel in CollectionService:GetTagged("LiftPanel") do
		local here = panel:GetAttribute("Floor")
		if not panel:IsA("BasePart") or typeof(here) ~= "number" then
			continue
		end
		table.insert(panels, panel)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Выбрать этаж"
		prompt.ObjectText = `Грузовой подъёмник · {here} этаж`
		prompt.MaxActivationDistance = PANEL_DISTANCE
		prompt.RequiresLineOfSight = false
		prompt.Parent = panel
		prompt.Triggered:Connect(function(player)
			if State.isNear(player, panel, PANEL_DISTANCE) then
				liftEvent:FireClient(player, here, sortedFloors())
			end
		end)
	end

	liftEvent.OnServerEvent:Connect(onChoice)
end

return Lift
