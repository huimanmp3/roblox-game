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

Parts.SIGN_BACKGROUND = Color3.fromRGB(24, 26, 33)

-- Табличка в современном стиле: тёмная скруглённая панель, цветная полоса слева и белый текст.
-- Светится сама (не зависит от освещения), читается с обеих сторон. color — цвет полосы.
function Parts.sign(text: string, cframe: CFrame, size: Vector3, color: Color3, parent: Instance): Part
	local sign = Parts.part({
		Name = "Sign",
		Size = size,
		CFrame = cframe,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	}, parent)

	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 50
		gui.LightInfluence = 0
		gui.Parent = sign

		local panel = Instance.new("Frame")
		panel.Size = UDim2.fromScale(1, 1)
		panel.BackgroundColor3 = Parts.SIGN_BACKGROUND
		panel.BorderSizePixel = 0
		panel.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.18, 0)
		corner.Parent = panel

		local accent = Instance.new("Frame")
		accent.AnchorPoint = Vector2.new(0, 0.5)
		accent.Position = UDim2.fromScale(0, 0.5)
		accent.Size = UDim2.new(0, math.max(8, math.floor(size.Y * 50 * 0.12)), 0.64, 0)
		accent.BackgroundColor3 = color
		accent.BorderSizePixel = 0
		accent.Parent = panel
		local accentCorner = Instance.new("UICorner")
		accentCorner.CornerRadius = UDim.new(1, 0)
		accentCorner.Parent = accent

		local label = Instance.new("TextLabel")
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromScale(0.5, 0.5)
		label.Size = UDim2.fromScale(0.86, 0.62)
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextScaled = true
		label.Font = Enum.Font.BuilderSansExtraBold
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Parent = panel
	end

	return sign
end

-- Невидимая стена: не даёт перепрыгнуть ограждение или выйти за пределы здания
function Parts.invisibleWall(name: string, from: Vector3, to: Vector3, parent: Instance): Part
	local wall = Parts.box(name, from, to, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, parent)
	wall.Transparency = 1
	wall.CanQuery = false
	wall.CanTouch = false
	return wall
end

-- Светодиодная лампа под потолком: светящаяся полоса и свет вниз
function Parts.ceilingLight(cframe: CFrame, length: number, range: number, parent: Instance): Part
	local lamp = Parts.part({
		Name = "CeilingLight",
		Size = Vector3.new(length, 0.25, 1.1),
		CFrame = cframe,
		Color = Color3.fromRGB(245, 248, 255),
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	}, parent)
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Bottom
	light.Range = range
	light.Angle = 140
	light.Brightness = 1.2
	light.Color = Color3.fromRGB(255, 248, 238)
	light.Shadows = false
	light.Parent = lamp
	return lamp
end

function Parts.tag(instance: Instance, tag: string)
	CollectionService:AddTag(instance, tag)
end

return Parts
