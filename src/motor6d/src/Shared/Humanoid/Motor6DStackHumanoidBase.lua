--!strict
--[=[
    @class Motor6DStackHumanoidBase
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Brio = require("Brio")
local Maid = require("Maid")
local Motor6DStackHumanoidInterface = require("Motor6DStackHumanoidInterface")
local Motor6DStackInterface = require("Motor6DStackInterface")
local Observable = require("Observable")
local Rx = require("Rx")
local RxBrioUtils = require("RxBrioUtils")
local RxInstanceUtils = require("RxInstanceUtils")
local ServiceBag = require("ServiceBag")
local TieRealmService = require("TieRealmService")
local Motor6DStackHumanoidBase = setmetatable({}, BaseObject)
Motor6DStackHumanoidBase.ClassName = "Motor6DStackHumanoidBase"
Motor6DStackHumanoidBase.__index = Motor6DStackHumanoidBase

export type Motor6DStackHumanoidBase =
	typeof(setmetatable(
		{} :: {
			_obj: Humanoid,
			_serviceBag: ServiceBag.ServiceBag,
			_tieRealmService: TieRealmService.TieRealmService,
			_observeMotor6DsBrioCache: Observable.Observable<Brio.Brio<Motor6D>>?,
		},
		{} :: typeof({ __index = Motor6DStackHumanoidBase })
	))
	& BaseObject.BaseObject

function Motor6DStackHumanoidBase.new(humanoid: Humanoid, serviceBag: ServiceBag.ServiceBag): Motor6DStackHumanoidBase
	local self: Motor6DStackHumanoidBase = setmetatable(BaseObject.new(humanoid) :: any, Motor6DStackHumanoidBase)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._tieRealmService = serviceBag:GetService(TieRealmService :: any)

	self._maid:GiveTask(Motor6DStackHumanoidInterface:Implement(self._obj, self, self._tieRealmService:GetTieRealm()))

	return self
end

--[=[
	Pushes a transformer for each Motor6DStack associated with the humanoid.

	@param createTransformerCallback CreateTransformerCallback -- Callback which creates the transformer for each Motor6DStack.
	@return () -> () -- A function which, when called, will clean up all created transformers.
]=]
function Motor6DStackHumanoidBase:PushForEachMotor6D(
	createTransformerCallback: Motor6DStackHumanoidInterface.CreateTransformerCallback
): () -> ()
	local topMaid = Maid.new()

	topMaid:GiveTask(self:ObserveMotor6DStacksBrio():Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local maid, motor6DStack = brio:ToMaidAndValue()
		local transformer = createTransformerCallback(maid, motor6DStack)
		maid:Add(motor6DStack:Push(transformer))
	end))

	self._maid[topMaid] = topMaid

	return function()
		self._maid[topMaid] = nil
	end
end

--[=[
	Observes Motor6D instances parented to the humanoid's character as Brio objects.

	@return Observable<Brio<Motor6D>>
]=]
function Motor6DStackHumanoidBase.ObserveMotor6DsBrio(
	self: Motor6DStackHumanoidBase
): Observable.Observable<Brio.Brio<Motor6D>>
	if self._observeMotor6DsBrioCache then
		return self._observeMotor6DsBrioCache
	end

	self._observeMotor6DsBrioCache = RxInstanceUtils.observeParentBrio(self._obj):Pipe({
		RxBrioUtils.flatMapBrio(function(character)
			return RxInstanceUtils.observeDescendantsBrio(character, function(descendant)
				return descendant:IsA("Motor6D")
			end)
		end) :: any,
		Rx.cache() :: any,
	}) :: any

	assert(self._observeMotor6DsBrioCache, "Typechecking assertion")
	return self._observeMotor6DsBrioCache
end

--[=[
	Observes Motor6DStackInterface instances for this character

	@return Observable<Brio<Motor6DStackInterface>>
]=]
function Motor6DStackHumanoidBase.ObserveMotor6DStacksBrio(self: Motor6DStackHumanoidBase): Observable.Observable<
	Brio.Brio<Motor6DStackInterface.Motor6DStackInterface>
>
	return self:ObserveMotor6DsBrio():Pipe({
		RxBrioUtils.flatMapBrio(function(motor6D)
			return Motor6DStackInterface:ObserveBrio(motor6D, self._tieRealmService:GetTieRealm())
		end) :: any,
	}) :: any
end

return Motor6DStackHumanoidBase
