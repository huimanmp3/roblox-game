--!strict
-- Грузовой подъёмник мезонина. На каждой остановке пульт с кнопками других этажей
-- (клавиши 1, 2, 3). Подъёмник переносит игрока вместе с тарой, которую он катит.

local CollectionService = game:GetService("CollectionService")

local State = require(script.Parent.State)

local PANEL_DISTANCE = 8
local KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five }

local Lift = {}

local stops: { [number]: BasePart } = {}

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
		for floor in stops do
			if floor ~= here then
				local prompt = Instance.new("ProximityPrompt")
				prompt.ActionText = `На {floor} этаж`
				prompt.ObjectText = "Грузовой подъёмник"
				prompt.HoldDuration = 0.5
				prompt.MaxActivationDistance = PANEL_DISTANCE
				prompt.RequiresLineOfSight = false
				prompt.KeyboardKeyCode = KEYS[floor] or Enum.KeyCode.E
				prompt.Parent = panel
				prompt.Triggered:Connect(function(player)
					if State.isNear(player, panel, PANEL_DISTANCE) then
						travel(player, floor)
					end
				end)
			end
		end
	end
end

return Lift
