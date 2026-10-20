--!strict
-- Внешний вид товара: фигура нужной формы, размера и цвета из Config (ItemType.Look),
-- материал и подробности из ItemModels. Если у товара задана картинка, она клеится
-- на переднюю и заднюю стороны.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ItemModels = require(script.Parent.ItemModels)

local Items = {}

local categoryByItem: { [Config.ItemType]: Config.Category } = {}
for _, category in Config.Categories do
	for _, item in category.Items do
		categoryByItem[item] = category
	end
end

function Items.categoryOf(item: Config.ItemType): Config.Category
	return categoryByItem[item]
end

-- maxSize: товар уменьшается, чтобы самая длинная сторона была не больше этого.
-- detailed: подробный вид с деталями и этикеткой (в руке и на полке); без него — только форма
-- и материал (для тар, где товара много). Детали лежат внутри корня, поэтому подробный товар
-- переставляют через PivotTo: он двигает корень вместе с деталями.
function Items.create(item: Config.ItemType, maxSize: number?, detailed: boolean?): Part
	local look = item.Look
	local dims = look.Dims
	local scale = 1
	if maxSize then
		scale = math.min(1, maxSize / math.max(dims.X, dims.Y, dims.Z))
	end
	local size = dims * scale

	local part = Instance.new("Part")
	part.Name = item.Name
	part.Color = look.Color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanTouch = false

	if look.Shape == "Ball" then
		part.Shape = Enum.PartType.Ball
		part.Size = Vector3.one * size.X
	elseif look.Shape == "Cylinder" then
		-- Ось цилиндра в Roblox идёт вдоль X: длина по X — это высота бутылки
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(size.Y, size.X, size.Z)
	elseif look.Shape == "Roll" then
		part.Shape = Enum.PartType.Cylinder
		part.Size = size
	else
		part.Size = size
	end

	ItemModels.decorate(item.Name, part, size, Items.uprightRotation(item), detailed == true)

	if look.Image ~= "" then
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local decal = Instance.new("Decal")
			decal.Texture = look.Image
			decal.Face = face
			decal.Parent = part
		end
	end

	return part
end

-- Высота товара в положении «стоя»: у бутылок это длина цилиндра (ось X)
function Items.uprightHeight(item: Config.ItemType, part: BasePart): number
	return if item.Look.Shape == "Cylinder" then part.Size.X else part.Size.Y
end

-- Как товар стоит: бутылки вертикально, остальное как есть
function Items.uprightRotation(item: Config.ItemType): CFrame
	if item.Look.Shape == "Cylinder" then
		return CFrame.Angles(0, 0, math.pi / 2)
	end
	return CFrame.identity
end

return Items
