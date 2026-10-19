--!strict
-- Помощники для постройки карты из простых блоков.

local CollectionService = game:GetService("CollectionService")

local Parts = {}

Parts.FLOOR = 0.05 -- высота пола: чуть выше Baseplate, чтобы поверхности не мерцали
Parts.BRAND = Color3.fromRGB(112, 36, 186)

function Parts.part(props: { [string]: any }, parent: Instance): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = parent
	return part
end

-- Блок между двумя противоположными углами: удобно для полов и стен
function Parts.box(
	name: string,
	from: Vector3,
	to: Vector3,
	color: Color3,
	material: Enum.Material,
	parent: Instance
): Part
	local low = from:Min(to)
	local high = from:Max(to)
	return Parts.part({
		Name = name,
		Size = high - low,
		CFrame = CFrame.new((low + high) / 2),
		Color = color,
		Material = material,
	}, parent)
end

-- Табличка с текстом, читается с обеих сторон
function Parts.sign(text: string, cframe: CFrame, size: Vector3, color: Color3, parent: Instance): Part
	local sign = Parts.part({
		Name = "Sign",
		Size = size,
		CFrame = cframe,
		Color = color,
		CanCollide = false,
		CanQuery = false,
	}, parent)

	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 50
		gui.Parent = sign

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextScaled = true
		label.Font = Enum.Font.GothamBlack
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Parent = gui
	end

	return sign
end

function Parts.tag(instance: Instance, tag: string)
	CollectionService:AddTag(instance, tag)
end

return Parts
