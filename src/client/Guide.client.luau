--!strict
-- Стрелка-указатель: луч от игрока к цели и метка над целью, видная сквозь стены.
-- Цель выставляет сервер в ObjectValue GuideTarget, подпись — в атрибут GuideLabel.
-- Рядом с целью стрелка прячется, чтобы не мешать работать.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local GUIDE_COLOR = Color3.fromRGB(190, 90, 255)
local HIDE_DISTANCE = 15

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local guideTarget = player:WaitForChild("GuideTarget") :: ObjectValue

local created: { Instance } = {}
local current: { root: BasePart, target: BasePart, beam: Beam, billboard: BillboardGui }? = nil

local function clear()
	for _, instance in created do
		instance:Destroy()
	end
	table.clear(created)
	current = nil
end

local function update()
	clear()

	local target = guideTarget.Value
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not target or not target:IsA("BasePart") or not root or not root:IsA("BasePart") then
		return
	end

	local from = Instance.new("Attachment")
	from.Name = "GuideFrom"
	from.Parent = root

	local to = Instance.new("Attachment")
	to.Name = "GuideTo"
	to.Parent = target

	local beam = Instance.new("Beam")
	beam.Attachment0 = from
	beam.Attachment1 = to
	beam.Color = ColorSequence.new(GUIDE_COLOR)
	beam.Width0 = 0.5
	beam.Width1 = 0.5
	beam.FaceCamera = true
	beam.LightEmission = 0.5
	beam.Transparency = NumberSequence.new(0.2)
	beam.Parent = root

	local billboard = Instance.new("BillboardGui")
	billboard.Adornee = target
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(240, 50)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 6, 0)
	billboard.Parent = playerGui

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.BuilderSansExtraBold
	label.TextScaled = true
	label.TextColor3 = GUIDE_COLOR
	label.TextStrokeTransparency = 0
	label.Text = `▼ {player:GetAttribute("GuideLabel") or ""}`
	label.Parent = billboard

	table.insert(created, from)
	table.insert(created, to)
	table.insert(created, beam)
	table.insert(created, billboard)
	current = { root = root, target = target, beam = beam, billboard = billboard }
end

RunService.Heartbeat:Connect(function()
	local guide = current
	if guide then
		local far = (guide.root.Position - guide.target.Position).Magnitude > HIDE_DISTANCE
		guide.beam.Enabled = far
		guide.billboard.Enabled = far
	end
end)

guideTarget.Changed:Connect(update)
player:GetAttributeChangedSignal("GuideLabel"):Connect(update)
player.CharacterAdded:Connect(function(character)
	character:WaitForChild("HumanoidRootPart")
	update()
end)
update()
