--!strict
-- Эффекты приёмки: товар летит в тележку, над ней всплывает цена пика.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local effectEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Effect") :: RemoteEvent

local FLY_TIME = 0.3
local REWARD_TIME = 0.8

local function makeEffectPart(size: Vector3, position: Vector3): Part
	local part = Instance.new("Part")
	part.Size = size
	part.CFrame = CFrame.new(position)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = workspace
	return part
end

local function flyItem(from: Vector3, to: Vector3, color: Color3)
	local item = makeEffectPart(Vector3.new(0.7, 0.7, 0.7), from)
	item.Color = color
	item.Material = Enum.Material.SmoothPlastic

	TweenService:Create(item, TweenInfo.new(FLY_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		CFrame = CFrame.new(to) * CFrame.Angles(math.pi, math.pi / 2, 0),
		Size = Vector3.new(0.3, 0.3, 0.3),
	}):Play()
	task.delay(FLY_TIME, function()
		item:Destroy()
	end)
end

local function showReward(position: Vector3, amount: number)
	local anchor = makeEffectPart(Vector3.new(0.1, 0.1, 0.1), position)
	anchor.Transparency = 1

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(100, 40)
	billboard.StudsOffset = Vector3.new(0, 1.5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.BuilderSansExtraBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(46, 204, 113)
	label.TextStrokeTransparency = 0.3
	label.Text = string.format("+%.2f ₽", amount)
	label.Parent = billboard

	local info = TweenInfo.new(REWARD_TIME)
	TweenService:Create(billboard, info, { StudsOffset = Vector3.new(0, 3.5, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(REWARD_TIME, function()
		anchor:Destroy()
	end)
end

effectEvent.OnClientEvent:Connect(function(kind: string, a: any, b: any, c: any)
	if kind == "item" then
		flyItem(a, b, c)
	elseif kind == "reward" then
		showReward(a, b)
	end
end)
