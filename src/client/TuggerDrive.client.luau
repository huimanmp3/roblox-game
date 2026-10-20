--!strict
-- Управление тягачом: W/S — газ и задний ход, A/D — поворот (на телефоне — экранный джойстик).
-- Сервер отдаёт физику тягача водителю, поэтому тягач двигается прямо отсюда:
-- каждый кадр ставим его на новое место и на высоту пола (GroundY), без физики колёс.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local TURN_SPEED = math.rad(100) -- градусов в секунду
local ACCELERATION = 24
local LOOK_AHEAD = 3.5 -- за сколько studs до стены тягач останавливается

local player = Players.LocalPlayer
local speed = 0

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.CollisionGroup = "Tugger" -- барьеры, которые тягач проезжает, луч тоже не замечает
rayParams.RespectCanCollide = true -- зоны на полу и тары без столкновений дорогу не загораживают

local function currentSeat(): VehicleSeat?
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local seat = if humanoid then humanoid.SeatPart else nil
	if seat and seat:IsA("VehicleSeat") and seat:GetAttribute("Tugger") == true then
		return seat
	end
	return nil
end

local function blocked(model: Model, origin: Vector3, direction: Vector3): boolean
	local character = player.Character
	rayParams.FilterDescendantsInstances = if character then { model, character } else { model }
	local hit = workspace:Raycast(origin, direction, rayParams)
	return hit ~= nil and hit.Instance.CanCollide
end

RunService.Heartbeat:Connect(function(deltaTime)
	local seat = currentSeat()
	local model = if seat then seat:FindFirstAncestorOfClass("Model") else nil
	local chassis = if model then model.PrimaryPart else nil
	if not seat or not model or not chassis or chassis.Anchored then
		speed = 0
		return
	end

	local maxSpeed = seat:GetAttribute("Speed")
	local groundY = seat:GetAttribute("GroundY")
	if typeof(maxSpeed) ~= "number" or typeof(groundY) ~= "number" then
		return
	end

	local target = seat.ThrottleFloat * maxSpeed
	speed += math.clamp(target - speed, -ACCELERATION * deltaTime, ACCELERATION * deltaTime)

	-- Поворачиваем только по горизонтали; задним ходом руль работает наоборот, как у машины
	local look = chassis.CFrame.LookVector
	local yaw = math.atan2(-look.X, -look.Z)
	local direction = if speed < -0.5 then -1 else 1
	yaw -= seat.SteerFloat * TURN_SPEED * deltaTime * direction
	local position = Vector3.new(chassis.Position.X, groundY, chassis.Position.Z)
	local rotated = CFrame.new(position) * CFrame.Angles(0, yaw, 0)

	local step = rotated.LookVector * speed * deltaTime
	if math.abs(speed) > 0.1 then
		local ahead = rotated.LookVector * (if speed > 0 then 1 else -1) * LOOK_AHEAD
		if blocked(model, position, ahead) then
			speed = 0
			step = Vector3.zero
		end
	end

	chassis.CFrame = rotated + step
	chassis.AssemblyLinearVelocity = Vector3.zero
	chassis.AssemblyAngularVelocity = Vector3.zero
end)
