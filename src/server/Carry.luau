--!strict
-- Перенос предмета в руках: деталь или модель крепится перед персонажем.
-- У модели должна быть PrimaryPart, к ней и цепляется сварка.

local DEFAULT_OFFSET = CFrame.new(0, 0.3, -1.9) -- перед грудью персонажа
local WELD_NAME = "CarryWeld"

local Carry = {}

local function mainPart(object: PVInstance): BasePart?
	if object:IsA("BasePart") then
		return object
	end
	if object:IsA("Model") then
		return object.PrimaryPart
	end
	return nil
end

-- offset задаёт положение относительно HumanoidRootPart
function Carry.attach(object: PVInstance, character: Model, offset: CFrame?): boolean
	local root = character:FindFirstChild("HumanoidRootPart")
	local main = mainPart(object)
	if not root or not root:IsA("BasePart") or not main then
		return false
	end

	Carry.detach(object)
	object:PivotTo(root.CFrame * (offset or DEFAULT_OFFSET))
	main.CanCollide = false
	main.Massless = true
	main.Anchored = false

	local weld = Instance.new("WeldConstraint")
	weld.Name = WELD_NAME
	weld.Part0 = root
	weld.Part1 = main
	weld.Parent = main

	object.Parent = character
	return true
end

-- Отцепляет предмет и закрепляет его на месте
function Carry.detach(object: PVInstance)
	local main = mainPart(object)
	if not main then
		return
	end
	local weld = main:FindFirstChild(WELD_NAME)
	if weld then
		weld:Destroy()
	end
	main.Anchored = true
end

return Carry
