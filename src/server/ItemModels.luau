--!strict
-- Подробный вид товаров: каждому товару свой материал, а в подробном режиме ещё детали
-- (крышки, ручки, ленты, уши у мишки...) и напечатанная этикетка на упаковке.
-- Подробный режим — у товара в руке и на полках мезонина. В таре товара много, там только
-- форма и материал, чтобы игра не тормозила.
-- Товар ищется по имени из Config. Новый товар без описания здесь будет простой фигурой.

local ItemModels = {}

local VERTICAL = CFrame.Angles(0, 0, math.pi / 2) -- цилиндр Roblox лежит вдоль X: так он встаёт
local FACING = CFrame.Angles(0, math.pi / 2, 0) -- так ось цилиндра смотрит вперёд (по Z)
local LABEL_DISTANCE = 30 -- дальше этого этикетки не рисуются

local WHITE = Color3.fromRGB(245, 245, 245)
local DARK = Color3.fromRGB(32, 33, 38)
local STEEL = Color3.fromRGB(190, 196, 202)
local GOLD = Color3.fromRGB(212, 175, 55)
local BRAND = Color3.fromRGB(112, 36, 186)

type Print = {
	Title: string,
	Subtitle: string?,
	Band: Color3,
	Text: Color3?,
	Circle: Color3?, -- круг-«картинка» над полосой
	Bricks: boolean?, -- три цветных кирпичика над полосой
}

-- Всё, что нужно описанию товара: корень, его размер «стоя» и способ добавить деталь
export type Context = {
	root: BasePart,
	size: Vector3, -- ширина, высота, глубина товара в положении «стоя»
	add: (
		name: string,
		shape: Enum.PartType,
		size: Vector3,
		offset: CFrame,
		color: Color3,
		material: Enum.Material?
	) -> Part,
	print: (part: BasePart, face: Enum.NormalId, spec: Print) -> (),
}

type Model = {
	Material: Enum.Material?,
	Reflectance: number?,
	Build: ((Context) -> ())?,
}

-- Этикетка на грани детали: цветная полоса с названием, подпись и простая «картинка»
local function addPrint(part: BasePart, face: Enum.NormalId, spec: Print)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 160
	gui.MaxDistance = LABEL_DISTANCE
	gui.Parent = part

	local band = Instance.new("Frame")
	band.Position = UDim2.fromScale(0, 0.42)
	band.Size = UDim2.fromScale(1, 0.3)
	band.BackgroundColor3 = spec.Band
	band.BorderSizePixel = 0
	band.Parent = gui

	local title = Instance.new("TextLabel")
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.fromScale(0.5, 0.5)
	title.Size = UDim2.fromScale(0.9, 0.8)
	title.BackgroundTransparency = 1
	title.Text = spec.Title
	title.TextScaled = true
	title.Font = Enum.Font.BuilderSansExtraBold
	title.TextColor3 = spec.Text or DARK
	title.Parent = band

	local subtitle = spec.Subtitle
	if subtitle then
		local label = Instance.new("TextLabel")
		label.Position = UDim2.fromScale(0.05, 0.76)
		label.Size = UDim2.fromScale(0.9, 0.13)
		label.BackgroundTransparency = 1
		label.Text = subtitle
		label.TextScaled = true
		label.Font = Enum.Font.BuilderSansBold
		label.TextColor3 = WHITE
		label.TextStrokeTransparency = 0.6
		label.Parent = gui
	end

	local circle = spec.Circle
	if circle then
		local dot = Instance.new("Frame")
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Position = UDim2.fromScale(0.5, 0.21)
		dot.Size = UDim2.fromScale(0.3, 0.3)
		dot.SizeConstraint = Enum.SizeConstraint.RelativeXX
		dot.BackgroundColor3 = circle
		dot.BorderSizePixel = 0
		dot.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = dot
	end

	if spec.Bricks then
		for index, color in { Color3.fromRGB(241, 196, 15), Color3.fromRGB(52, 152, 219), Color3.fromRGB(46, 204, 113) } do
			local brick = Instance.new("Frame")
			brick.Position = UDim2.fromScale(0.1 + (index - 1) * 0.28, 0.12 + (index % 2) * 0.08)
			brick.Size = UDim2.fromScale(0.24, 0.16)
			brick.BackgroundColor3 = color
			brick.BorderSizePixel = 0
			brick.Parent = gui
		end
	end
end

-- Бутылка: крышка сверху и этикетка спереди
local function bottle(capColor: Color3, capHeight: number, capWidth: number, spec: Print): (Context) -> ()
	return function(ctx: Context)
		local width, height = ctx.size.X, ctx.size.Y
		ctx.add(
			"Cap",
			Enum.PartType.Cylinder,
			Vector3.new(height * capHeight, width * capWidth, width * capWidth),
			CFrame.new(0, height / 2 + height * capHeight / 2, 0) * VERTICAL,
			capColor
		)
		local label = ctx.add(
			"Label",
			Enum.PartType.Block,
			Vector3.new(width * 0.72, height * 0.5, 0.02),
			CFrame.new(0, -height * 0.05, -width / 2 - 0.005),
			WHITE
		)
		ctx.print(label, Enum.NormalId.Front, spec)
	end
end

-- Коробка или пакет: этикетка спереди и сзади
local function printed(spec: Print): (Context) -> ()
	return function(ctx: Context)
		ctx.print(ctx.root, Enum.NormalId.Front, spec)
		ctx.print(ctx.root, Enum.NormalId.Back, spec)
	end
end

-- Ручка-петля сверху (у пакета или коробки)
local function topHandle(ctx: Context, color: Color3)
	local width, height = ctx.size.X, ctx.size.Y
	local span = width * 0.4
	for _, x in { -span / 2, span / 2 } do
		ctx.add(
			"HandlePost",
			Enum.PartType.Block,
			Vector3.new(0.05, height * 0.12, 0.05),
			CFrame.new(x, height / 2 + height * 0.06, 0),
			color
		)
	end
	ctx.add(
		"HandleBar",
		Enum.PartType.Block,
		Vector3.new(span + 0.05, 0.05, 0.06),
		CFrame.new(0, height / 2 + height * 0.12, 0),
		color
	)
end

-- Ручка сбоку (кружка, чайник): буква «С» из трёх брусков
local function sideHandle(ctx: Context, color: Color3, thickness: number)
	local width, height = ctx.size.X, ctx.size.Y
	local reach = width * 0.28
	local x = width / 2
	for _, y in { height * 0.25, -height * 0.25 } do
		ctx.add(
			"Handle",
			Enum.PartType.Block,
			Vector3.new(reach, thickness, thickness),
			CFrame.new(x + reach / 2 - 0.02, y, 0),
			color
		)
	end
	ctx.add(
		"Handle",
		Enum.PartType.Block,
		Vector3.new(thickness, height * 0.5 + thickness, thickness),
		CFrame.new(x + reach - thickness / 2, 0, 0),
		color
	)
end

local MODELS: { [string]: Model } = {
	-- Химия
	["Губки для посуды"] = {
		Material = Enum.Material.Fabric,
		Build = function(ctx)
			local size = ctx.size
			ctx.add(
				"Scrub",
				Enum.PartType.Block,
				Vector3.new(size.X + 0.01, size.Y * 0.3, size.Z + 0.01),
				CFrame.new(0, size.Y * 0.36, 0),
				Color3.fromRGB(39, 140, 80),
				Enum.Material.Fabric
			)
		end,
	},
	["Средство для посуды"] = {
		Reflectance = 0.1,
		Build = bottle(WHITE, 0.14, 0.45, {
			Title = "ЧИСТО",
			Subtitle = "для посуды",
			Band = Color3.fromRGB(46, 204, 113),
			Text = WHITE,
		}),
	},
	["Стиральный порошок"] = {
		Build = function(ctx)
			topHandle(ctx, DARK)
			printed({
				Title = "ПОРОШОК",
				Subtitle = "автомат · 3 кг",
				Band = WHITE,
				Text = Color3.fromRGB(41, 98, 185),
				Circle = Color3.fromRGB(52, 152, 219),
			})(ctx)
		end,
	},

	-- Красота
	["Помада"] = {
		Material = Enum.Material.Metal,
		Build = function(ctx)
			local width, height = ctx.size.X, ctx.size.Y
			ctx.root.Color = DARK
			ctx.add(
				"Ring",
				Enum.PartType.Cylinder,
				Vector3.new(height * 0.08, width * 1.04, width * 1.04),
				CFrame.new(0, height * 0.18, 0) * VERTICAL,
				GOLD,
				Enum.Material.Metal
			)
			ctx.add(
				"Bullet",
				Enum.PartType.Cylinder,
				Vector3.new(height * 0.3, width * 0.7, width * 0.7),
				CFrame.new(0, height / 2 + height * 0.15, 0) * VERTICAL,
				Color3.fromRGB(192, 30, 50)
			)
			ctx.add(
				"Tip",
				Enum.PartType.Ball,
				Vector3.one * width * 0.7,
				CFrame.new(0, height / 2 + height * 0.3, 0),
				Color3.fromRGB(192, 30, 50)
			)
		end,
	},
	["Шампунь"] = {
		Reflectance = 0.05,
		Build = bottle(WHITE, 0.16, 0.7, {
			Title = "ШАМПУНЬ",
			Subtitle = "для всех типов волос",
			Band = Color3.fromRGB(255, 150, 200),
			Text = WHITE,
		}),
	},
	["Фен"] = {
		Build = printed({
			Title = "ФЕН",
			Subtitle = "2000 Вт · ионизация",
			Band = BRAND,
			Text = WHITE,
			Circle = Color3.fromRGB(255, 150, 200),
		}),
	},

	-- Общак
	["Носки"] = {
		Material = Enum.Material.Fabric,
		Build = function(ctx)
			local size = ctx.size
			local sleeve = ctx.add(
				"Sleeve",
				Enum.PartType.Block,
				Vector3.new(size.X * 0.36, size.Y + 0.02, size.Z + 0.02),
				CFrame.new(0, 0, 0),
				WHITE,
				Enum.Material.Cardboard
			)
			ctx.print(
				sleeve,
				Enum.NormalId.Front,
				{ Title = "НОСКИ", Subtitle = "5 пар", Band = BRAND, Text = WHITE }
			)
		end,
	},
	["Кружка"] = {
		Reflectance = 0.05,
		Build = function(ctx)
			local width, height = ctx.size.X, ctx.size.Y
			ctx.add(
				"Inside",
				Enum.PartType.Cylinder,
				Vector3.new(0.02, width * 0.86, width * 0.86),
				CFrame.new(0, height / 2 + 0.005, 0) * VERTICAL,
				Color3.fromRGB(205, 205, 212)
			)
			ctx.add(
				"Stripe",
				Enum.PartType.Cylinder,
				Vector3.new(height * 0.12, width * 1.01, width * 1.01),
				CFrame.new(0, height * 0.2, 0) * VERTICAL,
				BRAND
			)
			sideHandle(ctx, WHITE, width * 0.12)
		end,
	},
	["Плед"] = {
		Material = Enum.Material.Fabric,
		Build = function(ctx)
			local length, diameter = ctx.size.X, ctx.size.Y
			for _, x in { -length * 0.28, length * 0.28 } do
				ctx.add(
					"Ribbon",
					Enum.PartType.Cylinder,
					Vector3.new(length * 0.07, diameter * 1.04, diameter * 1.04),
					CFrame.new(x, 0, 0),
					Color3.fromRGB(120, 80, 50),
					Enum.Material.Fabric
				)
			end
		end,
	},

	-- Электроника
	["Зарядка"] = {
		Build = function(ctx)
			local size = ctx.size
			for _, x in { -size.X * 0.18, size.X * 0.18 } do
				ctx.add(
					"Prong",
					Enum.PartType.Cylinder,
					Vector3.new(size.Z * 0.35, size.X * 0.12, size.X * 0.12),
					CFrame.new(x, 0, size.Z / 2 + size.Z * 0.17) * FACING,
					STEEL,
					Enum.Material.Metal
				)
			end
			ctx.add(
				"Port",
				Enum.PartType.Block,
				Vector3.new(size.X * 0.45, size.Y * 0.15, 0.02),
				CFrame.new(0, 0, -size.Z / 2 - 0.005),
				DARK
			)
			ctx.add(
				"Led",
				Enum.PartType.Block,
				Vector3.new(size.X * 0.1, 0.02, size.X * 0.1),
				CFrame.new(0, size.Y / 2 + 0.005, -size.Z * 0.3),
				Color3.fromRGB(46, 204, 113),
				Enum.Material.Neon
			)
		end,
	},
	["Наушники"] = {
		Build = function(ctx)
			-- В подробном виде шар-заготовка прячется, вместо него наушники
			local size = ctx.size.X
			ctx.root.Transparency = 1
			for _, side in { -1, 1 } do
				ctx.add(
					"Cup",
					Enum.PartType.Cylinder,
					Vector3.new(size * 0.22, size * 0.55, size * 0.55),
					CFrame.new(side * size * 0.36, -size * 0.12, 0),
					DARK
				)
				ctx.add(
					"Cushion",
					Enum.PartType.Cylinder,
					Vector3.new(size * 0.08, size * 0.45, size * 0.45),
					CFrame.new(side * size * 0.22, -size * 0.12, 0),
					Color3.fromRGB(70, 72, 80),
					Enum.Material.Fabric
				)
				ctx.add(
					"Arm",
					Enum.PartType.Block,
					Vector3.new(0.05, size * 0.4, size * 0.12),
					CFrame.new(side * size * 0.4, size * 0.22, 0) * CFrame.Angles(0, 0, side * math.rad(12)),
					DARK
				)
			end
			ctx.add(
				"Band",
				Enum.PartType.Block,
				Vector3.new(size * 0.7, 0.06, size * 0.14),
				CFrame.new(0, size * 0.43, 0),
				DARK
			)
		end,
	},
	["Чайник"] = {
		Material = Enum.Material.Metal,
		Reflectance = 0.15,
		Build = function(ctx)
			local width, height = ctx.size.X, ctx.size.Y
			ctx.add(
				"Base",
				Enum.PartType.Cylinder,
				Vector3.new(height * 0.07, width * 1.05, width * 1.05),
				CFrame.new(0, -height / 2 + height * 0.035, 0) * VERTICAL,
				DARK
			)
			ctx.add(
				"Lid",
				Enum.PartType.Cylinder,
				Vector3.new(height * 0.05, width * 0.7, width * 0.7),
				CFrame.new(0, height / 2 + height * 0.025, 0) * VERTICAL,
				DARK
			)
			ctx.add(
				"Knob",
				Enum.PartType.Ball,
				Vector3.one * width * 0.14,
				CFrame.new(0, height / 2 + height * 0.08, 0),
				DARK
			)
			ctx.add(
				"Spout",
				Enum.PartType.Block,
				Vector3.new(width * 0.3, height * 0.12, width * 0.14),
				CFrame.new(-width / 2 - width * 0.1, height * 0.25, 0) * CFrame.Angles(0, 0, math.rad(-35)),
				STEEL,
				Enum.Material.Metal
			)
			sideHandle(ctx, DARK, width * 0.1)
		end,
	},

	-- Детское
	["Соска"] = {
		Build = function(ctx)
			local size = ctx.size.X
			local shieldColor = ctx.root.Color
			ctx.root.Transparency = 1
			ctx.add(
				"Shield",
				Enum.PartType.Cylinder,
				Vector3.new(size * 0.2, size * 0.95, size * 0.95),
				CFrame.new(0, 0, 0) * FACING,
				shieldColor
			)
			ctx.add(
				"Nipple",
				Enum.PartType.Ball,
				Vector3.one * size * 0.45,
				CFrame.new(0, 0, -size * 0.3),
				Color3.fromRGB(240, 220, 190)
			)
			ctx.add(
				"Ring",
				Enum.PartType.Cylinder,
				Vector3.new(size * 0.08, size * 0.55, size * 0.55),
				CFrame.new(0, 0, size * 0.22) * FACING,
				WHITE
			)
		end,
	},
	["Мягкая игрушка"] = {
		Material = Enum.Material.Fabric,
		Build = function(ctx)
			-- Плюшевый мишка: корень — туловище, к нему голова, уши, мордочка, глаза, лапы
			local size = ctx.size.X
			local fur = ctx.root.Color
			local light = fur:Lerp(Color3.fromRGB(245, 225, 200), 0.6)
			local function ball(name: string, scale: number, position: Vector3, color: Color3)
				ctx.add(
					name,
					Enum.PartType.Ball,
					Vector3.one * size * scale,
					CFrame.new(position * size),
					color,
					Enum.Material.Fabric
				)
			end
			ball("Head", 0.62, Vector3.new(0, 0.58, -0.04), fur)
			ball("Snout", 0.24, Vector3.new(0, 0.52, -0.3), light)
			for _, side in { -1, 1 } do
				ball("Ear", 0.22, Vector3.new(side * 0.22, 0.86, -0.02), fur)
				ball("Eye", 0.07, Vector3.new(side * 0.1, 0.64, -0.32), DARK)
				ball("Arm", 0.26, Vector3.new(side * 0.44, 0.06, -0.1), fur)
				ball("Foot", 0.3, Vector3.new(side * 0.22, -0.38, -0.2), light)
			end
		end,
	},
	["Конструктор"] = {
		Build = printed({
			Title = "КОНСТРУКТОР",
			Subtitle = "500 деталей · 6+",
			Band = Color3.fromRGB(241, 196, 15),
			Text = DARK,
			Bricks = true,
		}),
	},

	-- Зоотовары
	["Лакомство для собак"] = {
		Material = Enum.Material.Foil,
		Build = function(ctx)
			local size = ctx.size
			ctx.add(
				"Zip",
				Enum.PartType.Block,
				Vector3.new(size.X + 0.01, size.Y * 0.1, size.Z * 0.6),
				CFrame.new(0, size.Y / 2 - size.Y * 0.05, 0),
				DARK
			)
			printed({
				Title = "ДЛЯ СОБАК",
				Subtitle = "лакомство",
				Band = WHITE,
				Text = Color3.fromRGB(160, 70, 20),
			})(ctx)
		end,
	},
	["Корм для кошек"] = {
		Material = Enum.Material.Foil,
		Build = function(ctx)
			local size = ctx.size
			ctx.add(
				"Seal",
				Enum.PartType.Block,
				Vector3.new(size.X + 0.01, size.Y * 0.08, size.Z * 0.5),
				CFrame.new(0, size.Y / 2 - size.Y * 0.04, 0),
				Color3.fromRGB(120, 180, 230),
				Enum.Material.Foil
			)
			printed({
				Title = "КОРМ",
				Subtitle = "для кошек · 1,5 кг",
				Band = WHITE,
				Text = Color3.fromRGB(30, 80, 150),
				Circle = Color3.fromRGB(243, 156, 18),
			})(ctx)
		end,
	},
	["Наполнитель"] = {
		Material = Enum.Material.Fabric,
		Build = function(ctx)
			topHandle(ctx, DARK)
			printed({
				Title = "НАПОЛНИТЕЛЬ",
				Subtitle = "комкующийся · 10 кг",
				Band = Color3.fromRGB(46, 204, 113),
				Text = WHITE,
			})(ctx)
		end,
	},
}

-- Оформить товар. root — его корневая деталь в начале координат, size — размер «стоя»,
-- upright — поворот, которым товар ставят «стоя» (детали задаются в положении «стоя»).
function ItemModels.decorate(name: string, root: BasePart, size: Vector3, upright: CFrame, full: boolean)
	local model = MODELS[name]
	if not model then
		return
	end
	root.Material = model.Material or Enum.Material.SmoothPlastic
	root.Reflectance = model.Reflectance or 0

	local build = model.Build
	if not build then
		return
	end
	local toRoot = root.CFrame * upright:Inverse()
	local context: Context = {
		root = root,
		size = size,
		add = function(partName, shape, partSize, offset, color, material)
			local part = Instance.new("Part")
			part.Name = partName
			part.Shape = shape
			part.Size = partSize
			part.CFrame = toRoot * offset
			part.Color = color
			part.Material = material or Enum.Material.SmoothPlastic
			part.TopSurface = Enum.SurfaceType.Smooth
			part.BottomSurface = Enum.SurfaceType.Smooth
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true
			part.Parent = root
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = part
			weld.Parent = part
			return part
		end,
		print = addPrint,
	}
	-- Без подробностей — только форма и материал
	if full then
		build(context)
	end
end

return ItemModels
