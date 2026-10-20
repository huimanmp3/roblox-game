--!strict
-- Звуки игры (Config.Sounds) для клиента:
--   Sfx.play("Scan") — звук только для себя;
--   Sfx.play("Scan", position) — звук в точке мира (слышно рядом).
-- Пустой ID в Config.Sounds — звука нет.

local SoundService = game:GetService("SoundService")

local Config = require(script.Parent.Config)

local WORLD_RANGE = 50

local Sfx = {}

local templates: { [string]: Sound } = {}

local function template(name: string): Sound?
	local id = (Config.Sounds :: any)[name]
	if typeof(id) ~= "string" or id == "" then
		return nil
	end
	local existing = templates[name]
	if existing then
		return existing
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = id
	sound.Volume = 0.5
	sound.Parent = SoundService
	templates[name] = sound
	return sound
end

function Sfx.play(name: string, position: Vector3?)
	local sound = template(name)
	if not sound then
		return
	end
	if not position then
		SoundService:PlayLocalSound(sound)
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Parent = workspace.Terrain
	attachment.WorldPosition = position
	local copy = sound:Clone()
	copy.RollOffMaxDistance = WORLD_RANGE
	copy.Parent = attachment
	copy:Play()
	task.delay(math.max(copy.TimeLength, 1) + 0.5, function()
		attachment:Destroy()
	end)
end

-- Зацикленный звук для себя (фоновый шум). nil — если ID не задан.
function Sfx.loop(name: string, volume: number): Sound?
	local sound = template(name)
	if not sound then
		return nil
	end
	local looped = sound:Clone()
	looped.Looped = true
	looped.Volume = volume
	looped.Parent = SoundService
	looped:Play()
	return looped
end

return Sfx
