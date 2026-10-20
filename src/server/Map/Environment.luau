--!strict
-- Свет и атмосфера: мягкий ровный свет склада, лёгкая дымка и цветокоррекция.
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
	-- Современный реалистичный свет с мягкими тенями
	Lighting.LightingStyle = Enum.LightingStyle.Realistic
	Lighting.PrioritizeLightingQuality = true
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.3
	Lighting.ClockTime = 13
	Lighting.Brightness = 2
	-- Под крышей склада свет в основном рассеянный: делаем его светлым и чуть холодным
	Lighting.Ambient = Color3.fromRGB(128, 130, 140)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 142, 150)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.ExposureCompensation = 0.15

	local color = effect("ColorCorrectionEffect", "WarehouseColor") :: ColorCorrectionEffect
	color.Brightness = 0.02
	color.Contrast = 0.08
	color.Saturation = 0.05
	color.TintColor = Color3.fromRGB(255, 252, 248)

	local bloom = effect("BloomEffect", "WarehouseBloom") :: BloomEffect
	bloom.Intensity = 0.6
	bloom.Size = 24
	bloom.Threshold = 1.4

	local atmosphere = effect("Atmosphere", "WarehouseAtmosphere") :: Atmosphere
	atmosphere.Density = 0.22
	atmosphere.Offset = 0
	atmosphere.Haze = 0.4
	atmosphere.Glare = 0
	atmosphere.Color = Color3.fromRGB(205, 210, 220)
	atmosphere.Decay = Color3.fromRGB(110, 115, 130)
end

return Environment
