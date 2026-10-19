--!strict
-- Перенос предмета в руках: деталь крепится перед персонажем.

local CARRY_OFFSET = CFrame.new(0, 0.3, -1.9) -- перед грудью персонажа
local WELD_NAME = "CarryWeld"

local Carry = {}

function Carry.attach(part: BasePart, character: Model): boolean
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end

	Carry.detach(part)
	part.CFrame = root.CFrame * CARRY_OFFSET
	part.CanCollide = false
	part.Massless = true
	part.Anchored = false

	local weld = Instance.new("WeldConstraint")
	weld.Name = WELD_NAME
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part

	part.Parent = character
	return true
end

-- Отцепляет деталь и закрепляет её на месте
function Carry.detach(part: BasePart)
	local weld = part:FindFirstChild(WELD_NAME)
	if weld then
		weld:Destroy()
	end
	part.Anchored = true
end

return Carry
