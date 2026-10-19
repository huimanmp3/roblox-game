--!strict
-- Коридор с постом охраны между раздевалкой и складом.
-- Прозрачный барьер с тегом SecurityGate пропускает только игроков в форме.

local Parts = require(script.Parent.Parts)

local F = Parts.FLOOR
local MIN_Z, MAX_Z = -135, -100
local HALF_WIDTH = 12
local GATE_Z = -117
local BOOTH_EDGE_X = -5 -- будка охраны занимает коридор от западной стены до этой линии

local FLOOR_COLOR = Color3.fromRGB(160, 160, 165)
local WALL_COLOR = Color3.fromRGB(215, 215, 220)
local BOOTH_COLOR = Color3.fromRGB(235, 235, 240)
local METAL_COLOR = Color3.fromRGB(150, 150, 155)

local Security = {}

function Security.build(parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Security"
	model.Parent = parent

	Parts.box(
		"Floor",
		Vector3.new(-HALF_WIDTH, F - 1, MIN_Z),
		Vector3.new(HALF_WIDTH, F, MAX_Z),
		FLOOR_COLOR,
		Enum.Material.Concrete,
		model
	)
	Parts.box(
		"Wall",
		Vector3.new(-HALF_WIDTH - 1, F, MIN_Z),
		Vector3.new(-HALF_WIDTH, F + 12, MAX_Z),
		WALL_COLOR,
		Enum.Material.Plaster,
		model
	)
	Parts.box(
		"Wall",
		Vector3.new(HALF_WIDTH, F, MIN_Z),
		Vector3.new(HALF_WIDTH + 1, F + 12, MAX_Z),
		WALL_COLOR,
		Enum.Material.Plaster,
		model
	)

	-- Будка охраны с окном
	Parts.box(
		"Booth",
		Vector3.new(-HALF_WIDTH, F, GATE_Z - 5),
		Vector3.new(BOOTH_EDGE_X, F + 8, GATE_Z + 5),
		BOOTH_COLOR,
		Enum.Material.Plaster,
		model
	)
	Parts.part({
		Name = "BoothWindow",
		Size = Vector3.new(0.2, 2.5, 6),
		CFrame = CFrame.new(BOOTH_EDGE_X + 0.1, F + 5, GATE_Z),
		Color = Color3.fromRGB(170, 210, 240),
		Material = Enum.Material.Glass,
		Transparency = 0.4,
	}, model)
	Parts.sign(
		"ПОСТ ОХРАНЫ",
		CFrame.new(0, F + 10, GATE_Z),
		Vector3.new(16, 2.5, 0.3),
		Color3.fromRGB(50, 60, 80),
		model
	)

	-- Турникеты: стойки и прозрачный барьер между ними
	for _, x in { BOOTH_EDGE_X + 0.4, 3.6, HALF_WIDTH - 0.4 } do
		Parts.part({
			Name = "TurnstilePost",
			Size = Vector3.new(0.6, 3.4, 1.2),
			CFrame = CFrame.new(x, F + 1.7, GATE_Z),
			Color = METAL_COLOR,
			Material = Enum.Material.Metal,
		}, model)
	end

	local gate = Parts.part({
		Name = "Gate",
		Size = Vector3.new(HALF_WIDTH - BOOTH_EDGE_X, 9, 0.4),
		CFrame = CFrame.new((HALF_WIDTH + BOOTH_EDGE_X) / 2, F + 4.5, GATE_Z),
		Color = Color3.fromRGB(255, 90, 90),
		Material = Enum.Material.Glass,
		Transparency = 0.75,
		CanQuery = false,
	}, model)
	Parts.tag(gate, "SecurityGate")
end

return Security
