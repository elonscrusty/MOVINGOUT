--[[
	TruckService.luau
	The one authority on delivery. Reconstruction rule (not taken from the original):
	  * the 8 corners of an item's collider box are tested in truck-cargo space;
	  * an item becomes delivered when at least Config.Delivery.InFraction of its corners
	    are inside the cargo volume (Tolerance studs of slack), nobody holds it, and that
	    stayed true for SettleTime seconds;
	  * a delivered item stops counting when fewer than OutFraction corners are inside
	    (hysteresis, so items on the boundary don't flicker);
	  * stacked items count if they are inside the volume (its top is open).
	The displayed count is always derived from the per-item states, never incremented by
	collision callbacks, and completion is checked only after states update.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local S = require(script.Parent.Services)

local TruckService = {}

local pendingSince: { [Model]: number } = {}
local accumulator = 0

-- Fraction (0..1) of an item's box corners inside the truck cargo volume.
function TruckService.InsideFraction(body: BasePart, cargo: CFrame, cargoSize: Vector3): number
	local tol = Config.Delivery.Tolerance
	local half = body.Size / 2
	local limit = cargoSize / 2
	local inside = 0
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local world = body.CFrame:PointToWorldSpace(Vector3.new(sx * half.X, sy * half.Y, sz * half.Z))
				local l = cargo:PointToObjectSpace(world)
				-- the cargo top is open: allow stacks to poke out above the walls
				if math.abs(l.X) <= limit.X + tol and math.abs(l.Z) <= limit.Z + tol and l.Y >= -limit.Y - tol and l.Y <= limit.Y + 6 then
					inside += 1
				end
			end
		end
	end
	return inside / 8
end

function TruckService.Counts(): (number, number)
	local lvl = S.World.Level
	if not lvl then
		return 0, 0
	end
	local delivered, required = 0, 0
	for _, model in lvl.Items do
		if model:GetAttribute("Required") then
			required += 1
			if model:GetAttribute("Delivered") then
				delivered += 1
			end
		end
	end
	return delivered, required
end

local function publish()
	local d, r = TruckService.Counts()
	local state = Net.State()
	state:SetAttribute("Delivered", d)
	state:SetAttribute("Required", r)
	return d, r
end

function TruckService.Reset()
	table.clear(pendingSince)
	accumulator = 0
	publish()
end

local function setDelivered(model: Model, value: boolean)
	if (model:GetAttribute("Delivered") == true) == value then
		return
	end
	model:SetAttribute("Delivered", value)
	local body = model.PrimaryPart
	S.Fx.All("Deliver", { Item = model.Name, Delivered = value, Pos = body and body.Position, Required = model:GetAttribute("Required") })
	if value and S.World.Assists.VanishDelivered and S.World.IsJob then
		task.delay(Config.Delivery.VanishDelay, function()
			if model:GetAttribute("Delivered") and model.Parent then
				S.Items.Vanish(model)
			end
		end)
	end
end

function TruckService.Step(dt: number)
	local lvl = S.World.Level
	if not lvl or S.World.Paused then
		return
	end
	accumulator += dt
	if accumulator < Config.Tick.DeliveryInterval then
		return
	end
	local step = accumulator
	accumulator = 0
	local truck = lvl.Truck
	local changed = false
	for _, model in lvl.Items do
		if model:GetAttribute("Vanished") then
			continue -- vanished items stay delivered
		end
		local body = model.PrimaryPart
		if not body or not model.Parent or model:GetAttribute("Recovering") then
			if model:GetAttribute("Delivered") then
				setDelivered(model, false)
				changed = true
			end
			pendingSince[model] = nil
			continue
		end
		local frac = TruckService.InsideFraction(body, truck.Cargo, truck.CargoSize)
		local wasDelivered = model:GetAttribute("Delivered") == true
		if wasDelivered then
			if frac < Config.Delivery.OutFraction then
				setDelivered(model, false)
				changed = true
			end
		else
			if frac >= Config.Delivery.InFraction and not S.Carry.IsHeld(model) then
				pendingSince[model] = (pendingSince[model] or 0) + step
				if pendingSince[model] >= Config.Delivery.SettleTime then
					pendingSince[model] = nil
					setDelivered(model, true)
					changed = true
				end
			else
				pendingSince[model] = nil
			end
		end
	end
	if changed then
		local d, r = publish()
		if S.World.IsJob and r > 0 and d >= r then
			S.Jobs.OnAllDelivered()
		end
	end
end

return TruckService
