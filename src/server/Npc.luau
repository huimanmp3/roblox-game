--!strict
-- Сотрудники-NPC: настоящие персонажи Roblox (R15) в форме склада. Стоят за столом
-- со стандартной анимацией ожидания или сидят на сиденье (стул, погрузчик, тягач).
-- Персонажей собирает Roblox по описанию (HumanoidDescription) один раз при запуске,
-- дальше NPC — копии этих заготовок. Если собрать не получилось, NPC просто не появятся.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

-- Стандартные анимации Roblox для R15
local IDLE_ANIMATION = "rbxassetid://507766388"
local SIT_ANIMATION = "rbxassetid://2506281703"
local WAIT_FOR_TEMPLATES = 30

-- Варианты внешности: цвет кожи и причёска (ID аксессуара из каталога Roblox, "" — без неё)
local LOOKS = {
	{ Skin = Color3.fromRGB(234, 184, 146), Hair = "376548738" },
	{ Skin = Color3.fromRGB(204, 142, 105), Hair = "63690008" },
	{ Skin = Color3.fromRGB(160, 108, 74), Hair = "451220849" },
	{ Skin = Color3.fromRGB(255, 214, 180), Hair = "63690008" },
}

local Npc = {}

local templates: { Model } = {}
local loading = 0
local started = false

local function describe(skin: Color3, hair: string): HumanoidDescription
	local uniform = Config.Uniform
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = skin
	description.TorsoColor = uniform.TopColor
	description.LeftArmColor = uniform.TopColor
	description.RightArmColor = uniform.TopColor
	description.LeftLegColor = uniform.BottomColor
	description.RightLegColor = uniform.BottomColor
	description.Shirt = uniform.ShirtId
	description.Pants = uniform.PantsId
	description.HairAccessory = hair
	return description
end

local function build(skin: Color3, hair: string): Model?
	local ok, result = pcall(function()
		return Players:CreateHumanoidModelFromDescription(describe(skin, hair), Enum.HumanoidRigType.R15)
	end)
	if ok then
		return result
	end
	-- Причёска могла не загрузиться: пробуем без неё
	if hair ~= "" then
		return build(skin, "")
	end
	warn(`Не удалось собрать NPC: {result}`)
	return nil
end

-- Собрать заготовки NPC (в фоне, это занимает пару секунд). Повторный вызов ничего не делает.
function Npc.preload()
	if started then
		return
	end
	started = true
	for _, look in LOOKS do
		loading += 1
		task.spawn(function()
			local rig = build(look.Skin, look.Hair)
			if rig then
				rig.Name = "Сотрудник"
				local humanoid = rig:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
					humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
				end
				-- NPC не мешают ходить и не ловят клики ТСД
				for _, descendant in rig:GetDescendants() do
					if descendant:IsA("BasePart") then
						descendant.CanCollide = false
						descendant.CanQuery = false
						descendant.CanTouch = false
					elseif descendant.Name == "Animate" then
						descendant:Destroy()
					end
				end
				table.insert(templates, rig)
			end
			loading -= 1
		end)
	end
end

-- Новая копия случайной заготовки. Ждёт, пока заготовки соберутся.
local function newRig(): (Model?, Humanoid?)
	Npc.preload()
	local waitStart = os.clock()
	while #templates == 0 and loading > 0 and os.clock() - waitStart < WAIT_FOR_TEMPLATES do
		task.wait(0.2)
	end
	if #templates == 0 then
		return nil, nil
	end
	local rig = templates[math.random(#templates)]:Clone()
	return rig, rig:FindFirstChildOfClass("Humanoid")
end

-- Ждём, пока модель окажется в Workspace (карту и машины сначала собирают, потом ставят в мир).
-- false — если так и не появилась (например, погрузчик уже уехал и исчез).
local function waitInWorld(instance: Instance): boolean
	local deadline = os.clock() + 10
	while not instance:IsDescendantOf(workspace) do
		if os.clock() > deadline then
			return false
		end
		task.wait(0.1)
	end
	return true
end

local function play(humanoid: Humanoid, animationId: string)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		local created = Instance.new("Animator")
		created.Parent = humanoid
		animator = created
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = animationId
	local track = (animator :: Animator):LoadAnimation(animation)
	track.Looped = true
	track:Play()
end

-- Сотрудник стоит: ноги на высоте cframe, смотрит по cframe.LookVector
function Npc.stand(cframe: CFrame, parent: Instance)
	task.spawn(function()
		local rig, humanoid = newRig()
		local root = if rig then rig:FindFirstChild("HumanoidRootPart") else nil
		if not rig or not humanoid or not root or not root:IsA("BasePart") or not waitInWorld(parent) then
			if rig then
				rig:Destroy()
			end
			return
		end
		root.Anchored = true
		rig:PivotTo(cframe * CFrame.new(0, humanoid.HipHeight + root.Size.Y / 2, 0))
		rig.Parent = parent
		play(humanoid, IDLE_ANIMATION)
	end)
end

-- Сотрудник сидит на сиденье (стул, погрузчик, тягач) и двигается вместе с ним.
-- parent — модель, в которой лежит сиденье (например, погрузчик).
function Npc.sit(seat: Seat, parent: Instance)
	task.spawn(function()
		local rig, humanoid = newRig()
		if not rig or not humanoid or not waitInWorld(seat) then
			if rig then
				rig:Destroy()
			end
			return
		end
		rig:PivotTo(seat.CFrame * CFrame.new(0, 3, 0))
		rig.Parent = parent
		seat:Sit(humanoid)
		play(humanoid, SIT_ANIMATION)
	end)
end

-- Сиденье для NPC: игроки на него не садятся, пройдя мимо
function Npc.seat(size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Seat
	local seat = Instance.new("Seat")
	seat.Name = "NpcSeat"
	seat.Size = size
	seat.CFrame = cframe
	seat.Color = color
	seat.Material = Enum.Material.Fabric
	seat.Anchored = true
	seat.CanCollide = false
	seat.CanTouch = false
	seat.CanQuery = false
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat.BottomSurface = Enum.SurfaceType.Smooth
	seat.Parent = parent
	return seat
end

return Npc
