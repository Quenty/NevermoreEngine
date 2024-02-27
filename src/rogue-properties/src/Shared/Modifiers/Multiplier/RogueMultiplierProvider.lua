--[=[
	@class RogueMultiplierProvider
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local Rx = require("Rx")
local RxBinderUtils = require("RxBinderUtils")
local BinderUtils = require("BinderUtils")
local RoguePropertyModifierUtils = require("RoguePropertyModifierUtils")
local RoguePropertyService = require("RoguePropertyService")
local Observable = require("Observable")
local Maid = require("Maid")
local ValueObject = require("ValueObject")

local RogueMultiplierProvider = {}
RogueMultiplierProvider.ServiceName = "RogueMultiplierProvider"

function RogueMultiplierProvider:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	-- Internal
	self._roguePropetyService = self._serviceBag:GetService(RoguePropertyService)
	self._rogueMultiplierBinder = self._serviceBag:GetService(require("RogueMultiplier"))

	self._roguePropetyService:AddProvider(self)
end

function RogueMultiplierProvider:GetBinder()
	return self._rogueMultiplierBinder
end

function RogueMultiplierProvider:Create(multiplier, source)
	assert(type(multiplier) == "number", "Bad multiplier")
	assert(typeof(source) == "Instance" or source == nil, "Bad source")

	local obj = Instance.new("NumberValue")
	obj.Name = "Multiplier"
	obj.Value = multiplier

	if source then
		RoguePropertyModifierUtils.createSourceLink(obj, source)
	end

	if RunService:IsClient() then
		self._rogueMultiplierBinder:BindClient(obj)
	else
		self._rogueMultiplierBinder:Bind(obj)
	end

	return obj
end

function RogueMultiplierProvider:GetInvertedVersion(propObj, rogueProperty, baseValue)
	if rogueProperty:GetDefinition():GetValueType() == "number" then
		local multiplier = 1

		for _, item in pairs(self:_getMultipliers(propObj)) do
			multiplier = multiplier*item:GetMultiplier()
		end

		return baseValue/multiplier
	else
		return baseValue
	end
end

function RogueMultiplierProvider:GetModifiedVersion(propObj, rogueProperty, baseValue)
	if rogueProperty:GetDefinition():GetValueType() == "number" then
		local multiplier = 1

		for _, item in pairs(self:_getMultipliers(propObj)) do
			multiplier = multiplier*item:GetMultiplier()
		end

		return baseValue*multiplier
	else
		return baseValue
	end
end

function RogueMultiplierProvider:ObserveModifiedVersion(propObj, rogueProperty, observeBaseValue)
	if rogueProperty:GetDefinition():GetValueType() == "number" then
		return Observable.new(function(sub)
			local topMaid = Maid.new()

			local lastValue = topMaid:Add(ValueObject.fromObservable(observeBaseValue))

			local function update()
				sub:Fire(lastValue.Value)
			end

			topMaid:GiveTask(self:_observeMultipliersBrio(propObj):Subscribe(function(brio)
				if brio:IsDead() then
					return
				end

				local maid = brio:ToMaid()
				local value = brio:GetValue()

				maid:GiveTask(value:ObserveMultiplier():Subscribe(function()
					update()
				end))

				update()

				maid:GiveTask(function()
					update()
				end)
			end))

			topMaid:GiveTask(lastValue:Observe():Subscribe(function()
				update()
			end))

			return topMaid
		end):Pipe({
			Rx.throttleDefer();
			Rx.map(function(baseValue)
				return self:GetModifiedVersion(propObj, rogueProperty, baseValue)
			end);
		})
	else
		return observeBaseValue
	end
end

function RogueMultiplierProvider:_observeMultipliersBrio(propObj)
	return RxBinderUtils.observeBoundChildClassBrio(self._rogueMultiplierBinder, propObj)
end

function RogueMultiplierProvider:_getMultipliers(propObj)
	return BinderUtils.getChildren(self._rogueMultiplierBinder, propObj)
end

return RogueMultiplierProvider