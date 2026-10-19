--!strict
-- Грузчик на погрузчике: везёт палет от ворот к рабочему столу и уезжает обратно.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Pallets = require(script.Parent.Pallets)
local State = require(script.Parent.State)
local Tasks = require(script.Parent.Tasks)
local notify = require(script.Parent.Notify)

local FORK_DISTANCE = 4.5 -- от погрузчика до центра палета на вилах
-- Точка в проезде за палетным местом. Совпадает с AISLE_OFFSET в Map/Receiving.
local APPROACH_DISTANCE = 10
local CARRY_LIFT = 0.4 -- насколько поднят палет при перевозке
local TURN_TIME = 0.6
local PALLET_ON_FORKS = CFrame.new(0, CARRY_LIFT, -FORK_DISTANCE)

local BODY_COLOR = Color3.fromRGB(243, 156, 18)
local DARK_COLOR = Color3.fromRGB(45, 45, 50)
local METAL_COLOR = Color3.fromRGB(150, 150, 155)
local SKIN_COLOR = Color3.fromRGB(234, 184, 146)
local HELMET_COLOR = Color3.fromRGB(241, 196, 15)

local Forklift = {}

local function addPart(model: Model, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	-- Погрузчик проезжает сквозь игроков, чтобы никого не зажать
	part.CanCollide = false
	part.CanQuery = false
	part.Parent = model
	return part
end

-- Погрузчик смотрит вперёд по -Z, точка опоры — на полу под центром
local function buildForklift(): Model
	local model = Instance.new("Model")
	model.Name = "Forklift"

	local root = addPart(model, "Root", Vector3.new(1, 0.2, 1), CFrame.new(0, 0.1, 0), DARK_COLOR)
	root.Transparency = 1
	root.PivotOffset = CFrame.new(0, -0.1, 0)
	model.PrimaryPart = root

	addPart(model, "Body", Vector3.new(3.2, 2.2, 4), CFrame.new(0, 1.6, 0.5), BODY_COLOR)
	addPart(model, "Counterweight", Vector3.new(3.2, 1.4, 1), CFrame.new(0, 1.5, 3), DARK_COLOR)
	addPart(model, "Seat", Vector3.new(1.4, 0.4, 1.2), CFrame.new(0, 2.9, 1.1), DARK_COLOR)
	addPart(model, "Roof", Vector3.new(3.4, 0.2, 3.2), CFrame.new(0, 6.6, 0.5), DARK_COLOR)
	for _, x in { -1.5, 1.5 } do
		for _, z in { -0.9, 1.9 } do
			addPart(model, "CabPost", Vector3.new(0.2, 3.8, 0.2), CFrame.new(x, 4.6, z), DARK_COLOR)
		end
	end

	-- Водитель-грузчик в форме и каске
	addPart(model, "Driver", Vector3.new(1.4, 1.6, 0.8), CFrame.new(0, 3.9, 1.1), Config.Uniform.TopColor)
	addPart(model, "Head", Vector3.new(1.1, 1.1, 1.1), CFrame.new(0, 5.25, 1.1), SKIN_COLOR)
	addPart(model, "Helmet", Vector3.new(1.3, 0.4, 1.3), CFrame.new(0, 5.95, 1.1), HELMET_COLOR)

	for _, x in { -1, 1 } do
		addPart(model, "Mast", Vector3.new(0.3, 5, 0.3), CFrame.new(x, 2.6, -1.7), DARK_COLOR)
		addPart(model, "Fork", Vector3.new(0.5, 0.15, 4.4), CFrame.new(x, 0.35, -4), METAL_COLOR)
	end

	for _, x in { -1.7, 1.7 } do
		for _, z in { -1, 2 } do
			local wheel = addPart(model, "Wheel", Vector3.new(0.8, 1.6, 1.6), CFrame.new(x, 0.8, z), DARK_COLOR)
			wheel.Shape = Enum.PartType.Cylinder
		end
	end

	return model
end

-- Точка на верхней грани детали: туда ставим погрузчик и палет
local function groundOf(part: BasePart): CFrame
	return part.CFrame * CFrame.new(0, part.Size.Y / 2, 0)
end

local function nearestDock(position: Vector3): BasePart?
	local best: BasePart? = nil
	local bestDistance = math.huge
	for _, dock in CollectionService:GetTagged("LoadingDock") do
		if dock:IsA("BasePart") then
			local distance = (dock.Position - position).Magnitude
			if distance < bestDistance then
				best = dock
				bestDistance = distance
			end
		end
	end
	return best
end

local function driveTo(model: Model, target: CFrame)
	local start = model:GetPivot()
	local distance = (target.Position - start.Position).Magnitude
	local duration = math.max(distance / Config.ForkliftSpeed, TURN_TIME)

	local value = Instance.new("CFrameValue")
	value.Value = start
	local connection = value.Changed:Connect(function(cframe: CFrame)
		model:PivotTo(cframe)
	end)

	local tween = TweenService:Create(value, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Value = target })
	tween:Play()
	tween.Completed:Wait()

	connection:Disconnect()
	value:Destroy()
	model:PivotTo(target)
end

local function drive(model: Model, route: { CFrame })
	for _, waypoint in route do
		driveTo(model, waypoint)
	end
end

local function arrive(workTable: State.WorkTable, pallet: State.Pallet, spotGround: CFrame)
	pallet.model:PivotTo(spotGround)
	pallet.model.Parent = State.folder("Pallets")
	workTable.pallet = pallet
	workTable.palletOnTheWay = false

	local owner = workTable.owner
	if owner then
		notify(
			owner,
			`Палет приехал, в основном «{pallet.mainCategory.Name}». Отсканируй его QR-код`,
			"success"
		)
		Tasks.refresh(owner)
	end
end

local function deliver(workTable: State.WorkTable, delivery: number)
	local spotGround = groundOf(workTable.palletSpot)
	local pallet = Pallets.create()

	local dock = nearestDock(spotGround.Position)
	if not dock then
		-- Ворот на карте нет: палет просто появляется на месте
		arrive(workTable, pallet, spotGround)
		return
	end

	local dockGround = groundOf(dock).Position
	local approach = spotGround * CFrame.new(0, 0, APPROACH_DISTANCE)
	local start = CFrame.lookAt(dockGround, Vector3.new(approach.X, dockGround.Y, approach.Z))

	local forklift = buildForklift()
	forklift:PivotTo(start)
	pallet.model:PivotTo(start * PALLET_ON_FORKS)
	pallet.model.Parent = forklift
	forklift.Parent = State.folder("Forklifts")

	-- Едем по проезду, разворачиваемся к палетному месту и подъезжаем вплотную
	drive(forklift, {
		CFrame.new(approach.Position) * start.Rotation,
		approach,
		spotGround * CFrame.new(0, 0, FORK_DISTANCE),
	})

	-- Если стол освободили, пока ехали, палет уезжает обратно вместе с погрузчиком
	if workTable.delivery == delivery then
		arrive(workTable, pallet, spotGround)
	end

	local dockFlat = Vector3.new(dockGround.X, approach.Y, dockGround.Z)
	drive(forklift, {
		approach,
		CFrame.lookAt(approach.Position, dockFlat),
		CFrame.lookAt(dockFlat, dockFlat + (dockFlat - approach.Position)),
	})
	forklift:Destroy()
end

function Forklift.requestPallet(workTable: State.WorkTable)
	if workTable.pallet or workTable.palletOnTheWay or not workTable.occupied then
		return
	end
	workTable.palletOnTheWay = true

	local delivery = workTable.delivery
	task.delay(Config.PalletDelay, function()
		if workTable.delivery == delivery then
			deliver(workTable, delivery)
		end
	end)
end

return Forklift
