--!strict
-- Как выглядит тягач: оранжевая машинка с мигалкой и сцепкой сзади. Смотрит вперёд по -Z,
-- точка опоры — на полу под центром. У тягача игрока есть сиденье (VehicleSeat),
-- у тягача NPC вместо него сидит водитель.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local CHASSIS_SIZE = Vector3.new(3.4, 1.2, 5)
local CHASSIS_HEIGHT = 0.9 -- центр корпуса над полом
local BODY_COLOR = Color3.fromRGB(230, 126, 34)
local DARK_COLOR = Color3.fromRGB(45, 45, 50)
local SKIN_COLOR = Color3.fromRGB(234, 184, 146)

local TuggerModel = {}

TuggerModel.COLLISION_GROUP = "Tugger"
TuggerModel.HALF_LENGTH = CHASSIS_SIZE.Z / 2

local function addPart(
	model: Model,
	chassis: BasePart,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = chassis.CFrame * offset
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanTouch = false
	part.Massless = true
	part.Parent = model

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = chassis
	weld.Part1 = part
	weld.Parent = part
	return part
end

-- withSeat = true — тягач игрока, false — тягач NPC с водителем
function TuggerModel.create(withSeat: boolean): (Model, BasePart, VehicleSeat?)
	local model = Instance.new("Model")
	model.Name = "Tugger"

	local chassis = Instance.new("Part")
	chassis.Name = "Chassis"
	chassis.Size = CHASSIS_SIZE
	chassis.CFrame = CFrame.new(0, CHASSIS_HEIGHT, 0)
	chassis.PivotOffset = CFrame.new(0, -CHASSIS_HEIGHT, 0)
	chassis.Color = BODY_COLOR
	chassis.Material = Enum.Material.SmoothPlastic
	chassis.Anchored = true
	-- Тягач двигают скриптом, а не физикой: сквозь людей и тары он проезжает
	chassis.CanCollide = false
	chassis.CollisionGroup = TuggerModel.COLLISION_GROUP
	chassis.Parent = model
	model.PrimaryPart = chassis

	addPart(model, chassis, "Hood", Vector3.new(3.2, 1.2, 1.6), CFrame.new(0, 1.2, -1.6), BODY_COLOR)
	addPart(
		model,
		chassis,
		"Hitch",
		Vector3.new(0.6, 0.3, 0.8),
		CFrame.new(0, -0.2, CHASSIS_SIZE.Z / 2 + 0.3),
		DARK_COLOR
	)
	addPart(model, chassis, "BeaconPole", Vector3.new(0.15, 2.5, 0.15), CFrame.new(1.4, 1.9, 2.1), DARK_COLOR)
	local beacon = addPart(
		model,
		chassis,
		"Beacon",
		Vector3.new(0.5, 0.4, 0.5),
		CFrame.new(1.4, 3.3, 2.1),
		Color3.fromRGB(241, 196, 15)
	)
	beacon.Material = Enum.Material.Neon
	for _, x in { -1.75, 1.75 } do
		for _, z in { -1.7, 1.7 } do
			local wheel =
				addPart(model, chassis, "Wheel", Vector3.new(0.5, 1.2, 1.2), CFrame.new(x, -0.3, z), DARK_COLOR)
			wheel.Shape = Enum.PartType.Cylinder
		end
	end

	if not withSeat then
		addPart(model, chassis, "Driver", Vector3.new(1.4, 1.6, 0.8), CFrame.new(0, 1.4, 0.8), Config.Uniform.TopColor)
		addPart(model, chassis, "Head", Vector3.new(1.1, 1.1, 1.1), CFrame.new(0, 2.75, 0.8), SKIN_COLOR)
		addPart(
			model,
			chassis,
			"Helmet",
			Vector3.new(1.3, 0.4, 1.3),
			CFrame.new(0, 3.45, 0.8),
			Color3.fromRGB(241, 196, 15)
		)
		return model, chassis, nil
	end

	local seat = Instance.new("VehicleSeat")
	seat.Name = "Seat"
	seat.Size = Vector3.new(2, 0.4, 1.8)
	seat.CFrame = chassis.CFrame * CFrame.new(0, 0.8, 0.8)
	seat.Color = DARK_COLOR
	seat.HeadsUpDisplay = false
	seat.CanCollide = false
	seat.Massless = true
	seat.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = chassis
	weld.Part1 = seat
	weld.Parent = seat

	return model, chassis, seat
end

return TuggerModel
