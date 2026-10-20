--!strict
-- Табло у рабочего стола: средний пик по всем товарам (меняется вместе с ценами)
-- и средний пик хозяина стола за смену.

local Pricing = require(script.Parent.Pricing)
local State = require(script.Parent.State)

local SCREEN_COLOR = Color3.fromRGB(15, 15, 20)
local TEXT_COLOR = Color3.fromRGB(120, 255, 140)
local UP_COLOR = Color3.fromRGB(46, 204, 113)
local DOWN_COLOR = Color3.fromRGB(255, 99, 88)

local Boards = {}

local function rubles(kopecks: number): string
	return string.format("%.2f ₽", kopecks / 100)
end

local function addLine(gui: SurfaceGui, positionY: number, height: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Position = UDim2.fromScale(0.05, positionY)
	label.Size = UDim2.fromScale(0.9, height)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.Code
	label.TextColor3 = TEXT_COLOR
	label.Parent = gui
	return label
end

-- Делает из детали табло: тёмный экран с тремя строками
function Boards.create(part: BasePart): State.Board
	part.Color = SCREEN_COLOR
	part.Material = Enum.Material.SmoothPlastic

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.LightInfluence = 0
	gui.Parent = part

	local title = addLine(gui, 0.05, 0.22)
	title.Text = "СРЕДНИЙ ПИК"

	return {
		average = addLine(gui, 0.3, 0.38),
		personal = addLine(gui, 0.72, 0.22),
	}
end

function Boards.refresh(workTable: State.WorkTable)
	local board = workTable.board
	if not board then
		return
	end

	local trend = Pricing.trend()
	local arrow = if trend > 0 then " ▲" elseif trend < 0 then " ▼" else ""
	board.average.Text = rubles(Pricing.average()) .. arrow
	board.average.TextColor3 = if trend > 0 then UP_COLOR elseif trend < 0 then DOWN_COLOR else TEXT_COLOR

	if not workTable.owner then
		board.personal.Text = "Стол свободен"
	elseif workTable.picks == 0 then
		board.personal.Text = "Твой: пиков пока нет"
	else
		board.personal.Text = `Твой: {rubles(workTable.earned / workTable.picks)} · {workTable.picks} пик.`
	end
end

function Boards.start()
	for _, workTable in State.tables do
		Boards.refresh(workTable)
	end
	Pricing.onChanged(function()
		for _, workTable in State.tables do
			Boards.refresh(workTable)
		end
	end)
end

return Boards
