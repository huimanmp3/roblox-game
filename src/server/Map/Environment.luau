--!strict
-- Свет: ровный нейтральный свет склада, мягкие тени и лёгкая цветокоррекция.
-- Если хочешь настроить свет вручную в Studio (Lighting), убери вызов Environment.apply из Map/init:
-- тогда скрипт ничего не будет менять.

local Lighting = game:GetService("Lighting")

local Environment = {}

-- Эффект в Lighting с таким именем: берём готовый или создаём
local function effect(className: string, name: string): Instance
	local existing = Lighting:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	local created = Instance.new(className :: any)
	created.Name = name
	created.Parent = Lighting
	return created
end

function Environment.apply()
	-- Современный реалистичный свет. Эти свойства есть не во всех версиях Roblox,
	-- поэтому ставим их осторожно: если их нет, просто остаётся обычный свет
	pcall(function()
		(Lighting :: any).LightingStyle = Enum.LightingStyle.Realistic
	end)
	pcall(function()
		(Lighting :: any).PrioritizeLightingQuality = true
	end)
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.2
	Lighting.ClockTime = 13
	Lighting.Brightness = 1.5
	-- Под крышей склада свет в основном рассеянный: ровный и нейтральный, без пересвета
	Lighting.Ambient = Color3.fromRGB(96, 98, 106)
	Lighting.OutdoorAmbient = Color3.fromRGB(110, 112, 120)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.ExposureCompensation = 0

	local color = effect("ColorCorrectionEffect", "WarehouseColor") :: ColorCorrectionEffect
	color.Brightness = 0
	color.Contrast = 0.1
	color.Saturation = 0.05
	color.TintColor = Color3.new(1, 1, 1)

	-- Свечение (bloom) и дымка внутри здания засвечивают картинку, поэтому их нет
	for _, name in { "WarehouseBloom", "WarehouseAtmosphere" } do
		local old = Lighting:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
end

return Environment
