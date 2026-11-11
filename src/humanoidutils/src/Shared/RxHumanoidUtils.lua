--!strict
--[=[
	@class RxHumanoidUtils
]=]

local require = require(script.Parent.loader).load(script)

local HumanoidUtils = require("HumanoidUtils")
local Maid = require("Maid")
local Observable = require("Observable")
local Rx = require("Rx")
local RxInstanceUtils = require("RxInstanceUtils")

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
	end) :: any
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
	end) :: any
end

--[=[
	Observes whether a humanoid state type is enabled on the humanoid.

	@param humanoid Humanoid
	@param stateType Enum.HumanoidStateType
	@return Observable<boolean>
]=]
function RxHumanoidUtils.observeHumanoidStateEnabled(
	humanoid: Humanoid,
	stateType: Enum.HumanoidStateType
): Observable.Observable<boolean>
	assert(typeof(humanoid) == "Instance" and humanoid:IsA("Humanoid"), "No humanoid")
	assert(typeof(stateType) == "EnumItem", "No stateType")

	return Rx.fromSignal(humanoid.StateEnabledChanged):Pipe({
		Rx.where(function(changedStateType)
			return changedStateType == stateType
		end) :: any,
		Rx.map(function(_changedStateType, isEnabled)
			return isEnabled
		end) :: any,
		Rx.startFrom(function()
			return { HumanoidUtils.isHumanoidStateEnabled(humanoid, stateType) }
		end) :: any,
		Rx.distinct() :: any,
	}) :: any
end

--[=[
	Observes whether the humanoid is allowed to jump. This is true when the jumping state is enabled
	and the humanoid's jump strength is above zero, which is the strength Roblox reads for the
	humanoid's [Humanoid.UseJumpPower] mode.

	@param humanoid Humanoid
	@return Observable<boolean>
]=]
function RxHumanoidUtils.observeJumpEnabled(humanoid: Humanoid): Observable.Observable<boolean>
	assert(typeof(humanoid) == "Instance" and humanoid:IsA("Humanoid"), "No humanoid")

	return Rx.combineLatest({
		isJumpStateEnabled = RxHumanoidUtils.observeHumanoidStateEnabled(humanoid, Enum.HumanoidStateType.Jumping),
		useJumpPower = RxInstanceUtils.observeProperty(humanoid, "UseJumpPower"),
		jumpPower = RxInstanceUtils.observeProperty(humanoid, "JumpPower"),
		jumpHeight = RxInstanceUtils.observeProperty(humanoid, "JumpHeight"),
	}):Pipe({
		Rx.map(function()
			return HumanoidUtils.isJumpEnabled(humanoid)
		end) :: any,
		Rx.distinct() :: any,
	}) :: any
end

return RxHumanoidUtils
