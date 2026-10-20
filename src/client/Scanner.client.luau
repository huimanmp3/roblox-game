--!strict
-- ТСД в руке: по клику сообщает серверу, по чему кликнули, и рисует лазер.
-- Что именно произошло (принят палет, товар ушёл в тележку), решает сервер.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local scanEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Scan") :: RemoteEvent

local LASER_TIME = 0.08
local LASER_COLOR = Color3.fromRGB(255, 40, 40)

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local lastScan = 0
local hooked: { [Tool]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function showLaser(tool: Tool, hitPosition: Vector3)
	local handle = tool:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		return
	end

	local from = handle.Position
	local distance = (hitPosition - from).Magnitude
	local laser = Instance.new("Part")
	laser.Anchored = true
	laser.CanCollide = false
	laser.CanQuery = false
	laser.CanTouch = false
	laser.CastShadow = false
	laser.Material = Enum.Material.Neon
	laser.Color = LASER_COLOR
	laser.Size = Vector3.new(0.06, 0.06, distance)
	laser.CFrame = CFrame.lookAt(from, hitPosition) * CFrame.new(0, 0, -distance / 2)
	laser.Parent = workspace

	task.delay(LASER_TIME, function()
		laser:Destroy()
	end)
end

local function onActivated(tool: Tool)
	local now = os.clock()
	if now - lastScan < Config.ScanCooldown then
		return
	end
	lastScan = now

	local character = player.Character
	if not character then
		return
	end

	-- Не попадать по своему персонажу и по таре в руках
	mouse.TargetFilter = character
	local target = mouse.Target
	showLaser(tool, mouse.Hit.Position)
	if target then
		scanEvent:FireServer(target)
	end
end

local function hook(child: Instance)
	if child:IsA("Tool") and child:GetAttribute("Scanner") == true and not hooked[child] then
		hooked[child] = true
		child.Activated:Connect(function()
			onActivated(child)
		end)
	end
end

local function watchCharacter(character: Model)
	for _, child in character:GetChildren() do
		hook(child)
	end
	character.ChildAdded:Connect(hook)
end

player.CharacterAdded:Connect(watchCharacter)
if player.Character then
	watchCharacter(player.Character)
end
