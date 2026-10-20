--!strict
-- Логистика карщиков: стоянка тягачей в центральном проходе, дорога вдоль северной стены
-- (через ворота для техники в К2), погрузка тягачей у буфера мусора К4 и у зоны пустых тар мезонина,
-- утилизация мусора в углу К2 и приём пустых тар у буфера К4.
-- Погрузки помечены тегом TrainPickup, места сдачи паровоза — тегом TrainDrop.
-- У обоих атрибут Kind: "cardboard" (тары с картоном) или "empty" (пустые тары).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Parts = require(script.Parent.Parts)

local F = Parts.FLOOR
local ROAD_Z = 189 -- совпадает с ROAD_Z в Hauling
local ROAD_MIN_X, ROAD_MAX_X = -148, 166

local ROAD_COLOR = Color3.fromRGB(241, 196, 15)
local DEPOT_COLOR = Color3.fromRGB(230, 126, 34)
local WASTE_COLOR = Color3.fromRGB(150, 110, 70)
local EMPTY_COLOR = Color3.fromRGB(150, 155, 160)
local PICKUP_COLOR = Color3.fromRGB(52, 152, 219)
local DARK_COLOR = Color3.fromRGB(50, 50, 60)
local CARDBOARD_COLOR = Color3.fromRGB(196, 154, 108)

local Logistics = {}

local function zone(model: Model, name: string, from: Vector2, to: Vector2, color: Color3): Part
	return Parts.part({
		Name = name,
		Size = Vector3.new(to.X - from.X, 0.05, to.Y - from.Y),
		CFrame = CFrame.new((from.X + to.X) / 2, F + 0.025, (from.Y + to.Y) / 2),
		Color = color,
		Transparency = 0.4,
		CanCollide = false,
		CanQuery = false,
	}, model)
end

local function buildDepot(model: Model)
	local depot = zone(model, "TuggerDepot", Vector2.new(-8, 152), Vector2.new(8, 176), DEPOT_COLOR)
	Parts.tag(depot, "TuggerDepot")
	Parts.sign(
		`ТЯГАЧИ · права с рейтинга {Config.Tugger.RatingRequired}`,
		CFrame.new(0, F + 8, 151.5),
		Vector3.new(16, 2, 0.3),
		DEPOT_COLOR,
		model
	)
end

local function buildRoad(model: Model)
	local line = Parts.box(
		"RoadLine",
		Vector3.new(ROAD_MIN_X, F, ROAD_Z - 0.25),
		Vector3.new(ROAD_MAX_X, F + 0.04, ROAD_Z + 0.25),
		ROAD_COLOR,
		Enum.Material.SmoothPlastic,
		model
	)
	line.CanCollide = false
end

-- Утилизация в северо-западном углу К2: пресс и тюки картона
local function buildUtilization(model: Model)
	local drop = zone(model, "Utilization", Vector2.new(-148, 164), Vector2.new(-112, 198), WASTE_COLOR)
	drop:SetAttribute("Kind", "cardboard")
	Parts.tag(drop, "TrainDrop")

	Parts.part({
		Name = "Press",
		Size = Vector3.new(8, 7, 8),
		CFrame = CFrame.new(-140, F + 3.5, 191),
		Color = DARK_COLOR,
		Material = Enum.Material.Metal,
	}, model)
	for _, x in { -128, -124, -120 } do
		Parts.part({
			Name = "Bale",
			Size = Vector3.new(3, 2.5, 3),
			CFrame = CFrame.new(x, F + 1.25, 194),
			Color = CARDBOARD_COLOR,
			Material = Enum.Material.Cardboard,
		}, model)
	end
	Parts.sign(
		"УТИЛИЗАЦИЯ МУСОРА",
		CFrame.new(-130, F + 9, 163.5),
		Vector3.new(20, 2.5, 0.3),
		WASTE_COLOR,
		model
	)
end

-- Приём пустых тар с мезонина: у северного края буфера пустых тар К4
local function buildEmptyDrop(model: Model)
	local drop = zone(model, "EmptyCartsDrop", Vector2.new(26, 172), Vector2.new(86, 186), EMPTY_COLOR)
	drop:SetAttribute("Kind", "empty")
	Parts.tag(drop, "TrainDrop")
	Parts.sign(
		"ПРИЁМ ПУСТЫХ ТАР С МЕЗОНИНА",
		CFrame.new(56, F + 7, 186.5),
		Vector3.new(24, 2.2, 0.3),
		DARK_COLOR,
		model
	)
end

-- Погрузка тягачей: здесь карщику выдают тары в паровоз
local function buildPickup(model: Model, name: string, kind: string, from: Vector2, to: Vector2, title: string)
	local pickup = zone(model, name, from, to, PICKUP_COLOR)
	pickup:SetAttribute("Kind", kind)
	Parts.tag(pickup, "TrainPickup")
	local center = (from + to) / 2
	Parts.sign(title, CFrame.new(center.X, F + 7, to.Y + 0.5), Vector3.new(22, 2.2, 0.3), PICKUP_COLOR, model)
end

function Logistics.build(parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Logistics"
	model.Parent = parent

	buildDepot(model)
	buildRoad(model)
	buildUtilization(model)
	buildEmptyDrop(model)
	-- Картон: между буфером мусора К4 и дорогой. Зона с запасом достаёт до дороги,
	-- поэтому цеплять тары можно, не съезжая с неё
	buildPickup(
		model,
		"CardboardPickup",
		"cardboard",
		Vector2.new(100, 172),
		Vector2.new(160, 186),
		"ПОГРУЗКА ТЯГАЧЕЙ · КАРТОН"
	)
	-- Пустые тары: между зоной пустых тар мезонина и дорогой
	buildPickup(
		model,
		"EmptyCartsPickup",
		"empty",
		Vector2.new(-100, 164),
		Vector2.new(-56, 184),
		"ПОГРУЗКА ТЯГАЧЕЙ · ПУСТЫЕ ТАРЫ"
	)
end

return Logistics
