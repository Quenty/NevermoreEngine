--[=[
	@class RxHumanoidUtils
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")
local Observable = require("Observable")

local RxHumanoidUtils = {}

--[=[
	Observes the running speed of a humanoid

	:::tip
	When using :MoveTo this is the only way to know if the humanoid is walking at any speed
	:::

	@return Observable<number>
]=]
function RxHumanoidUtils.observeRunningSpeed(humanoid: Humanoid): Observable.Observable<number>
	assert(typeof(humanoid) == "Instance" and humanoid:IsA("Humanoid"), "No humanoid")

	return Observable.new(function(sub)
		local maid = Maid.new()

		local lastRunningSpeed = nil

		local function emitRunningSpeed(speed: number)
			if lastRunningSpeed ~= speed then
				lastRunningSpeed = speed
				sub:Fire(speed)
			end
		end

		maid:GiveTask(humanoid.Running:Connect(function(speed)
			emitRunningSpeed(speed)
		end))

		maid:GiveTask(humanoid.Swimming:Connect(function()
			emitRunningSpeed(0)
		end))

		maid:GiveTask(humanoid.Jumping:Connect(function()
			emitRunningSpeed(0)
		end))

		maid:GiveTask(humanoid.FreeFalling:Connect(function()
			emitRunningSpeed(0)
		end))

		maid:GiveTask(humanoid.Seated:Connect(function()
			emitRunningSpeed(0)
		end))

		if not lastRunningSpeed then
			emitRunningSpeed(0)
		end

		return maid
	end)
end

--[=[
	Observes a humanoid's HumanoidStateType
]=]
function RxHumanoidUtils.observeHumanoidStateType(humanoid: Humanoid): Observable.Observable<Enum.HumanoidStateType>
	return Observable.new(function(sub)
		local maid = Maid.new()

		local lastStateType = nil

		local function emitStateType(stateType: Enum.HumanoidStateType)
			if lastStateType ~= stateType then
				lastStateType = stateType
				sub:Fire(stateType)
			end
		end

		maid:GiveTask(humanoid.StateChanged:Connect(function(_oldState, stateType)
			emitStateType(stateType)
		end))

		if not lastStateType then
			emitStateType(humanoid:GetState())
		end

		return maid
	end)

end

return RxHumanoidUtils
