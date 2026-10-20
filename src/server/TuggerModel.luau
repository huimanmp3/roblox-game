--!strict
-- Как выглядит тягач: оранжевый корпус на тёмной раме, капот с решёткой и фарами, руль,
-- сиденье со спинкой, защитная дуга с мигалкой, колёса с дисками и сцепка сзади.
-- Смотрит вперёд по -Z, точка опоры — на полу под центром. У тягача игрока сиденье VehicleSeat,
-- у тягача NPC на обычном сиденье сидит водитель-NPC.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Npc = require(script.Parent.Npc)

local CHASSIS_SIZE = Vector3.new(3.4, 1.2, 5)
local CHASSIS_HEIGHT = 0.9 -- центр корпуса над полом
local WHEEL_RADIUS = 0.65
local BODY_COLOR = Color3.fromRGB(232, 120, 28)
local DARK_COLOR = Color3.fromRGB(40, 42, 48)
local TIRE_COLOR = Color3.fromRGB(28, 28, 32)
local HUB_COLOR = Color3.fromRGB(170, 175, 182)
local SEAT_COLOR = Color3.fromRGB(34, 36, 42)
local STRIPE_COLOR = Color3.fromRGB(112, 36, 186)

local TuggerModel = {}

TuggerModel.COLLISION_GROUP = "Tugger"
TuggerModel.HALF_LENGTH = CHASSIS_SIZE.Z / 2

local function addPart(
	model: Model,
	chassis: BasePart,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = chassis.CFrame * offset
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.Parent = model

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = chassis
	weld.Part1 = part
	weld.Parent = part
	return part
end

-- Колесо: резиновая шина и стальной диск, который чуть выступает наружу
local function addWheel(model: Model, chassis: BasePart, x: number, z: number)
	local y = WHEEL_RADIUS - CHASSIS_HEIGHT
	local tire = addPart(
		model,
		chassis,
		"Wheel",
		Vector3.new(0.6, WHEEL_RADIUS * 2, WHEEL_RADIUS * 2),
		CFrame.new(x, y, z),
		TIRE_COLOR,
		Enum.Material.Rubber
	)
	tire.Shape = Enum.PartType.Cylinder
	local hub = addPart(
		model,
		chassis,
		"Hub",
		Vector3.new(0.66, WHEEL_RADIUS, WHEEL_RADIUS),
		CFrame.new(x, y, z),
		HUB_COLOR,
		Enum.Material.Metal
	)
	hub.Shape = Enum.PartType.Cylinder
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
	chassis.TopSurface = Enum.SurfaceType.Smooth
	chassis.BottomSurface = Enum.SurfaceType.Smooth
	chassis.Anchored = true
	-- Тягач двигают скриптом, а не физикой: сквозь людей и тары он проезжает
	chassis.CanCollide = false
	chassis.CollisionGroup = TuggerModel.COLLISION_GROUP
	chassis.Parent = model
	model.PrimaryPart = chassis

	-- Звук мотора (если задан в Config.Sounds.Tugger)
	if Config.Sounds.Tugger ~= "" then
		local motor = Instance.new("Sound")
		motor.Name = "Motor"
		motor.SoundId = Config.Sounds.Tugger
		motor.Looped = true
		motor.Volume = 0.35
		motor.RollOffMaxDistance = 50
		motor.Playing = true
		motor.Parent = chassis
	end

	local halfZ = CHASSIS_SIZE.Z / 2
	local top = CHASSIS_SIZE.Y / 2 -- верх корпуса относительно центра шасси

	-- Рама снизу, бамперы и фирменная полоса по бортам
	addPart(
		model,
		chassis,
		"Frame",
		Vector3.new(3.5, 0.35, 5.3),
		CFrame.new(0, -0.6, 0),
		DARK_COLOR,
		Enum.Material.Metal
	)
	for _, z in { -1, 1 } do
		addPart(
			model,
			chassis,
			"Bumper",
			Vector3.new(3.7, 0.45, 0.3),
			CFrame.new(0, -0.35, z * (halfZ + 0.15)),
			DARK_COLOR,
			Enum.Material.Rubber
		)
	end
	for _, x in { -1, 1 } do
		addPart(
			model,
			chassis,
			"Stripe",
			Vector3.new(0.05, 0.22, CHASSIS_SIZE.Z - 0.6),
			CFrame.new(x * (CHASSIS_SIZE.X / 2 + 0.025), 0.15, 0),
			STRIPE_COLOR
		)
	end

	-- Капот спереди: решётка и фары
	addPart(model, chassis, "Hood", Vector3.new(3.2, 1.1, 1.7), CFrame.new(0, top + 0.55, -halfZ + 0.85), BODY_COLOR)
	addPart(
		model,
		chassis,
		"Grille",
		Vector3.new(2, 0.6, 0.05),
		CFrame.new(0, top + 0.45, -halfZ - 0.03),
		DARK_COLOR,
		Enum.Material.Metal
	)
	for _, x in { -1.2, 1.2 } do
		addPart(
			model,
			chassis,
			"Headlight",
			Vector3.new(0.5, 0.32, 0.06),
			CFrame.new(x, top + 0.45, -halfZ - 0.04),
			Color3.fromRGB(255, 244, 214),
			Enum.Material.Neon
		)
		addPart(
			model,
			chassis,
			"Taillight",
			Vector3.new(0.4, 0.25, 0.06),
			CFrame.new(x, 0.1, halfZ + 0.04),
			Color3.fromRGB(220, 40, 40),
			Enum.Material.Neon
		)
	end

	-- Рабочее место: коврик, руль на наклонной колонке, спинка сиденья
	addPart(
		model,
		chassis,
		"FloorMat",
		Vector3.new(3, 0.06, 2.6),
		CFrame.new(0, top + 0.03, 0.9),
		DARK_COLOR,
		Enum.Material.Rubber
	)
	addPart(
		model,
		chassis,
		"SteeringColumn",
		Vector3.new(0.16, 1.1, 0.16),
		CFrame.new(0, top + 1.3, -0.45) * CFrame.Angles(math.rad(-30), 0, 0),
		DARK_COLOR,
		Enum.Material.Metal
	)
	local wheel = addPart(
		model,
		chassis,
		"SteeringWheel",
		Vector3.new(0.12, 1, 1),
		CFrame.new(0, top + 1.85, -0.2) * CFrame.Angles(math.rad(-30), math.rad(90), 0),
		DARK_COLOR
	)
	wheel.Shape = Enum.PartType.Cylinder
	addPart(
		model,
		chassis,
		"SeatBack",
		Vector3.new(2, 1.5, 0.3),
		CFrame.new(0, top + 1.35, 1.85),
		SEAT_COLOR,
		Enum.Material.Fabric
	)

	-- Защитная дуга за сиденьем и мигалка на ней
	for _, x in { -1.45, 1.45 } do
		addPart(
			model,
			chassis,
			"RollBar",
			Vector3.new(0.16, 3, 0.16),
			CFrame.new(x, top + 1.5, 2.15),
			DARK_COLOR,
			Enum.Material.Metal
		)
	end
	addPart(
		model,
		chassis,
		"RollBarTop",
		Vector3.new(3.06, 0.16, 0.16),
		CFrame.new(0, top + 3, 2.15),
		DARK_COLOR,
		Enum.Material.Metal
	)
	addPart(
		model,
		chassis,
		"Beacon",
		Vector3.new(0.45, 0.35, 0.45),
		CFrame.new(1.1, top + 3.26, 2.15),
		Color3.fromRGB(241, 196, 15),
		Enum.Material.Neon
	)
	addPart(
		model,
		chassis,
		"Hitch",
		Vector3.new(0.6, 0.3, 0.8),
		CFrame.new(0, -0.2, halfZ + 0.3),
		DARK_COLOR,
		Enum.Material.Metal
	)

	for _, x in { -1.75, 1.75 } do
		for _, z in { -1.7, 1.7 } do
			addWheel(model, chassis, x, z)
		end
	end

	local seatCFrame = chassis.CFrame * CFrame.new(0, top + 0.2, 0.9)
	if not withSeat then
		-- Водитель NPC: настоящий персонаж в форме, сидит за рулём
		local seat = Npc.seat(Vector3.new(2, 0.4, 1.8), seatCFrame, SEAT_COLOR, model)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = chassis
		weld.Part1 = seat
		weld.Parent = seat
		Npc.sit(seat, model)
		return model, chassis, nil
	end

	local seat = Instance.new("VehicleSeat")
	seat.Name = "Seat"
	seat.Size = Vector3.new(2, 0.4, 1.8)
	seat.CFrame = seatCFrame
	seat.Color = SEAT_COLOR
	seat.Material = Enum.Material.Fabric
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
